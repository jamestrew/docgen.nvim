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
end)
