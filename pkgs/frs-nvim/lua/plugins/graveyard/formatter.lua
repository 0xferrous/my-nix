return {
  {
    "mhartington/formatter.nvim",
    enabled = false,
    config = function()
      local filetypes = require("formatter.filetypes")
      local config = {
        filetype = {
          typescript = filetypes.typescript.prettier,
          typescriptreact = filetypes.typescriptreact.prettier,
          lua = filetypes.lua.stylua,
          nix = filetypes.nix.nixpkgs_fmt,
          json = filetypes.json.prettier,
          solidity = function()
            return { exe = "forge", args = { "fmt", "--raw", "-" } }
          end,
          -- fennel = function() return { exe = "fnlfmt", args = { "-" } } end,
          toml = filetypes.toml.taplo,
        },
      }
      local formatter = require("formatter")
      local ignored = require("plenary.collections.py_list")({ "toml" })

      formatter.setup(config)

      vim.keymap.set("n", "<leader>f", "<cmd>FormatWrite<CR>", { desc = "format and write" })
      vim.keymap.set("n", "<leader>F", "<cmd>Format<CR>", { desc = "format without write" })

      vim.api.nvim_create_autocmd({ "BufWritePre" }, {
        pattern = { "*" },
        callback = function(ev)
          if ev.buf then
            local bufnr = ev.buf
            local bufvars = vim.b[bufnr]
            if not (bufvars and bufvars.lsp_fmt_aucmd) then
              local ft = vim.bo[bufnr].filetype
              if not ignored:contains(ft) then
                vim.cmd("Format")
              end
            end
          end
        end,
      })
    end,
    dependencies = { "nvim-lua/plenary.nvim" },
  },
}
