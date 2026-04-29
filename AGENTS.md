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
