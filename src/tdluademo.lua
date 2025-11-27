local tdlua = require("td.tdlua")
local client = tdlua()
vim.print(client:execute({
  ["@type"] = "getTextEntities",
  text = "@telegram /test_command https://telegram.org telegram.me",
  ["@extra"] = { "5", 7.0 },
}))

vim.print(client:execute({
  ["@type"] = "sendMessage",
  ["@extra"] = "asd",
}))
