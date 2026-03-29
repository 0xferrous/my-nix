local servers = {
  gopls = {},
  -- pyright = {},
  ty = {},
  ts_ls = {},
  lua_ls = {
    Lua = {
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
    },
  },
  ccls = {
    init_options = {
      compilationDatabaseDirectory = "build",
    },
  },
  zk = {},
  nushell = {},
  marksman = {},
  -- TODO: configure Solidity LSP
  zls = {},
}

local function configure_lsp_servers(servers)
  for lsp_name, config in pairs(servers) do
    vim.lsp.config(lsp_name, config)
    vim.lsp.enable(lsp_name)
  end
end

local function on_attach(client, buf)
  local function nmap(keys, func, desc)
    vim.keymap.set("n", keys, func, {
      buffer = buf,
      desc = "LSP: " .. desc,
    })
  end

  if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
    vim.lsp.inlay_hint.enable()
    nmap("<leader>th", function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }))
    end, "Toggle [T]ype Hints")
  end -- TODO: change default diagnostic symbols

  nmap("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
  nmap("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
  nmap("gI", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")
  nmap("<leader>D", vim.lsp.buf.type_definition, "Type [D]efinition")
  nmap("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")
  nmap("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")
  nmap("<c-k>", vim.lsp.buf.signature_help, "Signature Documentation")
  nmap("<leader>wa", vim.lsp.buf.add_workspace_folder, "Add [W]orkspace [A]dd Folder")
  nmap("<leader>wr", vim.lsp.buf.remove_workspace_folder, "Remove [W]orkspace [R]emove Folder")
  nmap("<leader>wl", function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, "[W]orkspace [L]ist Folders")

  vim.api.nvim_buf_create_user_command(buf, "FormatLsp", function()
    vim.lsp.buf.format()
  end, { desc = "Format current buffer with LSP" })
end

local function setup_lsp()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local blink = require("blink.cmp")
  capabilities = blink.get_lsp_capabilities(capabilities)
  capabilities.textDocument.foldingRange = {
    dynamicRegistration = false,
    lineFoldingOnly = true,
  }

  vim.lsp.config("*", { capabilities = capabilities })
  configure_lsp_servers(servers)

  vim.g.rustaceanvim = {
    tools = {},
    server = {
      on_attach = on_attach,
      default_settings = {
        ["rust-analyzer"] = {},
      },
    },
    dap = {},
  }

  require("crates").setup({
    lsp = {
      enabled = true,
      on_attach = on_attach,
      actions = true,
      completion = true,
      hover = true,
    },
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      on_attach(client, ev.buf)
    end,
  })
end

return {
  {
    "saecki/crates.nvim",
    lazy = true,
    on_require = "crates",
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      {
        "j-hui/fidget.nvim",
        opts = {
          notification = {
            window = { winblend = 0 },
          },
        },
      },
      "mrcjkb/rustaceanvim",
      "saghen/blink.cmp",
      "saecki/crates.nvim",
    },
    config = function()
      setup_lsp()
    end,
  },
}
