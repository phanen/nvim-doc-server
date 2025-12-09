local api, fn = vim.api, vim.fn

local M = {}

M.init_nvim = function()
  vim.env.XDG_DATA_HOME = vim.fs.abspath("./deps/.data")
  vim.env.XDG_CONFIG_HOME = vim.fs.abspath("./deps/.config")
  ---@diagnostic disable-next-line: param-type-mismatch
  vim.opt.pp:append(vim.fs.joinpath(fn.stdpath("data"), "site"))
  vim.pack.add({
    { src = "https://github.com/tweekmonster/helpful.vim" },
    { src = "https://github.com/folke/tokyonight.nvim" },
  }, { confirm = false })
  vim.cmd.runtime("plugin/helpful.vim")
  -- vim.pack.update(nil, { force = true })
  -- todo: handle termresponse
  -- api.nvim_ui_send = function(c) io.stderr:write(c) end
  require("vim._extui").enable({}) -- redir
  local ns = api.nvim_create_namespace("nvim-doc-server")
  local ansi = require("ansi")
  -- "https://github.com/neovim/neovim/pull/36884"
  if true then
    return
  end
  vim.ui_attach(
    ns,
    { ext_messages = true },
    vim.schedule_wrap(function(event, kind, ...)
      if event ~= "msg_show" then
        return
      end
      local args = { ... }
      local chunks = args[1]
      -- pretty print for list_cmd style payload
      if type(chunks) == "table" and type(chunks[1]) == "table" then
        local colored = {}
        for _, chunk in ipairs(chunks) do
          if type(chunk) == "table" then
            local text = chunk[2]
            local hl_id = chunk[3]
            local colored_text = text
            if hl_id and type(hl_id) == "number" then
              local hl_name = fn.synIDattr(hl_id, "name")
              if hl_name and #hl_name > 0 then
                colored_text = ansi.ansi_from_hl(hl_name, text)
              end
            end
            table.insert(colored, colored_text)
          end
        end
        -- io.stderr:write(kind .. ": ")
        io.stderr:write(table.concat(colored, ""))
        io.stderr:write("\n")
      else
        io.stderr:write(kind .. ": ")
        -- io.stderr:write(payload[1])
        -- io.stderr:write(vim.inspect(args) .. "\n")
      end
    end)
  )
end

M.render_extwin = function(timeout)
  local buf = require("vim._extui.shared").bufs.cmd
  buf = buf ~= -1 and buf
    or vim.iter(api.nvim_list_bufs()):find(function(b)
      return vim.bo[b].filetype == "cmd"
    end)
  if not buf then
    return false, "No pager buffer!"
  end
  vim.wait(timeout or 500, function()
    return #table.concat(api.nvim_buf_get_lines(buf, 0, -1, true), "\n") > 0
  end)
  local win = fn.bufwinid(buf)
  if win == -1 then
    return false, "Pager is not displayed!"
  end
  local html = vim._with({ silent = true }, function()
    return require("tohtml").tohtml(win)
  end)
  return true, table.concat(html, "\n")
end

M.excmd = function(cmd, opts)
  local ok, res = pcall(api.nvim_parse_cmd, cmd, {})
  if not ok then
    return res
  end
  -- :sandbox?
  if res.cmd == "!" then
    return "Dangerous!\n" .. vim.inspect(res)
  end
  ok, res = pcall(api.nvim_exec2, cmd, opts)
  return not ok and res or (res or {}).output or ""
end

M.next_tag = function()
  local ts = vim.treesitter
  local buf = api.nvim_get_current_buf()
  local parser = assert(ts.get_parser(buf, "vimdoc"))
  local root = assert(parser:parse())[1]:root()
  local query = ts.query.parse("vimdoc", [[(tag) @tag]])
  local tags = {}
  for _, match, _ in query:iter_matches(root, buf, 0, -1) do
    for _, nodes in pairs(match) do
      for _, node in ipairs(nodes) do
        local start_row, start_col = node:range()
        tags[#tags + 1] = { row = start_row, col = start_col }
      end
    end
  end

  local cursor = api.nvim_win_get_cursor(0)
  local cur_row, cur_col = cursor[1] - 1, cursor[2]

  for _, tag in ipairs(tags) do
    if tag.row > cur_row or (tag.row == cur_row and tag.col > cur_col) then
      if tag.row ~= cur_row then -- ignore tags at the same line
        -- return tag.row + 1, tag.col
        return tag.row, tag.col
      end
    end
  end

  print("No next tag found")
end

M.new2old = function(obj)
  for k, v in pairs(obj) do
    if type(v) == "table" then
      M.new2old(v)
    end
    if k == "@type" and not obj._ then
      obj._ = v
      obj["@type"] = nil
    end
  end
  return obj
end

return M
