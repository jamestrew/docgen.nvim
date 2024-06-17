local M = {}

local s_lit = function(s)
  if s == nil then return "" end
  return s:gsub("\n", "\\n")
end

---@enum docgen.renderer.states
local states = {
  PARAGRAPH = 0,
  OL = 1,
  UL = 2,
  CODE = 3,
  PRE = 4,
}

local MAX_WIDTH = 78
local TAB_WIDTH = 2

---@class docgen.renderer.Markdown
---@field state docgen.renderer.states
---@field lines string[]
---@field curr_pos integer
---@field peek_line integer?
---@field output_lines string[]
local Markdown = {}
Markdown.__index = Markdown

---@param input string
---@return docgen.renderer.Markdown
function Markdown:new(input)
  input = vim.trim(input):gsub("\r?\n", "\n")
  input = input:gsub("\r", "\n")
  input = input:gsub("([^\n]*)\t", string.rep(" ", TAB_WIDTH))

  local obj = setmetatable({
    state = states.PARAGRAPH,
    lines = vim.split(input, "\n"),
    curr_pos = 1,
    peek_pos = 2,
    output_lines = {},
  }, Markdown)

  return obj
end

---@param index integer
---@return docgen.renderer.states
function Markdown:line_type(index)
  local line = vim.trim(self.lines[index])
  if vim.startswith(line, "- ") or vim.startswith(line, "* ") or vim.startswith(line, "+ ") then
    return states.UL
  elseif line:match("^%d+%.") then
    return states.OL
  elseif vim.startswith(line, "```") then
    return states.CODE
  elseif vim.startswith(line, "<pre>") then
    return states.PRE
  else
    return states.PARAGRAPH
  end
end

function Markdown:parse()
  while self.curr_pos <= #self.lines do
    local curr_type = self:line_type(self.curr_pos)
    if curr_type == states.UL then
      self:parse_list_item(1)
    elseif curr_type == states.OL then
      self:parse_ol()
    elseif curr_type == states.CODE then
      self:parse_code_block()
    elseif curr_type == states.PRE then
      self:parse_pre_block()
    else
      self:parse_paragraphs("")
    end
  end
end

function Markdown:parse_ul() end
function Markdown:parse_ol() end

---@param depth integer indentation depth of current node
function Markdown:parse_list_item(depth)
  -- iterate over lines
  -- collect while tabbed lines (tab depth depending on `depth`) -> these lines are all paragraphs in the current list item
  -- parse the paragraph with `parse_paragraph`

  depth = depth * TAB_WIDTH

  local lines = {}
  local end_pos = self.curr_pos
  for i = self.curr_pos, #self.lines do
    local line = self.lines[i]
    local line_depth = #line - #vim.trim(line)
    if line_depth == depth or line == "" then
      end_pos = i
      self:append_para(i, lines)
    else
      break
    end
  end

  lines[1] = lines[1]:gsub("^%s%-", "")
  local text = table.concat(lines, "")
  self:parse_paragraph_lines(table.concat(lines, ""), "")

  -- currently only concerned with unordered lists but maybe want to track the
  -- list number for later when handling orderer lists
  self.curr_pos = end_pos + 1
end

function Markdown:parse_code_block() end
function Markdown:parse_pre_block() end

function Markdown:append_para(idx, lines)
  if self.lines[idx] == "" then
    table.insert(lines, "\n")
  else
    local line = self.lines[idx]
    if self.lines[idx + 1] ~= "" then line = line .. " " end
    table.insert(lines, line)
  end
end

function Markdown:parse_paragraphs()
  local lines = {}
  local end_pos = #self.lines
  for i = self.curr_pos, end_pos do
    if self:line_type(i) == states.PARAGRAPH then
      end_pos = i
      self:append_para(i, lines)
    else
      break
    end
  end

  local text = table.concat(lines, "")
  lines = self:parse_paragraph_lines(text, "")
  self.output_lines = lines
  self.curr_pos = end_pos + 1
end

---@param text string
---@param prefix string
---@return string[]
function Markdown:parse_paragraph_lines(text, prefix)
  local lines = {}
  for para in vim.gsplit(text, "\n\n") do
    local line_buf = {}
    for line in vim.gsplit(para, "<br>") do
      line = vim.trim(line)
      if line == "" then
        table.insert(line_buf, line)
      else
        local start, finish = 1, math.min(#line, MAX_WIDTH)
        while start < #line do
          table.insert(line_buf, vim.trim(line:sub(start, finish)))
          start = finish + 1
          finish = math.min(#line, finish + MAX_WIDTH)
        end
      end
    end
    table.insert(lines, table.concat(line_buf, "\n"))
  end

  return lines
end

---@param prefix string?
---@param width integer?
---@return string
function Markdown:render(prefix, width)
  self:parse()
  return table.concat(self.output_lines, "\n")
end

---@param brief string?
---@return string
M.render_brief = function(brief)
  if brief then
    local desc = Markdown:new(brief)
    return desc:render()
  end
  return ""
end

return M
