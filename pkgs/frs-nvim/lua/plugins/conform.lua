local prettier_opts = { "prettier", lsp_format = "fallback" }

return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        javascript = prettier_opts,
        typescript = prettier_opts,
        solidity = { "forge_fmt" },
        fennel = { "fnlfmt" },
        rust = {},
        toml = { "taplo" },
      },
      format_on_save = {},
      default_format_opts = { lsp_format = "prefer" },
    },
  },
}
