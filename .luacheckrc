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

-- Test-specific configuration
files["tests/**/*.lua"] = {
  globals = {
    "describe",
    "it",
    "before_each",
    "after_each",
    "assert",
    "vim", -- Allow modifying vim for mocking in tests
    "debug", -- Allow modifying debug.getinfo for path mocking
  },
}
