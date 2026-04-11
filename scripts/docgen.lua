vim.opt.rtp:append(".")

require("docgen").run({
  name = "docgen",
  description = "Generate vimdoc for your Neovim plugin from LuaCATS annotations",
  files = {
    { "./lua/docgen/init.lua", tag = "docgen.nvim", fn_tag_prefix = "docgen" },
    { "./lua/docgen/_doc/briefs.lua", title = "BRIEFS", tag = "docgen.briefs" },
    { "./lua/docgen/_doc/classes.lua", title = "CLASSES", tag = "docgen.classes" },
    { "./lua/docgen/_doc/functions.lua", title = "FUNCTIONS", tag = "docgen.functions" },
    -- "./lua/docgen/parser.lua",
    -- "./lua/docgen/renderer.lua",
  },
})
