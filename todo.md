[LuaCATS](https://luals.github.io/wiki/annotations/)

- [ ] generate briefs
- [ ] generate class docs
- [ ] generate function docs
- [ ] beef up existing tests
- [ ] glue everything together
- [ ] ???


# markdown parser
### TODO
- [x] support `<br>`
- [x] support inline code
- [x] support `<pre>`
- [x] condense paragraph and plain parsing
- [ ] check eof block compat ie. blocks ending with a eof
- [ ] clean up and comprehension
- [ ] testing, testing, testing

### briefs
what to allow - some kind of markdown light...
- items and enumeration
- line break with `<br>`
- code block with '```' -> must be at the start of a line


### questions
- [ ] tags and how to handle them
- [ ] not a q but read `:h help-writing`


# gen_vimdoc
- defines a schema of docs to generate
- loops over the schema by file
- parses files and collects classes/functions/briefs
    - makes sure there's no overlapping class definitions
- for each file, if there's briefs -> md_to_vimdoc
    - this seems like a MAJOR hassle and requires tree-sitter-markdown as an additional dependency
    - how does TJ's tree-sitter-lua handle briefs? -> markdown-- and basic lua parsing


