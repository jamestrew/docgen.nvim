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

  exp.myclass.fields[1].desc = "Field\ndocumentation"

  test(
    "with field doc above",
    [[
    --- @class myclass
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
    --- @class myclass
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

describe("function", function()
  it("handle different definition forms", function()
    local input = [[
local M = {}
function M.myfunc() end

M.otherfunc = function() end
return M
    ]]
    local expect = {
      { name = "M.myfunc" },
      { name = "M.otherfunc" },
    }

    local _, actual, _, _ = parser.parse_str(input, "myfile.lua")
    assert.same(expect, actual)
  end)

  it("@async sets async=true", function()
    local input = [[
local M = {}
---@async
---@param x string
function M.myfunc(x) end
return M
    ]]
    local _, funs, _, _ = parser.parse_str(input, "myfile.lua")
    assert.same(true, funs[1].async)
  end)

  it("@overload accumulates overloads", function()
    local input = [[
local M = {}
---@overload fun(x: string): boolean
---@overload fun(x: number): string
---@param x string
function M.myfunc(x) end
return M
    ]]
    local _, funs, _, _ = parser.parse_str(input, "myfile.lua")
    assert.same({ "fun(x: string): boolean", "fun(x: number): string" }, funs[1].overloads)
  end)

  it("@overload is preserved for class methods converted to fields", function()
    local input = [[
local M = {}
---@class MyClass
local MyClass = {}
---@overload fun(self: MyClass, x: string): boolean
---@overload fun(self: MyClass, x: number): string
---@param x string
function MyClass:myfunc(x) end
return M
    ]]
    local classes, _, _, _ = parser.parse_str(input, "myfile.lua")
    assert.same(
      { "fun(self: MyClass, x: string): boolean", "fun(self: MyClass, x: number): string" },
      classes.MyClass.fields[1].overloads
    )
  end)
end)

describe("enum", function()
  local function assert_no_output(input)
    local classes, funs, briefs, uncommitted = parser.parse_str(input, "myfile.lua")
    assert.same({}, classes)
    assert.same({}, funs)
    assert.same({}, briefs)
    assert.same({}, uncommitted)
  end

  it("local enum produces no output", function()
    assert_no_output([[
local M = {}
---@enum MyColors
local MyColors = { red = 1, blue = 2 }
return M
    ]])
  end)

  it("module enum produces no output", function()
    assert_no_output([[
local M = {}
---@enum MyColors
M.MyColors = { red = 1, blue = 2 }
return M
    ]])
  end)

  it("does not swallow annotations meant for the next declaration", function()
    -- this is not spec compliant Lua type annotation but to make sure we're saying
    -- relatively resiliant to user errors where we can.
    local input = [[
local M = {}
---@enum MyColors
---@param x string
function M.myfunc(x) end
return M
    ]]
    local _, funs, _, _ = parser.parse_str(input, "myfile.lua")
    assert.same({
      {
        module = "myfile.lua",
        modvar = "M",
        name = "myfunc",
        params = {
          { name = "x", type = "string" },
        },
      },
    }, funs)
  end)
end)
