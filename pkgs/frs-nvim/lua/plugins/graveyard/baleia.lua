return {
  {
    "m00qek/baleia.nvim",
    enabled = false,
    ft = "ansi",
    config = function()
      vim.g.baleia = require("baleia").setup({})
      vim.api.nvim_create_user_command("BaleiaColorize", function()
        vim.g.baleia:once(vim.api.nvim_get_current_buf())
      end, { bang = true })

      vim.api.nvim_create_user_command("BaleiaLogs", function()
        vim.g.baleia.logger:show()
      end, { bang = true })

      if vim.bo.filetype == "ansi" then
        vim.cmd("BaleiaColorize")
      end

      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "*.ansi",
        callback = function()
          vim.cmd("BaleiaColorize")
        end,
        desc = "Auto-colorize ANSI files with Baleia",
      })
    end,
  },
}
