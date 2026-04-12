.PHONY: test lint all lint-check

all: test lint

test:
	nvim -l ./tests/busted.lua tests

lint:
	stylua lua/
	luacheck lua/

lint-check:
	stylua --check lua/
	luacheck lua/
