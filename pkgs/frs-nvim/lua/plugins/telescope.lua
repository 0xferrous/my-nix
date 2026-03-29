return {
  {
    "nvim-telescope/telescope.nvim",
    event = "VimEnter",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        cond = function()
          return vim.fn.executable("make") == 1
        end,
      },
      "nvim-telescope/telescope-ui-select.nvim",
      {
        "0xferrous/telescope-project.nvim",
        branch = "feat/osc7",
      },
      "debugloop/telescope-undo.nvim",
    },
    config = function()
      local opts = {
        extensions = {
          project = {
            base_dirs = { "~/dev" },
            enable_osc7 = true,
          },
          undo = {},
          ["ui-select"] = { require("telescope.themes").get_dropdown() },
        },
        pickers = {
          buffers = {
            sort_mru = true,
            cwd_only = true,
            mappings = {
              i = {
                ["<C-d>"] = "delete_buffer",
              },
            },
          },
        },
        defaults = {
          mappings = {
            i = {
              ["<C-u>"] = false,
              ["<C-d>"] = false,
            },
          },
        },
      }

      local telescope = require("telescope")
      local telescope_builtin = require("telescope.builtin")
      local plenary_functional = require("plenary.functional")

      telescope.setup(opts)

      -- Enable Telescope extensions if they are installed
      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "ui-select")
      pcall(telescope.load_extension, "project")
      pcall(telescope.load_extension, "undo")

      -- Project switcher
      vim.api.nvim_set_keymap(
        "n",
        "<C-p>",
        ":lua require'telescope'.extensions.project.project{}<CR>",
        { noremap = true, silent = true, desc = "Switch [p]roject" }
      )
    end,
  },
}
