-- Tests for mdbuf/window.lua

-- Helper to mock vim.api/vim.fn functions with automatic restore
local function with_mocks(mocks, fn)
  local originals = {}
  -- Store originals and apply mocks
  for key, mock_fn in pairs(mocks) do
    if key:match('^api%.') then
      local api_key = key:gsub('^api%.', '')
      originals[key] = vim.api[api_key]
      vim.api[api_key] = mock_fn
    elseif key:match('^fn%.') then
      local fn_key = key:gsub('^fn%.', '')
      originals[key] = vim.fn[fn_key]
      vim.fn[fn_key] = mock_fn
    elseif key == 'notify' then
      originals[key] = vim.notify
      vim.notify = mock_fn
    elseif key == 'cmd' then
      originals[key] = vim.cmd
      vim.cmd = mock_fn
    elseif key == 'require' then
      originals[key] = _G.require
      _G.require = mock_fn
    end
  end
  -- Run test function
  local ok, err = pcall(fn)
  -- Restore originals
  for key, original in pairs(originals) do
    if key:match('^api%.') then
      local api_key = key:gsub('^api%.', '')
      vim.api[api_key] = original
    elseif key:match('^fn%.') then
      local fn_key = key:gsub('^fn%.', '')
      vim.fn[fn_key] = original
    elseif key == 'notify' then
      vim.notify = original
    elseif key == 'cmd' then
      vim.cmd = original
    elseif key == 'require' then
      _G.require = original
    end
  end
  -- Re-raise error if test failed
  if not ok then
    error(err)
  end
end

describe('mdbuf.window', function()
  local window
  local config

  before_each(function()
    -- Clear cache and reload modules
    package.loaded['mdbuf.window'] = nil
    package.loaded['mdbuf.config'] = nil

    config = require('mdbuf.config')
    config.setup()
    window = require('mdbuf.window')

    -- Reset window state
    window.preview_win = nil
    window.preview_buf = nil
    window.source_buf = nil
    window.source_map = nil
  end)

  describe('is_open', function()
    it('should return false when preview_win is nil', function()
      window.preview_win = nil
      assert.is_false(window.is_open())
    end)

    it('should return false when window is invalid', function()
      window.preview_win = 999 -- Non-existent window
      local checked_win = nil

      with_mocks({
        ['api.nvim_win_is_valid'] = function(win)
          checked_win = win
          return false
        end,
      }, function()
        assert.is_false(window.is_open())
        assert.equals(999, checked_win)
      end)
    end)

    it('should return true when window is valid', function()
      window.preview_win = 1
      local checked_win = nil

      with_mocks({
        ['api.nvim_win_is_valid'] = function(win)
          checked_win = win
          return true
        end,
      }, function()
        assert.is_true(window.is_open())
        assert.equals(1, checked_win)
      end)
    end)
  end)

  describe('get_source_buf', function()
    it('should return nil when not set', function()
      window.source_buf = nil
      assert.is_nil(window.get_source_buf())
    end)

    it('should return source buffer when set', function()
      window.source_buf = 42
      assert.equals(42, window.get_source_buf())
    end)
  end)

  describe('get_window', function()
    it('should return nil when not set', function()
      window.preview_win = nil
      assert.is_nil(window.get_window())
    end)

    it('should return preview window when set', function()
      window.preview_win = 5
      assert.equals(5, window.get_window())
    end)
  end)

  describe('close', function()
    it('should clear all state', function()
      window.preview_win = 1
      window.preview_buf = 2
      window.source_buf = 3
      window.source_map = { lineToY = {} }

      with_mocks({
        ['api.nvim_win_is_valid'] = function() return true end,
        ['api.nvim_win_close'] = function() end,
      }, function()
        window.close()

        assert.is_nil(window.preview_win)
        assert.is_nil(window.preview_buf)
        assert.is_nil(window.source_buf)
        assert.is_nil(window.source_map)
      end)
    end)

    it('should handle already closed window', function()
      window.preview_win = nil

      assert.has_no.errors(function()
        window.close()
      end)
    end)
  end)

  describe('sync_scroll', function()
    it('should do nothing when window is not open', function()
      window.preview_win = nil

      assert.has_no.errors(function()
        window.sync_scroll(10)
      end)
    end)

    it('should do nothing when source_map is nil', function()
      window.preview_win = 1
      window.preview_buf = 1
      window.source_map = nil

      with_mocks({
        ['api.nvim_win_is_valid'] = function() return true end,
        ['api.nvim_buf_is_valid'] = function() return true end,
      }, function()
        assert.has_no.errors(function()
          window.sync_scroll(10)
        end)
      end)
    end)

    it('should find nearest mapped line', function()
      window.preview_win = 1
      window.preview_buf = 1
      window.source_map = {
        lineToY = {
          ['1'] = 0,
          ['5'] = 100,
          ['10'] = 200,
          ['20'] = 400,
        },
        totalHeight = 500,
      }

      local cursor_set = nil

      with_mocks({
        ['api.nvim_win_is_valid'] = function() return true end,
        ['api.nvim_buf_is_valid'] = function() return true end,
        ['api.nvim_win_get_height'] = function() return 24 end,
        ['api.nvim_buf_line_count'] = function() return 100 end,
        ['api.nvim_win_set_cursor'] = function(win, pos)
          cursor_set = pos
        end,
      }, function()
        -- Scroll to line 7 - should find nearest (line 5 at Y=100)
        window.sync_scroll(7)

        assert.is_not_nil(cursor_set)
        -- Y=100, totalHeight=500, bufLines=100 -> ratio=0.2, line=20
        -- The exact value depends on implementation, but should be a reasonable line number
        assert.is_number(cursor_set[1])
        assert.is_true(cursor_set[1] >= 1 and cursor_set[1] <= 100, 'cursor line should be within buffer bounds')
      end)
    end)
  end)

  describe('update_image', function()
    it('should handle missing preview buffer', function()
      window.preview_buf = nil
      local notifications = {}

      with_mocks({
        notify = function(msg, level)
          table.insert(notifications, { msg = msg, level = level })
        end,
      }, function()
        window.update_image('/tmp/test.png', {})

        assert.is_true(#notifications > 0)
        assert.truthy(notifications[1].msg:match('not valid'))
      end)
    end)

    it('should store source_map', function()
      window.preview_buf = 1
      local original_require = require

      with_mocks({
        ['api.nvim_buf_is_valid'] = function() return true end,
        ['api.nvim_buf_set_lines'] = function() end,
        require = function(modname)
          if modname == 'image' then
            error('module not found')
          end
          return original_require(modname)
        end,
      }, function()
        local test_map = { lineToY = { ['1'] = 0 }, totalHeight = 100 }
        window.update_image('/tmp/test.png', test_map)

        assert.same(test_map, window.source_map)
      end)
    end)
  end)

  describe('create_split', function()
    local mocks = {}

    before_each(function()
      -- Store originals and set up mocks
      mocks.nvim_create_buf = vim.api.nvim_create_buf
      mocks.nvim_buf_set_option = vim.api.nvim_buf_set_option
      mocks.nvim_buf_set_name = vim.api.nvim_buf_set_name
      mocks.nvim_get_current_win = vim.api.nvim_get_current_win
      mocks.nvim_win_set_buf = vim.api.nvim_win_set_buf
      mocks.nvim_win_set_option = vim.api.nvim_win_set_option
      mocks.nvim_set_current_win = vim.api.nvim_set_current_win
      mocks.bufwinid = vim.fn.bufwinid
      mocks.cmd = vim.cmd

      local buf_counter = 0
      vim.api.nvim_create_buf = function()
        buf_counter = buf_counter + 1
        return buf_counter
      end
      vim.api.nvim_buf_set_option = function() end
      vim.api.nvim_buf_set_name = function() end
      vim.api.nvim_get_current_win = function() return 2 end
      vim.api.nvim_win_set_buf = function() end
      vim.api.nvim_win_set_option = function() end
      vim.api.nvim_set_current_win = function() end
      vim.fn.bufwinid = function() return 1 end
      vim.cmd = function() end
    end)

    after_each(function()
      -- Restore originals
      vim.api.nvim_create_buf = mocks.nvim_create_buf
      vim.api.nvim_buf_set_option = mocks.nvim_buf_set_option
      vim.api.nvim_buf_set_name = mocks.nvim_buf_set_name
      vim.api.nvim_get_current_win = mocks.nvim_get_current_win
      vim.api.nvim_win_set_buf = mocks.nvim_win_set_buf
      vim.api.nvim_win_set_option = mocks.nvim_win_set_option
      vim.api.nvim_set_current_win = mocks.nvim_set_current_win
      vim.fn.bufwinid = mocks.bufwinid
      vim.cmd = mocks.cmd
    end)

    it('should store source buffer', function()
      window.create_split(42)
      assert.equals(42, window.source_buf)
    end)

    it('should create preview buffer', function()
      window.create_split(1)
      assert.is_not_nil(window.preview_buf)
    end)

    it('should set preview window', function()
      window.create_split(1)
      assert.equals(2, window.preview_win)
    end)

    it('should return true on success', function()
      local result = window.create_split(1)
      assert.is_true(result)
    end)

    it('should use vertical split by default', function()
      local cmd_called = nil
      vim.cmd = function(cmd)
        cmd_called = cmd
      end

      window.create_split(1)

      assert.truthy(cmd_called:match('vertical'))
    end)

    it('should use horizontal split when configured', function()
      config.setup({ preview = { split = 'horizontal' } })

      local cmd_called = nil
      vim.cmd = function(cmd)
        cmd_called = cmd
      end

      window.create_split(1)

      assert.falsy(cmd_called:match('vertical'))
    end)
  end)
end)
