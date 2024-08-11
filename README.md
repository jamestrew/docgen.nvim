# docgen.nvim

### 🚧 UNDER CONSTRUCTION 🚧

A Neovim help doc generation tool HEAVILY inspired by Neovim core's doc gen tool.<br>
Generate help docs with the same style and formatting as Neovim core's help
docs using in-code annotations (LuaCATS + more).


## Guide
Getting started with `docgen.nvim`
1. Create a script for `docgen.nvim`
    eg.
    ```lua
    -- script/gendoc.lua
    vim.opt.rtp:append "."

    -- `docgen.nvim` installation location
    vim.env.DOCGEN_PATH = vim.env.DOCGEN_PATH or ".deps/docgen.nvim"

    -- bootstrap script will git clone `docgen.nvim` and place it in your
    -- runtimepath automatically
    -- if the `DOCGEN_PATH` env variable is defined, it will use the defined
    -- path instead of cloning another copy
    load(vim.fn.system "curl -s https://raw.githubusercontent.com/jamestrew/docgen.nvim/master/scripts/bootstrap.lua")()

    -- main entry point
    require("docgen").run({
      name = "my_plugin", -- will be used to generate `doc/my_plugin.txt`
      files = {
        -- list the file you want used to generate vimdoc *IN ORDER* that they
        -- will appear in the vimdoc

        ".lua/my_plugin/init.lua", -- can simply list file(s)

        -- can optionally provide configuration for each file
        {
          ".lua/my_plugin/utils.lua",
          title = "UTIL",
        },
      },
    })
    ```
    See [docgen.run()] for more information on the configuration options.
2. Run your script above from your shell
    eg. `nvim -l script/gendoc.lua`
3. That's pretty much it. Any LuaCATS annotations in the files you listed will
   be used to generate the vimdoc for your plugin.

Each file provided to `require("docgen").run` can have up to three parts:
1. A section header (which always exists) like so
   ```
   ==========================================================================
   DOCGEN                                                     *docgen.nvim*
   ```
    The title of the section (on the left) and the tag (on the right) can be
    configured via the `title` and `tag` options in [docgen.FileSection]
    respectively.
2. A briefs section to discribe the main concepts in the given file/plugin
    (what you're reading now). See [docgen.briefs].
3. Type definitions for any classes defined in the file. See [docgen.classes].
4. Type definitions for any exported/public functions defined in the file. See [docgen.functions].

See [`:h
docgen.nvim`](https://github.com/jamestrew/docgen.nvim/blob/master/doc/docgen.txt)
for more info for now.

## Credit
- [lewis6991](https://github.com/lewis6991) on the Neovim core team for his
work on the Neovim core doc gen script
