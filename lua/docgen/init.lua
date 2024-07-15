local parser = require("docgen.parser")

local M = {}

---@class docgen.config.opts
---@field name string plugin name
---@field files string[] file paths to generate docs from

-- api ideas
---@param opts docgen.config.opts
M.run = function(opts)
  local docs = {} ---@type string[]
  for _, file in ipairs(opts.files) do
    local classes, funs, briefs = parser.parse(file)
    table.insert(docs, vim.inspect({ classes = classes, funs = funs, briefs = briefs }))
  end

  local fname = vim.fs.joinpath(".", "doc", opts.name)
  local f, err = io.open(fname, "w")
  if f == nil then error(string.format("failed to open file: %s\n%s", fname, err)) end

  for _, x in ipairs(docs) do
    f:write(x)
  end
  f:close()
end

return M
