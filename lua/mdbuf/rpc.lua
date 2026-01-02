---@class MdbufRpc
---@field private job_id number|nil
---@field private request_id number
---@field private pending_requests table<number, function>
---@field private buffer string

local config = require('mdbuf.config')

local M = {}

M.job_id = nil
M.request_id = 0
M.pending_requests = {}
M.buffer = ''

---Start the render server
---@param callback? function Called when server is ready
function M.start_server(callback)
  if M.job_id then
    if callback then
      callback()
    end
    return
  end

  local cmd = config.get_server_cmd()
  vim.notify('[mdbuf] Starting server: ' .. table.concat(cmd, ' '), vim.log.levels.DEBUG)

  M.job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      M.on_stdout(data)
    end,
    on_stderr = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= '' then
          vim.notify('[mdbuf] Server: ' .. line, vim.log.levels.DEBUG)
        end
      end
    end,
    on_exit = function(_, code, _)
      vim.notify('[mdbuf] Server exited with code ' .. code, vim.log.levels.WARN)
      M.job_id = nil
      M.pending_requests = {}
      M.buffer = ''
    end,
    stdout_buffered = false,
    stderr_buffered = false,
  })

  if M.job_id <= 0 then
    vim.notify('[mdbuf] Failed to start server', vim.log.levels.ERROR)
    M.job_id = nil
    return
  end

  -- Send ping to verify server is ready
  if callback then
    vim.defer_fn(function()
      M.request('ping', {}, function(err, result)
        if err then
          vim.notify('[mdbuf] Server ping failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
        else
          vim.notify('[mdbuf] Server ready: ' .. result.version, vim.log.levels.INFO)
          callback()
        end
      end)
    end, 500)
  end
end

---Stop the render server
function M.stop_server()
  if not M.job_id then
    return
  end

  -- Send shutdown request
  M.request('shutdown', {}, function(_, _)
    -- Server should exit on its own
  end)

  -- Force kill after timeout
  vim.defer_fn(function()
    if M.job_id then
      vim.fn.jobstop(M.job_id)
      M.job_id = nil
    end
  end, 1000)
end

---Handle stdout data from server
---@param data string[]
function M.on_stdout(data)
  for _, line in ipairs(data) do
    if line ~= '' then
      M.buffer = M.buffer .. line
    else
      -- Empty line might be part of newline handling
      if M.buffer ~= '' then
        M.process_message(M.buffer)
        M.buffer = ''
      end
    end
  end

  -- Try to parse any complete JSON in buffer
  if M.buffer ~= '' then
    local ok, result = pcall(vim.json.decode, M.buffer)
    if ok then
      M.process_message(M.buffer)
      M.buffer = ''
    end
  end
end

---Process a JSON-RPC message
---@param json_str string
function M.process_message(json_str)
  local ok, response = pcall(vim.json.decode, json_str)
  if not ok then
    vim.notify('[mdbuf] Failed to parse response: ' .. json_str, vim.log.levels.ERROR)
    return
  end

  local id = response.id
  local callback = M.pending_requests[id]
  if not callback then
    vim.notify('[mdbuf] Unknown response id: ' .. id, vim.log.levels.WARN)
    return
  end

  M.pending_requests[id] = nil

  if response.error then
    callback(response.error, nil)
  else
    callback(nil, response.result)
  end
end

---Send a JSON-RPC request
---@param method string
---@param params table
---@param callback function(err, result)
function M.request(method, params, callback)
  if not M.job_id then
    callback({ code = -1, message = 'Server not running' }, nil)
    return
  end

  M.request_id = M.request_id + 1
  local id = M.request_id

  local request = {
    jsonrpc = '2.0',
    id = id,
    method = method,
    params = params,
  }

  M.pending_requests[id] = callback

  local json = vim.json.encode(request) .. '\n'
  vim.fn.chansend(M.job_id, json)
end

---Check if server is running
---@return boolean
function M.is_running()
  return M.job_id ~= nil
end

return M
