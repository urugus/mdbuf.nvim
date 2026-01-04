# mdbuf.nvim

Markdown preview in Neovim buffer using sixel graphics.

## Features

- Browser-quality markdown rendering using Playwright
- In-buffer preview via sixel graphics (requires image.nvim)
- Vertical/horizontal split preview
- Auto-refresh on save
- Scroll synchronization
- Light/dark theme support
- Custom CSS support

## Requirements

- Neovim 0.9+
- Node.js 18+
- [image.nvim](https://github.com/3rd/image.nvim) for in-buffer image display
- Sixel-capable terminal (Ghostty, WezTerm, etc.)

## Installation

### Using lazy.nvim

```lua
{
  'username/mdbuf.nvim',
  build = 'cd server && npm install && npm run build',
  dependencies = {
    '3rd/image.nvim',
  },
  ft = 'markdown',
  opts = {
    -- your configuration
  },
}
```

### Using packer.nvim

```lua
use {
  'username/mdbuf.nvim',
  run = 'cd server && npm install && npm run build',
  requires = { '3rd/image.nvim' },
  config = function()
    require('mdbuf').setup({})
  end,
}
```

## Setup

```lua
require('mdbuf').setup({
  -- Server settings
  server = {
    cmd = nil,          -- nil = auto-detect, or {"node", "path/to/server"}
    timeout = 10000,    -- Startup timeout in ms
  },

  -- Preview window settings
  preview = {
    split = 'vertical', -- 'vertical' or 'horizontal'
    width = 50,         -- Width percent for vertical split
    height = 50,        -- Height percent for horizontal split
  },

  -- Render settings
  render = {
    theme = 'light',    -- 'light' or 'dark'
    width = 800,        -- Render width in pixels
    pixels_per_char = 12, -- Fallback pixels/column when terminal doesn't report pixel size
    custom_css = nil,   -- Path to custom CSS file
  },

  -- Behavior settings
  behavior = {
    auto_open = false,  -- Auto-open preview for markdown files
    auto_close = true,  -- Close preview when source buffer closes
    sync_scroll = true, -- Enable scroll synchronization
  },
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:MdbufOpen` | Open markdown preview |
| `:MdbufClose` | Close markdown preview |
| `:MdbufToggle` | Toggle markdown preview |
| `:MdbufRefresh` | Manually refresh preview |

## Keymaps

mdbuf.nvim doesn't set any keymaps by default. Here's a recommended configuration:

```lua
vim.keymap.set('n', '<leader>mp', '<cmd>MdbufToggle<cr>', { desc = 'Toggle markdown preview' })
vim.keymap.set('n', '<leader>mr', '<cmd>MdbufRefresh<cr>', { desc = 'Refresh markdown preview' })
```

## How It Works

1. Markdown content is sent to a TypeScript server via JSON-RPC
2. Server converts markdown to HTML using [marked](https://marked.js.org/)
3. HTML is rendered to PNG using [Playwright](https://playwright.dev/)
4. PNG is displayed in Neovim buffer using [image.nvim](https://github.com/3rd/image.nvim)

## Development

### Building the server

```bash
cd server
npm install
npm run build
```

### Running in development mode

```bash
cd server
npm run dev
```

### CLI tool for testing

```bash
cd server
npm run render -- README.md output.png
```

### Server unit tests (Vitest)

```bash
cd server
npm run test
```

```bash
cd server
npm run test:watch
```

## License

MIT
