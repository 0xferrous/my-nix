# Portable Neovim flake

This repo packages the Neovim config as a deterministic Nix app.

Goal:

```bash
nix run .
```

## Principles

- plugin code is provided by Nix
- no lazy.nvim git downloads at runtime
- no runtime plugin build/install hooks for active plugins
- the Lua config in `lua/**` is the source of truth

## How it works

### Wrapped Neovim

`flake.nix` builds a wrapped Neovim via `nix-wrapper-modules`.

The wrapped app exposes:
- `nvim`
- `vim`
- `vi`

and points Neovim at a generated config directory built from this repo's Lua files.

### Config packaging

A small derivation copies:
- `lua/cfg/*.lua`
- `lua/plugins/*.lua`
- `lua/plugins/graveyard/*.lua`
- `lua/ftplugin/*.lua`
- `lua/*.lua`

and writes an `init.lua` that does:

```lua
package.path = "$out/lua/?.lua;$out/lua/?/init.lua;" .. package.path
vim.opt.rtp:prepend("$out")
vim.loader.enable()
require("cfg")
```

So runtime loads the packaged Lua config directly from the Nix store.

### Plugin packaging via Nix

Plugins are supplied by:
- `pkgs.vimPlugins`
- custom flake inputs packaged with `buildVimPlugin`

Runtime loading is handled by `lze` plus `packadd`, using the plugin specs in `lua/plugins/*.lua`.

Important consequence:
- plugin sources come from Nix, not from runtime cloning/downloading

### Supermaven

`sm-agent` is packaged in Nix and added to `PATH`.

The config patches `supermaven-nvim` so it uses the packaged `sm-agent` directly instead of downloading or bootstrapping a cache copy at runtime.

## Outputs

The flake exports:
- `packages.<system>.nvim`
- `packages.<system>.smoke`
- `packages.<system>.smoke-lsp`
- `packages.<system>.smoke-commands`
- `packages.<system>.live`
- `packages.<system>.default`
- matching `apps.<system>.*`

## Usage

From repo root:

```bash
nix run .
```

Build only:

```bash
nix build .#default
```

Smoke test lazy/plugin loading:

```bash
nix run .#smoke
```

Smoke test LSP wiring:

```bash
nix run .#smoke-lsp
```

Smoke test command/UI wiring that can run headlessly in CI:

```bash
nix run .#smoke-commands
```

Live/dev mode against your working tree:

```bash
nix run .#live
```

Override live config root if needed:

```bash
NVIM_LIVE_CONFIG_ROOT=/path/to/repo nix run .#live
```

`#live` expects a Lua config tree containing `lua/cfg/init.lua`.

### Startup debug logging

Startup logging is disabled by default.

To enable it for a debugging session, set:

```bash
NVIM_STARTUP_DEBUG=1 nvim
```

Or with the flake apps:

```bash
NVIM_STARTUP_DEBUG=1 nix run .#live
NVIM_STARTUP_DEBUG=1 nix run .
```

When enabled, Neovim writes startup logs to:
- `/tmp/nvim-init.log`
- `/tmp/nvim-startup.log`

## Notes

- `lua/**` is the source of truth
- `fnl/**` and Hotpot are no longer part of the active runtime
- `LAZY_TRIGGERS.md` and `NIX_PLUGIN_MIGRATION.md` are historical migration docs, not runtime sources

## Extra docs

- `FFF.md` — how to use FFF in this config, query patterns, picker keymaps, and local integration notes
