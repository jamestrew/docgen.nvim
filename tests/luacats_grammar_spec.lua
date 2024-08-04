local grammar = require("docgen.grammar.luacats")

--- @param text string
--- @param exp table<string,string>
local function test(text, exp)
  it(string.format("can parse %q", text), function()
    assert.same(exp, grammar:match(text))
  end)
end

describe("params", function()
  test("@param hello vim.type", {
    kind = "param",
    name = "hello",
    type = "vim.type",
  })

  test("@param hello vim.type this is a description", {
    kind = "param",
    name = "hello",
    type = "vim.type",
    desc = "this is a description",
  })

  test("@param hello vim.type|string this is a description", {
    kind = "param",
    name = "hello",
    type = "vim.type|string",
    desc = "this is a description",
  })

  test("@param hello vim.type?|string? this is a description", {
    kind = "param",
    name = "hello",
    type = "vim.type?|string?",
    desc = "this is a description",
  })

  test("@param ... string desc", {
    kind = "param",
    name = "...",
    type = "string",
    desc = "desc",
  })

  test("@param level (integer|string) desc", {
    kind = "param",
    name = "level",
    type = "integer|string",
    desc = "desc",
  })

  test('@param rfc "rfc2396"| "rfc2732" | "rfc3986" | nil', {
    kind = "param",
    name = "rfc",
    type = '"rfc2396"| "rfc2732" | "rfc3986" | nil',
  })

  test('@param offset_encoding "utf-8" | "utf-16" | "utf-32" | nil', {
    kind = "param",
    name = "offset_encoding",
    type = '"utf-8" | "utf-16" | "utf-32" | nil',
  })

  -- handle a : after the param type
  test("@param a b: desc", {
    kind = "param",
    name = "a",
    type = "b",
    desc = "desc",
  })

  test(
    "@field prefix? string|table|(fun(diagnostic:vim.Diagnostic,i:integer,total:integer): string, string)",
    {
      kind = "field",
      name = "prefix?",
      type = "string|table|(fun(diagnostic:vim.Diagnostic,i:integer,total:integer): string, string)",
    }
  )

  test("@param type `T` this is a generic type", {
    desc = "this is a generic type",
    kind = "param",
    name = "type",
    type = "`T`",
  })

  test('@param type [number,string,"good"|"bad"] this is a tuple type', {
    desc = "this is a tuple type",
    kind = "param",
    name = "type",
    type = '[number,string,"good"|"bad"]',
  })

  -- test("@param foo (string|number)[] this is a union array", {
  --   desc = "this is a union array",
  --   kind = "param",
  --   name = "foo",
  --   type = "(string|number)[]",
  -- })

  test("@param foo fun(a:string): boolean this is a function", {
    desc = "this is a function",
    kind = "param",
    name = "foo",
    type = "fun(a:string): boolean",
  })

  test("@param foo (string)[] this is a string array", {
    desc = "this is a string array",
    kind = "param",
    name = "foo",
    type = "(string)[]",
  })
end)

describe("returns", function()
  test("@return string hello this is a description", {
    kind = "return",
    {
      name = "hello",
      type = "string",
    },
    desc = "this is a description",
  })
  test("@return fun() hello this is a description", {
    kind = "return",
    {
      name = "hello",
      type = "fun()",
    },
    desc = "this is a description",
  })

  test("@return fun(a: string[]): string hello this is a description", {
    kind = "return",
    {
      name = "hello",
      type = "fun(a: string[]): string",
    },
    desc = "this is a description",
  })

  test("@return fun(a: table<string,any>): string hello this is a description", {
    kind = "return",
    {
      name = "hello",
      type = "fun(a: table<string,any>): string",
    },
    desc = "this is a description",
  })

  test("@return (string command) the command and arguments", {
    kind = "return",
    {
      name = "command",
      type = "string",
    },
    desc = "the command and arguments",
  })

  test("@return (string command, string[] args) the command and arguments", {
    kind = "return",
    {
      name = "command",
      type = "string",
    },
    {
      name = "args",
      type = "string[]",
    },
    desc = "the command and arguments",
  })

  test("@return string ... some strings", {
    kind = "return",
    {
      name = "...",
      type = "string",
    },
    desc = "some strings",
  })
end)

describe("fields", function()
  test("@field [integer] integer", {
    kind = "field",
    name = "[integer]",
    type = "integer",
  })

  test("@field [1] integer", {
    kind = "field",
    name = "[1]",
    type = "integer",
  })

  test("@field [1] integer this is a description", {
    kind = "field",
    name = "[1]",
    type = "integer",
    desc = "this is a description",
  })
end)

describe("types", function()
  local types = require("docgen.grammar.types")

  ---@param idx integer
  ---@param input string
  ---@param expected string|boolean
  local function test_types(idx, input, expected)
    it(string.format("%d: can parse %q", idx, input), function()
      local actual = types:match(input)
      if expected == true then
        assert.same(input, actual)
      elseif not expected then
        assert.is_nil(actual)
      else
        assert.same(expected, actual)
      end
    end)
  end

  ---@type [string, string|boolean][]
  local test_cases = {
    { "foo", true },
    { "foo   ", "foo" },
    { "true", true },
    { "vim.type", true },
    { "vim-type", true },
    { "`ABC`", true },
    { "42", true },
    { "-42", true },
    { "(foo)", "foo" },
    { "true?", true },
    { "(true)?", true },
    { "string[]", true },
    { "string|number", true },
    { "(string)[]", true },
    { "(string|number)[]", true },
    { ")bad", false },
    { "coalesce??", "coalesce?" },
    { "number?|string", true },
    { "'foo'|'bar'|'baz'", true },
    { [["foo"|"bar"|"baz"]], true },
    { "(number)?|string", true }, --
    { "number[]|string", true },
    { "string[]?", true },
    { "wtf?[]", true },
    { "vim.type?|string?   ", "vim.type?|string?" },

    -- tuples
    { "[string]", true },
    { "[1]", true },
    { "[string, number]", true },
    { "[string, number]?", true },
    { "[string, number][]", true },
    { "[string, number]|string", true },
    { "[string|number, number?]", true },
    { "string|[string, number]", true },
    { "(true)?|[foo]", true },
    { "[fun(a: string):boolean]", true },

    -- dict
    { "{[string]:string}", true },
    { "{ [ string ] : string }", true },
    { "{ [ string|any ] : string }", true },
    { "{[string]: string, [number]: boolean}", true },

    -- key-value table
    { "table<string,any>", true },
    { "table", true },
    { "string|table|boolean", true },
    { "string|table|(boolean)", true },

    -- table literal
    { "{foo: number}", true },
    { "{foo: string, bar: [number, boolean]?}", true },

    -- function
    { "fun(a: string, b:foo|bar): string", true },
    { "(fun(a: string, b:foo|bar): string)?", true },
    { "fun(a: string, b:foo|bar): string, string", true },
    { "fun(a: string, b:foo|bar)", true },
    -- {
    --   "string|table|(fun(diagnostic:vim.Diagnostic,i:integer,total:integer): string, string)",
    --   true,
    -- },
  }

  for i, tc in ipairs(test_cases) do
    test_types(i, tc[1], tc[2])
  end
end)
