-- Minimal Neovim configuration for running tests with plenary.nvim
-- Usage: nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/plenary"

-- Try common plugin manager paths for plenary.nvim
local plugin_paths = {
  vim.fn.stdpath('data') .. '/lazy/plenary.nvim',
  vim.fn.stdpath('data') .. '/site/pack/packer/start/plenary.nvim',
  vim.fn.stdpath('data') .. '/site/pack/vendor/start/plenary.nvim',
  vim.fn.expand('~/.local/share/nvim/site/pack/vendor/start/plenary.nvim'),
  vim.fn.expand('~/.local/share/nvim/lazy/plenary.nvim'),
  -- For CI: plenary installed via luarocks or git clone
  vim.fn.getcwd() .. '/deps/plenary.nvim',
}

for _, path in ipairs(plugin_paths) do
  if vim.loop.fs_stat(path) then
    vim.opt.rtp:prepend(path)
    break
  end
end

-- Add the plugin itself to runtimepath
local plugin_root = vim.fn.fnamemodify(vim.fn.expand('<sfile>:p:h'), ':h')
vim.opt.rtp:prepend(plugin_root)

-- Set up runtime for tests
vim.cmd([[runtime plugin/plenary.vim]])

-- Configure for headless testing
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false
