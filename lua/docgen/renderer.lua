local parse_md = require("docgen.grammar.markdown").parse_markdown

local M = {}

local TEXT_WIDTH = 78
local TAB_WIDTH = 4
local TAB = string.rep(" ", TAB_WIDTH)

-- luacheck: ignore 211
---@diagnostic disable-next-line: unused-local, unused-function
local function string_literal(str)
  str = string.gsub(str, "\n", "\\n")
  str = string.gsub(str, "\t", "\\t")
  str = string.gsub(str, " ", "·")
  return str
end

--- Wrap text to a given width based on indentation. Treats `inline code` as a
--- single word to avoid splitting it during wrapping.
---@param text string
---@param start_indent integer number of spaces to indent the first line
---@param indents integer number of spaces to indent subsequent lines
---@return string
local text_wrap = function(text, start_indent, indents)
  local lines = {}
  local sindent = string.rep(" ", start_indent)
  local indent = string.rep(" ", indents)
  local line = sindent

  local i = 1
  while i <= #text do
    local word ---@type string

    if text:sub(i, i) == "`" then
      local code_end_idx = text:find("`", i + 1)
      if code_end_idx then
        word = text:sub(i, code_end_idx)
        local _, next_word_start = text:find("%s+", code_end_idx + 1)
        if next_word_start then
          word = text:sub(i, next_word_start - 1)
          i = next_word_start + 1
        else
          i = code_end_idx + 1
        end
      else
        word = text:sub(i)
        i = #text + 1
      end
    else
      local space_start_idx, space_end_idx = text:find("%s+", i)
      if space_start_idx then
        word = text:sub(i, space_start_idx - 1)
        i = space_end_idx + 1
      else
        word = text:sub(i)
        i = #text + 1
      end
    end

    if line == sindent then
      line = sindent .. word
    elseif #line + #word + 1 > TEXT_WIDTH then
      table.insert(lines, line)
      line = indent .. word
    else
      line = line .. " " .. word
    end
  end

  table.insert(lines, line)
  return table.concat(lines, "\n")
end

---@param ty string
---@param classes table<string, docgen.parser.class>
---@return docgen.parser.class?
local function get_type_class(ty, classes)
  if not classes then return end
  -- extract type from optional annotation or list annotation
  local cty = ty:gsub("%s*|%s*nil", "?"):gsub("?$", ""):gsub("%[%]$", "")
  return classes[cty]
end

---@param ty string
---@param generics table<string,string>
---@return string
local function replace_generics(ty, generics)
  if ty:sub(-2) == "[]" then
    local ty0 = ty:sub(1, -3)
    if generics[ty0] then return generics[ty0] .. "[]" end
  elseif ty:sub(-1) == "?" then
    local ty0 = ty:sub(1, -2)
    if generics[ty0] then return generics[ty0] .. "?" end
  end

  return generics[ty] or ty
end

---@param name string
---@return string
local function format_field_name(name)
  local opt
  name, opt = name:match("^([^?]*)(%??)$")
  return string.format("{%s}%s", name, opt)
end

---@param ty string
---@param generics? table<string,string>
---@param default? string
---@return string
local function render_type(ty, generics, default)
  if generics then ty = replace_generics(ty, generics) end
  ty = ty:gsub("%s*|%s*nil", "?")
  ty = ty:gsub("nil%s*|%s*(.*)", "%1?")
  ty = ty:gsub("%s*|%s*", "|")
  if default then return string.format("(`%s`, default: %s)", ty, default) end
  return string.format("(`%s`)", ty)
end

---@param desc? string
---@return string, string?
local function get_default(desc)
  if not desc then return "", nil end

  -- TODO: capture `)` if inside backticks
  -- eg: `(default: `vim.loop.cwd()`)`  ->  `vim.loop.cwd()`
  local default = desc:match("\n?%s*%([dD]efault: *([^)]+)%)$")
  if default then desc = desc:gsub("\n?%s*%([dD]efault: *[^)]+%)$", "") end

  return desc, default
end

---@param class docgen.parser.class
---@param classes table<string, docgen.parser.class>
local function resolve_class_parents(class, classes)
  local parents = {} ---@type string[]

  local cls = class
  while cls.parent and classes[cls.parent] do
    local parent = classes[cls.parent] ---@type docgen.parser.class
    if parent.nodoc or parent.access then break end
    table.insert(parents, parent.name)
    cls = parent
  end

  for _, c in ipairs(parents) do
    local child_fields = vim
      .iter(class.fields)
      :map(function(f)
        return f.name
      end)
      :totable()

    for _, field in ipairs(classes[c].fields) do
      if not vim.tbl_contains(child_fields, field.name) then table.insert(class.fields, field) end
    end
  end
end

---@param obj docgen.parser.field|docgen.parser.param|docgen.parser.return
---@param classes table<string, docgen.parser.class>
local function inline_type(obj, classes)
  local ty = obj.type
  if not ty then return end

  local cls = get_type_class(ty, classes)
  if not cls or cls.nodoc then return end

  obj.desc = obj.desc or ""

  if not cls.inlinedoc then
    if cls.nodoc or cls.access then
      error(
        string.format(
          "Class `%s` is not to be documented as a parameter/field/return value.\n"
            .. "Use `---@inlinedoc` or remove `---@nodoc` or access modifiers.",
          cls.name
        )
      )
    end

    -- add as a tag if not already done when not inlined
    local tag = string.format("|%s|", cls.name)
    if obj.desc:find(tag) then return end

    local period = (obj.desc == "" or vim.endswith(obj.desc, ".")) and "" or "."
    obj.desc = string.format("%s%s See %s", obj.desc, period, tag)
    return
  end

  local ty_is_opt = (ty:match("%?$") or ty:match("%s*|%s*nil$")) ~= nil
  local ty_is_list = (ty:match("%[%]$")) ~= nil
  ty = ty_is_opt and "table?" or (ty_is_list and "table[]" or "table")

  local desc = ""
  if cls.desc then
    desc = cls.desc
  elseif obj.desc == "" then
    if ty_is_list then
      desc = "A list of objects with the following fields:"
    else
      desc = "A table with the following fields:"
    end
  end

  resolve_class_parents(cls, classes)
  local cls_descs = {}
  for _, field in ipairs(cls.fields) do
    if not field.access and not vim.startswith(field.name, "_") then
      local fdesc, fdefault = get_default(field.desc)
      local field_ty = render_type(field.type, nil, fdefault)
      local field_name = format_field_name(field.name)
      table.insert(cls_descs, string.format("- %s %s %s", field_name, field_ty, fdesc))
    end
  end

  desc = desc .. "\n" .. table.concat(cls_descs, "\n")
  obj.type = ty
  obj.desc = desc
end

---@param objs (docgen.parser.field | docgen.parser.param)[]
---@param generics? table<string, string>
---@param classes table<string, docgen.parser.class>
---@return string
local function render_fields_or_params(objs, generics, classes)
  local res = {}

  objs = vim
    .iter(objs)
    :filter(function(p)
      return not p.nodoc
        and not p.access
        and not vim.tbl_contains({ "_", "self" }, p.name)
        and not vim.startswith(p.name, "_")
    end)
    :totable()

  local indent = 0
  for _, p in ipairs(objs) do
    if p.type or p.desc then indent = math.max(indent, #p.name + 3) end
  end

  local indent_offset = indent + 9
  for _, obj in ipairs(objs) do
    local desc, default = get_default(obj.desc)
    obj.desc = desc

    inline_type(obj, classes)
    desc = obj.desc

    local fname = obj.kind == "operator" and string.format("op(%s)", obj.name)
      or format_field_name(obj.name)
    local pname = string.format("%s  • %-" .. indent .. "s", TAB, fname)

    if obj.type then
      local pty = render_type(obj.type, generics, default)

      if desc then
        table.insert(res, pname)
        if #pty > TEXT_WIDTH - indent then
          vim.list_extend(res, { " ", pty, "\n" })
          table.insert(res, M.render_markdown(desc, indent_offset, indent_offset))
          table.insert(res, "\n")
        else
          desc = string.format("%s %s", pty, desc)
          desc = M.render_markdown(desc, #pname, indent_offset):gsub("^ *", "")
          table.insert(res, string.format(" %s\n", desc))
        end
      else
        table.insert(res, string.format("%s %s\n", pname, pty))
      end
    else
      if desc then
        table.insert(res, pname)
        table.insert(res, M.render_markdown(desc, 1, indent_offset))
        table.insert(res, "\n")
      end
    end
  end

  return table.concat(res)
end

---@param class docgen.parser.class
---@param classes table<string, docgen.parser.class>
---@return string?
local function render_class(class, classes)
  if class.access or class.nodoc or class.inlinedoc then return end

  local res = {}

  table.insert(res, string.format("*%s*\n", class.name))

  if class.parent then
    local parent = classes[class.parent]
    if not parent then
      error(string.format("Parent class %s of %s is not found", class.parent, class.name))
    end
    if parent.inlinedoc then
      resolve_class_parents(class, classes)
    else
      local text = string.format("Extends |%s|", class.parent)
      table.insert(res, M.render_markdown(text, 0, 0))
      table.insert(res, "\n")
    end
  end

  if class.desc then
    table.insert(res, M.render_markdown(class.desc, TAB_WIDTH, TAB_WIDTH))
    table.insert(res, "\n")
  end

  local fields_text = render_fields_or_params(class.fields, nil, classes)
  if not fields_text:match("^%s*$") then
    table.insert(res, string.format("\n%sFields: ~\n", TAB))
    table.insert(res, fields_text)
    table.insert(res, "\n")
  end

  return table.concat(res)
end

---@param classes table<string, docgen.parser.class>
---@param all_classes table<string, docgen.parser.class>
---@return string
M.render_classes = function(classes, all_classes)
  local res = {}
  for _, class in vim.spairs(classes) do
    local class_desc = render_class(class, all_classes)
    if class_desc and not class_desc:match("^%s*$") then table.insert(res, class_desc) end
  end
  return table.concat(res)
end

---@param fun docgen.parser.fun
---@param section docgen.section
---@return string?
local function render_fun_header(fun, section)
  local res = {}

  local params = {}
  for _, param in ipairs(fun.params or {}) do
    if param.name ~= "self" then table.insert(params, format_field_name(param.name)) end
  end

  local name = fun.classvar and string.format("%s:%s", fun.classvar, fun.name)
    or string.format("%s.%s", section.fn_prefix, fun.name)
  local param_str = table.concat(params, ", ")
  local proto = fun.table and name or string.format("%s(%s)", name, param_str)

  local fn_suffix = fun.table and "" or "()"
  local tag
  if fun.classvar then
    tag = string.format("*%s:%s%s*", fun.classvar, fun.name, fn_suffix)
  else
    tag = string.format("*%s.%s%s*", section.tag, fun.name, fn_suffix)
  end

  local header_width = #proto + #tag
  if header_width > TEXT_WIDTH - (TAB_WIDTH * 2) then
    table.insert(res, string.format("%" .. TEXT_WIDTH .. "s\n", tag))
    local nm, pargs = proto:match("([^(]+%()(.*)") -- `fn_name(` and `arg1, arg2, ...)`
    table.insert(res, nm)
    table.insert(res, text_wrap(pargs, 0, #nm))
  else
    local pad = TEXT_WIDTH - header_width
    table.insert(res, string.format("%s%s%s", proto, string.rep(" ", pad), tag))
  end

  return table.concat(res)
end

---@param returns docgen.parser.return[]
---@param generics table<string, string>
---@param classes table<string, docgen.parser.class>
---@return string
local function render_fun_returns(returns, generics, classes)
  local res = {}

  for _, ret in ipairs(returns) do
    inline_type(ret, classes)

    local blk = {} ---@type string[]
    if ret.type then table.insert(blk, render_type(ret.type, generics)) end
    table.insert(blk, ret.desc or "")

    local offset = TAB_WIDTH * 2
    table.insert(res, M.render_markdown(table.concat(blk, " "), offset, offset))
    table.insert(res, "\n")
  end

  return table.concat(res)
end

---@param fun docgen.parser.fun
---@param config? docgen.FunConfig
local function xform_fn(fun, config)
  if config and config.fn_xform then
    config.fn_xform(fun)
    return
  end
end

---@param fun docgen.parser.fun
---@param classes table<string, docgen.parser.class>
---@param section docgen.section
---@param config? docgen.FunConfig
---@return string?
local function render_fun(fun, classes, section, config)
  if fun.access or fun.deprecated or fun.nodoc then return end
  if vim.startswith(fun.name, "_") or fun.name:find("[:.]_") then return end

  local res = {}
  local bullet_offset = TAB_WIDTH * 2

  xform_fn(fun, config)

  table.insert(res, render_fun_header(fun, section))
  table.insert(res, "\n")

  if fun.desc then
    table.insert(res, M.render_markdown(fun.desc, TAB_WIDTH, TAB_WIDTH))
    table.insert(res, "\n\n")
  end

  if fun.notes then
    table.insert(res, string.format("%sNote: ~\n", TAB))
    for _, note in ipairs(fun.notes) do
      table.insert(
        res,
        string.format("%s  • %s", TAB, M.render_markdown(note.desc, 0, bullet_offset))
      )
      table.insert(res, "\n")
    end
    table.insert(res, "\n")
  end

  if fun.params and #fun.params > 0 then
    local param_text = render_fields_or_params(fun.params, fun.generics, classes)
    if not param_text:match("^%s*$") then
      table.insert(res, string.format("%sParameters: ~\n", TAB))
      table.insert(res, param_text)
      table.insert(res, "\n")
    end
  end

  if fun.returns and #fun.returns > 0 then
    local return_text = render_fun_returns(fun.returns, fun.generics, classes)
    if #fun.returns > 1 then
      table.insert(res, string.format("%sReturn (multiple): ~\n", TAB))
    else
      table.insert(res, string.format("%sReturn: ~\n", TAB))
    end
    if not return_text:match("^%s*$") then
      table.insert(res, return_text)
      table.insert(res, "\n")
    end
  end

  if fun.see and #fun.see > 0 then
    table.insert(res, string.format("%sSee also: ~\n", TAB))
    for _, s in ipairs(fun.see) do
      table.insert(
        res,
        string.format("%s  • %s\n", TAB, M.render_markdown(s.desc, 0, bullet_offset))
      )
    end
    table.insert(res, "\n")
  end

  return table.concat(res)
end

---@param funs docgen.parser.fun[]
---@param classes table<string, docgen.parser.class>
---@param section docgen.section
---@param config? docgen.FunConfig
---@return string
M.render_funs = function(funs, classes, section, config)
  local res = {}
  for _, fun in ipairs(funs) do
    local fun_doc = render_fun(fun, classes, section, config)
    if fun_doc then table.insert(res, fun_doc) end
  end
  return table.concat(res)
end

---@param paragraph string
---@param start_indent integer
---@param indents integer
---@param next_block docgen.grammar.markdown.result?
---@return string
local function render_paragraph(paragraph, start_indent, indents, next_block)
  local res = {}
  for para_line in vim.gsplit(paragraph, "\n") do
    table.insert(res, text_wrap(para_line, start_indent, indents))
    table.insert(res, "\n")
  end

  if next_block and next_block.kind == "paragraph" then table.insert(res, "\n") end
  return table.concat(res)
end

---@param ul docgen.grammar.markdown.ul
---@param lines string[]
---@param start_indent integer
---@param indent integer
---@param list_marker_size integer?
local function render_ul(ul, lines, start_indent, indent, list_marker_size)
  list_marker_size = list_marker_size or 2 -- len('• ')
  local sep = ul.tight and "\n" or "\n\n"

  for _, items in ipairs(ul.items) do
    local marker_ws = string.rep(" ", start_indent)
    local marker = string.format("%s•%s", marker_ws, string.rep(" ", list_marker_size - 1))

    local list_item = M._render_markdown(
      items,
      indent + list_marker_size,
      indent + list_marker_size,
      list_marker_size
    ):gsub("^ *", "")

    table.insert(lines, string.format("%s%s%s", marker, list_item, sep))
    start_indent = indent
  end
end

---@param ol docgen.grammar.markdown.ol
---@param lines string[]
---@param start_indent integer
---@param indent integer
local function render_ol(ol, lines, start_indent, indent)
  local sep = ol.tight and "\n" or "\n\n"

  local max_marker = ol.start + #ol.items - 1
  local list_marker_size = #tostring(max_marker) + 1 + 1 -- number + dot + space

  for i, items in ipairs(ol.items) do
    local marker_ws = string.rep(" ", start_indent)
    local marker_num = tostring(ol.start + i - 1) .. "."
    local marker = string.format(
      "%s%s%s",
      marker_ws,
      marker_num,
      string.rep(" ", list_marker_size - #marker_num)
    )

    local list_item = M._render_markdown(
      items,
      indent + list_marker_size,
      indent + list_marker_size,
      list_marker_size
    ):gsub("^ *", "")

    table.insert(lines, string.format("%s%s%s", marker, list_item, sep))
    start_indent = indent
  end
end

---@param markdown docgen.grammar.markdown.result[]
---@param start_indent integer indentation amount for the first line
---@param indent integer indentation amount for subsequent lines
---@param list_marker_size integer? size of list marker including alignment padding minus indentation
---@return string
M._render_markdown = function(markdown, start_indent, indent, list_marker_size)
  local res = {} ---@type string[]

  for i, block in ipairs(markdown) do
    local tabs = string.rep(" ", start_indent)
    local next_block = markdown[i + 1]

    if block.kind == "paragraph" then
      ---@cast block docgen.grammar.markdown.paragraph
      table.insert(res, render_paragraph(block.text, start_indent, indent, next_block))
    elseif block.kind == "code" then
      ---@cast block docgen.grammar.markdown.code_block
      table.insert(res, string.format("%s>%s\n", tabs, block.lang or ""))
      for line in vim.gsplit(vim.trim(block.code):gsub("\n$", ""), "\n") do
        table.insert(res, string.format("%s%s%s\n", tabs, TAB, line))
      end
      table.insert(res, string.format("%s<\n", tabs))
    elseif block.kind == "pre" then
      ---@cast block docgen.grammar.markdown.pre_block
      for line in vim.gsplit(vim.trim(block.lines):gsub("\n$", ""), "\n") do
        table.insert(res, tabs .. line .. "\n")
      end
    elseif block.kind == "ul" then
      ---@cast block docgen.grammar.markdown.ul
      render_ul(block, res, start_indent, indent, list_marker_size)
    elseif block.kind == "ol" then
      ---@cast block docgen.grammar.markdown.ol
      render_ol(block, res, start_indent, indent)
    end

    start_indent = indent
  end

  return (table.concat(res):gsub("[ \n]+$", ""))
end

---@param markdown string
---@param start_indent integer indentation amount for the first line
---@param indent integer indentation amount for subsequent lines
---@return string
M.render_markdown = function(markdown, start_indent, indent)
  local md = parse_md(markdown)
  return M._render_markdown(md, start_indent, indent, nil)
end

---@param briefs string[]
---@return string
M.render_briefs = function(briefs)
  local res = {}
  for _, brief in ipairs(briefs) do
    table.insert(res, M.render_markdown(brief, 0, 0))
  end
  return table.concat(res)
end

---@param section docgen.section
---@param briefs string[]
---@param funs docgen.parser.fun[]
---@param classes table<string, docgen.parser.class>
---@param all_classes table<string, docgen.parser.class>
---@param config docgen.Config
---@return string
M.render_section = function(section, briefs, funs, classes, all_classes, config)
  local res = {}

  local brief_tag = string.format("*%s*", section.tag)
  table.insert(res, string.rep("=", TEXT_WIDTH))
  table.insert(res, "\n")
  table.insert(
    res,
    string.format("%s%" .. (TEXT_WIDTH - #section.title) .. "s\n", section.title, brief_tag)
  )

  local briefs_text = M.render_briefs(briefs)
  if not briefs_text:match("^%s*$") then
    table.insert(res, "\n")
    table.insert(res, briefs_text)
    table.insert(res, "\n")
  end

  local classes_text = M.render_classes(classes, all_classes)
  if not classes_text:match("^%s*$") then
    table.insert(res, "\n")
    table.insert(res, classes_text)
  end

  local funs_text = M.render_funs(funs, classes, section, config.fn_config)
  if not funs_text:match("^%s*$") then
    table.insert(res, "\n")
    table.insert(res, funs_text)
  end

  return table.concat(res)
end

---@param doc_lines string[]
function M.append_modeline(doc_lines)
  table.insert(
    doc_lines,
    string.format(
      " vim:tw=%d:ts=%d:sw=%d:sts=%d:et:ft=help:norl:\n",
      TEXT_WIDTH,
      TAB_WIDTH * 2,
      TAB_WIDTH,
      TAB_WIDTH
    )
  )
end

return M
