-- Tests for FFI struct name conflict handling
-- This test simulates the scenario where another plugin (e.g., image.nvim)
-- has already defined a 'winsize' struct with a different layout.
--
-- IMPORTANT: This file is named to run BEFORE terminal_spec.lua (alphabetically)
-- because FFI definitions persist for the entire Neovim process.

describe('mdbuf.terminal FFI conflict handling', function()
  it('should work even when winsize is already defined by another plugin', function()
    local ffi = require('ffi')

    -- Simulate another plugin defining winsize with incompatible layout
    -- This mimics what happens when image.nvim or similar plugins load first
    pcall(function()
      ffi.cdef([[
        typedef struct { int dummy_field; } winsize;
      ]])
    end)

    -- Clear and reload modules
    package.loaded['mdbuf.terminal'] = nil
    package.loaded['mdbuf.config'] = nil

    require('mdbuf.config').setup()
    local terminal = require('mdbuf.terminal')

    -- Terminal should work because it uses mdbuf_winsize (unique name)
    -- If this fails, someone likely renamed mdbuf_winsize back to winsize
    local size = terminal.get_size()

    assert.is_not_nil(size, 'get_size() should return a table')
    assert.is_number(size.cell_width, 'cell_width should be a number')
    assert.is_true(size.cell_width > 0, 'cell_width should be positive')
  end)
end)
