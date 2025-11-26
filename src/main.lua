local http = require("prelive.core.http")
local Server = http.Server
local api, fn = vim.api, vim.fn

vim.env.XDG_DATA_HOME = vim.fs.abspath("./deps/.data")
vim.env.XDG_CONFIG_HOME = vim.fs.abspath("./deps/.config")
---@diagnostic disable-next-line: param-type-mismatch
vim.opt.pp:append(vim.fs.joinpath(fn.stdpath("data"), "site"))
vim.pack.add({ { src = "https://github.com/tweekmonster/helpful.vim" } }, { confirm = false })
vim.cmd.runtime("plugin/helpful.vim")
-- vim.pack.update(nil, { force = true })
-- todo: handle termresponse
-- api.nvim_ui_send = function(c) io.stderr:write(c) end

require("vim._extui").enable({}) -- redir

local render_extwin = function(res, timeout)
  local buf = require("vim._extui.shared").bufs.cmd
  buf = buf ~= -1 and buf
    or vim.iter(api.nvim_list_bufs()):find(function(b)
      return vim.bo[b].filetype == "cmd"
    end)
  if not buf then
    res:write("No pager buffer!", nil, http.status.NOT_FOUND)
    return
  end
  vim.wait(timeout or 500, function()
    return #table.concat(api.nvim_buf_get_lines(buf, 0, -1, true), "\n") > 0
  end)
  local win = fn.bufwinid(buf)
  if win == -1 then
    res:write("Pager is not displayed!", nil, http.status.NOT_FOUND)
    return
  end
  local html = vim._with({ silent = true }, function()
    return require("tohtml").tohtml(win)
  end)
  res:write(table.concat(html, "\n"))
end

local excmd = function(cmd, opts)
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

local next_tag = function()
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

local server = Server:new("127.0.0.1", 8080, {
  tcp_max_backlog = 16,
  tcp_recv_buffer_size = 1024,
  keep_alive_timeout = 60 * 1000,
  max_body_size = 1024 * 1024 * 1,
  max_request_line_size = 1024 * 4,
  max_header_field_size = 1024 * 4,
  max_header_num = 100,
  max_chunk_ext_size = 1024 * 1,
})
server:use_logger("/")
server:get("/hello", function(_, res)
  res:write("Hello, World!")
end)

server:get("/echo", function(req, res)
  res:write(vim.inspect(req))
end)

server:get("/ex", function(req, res)
  local cmd = vim.uri_decode(req.query)
  res:write(excmd(cmd, { output = true }))
end)

server:get("/ex2", function(req, res)
  excmd(vim.uri_decode(req.query), {})
  render_extwin(res)
end)

server:get("/doc", function(req, res)
  local q = req.query
  if #q == 0 then
    res:write("No query!")
    return
  end
  if not pcall(vim.cmd.help, q) then
    res:write("Not found!", nil, http.status.NOT_FOUND)
    return
  end
  local tag = vim.ui._get_urls()[1]
  local url = "https://neovim.io/doc/user/helptag.html?tag=" .. vim.uri_encode(tag)
  local range = { fn.line("."), math.max(next_tag() or 0, fn.line(".") + 10) }
  local html = require("tohtml").tohtml(0, { number_lines = false, range = range })
  if html[1] then
    -- local c = ('<a href="%s">%s</a>'):format(redir_url, redir_url)
    res:write(table.concat(html, "\n"))
    return
  end
  res.headers:set("Location", url)
  res:write_header(http.status.FOUND)
end)

server:get("/version", function(req, res)
  vim.cmd.Help(vim.uri_decode(req.query))
  print("") -- flush output
  -- api.nvim_feedkeys("g<", "n", false)
  render_extwin(res)
end)

-- vim.o.verbose = 0
server:get("/", function(_, res)
  local info = [[
    <h1>Nvim Doc API</h1>
    <ul>
      <li><b>/exraw?query</b> - Execute ex command and return raw output</li>
      <li><b>/ex?query</b> - Execute ex command and return HTML output</li>
      <li><b>/doc?query</b> - Get Neovim help documentation</li>
      <li><b>/version?query</b> - Get Neovim help version info</li>
      <li><b>/hello</b> - Simple Hello World response</li>
      <li><b>/echo</b> - Echo request info</li>
    </ul>
    <p>Examples:</p>
    <ul>
      <li><a href="/ex?map"><code>/ex?map</code></a></li>
      <li><a href="/ex2?hi"><code>/ex2?hi</code></a></li>
      <li><a href="/doc?wildtrigger"><code>/doc?wildtrigger</code></a></li>
      <li><a href="/version?treesitter"><code>/version?treesitter</code></a></li>
      <li><a href="/hello"><code>/hello</code></a></li>
      <li><a href="/echo"><code>/echo</code></a></li>
    </ul>
  ]]
  res:write(info)
end)

server:start_serve()

if not ... then
  return
end

while true do
  vim.wait(0)
end
