local parse_md = require("docgen.grammar.markdown").parse_markdown

local M = {}

local TEXT_WIDTH = 78
local TAB_WIDTH = 4
local TAB = string.rep(" ", TAB_WIDTH)

---@diagnostic disable-next-line: unused-local, unused-function
local function string_literal(str)
  str = string.gsub(str, "\n", "\\n")
  str = string.gsub(str, "\t", "\\t")
  str = string.gsub(str, " ", "·")
  return str
end

---@param text string
---@param start_indent integer number of spaces to indent the first line
---@param indents integer number of spaces to indent subsequent lines
---@return string
local text_wrap = function(text, start_indent, indents)
  local lines = {}

  local sindent = string.rep(" ", start_indent)
  local indent = string.rep(" ", indents)
  local line = sindent
  for word in vim.gsplit(text, "%s+") do
    if #line + #word + 1 > TEXT_WIDTH then
      table.insert(lines, line)
      line = indent .. word
    elseif line == sindent then
      line = sindent .. word
    else
      line = line .. " " .. word
    end
  end
  table.insert(lines, line)
  return table.concat(lines, "\n")
end

---@param ty string
---@param classes table<string, docgen.luacats.parser.class>
---@return docgen.luacats.parser.class?
local function get_class(ty, classes)
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
---@return string?, string?
local function get_default(desc)
  if not desc then return end

  local default = desc:match("\n%s*%([dD]efault: ([^)]+)%)")
  if default then desc = desc:gsub("\n%s*%([dD]efault: [^)]+%)", "") end

  return desc, default
end

---@param obj docgen.luacats.parser.field|docgen.luacats.parser.param|docgen.luacats.parser.return
---@param classes table<string, docgen.luacats.parser.class>
local function inline_type(obj, classes)
  local ty = obj.type
  if not ty then return end

  local cls = get_class(ty, classes)
  if not cls or cls.nodoc then return end

  obj.desc = obj.desc or ""

  if not cls.inlinedoc then
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

  local cls_descs = {}
  for _, field in ipairs(cls.fields) do
    if not field.access then
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

---@param objs (docgen.luacats.parser.field | docgen.luacats.parser.param)[]
---@param generics table<string, string>
---@param classes table<string, docgen.luacats.parser.class>
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
  for _, p in ipairs(objs) do
    local desc, default = get_default(p.desc)
    p.desc = desc

    inline_type(p, classes)

    local fname = p.kind == "operator" and string.format("op(%s)", p.name)
      or format_field_name(p.name)
    local pname = string.format("%s  • %-" .. indent .. "s", TAB, fname)

    if p.type then
      local pty = render_type(p.type, generics, default)

      if desc then
        table.insert(res, pname)
        if #pty > TEXT_WIDTH - indent then
          vim.list_extend(res, { " ", pty, "\n" })
          local desc_md = parse_md(desc)
          table.insert(res, M.render_markdown(desc_md, indent_offset, indent_offset, nil, 0))
          table.insert(res, "\n")
        else
          desc = string.format("%s %s", pty, desc)
          local desc_md = parse_md(desc)
          table.insert(res, M.render_markdown(desc_md, 1, indent_offset, nil, 0))
          table.insert(res, "\n")
        end
      else
        table.insert(res, string.format("%s %s\n", pname, pty))
      end
    else
      if desc then
        local desc_md = parse_md(desc)
        table.insert(res, pname)
        table.insert(res, M.render_markdown(desc_md, 1, indent_offset, nil, 0))
        table.insert(res, "\n")
      end
    end
  end

  return table.concat(res)
end

---@param classes table<string, docgen.luacats.parser.class>
---@return string
M.render_classes = function(classes)
  return ""
end

---@param fun docgen.luacats.parser.fun
---@return string?
local function render_fun_header(fun)
  local res = {}

  local params = {}
  for _, param in ipairs(fun.params or {}) do
    if param.name ~= "self" then table.insert(params, format_field_name(param.name)) end
  end

  local name = fun.classvar and string.format("%s:%s", fun.classvar, fun.name) or fun.name
  local param_str = table.concat(params, ", ")
  local proto = fun.table and name or string.format("%s(%s)", name, param_str)

  local fn_suffix = fun.table and "" or "()"
  local tag
  if fun.classvar then
    tag = string.format("*%s:%s%s*", fun.classvar, fun.name, fn_suffix)
  else
    tag = string.format("*%s.%s%s*", fun.module, fun.name, fn_suffix)
  end

  local header_width = #proto + #tag
  if header_width > TEXT_WIDTH - (TAB_WIDTH * 2) then
    print("proto", proto)
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

---@param returns docgen.luacats.parser.return[]
---@param generics table<string, string>
---@param classes table<string, docgen.luacats.parser.class>
---@return string
local function render_fun_returns(returns, generics, classes)
  local res = {}

  for _, ret in ipairs(returns) do
    inline_type(ret, classes)

    local blk = {} ---@type string[]
    if ret.type then table.insert(blk, render_type(ret.type, generics)) end
    table.insert(blk, ret.desc or "")

    local offset = TAB_WIDTH * 2
    local md = parse_md(table.concat(blk, " "))
    table.insert(res, M.render_markdown(md, offset, offset, nil, 0))
  end

  return table.concat(res)
end

---@param fun docgen.luacats.parser.fun
---@param classes table<string, docgen.luacats.parser.class>
---@return string?
local function render_fun(fun, classes)
  if fun.access or fun.deprecated or fun.nodoc then return end
  if vim.startswith(fun.name, "_") or fun.name:find("[:.]_") then return end

  local res = {}
  local bullet_offset = TAB_WIDTH * 2

  table.insert(res, render_fun_header(fun))
  table.insert(res, "\n")

  if fun.desc then
    local md = parse_md(fun.desc)
    table.insert(res, M.render_markdown(md, TAB_WIDTH, TAB_WIDTH, nil, 0))
    table.insert(res, "\n\n")
  end

  if fun.notes then
    table.insert(res, string.format("%sNote: ~\n", TAB))
    for _, note in ipairs(fun.notes) do
      local md = parse_md(note.desc)
      table.insert(
        res,
        string.format("%s  • %s", TAB, M.render_markdown(md, 0, bullet_offset, nil, 0))
      )
    end
    table.insert(res, "\n\n")
  end

  if fun.params and #fun.params > 0 then
    local param_text = render_fields_or_params(fun.params, fun.generics, classes)
    if not param_text:match("^%s*$") then
      table.insert(res, string.format("%sParameters: ~\n", TAB))
      print("param_text", string_literal(param_text))
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
      table.insert(res, "\n\n")
    end
  end

  if fun.see and #fun.see > 0 then
    table.insert(res, string.format("%sSee also: ~\n", TAB))
    for _, s in ipairs(fun.see) do
      local md = parse_md(s.desc)
      table.insert(
        res,
        string.format("%s  • %s\n", TAB, M.render_markdown(md, 0, bullet_offset, nil, 0))
      )
    end
    table.insert(res, "\n\n")
  end

  return table.concat(res)
end

---@param funs docgen.luacats.parser.fun[]
---@param classes table<string, docgen.luacats.parser.class>
---@return string
M.render_funs = function(funs, classes)
  local res = {}
  for _, fun in ipairs(funs) do
    local fun_doc = render_fun(fun, classes)
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
---@param list_depth integer
local function render_ul(ul, lines, start_indent, indent, list_marker_size, list_depth)
  list_marker_size = list_marker_size or 2 -- len('• ')
  local marker_ws = string.rep(" ", list_depth * TAB_WIDTH)
  local marker = "•" .. string.rep(" ", list_marker_size - 1)
  local sep = ul.tight and "\n" or "\n\n"
  for _, item in ipairs(ul.items) do
    local list_item = M.render_markdown(
      item,
      start_indent + list_marker_size,
      indent + list_marker_size,
      list_marker_size,
      list_depth + 1
    )
    table.insert(lines, marker_ws .. marker .. list_item:gsub("^ *", "") .. sep)
  end
end

---@param ol docgen.grammar.markdown.ol
---@param lines string[]
---@param start_indent integer
---@param indent integer
---@param list_marker_size integer?
---@param list_depth integer
local function render_ol(ol, lines, start_indent, indent, list_marker_size, list_depth)
  list_marker_size = list_marker_size or 3 -- len('1. ')
  local marker_ws = string.rep(" ", start_indent)

  local max_marker = ol.start + #ol.items - 1
  list_marker_size = #tostring(max_marker) + 1 + 1 -- number + dot + space

  local sep = ol.tight and "\n" or "\n\n"
  for i, item in ipairs(ol.items) do
    local marker = tostring(ol.start + i - 1) .. "."
    marker = marker .. string.rep(" ", list_marker_size - #marker)
    local list_item = M.render_markdown(
      item,
      start_indent + list_marker_size,
      indent + list_marker_size,
      list_marker_size,
      list_depth + 1
    )
    table.insert(lines, marker_ws .. marker .. list_item:gsub("^ *", "") .. sep)
  end
end

---@param markdown docgen.grammar.markdown.result[]
---@param start_indent integer indentation amount for the first line
---@param indent integer indentation amount for list child items
---@param list_marker_size integer? size of list marker including alignment padding minus indentation
---@param list_depth integer current list depth
---@return string
M.render_markdown = function(markdown, start_indent, indent, list_marker_size, list_depth)
  local res = {} ---@type string[]
  local tabs = string.rep(" ", start_indent)

  for i, block in ipairs(markdown) do
    if block.kind == "paragraph" then ---@cast block docgen.grammar.markdown.paragraph
      table.insert(res, render_paragraph(block.text, start_indent, indent, markdown[i + 1]))
    elseif block.kind == "code" then ---@cast block docgen.grammar.markdown.code_block
      table.insert(res, string.format("%s>%s\n", tabs, block.lang or ""))
      for line in vim.gsplit(block.code:gsub("\n$", ""), "\n") do
        table.insert(res, tabs .. line .. "\n")
      end
      table.insert(res, string.format("%s<\n", tabs))
    elseif block.kind == "pre" then ---@cast block docgen.grammar.markdown.pre_block
      for line in vim.gsplit(block.lines:gsub("\n$", ""), "\n") do
        table.insert(res, tabs .. line .. "\n")
      end
    elseif block.kind == "ul" then ---@cast block docgen.grammar.markdown.ul
      render_ul(block, res, start_indent, indent, list_marker_size, list_depth)
    elseif block.kind == "ol" then ---@cast block docgen.grammar.markdown.ol
      render_ol(block, res, start_indent, indent, list_marker_size, list_depth)
    end

    start_indent = indent
  end

  return (table.concat(res):gsub("[ \n]+$", ""))
end

---@param briefs string[]
---@return string
M.render_briefs = function(briefs)
  local res = {}
  for _, brief in ipairs(briefs) do
    local md = parse_md(brief)
    table.insert(res, M.render_markdown(md, 0, 0, nil, 0))
  end
  return table.concat(res)
end

return M
