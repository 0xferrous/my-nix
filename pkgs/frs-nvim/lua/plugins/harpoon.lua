return {
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = { "<C-h>", "<C-j>", "<C-k>", "<C-l>", "<C-e>", "ha", "hr", "hn", "hp" },
    config = function()
      local harpoon = require("harpoon")
      local conf = require("telescope.config").values
      local pickers = require("telescope.pickers")
      local finders = require("telescope.finders")
      local harpoon_extensions = require("harpoon.extensions")

      local function toggle_telescope(harpoon_files)
        local file_paths = {}
        for _, item in ipairs(harpoon_files.items) do
          table.insert(file_paths, item.value)
        end

        local picker = pickers.new({}, {
          prompt_title = "Harpoon",
          finder = finders.new_table({ results = file_paths }),
          previewer = conf.file_previewer({}),
          sorter = conf.generic_sorter({}),
        })
        picker:find()
      end

      harpoon:setup()

      vim.keymap.set("n", "<C-h>", function()
        local list = harpoon:list()
        list:select(1)
      end, { desc = "select file 1 from harpoon" })

      vim.keymap.set("n", "<C-j>", function()
        local list = harpoon:list()
        list:select(2)
      end, { desc = "select file 2 from harpoon" })

      vim.keymap.set("n", "<C-k>", function()
        local list = harpoon:list()
        list:select(3)
      end, { desc = "select file 3 from harpoon" })

      vim.keymap.set("n", "<C-l>", function()
        local list = harpoon:list()
        list:select(4)
      end, { desc = "select file 4 from harpoon" })

      vim.keymap.set("n", "ha", function()
        harpoon:list():add()
      end, { desc = "add buffer to harpoon", noremap = true })

      vim.keymap.set("n", "hr", function()
        harpoon:list():remove()
      end, { desc = "remove buffer from harpoon" })

      vim.keymap.set("n", "hn", function()
        harpoon:list():next()
      end, { desc = "open next harpoon file" })

      vim.keymap.set("n", "hp", function()
        harpoon:list():prev()
      end, { desc = "open prev harpoon file" })

      vim.keymap.set("n", "<C-e>", function()
        toggle_telescope(harpoon:list())
      end, { desc = "Open harpoon window" })

      harpoon:extend(harpoon_extensions.builtins.highlight_current_file)
    end,
  },
}
