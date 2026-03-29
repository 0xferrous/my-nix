return {
  {
    "kevinhwang91/nvim-ufo",
    keys = { "zR", "zM", "zr", "zm" },
    config = function()
      local ufo = require("ufo")

      vim.o.foldcolumn = "1"
      vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true
      vim.o.fillchars = "eob: ,fold: ,foldopen:,foldsep: ,foldclose:"

      vim.keymap.set("n", "zR", ufo.openAllFolds, { desc = "Open all folds" })
      vim.keymap.set("n", "zM", ufo.closeAllFolds, { desc = "Close all folds" })
      vim.keymap.set("n", "zr", ufo.openFoldsExceptKinds, { desc = "Open folds except special kinds" })
      vim.keymap.set("n", "zm", ufo.closeFoldsWith, { desc = "Close folds with higher level" })

      ufo.setup({
        provider_selector = function()
          return { "treesitter", "indent" }
        end,
      })
    end,
    dependencies = { "kevinhwang91/promise-async" },
  },
}
