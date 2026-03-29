return {
  -- Comment plugin - load on keys
  {
    "numToStr/Comment.nvim",
    event = "VeryLazy",
    opts = {},
  },
  -- GitHub integration - load on command
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    opts = {},
  },
  -- Motion plugin - load on keys
  {
    "smoka7/hop.nvim",
    keys = { "s", "S" },
    opts = {},
  },
  -- Better % matching - load with buffers
  {
    "andymass/vim-matchup",
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
  },
  -- TODO highlighting
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },
  -- Auto pairs - load on insert
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },
  -- Quickfix improvements - load on quickfix
  {
    "yorickpeterse/nvim-pqf",
    event = "VeryLazy",
    opts = {},
  },
  -- Floating help
  {
    "Tyler-Barham/floating-help.nvim",
    cmd = "FloatingHelp",
    opts = {},
  },
  -- Winbar breadcrumbs
  {
    "Bekaboo/dropbar.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-telescope/telescope-fzf-native.nvim" },
    opts = {},
  },
  -- Git link generation
  {
    "ruifm/gitlinker.nvim",
    keys = { { "<leader>gy", mode = { "n", "v" } } },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },
  -- File explorer
  {
    "stevearc/oil.nvim",
    cmd = "Oil",
    keys = { { "-" } },
    dependencies = { "echasnovski/mini.icons" },
    opts = {},
  },
  -- Markdown rendering
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "Avante", "codecompanion" },
    opts = { filetypes = { "markdown", "Avante", "codecompanion" } },
  },
  -- Buffer management
  {
    "stevearc/stickybuf.nvim",
    event = "VeryLazy",
    opts = {},
  },
  -- Paredit for lisp
  {
    "julienvincent/nvim-paredit",
    ft = { "clojure", "fennel", "lisp", "scheme" },
    opts = {},
  },
  -- Git commands
  {
    "tpope/vim-fugitive",
    cmd = { "Git", "G", "Gvdiffsplit", "Gread", "Gwrite", "Ggrep", "GMove", "GDelete", "GBrowse" },
  },
  -- Detect indent
  {
    "tpope/vim-sleuth",
    event = { "BufReadPost", "BufNewFile" },
  },
  -- Vim game
  {
    "ThePrimeagen/vim-be-good",
    cmd = "VimBeGood",
  },
  -- Icons (needed by other plugins)
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },
  -- Symbols outline
  {
    "simrat39/symbols-outline.nvim",
    cmd = "SymbolsOutline",
  },
  -- Per project notes
  {
    "JellyApple102/flote.nvim",
    cmd = "Flote",
  },
  -- Rainbow delimiters
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = { "BufReadPost", "BufNewFile" },
  },
  -- Startuptime profiling
  {
    "dstein64/vim-startuptime",
    cmd = "StartupTime",
  },
  -- ASCII diagrams
  {
    "jbyuki/venn.nvim",
    cmd = "VBox",
  },
  -- Activity tracking
  {
    "ActivityWatch/aw-watcher-vim",
    event = "VeryLazy",
  },
  -- Unix commands
  {
    "tpope/vim-eunuch",
    cmd = { "Remove", "Delete", "Move", "Rename", "Chmod", "Mkdir", "SudoWrite", "SudoEdit" },
  },
  -- TypeScript syntax
  {
    "HerringtonDarkholme/yats.vim",
    ft = { "typescript", "typescriptreact" },
  },
  -- Bracket mappings
  {
    "tpope/vim-unimpaired",
    keys = { "[", "]" },
  },
  -- Conflict markers
  {
    "rhysd/conflict-marker.vim",
    event = "VeryLazy",
  },
}
