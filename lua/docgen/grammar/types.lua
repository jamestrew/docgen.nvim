local lpeg = vim.lpeg
local P, C = lpeg.P, lpeg.C

local util = require("docgen.grammar.utils")
local rep, rep1, opt, Pf, Plf, paren, comma, comma1 =
  util.rep, util.rep1, util.opt, util.Pf, util.Plf, util.paren, util.comma, util.comma1
local any, num = util.any, util.num
local v = util.v

local lua = require("docgen.grammar.lua")
local ident, type_ident = lua.ident, lua.type_ident

local string_single = P("'") * rep(any - P("'")) * P("'")
local string_double = P('"') * rep(any - P('"')) * P('"')
local generic = P("`") * type_ident * "`"

local literal = string_single + string_double + (opt("-") * rep(num, 1))

local ty_prims = type_ident + literal + generic

local array_postfix = rep1(Plf("[]"))
local opt_postfix = rep1(Plf("?"))

local grammar = P({
  "typedef",
  typedef = C(v.type),

  type = v.ty * rep(array_postfix + opt_postfix) * rep(Pf("|") * v.ty),
  ty = v.composite + paren(v.typedef),
  composite = (v.types * array_postfix) + (v.types * opt_postfix) + v.types,
  types = v.kv_table + v.tuple + v.dict + v.table_literal + v.fun + ty_prims,

  tuple = Pf("[") * comma1(v.type) * Plf("]"),
  dict = Pf("{") * comma1(Pf("[") * v.type * Pf("]") * Pf(":") * v.type) * Plf("}"),
  kv_table = Pf("table") * Pf("<") * v.type * Pf(",") * v.type * Pf(">"),
  table_literal = Pf("{") * comma1(ident * Pf(":") * v.type) * Pf("}"),
  fun = Pf("fun") * Pf("(") * comma(ident * Pf(":") * v.type) * Plf(")") * opt(
    Pf(":") * comma1(v.type)
  ),
}) / function(match)
  return match:gsub("^%((.*)%)$", "%1"):gsub("%?+", "?")
end

return grammar
