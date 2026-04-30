local bigfile = require("cfg.bigfile")

local eevee = [[
⠀⠀⠀⠀⠀⠀⣀⣠⣤⡔⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡴⣧
⠀⠀⣀⣤⣶⣿⣿⣿⣿⣏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡾⠁⣼
⢠⣾⣿⣿⣿⣿⣿⣿⣿⢷⣆⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⡟⠀⠀⣿
⣾⣿⣿⣟⢛⣛⣛⣛⣋⠭⠥⠿⣿⣿⣷⣤⠀⠀⠀⢀⣀⣀⣠⣀⡀⢿⡇⠀⣸⡇
⣿⣿⣿⠻⢧⠙⢯⡀⠈⠉⠙⠛⠳⢦⣝⢿⣷⢠⣾⣿⣿⣿⣿⣯⣬⡥⢰⡟⠀
⢹⣯⣛⠯⢿⣾⣷⣍⡳⣤⣀⠀⠀⠀⠉⠳⣍⣿⣿⣿⣿⣿⣿⣿⣿⣿⡃⠀⠀
⠈⠹⣿⣿⣾⣿⣿⣿⣿⣷⣭⣛⠷⢦⣤⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⠀⠀
⠀⠀⠈⠛⠿⣿⣿⣿⣿⣿⢋⣵⡾⣣⣤⣦⢻⣿⣿⣿⣻⠻⣿⣿⣿⡏⠖⢻⠀⠀
⠀⠀⠀⠀⠀⠀⠈⠉⠉⣱⣿⡟⠼⣻⣿⣿⢸⣿⣿⡇⡛⠀⣿⣿⣿⣧⡠⣸⡇⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣷⢹⣿⣿⣿⣏⢿⣿⣷⣕⣧⣿⣿⣿⢿⣿⡿⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⣿⣿⣠⢿⣿⡟⣿⣷⣭⣻⠿⢿⠿⠷⢞⣫⣵⠿⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⣿⡟⣎⢿⣧⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⣿⣿⠁⠻⣷⡝⣩⣿⣿⣿⣿⣿⣿⠿⠁⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣿⣿⠀⠀⠀⠀⣿⣿⣿⠉⠙⢻⢟⣿⡇⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⣿⡀⠀⠸⣿⣿⡇⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⢿⡧⠀⠀⠈⠉⠀⠀⠀⠀⠀⠀
]]

local dashboard_opts = {
  enabled = true,
  preset = {
    keys = {
      {
        icon = " ",
        key = "f",
        desc = "Find File",
        action = ":lua require('fzf-lua').files()",
      },
      {
        icon = " ",
        key = "n",
        desc = "New File",
        action = ":ene | startinsert",
      },
      {
        icon = " ",
        key = "g",
        desc = "Find Text",
        action = ":lua require('fzf-lua').live_grep()"
      },
      {
        icon = " ",
        key = "r",
        desc = "Recent Files",
        action = ":lua Snacks.dashboard.pick('oldfiles')",
      },
      {
        icon = " ",
        key = "c",
        desc = "Config",
        action = ":lua require('fzf-lua').files({ cwd = vim.fn.stdpath('config'), prompt = 'Config Files> ' })"
      },
      {
        icon = " ",
        key = "s",
        desc = "Restore Session",
        action = ":lua MiniSessions.select()",
      },
      {
        icon = "󰒲 ",
        key = "L",
        desc = "Lazy",
        action = ":Lazy",
        enabled = package.loaded.lazy ~= nil,
      },
      {
        icon = " ",
        key = "q",
        desc = "Quit",
        action = ":qa",
      },
    },
    header = eevee,
  },
  sections = {
    { section = "header" },
    { section = "keys", gap = 1, padding = 1, pane = 2 },
  },
}

return {
  {
    "ibhagwan/fzf-lua",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      "default-title",
      winopts = {
        preview = {
          layout = "flex",
        },
      },
      files = {
        fd_opts = "--color=never --type f --hidden --follow --exclude .git",
      },
      grep = {
        rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden --glob '!.git'",
        rg_glob = true,
        glob_flag = "--iglob",
        glob_separator = "%s%-%-",
        winopts = {
          preview = {
            layout = "vertical",
            vertical = "down:60%",
          },
        },
      },
    },
    config = function(spec)
      local fzf = require("fzf-lua")
      fzf.setup(spec.opts)

      vim.keymap.set("n", "<leader>sh", fzf.help_tags, { desc = "[S]earch [H]elp" })
      vim.keymap.set("n", "<leader>sk", fzf.keymaps, { desc = "[S]earch [K]eymaps" })
      vim.keymap.set("n", "<leader>sf", fzf.files, { desc = "[S]earch [F]iles" })
      vim.keymap.set("n", "<leader>ss", fzf.builtin, { desc = "[S]earch [S]elect pickers" })
      vim.keymap.set("n", "<leader>sw", fzf.grep_cword, { desc = "[S]earch current [W]ord" })
      vim.keymap.set("n", "<leader>sg", fzf.live_grep, { desc = "[S]earch by [G]rep with globs" })
      vim.keymap.set("n", "<leader>sd", fzf.diagnostics_workspace, { desc = "[S]earch [D]iagnostics" })
      vim.keymap.set("n", "<leader>sr", fzf.resume, { desc = "[S]earch [R]esume" })
      vim.keymap.set("n", "<leader>s.", fzf.oldfiles, { desc = "[S]earch Recent Files (\".\" for repeat)" })
      vim.keymap.set("n", "<leader>gf", fzf.git_files, { desc = "Search [G]it [F]iles" })
      vim.keymap.set("n", "<leader><space>", fzf.buffers, { desc = "[ ] Find existing buffers" })
      vim.keymap.set("n", "<leader>/", fzf.blines, { desc = "[/] Fuzzily search in current buffer" })
      vim.keymap.set("n", "<leader>s/", fzf.grep_curbuf, { desc = "[S]earch [/] in Open Files" })
      vim.keymap.set("n", "<leader>sn", function()
        fzf.files({ cwd = vim.fn.stdpath("config"), prompt = "Config Files> " })
      end, { desc = "[S]earch [N]eovim files" })
    end,
  },
  {
    "folke/snacks.nvim",
    priority = 1000,
    event = "VimEnter",
    opts = {
      picker = {},
      image = { enabled = true },
      dashboard = dashboard_opts,
      terminal = {},
      bigfile = bigfile.defaults,
      quickfile = { enabled = true },
      scratch = { enabled = true },
      notifier = { enabled = true, style = "minimal" },
    },
    keys = {
      {
        "<leader>.",
        "<cmd>lua Snacks.scratch()<cr>",
        desc = "Toggle Scratch Buffer",
      },
      {
        "<leader>SS",
        "<cmd>lua Snacks.scratch.select()<cr>",
        desc = "[S]earch [H]elp",
      },
    },
    config = function(opts)
      local snacks = require("snacks")
      local snacks_git = require("snacks.git")
      snacks.setup(opts.opts)

      vim.api.nvim_create_user_command("Notifications", function()
        snacks.notifier.show_history()
      end, { desc = "Show notifications history", force = true })

      vim.keymap.set("n", "<leader>un", "<cmd>lua Snacks.notifier.show_history()<cr>", { desc = "Show [N]otification history" })
    end,
  },
}
