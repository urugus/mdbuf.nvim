.PHONY: test test-lua lint lint-lua deps clean

# Default target
test: test-lua

# Run Lua tests with plenary.nvim
test-lua: deps
	NVIM_LISTEN_ADDRESS= nvim --headless --clean -u tests/minimal_init.lua \
		-c "lua vim.opt.rtp:prepend('deps/plenary.nvim')" \
		-c "lua vim.opt.rtp:prepend('.')" \
		-c "runtime plugin/plenary.vim" \
		-c "PlenaryBustedDirectory tests/plenary { minimal_init = 'tests/minimal_init.lua' }"

# Run all linters
lint: lint-lua

# Lint Lua code
lint-lua:
	luacheck lua/ tests/

# Install test dependencies
deps:
	@if [ ! -d "deps/plenary.nvim" ]; then \
		echo "Cloning plenary.nvim..."; \
		mkdir -p deps; \
		git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git deps/plenary.nvim; \
	fi

# Clean dependencies
clean:
	rm -rf deps/
