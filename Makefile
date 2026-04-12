.PHONY: test docgen lint lint-check all

all: test docgen lint

test:
	nvim -l ./tests/busted.lua tests

docgen:
	nvim -l ./scripts/docgen.lua

lint:
	stylua lua/
	luacheck lua/

lint-check:
	stylua --check lua/
	luacheck lua/
