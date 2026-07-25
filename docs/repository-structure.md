# Repository structure

This repository contains public Nix building blocks extracted from a larger personal setup. It separates reusable modules from the public `fr` configuration that private flakes can import and override.

## Top-level layout

| Path | Purpose |
| --- | --- |
| `flake.nix` | Main flake entrypoint. Wires inputs, exports packages/apps, reusable modules, public `fr` configs, and the `mkAgentBoxImage` helper. |
| `flake.lock` | Locked flake input revisions. |
| `README.md` | High-level project overview and examples for consuming the public configs. |
| `AGENTS.md` | Repo-wide instructions for coding agents working in this repository. |
| `justfile` | Convenience commands for building/loading the agent-box image and updating `frs-nvim` locks. |
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
- `lib.mkAgentBoxImage`: helper imported from `lib/mkAgentBoxImage.nix` for building an agent-box runtime image.
- `homeManagerModules`: reusable Home Manager modules from `modules/home/default.nix`.
- `nixosModules`: reusable NixOS modules from `modules/nixos/default.nix`.
- `homeConfigs.fr`: public Home Manager config wrapper importing `config/fr/home.nix` and passing flake inputs through `_module.args.myNixInputs`.
- `nixosConfigs.fr`: public NixOS config from `config/fr/nixos.nix`.
- `nixosConfigs.agent`: agent NixOS config from `config/agent/nixos.nix`.

## `lib/`

```text
lib/
└── mkAgentBoxImage.nix
```

`lib/mkAgentBoxImage.nix` builds an image intended for use inside `agent-box`. The root flake exposes it as `lib.mkAgentBoxImage` and injects this flake's inputs, including the stable Foundry input under `foundry`.

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

Defines the standalone agent NixOS baseline, including SSH, Tailscale, Nushell, Home Manager user configuration, development tools, and VM filesystem/runtime defaults.

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
├── agent-box-rt-image.yml
└── frs-nvim-ci.yml
```

- `agent-box-rt-image.yml`: workflow related to the agent-box runtime image.
- `frs-nvim-ci.yml`: CI for the portable Neovim flake/config.

## Structural conventions

- Put generic reusable Home Manager modules under `modules/home` and export them from `flake.nix` via `homeManagerModules.*`.
- Put generic reusable NixOS modules under `modules/nixos` and export them via `nixosModules.*`.
- Put public `fr` Home Manager config under `config/fr/home.nix` and export it via `homeConfigs.fr`.
- Put public `fr` NixOS config under `config/fr/nixos.nix` and export it via `nixosConfigs.fr`.
- Gate public/private split defaults behind `fr.public.enable` where appropriate.
- Prefer `lib.mkDefault` for public defaults that private configuration may override.
- When public config needs this flake's inputs, pass them as `myNixInputs` through `_module.args` rather than using the generic name `inputs`.
