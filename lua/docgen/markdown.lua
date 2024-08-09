--- @class (private) docgen.MDNode__
--- @field [integer] docgen.MDNode__
--- @field type string
--- @field text? string

local INDENTATION = 4
local TEXT_WIDTH = 78

local NBSP = string.char(160)

local M = {}

--- @param txt string
--- @param srow integer
--- @param scol integer
--- @param erow? integer
--- @param ecol? integer
--- @return string
local function slice_text(txt, srow, scol, erow, ecol)
  local lines = vim.split(txt, "\n")

  if srow == erow then return lines[srow + 1]:sub(scol + 1, ecol) end

  if erow then
    -- Trim the end
    for _ = erow + 2, #lines do
      table.remove(lines, #lines)
    end
  end

  -- Trim the start
  for _ = 1, srow do
    table.remove(lines, 1)
  end

  lines[1] = lines[1]:sub(scol + 1)
  lines[#lines] = lines[#lines]:sub(1, ecol)

  return table.concat(lines, "\n")
end

--- @param text string
--- @return docgen.MDNode__
local function parse_md_inline(text)
  local parser = vim.treesitter.languagetree.new(text, "markdown_inline")
  local root = parser:parse(true)[1]:root()

  --- @param node TSNode
  --- @return docgen.MDNode__?
  local function extract(node)
    local ntype = node:type()

    if ntype:match("^%p$") then return end

    --- @type table<any,any>
    local ret = { type = ntype }
    ret.text = vim.treesitter.get_node_text(node, text)

    local row, col = 0, 0

    for child, child_field in node:iter_children() do
      local e = extract(child)
      if e and ntype == "inline" then
        local srow, scol = child:start()
        if (srow == row and scol > col) or srow > row then
          local t = slice_text(ret.text, row, col, srow, scol)
          if t and t ~= "" then table.insert(ret, { type = "text", j = true, text = t }) end
        end
        row, col = child:end_()
      end

      if child_field then
        ret[child_field] = e
      else
        table.insert(ret, e)
      end
    end

    if ntype == "inline" and (row > 0 or col > 0) then
      local t = slice_text(ret.text, row, col)
      if t and t ~= "" then table.insert(ret, { type = "text", text = t }) end
    end

    return ret
  end

  return extract(root) or {}
end

--- @param text string
--- @return docgen.MDNode__
local function parse_md(text)
  local parser = vim.treesitter.languagetree.new(text, "markdown", {
    injections = { markdown = "" },
  })

  local root = parser:parse(true)[1]:root()

  local EXCLUDE_TEXT_TYPE = {
    list = true,
    list_item = true,
    section = true,
    document = true,
    fenced_code_block = true,
    fenced_code_block_delimiter = true,
  }

  --- @param node TSNode
  --- @return docgen.MDNode__?
  local function extract(node)
    local ntype = node:type()

    if ntype:match("^%p$") then return end

    --- @type table<any,any>
    local ret = { type = ntype }

    if not EXCLUDE_TEXT_TYPE[ntype] then ret.text = vim.treesitter.get_node_text(node, text) end

    if ntype == "inline" then ret = parse_md_inline(ret.text) end

    for child, child_field in node:iter_children() do
      local e = extract(child)
      if child_field then
        ret[child_field] = e
      else
        table.insert(ret, e)
      end
    end

    return ret
  end

  return extract(root) or {}
end

--- @param x string
--- @param start_indent integer
--- @param indent integer
--- @return string
local function text_wrap(x, start_indent, indent)
  local words = vim.split(vim.trim(x), "%s+")
  local parts = { string.rep(" ", start_indent) } --- @type string[]
  local count = indent

  for i, w in ipairs(words) do
    if count > indent and count + #w > TEXT_WIDTH - 1 then
      parts[#parts + 1] = "\n"
      parts[#parts + 1] = string.rep(" ", indent)
      count = indent
    elseif i ~= 1 then
      parts[#parts + 1] = " "
      count = count + 1
    end
    count = count + #w
    parts[#parts + 1] = w
  end

  return (table.concat(parts):gsub("%s+\n", "\n"):gsub("\n+$", ""))
end

---@param node docgen.MDNode__
---@param start_indent integer
---@param next_indent integer
---@param list_depth integer
---@param next_node docgen.MDNode__?
---@return string[]
local function render_paragraph(node, start_indent, next_indent, list_depth, next_node)
  local res = {}
  for i, child in ipairs(node) do
    local paragraphs =
      table.concat(M.render_md(child, node[i + 1], start_indent, next_indent, list_depth))
    for para_line in vim.gsplit(paragraphs, "\n") do
      table.insert(res, text_wrap(para_line, start_indent, next_indent))
      table.insert(res, "\n")
    end
  end
  if next_node and next_node.type == "paragraph" then table.insert(res, "\n") end
  return res
end

---@param node docgen.MDNode__
---@param start_indent integer
---@param next_indent integer
---@param list_depth integer
---@return string[]
local function render_fenced_code_block(node, start_indent, next_indent, list_depth)
  local res = {}
  table.insert(res, ">")
  for _, child in ipairs(node) do
    if child.type == "info_string" then
      table.insert(res, child.text)
      break
    end
  end
  table.insert(res, "\n")
  for i, child in ipairs(node) do
    if child.type ~= "info_string" then
      table.insert(res, M.render_md(child, node[i + 1], start_indent, next_indent, list_depth))
    end
  end
  table.insert(res, "<\n")
  return res
end

---@param node docgen.MDNode__
---@param start_indent integer
---@param next_indent integer
---@return string[]
local function render_code_fence_content(node, start_indent, next_indent)
  local res = {}
  local lines = vim.split(node.text:gsub("\n%s*$", ""), "\n")

  local cindent = start_indent == 0 and INDENTATION or next_indent
  -- if list_depth > 0 then
  --   -- The tree-sitter markdown parser doesn't parse the code blocks indents
  --   -- correctly in lists. Fudge it!
  --   lines[1] = "    " .. lines[1] -- ¯\_(ツ)_/¯
  --   cindent = next_indent - list_depth
  --   local _, initial_indent = lines[1]:find("^%s*")
  --   initial_indent = initial_indent + cindent
  --   if initial_indent < next_indent then cindent = next_indent - INDENTATION end
  -- end

  local tab = string.rep(" ", cindent)
  for _, l in ipairs(lines) do
    if #l > 0 then
      table.insert(res, tab)
      table.insert(res, l)
    end
    table.insert(res, "\n")
  end
  return res
end

---@param node docgen.MDNode__
---@param start_indent integer
---@return string[]
local function render_pre_block(node, start_indent)
  local res = {}
  local text = node.text:gsub("^<pre>\n?", "")
  text = text:gsub("</pre>%s*$", "")
  local tab = string.rep(" ", start_indent)
  for line in vim.gsplit(text, "\n") do
    table.insert(res, string.format("%s%s\n", tab, line))
  end
  return res
end

---@alias docgen.MDNode.List.kind "ul" | "ol"

---@type table<string, docgen.MDNode.List.kind>
local LIST_MARKERS = {
  list_marker_minus = "ul",
  list_marker_plus = "ul",
  list_marker_star = "ul",
  list_marker_dot = "ol",
}

-- ---@class (private) docgen.MDNode.List : docgen.MDNode
-- ---@field kind 'ul' | 'ol'
-- ---@field tight boolean
-- ---@field start integer?
-- ---@field items docgen.MDNode[]
local List = {}
List.__index = List

---@param list docgen.MDNode__
---@return docgen.MDNode.List
function List:new(list)
  local res = { tight = true }

  local got_kind = false
  local items = {}

  for _, list_items in ipairs(list) do
    list_items = vim
      .iter(ipairs(list_items))
      :filter(function(_, node)
        if node.type == "block_continuation" then
          res.tight = false
          return false
        elseif LIST_MARKERS[node.type] ~= nil then
          if not got_kind then
            res.kind = LIST_MARKERS[node.type]
            res.start = tonumber(node.text:match("%d+"))
            got_kind = true
          end
          return false
        end
        return true
      end)
      :map(function(_, node)
        return node
      end)
      :totable()

    table.insert(items, list_items)
  end

  res.items = items
  return res
end

---@param ul_list docgen.MDNode.List
---@param start_indent integer
---@param next_indent integer
---@param list_depth integer
---@param list_marker_size integer?
---@return string[]
local function render_ul(ul_list, start_indent, next_indent, list_depth, list_marker_size)
  list_marker_size = list_marker_size or 2 -- ie `• `
  -- local sep = ul_list.tight and "" or "\n"
  local sep = ul_list.tight and "\n" or "\n\n"
  local res = {}

  for _, list_item in ipairs(ul_list.items) do
    local marker_ws = string.rep(" ", start_indent)
    local marker = string.format("%s•%s", marker_ws, string.rep(" ", list_marker_size - 1))
    local item_parts = {}
    for i, item in ipairs(list_item) do
      local child_part = M.render_md(
        item,
        ul_list[i + 1],
        next_indent + list_marker_size,
        next_indent + list_marker_size,
        list_depth + 1,
        list_marker_size
      )
      vim.list_extend(item_parts, child_part)
      table.insert(item_parts, "\n")
    end

    local item_text = table.concat(item_parts):gsub("^ *", ""):gsub("[ \n]+$", "")
    table.insert(res, string.format("%s%s%s", marker, item_text, sep))
    start_indent = next_indent
  end
  return res
end

---@param node docgen.MDNode__
---@param next_node docgen.MDNode__?
---@param start_indent integer
---@param next_indent integer
---@param list_depth integer
---@param list_marker_size integer?
---@return string[]
function M.render_md(node, next_node, start_indent, next_indent, list_depth, list_marker_size)
  local parts = {} --- @type string[]

  -- For debugging
  local add_tag = false
  -- local add_tag = true

  local ntype = node.type

  if add_tag then parts[#parts + 1] = "<" .. ntype .. ">" end

  if ntype == "text" then
    parts[#parts + 1] = node.text
  elseif ntype == "html_tag" then
    if node.text == "<br>" then
      parts[#parts + 1] = "\n"
    else
      error("html_tag: " .. node.text)
    end
  elseif ntype == "inline_link" then
    vim.list_extend(parts, { "*", node[1].text, "*" })
  elseif ntype == "shortcut_link" then
    if node[1].text:find("^<.*>$") then
      parts[#parts + 1] = node[1].text
    else
      vim.list_extend(parts, { "|", node[1].text, "|" })
    end
  elseif ntype == "backslash_escape" then
    parts[#parts + 1] = node.text
  elseif ntype == "emphasis" then
    parts[#parts + 1] = node.text:sub(2, -2)
  elseif ntype == "code_span" then
    parts[#parts + 1] = table.concat({ "`", node.text:sub(2, -2):gsub(" ", NBSP), "`" })
  elseif ntype == "inline" then
    if #node == 0 then
      local text = assert(node.text)
      parts[#parts + 1] = text_wrap(text, start_indent, next_indent)
    else
      for i, child in ipairs(node) do
        vim.list_extend(
          parts,
          M.render_md(child, node[i + 1], next_indent, next_indent, list_depth)
        )
      end
    end
  elseif ntype == "paragraph" then
    vim.list_extend(parts, render_paragraph(node, start_indent, next_indent, list_depth, next_node))
  elseif ntype == "code_fence_content" then
    vim.list_extend(parts, render_code_fence_content(node, start_indent, next_indent))
  elseif ntype == "fenced_code_block" then
    vim.list_extend(parts, render_fenced_code_block(node, start_indent, next_indent, list_depth))
  elseif ntype == "html_block" then
    assert(node.text:find("^<pre>"), "Only support <pre> html blocks, got: ", node.text)
    vim.list_extend(parts, render_pre_block(node, start_indent))
  elseif ntype == "list_marker_dot" then
    parts[#parts + 1] = node.text
  elseif contains(ntype, { "list_marker_minus", "list_marker_star" }) then
    parts[#parts + 1] = "• "
  elseif ntype == "list_item" then
    parts[#parts + 1] = string.rep(" ", list_depth <= 3 and start_indent or next_indent)
    local offset = node[1].type == "list_marker_dot" and 3 or 2
    -- TODO: need to account for different list marker sizes
    -- see my previous `list_marker_size` stuff
    for i, child in ipairs(node) do
      local sindent = i <= 2 and 0 or (next_indent + offset)
      vim.list_extend(
        parts,
        M.render_md(child, node[i + 1], sindent, next_indent + offset, list_depth + 1)
      )
    end
  else
    if node.text then error(string.format("cannot render:\n%s", vim.inspect(node))) end
    for i, child in ipairs(node) do
      local start_indent0 = i == 1 and start_indent or next_indent
      local next = node[i + 1]
      local last_node = i == #node
      vim.list_extend(parts, M.render_md(child, next, start_indent0, next_indent, list_depth + 1))

      -- if ntype ~= "list" and not last_node then
      --   if next_node.type ~= "list" then parts[#parts + 1] = "\n" end
      -- end

      -- if not last_node then
      --   if ntype ~= "list" then
      --     if next_node.type ~= "list" then parts[#parts + 1] = "\n" end
      --   elseif child.type == "list" then
      --     if next_node.type == "list" then
      --       if level == 0 then parts[#parts + 1] = "\n" end
      --     else
      --       parts[#parts + 1] = "\n"
      --     end
      --   end
      -- end
    end
  end

  if add_tag then parts[#parts + 1] = "</" .. ntype .. ">" end

  return parts
end

local function align_tags()
  --- @param line string
  --- @return string
  return function(line)
    local tag_pat = "%s*(%*.+%*)%s*$"
    local tags = {}
    for m in line:gmatch(tag_pat) do
      table.insert(tags, m)
    end

    if #tags > 0 then
      line = line:gsub(tag_pat, "")
      local tags_str = " " .. table.concat(tags, " ")
      --- @type integer
      local conceal_offset = select(2, tags_str:gsub("%*", "")) - 2
      local pad = string.rep(" ", TEXT_WIDTH - #line - #tags_str + conceal_offset)
      return line .. pad .. tags_str
    end

    return line
  end
end

--- @param text string
--- @param start_indent integer
--- @param indent integer
--- @return string
function M.md_to_vimdoc(text, start_indent, indent)
  -- Add an extra newline so the parser can properly capture ending ```
  local parsed = parse_md(text .. "\n")
  local ret = M.render_md(parsed, nil, start_indent, indent, 0)

  local lines = vim.split(table.concat(ret):gsub(NBSP, " "), "\n")

  lines = vim.tbl_map(align_tags(), lines)

  local s = table.concat(lines, "\n")
  s = (s:gsub("[ \n]+$", ""))

  -- Reduce whitespace in code-blocks
  -- s = s:gsub("\n+%s*>([a-z]+)\n", " >%1\n")
  -- s = s:gsub("\n+%s*>\n?\n", " >\n")

  return s
end

local s = [[
- item 1

- item 2
]]

vim.print(parse_md(s))

local f = {
  {
    {
      text = "- ",
      type = "list_marker_minus",
    },
    {
      {
        text = "item 1",
        type = "inline",
      },
      {
        text = "",
        type = "block_continuation",
      },
      text = "item 1\n",
      type = "paragraph",
    },
    type = "list_item",
  },
  {
    {
      text = "- ",
      type = "list_marker_minus",
    },
    {
      {
        text = "item 2",
        type = "inline",
      },
      text = "item 2\n",
      type = "paragraph",
    },
    type = "list_item",
  },
  type = "list",
}

return M
