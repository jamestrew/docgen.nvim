local parser = require("docgen.parser")
local renderer = require("docgen.renderer")
local parse_md = require("docgen.grammar.markdown").parse_markdown

local function string_literal(str)
  -- str = string.gsub(str, "\n", "\\n")
  -- str = string.gsub(str, "\t", "\\t")
  str = string.gsub(str, " ", "·")
  return str
end

local inspect_diff = function(a, b, other)
  local opts = {
    ctxlen = 10,
    algorithm = "minimal",
  }
  ---@diagnostic disable-next-line: missing-parameter
  return "expected-actual\n"
    .. tostring(vim.diff(string_literal(a), string_literal(b), opts))
    .. "\n"
    .. vim.inspect(other)
end

describe("briefs", function()
  local assert_brief = function(input, expect)
    input = vim.trim(input) .. "\n"
    expect = expect:gsub("^\n+", ""):gsub("[ \n]+$", "")
    local _, _, briefs, _ = parser.parse_str(input, "foo.lua")
    local actual = renderer.render_briefs(briefs)
    local md = parse_md(briefs[1])
    assert.are.same(expect, actual, inspect_diff(expect, actual, md))
    return md
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
    it("works", function()
      local input = [[
---@brief
--- 9. item 1
---     9. nested 1
---     10. nested 2
---     - nested 2
---         ```lua
---         print('hello')
---         ```
--- 10. item 2
    ]]

      local expect = [[
9.  item 1
    9.  nested 1
    10. nested 2
    •   nested 2
        >lua
        print('hello')
        <
10. item 2
    ]]
      assert_brief(input, expect)
    end)
  end)
end)

describe("functions", function()
  local assert_funs = function(input, expect)
    input = string.format("local M = {}\n%s\nreturn M\n", input)
    expect = expect:gsub("^\n+", ""):gsub("[ \n]+$", "")
    local classes, funs, _, _ = parser.parse_str(input, "foo.lua")
    local actual = renderer.render_funs(funs, classes):gsub("[ \n]+$", "")
    assert.are.same(
      expect,
      actual,
      inspect_diff(expect, actual, { classes = classes, funs = funs })
    )
  end

  it("basic", function()
    local input = [[
--- Append `x` to 'foo'
---@note this is a note
---@param x string some string to append to 'foo'
---@param y string another string to append to 'foo'
---
--- another paragraph for the `y` parameter. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBB
---@return string x the string 'foo' appended with 'x'
---@see foobar
M.foo = function(x, y) return 'foo' + x end
    ]]

    local expect = [[
foo({x}, {y})                                                  *foo.lua.foo()*
    Append `x` to 'foo'

    Note: ~
      • this is a note

    Parameters: ~
      • {x}  (`string`) some string to append to 'foo'
      • {y}  (`string`) another string to append to 'foo'

             another paragraph for the `y` parameter.
             AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBB

    Return: ~
        (`string`) the string 'foo' appended with 'x'

    See also: ~
      • foobar
]]

    assert_funs(input, expect)
  end)

  it("no doc", function()
    local fun = [[
---@param x string some string to append to 'foo'
---@param y string another string to append to 'foo'
---@return string x the string 'foo' appended with 'x'
M.foo = function(x, y) return 'foo' + x end

---@param a integer
---@return integer
M._bar = function(a) return a end
    ]]

    local inputs = {
      "---@nodoc",
      "---@package",
    }

    for _, tinput in ipairs(inputs) do
      local input = string.format("%s\n%s", tinput, fun)
      assert_funs(input, "")
    end
  end)

  it("class method", function()
    local input = [[
---@class M
---@field bar string
local M = {
  bar = "hello"
}

--- hello
---@return M
function M:new()
  return setmetatable({}, { __index = {} })
end
    ]]

    local expect = [[
M:new()                                                              *M:new()*
    hello

    Return: ~
        (`M`) See |M|
    ]]
    assert_funs(input, expect)
  end)

  it("long function", function()
    local input = [[
--- hello
---@param some_param string
---@return integer # just 42
M.this_is_a_really_long_function_name_that_should_be_wrapped = function(some_param)
  return 42
end
    ]]
    local expect = [[
        *foo.lua.this_is_a_really_long_function_name_that_should_be_wrapped()*
this_is_a_really_long_function_name_that_should_be_wrapped({some_param})
    hello

    Parameters: ~
      • {some_param}  (`string`)

    Return: ~
        (`integer`) just 42
    ]]
    assert_funs(input, expect)
  end)

  it("funky params, returns", function()
    local input = [[
--- hello
---@param ... string some strings
---@return boolean enabled
---@return boolean|nil error if something errored
---@return string ... some return strings
function M.funky_params(...)
  return true, nil, "foo", "bar"
end
    ]]

    local expect = [[
funky_params({...})                                   *foo.lua.funky_params()*
    hello

    Parameters: ~
      • {...}  (`string`) some strings

    Return (multiple): ~
        (`boolean`)
        (`boolean?`) if something errored
        (`string`) some return strings
    ]]

    assert_funs(input, expect)
  end)
end)
