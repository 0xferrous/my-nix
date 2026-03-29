# Fennel -> Lua refactor audit and deterministic-build action list

## Repo constraint from `README.md`
This repo is intended to provide a **deterministic Neovim build** that users can run with:

```bash
nix run .
```

That means:
- plugin code must come from Nix, not runtime git clones
- parser/plugin compilation must happen at Nix build time, not at editor startup
- runtime network download is not acceptable
- runtime install/bootstrap side effects are also undesirable, even if they are offline
- plugin specs should not rely on lazy.nvim-style `build` hooks for correctness

## What the current flake already gets right
From `README.md`, `flake.nix`, and `lua/cfg/fns.lua`:
- plugin sources are supplied by `pkgs.vimPlugins` or flake inputs packaged with `buildVimPlugin`
- the runtime loader is `lze` + `packadd`, not lazy.nvim's package downloader
- `lua/cfg/fns.lua` does **not** execute plugin `build` hooks
- `nvim-treesitter` is packaged via `pkgs.vimPlugins.nvim-treesitter.withAllGrammars`

So several `build = ...` fields are currently inert. That is good for avoiding runtime mutation, but they are still misleading and should not remain if the goal is a strictly deterministic packaged config.

## Audit categories
- **Equivalent**: Lua preserves the Fennel behavior.
- **Fixed**: Lua had a real semantic mismatch and was corrected.
- **Intentional change**: Lua differs from Fennel, but the difference is deliberate or beneficial.
- **Needs deterministic cleanup**: behavior may work today, but conflicts with the repo's Nix-first / no-runtime-install goal.
- **Needs verification**: worth separately confirming against runtime/plugin expectations.

## Refactor fixes already applied
- [x] `lua/plugins/feed.lua`
  - Restored `rust` as a subgroup under `programming` instead of a top-level feed category.
- [x] `lua/plugins/codecompanion.lua`
  - Changed to `diff.gen_source.none()`.
- [x] `lua/plugins/mini.lua`
  - Changed to `indentscope.gen_animation.none()`.
  - Restored the plugin repo string to match the original Fennel config.

## Determinism-focused findings

### 1. `lua/plugins/treesitter.lua`
**Status:** Fixed / needs follow-up

Current state:
- removed `build = ":TSUpdate"`
- grammars are supplied by `pkgs.vimPlugins.nvim-treesitter.withAllGrammars`

Assessment:
- the misleading runtime build hook is gone
- the local Noir parser registration still points at upstream metadata; if Noir support is required, it should eventually be packaged via Nix rather than installed out-of-band

Follow-up:
- decide whether Noir grammar support is required; if yes, package it in Nix

### 2. `lua/plugins/telescope.lua`
**Status:** Fixed

Current state:
- removed `build = "make"` from the `telescope-fzf-native.nvim` dependency spec
- plugin remains supplied by `pkgs.vimPlugins.telescope-fzf-native-nvim`

Assessment:
- the spec no longer suggests runtime/native compilation
- build responsibility stays in Nix packaging where it belongs

### 3. `lua/plugins/misc.lua` (`firenvim`)
**Status:** Fixed / needs policy decision

Current state:
- removed `build = ":call firenvim#install(0)"`

Assessment:
- the explicit runtime install hook is gone
- if Firenvim support is still desired, it should be handled as a separate documented integration path rather than a plugin build hook

Follow-up:
- decide whether Firenvim should remain in the default deterministic package at all

### 4. `lua/plugins/supermaven.lua`
**Status:** Fixed deterministic cleanup

Current state:
- runtime cache bootstrap was removed
- the config now patches `supermaven-nvim.binary.binary_fetcher.fetch_binary()` before requiring `supermaven-nvim`
- the patched `fetch_binary()` returns the Nix-provided `sm-agent` from `PATH`

Assessment:
- this preserves the plugin's behavior while eliminating runtime `mkdir/cp/chmod` side effects
- the plugin now runs directly against the packaged agent binary instead of copying it into a writable cache path

Follow-up:
- if desired, this could later be moved from runtime monkey-patching into a cleaner Nix-side patch to the plugin package itself

### 5. `lua/plugins/neorg.lua`
**Status:** Fixed

Current state:
- removed the `vhyrro/luarocks.nvim` plugin spec
- removed `dependencies = { "luarocks.nvim" }` from the Neorg spec
- removed the `luarocks.nvim` flake input / custom plugin packaging entry

Assessment:
- this matches the repo's deterministic-build policy
- Neorg is now treated like the rest of the packaged plugins instead of depending on a runtime rock-management layer

Follow-up:
- if Neorg later proves to need any Lua rock dependency, package that explicitly with Nix rather than reintroducing `luarocks.nvim`

### 6. `lua/plugins/mini.lua`
**Status:** Fixed

Current state:
- semantics were fixed
- plugin repo string remains `nvim-mini/mini.nvim`

Assessment:
- confirmed as the correct upstream identifier
- no further action needed on repo identity

## Intentional non-equivalences currently kept
- `init.lua`
  - pure Lua bootstrap; no Hotpot / `.compiled` runtime bootstrap
- `lua/cfg/init.lua`
  - explicitly sets `vim.opt.shell = nu`
- `lua/plugins/lsp.lua`
  - keeps corrected `list_workspace_folders()` call

## Full file-by-file audit matrix

| Fennel | Lua | Status | Notes |
|---|---|---|---|
| `fnl/init.fnl` | `init.lua` | Intentional change | Pure Lua bootstrap; no `.compiled` RTP prepend and no `hotpot` require. |
| `fnl/cfg/init.fnl` | `lua/cfg/init.lua` | Intentional change | Explicitly sets `vim.opt.shell = nu`; old Fennel line was commented out. |
| `fnl/say-hello.fnl` | `lua/say-hello.lua` | Equivalent | Same `print("hello!")`. |
| `fnl/zk.fnl` | `lua/zk.lua` | Equivalent | Same `:NeoTree reveal`. |
| `fnl/ftplugin/fennel.fnl` | `lua/ftplugin/fennel.lua` | Equivalent | Same `formatprg`. |
| `fnl/ftplugin/nu.fnl` | `lua/ftplugin/nu.lua` | Equivalent | Same buffer-local indent options and debug print. |
| `fnl/ftplugin/solidity.fnl` | `lua/ftplugin/solidity.lua` | Equivalent | Same `formatprg`. |
| `fnl/plugins/avante.fnl` | `lua/plugins/avante.lua` | Equivalent | Matches compiled structure. |
| `fnl/plugins/aw-watcher.fnl` | `lua/plugins/aw-watcher.lua` | Equivalent | Same plugin spec and opts. |
| `fnl/plugins/cmp.fnl` | `lua/plugins/cmp.lua` | Equivalent | Same `blink.cmp` config. |
| `fnl/plugins/codecompanion.fnl` | `lua/plugins/codecompanion.lua` | Fixed | `mini.diff` source now uses `diff.gen_source.none()`. |
| `fnl/plugins/colorschemes.fnl` | `lua/plugins/colorschemes.lua` | Equivalent | Same plugin list and colorscheme setup. |
| `fnl/plugins/conform.fnl` | `lua/plugins/conform.lua` | Equivalent | Same formatter mapping and save behavior. |
| `fnl/plugins/feed.fnl` | `lua/plugins/feed.lua` | Fixed | Restored `programming_feeds.rust = rust_feeds`. |
| `fnl/plugins/gitsigns.fnl` | `lua/plugins/gitsigns.lua` | Equivalent | Same mappings and `on_attach`. |
| `fnl/plugins/graveyard/baleia.fnl` | `lua/plugins/graveyard/baleia.lua` | Equivalent | No semantic drift found. |
| `fnl/plugins/graveyard/dash.fnl` | `lua/plugins/graveyard/dash.lua` | Equivalent | No semantic drift found. |
| `fnl/plugins/graveyard/difftastic.fnl` | `lua/plugins/graveyard/difftastic.lua` | Equivalent | No semantic drift found. |
| `fnl/plugins/graveyard/formatter.fnl` | `lua/plugins/graveyard/formatter.lua` | Equivalent | No semantic drift found. |
| `fnl/plugins/graveyard/noice.fnl` | `lua/plugins/graveyard/noice.lua` | Equivalent | No semantic drift found. |
| `fnl/plugins/graveyard/nvim-notify.fnl` | `lua/plugins/graveyard/nvim-notify.lua` | Equivalent | No semantic drift found. |
| `fnl/plugins/graveyard/parinfer.fnl` | `lua/plugins/graveyard/parinfer.lua` | Equivalent / graveyard | Contains a build command, but graveyard plugins are not part of active loader set. |
| `fnl/plugins/graveyard/telekasten.fnl` | `lua/plugins/graveyard/telekasten.lua` | Equivalent | Same plugin behavior. |
| `fnl/plugins/harpoon.fnl` | `lua/plugins/harpoon.lua` | Equivalent | Same harpoon setup, mappings, telescope bridge. |
| `fnl/plugins/lsp.fnl` | `lua/plugins/lsp.lua` | Intentional change | Lua fixes broken `list_workspace_folders` printing. |
| `fnl/plugins/lualine.fnl` | `lua/plugins/lualine.lua` | Equivalent | Same sections and options. |
| `fnl/plugins/mini.fnl` | `lua/plugins/mini.lua` | Fixed | Semantics fixed; `nvim-mini/mini.nvim` confirmed as the correct repo identifier. |
| `fnl/plugins/misc.fnl` | `lua/plugins/misc.lua` | Equivalent / fixed deterministic cleanup | Config is equivalent; removed the Firenvim runtime install hook from the spec. |
| `fnl/plugins/neorg.fnl` | `lua/plugins/neorg.lua` | Intentional change / fixed deterministic cleanup | Same Neorg config, but removed `luarocks.nvim` to match the repo's Nix-only deterministic policy. |
| `fnl/plugins/neotest.fnl` | `lua/plugins/neotest.lua` | Equivalent | Same adapter setup. |
| `fnl/plugins/neotree.fnl` | `lua/plugins/neotree.lua` | Equivalent | Same sources, opts, key. |
| `fnl/plugins/noconf.fnl` | `lua/plugins/noconf.lua` | Equivalent | Same plugin list. |
| `fnl/plugins/overseer.fnl` | `lua/plugins/overseer.lua` | Equivalent | Same command-triggered spec. |
| `fnl/plugins/snacks.fnl` | `lua/plugins/snacks.lua` | Equivalent | Same dashboard, keys, picker mappings, notifier command. |
| `fnl/plugins/supermaven.fnl` | `lua/plugins/supermaven.lua` | Intentional change / fixed deterministic cleanup | Keeps method-call fixes and now uses the Nix-provided `sm-agent` directly by overriding `fetch_binary()` before plugin init. |
| `fnl/plugins/telescope.fnl` | `lua/plugins/telescope.lua` | Equivalent / fixed deterministic cleanup | Same behavior; removed `build = "make"` from the spec. Also fixed Lua syntax for the `["ui-select"]` extension key. |
| `fnl/plugins/toggleterm.fnl` | `lua/plugins/toggleterm.lua` | Equivalent | Same toggleterm and manager behavior. |
| `fnl/plugins/treesitter.fnl` | `lua/plugins/treesitter.lua` | Equivalent / fixed deterministic cleanup | Same setup behavior; removed `build = ":TSUpdate"` from the spec. |
| `fnl/plugins/trouble.fnl` | `lua/plugins/trouble.lua` | Equivalent | Same keys and commands. |
| `fnl/plugins/ufo.fnl` | `lua/plugins/ufo.lua` | Equivalent | Same fold config and provider selector. |
| `fnl/plugins/which-key.fnl` | `lua/plugins/which-key.lua` | Equivalent | Same icon/key fallback and group spec. |
| `fnl/plugins/zk.fnl` | `lua/plugins/zk.lua` | Equivalent | Same mappings and daily note callback. |

## Recommended next code changes
- [x] Remove `build = ":TSUpdate"` from `lua/plugins/treesitter.lua`
- [x] Remove `build = "make"` from `lua/plugins/telescope.lua`
- [x] Remove `build = ":call firenvim#install(0)"` from `lua/plugins/misc.lua`
- [x] Remove `luarocks.nvim` from `lua/plugins/neorg.lua` and from `flake.nix`
- [x] Redesign `lua/plugins/supermaven.lua` to avoid runtime copy/bootstrap into cache paths
- [x] Verify the correct repo identifier in `lua/plugins/mini.lua`

## Validation completed so far
- [x] Read `README.md` and re-evaluated the refactor under the repo's deterministic-build goal.
- [x] Re-read the changed plugin files.
- [x] Compared fixed Lua against original Fennel semantics.
- [x] Ran a lightweight syntax check with `lua loadfile(...)` on changed plugin files.
- [x] Verified `lua/plugins/treesitter.lua`, `lua/plugins/telescope.lua`, `lua/plugins/misc.lua`, `lua/plugins/neorg.lua`, and `lua/plugins/supermaven.lua` still parse after deterministic-cleanup edits.

## Deterministic compliance summary
Active Lua plugin specs and loader behavior now appear compliant with the repo's stated deterministic-build goal:
- active plugin code is provided by Nix
- active plugin specs no longer carry runtime `build` hooks for treesitter, telescope, firenvim, or Neorg's `luarocks.nvim`
- Supermaven now uses the Nix-provided `sm-agent` directly instead of downloading or bootstrapping a cache copy at runtime
- the custom loader still does not execute lazy-style `build` hooks

Remaining caveats:
- `lua/plugins/graveyard/parinfer.lua` still contains a `build` field, but graveyard plugins are not part of the active loader set
- Noir treesitter parser support is still only registered as upstream metadata; if it must be guaranteed in the packaged build, it should be packaged explicitly in Nix
- some intentional semantic changes remain (`init.lua`, `lua/cfg/init.lua`, `lua/plugins/lsp.lua`), but they are not determinism violations
