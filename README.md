# my-nix

Public Nix files extracted from my larger setup.

## Table of contents

- [Public building blocks](#public-building-blocks)
- [Layout pattern](#layout-pattern)
- [Overlay & packages](#overlay--packages)
- [Public `fr` config pattern](#public-fr-config-pattern)

## Public building blocks

Current public building blocks include:

- `overlays.default`: overlay exposing the reusable packages under [`pkgs/`](./pkgs/) under their plain names (see [Overlay & packages](#overlay--packages))
- `packages.<system>.*`: the same packages as flake outputs, no overlay required
- [`pkgs/frs-nvim`](./pkgs/frs-nvim/README.md): portable Neovim wrapper config exposed via this repo's flake `packages` and `apps`
- `packages.<system>.pi`: `pi` wrapped with default CLI args plus bundled extensions/theme
- `packages.<system>.install-bin`: helper that symlinks a path into `~/bin` using the path basename
- [`lib/mkAgentBoxImage.nix`](./lib/mkAgentBoxImage.nix): image builder for environments intended to run inside [`agent-box`](https://github.com/0xferrous/agent-box), exposed via this repo's flake as `lib.mkAgentBoxImage`
- [`docs/pending-changes.md`](./docs/pending-changes.md): rolling WIP / pending-change log
- `nixosModules.virtiofsdNixStore`: socket-activated read-only `/nix/store` sharing via `virtiofsd`
- `homeManagerModules.vcs`: generic reusable Home Manager VCS identity projection module
- `homeManagerModules.direnv`: reusable Home Manager direnv module with configurable Poetry/devenv stdlib helpers
- `homeManagerModules.termfilechooser`: reusable Home Manager module for `xdg-desktop-portal-termfilechooser`
- `homeConfigs.fr`: public `fr` Home Manager config intended to be imported from a private configuration
- `nixosConfigs.fr`: public `fr` NixOS config intended to be imported from a private configuration

## Layout pattern

This repo separates generic reusable modules from public `fr` config:

- `modules/home/*`: generic reusable Home Manager modules. These should be broadly useful and contain no personal identity/private host config.
- `modules/nixos/*`: generic reusable NixOS modules.
- `config/fr/home.nix`: public `fr` Home Manager config consumed by private configs.
- `config/fr/nixos.nix`: public `fr` NixOS config consumed by private configs.

Root flake exports them separately:

- `homeManagerModules.vcs` exports `modules/home/vcs.nix`
- `homeManagerModules.direnv` exports `modules/home/programs/direnv.nix`
- `homeManagerModules.termfilechooser` exports `modules/home/termfilechooser.nix`
- `nixosModules.k3sMicrovm` exports `modules/nixos/k3s-microvm.nix`
- `homeConfigs.fr` exports `config/fr/home.nix`
- `nixosConfigs.fr` exports `config/fr/nixos.nix`

Public `fr` config should be gated behind `fr.public.enable` and use `lib.mkDefault` for values that a private repo may override. Generic modules should expose narrowly-scoped options and let users configure upstream Home Manager/NixOS modules directly where possible.

Current public `fr` Home Manager defaults enable the reusable `direnv` module with devenv and Poetry stdlib helpers, plus the reusable `termfilechooser` module with `superfile` running inside `kitty`.

## Overlay & packages

[`pkgs/`](./pkgs/) holds package expressions that are generally useful beyond this repo's own config. They are exposed two ways:

- `overlays.default` — apply the overlay to get every package under its plain name in `pkgs`
- `packages.<system>.*` — the same packages as flake outputs, without applying the overlay

The overlay is built from this flake's inputs (e.g. `pi` wraps the `llm-agents` CLI, `herdr` comes from `llm-agents`, `hints` pulls in a pinned source), so consume it via the flake output rather than copying the file standalone.

Example — NixOS module:

```nix
{ inputs, ... }: {
  nixpkgs.overlays = [ inputs.my-nix.overlays.default ];
  environment.systemPackages = [ pkgs.git-hunk pkgs.jj-hunk ];
}
```

Example — direct `pkgs` import:

```nix
pkgs = import inputs.nixpkgs {
  system = "x86_64-linux";
  overlays = [ inputs.my-nix.overlays.default ];
};
```

Packages provided by the overlay:

| package | description |
| --- | --- |
| `pi`, `pi-acp` | `pi` (llm-agents CLI) wrapped with default CLI args plus bundled extensions/theme and AI tooling; `pi-acp` is the Agent Client Protocol adapter |
| `herdr` | agent multiplexer that lives in your terminal |
| `git-hunk`, `jj-hunk` | non-interactive hunk staging for `git` and `jj` |
| `takopi` | Telegram bridge for Codex, Claude Code, and other agent CLIs |
| `terminal-control` | control, inspect, test, and capture real terminal applications for agents and TUI review |
| `prime-agent` | self-improving RLM agent for coding workflows and long-running autonomous tasks |
| `oh-my-pi` | AI coding agent for the terminal |
| `qwen3-server` | Qwen3-Coder 30B-A3B served directly by llama.cpp (Vulkan backend), plus `qwen3-get-model`/`qwen3-bench` helpers |
| `ironclaw` | secure personal AI assistant |
| `iron-proxy` | MITM egress proxy with DNS server, secret injection, and audit logging |
| `obscura` | headless browser engine in Rust: V8, real DOM, CDP, stealth |
| `codex-desktop` | ChatGPT/Codex Linux desktop app (preview): closed-source Electron bundle of the Apache-2.0 `codex` CLI; ships as `.deb` from OpenAI's apt repository (versioned pool URL, pinned via `pkgs/codex-desktop-source.nix`), unpacked and patched here (unfree, `--no-sandbox`, Wayland-aware wrapper with X11 fallback) |
| `hints` | click, scroll, and drag with your keyboard |
| `opensrc` | fetch and cache source code for packages and repos |
| `flake-utils` | synchronize selected flake input locks across local flakes |
| `google-authenticator-transfer-decode` | decode Google Authenticator transfer QR payloads to standard `otpauth` URIs |
| `fr-frame-summon` | summon the Frame extension via local JSON-RPC WebSocket |
| `fr-kbd-backlight` | Nushell helper for managing keyboard backlight brightness |
| `install-bin` | symlink a binary into `~/bin` using the source path basename |
| `ashWrappers` | guest-side wrappers for the Ash Portal |
| `plannotator-pi-extension` | interactive plan and code review extension for Pi |
| `frsNvimPackage` | the [`pkgs/frs-nvim`](./pkgs/frs-nvim/README.md) package |

`packages.<system>.*` exposes all of the above except the overlay-only entries `herdr`, `ashWrappers`, `hints`, `plannotator-pi-extension`, and `frsNvimPackage`.

## Public `fr` config pattern

This repo can export public Home Manager and NixOS config consumed from a private flake.

Current NixOS baseline:

- gates public config behind `fr.public.enable`
- keeps Home Manager baseline minimal for user-level config
- puts `ghmd` in NixOS, not Home Manager
- imports upstream `ghmd.nixosModules.default`
- enables upstream `services.ghmd`
- enables a Caddy vhost for `http://ghmd.localhost`
- serves Rust docs at `http://rustdoc.localhost`
- maps `ghmd.localhost` and `rustdoc.localhost` to `127.0.0.1` with `networking.hosts`
- sets opinionated defaults on upstream `services.ghmd`:
  - `host = "127.0.0.1"`
  - `port = 9000`
  - `theme = "gruvbox"`
  - `rootDir = /home/<user>` derived from `fr.public.user` unless `fr.public.homeDir` overrides it

Example private usage:

```nix
{
  inputs.my-nix.url = "github:0xferrous/my-nix";

  outputs = { nixpkgs, home-manager, my-nix, ... }: {
    nixosConfigurations.machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        my-nix.nixosConfigs.fr
        {
          fr.public.enable = true;
          fr.public.user = "dmnt";

          # optional private overrides
          fr.public.ghmd.domain = "ghmd.localhost";
          services.ghmd.rootDir = /srv/docs;
        }
      ];
    };

    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      modules = [
        my-nix.homeConfigs.fr
        {
          fr.public.enable = true;
        }
      ];
    };
  };
}
```

Notes:

- Caddy pattern follows NixOS-style `virtualHosts."http://...".extraConfig`
- `ghmd.localhost` resolution comes from `networking.hosts`, not Caddy alone
- ghmd service itself comes from upstream `ghmd` flake NixOS module
- default ghmd content root is `/home/<fr.public.user>` unless `fr.public.homeDir` or `services.ghmd.rootDir` overrides it
- default public URLs are `http://ghmd.localhost` and `http://rustdoc.localhost`
