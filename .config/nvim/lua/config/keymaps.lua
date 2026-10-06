-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "<leader>mp", function()
  vim.cmd("vsplit | terminal glow " .. vim.fn.expand("%"))
end, { desc = "Markdown Preview (glow)" })

vim.keymap.set("n", "<leader>W", ":wa<CR>", { desc = "Write all buffers" })
vim.keymap.set("n", "<leader>Q", ":qa<CR>", { desc = "Quit all" })
vim.keymap.set("n", "<leader>h", ":nohlsearch<CR>", { desc = "Clear search highlight" })
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search result centered" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Previous search result centered" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
vim.keymap.set("n", "<leader>t", ":terminal<CR>", { desc = "Open terminal" })

vim.keymap.set("i", "<C-BS>", "<C-w>", { desc = "Delete word before cursor" })
vim.keymap.set("i", "<C-Del>", "<C-o>dw", { desc = "Delete word after cursor" })
vim.keymap.set("i", "<C-Left>", "<C-o>b", { desc = "Move back one word" })
vim.keymap.set("i", "<C-Right>", "<C-o>w", { desc = "Move forward one word" })
