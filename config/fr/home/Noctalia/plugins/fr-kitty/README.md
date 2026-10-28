# `fr/kitty`

Noctalia plugin for switching between Kitty panes.

For end-user instructions see [USAGE.md](USAGE.md).

It lists every Kitty pane across OS windows and tabs using Kitty remote
control, lets you search by pane title, working directory, pane ID, or running
process/command, and focuses the selected pane. Focusing a pane also switches to
its tab and OS window.

## Entry

- `panes` — **launcher provider**, the only UI. Type `/kitty` in Noctalia's
  built-in launcher. Set `include_in_global_search = true` in `plugin.toml` to
  also match panes in the un-prefixed global search.

It is backed by [`kitty.luau`](kitty.luau) (parse/search) and
[`fetch.luau`](fetch.luau) (socket discovery + `kitten @ ls`), driven by
[`provider.luau`](provider.luau).

The plugin is copied to Noctalia's data directory by Home Manager and enabled
as `fr/kitty` in `config/fr/home/noctalia.nix`. It has no bar widget and no
panel; reach it with `/kitty` in the launcher.

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

## Results

Results are a flat ranked list in Noctalia's launcher; each row shows the
pane's `OS window › tab` breadcrumb and, when known, its working directory.
`↑` / `↓` move the selection, `Enter` jumps to the pane (switching to its tab
and OS window), and typing re-ranks live. The pane list is re-read on each fresh
`/kitty` open, with results cached briefly for typed queries.

Loading failures (no socket, missing `kitten`, remote-control or JSON errors)
are written to the Noctalia log with a `kitty:` prefix:
`journalctl --user -u noctalia -e | grep 'kitty:'`.

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
