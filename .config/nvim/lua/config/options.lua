-- Options are automatically loaded before lazy.nvim startup.
require("config.remote_clipboard").setup()

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.g.autoformat = false

vim.opt.relativenumber = false
vim.opt.number = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.signcolumn = "yes:1"
vim.opt.colorcolumn = "100"
vim.opt.cursorline = true
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.termguicolors = true
vim.opt.updatetime = 200
vim.opt.timeoutlen = 300
vim.opt.undofile = true
vim.opt.undolevels = 10000
vim.opt.backspace = { "indent", "eol", "start" }
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.wrap = false
vim.opt.mouse = "a"
vim.opt.confirm = true
vim.opt.grepprg = "rg --vimgrep"
vim.opt.fillchars = "eob: ,fold: ,foldopen:,foldclose:"
vim.opt.foldlevel = 99
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.shortmess:append("I")
vim.opt.swapfile = false
vim.opt.undodir = vim.fn.stdpath("state") .. "/undo"
vim.opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }
