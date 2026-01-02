---@class Mdbuf
---@field config MdbufConfig
---@field setup fun(opts?: table)
---@field open_preview fun()
---@field close_preview fun()
---@field toggle_preview fun()
---@field refresh fun()

local config = require('mdbuf.config')
local rpc = require('mdbuf.rpc')
local window = require('mdbuf.window')
local render = require('mdbuf.render')

local M = {}

---Setup mdbuf plugin
---@param opts? table
function M.setup(opts)
  config.setup(opts)

  -- Create user commands
  vim.api.nvim_create_user_command('MdbufOpen', function()
    M.open_preview()
  end, { desc = 'Open markdown preview' })

  vim.api.nvim_create_user_command('MdbufClose', function()
    M.close_preview()
  end, { desc = 'Close markdown preview' })

  vim.api.nvim_create_user_command('MdbufToggle', function()
    M.toggle_preview()
  end, { desc = 'Toggle markdown preview' })

  vim.api.nvim_create_user_command('MdbufRefresh', function()
    M.refresh()
  end, { desc = 'Refresh markdown preview' })

  -- Create autocommands
  local augroup = vim.api.nvim_create_augroup('mdbuf', { clear = true })

  -- Auto-refresh on save
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = augroup,
    pattern = { '*.md', '*.markdown' },
    callback = function(args)
      if window.is_open() and window.get_source_buf() == args.buf then
        render.render(args.buf)
      end
    end,
    desc = 'Refresh mdbuf preview on save',
  })

  -- Auto-close preview when source buffer closes
  if config.options.behavior.auto_close then
    vim.api.nvim_create_autocmd('BufDelete', {
      group = augroup,
      callback = function(args)
        if window.get_source_buf() == args.buf then
          M.close_preview()
        end
      end,
      desc = 'Close mdbuf preview when source closes',
    })
  end

  -- Scroll sync
  if config.options.behavior.sync_scroll then
    vim.api.nvim_create_autocmd('CursorMoved', {
      group = augroup,
      pattern = { '*.md', '*.markdown' },
      callback = function(args)
        if window.is_open() and window.get_source_buf() == args.buf then
          local cursor = vim.api.nvim_win_get_cursor(0)
          window.sync_scroll(cursor[1])
        end
      end,
      desc = 'Sync mdbuf scroll position',
    })
  end

  -- Auto-open preview for markdown files
  if config.options.behavior.auto_open then
    vim.api.nvim_create_autocmd('BufEnter', {
      group = augroup,
      pattern = { '*.md', '*.markdown' },
      callback = function(args)
        if not window.is_open() then
          M.open_preview()
        end
      end,
      desc = 'Auto-open mdbuf preview',
    })
  end

  -- Cleanup on exit
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    callback = function()
      rpc.stop_server()
    end,
    desc = 'Stop mdbuf server on exit',
  })
end

---Open markdown preview
function M.open_preview()
  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.bo[buf].filetype

  if ft ~= 'markdown' then
    vim.notify('[mdbuf] Current buffer is not markdown', vim.log.levels.WARN)
    return
  end

  render.preview(buf)
end

---Close markdown preview
function M.close_preview()
  window.close()
end

---Toggle markdown preview
function M.toggle_preview()
  if window.is_open() then
    M.close_preview()
  else
    M.open_preview()
  end
end

---Refresh preview (re-render current buffer)
function M.refresh()
  if not window.is_open() then
    vim.notify('[mdbuf] Preview not open', vim.log.levels.WARN)
    return
  end

  local source_buf = window.get_source_buf()
  if source_buf then
    render.render(source_buf)
  end
end

return M
