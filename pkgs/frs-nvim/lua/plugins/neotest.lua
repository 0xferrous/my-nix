return {
  {
    "llllvvuu/neotest-foundry",
    lazy = true,
  },
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "llllvvuu/neotest-foundry",
    },
    lazy = true,
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-foundry"),
        },
      })
    end,
  },
}
