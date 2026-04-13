# docgen.nvim

Generate Vim help docs for your Neovim plugin from annotations in your Lua
source files.

`docgen.nvim` is heavily inspired by Neovim core's doc generation tooling and
produces help docs in the same general style and layout as built-in Vim/Neovim
documentation. The goal is to generally standardize the way of writing and
rendering help docs.

## Requirements

- Neovim 0.10+

## What It Generates

`docgen.nvim` can generate:

- a section header
- a brief overview section
- class/type documentation
- exported function documentation

That makes it a good fit for plugin APIs that already use annotations for Lua
language servers and editor tooling.

## Supported Annotations

`docgen.nvim` is annotation-driven rather than tied to a single documentation
style.

It is built around the common Lua annotation patterns used by LuaCATS (LuaLS)
and  EmmyLua-style annotations for documenting classes, fields, parameters,
and returns.

Supported annotations include:

- `---@brief` for section overviews
- `---@class` and `---@field` for documented types
- `---@param` and `---@return` for function docs
- `---@see` for related references
- `---@note` for additional notes
- `---@nodoc` to exclude items from generated docs
- `---@inlinedoc` to inline table-like class fields into function parameter docs

References:

- [LuaLS / LuaCATS annotations](https://luals.github.io/wiki/annotations/)
- [EmmyLua annotation reference](https://raw.githubusercontent.com/EmmyLuaLs/emmylua-analyzer-rust/refs/heads/main/docs/emmylua_doc/annotations_EN/README.md)

## Quick Start

Create a `Makefile` target:

```makefile
.deps/docgen.nvim:
	git clone --depth 1 --branch v1.0.1 https://github.com/jamestrew/docgen.nvim $@

.PHONY: docgen
docgen: .deps/docgen.nvim
	nvim -l scripts/gendoc.lua
```

Entrypoint script for defining docgen config:

```lua
-- scripts/gendoc.lua
vim.opt.rtp:prepend(".deps/docgen.nvim")

require("docgen").run({
  name = "my_plugin",
  files = {
    "./lua/my_plugin/init.lua",
    {
      "./lua/my_plugin/utils.lua",
      title = "UTIL",
    },
  },
})
```

Add `.deps/` to your `.gitignore`, then run:

```sh
make docgen
```

This will generate `doc/my_plugin.txt`.

## Configuration

The main entrypoint is `require("docgen").run({ ... })`.

```lua
require("docgen").run({
  name = "docgen",
  description = "Short description for plugin",
  files = {
    { "./lua/docgen/init.lua", tag = "docgen.nvim", fn_tag_prefix = "docgen" },
    "./lua/docgen/parser.lua",
    "./lua/docgen/renderer.lua",
  },
})
```

Config fields:

- `name` (`string`): plugin name, used to generate `doc/<name>.txt`
- `description` (`string?`): short description shown in `:h local-additions`
- `files` (`(string|docgen.FileSection)[]`): files to render, in display order

Each `files` entry can be either a string path or a table with per-section
options:

- `[1]` (`string`): source file path
- `title` (`string?`): section title shown on the left
- `tag` (`string?`): section help tag shown on the right
- `fn_prefix` (`string?`): prefix used for rendered function headers
- `fn_tag_prefix` (`string?`): prefix used for rendered function tags

## Writing Docs

### Briefs

Briefs are a way to provide a high-level overview of the concepts in the file
or plugin. They are defined using the `---@brief` custom annotation followed
by some text. Any continuous lines of comments following the `---@brief`
annotation will be used as the brief description.

```lua
---@brief
--- The contents of the brief is parsed as markdown and a subset of the markdown
--- syntax will be rendered as vimdoc. In fact, this markdown parsing and
--- rendering applies to all annotation descriptions.
---
--- The supported syntaxes are:
--- - paragraphs
--- - lists (unordered and ordered, nesting included)
--- - various inline styles
---   - inline code span will be rendered as is
---   - italic/emphasis text will be rendered as plain text
---   - inline links (eg. `[hello]()`) will be rendered as a tag (eg. [hello]())
---   - shortcut links (eg. `[hello]`) will be rendered as a hot-link (eg. [hello])
---   - `<br>` will be rendered as a newline
--- - fenced code blocks (including language info)
--- - `<pre>` blocks for pre-formatted text
---
--- Other than `<pre>` and code blocks, all text will be wrapped at 78 characters.
---
--- Here's a sample code block:
--- ```lua
--- print('hello world')
--- ```
```

This will be rendered as:

```help
The contents of the brief is parsed as markdown and subset of the markdown
syntax will be rendered as vimdoc. In fact, this markdown parsing and
rendering is applies to all annotation descriptions.

The supported syntaxes are:
• paragraphs
• lists (unordered and ordered, nesting included)
• various inline styles
  • inline code span will be rendered as is
  • italic/emphasis text will be rendered as plain text
  • inline links (eg. `[hello]()`) will be rendered as a tag (eg. *hello*)
  • shortcut links (eg. `[hello]`) will be rendered as a hot-link (eg.
    |hello|)
  • `<br>` will be rendered as a newline
• fenced code blocks (including language info)
• `<pre>` blocks for pre-formatted text

Other than `<pre>` and code blocks, all text will be wrapped at 78 characters.

Here's a sample code block: >lua
    print('hello world')
<
```

Tip: `:setlocal formatoptions+=cro` is handy for writing briefs. `:set spell`
can help too.

### Classes

Classes are defined using the `---@class` and `---@field` annotations.

```lua
---@class MyClass
---@field foo string this is a description of the field
---
--- You can also write a description above the field if it's too long to
--- cleanly fit next to the field like the field above. Both of these descriptions
--- will be parsed as markdown so you can use the same markdown syntaxes as
--- in the brief.
---@field bar number
```

There are a few additional annotations that control how classes are rendered in
the generated vimdoc.

`---@nodoc`

By default, any classes defined in files included in `docgen.run` will be
included in the vimdoc. If you want to exclude a class from generated docs, use
`---@nodoc`:

```lua
---@nodoc
---@class MyPrivateClass
---@field foo string
```

`---@inlinedoc`

You may have an `opt` table parameter or similar parameter for a function that
is a table with many fields. You may want to use a class to define this table
structure but not include the class itself in the vimdoc. `---@inlinedoc`
excludes the class from top-level class docs and instead uses the fields of the
class to generate the function signature and parameter details:

```lua
---@inlinedoc
---@class MyOptTable
---@field foo string some string
---@field bar number some number

---@param opt MyOptTable
function M.myfunc(opt) end
```

That function parameter will then be documented roughly as:

```help
Parameters: ~
  • `opt` (`table`) A table with the following fields:
          • `foo` (`string`) some string
          • `bar` (`number`) some number
```

Inheritance

Inheritance uses the usual `---@class Child : Parent` form:

```lua
---@class Animal

---@class Dog : Animal
```

`docgen.nvim` renders inheritance differently depending on whether `Dog` and
`Animal` use `---@nodoc` or `---@inlinedoc`:

- If neither class uses `---@nodoc` nor `---@inlinedoc`, both are documented
  and `Dog` will show `Extends |Animal|`.
- If `Animal` is marked `---@nodoc`, `Dog` will still show the inheritance.
- If `Animal` is marked `---@inlinedoc`, `Dog` resolves the inheritance and
  includes inherited fields in its own documentation.
- If `Dog` is marked `---@inlinedoc` and `Animal` is marked `---@nodoc`, `Dog`
  still resolves inheritance and includes inherited fields when used as inline
  table params.

Child classes do not inherit private fields from parent classes.

### Functions

Functions are documented primarily via `---@param` and `---@return`.
`docgen.nvim` also supports `---@see` and the custom `---@note` annotation on
functions.

```lua
--- This is a description of the function.
---@note This is a note about the function.
---@see SomeOtherFunction
---@param a number first number
---@param b number second number
---@return number # the sum of `a` and `b`
---@return number # the product of `a` and `b`
function M.myfunc(a, b)
  return a + b, a * b
end
```

This will be rendered roughly as:

```help
my_plugin.myfunc({a}, {b})                            *my_plugin.myfunc*
    This is a description of the function. As usual, this description
    will be parsed as markdown.

    Note: ~
      • This is a note about the function.

    Parameters: ~
      • `a` (`number`) first number
      • `b` (`number`) second number

    Return (multiple): ~
        (`number`) the sum of `a` and `b`
        (`number`) the product of `a` and `b`

    See also: ~
      • SomeOtherFunction
```

Default parameter values can be documented inline in the parameter description
using `(default: ...)`. When present, `docgen.nvim` removes that fragment from
the prose description and renders it next to the parameter type.

```lua
---@param x string some string (default: `"hello"`)
---@param y string cwd (default: `vim.uv.cwd()`)
---@param z boolean some comment (default: `true`) and (other comment)
function M.some_function(x, y, z) end
```

This renders roughly as:

```help
foo_bar.some_function({x}, {y}, {z})                 *foo_bar.some_function*
    Parameters: ~
      • {x}  (`string`, default: `"hello"`) some string
      • {y}  (`string`, default: `vim.uv.cwd()`) cwd
      • {z}  (`boolean`, default: `true`) some comment and (other comment)
```

Function headers can be customized with the `docgen.FileSection` options
`fn_prefix` and `fn_tag_prefix`. Using the same example, setting
`{ fn_prefix = "hello", fn_tag_prefix = "goodbye" }` would render the header
as:

```help
hello.myfunc({a}, {b})                                  *goodbye.myfunc*
```

This is useful when you have functions defined in one module but are re-exported
by another, user-facing module.

`docgen.nvim` will generate documentation for functions that meet all of the
following:

- exported, meaning not local
- not marked with `---@nodoc`, `---@package`, `---@private`, `---@protected`,
  or `---@deprecated`
- have at least one annotation
- not prefixed with `_`


## Credit

- [lewis6991](https://github.com/lewis6991) for the Neovim core doc generation
  work that inspired this project
