local parser = require("docgen.parser")
local renderer = require("docgen.renderer")
local parse_md = require("docgen.grammar.markdown").parse_markdown

local function string_literal(str)
  -- str = string.gsub(str, "\n", "\\n")
  -- str = string.gsub(str, "\t", "\\t")
  str = string.gsub(str, "    ", "󰌒")
  str = string.gsub(str, " ", "·")
  return str
end

local inspect_diff = function(expected, actual, other)
  local opts = {
    ctxlen = 10,
    algorithm = "minimal",
  }
  ---@diagnostic disable-next-line: missing-parameter
  return "actual-expected\n"
    .. tostring(vim.diff(string_literal(actual), string_literal(expected), opts))
    .. "\n"
    .. vim.inspect(other)
end

---@param expect string
---@param actual string
---@param other any
local function assert_lines(expect, actual, other)
  expect = "\n" .. expect
  actual = "\n" .. actual
  local passes = true
  local expect_lines = vim.split(expect, "\n")
  for i, line in vim.iter(vim.gsplit(actual, "\n")):enumerate() do
    if expect_lines[i] == "" then
      passes = string.match(line, "^%s*$") ~= nil
    else
      passes = expect_lines[i] == line
    end
    if not passes then break end
  end

  if not passes then assert.are.same(expect, actual, inspect_diff(expect, actual, other)) end
end

describe("functions", function()
  ---@type docgen.section
  local section = {
    title = "FOO_BAR",
    tag = "foo.bar",
    fn_prefix = "foo_bar",
  }

  local assert_funs = function(input, expect)
    input = string.format("local M = {}\n%s\nreturn M\n", input)
    expect = expect:gsub("^\n+", ""):gsub("[ \n]+$", "")
    local classes, funs, _, _ = parser.parse_str(input, "foo.lua")
    local actual = renderer.render_funs(funs, classes, section, {}):gsub("[ \n]+$", "")
    assert_lines(expect, actual, { classes = classes, funs = funs })
  end

  it("basic", function()
    local input = [[
--- Append `x` to 'foo'
---@eval return vim.inspect({ x = 1, y = 2 })
---@note this is a note
---@param x string some string to append to 'foo'
---@param y string another string to append to 'foo'
---
--- another paragraph for the `y` parameter. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBB
---@return string x the string 'foo' appended with 'x'
---@see foobar
M.foo = function(x, y) return 'foo' + x end

--- another one
M.bar = function() end
    ]]

    local expect = [[
foo_bar.foo({x}, {y})                                          *foo.bar.foo()*
    Append `x` to 'foo'

    { x = 1, y = 2 }

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

foo_bar.bar()                                                  *foo.bar.bar()*
    another one
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
        *foo.bar.this_is_a_really_long_function_name_that_should_be_wrapped()*
foo_bar.this_is_a_really_long_function_name_that_should_be_wrapped({some_param})
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
---@generic T
---@param ... string some strings
---@param ty `T` some type
---@return boolean enabled
---@return boolean|nil error if something errored
---@return string ... some return strings
function M.funky_params(..., ty)
  return true, nil, "foo", "bar"
end
    ]]

    local expect = [[
foo_bar.funky_params({...}, {ty})                     *foo.bar.funky_params()*
    hello

    Parameters: ~
      • {...}  (`string`) some strings
      • {ty}   (``T``) some type

    Return (multiple): ~
        (`boolean`)
        (`boolean?`) if something errored
        (`string`) some return strings
    ]]

    assert_funs(input, expect)
  end)
end)

describe("classes", function()
  local assert_classes = function(input, expect)
    input = string.format("local M = {}\n%s\nreturn M\n", input)
    expect = expect:gsub("^\n+", ""):gsub("[ \n]+$", "")
    local classes, _, _, _ = parser.parse_str(input, "foo.lua")
    local actual = renderer.render_classes(classes):gsub("[ \n]+$", "")
    assert_lines(expect, actual, { classes = classes })
  end

  it("basic", function()
    local input = [[
--- some description about Foobar
--- - here's a list
---     - it's nested
---
--- ```lua
--- print('hello')
--- ```
---@class Foobar
---@field a string
---@field b number
---@field c boolean
---@field d "rfc2396"| "rfc2732" | "rfc3986" | nil
---@field e fun(a: table<string,any>): string hello this is a description
    ]]
    local expect = [[
*Foobar*
    some description about Foobar
    • here's a list
      • it's nested
    >lua
    print('hello')
    <

    Fields: ~
      • {a}  (`string`)
      • {b}  (`number`)
      • {c}  (`boolean`)
      • {d}  (`"rfc2396"|"rfc2732"|"rfc3986"?`)
      • {e}  (`fun(a: table<string,any>): string`) hello this is a description
    ]]
    assert_classes(input, expect)
  end)
end)

describe("render_markdown", function()
  local assert_md = function(input, expect, start_indent, indent)
    start_indent = start_indent or 0
    indent = indent or 0
    input = vim.trim(input) .. "\n"
    expect = expect:gsub("^\n+", ""):gsub("[ \n]+$", "")
    local md = parse_md(input)
    local actual = renderer.render_markdown(input, start_indent, indent)
    assert_lines(expect, actual, { markdown = md, start_indent = start_indent, indent = indent })
  end

  describe("paragraphs", function()
    it("basic wrap", function()
      local input = [[
Paragraph as 79 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBBBBBBB
    ]]
      local expect = [[
Paragraph as 79 characters AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
BBBBBBBBBB
      ]]
      assert_md(input, expect, 0, 0)
    end)

    it("with line break", function()
      local input = [[
New paragraph with line break<br>Should be new line. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
      ]]
      local expect = [[
New paragraph with line break
Should be new line. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
      ]]
      assert_md(input, expect, 0, 0)
    end)

    it("with indent", function()
      local input = [[
another string to append to 'foo'

another paragraph for the `y` parameter. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBB
    ]]
      local expect = [[
    another string to append to 'foo'

    another paragraph for the `y` parameter. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    BBBBB
    ]]
      assert_md(input, expect, 4, 4)
    end)
  end)

  describe("code blocks", function()
    it("no language", function()
      local input = [[
```

print('hello')

print('world')
```
      ]]
      local expect = [[
>
print('hello')

print('world')
<
      ]]
      assert_md(input, expect, 0, 0)
    end)

    it("with language", function()
      local input = [[
```lua

print('hello')


print('world')
```
      ]]
      local expect = [[
>lua
print('hello')


print('world')
<
      ]]
      assert_md(input, expect)
    end)

    it("with indent", function()
      local input = [[
```lua

print('hello')


print('world')
```
      ]]
      local expect = [[
    >lua
    print('hello')


    print('world')
    <
      ]]
      assert_md(input, expect, 4, 4)
    end)
  end)

  describe("pre blocks", function()
    it("basic", function()
      local input = [[
<pre>
You can disable formatting with a
pre block.
This is useful if you want to draw a table or write some code
</pre>
    ]]
      local expect = [[
You can disable formatting with a
pre block.
This is useful if you want to draw a table or write some code
    ]]
      assert_md(input, expect)
    end)

    it("with indent", function()
      local input = [[
<pre>
You can disable formatting with a
pre block.
This is useful if you want to draw a table or write some code
</pre>
    ]]
      local expect = [[
    You can disable formatting with a
    pre block.
    This is useful if you want to draw a table or write some code
    ]]
      assert_md(input, expect, 4, 8)
    end)
  end)

  describe("ul", function()
    it("ul with paragraphs", function()
      local input = [[
- item 1

    paragraph
]]
      local expect = [[
• item 1

  paragraph
    ]]
      assert_md(input, expect)

      expect = [[
    • item 1

      paragraph
      ]]
      assert_md(input, expect, 4, 4)

      expect = [[
    • item 1

          paragraph
      ]]
      assert_md(input, expect, 4, 8)
    end)

    it("many items, tight", function()
      local expect
      local input = [[
- item 1
- item 2
      ]]

      expect = [[
• item 1
• item 2
      ]]
      assert_md(input, expect)

      expect = [[
    • item 1
    • item 2
      ]]
      assert_md(input, expect, 4, 4)

      expect = [[
    • item 1
        • item 2
      ]]
      assert_md(input, expect, 4, 8)
    end)

    it("many items, loose", function()
      local expect
      local input = [[
- item 1

- item 2
      ]]

      expect = [[
• item 1

• item 2
      ]]
      assert_md(input, expect)

      expect = [[
    • item 1

    • item 2
      ]]
      assert_md(input, expect, 4, 4)

      expect = [[
    • item 1

        • item 2
      ]]
      assert_md(input, expect, 4, 8)
    end)

    it("nested", function()
      local input = [[
- item 1
    - item 2
        - item 3
    ]]
      local expect = [[
• item 1
  • item 2
    • item 3
    ]]
      assert_md(input, expect)

      expect = [[
    • item 1
      • item 2
        • item 3
    ]]
      assert_md(input, expect, 4, 4)

      expect = [[
    • item 1
          • item 2
            • item 3
    ]]
      assert_md(input, expect, 4, 8)
    end)

    it("multiple paragraphs in one item", function()
      local input = [[
- item 1

    same item, new paragrah AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBBBBBBB

    same item, new paragrah AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBBBBBBBB
- item 2
      ]]

      local expect = [[
• item 1

  same item, new paragrah AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBBBBBBBB

  same item, new paragrah AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  BBBBBBBBBBB

• item 2

      ]]
      assert_md(input, expect)
    end)

    it("code block in list", function()
      local input = [[
- item 1
    ```lua
    print('hello')
    ```
    - nested 1
- item 2
      ]]
      local expect = [[
• item 1
  >lua
  print('hello')
  <
  • nested 1
• item 2
      ]]
      assert_md(input, expect)
    end)
  end)

  describe("ol", function()
    it("mixed", function()
      local expect
      local input = [[
9. item 1
    9. nested 1
    10. nested 2
    - nested 2
        ```lua
        print('hello')
        ```
10. item 2
      ]]

      expect = [[
9.  item 1
    9.  nested 1
    10. nested 2
    •   nested 2
        >lua
        print('hello')
        <
10. item 2
      ]]
      assert_md(input, expect)

      expect = [[
    9.  item 1
        9.  nested 1
        10. nested 2
        •   nested 2
            >lua
            print('hello')
            <
    10. item 2
      ]]
      assert_md(input, expect, 4, 4)

      expect = [[
    9.  item 1
            9.  nested 1
            10. nested 2
            •   nested 2
                >lua
                print('hello')
                <
        10. item 2
      ]]
      assert_md(input, expect, 4, 8)
    end)
  end)

  it("huh", function()
    local input =
      "some description about Foobar\n- here's a list\n    - it's nested\n\n```lua\nprint('hello')\n```"
    local expect = [[
    some description about Foobar
    • here's a list
      • it's nested
    >lua
    print('hello')
    <
    ]]
    assert_md(input, expect, 4, 4)
  end)
end)
