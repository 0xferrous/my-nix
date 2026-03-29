return {
  {
    "clabby/difftastic.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    config = function()
      require("difftastic-nvim").setup()
    end,
  },
}
