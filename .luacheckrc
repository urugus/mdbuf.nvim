-- Luacheck configuration for Neovim plugins
std = "lua51"

globals = {
  "vim",
}

read_globals = {
  "vim",
}

-- Ignore some warnings
ignore = {
  "212", -- Unused argument
  "631", -- Line too long
}

-- Max line length
max_line_length = 120
