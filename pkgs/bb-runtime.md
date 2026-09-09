# bb runtime contract

`bb` packages the published Linux x64 Electron AppImage and launches its
server, host daemon, bridge workers, official plugins, and web UI from the same
release. The Nix wrapper adds the runtime tools needed by those processes while
leaving user state and provider configuration in place.

The wrapper preserves `HOME`, `PATH`, `XDG_CONFIG_HOME`, `CODEX_HOME`,
`PI_CODING_AGENT_DIR`, `BB_DATA_DIR`, and provider API credentials. It prepends
the packaged Codex and Pi executables to `PATH` instead of replacing the user's
path. The provider bridges also receive absolute command paths through
`BB_CODEX_BRIDGE_APP_SERVER_COMMAND` and `BB_PI_BRIDGE_COMMAND` unless the user
has already set those variables.

The app's own plugin host reads bundled official plugins from the release and
user-installed plugins from `BB_DATA_DIR` (normally `~/.bb`). The package does
not relocate or overwrite `~/.bb`, `~/.codex`, `~/.pi`, `~/.claude`, project
skill roots, or provider configuration. `BB_BRIDGE_DIR` and `BB_CLI_DIR` remain
owned by the packaged bb runtime, and the bundled CLI shebang points at the Nix
Node runtime so it does not depend on a user-installed `node`.

Nushell needs one special case: the packaged desktop's shell-path helper asks
the configured shell for a POSIX-style `$PATH`, which Nushell reports literally
inside the AppImage FHS environment. When `SHELL` points to Nushell, the
launcher uses `/bin/bash` for the packaged process and retains the original
value as `BB_NIX_ORIGINAL_SHELL`.

The launcher adds `git` and Node to the AppImage FHS environment, passes
`--no-sandbox`, and selects SwiftShader only when `/dev/dri` is absent. It
selects Wayland when `WAYLAND_DISPLAY` is available. The `bb-app` launcher uses
the AppImage's Electron runtime in Node mode so its native add-ons use the
Electron ABI shipped by the release; the standalone `bb` CLI uses the Nix Node
runtime.

Run the desktop app, then use the packaged CLI entrypoint against its local
server with:

```bash
nix run github:0xferrous/my-nix#bb
nix shell github:0xferrous/my-nix#bb -c bb provider list
nix shell github:0xferrous/my-nix#bb -c bb thread list --json
```

For provider smoke checks, select `codex` and `pi` with the `luna` model shown
by `provider models`, then inspect `thread list --json` and the thread events.
