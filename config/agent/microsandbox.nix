{
  lib,
  home-manager,
  myNixInputs,
  pkgs,
  ...
}:

{
  imports = [
    home-manager.nixosModules.home-manager
    ../microsandbox/module.nix
  ];

  # This is a switchable NixOS target for the minimal microsandbox image, not
  # another OCI image. The image already supplies /init and the guest kernel.
  boot.isContainer = true;
  networking.useHostResolvConf = lib.mkForce false;

  # The agent target declares useful inotify and namespace sysctls; unlike the
  # minimal bootstrap defaults, this target explicitly applies them.
  systemd.services.systemd-sysctl.enable = lib.mkForce true;

  fr.agent.impermanence.enable = false;

  fr.agent.selfUpdate = {
    enable = true;
    workspace = "/workspace";
    nixosTarget =
      if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
        "agent-microsandbox"
      else
        "agent-microsandbox-${pkgs.stdenv.hostPlatform.system}";
    homeTarget =
      if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
        "agent-microsandbox"
      else
        "agent-microsandbox-${pkgs.stdenv.hostPlatform.system}";
  };

  # Install the agent Home Manager profile as part of this switch target.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit myNixInputs;
      agentUseAshIntegration = false;
      agentUseProxy = false;
      agentUseBbSource = false;
      bbPackageOverride = myNixInputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.bb-app;
      includeOpenCodeDesktop = false;
    };
    users.agent = import ./home.nix;
  };
}
