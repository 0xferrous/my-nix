# `fr/kitty`

Noctalia plugin for switching between Kitty panes.

For end-user instructions see [USAGE.md](USAGE.md).

It lists every Kitty pane across OS windows and tabs using Kitty remote
control, lets you search by pane title, working directory, pane ID, or running
process/command, and focuses the selected pane. Focusing a pane also switches to
its tab and OS window.

## Entries

- `panes` — **launcher provider**, the primary UI. Type `/kitty` in Noctalia's
  built-in launcher. Set `include_in_global_search = true` in `plugin.toml` to
  also match panes in the un-prefixed global search.
- `panes` — **panel**, a dedicated one-click switcher opened by the bar button.
- `launcher` — the bar button that opens the panel.

All three share [`kitty.luau`](kitty.luau) (parse/search) and
[`fetch.luau`](fetch.luau) (socket discovery + `kitten @ ls`).

The plugin is copied to Noctalia's data directory by Home Manager, enabled as
`fr/kitty`, and the `kitty-panes` bar widget is placed on the bottom bar in
`config/fr/home/noctalia.nix`. The launcher provider is reached with `/kitty`;
the panel can also be toggled directly:

```sh
noctalia msg panel-toggle fr/kitty:panes
```

## Requirements

- Kitty with remote control enabled:

  ```conf
  allow_remote_control yes
  listen_on unix:/run/user/1000/kitty
  ```

- The `kitten` executable on the Noctalia service `PATH`.
- `jq` on the same `PATH`. `kitten @ ls` includes every window's environment,
  which is large enough that decoding it verbatim exceeds Noctalia's 25 ms
  async-callback CPU budget. In the subprocess (where CPU is not budgeted) the
  plugin pipes `kitten @ ls` through [`ls-filter.jq`](ls-filter.jq), which
  emits one unit-separated line per pane with the command strings already
  computed. The Luau side then parses those lines directly instead of calling
  `noctalia.json.decode`, so a large session stays well inside the budget.
- `kitty` must be told which socket to use, because Noctalia runs outside Kitty
  and therefore does not inherit `KITTY_LISTEN_ON`. Kitty appends `-<pid>` to
  the `listen_on` value (so `listen_on unix:/run/user/1000/kitty` actually
  listens on `unix:/run/user/1000/kitty-<kitty-pid>`), and every kitty process
  gets its own socket. The plugin resolves sockets in this order:

  1. the `socket` plugin setting (`unix:`/`tcp:` scheme optional),
  2. `KITTY_LISTEN_ON` from the environment,
  3. auto-discovery: every `$XDG_RUNTIME_DIR/kitty*` socket.

  Multiple discovered sockets are queried and their pane trees merged, so panes
  from separately launched kitty processes all appear. Each row remembers its
  own socket, so focusing always targets the right instance. Set the `socket`
  setting explicitly to pin a single instance instead.

### Focusing and the compositor

On Wayland, kitty's `focus-window` can only raise its OS window when it has a
valid activation token; from the launcher Noctalia owns the focus, so kitty
gets none and the workspace would not switch. The plugin lets kitty select the
pane/tab, then resolves the target OS window in niri by title and focuses it
with niri's IPC, which is not token-gated. `focus_delay_ms` (default 0) is
the wait before the first workspace-switch attempt; the plugin then re-asserts
the focus three times in case the launcher's close grabs it back. Raise it if
the workspace does not switch. On compositors without `niri`, only kitty's own
activation runs.

## Search

Search is case-insensitive and splits on whitespace; every token must match.
Fields are weighted so exact pane IDs and titles rank above CWDs and background
command lines. Kitty's JSON does not expose the processes running inside a
remote SSH session, so only the local `ssh` command is searchable there.

Tokens can target one attribute with `field:value`, and a leading `-` negates:

| Filter | Matches |
|--------|---------|
| `pane:220`, `id:220` | pane id |
| `os:2` | OS window ordinal (or id) |
| `tab:97` | tab id (or ordinal) |
| `process:pi`, `cmd:pi` | foreground command/process name or command line |
| `cwd:project` | pane or foreground-process working directory |
| `title:notes` | pane title |
| `socket:kitty-123` | remote-control socket |

Filters combine with each other and with plain tokens, e.g.
`os:2 process:nvim` or `cwd:project -process:ssh`. An unknown `foo:bar` is
treated as plain text.

## Panel controls

The panel renders the panes as a collapsible tree:

- Click an **OS window** or **tab** header (the chevron) to collapse/expand it.
  Only the selected pane and its ancestors/neighbours stay on screen; the list
  follows the selection.
- A pinned bar above the list shows the selected pane's `OS window › tab`, so
  the context stays visible even when a header scrolls out of the window. On
  open, the focused pane starts selected.
- Type to filter — while a query is active the tree flattens to a ranked list.

Keys:

- `↑` / `↓` move the pane selection (hold to repeat), `Enter` focuses.
- `Ctrl+R` or the refresh button re-reads `kitten @ ls`.
- Clicking a pane row focuses it.

Loading, missing-socket, missing-`kitten`, remote-control, and JSON errors are
reported inline with a retry button.

## Tests

The parser and search helpers in `kitty.luau` are host-independent and covered
by `tests/kitty_spec.luau`, which runs the same assertions through both
`parse()` (the raw `kitten @ ls` JSON tree) and `parseLines()` (the compact
`ls-filter.jq` output production uses). `tests/fixture-ls.json` is a captured
`kitten @ ls` tree. Run them with:

```sh
./tests/run-tests.sh
```

or from the repository root:

```sh
just test-fr-kitty
```

The tests use `luau` and `jq` when they are on `PATH`, otherwise
`nix shell nixpkgs#luau nixpkgs#jq`.
