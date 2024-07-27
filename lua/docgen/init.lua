---@brief
--- Generate documentation from lua files with LuaCATS annotations + more.

local parser = require("docgen.parser")
local renderer = require("docgen.renderer")

local M = {}

---@class docgen.Config
---@inlinedoc
---
--- plugin name, will be used to generate filename, eg `docgen` -> `docgen.txt`
---@field name string
---
--- file paths/config to generate docs from in order
---@field files (string|docgen.FileSection)[]
---
--- function to generate section titles from filenames
--- if not provided, |section_title| will be used
---@field section_title? fun(filename: string): string
---
--- function to generate section tags from filenames
---@field section_tag? fun(filename: string): string
---
---@field fn_config? docgen.FunConfig

---@class docgen.FunConfig
---@field fn_xform? fun(fn: docgen.parser.fun)

---@class docgen.section
---@field title string
---@field tag string
---@field fn_prefix string

---@class docgen.FileSection
---@field [1] string filepath from which to generate the section from
---
--- title of the section
---
--- if omitted, generated from the filename
--- eg:
--- - './lua/telescope/init.lua'         -> 'TELESCOPE'
--- - './lua/telescope/actions/init.lua' -> 'ACTIONS'
--- - './lua/telescope/actions/set.lua'  -> 'ACTIONS_SET'
---@field title string?
---
--- help tag of the section WITHOUT the asterisks
---
--- if omitted, generated from the filename
--- eg:
--- - './lua/telescope/init.lua'         -> 'telescope'
--- - './lua/telescope/actions/init.lua' -> 'telescope.actions'
--- - './lua/telescope/actions/set.lua'  -> 'telescope.actions.set'
---@field tag string?
---
--- module prefix for functions
---
--- if omitted, generated from the filename same as `section_title` but in lowercase
---@field fn_prefix string?

---@param filename string
---@param plugin_name string
---@return string
local function section_title(filename, plugin_name)
  filename = vim.fs.normalize(filename)
  local parts = vim.split(filename, "/")
  local name = vim
    .iter(parts)
    :skip(2)
    :filter(function(f)
      return f ~= "init.lua"
    end)
    :map(function(f)
      return f:gsub("%.lua$", ""):upper()
    end)
    :join("_")

  return name ~= "" and name or plugin_name:upper()
end

---@param title string
---@param plugin_name string
---@return string
local function section_tag(title, plugin_name)
  title = title:lower()
  local name = plugin_name:lower()
  return title ~= name and string.format("%s.%s", name, title) or name
end

---@param file string|docgen.FileSection
---@return docgen.section
local function make_section(file, config)
  if type(file) == "string" then
    local title = section_title(file, config.name)
    return {
      title = title,
      tag = section_tag(title, config.name),
      fn_prefix = title:lower(),
    }
  end

  local path_title = section_title(file[1], config.name)
  return {
    title = vim.F.if_nil(file.title, path_title),
    tag = vim.F.if_nil(file.tag, section_tag(path_title, config.name)),
    fn_prefix = vim.F.if_nil(file.fn_prefix, path_title:lower()),
  }
end

---@param config docgen.Config
M.run = function(config)
  local file_res = {} ---@type table<string, [table<string, docgen.parser.class>, docgen.parser.fun[], string[]]>
  local all_classes = {} ---@type table<string, docgen.parser.class>
  for _, file in ipairs(config.files) do
    local filepath = type(file) == "string" and file or file[1]

    local classes, funs, briefs = parser.parse(filepath)
    file_res[filepath] = { classes, funs, briefs }

    all_classes = vim.tbl_extend("error", all_classes, classes)
  end

  local doc_lines = {} ---@type string[]
  for _, file in vim.spairs(config.files) do
    local filepath = type(file) == "string" and file or file[1]
    print("    Generating docs for:", filepath)
    local classes, funs, briefs =
      file_res[filepath][1], file_res[filepath][2], file_res[filepath][3]
    local section = make_section(file, config)
    table.insert(
      doc_lines,
      renderer.render_section(section, briefs, funs, classes, all_classes, config)
    )
  end

  renderer.append_modeline(doc_lines)

  local fname = vim.fs.joinpath(".", "doc", config.name .. ".txt")
  print("Writing to:", fname)
  local f, err = io.open(fname, "w")
  if f == nil then error(string.format("failed to open file: %s\n%s", fname, err)) end

  for _, x in ipairs(doc_lines) do
    f:write(x)
  end
  f:close()
end

return M
