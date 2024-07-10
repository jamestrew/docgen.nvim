local M = {}

local TEXT_WIDTH = 78
local TAB_WIDTH = 4
local TAB = string.rep(" ", TAB_WIDTH)

--- comment
--- @param classes table<string, docgen.luacats.parser.class>
--- @return string
M.render_classes = function(classes)
  return ""
end

--- comment
--- @param funs docgen.luacats.parser.fun[]
--- @return string
M.render_funcs = function(funs)
  return ""
end

local function clean_newline(tabs, line)
  return line ~= tabs and line .. "\n" or "\n"
end

---@param lines string[]
---@param tabs string
---@param paragraph docgen.grammar.markdown.paragraph
---@param last_paragraph boolean
local function render_paragraph(lines, tabs, paragraph, last_paragraph)
  local line = tabs
  for para_line in vim.gsplit(paragraph.text, "\n") do
    for word in para_line:gmatch("%S+") do
      if #line + #word + 1 > TEXT_WIDTH then
        line = line .. "\n"
        table.insert(lines, line)
        line = tabs
      end

      line = line ~= tabs and line .. " " .. word or tabs .. word
    end

    line = clean_newline(tabs, line)
    table.insert(lines, line)
    line = tabs
  end

  if not last_paragraph then line = clean_newline(tabs, line) end
  table.insert(lines, line)
end

---@param markdown docgen.grammar.markdown.result[]
---@param start_indent integer
---@param list_indent integer
---@param list_depth integer
---@return string
M.render_markdown = function(markdown, start_indent, list_indent, list_depth)
  local res = {} ---@type string[]
  local tabs = string.rep(TAB, start_indent)

  for i, block in ipairs(markdown) do
    if i == 2 then tabs = tabs .. string.rep(" ", list_indent) end

    if block.kind == "paragraph" then ---@cast block docgen.grammar.markdown.paragraph
      local next_block = markdown[i + 1]
      render_paragraph(res, tabs, block, not next_block or next_block.kind ~= "paragraph")
    elseif block.kind == "code" then ---@cast block docgen.grammar.markdown.code_block
      table.insert(res, tabs .. ">" .. (block.lang or "") .. "\n")
      for line in vim.gsplit(block.code:gsub("\n$", ""), "\n") do
        table.insert(res, tabs .. line .. "\n")
      end
      table.insert(res, tabs .. "<\n")
    elseif block.kind == "pre" then ---@cast block docgen.grammar.markdown.pre_block
      for line in vim.gsplit(block.lines:gsub("\n$", ""), "\n") do
        table.insert(res, tabs .. line .. "\n")
      end
    elseif block.kind == "ul" then ---@cast block docgen.grammar.markdown.ul
      local marker = string.rep(TAB, start_indent + list_depth) .. "• "
      local sep = block.tight and "\n" or "\n\n"
      for _, item in ipairs(block.items) do
        local list_item = M.render_markdown(item, start_indent, list_indent + 2, list_depth + 1)
        table.insert(res, marker .. list_item .. sep)
      end
    elseif block.kind == "ol" then ---@cast block docgen.grammar.markdown.ol
      local marker_ws = string.rep(TAB, start_indent + list_depth)

      local max_marker = block.start + #block.items - 1
      local max_marker_size = #tostring(max_marker) + 1

      local sep = block.tight and "\n" or "\n\n"
      for j, item in ipairs(block.items) do
        local marker = tostring(block.start + j - 1) .. ". "
        local list_item =
          M.render_markdown(item, start_indent, list_indent + max_marker_size, list_depth + 1)
        table.insert(res, marker_ws .. marker .. list_item .. sep)
      end
    end
  end

  return (table.concat(res):gsub("[ \n]+$", ""))
end

--- comment
--- @param briefs docgen.grammar.markdown.result[]
--- @return string
M.render_briefs = function(briefs)
  return ""
end

return M
