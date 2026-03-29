# Treesitter migration notes (current)

## Root cause identified

The main issue was a mixed treesitter runtime during migration:

- multiple treesitter plugin variants/shapes were present at different points,
- plugin expectations (`nvim-treesitter.parsers.has_parser`, query directives like `set-lang-from-info-string!`) did not always match what was currently loaded.

This caused errors like:

- `attempt to call field 'has_parser' (a nil value)` (from `vim-illuminate`)
- `No handler for set-lang-from-info-string!` (query directive registration mismatch)

## Current mitigation/state

The config now uses a single `nvim-treesitter` plugin path (legacy variant removed), with loader-side compatibility and ordering fixes:

1. Early registration attempts for query helpers:
   - `require("nvim-treesitter.query_predicates")`
   - `require("nvim-treesitter.query")`

2. Compatibility shim in loader (`lua/cfg/fns.lua`):
   - ensures `nvim-treesitter.parsers.has_parser` exists for plugins that expect it,
   - supports both parser module shapes (`get_parser_configs()` vs direct table entries).

3. Wrapper config aligned for lazy runtime:
   - plugin sets are lazy/opt,
   - grammar collation disabled to avoid synthetic/mismatched treesitter runtime artifacts.

## Validation status

- Headless startup: passes.
- Trigger smoke tests: `lsp`, `telescope`, `snacks`, `neotest`, `neorg`, `zk`, `vim-illuminate`, `render-markdown` load without immediate loader errors.

## Remaining risk

Treesitter-related compatibility can still regress when upstream plugin/runtime versions move. If new failures appear, re-check:

- active runtime path for `nvim-treesitter/*` modules,
- directive registration timing,
- parser module shape exposed at runtime.
