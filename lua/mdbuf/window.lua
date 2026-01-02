---@class MdbufWindow
---@field private preview_win number|nil
---@field private preview_buf number|nil
---@field private source_buf number|nil
---@field private source_map table|nil

local config = require('mdbuf.config')

local M = {}

M.preview_win = nil
M.preview_buf = nil
M.source_buf = nil
M.source_map = nil

---Create preview split window
---@param source_buf number Source buffer number
---@return boolean success
function M.create_split(source_buf)
  M.source_buf = source_buf

  -- Create preview buffer
  M.preview_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M.preview_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(M.preview_buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(M.preview_buf, 'swapfile', false)
  vim.api.nvim_buf_set_name(M.preview_buf, 'mdbuf://preview')

  -- Calculate split size
  local opts = config.options.preview
  local split_cmd

  if opts.split == 'vertical' then
    local width = math.floor(vim.o.columns * opts.width / 100)
    split_cmd = 'vertical rightbelow ' .. width .. 'split'
  else
    local height = math.floor(vim.o.lines * opts.height / 100)
    split_cmd = 'rightbelow ' .. height .. 'split'
  end

  -- Create split and set buffer
  vim.cmd(split_cmd)
  M.preview_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.preview_win, M.preview_buf)

  -- Set window options
  vim.api.nvim_win_set_option(M.preview_win, 'number', false)
  vim.api.nvim_win_set_option(M.preview_win, 'relativenumber', false)
  vim.api.nvim_win_set_option(M.preview_win, 'signcolumn', 'no')
  vim.api.nvim_win_set_option(M.preview_win, 'cursorline', false)
  vim.api.nvim_win_set_option(M.preview_win, 'wrap', false)

  -- Return focus to source window
  local source_win = vim.fn.bufwinid(source_buf)
  if source_win ~= -1 then
    vim.api.nvim_set_current_win(source_win)
  end

  return true
end

---Update preview with rendered image
---@param image_path string Path to rendered PNG
---@param source_map table Source line to Y position mapping
function M.update_image(image_path, source_map)
  if not M.preview_buf or not vim.api.nvim_buf_is_valid(M.preview_buf) then
    vim.notify('[mdbuf] Preview buffer not valid', vim.log.levels.WARN)
    return
  end

  M.source_map = source_map

  -- Clear existing content
  vim.api.nvim_buf_set_lines(M.preview_buf, 0, -1, false, {})

  -- Check if image.nvim is available and setup
  local ok, image = pcall(require, 'image')
  if not ok then
    vim.notify('[mdbuf] image.nvim not found. Install 3rd/image.nvim for image display.', vim.log.levels.WARN)
    vim.api.nvim_buf_set_lines(M.preview_buf, 0, -1, false, {
      'Preview rendered to: ' .. image_path,
      '',
      'Install image.nvim for in-buffer display:',
      'https://github.com/3rd/image.nvim',
    })
    return
  end

  -- Check if image.nvim is properly setup
  local ok_setup, has_get_images = pcall(function()
    -- image.nvim stores setup state internally, try a safe operation
    return image.get_images and type(image.get_images) == 'function'
  end)

  local is_setup = ok_setup and has_get_images

  if not is_setup then
    vim.notify('[mdbuf] image.nvim is not setup. Call require("image").setup() first.', vim.log.levels.WARN)
    vim.api.nvim_buf_set_lines(M.preview_buf, 0, -1, false, {
      'Preview rendered to: ' .. image_path,
      '',
      'image.nvim needs to be setup first:',
      'require("image").setup()',
    })
    return
  end

  -- Display image using image.nvim (with pcall for safety)
  local img_ok, img = pcall(image.from_file, image_path, {
    buffer = M.preview_buf,
    window = M.preview_win,
    x = 0,
    y = 0,
    width = vim.api.nvim_win_get_width(M.preview_win),
  })

  if img_ok and img then
    img:render()
  else
    local err_msg = img_ok and 'unknown error' or tostring(img)
    vim.notify('[mdbuf] Failed to load image: ' .. err_msg, vim.log.levels.ERROR)
    vim.api.nvim_buf_set_lines(M.preview_buf, 0, -1, false, {
      'Preview rendered to: ' .. image_path,
      '',
      'Error loading image: ' .. err_msg,
    })
  end
end

---Sync scroll position based on source line
---@param source_line number
function M.sync_scroll(source_line)
  if not M.preview_win or not vim.api.nvim_win_is_valid(M.preview_win) then
    return
  end

  if not M.preview_buf or not vim.api.nvim_buf_is_valid(M.preview_buf) then
    return
  end

  if not M.source_map or not M.source_map.lineToY then
    return
  end

  -- Find nearest mapped line
  local target_y = nil
  local nearest_line = nil

  for line_str, y in pairs(M.source_map.lineToY) do
    local line = tonumber(line_str)
    if line and line <= source_line then
      if not nearest_line or line > nearest_line then
        nearest_line = line
        target_y = y
      end
    end
  end

  if target_y then
    -- Scroll preview window to target Y position
    -- This is approximate since we're dealing with pixels vs lines
    local win_height = vim.api.nvim_win_get_height(M.preview_win)
    local total_height = M.source_map.totalHeight or 1
    local scroll_ratio = target_y / total_height
    local scroll_line = math.floor(scroll_ratio * win_height)

    -- Ensure cursor position is within buffer bounds
    local buf_line_count = vim.api.nvim_buf_line_count(M.preview_buf)
    if buf_line_count > 0 then
      local safe_line = math.max(1, math.min(scroll_line, buf_line_count))
      pcall(vim.api.nvim_win_set_cursor, M.preview_win, { safe_line, 0 })
    end
  end
end

---Close preview window
function M.close()
  if M.preview_win and vim.api.nvim_win_is_valid(M.preview_win) then
    vim.api.nvim_win_close(M.preview_win, true)
  end

  M.preview_win = nil
  M.preview_buf = nil
  M.source_buf = nil
  M.source_map = nil
end

---Check if preview is open
---@return boolean
function M.is_open()
  return M.preview_win ~= nil and vim.api.nvim_win_is_valid(M.preview_win)
end

---Get preview window handle
---@return number|nil
function M.get_window()
  return M.preview_win
end

---Get source buffer
---@return number|nil
function M.get_source_buf()
  return M.source_buf
end

return M
