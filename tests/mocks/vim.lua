-- Mock vim global for unit testing outside of Neovim
-- This provides minimal stubs for vim API functions used in the plugin

local M = {}

-- Storage for mock state
M._buffers = {}
M._windows = {}
M._options = {}
M._global_options = {
  columns = 120,
  lines = 40,
}
M._current_buf = 1
M._current_win = 1

-- vim.fn mock
M.fn = {
  fnamemodify = function(path, modifier)
    if modifier == ':h' then
      return path:match('(.*/)')
    elseif modifier == ':h:h' then
      local result = path:match('(.*/)')
      if result then
        return result:match('(.*/)')
      end
    elseif modifier == ':h:h:h' then
      local result = path:match('(.*/)')
      if result then
        result = result:match('(.*/)')
        if result then
          return result:match('(.*/)')
        end
      end
    end
    return path
  end,
  filereadable = function(path)
    return 0
  end,
  getcwd = function()
    return '/tmp'
  end,
  bufwinid = function(buf)
    return buf
  end,
  jobstart = function(cmd, opts)
    return 1
  end,
  jobstop = function(id)
    return 1
  end,
  chansend = function(id, data)
    return #data
  end,
  expand = function(str)
    return str
  end,
  readfile = function(path)
    return {}
  end,
}

-- vim.api mock
M.api = {
  nvim_create_buf = function(listed, scratch)
    local buf = #M._buffers + 1
    M._buffers[buf] = {
      lines = {},
      options = { buftype = '', bufhidden = '', swapfile = true },
      name = '',
    }
    return buf
  end,
  nvim_buf_is_valid = function(buf)
    return M._buffers[buf] ~= nil
  end,
  nvim_buf_get_lines = function(buf, start, stop, strict)
    local buffer = M._buffers[buf]
    if not buffer then
      return {}
    end
    return buffer.lines
  end,
  nvim_buf_set_lines = function(buf, start, stop, strict, lines)
    local buffer = M._buffers[buf]
    if buffer then
      buffer.lines = lines
    end
  end,
  nvim_buf_get_name = function(buf)
    local buffer = M._buffers[buf]
    return buffer and buffer.name or ''
  end,
  nvim_buf_set_name = function(buf, name)
    local buffer = M._buffers[buf]
    if buffer then
      buffer.name = name
    end
  end,
  nvim_buf_set_option = function(buf, name, value)
    local buffer = M._buffers[buf]
    if buffer then
      buffer.options[name] = value
    end
  end,
  nvim_buf_line_count = function(buf)
    local buffer = M._buffers[buf]
    return buffer and #buffer.lines or 0
  end,
  nvim_get_current_buf = function()
    return M._current_buf
  end,
  nvim_set_current_buf = function(buf)
    M._current_buf = buf
  end,
  nvim_get_current_win = function()
    return M._current_win
  end,
  nvim_set_current_win = function(win)
    M._current_win = win
  end,
  nvim_win_is_valid = function(win)
    return M._windows[win] ~= nil
  end,
  nvim_win_get_buf = function(win)
    local window = M._windows[win]
    return window and window.buf or 1
  end,
  nvim_win_set_buf = function(win, buf)
    local window = M._windows[win]
    if window then
      window.buf = buf
    end
  end,
  nvim_win_get_width = function(win)
    local window = M._windows[win]
    return window and window.width or 80
  end,
  nvim_win_get_height = function(win)
    local window = M._windows[win]
    return window and window.height or 24
  end,
  nvim_win_get_cursor = function(win)
    local window = M._windows[win]
    return window and window.cursor or { 1, 0 }
  end,
  nvim_win_set_cursor = function(win, pos)
    local window = M._windows[win]
    if window then
      window.cursor = pos
    end
  end,
  nvim_win_set_option = function(win, name, value)
    local window = M._windows[win]
    if window then
      window.options = window.options or {}
      window.options[name] = value
    end
  end,
  nvim_win_close = function(win, force)
    M._windows[win] = nil
  end,
  nvim_create_user_command = function(name, callback, opts) end,
  nvim_create_augroup = function(name, opts)
    return 1
  end,
  nvim_create_autocmd = function(event, opts)
    return 1
  end,
}

-- vim.bo mock (buffer options)
M.bo = setmetatable({}, {
  __index = function(_, buf)
    if type(buf) == 'number' then
      return setmetatable({}, {
        __index = function(_, key)
          local buffer = M._buffers[buf]
          return buffer and buffer.options[key]
        end,
        __newindex = function(_, key, value)
          local buffer = M._buffers[buf]
          if buffer then
            buffer.options[key] = value
          end
        end,
      })
    end
    local buffer = M._buffers[M._current_buf]
    return buffer and buffer.options[buf]
  end,
})

-- vim.o mock (global options)
M.o = setmetatable({}, {
  __index = function(_, key)
    return M._global_options[key]
  end,
  __newindex = function(_, key, value)
    M._global_options[key] = value
  end,
})

-- vim.cmd mock
M.cmd = function(cmd) end

-- vim.notify mock
M._notifications = {}
M.notify = function(msg, level)
  table.insert(M._notifications, { msg = msg, level = level })
end

-- vim.log mock
M.log = {
  levels = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
  },
}

-- vim.json mock
M.json = {
  encode = function(obj)
    -- Simple JSON encoder for basic types
    if type(obj) == 'nil' then
      return 'null'
    elseif type(obj) == 'boolean' then
      return obj and 'true' or 'false'
    elseif type(obj) == 'number' then
      return tostring(obj)
    elseif type(obj) == 'string' then
      return '"' .. obj:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
    elseif type(obj) == 'table' then
      -- Check if array
      local is_array = #obj > 0 or next(obj) == nil
      if is_array then
        local parts = {}
        for _, v in ipairs(obj) do
          table.insert(parts, M.json.encode(v))
        end
        return '[' .. table.concat(parts, ',') .. ']'
      else
        local parts = {}
        for k, v in pairs(obj) do
          table.insert(parts, '"' .. k .. '":' .. M.json.encode(v))
        end
        return '{' .. table.concat(parts, ',') .. '}'
      end
    end
    return 'null'
  end,
  decode = function(str)
    -- Safe JSON decoder using pattern matching (no loadstring/load)
    local function skip_ws(s, i)
      local _, j = s:find('^%s*', i)
      return (j or i - 1) + 1
    end

    local function parse_string(s, i)
      i = i + 1
      local res = {}
      local len = #s
      while i <= len do
        local c = s:sub(i, i)
        if c == '"' then
          return table.concat(res), i + 1
        elseif c == '\\' then
          local nextc = s:sub(i + 1, i + 1)
          if nextc == 'n' then
            table.insert(res, '\n')
          elseif nextc == '"' then
            table.insert(res, '"')
          elseif nextc == '\\' then
            table.insert(res, '\\')
          elseif nextc == 't' then
            table.insert(res, '\t')
          elseif nextc == 'r' then
            table.insert(res, '\r')
          else
            table.insert(res, nextc)
          end
          i = i + 2
        else
          table.insert(res, c)
          i = i + 1
        end
      end
      error('Invalid JSON string: ' .. s)
    end

    local function parse_number(s, i)
      local start_i = i
      local len = #s
      if s:sub(i, i) == '-' then
        i = i + 1
      end
      while i <= len and s:sub(i, i):match('%d') do
        i = i + 1
      end
      if i <= len and s:sub(i, i) == '.' then
        i = i + 1
        while i <= len and s:sub(i, i):match('%d') do
          i = i + 1
        end
      end
      if i <= len and s:sub(i, i):lower() == 'e' then
        i = i + 1
        if s:sub(i, i) == '+' or s:sub(i, i) == '-' then
          i = i + 1
        end
        while i <= len and s:sub(i, i):match('%d') do
          i = i + 1
        end
      end
      local n = tonumber(s:sub(start_i, i - 1))
      if n == nil then
        error('Invalid JSON number: ' .. s:sub(start_i, i - 1))
      end
      return n, i
    end

    local parse_value

    local function parse_array(s, i)
      i = i + 1
      local res = {}
      i = skip_ws(s, i)
      if s:sub(i, i) == ']' then
        return res, i + 1
      end
      while true do
        local val
        val, i = parse_value(s, i)
        table.insert(res, val)
        i = skip_ws(s, i)
        local c = s:sub(i, i)
        if c == ']' then
          return res, i + 1
        elseif c == ',' then
          i = skip_ws(s, i + 1)
        else
          error('Invalid JSON array')
        end
      end
    end

    local function parse_object(s, i)
      i = i + 1
      local res = {}
      i = skip_ws(s, i)
      if s:sub(i, i) == '}' then
        return res, i + 1
      end
      while true do
        i = skip_ws(s, i)
        if s:sub(i, i) ~= '"' then
          error('Invalid JSON object key')
        end
        local key
        key, i = parse_string(s, i)
        i = skip_ws(s, i)
        if s:sub(i, i) ~= ':' then
          error('Invalid JSON object')
        end
        i = skip_ws(s, i + 1)
        local val
        val, i = parse_value(s, i)
        res[key] = val
        i = skip_ws(s, i)
        local c = s:sub(i, i)
        if c == '}' then
          return res, i + 1
        elseif c == ',' then
          i = skip_ws(s, i + 1)
        else
          error('Invalid JSON object')
        end
      end
    end

    parse_value = function(s, i)
      i = skip_ws(s, i)
      local c = s:sub(i, i)
      if c == '' then
        error('Invalid JSON: unexpected end')
      elseif c == 'n' and s:sub(i, i + 3) == 'null' then
        return nil, i + 4
      elseif c == 't' and s:sub(i, i + 3) == 'true' then
        return true, i + 4
      elseif c == 'f' and s:sub(i, i + 4) == 'false' then
        return false, i + 5
      elseif c == '"' then
        return parse_string(s, i)
      elseif c == '[' then
        return parse_array(s, i)
      elseif c == '{' then
        return parse_object(s, i)
      elseif c == '-' or c:match('%d') then
        return parse_number(s, i)
      else
        error('Invalid JSON: unexpected character: ' .. c)
      end
    end

    str = str:match('^%s*(.-)%s*$')
    local result, pos = parse_value(str, 1)
    pos = skip_ws(str, pos)
    if pos <= #str then
      error('Invalid JSON: trailing content')
    end
    return result
  end,
}

-- vim.deepcopy mock
M.deepcopy = function(orig)
  local copy
  if type(orig) == 'table' then
    copy = {}
    for k, v in pairs(orig) do
      copy[M.deepcopy(k)] = M.deepcopy(v)
    end
    setmetatable(copy, M.deepcopy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

-- vim.tbl_deep_extend mock
M.tbl_deep_extend = function(behavior, ...)
  local result = {}
  local tables = { ... }
  for _, t in ipairs(tables) do
    if t then
      for k, v in pairs(t) do
        if type(v) == 'table' and type(result[k]) == 'table' then
          result[k] = M.tbl_deep_extend(behavior, result[k], v)
        else
          result[k] = M.deepcopy(v)
        end
      end
    end
  end
  return result
end

-- vim.inspect mock
M.inspect = function(obj)
  if type(obj) == 'string' then
    return '"' .. obj .. '"'
  elseif type(obj) == 'table' then
    return M.json.encode(obj)
  else
    return tostring(obj)
  end
end

-- vim.defer_fn mock
M._deferred = {}
M.defer_fn = function(fn, ms)
  table.insert(M._deferred, { fn = fn, ms = ms })
end

-- Helper to reset mock state
M._reset = function()
  M._buffers = {}
  M._windows = {}
  M._notifications = {}
  M._deferred = {}
  M._current_buf = 1
  M._current_win = 1
end

-- Helper to create a test buffer
M._create_test_buffer = function(opts)
  opts = opts or {}
  local buf = M.api.nvim_create_buf(false, true)
  if opts.lines then
    M._buffers[buf].lines = opts.lines
  end
  if opts.filetype then
    M._buffers[buf].options.filetype = opts.filetype
  end
  if opts.name then
    M._buffers[buf].name = opts.name
  end
  return buf
end

-- Helper to create a test window
M._create_test_window = function(opts)
  opts = opts or {}
  local win = #M._windows + 1
  M._windows[win] = {
    buf = opts.buf or 1,
    width = opts.width or 80,
    height = opts.height or 24,
    cursor = opts.cursor or { 1, 0 },
    options = {},
  }
  return win
end

return M
