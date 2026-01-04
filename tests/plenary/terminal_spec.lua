-- Tests for mdbuf/terminal.lua

-- Helper to mock require with automatic restore
local function with_require_mock(mock_fn, test_fn)
  local original_require = _G.require
  _G.require = mock_fn
  local ok, err = pcall(test_fn)
  _G.require = original_require
  if not ok then
    error(err)
  end
end

describe('mdbuf.terminal', function()
  local terminal
  local config

  before_each(function()
    -- Clear cache and reload modules
    package.loaded['mdbuf.terminal'] = nil
    package.loaded['mdbuf.config'] = nil

    config = require('mdbuf.config')
    config.setup()
    terminal = require('mdbuf.terminal')
  end)

  describe('get_size', function()
    it('should return a table with cell_width and cell_height', function()
      local size = terminal.get_size()

      assert.is_not_nil(size)
      assert.is_table(size)
      assert.is_number(size.cell_width)
      assert.is_number(size.cell_height)
    end)

    it('should return positive values', function()
      local size = terminal.get_size()

      assert.is_true(size.cell_width > 0, 'cell_width should be positive')
      assert.is_true(size.cell_height > 0, 'cell_height should be positive')
    end)

    it('should return all size fields', function()
      local size = terminal.get_size()

      assert.is_number(size.screen_cols)
      assert.is_number(size.screen_rows)
      assert.is_true(size.screen_cols > 0)
      assert.is_true(size.screen_rows > 0)
    end)
  end)

  describe('get_cell_width', function()
    it('should return a positive number', function()
      local width = terminal.get_cell_width()

      assert.is_number(width)
      assert.is_true(width > 0, 'cell_width should be positive')
    end)
  end)

  describe('get_cell_height', function()
    it('should return a positive number', function()
      local height = terminal.get_cell_height()

      assert.is_number(height)
      assert.is_true(height > 0, 'cell_height should be positive')
    end)
  end)

  describe('update_size', function()
    it('should return size table', function()
      local size = terminal.update_size()

      assert.is_not_nil(size)
      assert.is_table(size)
      assert.is_number(size.cell_width)
    end)

    it('should update cached size', function()
      local size1 = terminal.update_size()
      local size2 = terminal.get_size()

      assert.same(size1, size2)
    end)
  end)

  describe('fallback behavior', function()
    it('should use config fallback when FFI fails', function()
      -- Set custom pixels_per_char
      config.setup({ render = { pixels_per_char = 16 } })

      -- Force reload terminal module to pick up new config
      package.loaded['mdbuf.terminal'] = nil
      terminal = require('mdbuf.terminal')

      local size = terminal.get_size()

      -- The fallback value should be used if TIOCGWINSZ fails
      -- (e.g., in headless test environment)
      assert.is_number(size.cell_width)
      assert.is_true(size.cell_width > 0)
    end)

    it('should fallback gracefully when FFI is not available', function()
      -- Set custom pixels_per_char for verification
      config.setup({ render = { pixels_per_char = 20 } })

      -- Clear and reload with mocked require that fails for 'ffi'
      package.loaded['mdbuf.terminal'] = nil

      local original_require = _G.require
      with_require_mock(function(modname)
        if modname == 'ffi' then
          error('module ffi not found')
        end
        return original_require(modname)
      end, function()
        terminal = original_require('mdbuf.terminal')
        local size = terminal.get_size()

        -- Should use fallback value from config
        assert.is_not_nil(size)
        assert.is_number(size.cell_width)
        assert.equals(20, size.cell_width)
      end)
    end)
  end)
end)
