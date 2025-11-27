--[[
    tdbot / tdcli retrocompatibility script
    put this file into your bot folder and append in the end of the main bot file
    require "tdbot"

    examle:
    file bot.lua:
        function tdbot_update_callback(data)
            ...
        end
    become
        local tdbot = require "tdbot"
        local tdbot_function = tdbot.getCallback()
        local function tdbot_update_callback(data)
            ...
        end
        tdbot.run(tdbot_update_callback)
    the script will start a loop, it will handle everything (if it work) throw tdlua
--]]
local tdlua = require("td.tdlua")

local env = assert(loadfile("./.env"))()
local api_id = os.getenv("TG_APP_ID") or env.api_id
api_id = tonumber(api_id)
local api_hash = os.getenv("TG_APP_HASH") or env.api_hash
if not api_id then
  print("Enter app id (take it from https://my.telegram.org/apps)")
  api_id = io.read()
end

if not api_hash then
  print("Enter app hash (take it from https://my.telegram.org/apps)")
  api_hash = io.read()
end

-- tdlua.setLogLevel(5)
-- tdlua.setLogPath("tdlua.log")
---@type td.client
local client = tdlua()
-- client = setmetatable({}, { __index = function() end })
client:send({ ["@type"] = "getAuthorizationState" })
local ready = false

local function authstate(state)
  if state == "authorizationStateClosed" then
    return true
  elseif state == "authorizationStateWaitTdlibParameters" then
    -- https://github.com/tdlib/td/issues/2211#issuecomment-1327625869
    client:send({
      ["@type"] = "setTdlibParameters",
      use_message_database = true,
      api_id = api_id,
      api_hash = api_hash,
      system_language_code = "en",
      device_model = "tdlua",
      system_version = "unk",
      application_version = "0.1",
      enable_storage_optimizer = true,
      use_pfs = true,
      database_directory = "./",
    })
  elseif state == "authorizationStateWaitEncryptionKey" then
    local dbpassword = ""
    client:send({
      ["@type"] = "checkDatabaseEncryptionKey",
      encryption_key = dbpassword,
    })
  elseif state == "authorizationStateWaitPhoneNumber" then
    -- print("Do you want to login as a Bot or as an User? [U/b]")
    local token = env.token
    client:send({ ["@type"] = "checkAuthenticationBotToken", token = token })
    -- local phone = io.read()
    -- client:send({
    --   ["@type"] = "setAuthenticationPhoneNumber",
    --   phone_number = phone,
    -- })
  elseif state == "authorizationStateWaitCode" then
    print("Enter code: ")
    local code = io.read()
    client:send({
      ["@type"] = "checkAuthenticationCode",
      code = code,
    })
  elseif state == "authorizationStateWaitPassword" then
    print("Enter password: ")
    local password = io.read()
    client:send({
      ["@type"] = "checkAuthenticationPassword",
      password = password,
    })
  elseif state == "authorizationStateReady" then
    ready = true
    print("ready")
  end
  return false
end

local function err(e)
  return e .. " " .. debug.traceback()
end

local function _call(params, cb, extra)
  local res = client:execute(params)
  cb = cb or vim.print
  if type(cb) == "function" then
    if type(res) == "table" then
      local ok, rres = xpcall(cb, err, extra, res)
      if not ok then
        print("Result cb failed", rres, debug.traceback())
        --vim.print(res)
        return false
      end
      return true
    end
  end
end

local function getCallback()
  return _call
end

local handler = function(cb, res)
  if not res then
    return
  end
  if type(res) ~= "table" then
    return
  end
  if not ready or res["@type"] == "updateAuthorizationState" then
    local r = res.authorization_state and res.authorization_state or res or {}
    local mustclose = authstate(r["@type"] or r["_"])
    if mustclose then
      return true
    end
    return
  end
  if res["@type"] == "connectionStateUpdating" then
    return
  end
  local ok, rres = xpcall(cb, err, res)
  if not ok then
    print("Update cb failed", rres)
    vim.print(res)
  end
end

local function run(cb)
  cb = cb or vim.print
  while true do
    local res = client:receive(1)
    if handler(cb, res) then
      break
    end
    -- signal handler is ignored when in dead loop...
    local nlua_pid = vim.api.nvim_get_proc(vim.uv.os_getpid()).ppid
    local lx_pid = vim.api.nvim_get_proc(nlua_pid).ppid
    if not vim.uv.os_getpriority(lx_pid) then
      break
    end
  end
  client = nil
end

return {
  run = run,
  getCallback = getCallback,
}
