local markdown = require("docgen.grammar.markdown")

---@param a table
---@param b table?
local inspect_diff = function(a, b)
  local opts = {
    ctxlen = 10,
    algorithm = "minimal",
  }
  ---@diagnostic disable-next-line: missing-parameter
  return tostring(vim.diff(vim.inspect(a), vim.inspect(b), opts))
end

---@param input string
---@param expect table
local assert_block = function(input, expect)
  local match = markdown.parse_markdown(input)
  assert.same(expect, match, inspect_diff(expect, match))
end

describe("paragraphs", function()
  local test = function(name, input, paragraphs)
    it(name, function()
      local expects = {}
      for _, p in ipairs(paragraphs) do
        table.insert(expects, { kind = "paragraph", text = p })
      end
      assert_block(input, expects)
    end)
  end

  test("single line", "this is a single line", { "this is a single line" })
  test("single line bunch of spaces", "hello    world    ", { "hello world " })
  test("single line trimmed", "this is a single line\n", { "this is a single line" })
  test("single line even more trimmed", "this is a single line\n\n\n", { "this is a single line" })
  test("empty lines with single line", "\n   \nhello world", { "hello world" })
  test("split lines", "line one\nline two", { "line one line two" })
  test("single paragraph with <br>", "line one<br>line two", { "line one\nline two" })
  test("two paragraphs", "p1\n\np2\nstill p2<br>still p2", { "p1", "p2 still p2\nstill p2" })
end)

describe("code blocks", function()
  it("basic", function()
    assert_block("```\nhello\n```", { { kind = "code", code = "hello\n" } })
  end)

  it("with lang", function()
    local input = [[```python
print("hello world")
print("goodbye")
```]]
    local expect =
      { { kind = "code", lang = "python", code = 'print("hello world")\nprint("goodbye")\n' } }
    assert_block(input, expect)
  end)
end)

describe("unordered list", function()
  it("one tight", function()
    local input = "- first bullet\n"
    local expect = {
      {
        kind = "ul",
        items = {
          { { kind = "paragraph", text = "first bullet" } },
        },
        tight = true,
      },
    }
    assert_block(input, expect)
  end)

  it("one item with 2 paragraphs", function()
    local input = [[- first paragraph

    second paragraph]]
    local expect = {
      {
        kind = "ul",
        items = {
          {
            { kind = "paragraph", text = "first paragraph" },
            { kind = "paragraph", text = "second paragraph" },
          },
        },
        tight = false,
      },
    }
    assert_block(input, expect)
  end)

  it("two tight", function()
    local input = [[- first bullet
- second bullet
]]
    local expect = {
      {
        kind = "ul",
        items = {
          { { kind = "paragraph", text = "first bullet" } },
          { { kind = "paragraph", text = "second bullet" } },
        },
        tight = true,
      },
    }
    assert_block(input, expect)
  end)

  it("two loose", function()
    local input = [[- first bullet

- second bullet
]]
    local expect = {
      {
        kind = "ul",
        items = {
          { { kind = "paragraph", text = "first bullet" } },
          { { kind = "paragraph", text = "second bullet" } },
        },
        tight = false,
      },
    }
    assert_block(input, expect)
  end)

  it("tight/loose mixed", function()
    local input = [[- first bullet
- second bullet

- third bullet
]]

    local expect = {
      {
        kind = "ul",
        items = {
          { { kind = "paragraph", text = "first bullet" } },
          { { kind = "paragraph", text = "second bullet" } },
          { { kind = "paragraph", text = "third bullet" } },
        },
        tight = false,
      },
    }
    assert_block(input, expect)
  end)

  it("nested", function()
    local input = [[
- first bullet
    - nested bullet
    - second nested bullet
        - doubly nested bullet
]]

    local expect = {
      {
        items = {
          {
            { kind = "paragraph", text = "first bullet" },
            {
              items = {
                { { kind = "paragraph", text = "nested bullet" } },
                {
                  { kind = "paragraph", text = "second nested bullet" },
                  {
                    items = { { { kind = "paragraph", text = "doubly nested bullet" } } },
                    kind = "ul",
                    tight = true,
                  },
                },
              },
              kind = "ul",
              tight = true,
            },
          },
        },
        kind = "ul",
        tight = true,
      },
    }
    assert_block(input, expect)
  end)
end)

describe("ordered list", function()
  it("one tight", function()
    local input = [[1. first bullet]]
    local expect = {
      {
        kind = "ol",
        items = {
          { { kind = "paragraph", text = "first bullet" } },
        },
        tight = true,
        start = 1,
      },
    }
    assert_block(input, expect)
  end)

  it("two tight", function()
    local input = [[3. first bullet
2. second bullet]]
    local expect = {
      {
        kind = "ol",
        items = {
          { { kind = "paragraph", text = "first bullet" } },
          { { kind = "paragraph", text = "second bullet" } },
        },
        tight = true,
        start = 3,
      },
    }
    assert_block(input, expect)
  end)

  it("mixed", function()
    local input = [[3. first bullet

3. second
    2. second nested A
    3. second nested B]]

    local expect = {
      {
        kind = "ol",
        items = {
          { { kind = "paragraph", text = "first bullet" } },
          {
            { kind = "paragraph", text = "second" },
            {
              items = {
                { { kind = "paragraph", text = "second nested A" } },
                { { kind = "paragraph", text = "second nested B" } },
              },
              kind = "ol",
              tight = true,
              start = 2,
            },
          },
        },
        tight = false,
        start = 3,
      },
    }

    assert_block(input, expect)
  end)
end)

it("pre block", function()
  local input = [[
<pre>
- fake list
<br>
1. fake list 2
```lua
fake code block
```
</pre>
  ]]
  local expect = {
    { kind = "pre", lines = "- fake list\n<br>\n1. fake list 2\n```lua\nfake code block\n```\n" },
  }
  assert_block(input, expect)
end)

describe("mixed", function()
  it("tight light + code", function()
    local input = [[
- one
- two
```lua
print('hello')
```
]]
    local expect = {
      {
        kind = "ul",
        items = {
          { { kind = "paragraph", text = "one" } },
          { { kind = "paragraph", text = "two" } },
        },
        tight = true,
      },
      { kind = "code", lang = "lua", code = "print('hello')\n" },
    }
    assert_block(input, expect)
  end)

  it("wombo combo", function()
    local input = [[I wonder if this works.
Still the same line.<br>But not anymore.
-fake list

New paragraph.
```lua
local function hi(name)
  print('hi', name)
end
```
How's that?
1. first bullet
    - nested bullet
    - second nested bullet
        - doubly nested bullet
<pre>
hello world
</pre>
]]

    local expect = {
      {
        kind = "paragraph",
        text = "I wonder if this works. Still the same line.\nBut not anymore. -fake list",
      },
      { kind = "paragraph", text = "New paragraph." },
      { kind = "code", lang = "lua", code = "local function hi(name)\n  print('hi', name)\nend\n" },
      { kind = "paragraph", text = "How's that?" },
      {
        items = {
          {
            { kind = "paragraph", text = "first bullet" },
            {
              items = {
                { { kind = "paragraph", text = "nested bullet" } },
                {
                  { kind = "paragraph", text = "second nested bullet" },
                  {
                    items = { { { kind = "paragraph", text = "doubly nested bullet" } } },
                    kind = "ul",
                    tight = true,
                  },
                },
              },
              kind = "ul",
              tight = true,
            },
          },
        },
        kind = "ol",
        tight = true,
        start = 1,
      },
      { kind = "pre", lines = "hello world\n" },
    }

    assert_block(input, expect)
  end)

  it("tight nested list with code block", function()
    local input = [[
- item 1
    ```lua
    print('hello')
    ```
    - nested 1
- item 2
    ]]
    local expect = {
      {
        kind = "ul",
        items = {
          {
            { kind = "paragraph", text = "item 1" },
            { kind = "code", lang = "lua", code = "print('hello')\n" },
            {
              items = { { { kind = "paragraph", text = "nested 1" } } },
              kind = "ul",
              tight = true,
            },
          },
          { { kind = "paragraph", text = "item 2" } },
        },
        tight = true,
      },
    }
    assert_block(input, expect)
  end)
end)
