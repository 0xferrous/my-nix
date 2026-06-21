{
  description = "Public Nix building blocks";

  nixConfig = {
    extra-substituters = [
      "https://numtide.cachix.org"
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium = {
      url = "github:amaanq/helium-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codexbar = {
      url = "github:0xferrous/CodexBar-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    frs-xofi-menus = {
      url = "github:0xferrous/frs-wofi-menus";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvimpager = {
      url = "github:lucc/nvimpager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noogle = {
      url = "github:nix-community/noogle";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noogle-cli = {
      url = "github:juliamertz/noogle-cli";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.noogle.follows = "noogle";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    numr = {
      url = "github:nasedkinpv/numr";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    wifitui = {
      url = "github:shazow/wifitui";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agent-box = {
      url = "github:0xferrous/agent-box";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    foundry-stable = {
      url = "github:shazow/foundry.nix/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    foundry-nightly = {
      url = "github:shazow/foundry.nix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agent-images = {
      url = "github:nothingnesses/agent-images";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms-plugin-registry = {
      url = "github:AvengeMedia/dms-plugin-registry";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agentspace = {
      url = "github:shazow/agentspace";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agent-stuff = {
      url = "github:0xferrous/agent-stuff";
      flake = false;
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghmd = {
      url = "github:0xferrous/ghmd";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    # agent-images = {
    #   url = "github:0xferrous/agent-images/feat/nix-ld";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    frs-nvim = {
      url = "path:./pkgs/frs-nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      frs-nvim,
      dms,
      fenix,
      ghmd,
      agentspace,
      impermanence,
      ...
    }:
    let
      system = "x86_64-linux";
      overlay = import ./pkgs/overlay.nix {
        inherit inputs system;
      };
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ overlay ];
      };
      lib = pkgs.lib;
    in
    {
      overlays.default = overlay;

      packages = lib.recursiveUpdate frs-nvim.packages {
        ${system} = {
          inherit (pkgs)
            fr-kbd-backlight
            git-hunk
            opensrc
            pi
            ;
          "install-bin" = pkgs."install-bin";
        };
      };
      apps = lib.recursiveUpdate frs-nvim.apps {
        ${system} = {
          pi = {
            type = "app";
            program = "${pkgs.pi}/bin/pi";
          };
          "install-bin" = {
            type = "app";
            program = "${pkgs."install-bin"}/bin/install-bin";
          };
        };
      };

      formatter.${system} = pkgs.nixfmt-tree;

      lib.mkAgentBoxImage =
        args:
        import ./lib/mkAgentBoxImage.nix (
          args
          // {
            inputs = inputs // {
              foundry = inputs.foundry-stable;
            };
          }
        );
      lib.mkAgentspaceVmSystems = import ./lib/mkAgentspaceVmSystems.nix;
      lib.mkAgentspaceVmApps = import ./mkAgentspaceVmApps.nix;
      homeManagerModules = import ./modules/home;
      nixosModules = import ./modules/nixos;
      homeConfigs = {
        fr =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            myNixInputs = inputs;
          in
          {
            imports = [
              inputs.agent-box.homeManagerModules.default
              (import ./config/fr/home.nix {
                inherit
                  config
                  lib
                  myNixInputs
                  pkgs
                  ;
              })
            ];
            _module.args.myNixInputs = inputs;
          };
      };
      nixosConfigs = {
        fr = import ./config/fr/nixos.nix {
          inherit dms fenix ghmd;
        };
        agent = import ./config/agent/nixos.nix {
          inherit fenix ghmd impermanence;
        };
      };

      nixosConfigurations.agent = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit fenix ghmd impermanence;
        };
        modules = [
          ./config/agent/nixos.nix
        ];
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          dhall
          dhall-json
          haskellPackages.dhall-toml
        ];
      };
    };
}
