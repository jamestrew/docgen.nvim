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

local assert_brief = function(input, expect, start_indent)
  input = vim.trim(input) .. "\n"
  expect = expect:gsub("^\n+", ""):gsub("[ \n]+$", "")
  start_indent = start_indent or 0
  local _, _, briefs, _ = parser.parse_str(input, "foo.lua")
  local md = briefs[1]
  local actual = renderer.render_markdown(md, start_indent, 0, 0)
  assert.are.same(expect, actual, inspect_diff(expect, actual, md))
  return md
end

describe("briefs", function()
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

  it("pre blocks", function()
    local input = [[
---@brief
--- <pre>
--- You can disable formatting with a
--- pre block.
--- This is useful if you want to draw a table or write some code
--- </pre>
    ]]
    local expect = [[
You can disable formatting with a
pre block.
This is useful if you want to draw a table or write some code
    ]]
    assert_brief(input, expect)
  end)

  describe("ul", function()
    it("one item", function()
      local input = [[
---@brief
--- - item 1
    ]]

      local expect = [[
• item 1
    ]]
      assert_brief(input, expect)
    end)

    it("two items, tight", function()
      local input = [[
---@brief
--- - item 1
--- - item 2
      ]]

      local expect = [[
• item 1
• item 2
    ]]
      assert_brief(input, expect)
    end)

    it("two items, loose", function()
      local input = [[
---@brief
--- - item 1
---
--- - item 2
      ]]

      local expect = [[
• item 1

• item 2
    ]]
      assert_brief(input, expect)
    end)

    it("nested", function()
      local input = [[
---@brief
--- - item 1
---     - nested item
      ]]

      local expect = [[
• item 1
    • nested item
      ]]
      assert_brief(input, expect)
    end)

    it("multiple paragraphs in one item", function()
      local input = [[
---@brief
--- - item 1
---
---     same item, new paragrah AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBBBBBBB
---
---     same item, new paragrah AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBBBBBBBB
--- - item 2
      ]]

      local expect = [[
• item 1

  same item, new paragrah AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBBBBBBB

  same item, new paragrah AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  BBBBBBBBBBB

• item 2
      ]]
      assert_brief(input, expect)
    end)

    it("code block in list", function()
      local input = [[
---@brief
--- - item 1
---     ```lua
---     print('hello')
---     ```
---     - nested 1
--- - item 2
      ]]
      local expect = [[
• item 1
  >lua
  print('hello')
  <
    • nested 1
• item 2
      ]]
      assert_brief(input, expect)
    end)
  end)

  describe("ol", function()
    it("foo", function()
      local input = [[
---@brief
--- 9. item 1
---     1. nested 1
---     - nested 2
--- 1. item 2
    ]]

      local expect = [[
9. item 1
    1. nested 1
    • nested 2
10. item 2
    ]]
      assert_brief(input, expect)
    end)
  end)
end)
