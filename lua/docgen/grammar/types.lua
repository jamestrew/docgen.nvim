---@diagnostic disable: unused-local, unused-function

local lpeg = vim.lpeg
local P, S = lpeg.P, lpeg.S
local C, Ct, Cg = lpeg.C, lpeg.Ct, lpeg.Cg
local V = lpeg.V

local util = require("docgen.grammar.utils")
local rep, rep1, opt, Pf, Sf = util.rep, util.rep1, util.opt, util.Pf, util.Sf
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

local array_postfix = Pf("[]") ^ 1
local opt_postfix = Pf("?") ^ 1

local grammar = P({
  "type",
  type = C(v.ty_base),

  ty_base = v.ty * (array_postfix + opt_postfix) ^ 0 * ((Pf("|") * v.ty) ^ 0),
  ty = v.ty_basics + paren(v.type),
  ty_basics = (v.ty_prims * array_postfix) + (v.ty_prims * opt_postfix) + v.ty_prims,
  ty_prims = v.ty_kv_table
    + v.ty_tuple
    + v.ty_dict
    + v.ty_table_literal
    + v.ty_fun
    + base_types
    + ty_ident
    + literal
    + generic,

  ty_tuple = Pf("[") * comma1(v.ty_base) * Pf("]"),
  ty_dict = Pf("{") * comma1(Pf("[") * v.ty_base * Pf("]") * Pf(":") * v.ty_base) * Pf("}"),
  ty_kv_table = Pf("table") * Pf("<") * v.ty_base * Pf(",") * v.ty_base * Pf(">"),
  ty_table_literal = Pf("{") * comma1(ty_ident * Pf(":") * v.ty_base) * Pf("}"),
  ty_fun = Pf("fun")
    * Pf("(")
    * comma(ty_ident * Pf(":") * v.ty_base)
    * Pf(")")
    * Pf(":")
    * v.ty_base,
}) / function(match)
  return match:gsub("^%((.*)%)$", "%1"):gsub("%?+", "?")
end

local f ---@type fun (a: number): number

return grammar
