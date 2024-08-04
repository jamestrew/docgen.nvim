local lpeg = vim.lpeg

local M = {}

--- @param x vim.lpeg.Pattern
--- @param count integer?
M.rep = function(x, count)
  count = vim.F.if_nil(count, 0)
  return x ^ count
end

--- @param x vim.lpeg.Pattern
M.rep1 = function(x)
  return x ^ 1
end

--- @param x vim.lpeg.Pattern | string
M.opt = function(x)
  if type(x) == "string" then return lpeg.P(x) ^ -1 end
  return x ^ -1
end

--- @param x string
M.Pf = function(x)
  return M.fill * lpeg.P(x) * M.fill
end

--- @param x string
M.Plf = function(x)
  return M.fill * lpeg.P(x)
end

--- @param x string
M.Sf = function(x)
  return M.fill * lpeg.S(x) * M.fill
end

--- @param x vim.lpeg.Pattern
function M.paren(x)
  return M.Pf("(") * x * M.fill * lpeg.P(")")
end

--- @param x vim.lpeg.Pattern
function M.parenOpt(x)
  return M.paren(x) + x
end

--- @param x vim.lpeg.Pattern
function M.comma1(x)
  return M.parenOpt(x * M.rep(M.Pf(",") * x))
end

--- @param x vim.lpeg.Pattern
function M.comma(x)
  return M.opt(M.comma1(x))
end

--- for debugging
M.It = function(tag)
  return lpeg.P(function(s, i)
    s = s:sub(i, #s)
    s = s:gsub("\n", "\\n")
    s = s:gsub("\t", "\\t")
    s = s:gsub(" ", "·")

    if true then print(string.format("tag: %s, match: '%s', idx: %s", tag, s, i)) end
    return true
  end)
end

---@param s string
---@param patt vim.lpeg.Pattern
---@param repl string
M.gsub = function(s, patt, repl)
  return lpeg.Cs((patt / repl + 1) ^ 0):match(s)
end

M.v = setmetatable({}, {
  __index = function(_, k)
    return lpeg.V(k)
  end,
})

M.ws = lpeg.S(" \t\r\n")
M.tab = lpeg.P("\t")
M.space = lpeg.P(" ")
M.spacing = lpeg.S(" \t")
M.spacing1 = M.rep1(M.spacing)
M.fill = M.opt(M.spacing1)
M.any = lpeg.P(1)
M.num = lpeg.R("09")
M.letter = lpeg.R("az", "AZ")

return M
