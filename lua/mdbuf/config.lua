---@class MdbufServerConfig
---@field cmd? string[] Server command (nil = auto-detect)
---@field timeout number Startup timeout in ms

---@class MdbufPreviewConfig
---@field split "vertical"|"horizontal" Split direction
---@field width number Width percent for vertical split
---@field height number Height percent for horizontal split

---@class MdbufRenderConfig
---@field theme "light"|"dark" Color theme
---@field width number Render width in pixels
---@field pixels_per_char number Pixels per character for viewport calculation
---@field custom_css? string Path to custom CSS file

---@class MdbufBehaviorConfig
---@field auto_open boolean Auto-open preview for markdown files
---@field auto_close boolean Close preview when source closes
---@field sync_scroll boolean Enable scroll synchronization

---@class MdbufConfig
---@field server MdbufServerConfig
---@field preview MdbufPreviewConfig
---@field render MdbufRenderConfig
---@field behavior MdbufBehaviorConfig

local M = {}

---@type MdbufConfig
M.defaults = {
  server = {
    cmd = nil,
    timeout = 10000,
  },
  preview = {
    split = 'vertical',
    width = 50,
    height = 50,
  },
  render = {
    theme = 'light',
    width = 800,
    pixels_per_char = 12,
    custom_css = nil,
  },
  behavior = {
    auto_open = false,
    auto_close = true,
    sync_scroll = true,
  },
}

---@type MdbufConfig
M.options = vim.deepcopy(M.defaults)

---@param opts? table
function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', M.defaults, opts or {})
end

---Get the server command
---@return string[]
function M.get_server_cmd()
  if M.options.server.cmd then
    return M.options.server.cmd
  end

  -- Auto-detect server location
  local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h:h')
  local server_path = plugin_root .. '/server'
  local dist_index = server_path .. '/dist/index.js'
  local src_index = server_path .. '/src/index.ts'

  -- Try compiled version first
  if vim.fn.filereadable(dist_index) == 1 then
    return { 'node', dist_index }
  end

  -- Fall back to tsx for development
  if vim.fn.filereadable(src_index) == 1 then
    return { 'npx', 'tsx', src_index }
  end

  error('mdbuf: Server not found. Run `npm install && npm run build` in ' .. server_path)
end

return M
