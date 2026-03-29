return {
  { "catppuccin/nvim", name = "catppuccin", lazy = true },
  {
    "rose-pine/neovim",
    lazy = true,
    config = function()
      local rose_pine = require("rose-pine")
      rose_pine.setup({ enable = { terminal = false } })
    end,
  },
  { "rebelot/kanagawa.nvim", lazy = true },
  { "nyoom-engineering/oxocarbon.nvim", lazy = true },
  { "nvimdev/nightsky.vim", lazy = true },
  {
    "folke/tokyonight.nvim",
    lazy = true,
    opts = {
      styles = {
        comments = { italic = true },
        functions = { italic = true },
      },
    },
  },
  { "oxfist/night-owl.nvim", lazy = true },
  { "cocopon/iceberg.vim", lazy = true },
  {
    "sainnhe/gruvbox-material",
    priority = 1000,
    lazy = false,
    config = function()
      vim.g.gruvbox_material_enable_italic = true
      vim.g.gruvbox_material_background = "hard"
      vim.g.gruvbox_material_foreground = "original"
      vim.g.gruvbox_material_inlay_hints_background = "dimmed"
      if vim.g.neovide then
        vim.g.gruvbox_material_transparent_background = 0
      end
      if vim.g.neovide == true then
        vim.g.gruvbox_material_transparent_background = 0
      else
        vim.g.gruvbox_material_transparent_background = 1
      end
    end,
  },
}
