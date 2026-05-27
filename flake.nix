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
      fenix,
      ghmd,
      agentspace,
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
      agentVmModule = import ./config/fr/agent-vm.nix {
        inherit pkgs lib;
        uname = "dmnt";
        mkExecSSH = agentspace.lib.mkExecSSH;
        piPackage = pkgs.pi;
        frsNvimPackage = frs-nvim.packages.${system}.default;
      };
      agentVms = agentVmModule.fr.agentspace.vms;
      allVms = lib.mapAttrs (_name: vmConfig: {
        type = "app";
        program = agentspace.lib.mkLaunch (
          agentspace.lib.mkSandbox (
            builtins.removeAttrs vmConfig [
              "enable"
              "packageName"
              "socketActivation"
            ]
          )
        );
      }) agentVms;
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
        };
      };
      apps = lib.recursiveUpdate frs-nvim.apps {
        ${system} = allVms // {
          pi = {
            type = "app";
            program = "${pkgs.pi}/bin/pi";
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
      homeManagerModules = import ./modules/home;
      nixosModules = import ./modules/nixos;
      homeConfigs = {
        fr =
          { ... }:
          {
            imports = [
              inputs.agent-box.homeManagerModules.default
              agentVmModule
              ./config/fr/home.nix
            ];
            _module.args.myNixInputs = inputs;
          };
      };
      nixosConfigs = {
        fr = import ./config/fr/nixos.nix {
          inherit fenix ghmd;
        };
      };
    };
}
