return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, { "prisma" })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    opts = {
      servers = {
        prismals = {},
      },
    },
  },
  {
    "LazyVim/LazyVim",
    init = function()
      vim.filetype.add({
        extension = {
          prisma = "prisma",
        },
      })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "prisma",
        callback = function()
          vim.lsp.enable("prismals")
        end,
      })
    end,
  },
}
