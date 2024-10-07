local lpeg = vim.lpeg
local P, C = lpeg.P, lpeg.C

local util = require("docgen.grammar.utils")
local rep, rep1, opt, Pf, Plf, paren, comma, comma1 =
  util.rep, util.rep1, util.opt, util.Pf, util.Plf, util.paren, util.comma, util.comma1
local any, num = util.any, util.num
local v = util.v

local lua = require("docgen.grammar.lua")
local ident, ty_ident = lua.ident, lua.type_ident
local opt_ident = ident * opt(P("?"))

local colon = Pf(":")
local ellipsis = P("...")
local string_single = P("'") * rep(any - P("'")) * P("'")
local string_double = P('"') * rep(any - P('"')) * P('"')
local generic = P("`") * ty_ident * "`"

local literal = string_single + string_double + (opt("-") * rep(num, 1))

local ty_prims = ty_ident + literal + generic

local array_postfix = rep1(Plf("[]"))
local opt_postfix = rep1(Plf("?"))
local rep_array_opt_postfix = rep(array_postfix + opt_postfix)

local grammar = P({
  "typedef",
  typedef = C(v.type),

  type = v.ty * rep_array_opt_postfix * rep(Pf("|") * v.ty * rep_array_opt_postfix),
  ty = v.composite + paren(v.typedef),
  composite = (v.types * array_postfix) + (v.types * opt_postfix) + v.types,
  types = v.generics + v.kv_table + v.tuple + v.dict + v.table_literal + v.fun + ty_prims,

  tuple = Pf("[") * comma1(v.type) * Plf("]"),
  dict = Pf("{") * comma1(Pf("[") * v.type * Pf("]") * colon * v.type) * Plf("}"),
  kv_table = Pf("table") * Pf("<") * v.type * Pf(",") * v.type * Plf(">"),
  table_literal = Pf("{") * comma1(opt_ident * Pf(":") * v.type) * Plf("}"),
  fun_param = (opt_ident + ellipsis) * opt(colon * v.type),
  fun_ret = v.type + (ellipsis * opt(colon * v.type)),
  fun = Pf("fun") * paren(comma(v.fun_param)) * opt(Pf(":") * comma1(v.fun_ret)),
  generics = P(ty_ident) * Pf("<") * comma1(v.type) * Plf(">"),
}) / function(match)
  return vim.trim(match):gsub("^%((.*)%)$", "%1"):gsub("%?+", "?")
end

return grammar
