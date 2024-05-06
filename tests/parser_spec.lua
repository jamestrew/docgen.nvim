local parser = require("docgen.parser")

describe("class", function()
  --- @param name string
  --- @param text string
  --- @param exp table<string,string>
  local function test(name, text, exp)
    exp = vim.deepcopy(exp, true)
    it(name, function() assert.are.same(exp, parser.parse_str(text, "myfile.lua")) end)
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

describe("brief", function()
  --- @param name string
  --- @param text string
  --- @param exp table
  local function test(name, text, exp)
    local _, _, actual, _ = parser.parse_str(text, "myfile.lua")
    it(name, function()
      assert.are.same(#exp, #actual)
      assert.are.same(exp, actual)
    end)
  end

  test(
    "empty",
    [[
  ---@brief
  ]],
    { "" }
  )

  test(
    "basic",
    [[
  ---@brief
  --- hello
  ]],
    { "\nhello" }
  )


end)
