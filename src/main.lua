local http = require("prelive.core.http")
local utils = require("utils")
local Server = http.Server
local _, fn = vim.api, vim.fn

utils.init_nvim()
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
server:use("/", function(_, res)
  res.headers:set("Connection", "close")
end)
server:get("/hello", function(_, res)
  res:write("Hello, World!")
end)

server:get("/echo", function(req, res)
  res:write(vim.inspect(req))
end)

server:get("/ex", function(req, res)
  local cmd = vim.uri_decode(req.query)
  res:write(utils.excmd(cmd, { output = true }))
end)

server:get("/ex2", function(req, res)
  utils.excmd(vim.uri_decode(req.query), {})
  local ok, r = utils.render_extwin()
  res:write(r, nil, not ok and http.status.NOT_FOUND or nil)
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
  local range = { fn.line("."), math.max(utils.next_tag() or 0, fn.line(".") + 10) }
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
  local ok, r = utils.render_extwin()
  res:write(r, nil, not ok and http.status.NOT_FOUND or nil)
end)

-- vim.o.verbose = 0
server:get("/", function(_, res)
  local info = [[
    <h1>Nvim Doc API</h1>
    <ul>
      <li><b>/ex?query</b> - Execute ex command and return raw output</li>
      <li><b>/ex2?query</b> - Execute ex command and return HTML output</li>
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
