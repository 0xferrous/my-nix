# Kitty Panes — user guide

Search every Kitty pane across all OS windows and tabs, and jump to one.

## Open

In Noctalia's built-in launcher, type `/kitty`. (Set
`include_in_global_search = true` in `plugin.toml` to also match panes without
the prefix.)

## Use

- Results are ranked by how well each pane matches your query; every row shows
  its `OS window › tab` breadcrumb and, when known, its folder.
- Type to filter by pane title, folder (CWD), pane ID (`220` or `#220`), or
  the running command.
- Narrow with attribute filters, e.g. `process:pi`, `os:2`, `tab:97`,
  `pane:220`, `cwd:project`, `title:notes`; prefix with `-` to exclude
  (`-process:ssh`).
- `↑` / `↓` move the selection, `Enter` jumps to the pane; jumping to a pane
  switches to its tab and OS window automatically.

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
- An empty result list usually means the socket isn't reachable; verify
  `kitten @ --to unix:/run/user/1000/kitty-<pid> ls` works in a terminal.
