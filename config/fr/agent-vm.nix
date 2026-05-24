{
  mkExecSSH,
  uname,
  piPackage,
  ...
}:
let
  homeDir = "/home/${uname}";
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
      home.packages = [
        piPackage
      ];
    };
  mkVm =
    vmName: vmConfig:
    {
      ssh.authorizedKeys = [
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJrIZYaoh6XQrI7ZMjSTa50PtK7neCGDOpOXCa+6i0J9KZKWRKJEhNqpbnn6ivzl7/pW9W9afN9NQB2EQdzpANE="
      ];
      ssh.exec = mkExecSSH {
        inherit homeDir;
        configFile = "~/.ssh/agentspace.config";
      };
      persistence.baseDir = "${homeDir}/vms/${vmName}";
      workspace.enable = true;
      workspace.addCurrentDir = true;
      writeFiles."/home/agent/.pi/agent/auth.json" = {
        path = "${homeDir}/.pi/agent/auth.json";
        mode = "0600";
        chown = "agent:users";
        overwrite = true;
      };
      homeModules = [
        homeConfig
      ];
      extraModules = [
        nixosConfig
      ];
    }
    // vmConfig;
in
{
  imports = [
    ../../modules/home/agentspace.nix
  ];

  fr.agentspace = {
    enable = true;

    vms.agentspace = mkVm "agentspace" {
      socketActivation = {
        enable = true;
        identityFile = "~/.ssh/ferrous.pub";
      };
      workspace.spaces.agentspace = "${homeDir}/dev/fr/open-source/agentspace";
    };
  };
}
