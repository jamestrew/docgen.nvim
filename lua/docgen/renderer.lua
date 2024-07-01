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
M.render_funs = function(funs)
  return ""
end

---@package
---@param markdown docgen.grammar.markdown.result[]
---@param start_indent integer
---@return string
M.render_markdown = function(markdown, start_indent)
  local res = {} ---@type string[]
  local tabs = string.rep(TAB, start_indent)

  local function clean_newline(line)
    return line ~= tabs and line .. "\n" or "\n"
  end

  for _, block in ipairs(markdown) do
    if block.kind == "paragraph" then
      ---@cast block docgen.grammar.markdown.paragraph
      local line = tabs
      for para_line in vim.gsplit(block.text, "\n") do
        for word in para_line:gmatch("%S+") do
          if #line + #word + 1 > TEXT_WIDTH then
            line = line .. "\n"
            table.insert(res, line)
            line = tabs
          end

          line = line ~= tabs and line .. " " .. word or tabs .. word
        end

        line = clean_newline(line)
        table.insert(res, line)
        line = tabs
      end
      line = clean_newline(line)
      table.insert(res, line)
    elseif block.kind == "code" then
      ---@cast block docgen.grammar.markdown.code_block
      table.insert(res, tabs .. ">" .. (block.lang or "") .. "\n")
      for line in vim.gsplit(block.code:gsub("\n$", ""), "\n") do
        table.insert(res, tabs .. line .. "\n")
      end
      table.insert(res, tabs .. "<\n")
    elseif block.kind == "pre" then
      ---@cast block docgen.grammar.markdown.pre_block
      for line in vim.gsplit(block.lines:gsub("\n$", ""), "\n") do
        table.insert(res, tabs .. line .. "\n")
      end
    elseif block.kind == "ul" then
      ---@cast block docgen.grammar.markdown.ul
      local marker = tabs .. "- "
      local sep = block.tight and "\n" or "\n\n"
      for _, item in ipairs(block.items) do
        if item.kind == "ul" or item.kind == "ol" then start_indent = start_indent + 1 end
        table.insert(res, marker .. M.render_markdown(item, start_indent) .. sep)
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

--[[

Just short of 78 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

New paragraph as 79 characters BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB BBBBBBBBBA
Paragraph as 79 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBBBBBBB

New paragraph with line break<br>Should be new line.

---

Just short of 78 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

New paragraph as 79 characters BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBA

New paragraph with line break
Should be new line.
]]
