# Issue: Telescope loads too early on startup

## Summary

`nvim-telescope/telescope.nvim` currently loads on `VimEnter` in `lua/plugins/telescope.lua`.

That means Telescope and its configured extensions are initialized on nearly every startup, even when no Telescope functionality is used during the session.

## Current config

File:
- `lua/plugins/telescope.lua`

Current trigger:

```lua
{
  "nvim-telescope/telescope.nvim",
  event = "VimEnter",
  ...
}
```

## Why this is a perf problem

Telescope is not needed for basic startup, but the current trigger causes its setup path to run eagerly.

That setup currently includes:

- `require("telescope")`
- `telescope.setup(...)`
- attempted loading of extensions:
  - `fzf`
  - `ui-select`
  - `project`
  - `undo`

So startup pays for Telescope initialization even when Neovim is being used for:

- opening a single file
- quick edits
- git/jj workflows
- sessions that rely on Snacks pickers instead

## Why this matters more in this config

This config already uses `folke/snacks.nvim` as the main picker UI for many common actions, including:

- help
- keymaps
- files
- grep
- diagnostics
- recent files
- buffers
- current-buffer line search

That makes unconditional Telescope loading at `VimEnter` harder to justify.

## Expected impact

Potentially noticeable startup improvement, especially when starting Neovim without immediately using Telescope.

## Constraints / dependencies

This change should not be done in isolation.

Other config currently assumes Telescope is available early:

- `lua/plugins/lsp.lua`
  - uses `require("telescope.builtin")` during LSP attach
- `lua/plugins/harpoon.lua`
  - requires Telescope modules in plugin config
- `lua/plugins/codecompanion.lua`
  - explicitly loads a Telescope extension during setup

These call sites should be audited and likely deferred before changing Telescope’s main trigger.

## Related issue: eager Telescope requires outside Telescope config

A related perf problem is that Telescope is required eagerly from other plugins, which weakens or can completely defeat lazy-loading.

### `lua/plugins/lsp.lua`

During `on_attach`, the config currently binds Telescope pickers like this:

- `require("telescope.builtin").lsp_implementations`
- `require("telescope.builtin").lsp_document_symbols`
- `require("telescope.builtin").lsp_dynamic_workspace_symbols`

That means Telescope work can happen as soon as an LSP attaches, even if the user never invokes those mappings.

#### Better pattern

Wrap the calls so Telescope is only required at invocation time, for example:

```lua
nmap("gI", function()
  require("telescope.builtin").lsp_implementations()
end, "[G]oto [I]mplementation")
```

The same pattern should be used for document symbols and workspace symbols.

### `lua/plugins/harpoon.lua`

Harpoon currently requires Telescope modules during plugin config:

- `require("telescope.config").values`
- `require("telescope.pickers")`
- `require("telescope.finders")`

But most Harpoon functionality does not need Telescope. Only the Telescope-based picker UI does.

#### Better pattern

Move those `require(...)` calls into the function that opens the Harpoon Telescope picker, so the normal Harpoon navigation path stays lightweight.

### Why this matters

Even if Telescope itself is moved off `VimEnter`, these eager `require(...)` calls can still pull Telescope-related code into startup-adjacent paths:

- first file open
- first LSP attach
- Harpoon plugin config

So this related issue should be addressed as part of the same refactor.

## Recommended fix

Refactor as a small cluster of changes:

1. Make Telescope lazy instead of loading on `VimEnter`
2. Move Telescope `require(...)` calls into the callbacks that actually need them
3. Audit CodeCompanion Telescope extension loading and defer it if possible
4. Re-test Harpoon, LSP Telescope pickers, and Telescope extensions

## Candidate directions

Possible lazy triggers:

- specific Telescope commands
- keymaps that invoke Telescope behavior
- `on_require = "telescope"`
- extension-driven loading paths

A safe implementation should preserve current behavior when Telescope features are actually invoked.

## Risk

Medium.

The perf upside is good, but there are multiple cross-plugin assumptions that need to be updated first.

## Acceptance criteria

- Telescope no longer loads on plain startup unless actually needed
- Harpoon Telescope UI still works
- LSP Telescope pickers still work
- Telescope extensions still work when invoked
- no regression in CodeCompanion integration if Telescope remains its UI backend
