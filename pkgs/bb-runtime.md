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

## State and impermanence

The packaged app leaves `BB_DATA_DIR` unset, so production state defaults to
`~/.bb`. This is the root of the bb-managed state tree and includes the SQLite
database, server and host-daemon identity, auth material, `config.json`,
`env.json`, `client.json`, logs, thread storage, worktrees, personal
workspaces, project attachments, themes, telemetry identity, plugin databases,
plugin secrets, plugin logs, installed plugin artifacts, and generated skills.
Persist the whole directory when using an impermanent home.

On Linux Electron derives `app.getPath("userData")` from `XDG_CONFIG_HOME` and
the product name `bb`, giving `~/.config/bb` by default. Persist this directory
for the desktop's `server-target.json`, encrypted `connect-credential.bin`,
`window-state.json`, and any profile data needed by a remote Connect target.
The desktop can therefore remain a thin client for a remote bb server without
re-enrolling on every launch.

Machines joined to a remote bb server use `~/.bb-machines/<server-host>` as
their data directory and keep the host-daemon port registry under
`~/.bb-machines/host-daemon-ports`. Persist `.bb-machines` when this Nix host
is used as a remote execution machine. The agent impermanence configuration
keeps all three roots:

```nix
users.agent.directories = [
  ".bb"
  ".config/bb"
  ".bb-machines"
];
```

Do not add separate persistence rules for transient runtime markers such as
`bb-app-runtime.json`, daemon lock files, or Electron's `owned-runtime.json`.
The desktop clears its packaged session cache at startup, and the runtime
reaps stale launcher state. If `BB_DATA_DIR` or `XDG_CONFIG_HOME` is overridden,
persist the resulting paths instead of assuming these defaults.

## Update checklist

When updating the release, change the version and AppImage hash together in
`pkgs/bb.nix`. Confirm the artifact remains the x86_64 Linux desktop release,
then check the unpacked paths used by the wrapper:

```text
resources/app.asar.unpacked/node_modules/bb-app/dist/bb-app.js
resources/app.asar.unpacked/node_modules/bb-app/dist/bb.js
resources/app.asar.unpacked/node_modules/bb-app/host-daemon/dist/bb
```

The release's Electron version is part of the native-module contract. Keep
`bb-app` on the AppImage's Electron runtime through `ELECTRON_RUN_AS_NODE=1`;
using Nix Node for that launcher can break `better-sqlite3`, `node-pty`, or
other native add-ons. The standalone `bb` CLI is different: its patched
shebang intentionally uses Nix Node.

After a package update, run the package and CLI smoke checks from the flake:

```bash
nix build .#bb
nix shell .#bb -c bb --help
nix shell .#bb -c bb-app --help
nix shell .#bb -c bb provider list --json
nix shell .#bb -c bb status --json
```

Start `bb-desktop` with isolated `HOME`, `BB_DATA_DIR`, and ports when testing
the local runtime. Confirm both Codex and Pi are available in `provider list`,
then exercise one `luna` thread through each provider and inspect the resulting
thread events with the CLI. Keep the desktop process alive while running those
checks because the CLI is a client of its server.
