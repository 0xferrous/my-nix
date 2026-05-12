# my-nix

Public Nix files extracted from my larger setup.

Current public building blocks include:

- [`pkgs/frs-nvim`](./pkgs/frs-nvim/README.md): portable Neovim wrapper config exposed via this repo's flake `packages` and `apps`
- [`lib/mkAgentBoxImage.nix`](./lib/mkAgentBoxImage.nix): image builder for environments intended to run inside [`agent-box`](https://github.com/0xferrous/agent-box), exposed via this repo's flake as `lib.mkAgentBoxImage`
- `homeManagerModules.vcs`: generic reusable Home Manager VCS identity projection module
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
- `homeManagerModules.termfilechooser` exports `modules/home/termfilechooser.nix`
- `nixosModules.k3sMicrovm` exports `modules/nixos/k3s-microvm.nix`
- `homeConfigs.fr` exports `config/fr/home.nix`
- `nixosConfigs.fr` exports `config/fr/nixos.nix`

Public `fr` config should be gated behind `fr.public.enable` and use `lib.mkDefault` for values that a private repo may override. Generic modules should expose narrowly-scoped options and let users configure upstream Home Manager/NixOS modules directly where possible.

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
