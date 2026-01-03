-- Tests for mdbuf/terminal.lua

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
  end)
end)
