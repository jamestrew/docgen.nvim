local lpeg = vim.lpeg
local P, R, C = lpeg.P, lpeg.R, lpeg.C
local util = require("docgen.grammar.utils")
local spaces, fill = util.spacing1, util.fill

local M = {}

local fn = P("function")
local loc = P("local")
local eq = P("=")
local oparen = P("(")
local dot = P(".")

local ident_first = P("_") + R("az", "AZ")
local ident = ident_first * (ident_first + R("09")) ^ 0
local ident_sep = dot + ":"

-- eg. `local foo = 1`
-- captures `foo`
M.local_variable = loc * spaces * C(ident) * spaces * eq

local tbl_fn1 = fn * spaces * C(ident) * C(ident_sep) * C(ident) * fill * oparen
local tbl_fn2 = C(ident) * C(ident_sep) * C(ident) * fill * eq * fill * fn

-- eg.
-- `function M.foobar() end` or `function M:foobar() end`
-- or
-- `M.foobar = function() end` or `M:foobar = function() end`
-- captures `M`, `.` or `:`, `foobar` for either case
M.table_function = tbl_fn1 + tbl_fn2

local tbl_chain = C((ident * dot) ^ 1 * ident)
local tbl_chain_fn1 = fn * spaces * tbl_chain * fill * oparen
local tbl_chain_fn2 = tbl_chain * fill * eq * fill * fn

-- eg.
-- `function A.B.C.foo() end`
-- `A.B.C.foo = function() end`
-- captures `A.B.C.foo`
M.table_chain_function = tbl_chain_fn1 + tbl_chain_fn2

-- eg. `M.foo = ...`
M.table_variable = C(ident) * dot * C(ident) * fill * eq

-- eg. `foo = ...`
-- either global variable or assignment
M.raw_variable = C(ident) * fill * eq

return M
