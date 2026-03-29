local bigfile = require("cfg.bigfile")

local function fff_find_files(opts)
  return function() require("fff").find_files(opts) end
end

local function fff_live_grep(opts)
  return function()
    local resolved_opts = opts
    if type(opts) == "function" then
      resolved_opts = opts()
    end
    require("fff").live_grep(resolved_opts)
  end
end

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
        action = ":lua require('fff').find_files()",
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
        action = ":lua require('fff').live_grep()",
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
        action = ":lua require('fff').find_files({ cwd = vim.fn.stdpath('config'), title = 'Config Files' })",
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

      vim.keymap.set("n", "<leader>sh", "<cmd>lua Snacks.picker.help()<cr>", { desc = "[S]earch [H]elp" })
      vim.keymap.set("n", "<leader>sk", "<cmd>lua Snacks.picker.keymaps()<cr>", { desc = "[S]earch [K]eymaps" })
      vim.keymap.set("n", "<leader>sf", fff_find_files(), { desc = "[S]earch [F]iles" })
      vim.keymap.set("n", "<leader>ss", "<cmd>lua Snacks.picker.pickers()<cr>", { desc = "[S]earch [S]elect pickers" })
      vim.keymap.set("n", "<leader>sw", fff_live_grep(function()
        return { query = vim.fn.expand("<cword>") }
      end), { desc = "[S]earch current [W]ord" })
      vim.keymap.set("n", "<leader>sg", fff_live_grep(), { desc = "[S]earch by [G]rep" }) -- sde ; sdw
      vim.keymap.set("n", "<leader>sd", "<cmd>lua Snacks.picker.diagnostics()<cr>", { desc = "[S]earch [D]iagnostics" })
      vim.keymap.set("n", "<leader>sr", "<cmd>lua Snacks.picker.resume()<cr>", { desc = "[S]earch [R]esume" })
      vim.keymap.set("n", "<leader>s.", "<cmd>lua Snacks.picker.recent()<cr>", { desc = "[S]earch Recent Files (\".\" for repeat)" })
      vim.keymap.set("n", "<leader>gf", "<cmd>lua Snacks.picker.git_files()<cr>", { desc = "Search [G]it [F]iles" })
      vim.keymap.set("n", "<leader><space>", "<cmd>lua Snacks.picker.buffers({ filter = { cwd = true } })<cr>", { desc = "[ ] Find existing buffers" })
      vim.keymap.set("n", "<leader>/", "<cmd>lua Snacks.picker.lines()<cr>", { desc = "[/] Fuzzily search in current buffer" })
      vim.keymap.set("n", "<leader>s/", "<cmd>lua Snacks.picker.grep_buffers()<cr>", { desc = "[S]earch [/] in Open Files" })
      vim.keymap.set("n", "<leader>sn", fff_find_files({ cwd = vim.fn.stdpath("config"), title = "Config Files" }), { desc = "[S]earch [N]eovim files" })
      vim.keymap.set("n", "<leader>un", "<cmd>lua Snacks.notifier.show_history()<cr>", { desc = "Show [N]otification history" })
    end,
  },
}
