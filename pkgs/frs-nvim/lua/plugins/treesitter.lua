local bigfile = require("cfg.bigfile")

local function treesitter_configure_localparsers()
  local parsers = require("nvim-treesitter.parsers")
  if type(parsers) == "table" then
    parsers.noir = {
      install_info = {
        url = "https://github.com/hhamud/tree-sitter-noir",
        files = { "src/parser.c", "src/scanner.c" },
        branch = "main",
      },
      filetype = "noir",
    }
  end
end

local function treesitter_start_for_buf(buf)
  local ft = vim.bo[buf].filetype or ""
  if ft ~= "" and ft ~= "typescript" and ft ~= "tsx" and not bigfile.is_bigfile(buf) then
    pcall(vim.treesitter.start, buf)
  end
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    lazy = false,
    config = function()
      -- New nvim-treesitter on Neovim 0.11+ is mostly parser/install metadata.
      -- Start highlighting via built-in vim.treesitter.
      require("nvim-treesitter").setup({})
      treesitter_configure_localparsers()

      local group = vim.api.nvim_create_augroup("treesitter-start", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        callback = function(args)
          treesitter_start_for_buf(args.buf)
        end,
      })

      -- Attach for the current buffer too.
      treesitter_start_for_buf(0)
    end,
  },
}
