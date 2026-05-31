{
  lib,
  config,
  pkgs,
  myNixInputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  homeDir = config.home.homeDirectory;
  nixosConfig =
    { lib, ... }:
    {
      nix.settings = {
        substituters = [
          "http://10.0.2.2:5000?priority=30"
          "https://cache.nixos.org"
        ];
        trusted-public-keys = [
          "nixos-1:TpdALX3FryCxN1I/WG+lhTeme19H/Ka035MJchdsYH4="
        ];
      };

      environment.sessionVariables.HARMONIA_CACHE_URL = "http://10.0.2.2:5000";
    };
  homeConfig =
    { ... }:
    {
      imports = [
        myNixInputs.nix-index-database.homeModules.default
      ];

      home.packages = with pkgs; [
        pi
        frsNvimPackage
      ];

      home.sessionVariables = {
        EDITOR = "nvim";
      };

      home.shellAliases = {
        vi = "nvim";
        vim = "nvim";
        vimdiff = "nvim -d";
      };

      programs.nix-index.enable = true;
      programs.nix-index-database.comma.enable = true;
    };
in
{
  imports = [
    ../../modules/home/agentspace.nix
  ];

  fr.agentspace = {
    enable = true;

    commonHomeModules = [ homeConfig ];
    commonNixosModules = [ nixosConfig ];
    commonWriteFiles = {
      "/home/agent/.pi/agent/auth.json" = {
        path = "${homeDir}/.pi/agent/auth.json";
        mode = "0600";
        chown = "agent:users";
        overwrite = true;
      };
      "/home/agent/.codex/auth.json" = {
        path = "${config.home.homeDirectory}/.codex/auth.json";
        mode = "0600";
        chown = "agent:users";
        overwrite = true;
      };
      "/home/agent/.local/share/uv/credentials/credentials.toml" = {
        path = "${config.home.homeDirectory}/.local/share/uv/credentials/credentials.toml";
        mode = "0600";
        chown = "agent:users";
        overwrite = true;
      };
    };

    vms.agentspace = {
      sshConnect.identityFile = "~/.ssh/ferrous.pub";
      workspace.spaces.agentspace = "${homeDir}/dev/fr/open-source/agentspace";
      workspace.spaces."my-nix" = "${homeDir}/dev/fr/my-nix";
      workspace.spaces."agent-stuff" = "${homeDir}/dev/fr/agent-stuff";
    };
  };
}
