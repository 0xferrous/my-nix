return {
  {
    "0xferrous/ansi.nvim",
    ft = "ansi",
    opts = {
      auto_enable = true,
      filetypes = { "ansi" },
      theme = "gruvbox_dark",
    },
  },
  {
    "0xferrous/eth.nvim",
    lazy = true,
    opts = {},
  },
  {
    "0xferrous/diffie.nvim",
    opts = {
      theme = "gruvbox_dark_hard",
    },
  },
  { "elkowar/yuck.vim", ft = "yuck" },
  { "iden3/vim-circom-syntax", ft = "circom" },
  {
    "morhetz/gruvbox",
    lazy = true,
    config = function()
      vim.g.gruvbox_italic = 1
      vim.g.gruvbox_improved_strings = 1
      vim.g.gruvbox_undercurl = 1
    end,
  },
  {
    "rafcamlet/nvim-luapad",
    cmd = { "Luapad", "LuaRun" },
    config = function()
      vim.keymap.set("n", "<leader>lr", ":LuaRun<CR>", { desc = "[L]ua [R]un" })
    end,
  },
  {
    "rmagatti/goto-preview",
    dependencies = { "rmagatti/logger.nvim" },
    event = "VeryLazy",
    config = true,
  },
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = { "org" },
    config = function()
      local data_dir = vim.fn.stdpath("data")
      require("orgmode").setup({
        org_agenda_files = data_dir .. "/org/**/*",
        org_default_notes_file = data_dir .. "/org/refile.org",
      })
    end,
  },
  {
    "RRethy/vim-illuminate",
    event = "VeryLazy",
    config = function()
      require("illuminate").configure({
        min_count_to_highlight = 2,
        providers = { "lsp", "regex" },
      })
    end,
  },
  { "godlygeek/tabular", cmd = "Tabularize" },
  { "dhruvasagar/vim-table-mode", ft = { "markdown", "org", "txt" } },
  {
    "mikesmithgh/kitty-scrollback.nvim",
    lazy = true,
    cmd = {
      "KittyScrollbackGenerateKittens",
      "KittyScrollbackCheckHealth",
      "KittyScrollbackGenerateCommandLineEditing",
    },
    event = { "User KittyScrollbackLaunch" },
    config = true,
    opts = {
      { restore_options = true },
    },
  },
  {
    "glacambre/firenvim",
    lazy = true,
  },
}
