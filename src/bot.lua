local utils = require("utils")
local fn = vim.fn

utils.init_nvim()
local tdbot = require("tdbot")
local bot = tdbot.getCallback()
local botid = nil

local function parseTextMD(text)
  print("DEBUGPRINT[611]: bot.lua:53: content=" .. vim.inspect(text))
  local obj
  bot(
    { ["@type"] = "parseTextEntities", text = text, parse_mode = { ["@type"] = "textParseModeMarkdown" } },
    function(_, res)
      obj = res
    end
  )
  return obj
end

local help = function(q)
  if not q or #q == 0 then
    return "No query!"
  end
  if not pcall(vim.cmd.help, q) then
    return "Not found!"
  end
  local tag = vim.ui._get_urls()[1]
  local url = "https://neovim.io/doc/user/helptag.html?tag=" .. vim.uri_encode(tag)

  local start_line, end_line = fn.line("."), math.max(utils.next_tag() or 0, fn.line(".") + 10)
  -- do
  --   local html = require("tohtml").tohtml(0, { number_lines = false, range = { start_line, end_line } })
  --   return table.concat(html, "\n") .. "\n" .. url
  -- end

  -- do -- https://github.com/Alir3z4/html2text
  --   local html = require("tohtml").tohtml(0, { number_lines = false, range = { start_line, end_line } })
  --   local obj = vim.system({ "html2text" }, { stdin = table.concat(html, "\n") }):wait()
  --   return vim.trim(obj.stdout or "") .. "\n" .. url
  -- end
  --
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line - 1, false)
  local md = require("tomd").convert(lines)
  local ret = table.concat(md, "\n") .. "\n" .. url
  vim.print(ret)
  return table.concat(md, "\n") .. "\n" .. url
end

-- local tdbot_function = tdbot.getCallback()
local function tdbot_update_callback(data)
  if not botid then
    bot({ _ = "getMe" }, vim.print)
  end
  data = utils.new2old(data)
  if data._ ~= "updateNewMessage" then
    return
  end
  local msg = data.message
  if msg.content._ ~= "messageText" then
    return
  end
  -- if msg.content.text.text == "ping" then
  local q = msg.content.text.text:match(":h (.+)")
  local content = help(q)
  -- https://core.telegram.org/api/entities
  -- https://github.com/tdlib/td/blob/a3a784e5775b2e33b2035bae773d97ac527466c6/test/message_entities.cpp#L1318
  assert(bot({
    _ = "sendMessage",
    chat_id = msg.chat_id,
    reply_to_message_id = msg.id,
    disable_notification = false,
    from_background = true,
    reply_markup = nil,
    input_message_content = {
      _ = "inputMessageText",
      text = parseTextMD(content),
      disable_web_page_preview = true,
      clear_draft = false,
    },
  }, vim.print, nil))
end
tdbot.run(tdbot_update_callback)
