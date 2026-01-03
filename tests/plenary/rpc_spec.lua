-- Tests for mdbuf/rpc.lua
describe('mdbuf.rpc', function()
  local rpc
  local config

  before_each(function()
    -- Clear cache and reload modules
    package.loaded['mdbuf.rpc'] = nil
    package.loaded['mdbuf.config'] = nil

    config = require('mdbuf.config')
    config.setup()
    rpc = require('mdbuf.rpc')

    -- Reset RPC state
    rpc.job_id = nil
    rpc.request_id = 0
    rpc.pending_requests = {}
    rpc.buffer = ''
  end)

  describe('is_running', function()
    it('should return false when job_id is nil', function()
      rpc.job_id = nil
      assert.is_false(rpc.is_running())
    end)

    it('should return true when job_id is set', function()
      rpc.job_id = 1
      assert.is_true(rpc.is_running())
    end)
  end)

  describe('process_message', function()
    it('should parse valid JSON-RPC response', function()
      local callback_called = false
      local callback_result = nil

      rpc.pending_requests[1] = function(err, result)
        callback_called = true
        callback_result = result
      end

      local json = vim.json.encode({
        jsonrpc = '2.0',
        id = 1,
        result = { status = 'ok', value = 42 },
      })

      rpc.process_message(json)

      assert.is_true(callback_called)
      assert.equals('ok', callback_result.status)
      assert.equals(42, callback_result.value)
      assert.is_nil(rpc.pending_requests[1]) -- Should be removed
    end)

    it('should handle error responses', function()
      local callback_error = nil

      rpc.pending_requests[1] = function(err, result)
        callback_error = err
      end

      local json = vim.json.encode({
        jsonrpc = '2.0',
        id = 1,
        error = { code = -32600, message = 'Invalid Request' },
      })

      rpc.process_message(json)

      assert.is_not_nil(callback_error)
      assert.equals(-32600, callback_error.code)
      assert.equals('Invalid Request', callback_error.message)
    end)

    it('should ignore responses with unknown id', function()
      -- Should not throw
      local json = vim.json.encode({
        jsonrpc = '2.0',
        id = 999,
        result = {},
      })

      assert.has_no.errors(function()
        rpc.process_message(json)
      end)
    end)

    it('should handle invalid JSON gracefully', function()
      -- Capture notifications
      local notifications = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      rpc.process_message('not valid json')

      assert.is_true(#notifications > 0)
      assert.truthy(notifications[1].msg:match('Failed to parse'))

      vim.notify = original_notify
    end)
  end)

  describe('on_stdout', function()
    it('should buffer incomplete messages', function()
      rpc.on_stdout({ '{"jsonrpc":"2.0",' })
      assert.equals('{"jsonrpc":"2.0",', rpc.buffer)
    end)

    it('should process complete messages', function()
      local callback_called = false
      rpc.pending_requests[1] = function()
        callback_called = true
      end

      local json = vim.json.encode({
        jsonrpc = '2.0',
        id = 1,
        result = {},
      })

      rpc.on_stdout({ json })

      assert.is_true(callback_called)
      assert.equals('', rpc.buffer)
    end)

    it('should handle multiple lines', function()
      local results = {}
      rpc.pending_requests[1] = function(_, r)
        table.insert(results, r)
      end
      rpc.pending_requests[2] = function(_, r)
        table.insert(results, r)
      end

      local json1 = vim.json.encode({ jsonrpc = '2.0', id = 1, result = { a = 1 } })
      local json2 = vim.json.encode({ jsonrpc = '2.0', id = 2, result = { b = 2 } })

      rpc.on_stdout({ json1 })
      rpc.on_stdout({ json2 })

      assert.equals(2, #results)
    end)
  end)

  describe('request', function()
    it('should fail when server is not running', function()
      rpc.job_id = nil
      local error_received = nil

      rpc.request('test', {}, function(err, result)
        error_received = err
      end)

      assert.is_not_nil(error_received)
      assert.equals(-1, error_received.code)
      assert.truthy(error_received.message:match('not running'))
    end)

    it('should increment request_id for each request', function()
      rpc.job_id = 1 -- Simulate running server

      -- Mock chansend
      local sent_data = {}
      local sent_ids = {}
      local original_chansend = vim.fn.chansend
      vim.fn.chansend = function(id, data)
        table.insert(sent_ids, id)
        table.insert(sent_data, data)
        return #data
      end

      rpc.request('method1', {}, function() end)
      rpc.request('method2', {}, function() end)

      -- Should have incremented IDs
      assert.truthy(sent_data[1]:match('"id":1'))
      assert.truthy(sent_data[2]:match('"id":2'))
      -- Verify chansend was called with correct job_id
      assert.equals(1, sent_ids[1])
      assert.equals(1, sent_ids[2])

      vim.fn.chansend = original_chansend
    end)

    it('should register pending callback', function()
      rpc.job_id = 1

      local sent_id = nil
      local original_chansend = vim.fn.chansend
      vim.fn.chansend = function(id, data)
        sent_id = id
        return 1
      end

      local callback = function() end
      rpc.request('test', {}, callback)

      assert.equals(callback, rpc.pending_requests[1])
      assert.equals(1, sent_id)

      vim.fn.chansend = original_chansend
    end)

    it('should format JSON-RPC request correctly', function()
      rpc.job_id = 1

      local sent_json = nil
      local sent_id = nil
      local original_chansend = vim.fn.chansend
      vim.fn.chansend = function(id, data)
        sent_id = id
        sent_json = data
        return #data
      end

      rpc.request('render', { markdown = '# Test' }, function() end)

      -- Verify chansend was called with correct job_id
      assert.equals(1, sent_id)

      -- Parse the sent JSON (strip newline)
      local json_str = sent_json:gsub('\n$', '')
      local ok, request = pcall(vim.json.decode, json_str)
      assert.is_true(ok, 'Failed to parse JSON: ' .. tostring(request))
      assert.equals('2.0', request.jsonrpc)
      assert.equals('render', request.method)
      assert.equals('# Test', request.params.markdown)
      assert.is_number(request.id)

      vim.fn.chansend = original_chansend
    end)
  end)

  describe('stop_server', function()
    it('should do nothing when server is not running', function()
      rpc.job_id = nil
      assert.has_no.errors(function()
        rpc.stop_server()
      end)
    end)

    it('should send shutdown request when running', function()
      rpc.job_id = 1

      local shutdown_sent = false
      local sent_id = nil
      local original_chansend = vim.fn.chansend
      vim.fn.chansend = function(id, data)
        sent_id = id
        if data:match('"method":"shutdown"') then
          shutdown_sent = true
        end
        return #data
      end

      rpc.stop_server()

      assert.is_true(shutdown_sent)
      assert.equals(1, sent_id)

      vim.fn.chansend = original_chansend
    end)
  end)
end)
