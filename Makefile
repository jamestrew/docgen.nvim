.PHONY: test docgen

test:
	nvim -l ./tests/busted.lua tests

docgen:
	nvim -l ./scripts/docgen.lua
