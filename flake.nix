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
      ...
    }:
    {
      packages = frs-nvim.packages;
      apps = frs-nvim.apps;
      lib.mkAgentBoxImage = args:
        import ./lib/mkAgentBoxImage.nix (
          args
          // {
            inputs = inputs // { foundry = inputs.foundry-stable; };
          }
        );
      homeManagerModules = import ./modules/home;
      nixosModules = import ./modules/nixos;
      homeConfigs = {
        fr = { ... }: {
          imports = [
            inputs.agent-box.homeManagerModules.default
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
