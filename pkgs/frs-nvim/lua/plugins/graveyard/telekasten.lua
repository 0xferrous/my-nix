return {
  {
    "renerocksai/telekasten.nvim",
    enabled = false,
    dependencies = { "nvim-telescope/telescope.nvim" },
    opts = {
      home = vim.fn.expand("~/notes-exp/telekasten"),
    },
  },
}
