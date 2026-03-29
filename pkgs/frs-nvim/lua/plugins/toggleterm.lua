return {
  {
    "akinsho/toggleterm.nvim",
    keys = { "tt" },
    opts = {
      direction = "float",
      open_mapping = "tt",
      insert_mappings = false,
      terminal_mappings = false,
      shell = "/run/current-system/sw/bin/nu",
    },
  },
  {
    "ryanmsnyder/toggleterm-manager.nvim",
    lazy = true,
    dependencies = {
      "akinsho/nvim-toggleterm.lua",
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
    },
    config = function()
      local toggleterm_manager = require("toggleterm-manager")
      local actions = toggleterm_manager.actions

      toggleterm_manager.setup({
        mappings = {
          i = {
            ["<CR>"] = {
              action = actions.toggle_term,
              exit_on_action = true,
            },
            ["<C-i>"] = {
              action = actions.create_term,
              exit_on_action = false,
            },
            ["<C-d>"] = {
              action = actions.delete_term,
              exit_on_action = false,
            },
            ["<C-r>"] = {
              action = actions.rename_term,
              exit_on_action = false,
            },
          },
        },
      })
    end,
  },
}
