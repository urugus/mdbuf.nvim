---@class MdbufRender

local config = require('mdbuf.config')
local rpc = require('mdbuf.rpc')
local window = require('mdbuf.window')
local terminal = require('mdbuf.terminal')

local M = {}

---Render current buffer
---@param buf? number Buffer number (defaults to current)
---@param callback? function(err, result)
function M.render(buf, callback)
  buf = buf or vim.api.nvim_get_current_buf()

  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local markdown = table.concat(lines, '\n')

  -- Get file path for relative image resolution
  local file_path = vim.api.nvim_buf_get_name(buf)
  if file_path == '' then
    file_path = vim.fn.getcwd() .. '/untitled.md'
  end

  -- Get render options
  local opts = config.options.render

  -- Calculate viewport width based on preview window
  local viewport_width = opts.width
  if window.is_open() then
    local win = window.get_window()
    if win then
      -- Calculate pixel width from columns using actual terminal cell size
      local cell_width = terminal.get_cell_width()
      viewport_width = math.floor(vim.api.nvim_win_get_width(win) * cell_width)
    end
  end

  -- Build render params
  local params = {
    markdown = markdown,
    filePath = file_path,
    viewport = {
      width = viewport_width,
    },
    options = {
      theme = opts.theme,
      css = opts.custom_css and vim.fn.readfile(opts.custom_css) or nil,
      sourceMap = config.options.behavior.sync_scroll,
    },
  }

  -- Ensure server is running
  if not rpc.is_running() then
    rpc.start_server(function()
      M.do_render(params, callback)
    end)
  else
    M.do_render(params, callback)
  end
end

---Internal render function
---@param params table
---@param callback? function(err, result)
function M.do_render(params, callback)
  vim.notify('[mdbuf] Rendering...', vim.log.levels.DEBUG)

  rpc.request('render', params, function(err, result)
    if err then
      vim.notify('[mdbuf] Render error: ' .. vim.inspect(err), vim.log.levels.ERROR)
      if callback then
        callback(err, nil)
      end
      return
    end

    vim.notify('[mdbuf] Rendered in ' .. result.renderTime .. 'ms', vim.log.levels.INFO)

    -- Update preview window
    if window.is_open() then
      window.update_image(result.imagePath, result.sourceMap)
    end

    if callback then
      callback(nil, result)
    end
  end)
end

---Render and open preview
---@param buf? number
function M.preview(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  -- Open preview window if not already open
  if not window.is_open() then
    window.create_split(buf)
  end

  -- Render
  M.render(buf)
end

return M
