.PHONY: deps format format-check test

STYLUA ?= stylua

deps:
	@test -d .deps/mini.nvim || git clone --depth 1 https://github.com/echasnovski/mini.nvim .deps/mini.nvim
	@test -d .deps/plenary.nvim || git clone --depth 1 https://github.com/nvim-lua/plenary.nvim .deps/plenary.nvim
	@test -d .deps/telescope.nvim || git clone --depth 1 https://github.com/nvim-telescope/telescope.nvim .deps/telescope.nvim

format:
	$(STYLUA) lua plugin tests

format-check:
	$(STYLUA) --check lua plugin tests

test: deps
	NVIM_LOG_FILE=/dev/null nvim --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()"
