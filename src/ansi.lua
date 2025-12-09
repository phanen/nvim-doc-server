-- https://github.com/ibhagwan/fzf-lua/blob/29efa7a4d8292e68ee64e7ec16ad1f88ee3c3f65/lua/fzf-lua/utils.lua#L670
local M = {}
M.ansi_codes = {} ---@type table<string, fun(string: any):string>
M.ansi_escseq = {
  -- the "\x1b" esc sequence causes issues
  -- with older Lua versions
  -- clear    = "\x1b[0m",
  clear = "[0m",
  bold = "[1m",
  italic = "[3m",
  underline = "[4m",
  black = "[0;30m",
  red = "[0;31m",
  green = "[0;32m",
  yellow = "[0;33m",
  blue = "[0;34m",
  magenta = "[0;35m",
  cyan = "[0;36m",
  white = "[0;37m",
  grey = "[0;90m",
  dark_grey = "[0;97m",
}

---@param name string
---@param escseq string
M.cache_ansi_escseq = function(name, escseq)
  ---@param string any
  ---@return string
  M.ansi_codes[name] = function(string)
    if string == nil or #string == 0 then
      return ""
    end
    if not escseq or #escseq == 0 then
      return string
    end
    return escseq .. string .. M.ansi_escseq.clear
  end
end

-- Generate a cached ansi sequence function for all basic colors
for color, escseq in pairs(M.ansi_escseq) do
  M.cache_ansi_escseq(color, escseq)
end

-- Helper func to test for invalid (cleared) highlights
function M.is_hl_cleared(hl)
  local ok, hl_def = pcall(vim.api.nvim_get_hl, 0, { name = hl, link = false })
  if not ok or M.tbl_isempty(hl_def) then
    return true
  end
end

function M.COLORMAP()
  if not M.__COLORMAP then
    M.__COLORMAP = vim.api.nvim_get_color_map()
  end
  return M.__COLORMAP
end

local function synIDattr(hl, w, mode)
  -- Although help specifies invalid mode returns the active hlgroups
  -- when sending `nil` for mode the return value for "fg" is also nil
  return mode == "cterm"
    or mode == "gui" and vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(hl)), w, mode)
    or vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(hl)), w)
end

function M.hexcol_from_hl(hlgroup, what, mode)
  if not hlgroup or not what then
    return
  end
  local hexcol = synIDattr(hlgroup, what, mode)
  -- Without termguicolors hexcol returns `{ctermfg|ctermbg}` which is
  -- a simple number representing the term ANSI color (e.g. 1-15, etc)
  -- in which case we return the number as is so it can be passed onto
  -- fzf's "--color" flag, this shouldn't be an issue for `ansi_from_hl`
  -- as the function validates the a 6-digit hex number (#1422)
  if hexcol and not hexcol:match("^#") and not tonumber(hexcol) then
    -- try to acquire the color from the map
    -- some schemes don't capitalize first letter?
    local col = M.COLORMAP()[hexcol:sub(1, 1):upper() .. hexcol:sub(2)]
    if col then
      -- format as 6 digit hex for hex2rgb()
      hexcol = ("#%06x"):format(col)
    else
      -- some colorschemes set fg=fg/bg or bg=fg/bg which have no value
      -- in the colormap, in this case reset `hexcol` to prevent fzf to
      -- err with "invalid color specification: bg:bg" (#976)
      -- TODO: should we extract `fg|bg` from `Normal` hlgroup?
      hexcol = ""
    end
  end
  return hexcol
end

local function hex2rgb(hexcol)
  local r, g, b = hexcol:match("#(%x%x)(%x%x)(%x%x)")
  if not r or not g or not b then
    return
  end
  ---@diagnostic disable: param-type-mismatch
  r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
  return r, g, b
end

function M.ansi_from_rgb(rgb, s)
  local r, g, b = hex2rgb(rgb)
  if r and g and b then
    return string.format("[38;2;%d;%d;%dm%s%s", r, g, b, s, "[0m")
  elseif tonumber(rgb) then
    -- No termguicolors, use the number as is
    return string.format("[38;5;%dm%s%s", rgb, s, "[0m")
  end
  return s
end

function M.ansi_from_hl(hl, s)
  if not hl or #hl == 0 or vim.fn.hlexists(hl) ~= 1 then
    return s, nil
  end
  -- https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797#rgb-colors
  -- Set foreground color as RGB: 'ESC[38;2;{r};{g};{b}m'
  -- Set background color as RGB: 'ESC[48;2;{r};{g};{b}m'
  local what = {
    ["fg"] = { rgb = true, code = 38 },
    ["bg"] = { rgb = true, code = 48 },
    ["bold"] = { code = 1 },
    ["italic"] = { code = 3 },
    ["underline"] = { code = 4 },
    ["inverse"] = { code = 7 },
    ["reverse"] = { code = 7 },
    ["strikethrough"] = { code = 9 },
  }
  -- List of ansi sequences to apply
  local escseqs = {}
  for w, p in pairs(what) do
    if p.rgb then
      local hexcol = M.hexcol_from_hl(hl, w)
      local r, g, b = hex2rgb(hexcol)
      if r and g and b then
        table.insert(escseqs, string.format("[%d;2;%d;%d;%dm", p.code, r, g, b))
        -- elseif #hexcol>0 then
        --   print("unresolved", hl, w, hexcol, M.COLORMAP()[synIDattr(hl, w)])
      elseif tonumber(hexcol) then
        -- No termguicolors, use the number as is
        table.insert(escseqs, string.format("[%d;5;%dm", p.code, tonumber(hexcol)))
      end
    else
      local value = synIDattr(hl, w)
      if value and tonumber(value) == 1 then
        table.insert(escseqs, string.format("[%dm", p.code))
      end
    end
  end
  local escseq = #escseqs > 0 and table.concat(escseqs) or nil
  local escfn = function(str)
    if escseq then
      str = string.format("%s%s%s", escseq, str or "", M.ansi_escseq.clear)
    end
    return str
  end
  return escfn(s), escseq, escfn
end

function M.has_ansi_coloring(str)
  return str:match("%[[%d;]-m")
end

---@param str string
---@return string, integer
function M.strip_ansi_coloring(str)
  -- remove escape sequences of the following formats:
  -- 1. ^[[34m
  -- 2. ^[[0;34m
  -- 3. ^[[m
  -- NOTE: didn't work with grep's "^[[K"
  -- return str:gsub("%[[%d;]-m", "")
  -- https://stackoverflow.com/a/49209650/368691
  return str:gsub("[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]", "")
end

function M.ansi_escseq_len(str)
  local stripped = M.strip_ansi_coloring(str)
  return #str - #stripped
end
return M
