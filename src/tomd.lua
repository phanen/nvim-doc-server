local api, ts = vim.api, vim.treesitter
local M = {}

--- Get a reusable buffer for parsing
---@return integer buf
local function get_buf()
  if M._buf and api.nvim_buf_is_valid(M._buf) then
    return M._buf
  end
  return api.nvim_create_buf(false, true)
end

--- Recursively process a Treesitter node and convert to Markdown
---@param node TSNode
---@param buf integer
---@param out string[]
local function process_node(node, buf, out)
  local ty = node:type()
  if ty == "tag" then
    out[#out + 1] = "## " .. ts.get_node_text(node, buf)
  elseif ty == "taglink" then
    local txt = ts.get_node_text(node, buf)
    txt = (vim.trim(txt):gsub("^|", ""):gsub("|$", ""))
    local url = "https://neovim.io/doc/user/helptag.html?tag=" .. vim.uri_encode(txt)
    out[#out + 1] = "[" .. txt .. "](" .. url .. ")"
  elseif ty == "optionlink" then
    local txt = ts.get_node_text(node, buf)
    out[#out + 1] = "`" .. txt .. "`"
  elseif ty == "keycode" then
    local txt = ts.get_node_text(node, buf)
    out[#out + 1] = "`" .. txt .. "`"
  elseif ty == "argument" then
    out[#out + 1] = "*" .. ts.get_node_text(node, buf) .. "*"
  elseif ty == "codeblock" then
    local lang = ""
    local code = {}
    for child in node:iter_children() do
      if child:type() == "language" then
        lang = ts.get_node_text(child, buf)
      elseif child:type() == "code" then
        for line_node in child:iter_children() do
          code[#code + 1] = ts.get_node_text(line_node, buf)
        end
      end
    end
    out[#out + 1] = "```" .. lang .. "\n" .. table.concat(code, "\n") .. "\n```"
  elseif ty == "line_li" then
    local line = {}
    for child in node:iter_children() do
      process_node(child, buf, line)
    end
    out[#out + 1] = "- " .. table.concat(line, " ")
  elseif ty == "column_heading" then
    local heading = {}
    for child in node:iter_children() do
      if child:type() == "heading" then
        heading[#heading + 1] = "**" .. ts.get_node_text(child, buf) .. "**"
      end
    end
    out[#out + 1] = table.concat(heading, " ")
  elseif ty == "word" then
    out[#out + 1] = ts.get_node_text(node, buf)
  elseif ty == "line" then
    local line = {}
    for child in node:iter_children() do
      process_node(child, buf, line)
    end
    out[#out + 1] = table.concat(line, " ")
  else
    for child in node:iter_children() do
      process_node(child, buf, out)
    end
  end
end

--- Convert Vimdoc lines to Markdown lines
---@param lines string[]
---@return string[] markdown_lines
M.convert = function(lines)
  local buf = get_buf()
  api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  local parser = assert(ts.get_parser(buf, "vimdoc"))
  local root = assert(parser:parse())[1]:root()

  local out = {}
  process_node(root, buf, out)
  return out
end

return M
