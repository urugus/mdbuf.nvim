.PHONY: test test-lua lint lint-lua deps clean

# Default target
test: test-lua

# Run Lua tests with plenary.nvim
test-lua: deps
	env -u NVIM_LISTEN_ADDRESS nvim --headless --clean -u tests/minimal_init.lua \
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
# Pin to specific commit for reproducibility and supply-chain security
PLENARY_COMMIT := b9fd5226c2f76c951fc8ed5923d85e4de065e509
deps:
	@if [ ! -d "deps/plenary.nvim" ]; then \
		echo "Cloning plenary.nvim ($(PLENARY_COMMIT))..."; \
		mkdir -p deps; \
		git clone https://github.com/nvim-lua/plenary.nvim.git deps/plenary.nvim; \
		cd deps/plenary.nvim && git checkout $(PLENARY_COMMIT); \
	fi

# Clean dependencies
clean:
	rm -rf deps/
