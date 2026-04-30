local M = {}

-- [[ Configure LSP ]]
--  This function gets run when an LSP connects to a particular buffer.
function M.lsp_on_attach(client, bufnr)
  local nmap = function(keys, func, desc)
    if desc then
      desc = "LSP: " .. desc
    end

    vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
  end

  nmap("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
  nmap("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
  nmap("gI", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")
  nmap("<leader>D", vim.lsp.buf.type_definition, "Type [D]efinition")
  nmap("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")
  nmap("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")

  nmap("<C-k>", vim.lsp.buf.signature_help, "Signature Documentation")

  nmap("<leader>wa", vim.lsp.buf.add_workspace_folder, "[W]orkspace [A]dd Folder")
  nmap("<leader>wr", vim.lsp.buf.remove_workspace_folder, "[W]orkspace [R]emove Folder")
  nmap("<leader>wl", function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, "[W]orkspace [L]ist Folders")

  if client then
    if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
      vim.lsp.inlay_hint.enable(true)
      nmap("<leader>th", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }))
      end, "[T]oggle Inlay [H]ints")
    end

    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
    end
  end

  vim.api.nvim_buf_create_user_command(bufnr, "FormatLsp", function(_)
    vim.lsp.buf.format()
  end, { desc = "Format current buffer with LSP" })

  if vim.g.have_nerd_font then
    local signs = { Error = "", Warn = "", Hint = "", Info = "" }
    local sign_hls = {
      [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
      [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
      [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
      [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
    }
    vim.diagnostic.config({
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = signs.Error,
          [vim.diagnostic.severity.WARN] = signs.Warn,
          [vim.diagnostic.severity.HINT] = signs.Hint,
          [vim.diagnostic.severity.INFO] = signs.Info,
        },
        numhl = sign_hls,
      },
      virtual_text = true,
    })
  end

  local create_auto_format_autocmd = function()
    if vim.b[bufnr].lsp_fmt_aucmd ~= nil then
      return
    end

    local aucmdid = vim.api.nvim_create_autocmd({ "BufWritePre" }, {
      pattern = { "<buffer>" },
      callback = function(_)
        vim.lsp.buf.format()
      end,
    })
    vim.b[bufnr].lsp_fmt_aucmd = aucmdid
    return aucmdid
  end

  local delete_auto_format_autocmd = function()
    if vim.b[bufnr].lsp_fmt_aucmd ~= nil then
      vim.api.nvim_del_autocmd(vim.b[bufnr].lsp_fmt_aucmd)
      vim.b[bufnr].lsp_fmt_aucmd = nil
    end
  end

  if client and client.server_capabilities.documentFormattingProvider then
    create_auto_format_autocmd()
  end

  vim.api.nvim_buf_create_user_command(bufnr, "DisableAutoFormat", delete_auto_format_autocmd, { desc = "Disable auto format with LSP" })
  vim.api.nvim_buf_create_user_command(bufnr, "EnableAutoFormat", create_auto_format_autocmd, { desc = "Enable auto format with LSP" })
end

local function normalize_specs(mod_value)
  if type(mod_value) ~= "table" then
    return {}
  end

  if type(mod_value[1]) == "string" then
    return { mod_value }
  end

  return mod_value
end

local function infer_main(spec)
  if type(spec.main) == "string" and spec.main ~= "" then
    return spec.main
  end

  if type(spec[1]) ~= "string" then
    return nil
  end

  local short = (spec[1]:match("/([^/]+)$") or spec[1]):gsub("%.nvim$", ""):gsub("%.vim$", "")
  local candidates = {
    short,
    short:gsub("-", "_"),
    short:gsub("-", ""),
    short:gsub("%.", ""),
  }

  for _, candidate in ipairs(candidates) do
    local ok, mod = pcall(require, candidate)
    if ok and type(mod) == "table" and type(mod.setup) == "function" then
      return candidate
    end
  end

  return nil
end

local function run_opts(spec)
  if spec.opts == nil then
    return
  end

  local main = infer_main(spec)
  if not main then
    return
  end

  local ok_mod, mod = pcall(require, main)
  if not ok_mod or type(mod) ~= "table" or type(mod.setup) ~= "function" then
    return
  end

  local opts = spec.opts
  if type(opts) == "function" then
    local ok_opts, generated = pcall(opts, spec)
    if not ok_opts then
      vim.notify(("nix loader: opts function failed for %s: %s"):format(spec[1] or "<unknown>", generated), vim.log.levels.WARN)
      return
    end
    opts = generated
  end

  local ok_setup, err = pcall(mod.setup, opts)
  if not ok_setup then
    vim.notify(("nix loader: setup failed for %s (%s): %s"):format(spec[1] or "<unknown>", main, err), vim.log.levels.WARN)
  end
end

local function run_config(spec)
  if type(spec.config) == "function" then
    local ok, err = pcall(spec.config, spec)
    if not ok then
      vim.notify(("nix loader: config failed for %s: %s"):format(spec[1] or "<unknown>", err), vim.log.levels.WARN)
    end
    return
  end

  if spec.config == true or spec.opts ~= nil then
    run_opts(spec)
  end
end

local function get_nix_info()
  local plugin_name = vim.g.nix_info_plugin_name or "nix-info"
  local ok, nix_info = pcall(require, plugin_name)
  if not ok or type(nix_info) ~= "table" or type(nix_info.plugins) ~= "table" then
    return nil
  end
  return nix_info
end

local function available_plugin_names(nix_info)
  local names = {}
  if type(nix_info) ~= "table" or type(nix_info.plugins) ~= "table" then
    return names
  end

  for _, section in pairs(nix_info.plugins) do
    if type(section) == "table" then
      for name, _ in pairs(section) do
        names[name] = true
      end
    end
  end

  return names
end

local function ensure_treesitter_parser_compat()
  local ok, parsers = pcall(require, "nvim-treesitter.parsers")
  if not ok or type(parsers) ~= "table" or type(parsers.has_parser) == "function" then
    return
  end

  local get_parser_configs = parsers.get_parser_configs

  parsers.has_parser = function(lang)
    if type(lang) ~= "string" or lang == "" then
      lang = vim.bo.filetype
    end
    if type(vim.treesitter) == "table" and type(vim.treesitter.language) == "table" and type(vim.treesitter.language.get_lang) == "function" then
      lang = vim.treesitter.language.get_lang(lang) or lang
    end

    if type(get_parser_configs) == "function" then
      local cfg = get_parser_configs()
      return type(cfg) == "table" and cfg[lang] ~= nil
    end

    -- Newer nvim-treesitter packs expose parser configs directly from this module.
    return parsers[lang] ~= nil
  end
end

local MODULE_ON_REQUIRE = {
  ["nvim-telescope/telescope.nvim"] = { "telescope" },
  ["nvim-neotest/neotest"] = { "neotest" },
  ["nvim-neorg/neorg"] = { "neorg" },
  ["folke/trouble.nvim"] = { "trouble" },
  ["kevinhwang91/nvim-ufo"] = { "ufo" },
  ["lewis6991/gitsigns.nvim"] = { "gitsigns" },
  ["stevearc/conform.nvim"] = { "conform" },
  ["zk-org/zk-nvim"] = { "zk" },
  ["olimorris/codecompanion.nvim"] = { "codecompanion" },
  ["folke/which-key.nvim"] = { "which-key" },
  ["folke/snacks.nvim"] = { "snacks" },
  ["nvim-treesitter/nvim-treesitter"] = { "nvim-treesitter" },
  ["saghen/blink.compat"] = { "blink.compat", "blink.compat.source" },
}

local PACK_NAME_OVERRIDES = {
  ["catppuccin/nvim"] = "catppuccin-nvim",
  ["ThePrimeagen/harpoon"] = "harpoon2",
  ["rose-pine/neovim"] = "rose-pine",
  ["llllvvuu/neotest-foundry"] = "neotest-foundry",
}

local function to_list(value)
  if value == nil then
    return {}
  end
  if type(value) == "string" then
    return { value }
  end
  if type(value) == "table" then
    return value
  end
  return {}
end

local function short_repo_name(spec)
  if type(spec[1]) ~= "string" then
    return nil
  end
  return spec[1]:match("/([^/]+)$") or spec[1]
end

local function plugin_id(spec, fallback)
  if type(spec.name) == "string" and spec.name ~= "" then
    return spec.name
  end
  if type(spec[1]) == "string" and spec[1] ~= "" then
    return spec[1]
  end
  return fallback
end

local function resolve_pack_name(spec, known_plugins)
  local repo = spec[1]
  if type(repo) == "string" and type(PACK_NAME_OVERRIDES[repo]) == "string" then
    return PACK_NAME_OVERRIDES[repo]
  end

  local short = short_repo_name(spec)
  local base_name = nil
  if type(spec.name) == "string" and spec.name ~= "" then
    base_name = spec.name
  elseif type(short) == "string" and short ~= "" then
    base_name = short
  end

  local candidates = {
    spec.name,
    spec[1],
    short,
    base_name,
  }

  if type(base_name) == "string" and base_name ~= "" then
    local stripped = base_name:gsub("%.nvim$", ""):gsub("%.vim$", "")
    local lower = base_name:lower()
    local lower_stripped = stripped:lower()
    table.insert(candidates, base_name .. ".nvim")
    table.insert(candidates, base_name .. "-nvim")
    table.insert(candidates, base_name .. ".vim")
    table.insert(candidates, stripped)
    table.insert(candidates, stripped .. ".nvim")
    table.insert(candidates, stripped .. "-nvim")
    table.insert(candidates, stripped .. ".vim")
    table.insert(candidates, lower)
    table.insert(candidates, lower .. ".nvim")
    table.insert(candidates, lower .. "-nvim")
    table.insert(candidates, lower_stripped)
    table.insert(candidates, lower_stripped .. ".nvim")
    table.insert(candidates, lower_stripped .. "-nvim")
  end

  local seen = {}
  for _, candidate in ipairs(candidates) do
    if type(candidate) == "string" and candidate ~= "" and not seen[candidate] then
      seen[candidate] = true
      if known_plugins[candidate] then
        return candidate
      end
    end
  end

  if type(base_name) == "string" and base_name ~= "" then
    return base_name
  end

  return spec[1]
end

local function merge_string_or_list(a, b)
  local out, seen = {}, {}
  for _, v in ipairs(to_list(a)) do
    if type(v) == "string" and not seen[v] then
      seen[v] = true
      table.insert(out, v)
    end
  end
  for _, v in ipairs(to_list(b)) do
    if type(v) == "string" and not seen[v] then
      seen[v] = true
      table.insert(out, v)
    end
  end
  if #out == 0 then
    return nil
  end
  if #out == 1 then
    return out[1]
  end
  return out
end

local function normalize_event(event)
  if type(event) == "string" then
    if event == "VeryLazy" then
      return "DeferredUIEnter"
    end
    return event
  end

  if type(event) ~= "table" then
    return event
  end

  if vim.islist(event) then
    local mapped = {}
    for _, item in ipairs(event) do
      if type(item) == "string" and item == "VeryLazy" then
        table.insert(mapped, "DeferredUIEnter")
      else
        table.insert(mapped, item)
      end
    end
    return mapped
  end

  local mapped = vim.deepcopy(event)
  if mapped.event == "VeryLazy" then
    mapped.event = "DeferredUIEnter"
  elseif type(mapped.event) == "table" then
    for i, ev in ipairs(mapped.event) do
      if ev == "VeryLazy" then
        mapped.event[i] = "DeferredUIEnter"
      end
    end
  end
  return mapped
end

local function normalize_enabled(spec)
  local enabled = spec.enabled
  local cond = spec.cond
  if enabled == nil and cond == nil then
    return nil
  end

  local eval = function(value)
    if value == nil then
      return true
    end
    if type(value) == "function" then
      local ok, result = pcall(value)
      return ok and not not result
    end
    return not not value
  end

  return function()
    return eval(enabled) and eval(cond)
  end
end

local function dependency_refs(spec)
  local refs = {}
  local deps = spec.dependencies
  if type(deps) ~= "table" then
    return refs
  end

  for _, dep in ipairs(deps) do
    if type(dep) == "string" then
      table.insert(refs, dep)
    elseif type(dep) == "table" then
      if type(dep.name) == "string" then
        table.insert(refs, dep.name)
      end
      if type(dep[1]) == "string" then
        table.insert(refs, dep[1])
      end
      local dep_short = dep[1] and dep[1]:match("/([^/]+)$")
      if type(dep_short) == "string" then
        table.insert(refs, dep_short)
      end
    end
  end

  return refs
end

local function load_triggers_present(spec)
  return spec.event ~= nil
    or spec.cmd ~= nil
    or spec.ft ~= nil
    or spec.keys ~= nil
    or spec.colorscheme ~= nil
    or spec.on_require ~= nil
end

local function is_plugin_spec(value)
  return type(value) == "table" and (type(value[1]) == "string" or type(value.name) == "string")
end

local function ensure_dependency_specs(all_specs)
  local out = {}
  local seen = {}
  local anon_idx = 0

  local function spec_key(spec)
    if type(spec.name) == "string" and spec.name ~= "" then
      return "name:" .. spec.name
    end
    if type(spec[1]) == "string" and spec[1] ~= "" then
      return "repo:" .. spec[1]
    end
    anon_idx = anon_idx + 1
    return "anon:" .. tostring(anon_idx)
  end

  local function push_if_new(spec)
    if type(spec) ~= "table" then
      return false
    end

    local key = spec_key(spec)
    if seen[key] then
      return false
    end

    seen[key] = true
    table.insert(out, spec)
    return true
  end

  local function add_dependency_specs(spec)
    if type(spec) ~= "table" then
      return
    end

    local deps = spec.dependencies
    if type(deps) ~= "table" then
      return
    end

    for _, dep in ipairs(deps) do
      local dep_spec = nil
      if type(dep) == "string" then
        dep_spec = { dep, lazy = true }
      elseif is_plugin_spec(dep) then
        dep_spec = dep
      end

      if dep_spec and push_if_new(dep_spec) then
        add_dependency_specs(dep_spec)
      end
    end
  end

  -- Keep canonical top-level specs first so dependency shims can't shadow them.
  for _, spec in ipairs(all_specs) do
    push_if_new(spec)
  end

  -- Then recursively append nested dependencies that are otherwise missing.
  for _, spec in ipairs(all_specs) do
    add_dependency_specs(spec)
  end

  return out
end

local function build_lze_specs(all_specs, known_plugins)
  local alias_to_id = {}
  local ordered = {}

  for idx, spec in ipairs(all_specs) do
    local load_name = resolve_pack_name(spec, known_plugins)
    local id = plugin_id(spec, load_name or ("anonymous-plugin-" .. idx))
    table.insert(ordered, { id = id, load_name = load_name, spec = spec })

    alias_to_id[id] = id
    if type(load_name) == "string" and load_name ~= "" then
      alias_to_id[load_name] = id
    end
    if type(spec[1]) == "string" then
      alias_to_id[spec[1]] = id
    end
    if type(spec.name) == "string" then
      alias_to_id[spec.name] = id
    end
    local short = short_repo_name(spec)
    if short then
      alias_to_id[short] = id
    end
  end

  local load_name_by_id = {}
  for _, entry in ipairs(ordered) do
    load_name_by_id[entry.id] = entry.load_name
  end

  local dep_of_map = {}
  for _, entry in ipairs(ordered) do
    local parent_id = entry.id
    for _, ref in ipairs(dependency_refs(entry.spec)) do
      local dep_id = alias_to_id[ref]
      if dep_id and dep_id ~= parent_id then
        dep_of_map[dep_id] = dep_of_map[dep_id] or {}
        table.insert(dep_of_map[dep_id], parent_id)
      end
    end
  end

  local lze_specs = {}
  for _, entry in ipairs(ordered) do
    local id = entry.id
    local load_name = entry.load_name
    local spec = entry.spec

    local module_on_require = nil
    local by_repo = MODULE_ON_REQUIRE[spec[1]]
    local by_name = MODULE_ON_REQUIRE[spec.name]
    local by_short = MODULE_ON_REQUIRE[short_repo_name(spec)]
    module_on_require = merge_string_or_list(module_on_require, by_repo)
    module_on_require = merge_string_or_list(module_on_require, by_name)
    module_on_require = merge_string_or_list(module_on_require, by_short)

    local on_require = merge_string_or_list(spec.on_require, module_on_require)
    if spec.lazy == true and not load_triggers_present(spec) and on_require == nil then
      local short = short_repo_name(spec)
      if short then
        on_require = short:gsub("%.nvim$", "")
      end
    end

    local lze_spec = {
      id,
      enabled = normalize_enabled(spec),
      beforeAll = spec.init,
      priority = spec.priority,
      lazy = spec.lazy,
      event = normalize_event(spec.event),
      cmd = spec.cmd,
      ft = spec.ft,
      keys = spec.keys,
      colorscheme = spec.colorscheme,
      dep_of = dep_of_map[id],
      on_require = on_require,
      load = function(_)
        local loaded_deps = {}
        for _, ref in ipairs(dependency_refs(spec)) do
          local dep_id = alias_to_id[ref]
          local dep_load_name = dep_id and load_name_by_id[dep_id] or nil
          if dep_id and dep_id ~= id and type(dep_load_name) == "string" and dep_load_name ~= "" and not loaded_deps[dep_load_name] then
            loaded_deps[dep_load_name] = true
            vim.cmd.packadd(dep_load_name)
          end
        end

        if type(load_name) ~= "string" or load_name == "" then
          vim.notify(("nix loader: no pack name for %s"):format(id), vim.log.levels.WARN)
          return
        end
        vim.cmd.packadd(load_name)
      end,
      after = function()
        if spec[1] == "nvim-treesitter/nvim-treesitter" or spec[1] == "RRethy/vim-illuminate" then
          ensure_treesitter_parser_compat()
        end
        if spec[1] == "nvim-treesitter/nvim-treesitter" then
          pcall(require, "nvim-treesitter.query_predicates")
          pcall(require, "nvim-treesitter.query")
        end
        run_config(spec)
      end,
    }

    table.insert(lze_specs, lze_spec)
  end

  return lze_specs
end

function M.setup_nix_plugins()
  local nix_info = get_nix_info()
  local known_plugins = available_plugin_names(nix_info)

  -- Ensure treesitter query directives/predicates are registered early when available.
  pcall(require, "nvim-treesitter.query_predicates")
  pcall(require, "nvim-treesitter.query")

  -- Compatibility shim: some plugin mixes expect parsers.has_parser().
  ensure_treesitter_parser_compat()
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = ensure_treesitter_parser_compat,
  })

  local plugin_modules = {
    "plugins.aw-watcher",
    "plugins.cmp",
    "plugins.codecompanion",
    "plugins.colorschemes",
    "plugins.conform",
    "plugins.feed",
    "plugins.gitsigns",
    "plugins.harpoon",
    "plugins.lsp",
    "plugins.lualine",
    "plugins.mini",
    "plugins.misc",
    "plugins.neorg",
    "plugins.neotest",
    "plugins.neotree",
    "plugins.noconf",
    "plugins.overseer",
    "plugins.snacks",
    "plugins.supermaven",
    "plugins.telescope",
    "plugins.toggleterm",
    "plugins.treesitter",
    "plugins.trouble",
    "plugins.ufo",
    "plugins.which-key",
    "plugins.zk",
  }

  local all_specs = {}
  for _, module_name in ipairs(plugin_modules) do
    local ok, mod_value = pcall(require, module_name)
    if not ok then
      vim.notify(("nix loader: failed requiring %s: %s"):format(module_name, mod_value), vim.log.levels.WARN)
    else
      local specs = normalize_specs(mod_value)
      for _, spec in ipairs(specs) do
        if type(spec) == "table" then
          table.insert(all_specs, spec)
        end
      end
    end
  end

  vim.g.lze = vim.tbl_deep_extend("force", vim.g.lze or {}, {
    load = vim.cmd.packadd,
    verbose = vim.env.NVIM_STARTUP_DEBUG == "1",
  })

  local lze = require("lze")
  lze.h.event.set_event_alias("VeryLazy", "DeferredUIEnter")

  local specs = build_lze_specs(ensure_dependency_specs(all_specs), known_plugins)
  lze.load(specs)
end

return M
