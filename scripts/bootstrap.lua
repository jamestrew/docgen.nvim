--[[
Usage:
```lua
load(vim.fn.system("curl -s https://raw.githubusercontent.com/jamestrew/docgen.nvim/master/scripts/bootstrap.lua"))()

require("docgen").run({
  ...
})
```
]]

if vim.env.DOCGEN_PATH and not vim.uv.fs_stat(vim.env.DOCGEN_PATH) then
  vim.env.DOCGEN_PATH = nil
end

local docgen_path = vim.env.DOCGEN_PATH or ".docgen"
if not vim.env.DOCGEN_PATH and not vim.uv.fs_stat(docgen_path) then
  vim.api.nvim_echo({
    {
      "Cloning docgen.nvim\n\n",
      "DiagnosticInfo",
    },
  }, true, {})
  local docgen_repo = "https://github.com/jamestrew/docgen.nvim.git"
  local ok, out = pcall(vim.fn.system, {
    "git",
    "clone",
    "--filter=blob:none",
    docgen_repo,
    docgen_path,
  })
  if not ok or vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone docgen.nvim\n", "ErrorMsg" },
      { vim.trim(out or ""), "WarningMsg" },
      { "\nPress any key to exit...", "MoreMsg" },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(docgen_path)
