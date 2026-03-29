# Neovim interactive smoke checklist

Use this after significant plugin/lazy-loading changes.

## Quick start

```bash
nix run .
```

## 0) Baseline

- [ ] Neovim opens without startup errors/messages
- [ ] `:checkhealth` opens (spot-check major warnings)

## 1) Notifications / Snacks

- [ ] `<leader>un` opens Snacks notification history
- [ ] `<leader>sf` opens Snacks file picker
- [ ] `<leader>sg` opens grep picker
- [ ] Preview windows in picker open without FileType/treesitter errors

## 2) Treesitter

- [ ] Open a Lua file: highlighting works
- [ ] Open a Markdown file: highlighting/injections do not error
- [ ] No `set-lang-from-info-string!` / `downcase!` errors appear

## 3) LSP

- [ ] Open a project file with active LSP
- [ ] `gd`, `gI`, `<leader>ds` work
- [ ] `:LspInfo` shows attached server
- [ ] No `module 'crates' not found` errors in Rust/TOML flows

## 4) Plugin commands / triggers

- [ ] `:Neotree` opens
- [ ] `:Trouble` opens
- [ ] `:Feed` opens command picker
- [ ] `:Octo` command resolves (if authenticated/env is set)

## 5) Neotest

- [ ] `:lua require('neotest')` succeeds
- [ ] `:lua require('neotest-foundry')` succeeds
- [ ] Neotest UI/actions open without runtime errors

## 6) Markdown / rendering

- [ ] Open a markdown buffer and confirm render-markdown behavior is normal
- [ ] No decoration provider / treesitter highlighter errors

## 7) Final sanity

- [ ] Open a few random filetypes (`lua`, `nix`, `markdown`, `toml`, `rust`) and switch buffers
- [ ] No recurring errors in `:messages`

---

## Scripted complement

Run the headless smoke tests too:

```bash
nix run .#smoke
nix run .#smoke-lsp
nix run .#smoke-commands
```
