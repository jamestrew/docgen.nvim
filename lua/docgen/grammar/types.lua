---@diagnostic disable: unused-local, unused-function

local lpeg = vim.lpeg
local P, S = lpeg.P, lpeg.S
local C, Ct, Cg = lpeg.C, lpeg.Ct, lpeg.Cg
local V = lpeg.V

local util = require("docgen.grammar.utils")
local rep, rep1, opt, Pf, Plf, Sf = util.rep, util.rep1, util.opt, util.Pf, util.Plf, util.Sf
local fill, any, num, letter = util.fill, util.any, util.num, util.letter
local ident = require("docgen.grammar.lua").ident
local v = util.v

local ty_ident_sep = P("-") + "."
local ty_ident = ident * rep(ty_ident_sep * ident)
local string_single = P("'") * rep(any - P("'")) * P("'")
local string_double = P('"') * rep(any - P('"')) * P('"')
local generic = P("`") * ty_ident * "`"

local literal = string_single + string_double + (opt("-") * num)
local base_types = P("nil")
  + "any"
  + "boolean"
  + "number"
  + "string"
  + "integer"
  + "function"
  + "table"
  + "thread"
  + "userdata"

local ty_prims = base_types + ty_ident + literal + generic

--- @param x vim.lpeg.Pattern
local function paren(x)
  return Pf("(") * x * fill * P(")")
end

--- @param x vim.lpeg.Pattern
local function parenOpt(x)
  return paren(x) + x
end

--- @param x vim.lpeg.Pattern
local function comma1(x)
  return parenOpt(x * rep(Pf(",") * x))
end

--- @param x vim.lpeg.Pattern
local function comma(x)
  return opt(comma1(x))
end

local array_postfix = Plf("[]") ^ 1
local opt_postfix = Plf("?") ^ 1

local grammar = P({
  "typedef",
  typedef = C(v.type),

  type = v.ty * (array_postfix + opt_postfix) ^ 0 * ((Pf("|") * v.ty) ^ 0),
  ty = v.composite + paren(v.typedef),
  composite = (v.types * array_postfix) + (v.types * opt_postfix) + v.types,
  types = v.kv_table + v.tuple + v.dict + v.table_literal + v.fun + ty_prims,

  tuple = Pf("[") * comma1(v.type) * Plf("]"),
  dict = Pf("{") * comma1(Pf("[") * v.type * Pf("]") * Pf(":") * v.type) * Plf("}"),
  kv_table = Pf("table") * Pf("<") * v.type * Pf(",") * v.type * Pf(">"),
  table_literal = Pf("{") * comma1(ident * Pf(":") * v.type) * Pf("}"),
  fun = Pf("fun")
    * Pf("(")
    * comma(ident * Pf(":") * v.type)
    * Plf(")")
    * (Pf(":") * comma1(v.type)) ^ -1,
}) / function(match)
  return match:gsub("^%((.*)%)$", "%1"):gsub("%?+", "?")
end

return grammar
