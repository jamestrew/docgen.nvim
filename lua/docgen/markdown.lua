local M = {}

--- @class docgen.MDNode.Inline
--- @field [integer] docgen.MDNode.Inline
--- @field type string
--- @field text? string

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
--- @return docgen.MDNode.Inline
local function parse_md_inline(text)
  local parser = vim.treesitter.languagetree.new(text, "markdown_inline")
  local root = parser:parse(true)[1]:root()

  --- @param node TSNode
  --- @return docgen.MDNode.Inline?
  local function extract(node)
    local ntype = node:type()

    if ntype:match("^%p$") or ntype == "code_span_delimiter" then return end

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

---@class docgen.MDNode.Paragraph
---@field kind 'paragraph'
---@field inner string|docgen.MDNode.Inline[]

---@param node TSNode
---@param text string
---@return docgen.MDNode.Paragraph
local function parse_paragraph(node, text)
  local res = { kind = "paragraph" }
  local inline = parse_md_inline(vim.treesitter.get_node_text(node:child(0), text))
  if #inline == 0 then
    res.inner = vim.trim(inline.text)
  else
    res.inner = inline
  end
  return res
end

---@class docgen.MDNode.Html
---@field kind 'pre'|'br'
---@field lines string[]

---@param node TSNode
---@param text string
---@return docgen.MDNode.Html
local function parse_html_block(node, text)
  text = vim.treesitter.get_node_text(node, text)
  if text:find("^ *<br>") then return { kind = "br", lines = { "" } } end

  assert(
    text:find("^ *<pre>"),
    string.format("Only support <br> or <pre> html blocks, got: %s", text)
  )

  text = text:gsub("\n$", "")
  text = text:gsub("^ *<pre>\n?", ""):gsub("\n?</pre>$", "")
  return {
    kind = "pre",
    lines = vim.split(text, "\n"),
  }
end

---@param lines string[]
---@return string[]
local function dedent_lines(lines)
  local min_indent = math.huge
  for _, line in ipairs(lines) do
    if line ~= "" then
      local indent = line:match("^%s*")
      min_indent = math.min(min_indent, #indent)
    end
  end

  for i, line in ipairs(lines) do
    lines[i] = line:sub(min_indent + 1)
  end
  return lines
end

---@class docgen.MDNode.Code
---@field kind 'code'
---@field lang string
---@field lines string[]

---@param node TSNode
---@param text string
---@return docgen.MDNode.Code
local function parse_code_block(node, text)
  local res = { kind = "code" }
  for child, _ in node:iter_children() do
    local ntype = child:type()
    if ntype == "info_string" then
      res.lang = vim.treesitter.get_node_text(child, text)
    elseif ntype == "code_fence_content" then
      local content = vim.treesitter.get_node_text(child, text):gsub("[ \n]+$", "")
      res.lines = dedent_lines(vim.split(content, "\n"))
    end
  end

  return res
end

---@class docgen.MDNode.List
---@field kind 'ol' | 'ul'
---@field tight boolean
---@field start? integer
---@field items table[]
---@field marker_size integer

local LIST_MARKERS = {
  list_marker_minus = "ul",
  list_marker_plus = "ul",
  list_marker_star = "ul",
  list_marker_dot = "ol",
}

---@param node TSNode
---@param text string
---@return docgen.MDNode.List
local function parse_list(node, text)
  local res = { tight = true, items = {} }
  local got_kind = false

  local list_text = vim.treesitter.get_node_text(node, text):gsub("[ \n]+$", "")
  if list_text:find("\n\n") then res.tight = false end

  ---@param n TSNode
  local function parse_list_item(n)
    local items = {}
    for child, _ in n:iter_children() do
      local ntype = child:type()

      if not got_kind and LIST_MARKERS[ntype] then
        res.kind = LIST_MARKERS[ntype]
        if res.kind == "ol" then
          local marker = vim.treesitter.get_node_text(child, text)
          res.start = tonumber(marker:match("%d+")) or 1
        end
        got_kind = true
      end

      if ntype == "paragraph" then
        table.insert(items, parse_paragraph(child, text))
      elseif ntype == "html_block" then
        table.insert(items, parse_html_block(child, text))
      elseif ntype == "fenced_code_block" then
        table.insert(items, parse_code_block(child, text))
      elseif ntype == "list" then
        table.insert(items, parse_list(child, text))
      end
    end

    return items
  end

  for child, _ in node:iter_children() do
    if child:type() == "list_item" then table.insert(res.items, parse_list_item(child)) end
  end

  if res.kind == "ol" then
    -- eg. len('12. ') => 4
    local last_item = res.start + #res.items - 1
    res.marker_size = #tostring(last_item) + 2
  else
    res.marker_size = 2 -- len('- ')
  end

  return res
end

---@alias docgen.MDNode
---| docgen.MDNode.Paragraph
---| docgen.MDNode.Html
---| docgen.MDNode.Code
---| docgen.MDNode.List

---@param text string
---@return docgen.MDNode[]
function M.parse_md(text)
  local parser = vim.treesitter.languagetree.new(text, "markdown", {
    injections = { markdown = "" },
  })

  local root = parser:parse(true)[1]:root()
  local nodes = {}

  ---@param node TSNode
  local function extract(node)
    local ntype = node:type()

    if ntype:match("^%p$") then return end

    if ntype == "paragraph" then
      table.insert(nodes, parse_paragraph(node, text))
    elseif ntype == "html_block" then
      table.insert(nodes, parse_html_block(node, text))
    elseif ntype == "fenced_code_block" then
      table.insert(nodes, parse_code_block(node, text))
    elseif ntype == "list" then
      table.insert(nodes, parse_list(node, text))
    elseif vim.list_contains({ "document", "section" }, ntype) then
      for child, _ in node:iter_children() do
        extract(child)
      end
    end
  end

  extract(root)
  return nodes
end

return M
