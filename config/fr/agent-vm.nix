{ mkExecSSH, uname, llmAgentsNixPkgs, ... }: 
let
  homeDir = "/home/${uname}";
  nixosConfig = {...}: {

  };
  homeConfig = {...}: {
    home.packages = with llmAgentsNixPkgs; [
      pi
    ];
  };
  mkVm = vmName: vmConfig: {
    ssh.authorizedKeys = ["ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJrIZYaoh6XQrI7ZMjSTa50PtK7neCGDOpOXCa+6i0J9KZKWRKJEhNqpbnn6ivzl7/pW9W9afN9NQB2EQdzpANE="];
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
  } // vmConfig;
in
{
  agentspace = mkVm "agentspace" {
    workspace.spaces.agentspace = "${homeDir}/dev/fr/open-source/agentspace";
  };
}
