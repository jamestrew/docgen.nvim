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




vim.print(parser.parse_str([[
---@brief
--- hello
--- there
---
--- newline
]], "foo.lua"))

return M
