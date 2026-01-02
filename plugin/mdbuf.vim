" mdbuf.nvim - Markdown preview in Neovim buffer
" Maintainer: Your Name
" License: MIT

if exists('g:loaded_mdbuf')
  finish
endif
let g:loaded_mdbuf = 1

" Minimum Neovim version check
if !has('nvim-0.9')
  echohl ErrorMsg
  echom 'mdbuf.nvim requires Neovim 0.9 or later'
  echohl None
  finish
endif

" Check for required features
if !has('nvim')
  echohl ErrorMsg
  echom 'mdbuf.nvim requires Neovim'
  echohl None
  finish
endif
