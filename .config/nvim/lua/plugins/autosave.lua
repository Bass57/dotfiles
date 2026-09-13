return {
  {
    "Pocco81/auto-save.nvim",
    event = "InsertLeave",
    opts = {
      enabled = true,
      execution_message = {
        message = function()
          return "Saved"
        end,
        dim = 0.18,
        cleaning_interval = 1250,
      },
      trigger_events = { "InsertLeave", "TextChanged" },
      condition = function(buf)
        if not vim.api.nvim_buf_is_valid(buf) then
          return false
        end
        return vim.bo[buf].modifiable and vim.bo[buf].filetype ~= "lua"
      end,
    },
  },
}
