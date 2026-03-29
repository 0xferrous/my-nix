# Migration status

The Fennel -> Lua and lazy.nvim -> Nix + lze migrations are effectively complete for the active config.

## Current source of truth

- `lua/cfg/*.lua`
- `lua/plugins/*.lua`
- `flake.nix`

## Remaining work

Any remaining work is normal config maintenance, not structural migration work.
Examples:
- adding new plugins to Nix packaging
- improving smoke tests
- refining loader heuristics if a new edge case appears

## Note

Older references to Fennel/Hotpot/plugin migration have been retired.
