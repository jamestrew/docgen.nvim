local parser = require("docgen.parser")
local renderer = require("docgen.renderer")

local M = {}

---@class docgen.Config
---@inlinedoc
---
--- plugin name, will be used to generate filename, eg `docgen` -> `docgen.txt`
---@field name string
---
--- file paths to generate docs from in order
---@field files string[]
---
--- function to generate section titles from filenames
--- if not provided, |section_title| will be used
---@field section_fmt? fun(filename: string): string
---
---
---@field fn_config? docgen.FunConfig

---@class docgen.FunConfig
---@field fn_xform? fun(fn: docgen.parser.fun)

---@class docgen.section
---@field title string
---@field tag string
---@field fn_prefix string

---@param files string[]
local function expand_files(files)
  for i, file in ipairs(files) do
    if vim.fn.isdirectory(file) == 1 then
      table.remove(files, i)
      for path, ty in vim.fn.dir(file) do
        if ty == "file" then table.insert(files, vim.fs.joinpath(file, path)) end
      end
    end
  end
end

--- Generate a section title from the filename by joining the useful module
--- name using underscores and uppercasing everything.
---
--- eg:
--- - './lua/telescope/actions/init.lua' -> 'ACTIONS'
--- - './lua/telescope/actions/set.lua' -> 'ACTIONS_SET'
---@param filename string
---@param config docgen.Config
---@return string
function M.section_title(filename, config)
  filename = vim.fs.normalize(filename)
  local name = vim
    .iter(vim.split(filename, "/"))
    :skip(2)
    :filter(function(f)
      return f ~= "init.lua"
    end)
    :map(function(f)
      return f:gsub("%.lua$", ""):upper()
    end)
    :join("_")

  return name ~= "" and name or config.name:upper()
end

---@param filename string
---@param config docgen.Config
---@return docgen.section
local function make_section(filename, config)
  local section_fmt = config.section_fmt and config.section_fmt or M.section_title
  local name = section_fmt(filename, config)
  local name_lower = name:lower()
  return {
    title = name,
    tag = name_lower ~= config.name and string.format("%s.%s", config.name, name_lower)
      or name_lower,
    fn_prefix = name_lower,
  }
end

-- api ideas
---@param config docgen.Config
M.run = function(config)
  expand_files(config.files)

  local file_res = {} ---@type table<string, [table<string, docgen.parser.class>, docgen.parser.fun[], string[]]>
  local all_classes = {} ---@type table<string, docgen.parser.class>
  for _, file in ipairs(config.files) do
    local classes, funs, briefs = parser.parse(file)
    file_res[file] = { classes, funs, briefs }

    all_classes = vim.tbl_extend("error", all_classes, classes)
  end

  local doc_lines = {} ---@type string[]
  for file, res in vim.spairs(file_res) do
    print("    Generating docs for:", file)
    local classes, funs, briefs = res[1], res[2], res[3]
    local section = make_section(file, config)
    table.insert(doc_lines, renderer.render_section(section, briefs, funs, classes, config))
  end

  renderer.append_modeline(doc_lines)

  local fname = vim.fs.joinpath(".", "doc", config.name .. ".txt")
  local f, err = io.open(fname, "w")
  if f == nil then error(string.format("failed to open file: %s\n%s", fname, err)) end

  for _, x in ipairs(doc_lines) do
    f:write(x)
  end
  f:close()
end

return M
