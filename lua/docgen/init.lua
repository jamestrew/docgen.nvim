-- luacheck: push ignore 631
---@brief
--- Generate vimdoc for your Neovim plugin using LuaCATS (and a few extra) annotations
--- within your lua files.
---
--- Getting started with `docgen.nvim`
--- 1. Create a script for `docgen.nvim`
---     eg.
---     ```lua
---     -- script/gendoc.lua
---     vim.opt.rtp:append "."
---
---     -- `docgen.nvim` installation location
---     vim.env.DOCGEN_PATH = vim.env.DOCGEN_PATH or ".deps/docgen.nvim"
---
---     -- bootstrap script will git clone `docgen.nvim` and place it in your
---     -- runtimepath automatically
---     -- if the `DOCGEN_PATH` env variable is defined, it will use the defined
---     -- path instead of cloning another copy
---     load(vim.fn.system "curl -s https://raw.githubusercontent.com/jamestrew/docgen.nvim/master/scripts/bootstrap.lua")()
---
---     -- main entry point
---     require("docgen").run({
---       name = "my_plugin", -- will be used to generate `doc/my_plugin.txt`
---       files = {
---         -- list the file you want used to generate vimdoc *IN ORDER* that they
---         -- will appear in the vimdoc
---
---         ".lua/my_plugin/init.lua", -- can simply list file(s)
---
---         -- can optionally provide configuration for each file
---         {
---           ".lua/my_plugin/utils.lua",
---           title = "UTIL",
---         },
---       },
---     })
---     ```
---     See [docgen.run()] for more information on the configuration options.
--- 2. Run your script above from your shell
---     eg. `nvim -l script/gendoc.lua`
--- 3. That's pretty much it. Any LuaCATS annotations in the files you listed will
---    be used to generate the vimdoc for your plugin.
---
--- Each file provided to `require("docgen").run` can have up to three parts:
--- 1. A section header (which always exists) like so
---    ```
---    ==========================================================================
---    DOCGEN                                                     *docgen.nvim*
---    ```
---     The title of the section (on the left) and the tag (on the right) can be
---     configured via the `title` and `tag` options in [docgen.FileSection]
---     respectively.
--- 2. A briefs section to discribe the main concepts in the given file/plugin
---     (what you're reading now). See [docgen.briefs].
--- 3. Type definitions for any classes defined in the file. See [docgen.classes].
--- 4. Type definitions for any exported/public functions defined in the file. See [docgen.functions].
-- luacheck: pop

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

-- we'll see if something like this is needed later
-- ---@nodoc
-- ---@class docgen.FunConfig
-- ---@field fn_xform? fun(fn: docgen.parser.fun)

--- File section configuration provides to the `files` list in [docgen.run].
---@class docgen.FileSection
---@field [1] string filepath from which to generate the section from
---
--- title of the section
---
--- if omitted, generated from the filename
--- eg:
--- - './lua/docgen/init.lua'             -> 'DOCGEN'
--- - './lua/docgen/grammar/init.lua'     -> 'GRAMMAR'
--- - './lua/docgen/grammar/luacats.lua'  -> 'GRAMMAR_LUACATS'
---@field title string?
---
--- help tag of the section WITHOUT the asterisks
---
--- if omitted, generated from the filename
--- eg:
--- - './lua/docgen/init.lua'             -> 'docgen'
--- - './lua/docgen/grammar/init.lua'     -> 'grammar'
--- - './lua/docgen/grammar/luacats.lua'  -> 'grammar.luacats'
---@field tag string?
---
--- module prefix for functions
---
--- if omitted, generated from the filename same as `section_title` but in lowercase
---@field fn_prefix string?
---
--- tag prefix for functions, if omitted, uses section tag as prefix
---@field fn_tag_prefix string?

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

---@nodoc
---@class docgen.section
---@field title string
---@field tag string
---@field fn_prefix string
---@field fn_tag_prefix string

---@param file string|docgen.FileSection
---@return docgen.section
local function make_section(file, config)
  if type(file) == "string" then
    local title = section_title(file, config.name)
    local tag = section_tag(title, config.name)
    return {
      title = title,
      tag = tag,
      fn_prefix = title:lower(),
      fn_tag_prefix = vim.F.if_nil(config.fn_tag_prefix or tag),
    }
  end

  local path_title = section_title(file[1], config.name)
  local tag = vim.F.if_nil(file.tag, section_tag(path_title, config.name))
  return {
    title = vim.F.if_nil(file.title, path_title),
    tag = tag,
    fn_prefix = vim.F.if_nil(file.fn_prefix, path_title:lower()),
    fn_tag_prefix = vim.F.if_nil(file.fn_tag_prefix, tag),
  }
end

---@param lines string[]
---@return string
local function trim_line_endings(lines)
  local content = table.concat(lines)
  local res = {}

  for line in vim.gsplit(content, "\n") do
    table.insert(res, (line:gsub(" +$", "")))
  end
  return table.concat(res, "\n")
end

--- Main entrypoint to generate documentation
---
--- eg.
--- ```lua
--- require("docgen").run({
---   name = "docgen",
---   files = {
---     { "./lua/docgen/init.lua", tag = "docgen.nvim", fn_tag_prefix = "docgen" },
---     "./lua/docgen/parser.lua",
---     "./lua/docgen/renderer.lua",
---   },
--- })
--- ```
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
    table.insert(doc_lines, renderer.render_section(section, briefs, funs, classes, all_classes))
  end

  renderer.append_modeline(doc_lines)

  local fname = vim.fs.joinpath(".", "doc", config.name .. ".txt")
  print("Writing to:", fname)
  local f, err = io.open(fname, "w")
  if f == nil then error(string.format("failed to open file: %s\n%s", fname, err)) end

  local doc = trim_line_endings(doc_lines)
  f:write(doc)
  f:close()
end

return M
