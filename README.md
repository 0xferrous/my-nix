# my-nix

Public Nix files extracted from my larger setup.

Current public building blocks include:

- [`pkgs/frs-nvim`](./pkgs/frs-nvim/README.md): portable Neovim wrapper config exposed via this repo's flake `packages` and `apps`
- [`images/agent-box-rt`](./images/agent-box-rt/README.md): image builder for environments intended to run inside [`agent-box`](https://github.com/0xferrous/agent-box), exposed via this repo's flake as `lib.mkAgentBoxImage`
- `homeManagerModules.public` / `homeManagerModules.default`: public Home Manager baseline module intended to be imported from a private configuration
- `nixosModules.public` / `nixosModules.default`: public NixOS baseline module intended to be imported from a private configuration

## Public module pattern

This repo can export reusable Home Manager and NixOS modules consumed from a private flake.

Current baseline:

- gates public modules behind `fr.public.enable`
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
        my-nix.nixosModules.default
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
        my-nix.homeManagerModules.default
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
