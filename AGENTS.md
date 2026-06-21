# AGENTS

Repo-wide instructions:

- when working on `pkgs/frs-nvim`, follow `pkgs/frs-nvim/AGENTS.md`
- generic reusable Home Manager modules live under `modules/home`
- generic reusable NixOS modules live under `modules/nixos`
- public `fr` Home Manager config lives under `config/fr/home.nix`
- public `fr` NixOS config lives under `config/fr/nixos.nix`
- export reusable Home Manager modules from the root `flake.nix` as `homeManagerModules.*`
- export reusable NixOS modules from the root `flake.nix` as `nixosModules.*`
- export public `fr` Home Manager config from the root `flake.nix` as `homeConfigs.fr`
- export public `fr` NixOS config from the root `flake.nix` as `nixosConfigs.fr`
- public/private split pattern: keep public defaults here, import them from the private config, gate them behind a short namespaced enable option (prefer `fr.public.enable` for the umbrella public module), and prefer `lib.mkDefault` for settings that private config may override
- when public config modules need this flake's inputs, pass them via `_module.args.myNixInputs = inputs` from the exported config wrapper; modules should accept `myNixInputs` rather than `inputs` to avoid colliding with consuming flakes. Remember `_module.args` is shared across the whole module evaluation, not private to only the modules imported by the module that sets it
- add new public Home Manager packages under `config/fr/home/packages/`, categorized by purpose (`cli-tools`, `dev`, `nix-tools`, `productivity`, `ai`, etc.) rather than by host; `linux.nix` is for Linux-only or platform-pinned packages, and `mac.nix` is reference-only and intentionally not imported
- when adding flake-provided package inputs, make them follow this flake's `nixpkgs` where possible; for Rust-package flakes that use `rust-overlay`, prefer a shared top-level `rust-overlay` input and `inputs.rust-overlay.follows = "rust-overlay"` to avoid stale toolchain fetch/unpack issues
- prefer upstream/nixpkgs package expressions over local packaging workarounds; if a local package expression is necessary, document why near the package entry
- always run `nix fmt` for formatting the code
