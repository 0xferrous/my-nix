# Issue: bigfile gating via plugin-spec `enabled` is the wrong layer

## Summary

Several plugins were gated with:

```lua
enabled = function()
  return not bigfile.is_bigfile(0)
end
```

This looks convenient, but it is evaluated by the custom loader at plugin load time, not by the plugin on a per-buffer basis.

As a result, it is not a correct implementation of “disable this plugin only for big buffers”.

## Why this is a problem

The custom loader in `lua/cfg/fns.lua` normalizes `spec.enabled` / `spec.cond` and passes the result into the generated `lze` spec.

That means `enabled` answers a loader-level question:

> should this plugin spec be active right now?

It does **not** answer the buffer-local question:

> should this plugin stay disabled for this specific big buffer?

Using `bigfile.is_bigfile(0)` here makes the decision depend on the current buffer at the moment the load trigger fires.

## What can go wrong

Example with a plugin triggered on `BufReadPost`:

- open a big file first
- plugin trigger fires
- `enabled()` returns `false`
- plugin does not load
- later open a small file
- plugin may or may not load depending on later triggers

Reverse order:

- open a small file first
- plugin loads globally
- later open a big file
- the spec-level `enabled` check is no longer useful for that buffer

So this approach is:
- context-sensitive
- not per-buffer
- asymmetric depending on open order

## Affected plugin classes

This is especially relevant for plugins that should ideally be:
- globally available
- but selectively disabled or reduced on large buffers

Examples in this config include:
- `Bekaboo/dropbar.nvim`
- `MeanderingProgrammer/render-markdown.nvim`
- `RRethy/vim-illuminate`
- `HiPhish/rainbow-delimiters.nvim`

## Better approaches

Use one of these instead:

1. **plugin-internal buffer-local guard**
   - load plugin normally
   - skip activation/setup for big buffers

2. **autocmd callback guard at attach/activation time**
   - check `bigfile.is_bigfile(buf)` where the plugin actually attaches or configures a buffer

3. **plugin-specific disable APIs / buffer variables**
   - if the plugin supports disabling itself for selected buffers

## Notes

The shared helper in `lua/cfg/bigfile.lua` is still useful.
The issue is the *layer* where bigfile gating is applied.

## Acceptance criteria

- no plugin-spec `enabled = function() return not bigfile.is_bigfile(0) end` for per-buffer bigfile behavior
- bigfile-sensitive plugins are gated at buffer attach/activation time instead
- behavior is consistent regardless of whether a big file or small file is opened first
