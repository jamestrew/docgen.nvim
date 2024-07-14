local parser = require("docgen.parser")

local M = {}

---@class docgen.config.opts
---@field name string plugin name
---@field files string[] file paths to generate docs from

-- api ideas
---@param opts docgen.config.opts
M.run = function(opts)
  local docs = {}
  for _, file in ipairs(opts.files) do
    table.insert(docs, tostring(vim.inspect(parser.parse(file))))
  end

  -- local fname = vim.fs.joinpath(".", "doc", opts.name)
  local fname = "./doc/foo.txt"
  local f, err = io.open(fname, "w")
  if f == nil then error(string.format("failed to open file: %s\n%s", fname, err)) end

  for _, x in ipairs(docs) do
    io.write(f, vim.inspect(x))
  end
  io.close(f)
end

vim.print(parser.parse_str(
  [[
---@brief
--- hello
--- there
---
--- newline


local M = {}

--- Append `x` to 'foo'
---@param x string some string to append to 'foo'
---@return string x the string 'foo' appended with 'x'
M.foo = function(x)
  return "foo" .. x
end

---@class M
---@field bar string
local M = {
  bar = "hello"
}

--- hello
function M:new()
  return setmetatable({}, { __index = {} })
end

return M
]],
  "foo.lua"
))

--[[
{
  M = {
    fields = { {
        kind = "field",
        name = "bar",
        type = "string"
      }, {
        name = "new",
        type = "fun(self: M)"
      } },
    kind = "class",
    module = "foo.lua",
    modvar = "M",
    name = "M"
  }
}
{ {
    desc = "Append `x` to 'foo'",
    module = "foo.lua",
    modvar = "M",
    name = "foo",
    params = { {
        desc = "some string to append to 'foo'",
        name = "x",
        type = "string"
      } },
    returns = { {
        desc = "the string 'foo' appended with 'x'",
        name = "x",
        type = "string"
      } },
    table = true
  }, {
    class = "M",
    classvar = "M",
    name = "new",
    params = { {
        name = "self",
        type = "M"
      } }
  } }
{ "\nhello\nthere\n\nnewline" }
{}
]]

return M
