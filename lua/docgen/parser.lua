local luacats_grammar = require("docgen.grammar.luacats")

--- @class (private) docgen.parser.param
--- @field name string
--- @field type string
--- @field desc? string

--- @class (private) docgen.parser.return
--- @field name string
--- @field type string
--- @field desc? string

--- @class (private) docgen.parser.note
--- @field desc? string

--- @class (private) docgen.parser.brief
--- @field kind 'brief'
--- @field desc? string

--- @class (private) docgen.parser.alias
--- @field kind 'alias'
--- @field type string[]
--- @field desc? string

--- @class (private) docgen.parser.fun
--- @field name string
--- @field params docgen.parser.param[]
--- @field returns docgen.parser.return[]
--- @field desc string
--- @field access? 'private'|'package'|'protected'
--- @field class? string
--- @field module? string
--- @field modvar? string
--- @field classvar? string
--- @field deprecated? true
--- @field since? string -- need?
--- @field attrs? string[] -- need?
--- @field nodoc? true
--- @field generics? table<string,string>
--- @field table? true
--- @field notes? docgen.parser.note[]
--- @field see? docgen.parser.note[]

--- @class (private) docgen.parser.field
--- @field name string
--- @field type string
--- @field desc string
--- @field access? 'private'|'package'|'protected'

--- @class (private) docgen.parser.class
--- @field kind 'class'
--- @field parent? string
--- @field name string
--- @field desc string
--- @field nodoc? true
--- @field inlinedoc? true
--- @field access? 'private'|'package'|'protected'
--- @field fields docgen.parser.field[]
--- @field notes? string[]

--- @class (private) docgen.parser.State
--- @field doc_lines? string[]
--- @field cur_obj? docgen.parser.obj
--- @field last_doc_item? docgen.parser.param|docgen.parser.return|docgen.parser.note
--- @field last_doc_item_indent? integer

--- @alias docgen.parser.obj
--- | docgen.parser.class
--- | docgen.parser.fun
--- | docgen.parser.brief
--- | docgen.parser.alias

--- If we collected any `---` lines. Add them to the existing (or new) object
--- Used for function/class descriptions and multiline param descriptions.
--- @param state docgen.parser.State
local function add_doc_lines_to_obj(state)
  if state.doc_lines then
    state.cur_obj = state.cur_obj or {}
    local cur_obj = assert(state.cur_obj)
    local txt = table.concat(state.doc_lines, "\n")
    if cur_obj.desc then
      cur_obj.desc = cur_obj.desc .. "\n" .. txt
    else
      cur_obj.desc = txt
    end
    state.doc_lines = nil
  end
end

--- @param line string
--- @param state docgen.parser.State
local function process_doc_line(line, state)
  line = line:sub(4):gsub("^%s+@", "@")

  local parsed = luacats_grammar:match(line)

  if not parsed or parsed.kind == "eval" then
    if parsed and parsed.kind == "eval" then
      local f, err = loadstring(parsed.desc)
      if err or f == nil then error("Error evaluating: " .. parsed.desc .. " - " .. err) end
      line = "\n" .. f()
    end

    if line:match("^ ") then line = line:sub(2) end

    if state.last_doc_item then
      if not state.last_doc_item_indent then
        state.last_doc_item_indent = #line:match("^%s*") + 1
      end
      state.last_doc_item.desc = (state.last_doc_item.desc or "")
        .. "\n"
        .. line:sub(state.last_doc_item_indent or 1)
    else
      state.doc_lines = state.doc_lines or {}
      table.insert(state.doc_lines, line)
    end
    return
  end

  state.last_doc_item_indent = nil
  state.last_doc_item = nil
  state.cur_obj = state.cur_obj or {}
  local cur_obj = assert(state.cur_obj)

  local kind = parsed.kind

  if kind == "brief" then
    state.cur_obj = {
      kind = "brief",
      desc = parsed.desc,
    }
  elseif kind == "class" then
    --- @cast parsed docgen.grammar.luacats.Class
    cur_obj.kind = "class"
    cur_obj.name = parsed.name
    cur_obj.parent = parsed.parent
    cur_obj.access = parsed.access
    cur_obj.desc = state.doc_lines and table.concat(state.doc_lines, "\n") or nil
    state.doc_lines = nil
    cur_obj.fields = {}
  elseif kind == "field" then
    --- @cast parsed docgen.grammar.luacats.Field
    parsed.desc = parsed.desc or state.doc_lines and table.concat(state.doc_lines, "\n") or nil
    if parsed.desc then parsed.desc = vim.trim(parsed.desc) end
    table.insert(cur_obj.fields, parsed)
    state.doc_lines = nil
  elseif kind == "operator" then
    parsed.desc = parsed.desc or state.doc_lines and table.concat(state.doc_lines, "\n") or nil
    if parsed.desc then parsed.desc = vim.trim(parsed.desc) end
    table.insert(cur_obj.fields, parsed)
    state.doc_lines = nil
  elseif kind == "param" then
    state.last_doc_item_indent = nil
    cur_obj.params = cur_obj.params or {}
    if vim.endswith(parsed.name, "?") then
      parsed.name = parsed.name:sub(1, -2)
      parsed.type = parsed.type .. "?"
    end
    state.last_doc_item = {
      name = parsed.name,
      type = parsed.type,
      desc = parsed.desc,
    }
    table.insert(cur_obj.params, state.last_doc_item)
  elseif kind == "return" then
    cur_obj.returns = cur_obj.returns or {}
    for _, t in ipairs(parsed) do
      table.insert(cur_obj.returns, {
        name = t.name,
        type = t.type,
        desc = parsed.desc,
      })
    end
    state.last_doc_item_indent = nil
    state.last_doc_item = cur_obj.returns[#cur_obj.returns]
  elseif kind == "private" then
    cur_obj.access = "private"
  elseif kind == "package" then
    cur_obj.access = "package"
  elseif kind == "protected" then
    cur_obj.access = "protected"
  elseif kind == "deprecated" then
    cur_obj.deprecated = true
  elseif kind == "inlinedoc" then
    cur_obj.inlinedoc = true
  elseif kind == "nodoc" then
    cur_obj.nodoc = true
  elseif kind == "since" then
    cur_obj.since = parsed.desc
  elseif kind == "see" then
    cur_obj.see = cur_obj.see or {}
    table.insert(cur_obj.see, { desc = parsed.desc })
  elseif kind == "note" then
    state.last_doc_item_indent = nil
    state.last_doc_item = {
      desc = parsed.desc,
    }
    cur_obj.notes = cur_obj.notes or {}
    table.insert(cur_obj.notes, state.last_doc_item)
  elseif kind == "type" then
    cur_obj.desc = parsed.desc
    parsed.desc = nil
    parsed.kind = nil
    cur_obj.type = parsed
  elseif kind == "alias" then
    state.cur_obj = {
      kind = "alias",
      desc = parsed.desc,
    }
  elseif kind == "enum" then
    -- TODO
    state.doc_lines = nil
  elseif
    vim.tbl_contains({
      "diagnostic",
      "cast",
      "overload",
      "meta",
    }, kind)
  then
    -- Ignore
    return
  elseif kind == "generic" then
    cur_obj.generics = cur_obj.generics or {}
    cur_obj.generics[parsed.name] = parsed.type or "any"
  else
    error("Unhandled" .. vim.inspect(parsed))
  end
end

--- @param fun docgen.parser.fun
--- @return docgen.parser.field
local function fun2field(fun)
  local parts = { "fun(" }
  for _, p in ipairs(fun.params or {}) do
    parts[#parts + 1] = string.format("%s: %s", p.name, p.type)
  end
  parts[#parts + 1] = ")"
  if fun.returns then
    parts[#parts + 1] = ": "
    local tys = {} --- @type string[]
    for _, p in ipairs(fun.returns) do
      tys[#tys + 1] = p.type
    end
    parts[#parts + 1] = table.concat(tys, ", ")
  end

  return {
    name = fun.name,
    type = table.concat(parts, ""),
    access = fun.access,
    desc = fun.desc,
  }
end

--- @param line string
--- @param state docgen.parser.State
--- @param classes table<string,docgen.parser.class>
--- @param classvars table<string,string>
--- @param has_indent boolean
local function process_lua_line(line, state, classes, classvars, has_indent)
  if state.cur_obj and state.cur_obj.kind == "class" then
    local nm = line:match("^local%s+([a-zA-Z0-9_]+)%s*=")
    if nm then classvars[nm] = state.cur_obj.name end
    return
  end

  do
    local parent_tbl, sep, fun_or_meth_nm =
      line:match("^function%s+([a-zA-Z0-9_]+)([.:])([a-zA-Z0-9_]+)%s*%(")
    if parent_tbl then
      -- Have a decl. Ensure cur_obj
      state.cur_obj = state.cur_obj or {}
      local cur_obj = assert(state.cur_obj)

      -- Match `Class:foo` methods for defined classes
      local class = classvars[parent_tbl]
      if class then
        --- @cast cur_obj docgen.parser.fun
        cur_obj.name = fun_or_meth_nm
        cur_obj.class = class
        cur_obj.classvar = parent_tbl
        -- Add self param to methods
        if sep == ":" then
          cur_obj.params = cur_obj.params or {}
          table.insert(cur_obj.params, 1, {
            name = "self",
            type = class,
          })
        end

        -- Add method as the field to the class
        table.insert(classes[class].fields, fun2field(cur_obj))
        return
      end

      -- Match `M.foo`
      if cur_obj and parent_tbl == cur_obj.modvar then
        cur_obj.name = fun_or_meth_nm
        return
      end
    end
  end

  do
    -- Handle: `function A.B.C.foo(...)`
    local fn_nm = line:match("^function%s+([.a-zA-Z0-9_]+)%s*%(")
    if fn_nm then
      state.cur_obj = state.cur_obj or {}
      state.cur_obj.name = fn_nm
      return
    end
  end

  do
    -- Handle: `M.foo = {...}` where `M` is the modvar
    local parent_tbl, tbl_nm = line:match("([a-zA-Z_]+)%.([a-zA-Z0-9_]+)%s*=")
    if state.cur_obj and parent_tbl and parent_tbl == state.cur_obj.modvar then
      state.cur_obj.name = tbl_nm
      -- state.cur_obj.table = true -- jt: not sure about enforcing this
      return
    end
  end

  do
    -- Handle: `foo = {...}`
    local tbl_nm = line:match("^([a-zA-Z0-9_]+)%s*=")
    if tbl_nm and not has_indent then
      state.cur_obj = state.cur_obj or {}
      state.cur_obj.name = tbl_nm
      state.cur_obj.table = true
      return
    end
  end

  if state.cur_obj then
    if line:find("^%s*%-%- luacheck:") then
      state.cur_obj = nil
    elseif line:find("^%s*local%s+") then
      state.cur_obj = nil
    elseif line:find("^%s*return%s+") then
      state.cur_obj = nil
    elseif line:find("^%s*[a-zA-Z_.]+%(%s+") then
      state.cur_obj = nil
    end
  end
end

--- Determine the table name used to export functions of a module
--- Usually this is `M`.
--- @param str string
--- @return string?
local function determine_modvar(str)
  local modvar --- @type string?
  for line in vim.gsplit(str, "\n") do
    do
      --- @type string?
      local m = line:match("^return%s+([a-zA-Z_]+)")
      if m then modvar = m end
    end
    do
      --- @type string?
      local m = line:match("^return%s+setmetatable%(([a-zA-Z_]+),")
      if m then modvar = m end
    end
  end
  return modvar
end

--- @param obj docgen.parser.obj
--- @param funs docgen.parser.fun[]
--- @param classes table<string,docgen.parser.class>
--- @param briefs string[]
--- @param uncommitted docgen.parser.obj[]
local function commit_obj(obj, classes, funs, briefs, uncommitted)
  local commit = false
  if obj.kind == "class" then
    --- @cast obj docgen.parser.class
    if not classes[obj.name] then
      classes[obj.name] = obj
      commit = true
    end
  elseif obj.kind == "alias" then
    -- Just pretend
    commit = true
  elseif obj.kind == "brief" then
    --- @cast obj docgen.parser.brief`
    briefs[#briefs + 1] = obj.desc
    commit = true
  else
    --- @cast obj docgen.parser.fun`
    if obj.name then
      funs[#funs + 1] = obj
      commit = true
    end
  end
  if not commit then table.insert(uncommitted, obj) end
  return commit
end

---@param lines string[]
---@param idx integer
---@return integer # line index after skipping the multiline comment
local function skip_multiline_comment(lines, idx)
  if lines[idx]:match("^ *%-%-%[%[") then
    while lines[idx] and not lines[idx]:match("]]") do
      idx = idx + 1
      assert(idx < #lines, "Unterminated multiline comment")
    end
  end
  return idx
end

local M = {}

---comment
---@param str string input string
---@param filename string
---@return table<string, docgen.parser.class>
---@return docgen.parser.fun[]
---@return string[]
---@return docgen.parser.alias|docgen.parser.brief|docgen.parser.class|docgen.parser.fun[]
function M.parse_str(str, filename)
  local funs = {} --- @type docgen.parser.fun[]
  local classes = {} --- @type table<string,docgen.parser.class>
  local briefs = {} --- @type docgen.grammar.markdown.result[]
  -- Keep track of any partial objects we don't commit
  local uncommitted = {} --- @type docgen.parser.obj[]

  local mod_return = determine_modvar(str)

  --- @type string
  local module = filename:match(".*/lua/([a-z_][a-z0-9_/]+)%.lua") or filename
  module = module:gsub("/", ".")

  local classvars = {} --- @type table<string,string>
  local state = {} --- @type docgen.parser.State

  local lines = vim.split(str, "\n")

  local i = 1
  while i <= #lines do
    i = skip_multiline_comment(lines, i)
    local line = lines[i]

    local has_indent = line:match("^%s+") ~= nil
    line = vim.trim(line)
    if vim.startswith(line, "---") then
      local ok, res = pcall(process_doc_line, line, state)
      if not ok then
        error(string.format("Error processing %s @ line: %s\n%s", filename, line, res))
      end
    else
      add_doc_lines_to_obj(state)

      if state.cur_obj then
        state.cur_obj.modvar = mod_return
        state.cur_obj.module = module
      end

      process_lua_line(line, state, classes, classvars, has_indent)

      -- Commit the object
      local cur_obj = state.cur_obj
      if cur_obj then
        if not commit_obj(cur_obj, classes, funs, briefs, uncommitted) then
          --- @diagnostic disable-next-line:inject-field
          cur_obj.line = line
        end
      end

      state = {}
    end
    i = i + 1
  end

  return classes, funs, briefs, uncommitted
end

--- @param filename string
function M.parse(filename)
  local f = assert(io.open(filename, "r"))
  local txt = f:read("*all")
  f:close()

  return M.parse_str(txt, filename)
end

return M
