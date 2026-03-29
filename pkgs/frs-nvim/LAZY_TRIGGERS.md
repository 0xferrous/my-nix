# Lazy trigger archive

This file is a historical note from the lazy.nvim -> Nix + lze migration.

## Current source of truth

Active plugin specs now live in:
- `lua/plugins/*.lua`

The runtime loader is:
- `lua/cfg/fns.lua`

## Status

This document is retained only as migration history.
It is no longer authoritative, and it no longer reflects a Fennel-based source tree.

If trigger behavior needs auditing now, inspect:
- `lua/plugins/*.lua`
- `lua/cfg/fns.lua`
- `scripts/smoke-lazy.lua`
