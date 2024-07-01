.PHONY: test docgen

test:
	nvim -l ./tests/busted.lua tests

