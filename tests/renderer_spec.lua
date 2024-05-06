local parser = require("docgen.parser")
local renderer = require("docgen.renderer")

local s_lit = function(s)
  if s == nil then return "" end
  return s:gsub("\n", "\\n")
end

describe("briefs", function()
  ---@param name string
  ---@param input string
  ---@param expect string
  local assert_brief = function(name, input, expect)
    it(name, function()
      local _, _, brief, _ = parser.parse_str(input, "myfile.lua")
      local actual = renderer.render_brief(brief[1])
      assert.are.same(s_lit(expect), s_lit(actual))
    end)
  end

  assert_brief("empty", "---@brief", "")

  assert_brief(
    "basic",
    [[---@brief
--- hello
    ]],
    "hello"
  )

  assert_brief(
    "single paragraph",
    [[---@brief
---abc
---def
    ]],
    "abc def"
  )

  assert_brief(
    "two paragraphs",
    [[---@brief
---abc
---
--- def
    ]],
    "abc\ndef"
  )

  assert_brief(
    "two paragraphs with <br>",
    [[---@brief
---abc<br>
---def
    ]],
    "abc\ndef"
  )

  assert_brief(
    "two paragraphs with <br> on the same line",
    [[---@brief
---abc<br>def
    ]],
    "abc\ndef"
  )

  assert_brief(
    "<br> spam",
    [[---@brief
--- <br>
--- <br>
--- <br>
--- <br>
--- <br>
--- finally
    ]],
    "\n\n\n\n\nfinally"
  )

  assert_brief(
    "text wrap",
    [[---@brief
  --- Lorum ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua
      ]],
    [[Lorum ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua]]
  )

  --   assert_brief(
  --     "unordered list",
  --     [[---@brief
  -- --- - Item 1
  -- ---   - Item 1.1 This item will be wrapped as well and the result will be as expected. This is really handy.
  -- ---     - Item 1.1.1
  -- ---   - Item 1.2
  -- --- - Item 2
  --     ]],
  --     vim.trim([[
  -- - Item 1
  --   - Item 1.1 This item will be wrapped as well and the result will be as
  --     expected. This is really handy.
  --     - Item 1.1.1
  --   - Item 1.2
  -- - Item 2
  --     ]])
  --   )
end)
