# AGENTS

Repo-wide instructions:

- when working on `pkgs/frs-nvim`, follow `pkgs/frs-nvim/AGENTS.md`
- reusable Home Manager modules live under `modules/home`
- reusable NixOS modules live under `modules/nixos`
- export reusable Home Manager modules from the root `flake.nix` as `homeManagerModules.*`
- export reusable NixOS modules from the root `flake.nix` as `nixosModules.*`
- public/private split pattern: keep public defaults here, import them from the private config, gate them behind a short namespaced enable option (prefer `fr.public.enable` for the umbrella public module), and prefer `lib.mkDefault` for settings that private config may override
