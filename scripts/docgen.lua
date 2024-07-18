vim.opt.rtp:append(".")

require("docgen").run({
  name = "docgen",
  files = {
    "./lua/docgen/init.lua",
    "./lua/docgen/parser.lua",
    "./lua/docgen/renderer.lua",
  },
})
