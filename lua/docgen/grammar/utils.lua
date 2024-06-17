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

--- @param x vim.lpeg.Pattern
M.opt = function(x)
  return x ^ -1
end

--- @param x string
M.Pf = function(x)
  return M.fill * lpeg.P(x) * M.fill
end

--- @param x string
M.Sf = function(x)
  return M.fill * lpeg.S(x) * M.fill
end

M.It = function(tag)
  return lpeg.P(function(s, i)
    s = s:gsub("\n", "\\n")
    print(string.format("tag: %s, match: %s, idx: %s", tag, s:sub(i, #s), i))
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
M.letter = lpeg.R("az", "AZ") + lpeg.S("_$")
M.foo = 23

return M
