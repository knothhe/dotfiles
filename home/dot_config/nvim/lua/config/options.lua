-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Show whitespace characters
vim.opt.list = true
vim.opt.listchars = {
	tab = "▸ ",
	trail = "·",
	nbsp = "␣",
	space = "·",
}

-- Set default indentation to 4 spaces
vim.opt.tabstop = 4 -- Number of spaces a <Tab> counts for
vim.opt.softtabstop = 4 -- Number of spaces <Tab> counts for while editing
vim.opt.shiftwidth = 4 -- Number of spaces for indentation
vim.opt.expandtab = true -- Use spaces instead of tabs
vim.opt.smartindent = true
vim.opt.autoindent = true

-- Use terminal colors
vim.opt.termguicolors = true

