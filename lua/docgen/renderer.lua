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

---@class docgen.renderer.Description
---@field state docgen.renderer.states
---@field lines string[]
---@field curr_pos integer
---@field peek_line integer?
---@field output_lines string[]
local Description = {}
Description.__index = Description

---@param input string
---@return docgen.renderer.Description
function Description:new(input)
  input = vim.trim(input):gsub("\r?\n", "\n")

  local obj = setmetatable({
    state = states.PARAGRAPH,
    lines = vim.split(input, "\n"),
    curr_pos = 1,
    peek_pos = 2,
    output_lines = {},
  }, Description)

  return obj
end

---@param line string
---@return docgen.renderer.states
---@return string?
function Description:new_state(line)
  line = vim.trim(line)

  if vim.startswith(line, "-") then
    self.state = states.UL
  elseif vim.trim(line):match("^[0-9]") then
    self.state = states.OL
  elseif line == "```" then
    return states.CODE
  elseif vim.trim(line):match("```(.*)") then
    local lang = vim.trim(line):match("```(.*)")
    return states.CODE, vim.trim(lang)
  elseif line == "<pre>" then
    return states.PRE
  end
  return states.PARAGRAPH
end

---@param index integer
---@return docgen.renderer.states
function Description:line_type(index)
  local line = vim.trim(self.lines[index])
  if vim.startswith(line, "-") then
    return states.UL
  elseif line:match("^[0-9]") then
    return states.OL
  elseif vim.startswith(line, "```") then
    return states.CODE
  elseif vim.startswith(line, "<pre>") then
    return states.PRE
  else
    return states.PARAGRAPH
  end
end

function Description:parse()
  local curr_type = self:line_type(self.curr_pos)
  if curr_type == states.UL then
    self:parse_ul()
  elseif curr_type == states.OL then
    self:parse_ol()
  elseif curr_type == states.CODE then
    self:parse_code_block()
  elseif curr_type == states.PRE then
    self:parse_pre_block()
  else
    self:parse_paragraphs()
  end
end

function Description:parse_ul() end
function Description:parse_ol() end
function Description:parse_code_block() end
function Description:parse_pre_block() end

function Description:parse_paragraphs()
  local lines = {}
  local end_pos = self.curr_pos
  for i = self.curr_pos, #self.lines do
    if self:line_type(i) == states.PARAGRAPH then
      end_pos = i
      if self.lines[i] == "" then
        table.insert(lines, "\n")
      else
        local line = self.lines[i]
        if self.lines[i + 1] ~= "" then line = line .. " " end
        table.insert(lines, line)
      end
    else
      break
    end
  end

  local text = table.concat(lines, "")

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
    table.insert(self.output_lines, table.concat(line_buf, "\n"))
  end

  self.curr_pos = end_pos
end

---@param prefix string?
---@param width integer?
---@return string
function Description:render(prefix, width)
  self:parse()
  return table.concat(self.output_lines, "\n")
end

---@param brief string?
---@return string
M.render_brief = function(brief)
  if brief then
    local desc = Description:new(brief)
    return desc:render()
  end
  return ""
end

return M
