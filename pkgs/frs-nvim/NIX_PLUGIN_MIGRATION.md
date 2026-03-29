# Nix plugin migration audit

This document is now historical.

The migration from lazy.nvim-managed plugin acquisition to Nix-packaged plugins has been completed for the active config.

## Current source of truth

- plugin specs: `lua/plugins/*.lua`
- loader bridge: `lua/cfg/fns.lua`
- packaging: `flake.nix`

## Current model

- plugins come from `pkgs.vimPlugins` or custom Nix-packaged inputs
- runtime loading is handled by `lze` + `packadd`
- active plugin specs no longer rely on runtime `build` hooks
- active config is Lua-only

## Historical note

This file previously tracked repo names and nixpkgs availability during the migration.
That work has been folded into the active flake and Lua config.

If a new plugin is added, audit it directly against:
- `flake.nix`
- `lua/plugins/*.lua`
- runtime smoke tests
