# Kitty Panes — user guide

Search every Kitty pane across all OS windows and tabs, and jump to one.

## Open

- In Noctalia's built-in launcher, type `/kitty`. (Set
  `include_in_global_search = true` in `plugin.toml` to also match panes without
  the prefix.)
- Or click the cat icon on the bottom bar for the dedicated panel, or run
  `noctalia msg panel-toggle fr/kitty:panes`.

## Use

- In the panel, panes are shown as a tree of **OS windows → tabs → panes**.
  Click a header's chevron to collapse or expand it; the list follows the
  selection as you move.
- Type to filter by pane title, folder (CWD), pane ID (`220` or `#220`), or
  the running command. While a query is active the tree flattens to a ranked
  list.
- Narrow with attribute filters, e.g. `process:pi`, `os:2`, `tab:97`,
  `pane:220`, `cwd:project`, `title:notes`; prefix with `-` to exclude
  (`-process:ssh`).
- `↑` / `↓` move the selection (hold to repeat), `Enter` jumps to the pane; the
  launcher list also scrolls with the mouse wheel.
- The focused pane is marked; jumping to a pane switches to its tab and OS
  window automatically.

## Requirements

- Kitty with remote control enabled:

  ```conf
  allow_remote_control yes
  listen_on unix:/run/user/1000/kitty
  ```

- `kitten` and `jq` available to Noctalia.

The socket is found automatically from `$XDG_RUNTIME_DIR/kitty-*` (Kitty appends
`-<pid>`). To pin one instance, set the plugin's **socket** option under
Settings → Plugins → fr/kitty, e.g. `unix:/run/user/1000/kitty-12345`.

## If the list is empty

- Check the log: `journalctl --user -u noctalia -e | grep 'kitty:'`.
- "No Kitty panes found" usually means the socket isn't reachable; verify
  `kitten @ --to unix:/run/user/1000/kitty-<pid> ls` works in a terminal.
