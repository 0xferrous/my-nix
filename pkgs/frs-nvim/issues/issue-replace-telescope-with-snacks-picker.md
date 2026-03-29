# Issue: replace Telescope with Snacks picker where possible

## Summary

This config already uses `folke/snacks.nvim` as the primary picker UI for many common workflows, but Telescope is still present as a secondary picker stack and compatibility layer.

The current state increases startup/load complexity and leaves multiple Telescope-specific integrations in the config.

Goal: replace Telescope-based picker usage with Snacks picker where practical, and reduce or remove the Telescope dependency surface.

## Why this is worth doing

### Consistency
The config already uses Snacks picker for many interactive flows, so continuing to maintain a parallel Telescope stack adds conceptual and UX inconsistency.

### Performance
Telescope currently contributes to startup or near-startup cost, and some call sites require Telescope earlier than necessary.

### Simplicity
Removing Telescope call sites where possible reduces:
- plugin setup complexity
- extension loading complexity
- cross-plugin dependency surface
- lazy-loading coordination work

## Current Telescope usage inventory

### 1. Telescope plugin config
File:
- `lua/plugins/telescope.lua`

Current role:
- Telescope setup
- extension setup/loading
- project picker
- ui-select integration
- undo extension

### 2. LSP mappings
File:
- `lua/plugins/lsp.lua`

Current Telescope usage:
- `telescope.builtin.lsp_implementations`
- `telescope.builtin.lsp_document_symbols`
- `telescope.builtin.lsp_dynamic_workspace_symbols`

Possible migration target:
- Snacks picker equivalents if available
- or built-in LSP/quickfix/location-list UX where appropriate

### 3. Harpoon picker UI
File:
- `lua/plugins/harpoon.lua`

Current Telescope usage:
- custom Telescope-based picker for Harpoon entries

Possible migration target:
- Snacks picker
- `vim.ui.select`
- Harpoon-native UI if sufficient

### 4. CodeCompanion
File:
- `lua/plugins/codecompanion.lua`

Current Telescope usage:
- `display.action_palette = { provider = "telescope" }`
- `telescope.load_extension("codecompanion")`

This is likely the strongest Telescope dependency remaining in the config.

Needs investigation:
- does CodeCompanion support a non-Telescope provider that fits this config?
- if not, should Telescope be retained only for CodeCompanion?

### 5. Toggleterm manager
File:
- `lua/plugins/toggleterm.lua`

Current Telescope usage:
- `toggleterm-manager.nvim` depends on `nvim-telescope/telescope.nvim`

Needs investigation:
- is Telescope strictly required for the desired workflow?
- is there a Snacks-compatible or simpler replacement?

### 6. Dropbar dependency
File:
- `lua/plugins/noconf.lua`

Current Telescope-related dependency:
- `nvim-telescope/telescope-fzf-native.nvim`

Needs investigation:
- is this actually needed for current Dropbar usage?
- can this dependency be removed?

## Existing Snacks picker usage

The config already uses Snacks picker for many common actions in `lua/plugins/snacks.lua`, including:

- help
- keymaps
- files
- grep
- diagnostics
- recent files
- buffers
- line search
- git files

This means the migration is not starting from zero; Snacks is already the dominant picker UX.

## Proposed migration plan

### Phase 1: audit and easy replacements
- replace Telescope-based LSP pickers with Snacks/built-in equivalents
- replace Harpoon Telescope picker UI
- identify whether Dropbar still needs Telescope-related dependency

### Phase 2: isolate remaining Telescope blockers
- determine whether CodeCompanion still requires Telescope
- determine whether toggleterm-manager still requires Telescope

### Phase 3: shrink or remove Telescope config
Depending on blockers:
- either remove Telescope completely
- or keep Telescope only for a small compatibility subset

## Risks

- some integrations may only support Telescope well today
- replacing Telescope may change UX slightly
- CodeCompanion may remain a hard blocker
- some plugins may rely on Telescope extensions not yet accounted for

## Acceptance criteria

- Telescope is no longer the default picker stack for any workflow that already has a viable Snacks-based replacement
- LSP symbol/implementation flows no longer require Telescope
- Harpoon no longer requires Telescope for its picker UI
- remaining Telescope dependencies are explicitly justified
- Telescope plugin/config can either be removed or reduced to a small compatibility role
