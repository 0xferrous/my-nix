return {
  {
    "zk-org/zk-nvim",
    name = "zk",
    lazy = true,
    opts = {
      picker = "snacks_picker",
      lsp = {
        auto_attach = {
          enabled = false,
        },
      },
    },
    keys = {
      {
        "<leader>zke",
        "<cmd>ZkNotes<cr>",
        desc = "zk notes",
      },
      {
        "<leader>zkn",
        "<cmd>ZkNew<cr>",
        desc = "creates and edits a new note",
      },
      {
        "<leader>zknt",
        "<cmd>'<,'>ZkNewFromTitleSelection<cr>",
        desc = "creates a new note(used as title) from visual selection",
      },
      {
        "<leader>zknc",
        "<cmd>'<,'>ZkNewFromContentSelection<cr>",
        desc = "creates a new note(used as content) from visual selection",
      },
      {
        "<leader>zkb",
        "<cmd>ZkBuffers<cr>",
        desc = "note picker for active zk notes buffers",
      },
      {
        "<leader>zkB",
        "<cmd>ZkBacklinks<cr>",
        desc = "note picker for backlinks of current note",
      },
      {
        "<leader>zkl",
        "<cmd>ZkLinks<cr>",
        desc = "note picker for links of current note",
      },
      {
        "<leader>zki",
        "<cmd>ZkInsertLink<cr>",
        desc = "inserts a link at the cursor",
      },
      {
        "<leader>zkI",
        ":<cmd>'<,'>ZkInsertLinkAtSelection<cr>",
        desc = "inserts a link around the selected text",
      },
      {
        "<leader>zkd",
        function()
          local zk = require("zk")
          zk.new({ dir = "journal/daily" })
        end,
        desc = "creates a new daily note",
      },
    },
  },
}
