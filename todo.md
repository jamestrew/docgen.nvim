[LuaCATS](https://luals.github.io/wiki/annotations/)

- [x] generate briefs
- [x] generate class docs
- [x] generate function docs
- [x] beef up existing tests
- [ ] glue everything together
    - [ ] study neovim and tree-sitter-lua docgen API and make some decisions about some below questions
    - [ ] implement glue
- [ ] ???
- [ ] use for telescope-file-browser


### questions
- what to do about `---@eval`

    probably just support it

- what to do about `---@tag`

    either support it or use a neovim core config style pattern

    latter offers more flexibility for future options

- main api
    - probably a `lazy.minit` style script for minimum setup requirement
    - probably using a config table (ditching `---@tag`)


- what to do about `M.foo = function` & `M:foo = function` syntax and whether to parse as a table

    currently the we support the former, the latter I've never seen and unsupported but technically valid syntax


### side quests
- [ ] support using `---@deprecated` with `---@class`?
- [ ] backport `---@return string ...` syntax to neovim core
