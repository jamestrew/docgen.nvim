local lpeg = require("lpeg")
local P, S = lpeg.P, lpeg.S
local C, Cg, Cb, Cc, Ct, Cs = lpeg.C, lpeg.Cg, lpeg.Cb, lpeg.Cc, lpeg.Ct, lpeg.Cs

local utils = require("docgen.grammar.utils")
local fill, space, ws, any, tab, num, letter, spacing =
  utils.fill, utils.space, utils.ws, utils.any, utils.tab, utils.num, utils.letter, utils.spacing
local v = utils.v

local M = {}

---@param name string
---@param self_closing boolean?
---@return vim.lpeg.Pattern
local function tag_start(name, self_closing)
  local ret = P("<") * P(name) * fill
  if self_closing then ret = ret * P("/") ^ -1 end
  return ret * P(">")
end

---@param name string
---@return vim.lpeg.Pattern
local function tag_end(name)
  return P("</") * P(name) * fill * P(">")
end

local br = tag_start("br", true)
local pre_start = tag_start("pre")
local pre_end = tag_end("pre")
local fourspaces = P("    ")
local backtick = P("`")
local newline = P("\n")
local nonindent_space = space ^ -3 * -spacing
local blank_line = fill * newline
local blank_lines = blank_line ^ 0
local line_char = P(1 - newline)
local line = line_char ^ 0 * newline
local tight_block_sep = P("\001")
local indent = space ^ -3 * tab + fourspaces / ""
local eof = -any

local parser = {}

parser.blocks = function(str)
  local res = Ct(parser.grammar):match(str)
  if res == nil then error(string.format("block failed on:\n%s", str:sub(1, 20))) end
  return res
end

---@class docgen.grammar.markdown.pre_block
---@field kind "pre"
---@field lines string

local process_pre = function(lines)
  return { kind = "pre", lines = lines }
end

local pre_lines = (line - pre_end) ^ 1

parser.pre = pre_start
  * fill
  * newline
  * (pre_lines / process_pre)
  * fill
  * pre_end
  * fill
  * (newline + eof)

local code_marker = backtick ^ 3
local code_lang = C((letter + num) ^ 0) * fill * (newline + eof)

local fenceindent

local code_start = function(marker, infostring)
  return C(nonindent_space) / function(s)
    fenceindent = #s
  end * marker * fill * infostring
end

local code_end = function(marker)
  return nonindent_space * marker * fill * (newline + eof)
end

local code_line = function(marker)
  return C(line - code_end(marker))
    / function(s)
      return s:gsub("^" .. string.rep(" ?", fenceindent), "")
    end
end

---@class docgen.grammar.markdown.code_block
---@field kind 'code'
---@field lang string?
---@field code string

parser.code_block = code_start(code_marker, code_lang)
  * Cs(code_line(code_marker) ^ 0)
  * code_end(code_marker)
  / function(lang, code)
    lang = lang ~= "" and lang or nil
    return { kind = "code", lang = lang, code = code }
  end

local ul_marker_char = C(P("-") + "*" + "+")
local ul_marker = (
  ul_marker_char * #ws * (tab + space ^ -3)
  + space * ul_marker_char * #ws * (tab + space ^ -2)
  + space * space * ul_marker_char * #ws * (tab + space ^ -1)
  + space * space * space * ul_marker_char * #ws
)

local num_delim = P(".")
local ol_marker = C(num ^ 3 * num_delim) * #ws
  + C(num ^ 2 * num_delim) * #ws * (tab + space ^ 1)
  + C(num * num_delim) * #ws * (tab + space ^ -2)
  + space * C(num ^ 2 * num_delim) * #ws
  + space * C(num * num_delim) * #ws * (tab + space ^ -1)
  + space * space * C(num ^ 1 * num_delim) * #ws

local list_marker = ul_marker + ol_marker

local list_enders = code_marker + pre_start
local opt_indented_line = (indent ^ -1 / "" * C(line_char ^ 1 * newline ^ -1)) - list_enders

local nested_list = Cs((opt_indented_line - list_marker) ^ 1)
  / function(match)
    return "\001" .. match
  end

local list_block_line = opt_indented_line - blank_line - (indent ^ -1 * list_marker)
local list_block = line * list_block_line ^ 0
local list_cont_block = blank_lines * (indent / "") * list_block

-- stylua: ignore
local tight_list_item = function(starter)
  return (
    Cs(
      starter / ""
      * list_block
      * nested_list ^ -1
    ) / parser.blocks
  ) * -(blank_lines * indent)
end

local loose_list_item = function(starter)
  return Cs(
    starter
      / ""
      * list_block
      * Cc("\n")
      * (nested_list + list_cont_block ^ 0)
      * (blank_lines / "\n\n")
  ) / parser.blocks
end

local tight_ul_items = Ct(tight_list_item(ul_marker) ^ 1) * Cc(true) * blank_lines * -ul_marker
local loose_ul_items = Ct(loose_list_item(ul_marker) ^ 1) * Cc(false) * blank_lines

---@class docgen.grammar.markdown.ul
---@field kind 'ul'
---@field items docgen.grammar.markdown.result[]
---@field tight boolean


-- stylua: ignore
parser.ul = (
  (tight_ul_items + loose_ul_items)
  * Cc(false)
  * blank_lines
) / function(items, tight)
  return { kind = "ul", items = items, tight = tight }
end

---@class docgen.grammar.markdown.ol
---@field kind 'ol'
---@field items docgen.grammar.markdown.result[]
---@field tight boolean
---@field start number

local tight_ol_items = Ct(tight_list_item(Cb("listtype")) * tight_list_item(ol_marker) ^ 0)
  * Cc(true)
  * blank_lines
  * -ol_marker
local loose_ol_items = Ct(loose_list_item(Cb("listtype")) * loose_list_item(ol_marker) ^ 0)
  * Cc(false)
  * blank_lines

parser.ol = Cg(ol_marker, "listtype")
  * (tight_ol_items + loose_ol_items)
  * Cb("listtype")
  / function(items, tight, start)
    return {
      kind = "ol",
      items = items,
      start = (C(num ^ 1) / tonumber):match(start),
      tight = tight,
    }
  end

---@class docgen.grammar.markdown.paragraph
---@field kind 'paragraph'
---@field text string

parser.paragraph = nonindent_space
  * Ct(v.inline ^ 1)
  * newline
  * (blank_line ^ 1 + fill)
  / function(inlines)
    return { kind = "paragraph", text = table.concat(inlines) }
  end

parser.br = br / "\n"

local specials = S("*_~&[]<!\\-@^")
local norm_char = any - (specials + ws + tight_block_sep)
parser.str = C(norm_char ^ 1)

parser.endline = (
  newline
  * -(blank_line + tight_block_sep + eof + code_start(code_marker, code_lang) + pre_start + ul_marker + ol_marker)
  * spacing ^ 0
) / " "

parser.symbol = C(specials - tight_block_sep)

local linebreak = spacing ^ 2 * parser.endline
-- stylua: ignore
parser.space = C(
  linebreak
  + spacing ^ 1 * parser.endline ^ -1 * eof
  + spacing ^ 1 * parser.endline ^ -1 * fill
) / " "

parser.blank = blank_line + tight_block_sep
local blankline = parser.blank ^ 0

parser.grammar = {
  "blocks",

  -- stylua: ignore
  blocks = parser.blank ^ 0
    *  v.block ^ -1
    * (blankline * v.block) ^ 0
    * parser.blank ^ 0
    * eof,
  block = parser.pre + parser.code_block + parser.ul + parser.ol + parser.paragraph,
  inline = parser.br + parser.str + parser.space + parser.endline + parser.symbol,
}

---@alias docgen.grammar.markdown.result
---| docgen.grammar.markdown.pre_block
---| docgen.grammar.markdown.code_block
---| docgen.grammar.markdown.ul
---| docgen.grammar.markdown.ol
---| docgen.grammar.markdown.paragraph

---@param str string input "markdown" text
---@return docgen.grammar.markdown.result[]
M.parse_markdown = function(str)
  str = str .. "\n"
  return parser.blocks(str)
end

return M
