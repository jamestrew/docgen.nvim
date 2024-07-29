local parser = require("docgen.parser")

describe("class", function()
  --- @param name string
  --- @param text string
  --- @param exp table<string,string>
  local function test(name, text, exp)
    exp = vim.deepcopy(exp, true)
    it(name, function()
      assert.same(exp, parser.parse_str(text, "myfile.lua"))
    end)
  end

  local exp = {
    myclass = {
      kind = "class",
      module = "myfile.lua",
      name = "myclass",
      fields = {
        { kind = "field", name = "myclass", type = "integer" },
      },
    },
  }

  test(
    "basic",
    [[
    --- @class myclass
    --- @field myclass integer
  ]],
    exp
  )

  exp.myclass.inlinedoc = true

  test(
    "with @inlinedoc (1)",
    [[
    --- @class myclass
    --- @inlinedoc
    --- @field myclass integer
  ]],
    exp
  )

  test(
    "with @inlinedoc (2)",
    [[
    --- @inlinedoc
    --- @class myclass
    --- @field myclass integer
  ]],
    exp
  )

  exp.myclass.inlinedoc = nil
  exp.myclass.nodoc = true

  test(
    "with @nodoc",
    [[
    --- @nodoc
    --- @class myclass
    --- @field myclass integer
  ]],
    exp
  )

  exp.myclass.nodoc = nil
  exp.myclass.access = "private"

  test(
    "with (private)",
    [[
    --- @class (private) myclass
    --- @field myclass integer
  ]],
    exp
  )

  exp.myclass.fields[1].desc = "Field\ndocumentation"

  test(
    "with field doc above",
    [[
    --- @class (private) myclass
    --- Field
    --- documentation
    --- @field myclass integer
  ]],
    exp
  )

  exp.myclass.fields[1].desc = "Field documentation"
  test(
    "with field doc inline",
    [[
    --- @class (private) myclass
    --- @field myclass integer Field documentation
  ]],
    exp
  )
end)

local function assert_fun(input, expect)
  local _, actual, _, _ = parser.parse_str(input, "myfile.lua")
  assert.same(expect, actual)
end

it("ignores multi-line comments", function()
  local input = [==[
local M = {}
--[[
function M.myfunc() end
]]
return M
  ]==]
  local expect = {}
  assert_fun(input, expect)
end)

