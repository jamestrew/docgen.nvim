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
local types = P("nil")
  + "any"
  + "boolean"
  + "number"
  + "string"
  + "integer"
  + "function"
  + "table"
  + "thread"
  + "userdata"

local ty_prims = types + ty_ident + literal + generic

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
local ty_basics = (ty_prims * array_postfix) + (ty_prims * opt_postfix) + ty_prims

local ty = ty_basics + paren(V("type"))
local ty_union = ty * (array_postfix + opt_postfix + ((Pf("|") * ty) ^ 0))

local grammar = P({
  "type",
  type = C(ty_union),
}) / function(match)
  return match:gsub("^%((.*)%)$", "%1"):gsub("%?+", "?")
end

---@type [string, string|boolean][]
local test_cases = {
  { "foo", "foo" },
  { "(foo)", "foo" }, -- handles redundant parens
  { "true", "true" },
  { "true?", "true?" }, -- ty_opt
  { "string[]", "string[]" }, -- ty_array
  { "string|number", "string|number" }, -- ty_union
  { "(string)[]", "(string)[]" }, -- FAIL
  { "(string|number)[]", "(string|number)[]" },
  { ")bad", false },
  { "coalesce??", "coalesce?" },
  { "number?|string", "number?|string" },
  { "number[]|string", "number[]|string" },
  { "string[]?", "string[]?" },
  { "wtf?[]", "wtf?[]" },
}

if true then
  for i, test_case in ipairs(test_cases) do
    local input, expected = test_case[1], test_case[2]
    local actual = grammar:match(input)
    if expected == false then
      assert(actual == nil, "failed to fail: " .. input)
    else
      assert(actual, "failed to match: " .. input)
      assert(
        expected == actual,
        vim.inspect({
          idx = i,
          expected = expected,
          got = vim.F.if_nil(actual, "<nil>"),
          input = input,
        })
      )
    end
  end

  print("types.lua: ok")
end

local f ---@type string[][]

-- precedence
-- array
-- union
-- opt
