# Repository structure

This repository contains public Nix building blocks extracted from a larger personal setup. It separates reusable modules from the public `fr` configuration that private flakes can import and override.

## Top-level layout

| Path | Purpose |
| --- | --- |
| `flake.nix` | Main flake entrypoint. Wires inputs, exports packages/apps, reusable modules, and public configs. |
| `flake.lock` | Locked flake input revisions. |
| `README.md` | High-level project overview and examples for consuming the public configs. |
| `AGENTS.md` | Repo-wide instructions for coding agents working in this repository. |
| `justfile` | Convenience commands for updating `frs-nvim` locks and refreshing package pins. |
| `lib/` | Reusable Nix library helpers. |
| `modules/` | Generic reusable Home Manager and NixOS modules. |
| `config/` | Public `fr` Home Manager/NixOS configuration built from the reusable modules. |
| `pkgs/` | Packaged software exposed by the flake, including the portable Neovim config. |
| `docs/` | Project documentation and planning notes. |
| `.github/workflows/` | CI workflows. |
| `.agents/skills/` | Local agent skill definitions used by coding agents. |

## Flake outputs

The root flake currently exports these main groups:

- `packages`: package outputs from `pkgs/frs-nvim`, plus this repo's helper packages for `x86_64-linux`.
- `apps`: runnable app outputs from `pkgs/frs-nvim`, plus this repo's helper apps for `x86_64-linux`.
- `homeManagerModules`: reusable Home Manager modules from `modules/home/default.nix`.
- `nixosModules`: reusable NixOS modules from `modules/nixos/default.nix`.
- `homeConfigs.fr`: public Home Manager config wrapper importing `config/fr/home.nix` and passing flake inputs through `_module.args.myNixInputs`.
- `nixosConfigs.fr`: public NixOS config from `config/fr/nixos.nix`.
- `nixosConfigs.agent`: stable agent NixOS config from `config/agent/nixos.nix`.
- `nixosConfigs.nash`: experimental agent NixOS config from `config/agent/nash.nix`, layered on top of the stable agent config.

## `lib/`

Reusable Nix helpers live here, including shared package expressions used by
multiple configuration call sites.

## Reusable modules: `modules/`

Generic modules live here. They should be broadly reusable and avoid private host-specific configuration.

```text
modules/
├── home/
│   ├── default.nix
│   ├── symlinks.nix
│   ├── termfilechooser.nix
│   ├── vcs.nix
│   └── programs/
│       ├── direnv.nix
│       ├── foundry.nix
│       ├── pass.nix
│       └── ssh.nix
└── nixos/
    ├── default.nix
    ├── desktop-portal.nix
    └── k3s-microvm.nix
```

### Home Manager modules

Exported from `modules/home/default.nix`:

- `homeManagerModules.symlinks`
- `homeManagerModules.termfilechooser`
- `homeManagerModules.vcs`
- `homeManagerModules.foundry`
- `homeManagerModules.pass`
- `homeManagerModules.direnv`
- `homeManagerModules.ssh`

### NixOS modules

Exported from `modules/nixos/default.nix`:

- `nixosModules.desktopPortal`
- `nixosModules.k3sMicrovm`

## Public `fr` config: `config/fr/`

The `config/fr` tree contains the public defaults for the `fr` setup. These modules are intended to be imported by private config and overridden there as needed.

```text
config/fr/
├── home.nix
├── nixos.nix
└── home/
    ├── alacritty.nix
    ├── atuin.nix
    ├── desktop-entries.nix
    ├── editorconfig.nix
    ├── enables.nix
    ├── fonts.nix
    ├── gpg.nix
    ├── gtk.nix
    ├── helix.nix
    ├── kitty-portal.nix
    ├── kitty.nix
    ├── misc.nix
    ├── neovim.nix
    ├── rofi.nix
    ├── service-misc.nix
    ├── starship.nix
    ├── wofi.nix
    └── zed.nix
```

### `config/fr/home.nix`

Imports reusable Home Manager modules plus the per-program files under `config/fr/home/`. It sets public defaults such as:

- password-store configuration via `fr.pass`
- direnv/devenv/Poetry helpers via `fr.direnv`
- terminal file chooser defaults via `fr.termfilechooser`
- SSH identity projection via `fr.ssh`
- conditional VCS identities for public `fr` development paths via `fr.vcs`

### `config/fr/nixos.nix`

Defines the public NixOS baseline under `fr.public`. The baseline is gated by `fr.public.enable` and includes:

- desktop portal defaults via `fr.desktopPortal`
- `ghmd` service defaults and optional Caddy proxy at `ghmd.localhost`
- Rust documentation served through Caddy at `rustdoc.localhost`
- localhost host mappings for the public service domains

### `config/agent/nixos.nix`

Defines the stable standalone agent NixOS baseline, including SSH, Tailscale, Nushell, Home Manager user configuration, development tools, and VM filesystem/runtime defaults.

### `config/agent/nash.nix`

Imports the stable agent baseline and layers guest-side support for experimental Ash features used through `nash`. It installs Waypipe and xwayland-satellite for guest Wayland/X11 forwarding, installs the development `ash-dbus-proxy` package, and starts the user-level host notification D-Bus bridge.

## Packages: `pkgs/`

```text
pkgs/
├── git-hunk.nix
├── jj-hunk.nix
├── install-bin.nix
└── frs-nvim/
```

- `pkgs/git-hunk.nix` packages the `git-hunk` tool.
- `pkgs/jj-hunk.nix` packages the `jj-hunk` tool.
- `pkgs/install-bin.nix` packages the `install-bin` helper for symlinking a path into `~/bin`.
- `pkgs/frs-nvim/` is a nested flake for the portable Neovim distribution.

## Portable Neovim: `pkgs/frs-nvim/`

`pkgs/frs-nvim` packages a deterministic Neovim configuration as a Nix app. The root flake re-exports its package and app outputs.

Important files and directories:

```text
pkgs/frs-nvim/
├── flake.nix
├── flake.lock
├── init.lua
├── lua/
│   ├── cfg/
│   ├── ftplugin/
│   ├── plugins/
│   │   └── graveyard/
│   ├── init.lua
│   ├── say-hello.lua
│   └── zk.lua
├── snippets/
├── scripts/
├── patches/
├── issues/
├── README.md
├── KEYMAPS.md
├── LAZY_TRIGGERS.md
├── SMOKE_CHECKLIST.md
└── justfile
```

Key roles:

- `flake.nix`: builds the wrapped Neovim package/app and smoke-test outputs.
- `lua/cfg/`: core Lua configuration loaded by the packaged config.
- `lua/plugins/`: active plugin specs and setup.
- `lua/plugins/graveyard/`: retained inactive/retired plugin config.
- `lua/ftplugin/`: filetype-specific config.
- `snippets/`: snippet definitions packaged with the config.
- `scripts/`: headless smoke-test scripts.
- `patches/`: local patches for vendored/plugin behavior.
- `issues/`: local issue notes for planned work.
- Markdown files such as `KEYMAPS.md`, `LAZY_TRIGGERS.md`, and `SMOKE_CHECKLIST.md`: operational documentation for the Neovim config.

## Documentation: `docs/`

```text
docs/
├── pending-changes.md
├── portals.md
├── public-extraction-plan.md
└── repository-structure.md
```

- `portals.md`: notes about desktop portal behavior/configuration.
- `public-extraction-plan.md`: planning notes for extracting reusable public config.
- `repository-structure.md`: this structure reference.

## CI and automation

```text
.github/workflows/
├── bb-android-build.yml
├── frs-nvim-ci.yml
├── microsandbox-nixos-image.yml
├── package-builds.yml
├── pages.yml
├── update-llm-agents.yml
└── update-packages.yml
```

- `bb-android-build.yml`: manual dispatch that builds the bb Android APKs.
- `frs-nvim-ci.yml`: smoke tests for the portable Neovim flake/config, run
  for changes under `pkgs/frs-nvim` and to the flake files.
- `microsandbox-nixos-image.yml`: builds the microsandbox NixOS image for both
  architectures and pushes it to GHCR; runs for `config/microsandbox` changes
  and by manual dispatch.
- `package-builds.yml`: builds the packages whose `drvPath` changes in a pull
  request, so package PRs (including the `update packages` ones) carry their
  own build check.
- `pages.yml`: publishes `pages/` to GitHub Pages from `main`.
- `update-llm-agents.yml`: weekly refresh of the `llm-agents` lock entry,
  committed straight to `main`.
- `update-packages.yml`: weekly or manual refresh of every updatable package,
  one pull request per package on the stable `update/<name>` branch, each
  bumped package built before its PR is opened, with a failed build handed to
  the repair agent described below.

### Self-healing package updates

`.github/scripts/build-or-autofix.sh` builds one package and, when the build
fails, hands the log to `opencode run --auto` (the same pinned llm-agents CLI
this machine uses) and asks it to repair the package expression under `pkgs/`.
`--auto` is required: without it a headless run would stall on the permission
prompts that `bash`/`external_directory` raise. The agent is told to verify its
own change with `nix build .#<attr> --no-link` and iterate until that passes;
the harness rebuilds afterwards as the authoritative gate (a cache hit when the
agent's build succeeded). It stops when the build passes, when the agent no
longer changes anything under `pkgs/`, or after `AUTOFIX_ATTEMPTS` attempts
(default 3; the `autofix-attempts` input on manual dispatch, `0` disables).
Each attempt gets `AUTOFIX_TIMEOUT` seconds (default 45 minutes).

The bump is committed first and a successful repair lands as its own
`fix(<package>): repair build after update` commit on top of it, so the pull
request shows what the agent changed. A repaired package gets a normal ready
pull request with a note in the body naming the model and attempt.

When the agent gives up, the leg does not fail: its changes are dropped, the
branch keeps the plain bump, and the pull request opens as a **draft** titled
`[needs-human] chore(<package>): update …` with the last build output in the
body and a line in the run summary. The pull request's own `package builds`
check is the failing signal then, and the branch is the starting point for
whoever finishes the fix. On a later run that succeeds, the step also runs
`gh pr ready` because `create-pull-request` cannot convert a draft back itself.

The agent only runs in `update packages`, which is triggered by the schedule or
by hand on `main`, never by a pull request or a fork.

Configuration:

- Model: `AUTOFIX_MODEL` repository variable, default
  `opencode-go/deepseek-v4.1-flash` (OpenCode Go). The free variant is
  `opencode/deepseek-v4.1-flash-free`, which is a different provider id.
  `opencode models | grep deepseek` lists what a credential can reach.
- Credentials: `OPENCODE_API_KEY` (an OpenCode Console key) for OpenCode Go.
  `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY` and
  `GEMINI_API_KEY` are also passed through for other providers. Without any of
  them the agent is skipped and the leg fails as before.

### Binary cache

Every workflow that builds uses the repo's own Cachix cache
(`0xferrous.cachix.org`, public key in `config/fr/nixos/nix.nix`) through
`cachix/cachix-action`:

- Pulling needs no credentials, so pull requests from forks still substitute
  prebuilt paths.
- Pushing needs the `CACHIX_AUTH_TOKEN` repository secret. `skipPush` keeps
  fork pull requests from receiving it, so foreign build results cannot enter
  a cache this repo's machines trust.
- `pushFilter` keeps fetched sources and nixpkgs tarballs out of the cache.

The host's harmonia cache (`http://192.168.127.1:5000`) serves the ash guests
on the bridge and is not reachable from GitHub runners.

Magic Nix Cache is deliberately unused: it uploads one GitHub Actions cache
entry per store path in the build closure, which trips GitHub's cache-API
throttle on bigger closures. It then disables itself for the rest of the run
("Not trying to use it again on this run") and answers `418` to Nix, so the
substituter is dropped mid-build and nothing is uploaded at all.

## Structural conventions

- Put generic reusable Home Manager modules under `modules/home` and export them from `flake.nix` via `homeManagerModules.*`.
- Put generic reusable NixOS modules under `modules/nixos` and export them via `nixosModules.*`.
- Put public `fr` Home Manager config under `config/fr/home.nix` and export it via `homeConfigs.fr`.
- Put public `fr` NixOS config under `config/fr/nixos.nix` and export it via `nixosConfigs.fr`.
- Gate public/private split defaults behind `fr.public.enable` where appropriate.
- Prefer `lib.mkDefault` for public defaults that private configuration may override.
- When public config needs this flake's inputs, pass them as `myNixInputs` through `_module.args` rather than using the generic name `inputs`.
