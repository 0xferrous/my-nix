return {
  {
    "saghen/blink.compat",
    version = "*",
    lazy = true,
    on_require = { "blink.compat", "blink.compat.source" },
    opts = {
      impersonate_nvim_cmp = true,
      debug = false,
    },
  },
  {
    "supermaven-inc/supermaven-nvim",
    event = "InsertEnter",
    opts = {
      ignore_filetypes = {
        fff_input = true,
        fff_list = true,
        fff_preview = true,
        fff_file_info = true,
      },
      keymaps = {
        accept_suggestion = "<S-Tab>",
        clear_suggestion = "<C-]>",
        accept_word = "<C-j>",
      },
    },
    config = function(opts)
      -- supermaven-nvim resolves its agent path by requiring
      -- `supermaven-nvim.binary.binary_fetcher`, and `binary_handler.lua`
      -- immediately calls `fetch_binary()` at module load time.
      --
      -- For this Nix-packaged config we do not want any runtime download or
      -- cache bootstrap. We already provide `sm-agent` in PATH via flake.nix,
      -- so override `fetch_binary()` before requiring `supermaven-nvim`.
      local fetcher = require("supermaven-nvim.binary.binary_fetcher")
      local src = vim.fn.exepath("sm-agent")

      if string.len(src) == 0 then
        vim.notify("supermaven: packaged sm-agent not found on PATH", vim.log.levels.WARN)
        return
      end

      fetcher.fetch_binary = function()
        return src
      end

      require("supermaven-nvim").setup(opts.opts)
    end,
    dependencies = { "saghen/blink.compat" },
  },
}
