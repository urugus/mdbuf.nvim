---@class MdbufTerminal
---@field private cached_size table|nil

local M = {}

-- Cached terminal size information
local cached_size = nil
local autocmd_registered = false

---Get terminal size using TIOCGWINSZ ioctl
---@return table|nil size { screen_x, screen_y, screen_cols, screen_rows, cell_width, cell_height }
local function query_terminal_size()
  local ok, ffi = pcall(require, 'ffi')
  if not ok then
    return nil
  end

  -- TIOCGWINSZ constants for different platforms
  local TIOCGWINSZ = {
    linux = 0x5413,
    osx = 0x40087468,
  }

  local platform = ((jit and jit.os) or 'linux'):lower()

  -- Windows is not supported for ioctl-based terminal size detection
  if platform == 'windows' then
    return nil
  end

  local constant = TIOCGWINSZ[platform] or TIOCGWINSZ.linux

  -- Define winsize struct if not already defined
  pcall(function()
    ffi.cdef([[
      typedef struct {
        unsigned short ws_row;
        unsigned short ws_col;
        unsigned short ws_xpixel;
        unsigned short ws_ypixel;
      } mdbuf_winsize;
      int ioctl(int fd, unsigned long request, ...);
    ]])
  end)

  local sz = ffi.new('mdbuf_winsize')

  -- Wrap ioctl call in pcall for safety
  local ok_ioctl, result = pcall(function()
    return ffi.C.ioctl(1, constant, sz) -- stdout = 1
  end)
  if not ok_ioctl then
    return nil
  end

  if result == 0 and sz.ws_col > 0 and sz.ws_row > 0 then
    local xpixel = tonumber(sz.ws_xpixel) or 0
    local ypixel = tonumber(sz.ws_ypixel) or 0
    local cols = tonumber(sz.ws_col)
    local rows = tonumber(sz.ws_row)

    -- Calculate cell size (some terminals may not report pixel size)
    local cell_width = xpixel > 0 and (xpixel / cols) or nil
    local cell_height = ypixel > 0 and (ypixel / rows) or nil

    return {
      screen_x = xpixel,
      screen_y = ypixel,
      screen_cols = cols,
      screen_rows = rows,
      cell_width = cell_width,
      cell_height = cell_height,
    }
  end

  return nil
end

---Register VimResized autocmd (called lazily)
local function ensure_autocmd()
  if autocmd_registered then
    return
  end
  autocmd_registered = true

  vim.api.nvim_create_autocmd('VimResized', {
    group = vim.api.nvim_create_augroup('mdbuf_terminal', { clear = true }),
    callback = function()
      M.update_size()
    end,
  })
end

---Update cached terminal size
---@return table size { screen_x, screen_y, screen_cols, screen_rows, cell_width, cell_height }
function M.update_size()
  local size = query_terminal_size()

  if size and size.cell_width and size.cell_width > 0 then
    cached_size = size
  else
    -- Fallback to config value or default
    local ok, config = pcall(require, 'mdbuf.config')
    local fallback_ppc = 12
    if ok and config.options and config.options.render then
      fallback_ppc = config.options.render.pixels_per_char or 12
    end

    cached_size = {
      cell_width = fallback_ppc,
      cell_height = fallback_ppc * 2, -- Approximate 2:1 ratio
      screen_x = 0,
      screen_y = 0,
      screen_cols = vim.o.columns,
      screen_rows = vim.o.lines,
    }
  end

  return cached_size
end

---Get cached terminal size (updates if not cached)
---@return table size { screen_x, screen_y, screen_cols, screen_rows, cell_width, cell_height }
function M.get_size()
  if not cached_size then
    M.update_size()
    ensure_autocmd()
  end
  return cached_size
end

---Get cell width in pixels
---@return number
function M.get_cell_width()
  local size = M.get_size()
  return size.cell_width
end

---Get cell height in pixels
---@return number
function M.get_cell_height()
  local size = M.get_size()
  return size.cell_height
end

return M
