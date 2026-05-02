{
  description = "Public Nix building blocks";

  nixConfig = {
    extra-substituters = [ "https://numtide.cachix.org" ];
    extra-trusted-public-keys = [
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
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
    agent-box-image = {
      url = "path:./images/agent-box-rt";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.llm-agents.follows = "llm-agents";
      inputs.nix-index-database.follows = "nix-index-database";
      inputs.agent-box.follows = "agent-box";
      inputs.foundry.follows = "foundry-stable";
      inputs.agent-images.follows = "agent-images";
    };
  };

  outputs =
    inputs@{
      frs-nvim,
      agent-box-image,
      fenix,
      ghmd,
      ...
    }:
    {
      packages = frs-nvim.packages;
      apps = frs-nvim.apps;
      lib.mkAgentBoxImage = agent-box-image.lib.mkAgentBoxImage;
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
