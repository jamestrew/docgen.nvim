--[[!
LPEG grammar for LuaCATS
]]

local lpeg = vim.lpeg
local P, C, Ct, Cg = lpeg.P, lpeg.C, lpeg.Ct, lpeg.Cg

local util = require("docgen.grammar.utils")
local rep, rep1, opt, Pf, Sf, comma1, paren =
  util.rep, util.rep1, util.opt, util.Pf, util.Sf, util.comma1, util.paren
local fill, any = util.fill, util.any
local v = util.v

local lua = require("docgen.grammar.lua")
local ident, type_ident = lua.ident, lua.type_ident

local ws = util.rep1(lpeg.S(" \t"))
local lname = (ident + P("...")) * opt(P("?"))

local colon = Pf(":")
local opt_exact = opt(Cg(Pf("(exact)"), "access"))
local access = P("private") + P("protected") + P("package")
local caccess = Cg(access, "access")
local desc_delim = Sf("#:") + ws
local desc = Cg(rep(any), "desc")
local opt_desc = opt(desc_delim * desc)
local ty_name = Cg(type_ident, "name")
local opt_parent = opt(colon * Cg(type_ident, "parent"))

--- @class docgen.grammar.luacats.Param
--- @field kind 'param'
--- @field name string
--- @field type string
--- @field desc? string

--- @class docgen.grammar.luacats.Return
--- @field kind 'return'
--- @field [integer] { type: string, name?: string}
--- @field desc? string

--- @class docgen.grammar.luacats.Generic
--- @field kind 'generic'
--- @field name string
--- @field type? string

--- @class docgen.grammar.luacats.Class
--- @field kind 'class'
--- @field name string
--- @field parent? string
--- @field access? 'private'|'protected'|'package'

--- @class docgen.grammar.luacats.Field
--- @field kind 'field'
--- @field name string
--- @field type string
--- @field desc? string
--- @field access? 'private'|'protected'|'package'

--- @class docgen.grammar.luacats.Note
--- @field desc? string

--- @alias docgen.grammar.luacats.result
--- | docgen.grammar.luacats.Param
--- | docgen.grammar.luacats.Return
--- | docgen.grammar.luacats.Generic
--- | docgen.grammar.luacats.Class
--- | docgen.grammar.luacats.Field
--- | docgen.grammar.luacats.Note

--- @class docgen.grammar.luacats
--- @field match fun(self, input: string): docgen.grammar.luacats.result?

local function annot(nm, pat)
  if type(nm) == "string" then nm = P(nm) end
  if pat then return Ct(Cg(P(nm), "kind") * fill * pat) end
  return Ct(Cg(P(nm), "kind"))
end

local typedef = require("docgen.grammar.types")

local grammar = P({
  rep1(P("@") * (v.ats + v.ext_ats)),

  ats = annot("param", Cg(lname, "name") * ws * v.ctype * opt_desc)
    + annot("return", comma1(Ct(v.ctype * opt(ws * (ty_name + Cg(P("..."), "name"))))) * opt_desc)
    + annot("type", comma1(Ct(v.ctype)) * opt_desc)
    + annot("cast", ty_name * ws * opt(Sf("+-")) * v.ctype)
    + annot("generic", ty_name * opt(colon * v.ctype))
    + annot("class", opt_exact * fill * ty_name * opt_parent)
    + annot("field", opt(caccess * ws) * v.field_name * ws * v.ctype * opt_desc)
    + annot("operator", ty_name * opt(paren(Cg(v.ctype, "argtype"))) * colon * v.ctype)
    + annot(access)
    + annot("deprecated")
    + annot("alias", ty_name * opt(ws * v.ctype))
    + annot("enum", ty_name)
    + annot("overload", v.ctype)
    + annot("see", opt(desc_delim) * desc)
    + annot("diagnostic", opt(desc_delim) * desc)
    + annot("meta"),

  --- Custom extensions
  ext_ats = (
    annot("note", desc)
    + annot("since", desc)
    + annot("nodoc")
    + annot("inlinedoc")
    + annot("brief", desc)
    + annot("eval", desc)
  ),

  field_name = Cg(lname + (v.ty_index * opt(P("?"))), "name"),
  ty_index = C(Pf("[") * typedef * fill * P("]")),

  ctype = Cg(typedef, "type"),
})

return grammar --[[@as docgen.grammar.luacats]]
