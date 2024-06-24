---@diagnostic disable: invisible

local parser = require("docgen.parser")
local renderer = require("docgen.renderer")

local function string_literal(str)
  str = string.gsub(str, "\n", "\\n")
  str = string.gsub(str, "\t", "\\t")
  str = string.gsub(str, " ", "·")
  return str
end

local inspect_diff = function(a, b, md)
  local opts = {
    ctxlen = 10,
    algorithm = "minimal",
  }
  ---@diagnostic disable-next-line: missing-parameter
  return "expected-actual\n"
    .. tostring(vim.diff(string_literal(a), string_literal(b), opts))
    .. "\n"
    .. vim.inspect(md)
end

describe("briefs", function()
  local assert_brief = function(input, expect, indents)
    input = vim.trim(input) .. "\n"
    expect = expect:gsub("^\n+", ""):gsub("[ \n]+$", "")
    indents = indents or 0
    local _, _, briefs, _ = parser.parse_str(input, "foo.lua")
    local md = briefs[1]
    local actual = renderer.render_markdown(md, indents)
    assert.are.same(expect, actual, inspect_diff(expect, actual, md))
  end

  describe("paragraphs", function()
    it("single line", function()
      local input = [[---@brief
--- this is a single line]]
      local expect = "this is a single line"
      assert_brief(input, expect)
    end)

    it("single line wrap, no indent", function()
      local input = [[---@brief
--- Paragraph as 79 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBBBBBBB
      ]]
      local expect = [[
Paragraph as 79 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
BBBBBBBBBB
      ]]
      assert_brief(input, expect)
    end)

    it("one paragraph with line break", function()
      local input = [[
---@brief
--- New paragraph with line break<br>Should be new line.
      ]]
      local expect = [[
New paragraph with line break
Should be new line.
      ]]
      assert_brief(input, expect)
    end)

    it("one paragrpah with line break and wrap", function()
      local input = [[
---@brief
--- New paragraph with line break<br>Should be new line. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
      ]]
      local expect = [[
New paragraph with line break
Should be new line. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
      ]]
      assert_brief(input, expect)
    end)

    it("many paragraphs, no indents", function()
      local input = [[
---@brief
--- Just short of 78 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
---
--- Paragraph as 79 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBBBBBBB
---
--- New paragraph with line break<br><br>Should be new line.
      ]]
      local expect = [[
Just short of 78 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

Paragraph as 79 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
BBBBBBBBBB

New paragraph with line break

Should be new line.
      ]]
      assert_brief(input, expect)
    end)

    it("one para, 1 indent", function()
      local input = [[
---@brief
--- Just short of 78 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
      ]]
      local expect = [[
    Just short of 78 characters
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
      ]]
      assert_brief(input, expect, 1)
    end)

    it("many paragraphs, 1 indent", function()
      local input = [[
---@brief
--- Just short of 78 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
---
--- Paragraph as 79 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBBBBBBB
---
--- New paragraph with line break<br><br>Should be new line.
      ]]
      local expect = [[
    Just short of 78 characters
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

    Paragraph as 79 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    BBBBBBBBBB

    New paragraph with line break

    Should be new line.
      ]]
      assert_brief(input, expect, 1)
    end)
  end)

  describe("code blocks", function()
    it("no language", function()
      local input = [[
---@brief
--- ```
---
--- print('hello')
---
--- print('world')
--- ```
      ]]
      local expect = [[
>

print('hello')

print('world')
<
      ]]
      assert_brief(input, expect)
    end)

    it("with language", function()
      local input = [[
---@brief
--- ```lua
---
--- print('hello')
---
--- print('world')
--- ```
      ]]
      local expect = [[
>lua

print('hello')

print('world')
<
      ]]
      assert_brief(input, expect)
    end)
  end)

  describe("pre blocks", function() end)
  describe("lists", function() end)
end)
