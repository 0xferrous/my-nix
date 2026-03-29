return {
  {
    "nvim-mini/mini.nvim",
    event = "VeryLazy",
    config = function()
      require("mini.ai").setup({ n_lines = 500 })
      require("mini.surround").setup({
        mappings = {
          add = "ys",
          delete = "ds",
          change = "cs",
        },
      })

      local MiniSessions = require("mini.sessions")
      local input = require("snacks").input.input

      MiniSessions.setup()

      vim.keymap.set("n", "<leader>Sc", function()
        input("Session name: ", function(session_name)
          MiniSessions.write(session_name)
        end)
      end, { desc = "Write a new session" })

      vim.keymap.set("n", "<leader>Ss", MiniSessions.select, { desc = "Select a session" })

      local indentscope = require("mini.indentscope")
      indentscope.setup({
        draw = {
          animation = indentscope.gen_animation.none(),
        },
      })
    end,
  },
}
