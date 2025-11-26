#!/usr/bin/env -S nvim --clean -l
-- #!/usr/bin/env -S nvim --clean --headless -ni NONE -u

if #vim.v.servername > 0 then
  pcall(vim.fn.serverstop, vim.v.servername)
end
vim.env.NVIM = nil
local ok, err = xpcall(function()
  assert(loadfile(_G.arg[1] or vim.v.argv[#vim.v.argv]))(_G.arg[1] and true or false)
end, debug.traceback)
if not ok then
  print(err)
  vim.cmd.cq(1)
end
