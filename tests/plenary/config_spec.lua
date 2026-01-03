-- Tests for mdbuf/config.lua
describe('mdbuf.config', function()
  local config

  before_each(function()
    -- Clear cache and reload module
    package.loaded['mdbuf.config'] = nil
    config = require('mdbuf.config')
  end)

  describe('defaults', function()
    it('should have server defaults', function()
      assert.is_nil(config.defaults.server.cmd)
      assert.equals(10000, config.defaults.server.timeout)
    end)

    it('should have preview defaults', function()
      assert.equals('vertical', config.defaults.preview.split)
      assert.equals(50, config.defaults.preview.width)
      assert.equals(50, config.defaults.preview.height)
    end)

    it('should have render defaults', function()
      assert.equals('light', config.defaults.render.theme)
      assert.equals(800, config.defaults.render.width)
      assert.is_nil(config.defaults.render.custom_css)
    end)

    it('should have behavior defaults', function()
      assert.is_false(config.defaults.behavior.auto_open)
      assert.is_true(config.defaults.behavior.auto_close)
      assert.is_true(config.defaults.behavior.sync_scroll)
    end)
  end)

  describe('setup', function()
    it('should use defaults when no options provided', function()
      config.setup()
      assert.equals('vertical', config.options.preview.split)
      assert.equals('light', config.options.render.theme)
    end)

    it('should merge custom options with defaults', function()
      config.setup({
        preview = {
          split = 'horizontal',
        },
        render = {
          theme = 'dark',
        },
      })

      -- Custom options should be applied
      assert.equals('horizontal', config.options.preview.split)
      assert.equals('dark', config.options.render.theme)

      -- Defaults should be preserved for unspecified options
      assert.equals(50, config.options.preview.width)
      assert.equals(800, config.options.render.width)
    end)

    it('should deep merge nested options', function()
      config.setup({
        server = {
          timeout = 5000,
        },
      })

      assert.equals(5000, config.options.server.timeout)
      assert.is_nil(config.options.server.cmd) -- Preserved from defaults
    end)

    it('should allow custom server command', function()
      config.setup({
        server = {
          cmd = { 'custom', 'server', 'cmd' },
        },
      })

      assert.same({ 'custom', 'server', 'cmd' }, config.options.server.cmd)
    end)

    it('should not mutate defaults', function()
      config.setup({
        preview = {
          split = 'horizontal',
        },
      })

      -- Original defaults should remain unchanged
      assert.equals('vertical', config.defaults.preview.split)
    end)
  end)

  describe('get_server_cmd', function()
    it('should return custom cmd when provided', function()
      config.setup({
        server = {
          cmd = { 'my-custom-server' },
        },
      })

      local cmd = config.get_server_cmd()
      assert.same({ 'my-custom-server' }, cmd)
    end)

    it('should auto-detect server when cmd is nil', function()
      -- Create mock file checks
      local original_filereadable = vim.fn.filereadable
      local readable_files = {}

      vim.fn.filereadable = function(path)
        return readable_files[path] and 1 or 0
      end

      -- Test with dist/index.js available
      readable_files['/mock/server/dist/index.js'] = true

      -- We need to mock the debug.getinfo path too
      local original_getinfo = debug.getinfo
      debug.getinfo = function(level, what)
        if what == 'S' then
          return { source = '@/mock/lua/mdbuf/config.lua' }
        end
        return original_getinfo(level, what)
      end

      config.setup({ server = { cmd = nil } })

      local cmd = config.get_server_cmd()
      assert.equals('node', cmd[1])
      assert.truthy(cmd[2]:match('index%.js'))

      -- Restore
      vim.fn.filereadable = original_filereadable
      debug.getinfo = original_getinfo
    end)
  end)
end)
