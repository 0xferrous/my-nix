{
  lib,
  myNixInputs,
  pkgs,
  ...
}:
let
  hermesConfigSourceScript = pkgs.writeShellScript "hermes-config-source" ''
    workspace=/var/lib/hermes/workspace
    if [ ! -e "$workspace/flake.nix" ]; then
      mkdir -p "$workspace"
      cp -a ${myNixInputs.self.outPath}/. "$workspace/"
      chmod -R u+rwX "$workspace"
      chown -R agent:users "$workspace"
    fi
  '';
in
{
  imports = [
    (myNixInputs.nixpkgs + "/nixos/modules/profiles/minimal.nix")
    myNixInputs.ash-stable.nixosModules.ashGuest
    myNixInputs.hermes-agent.nixosModules.default
    myNixInputs.impermanence.nixosModules.impermanence
  ];

  networking.hostName = "hermes";
  system.stateVersion = "26.05";
  system.disableInstallerTools = true;

  virtualisation.ash-guest = {
    enable = true;
    user = "agent";
    emptyPassword = false;
    passwordlessSudo = true;
  };

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  services.openssh.enable = true;

  users.users.agent = {
    isNormalUser = true;
    uid = 1000;
    group = "users";
    home = "/home/agent";
    createHome = true;
    shell = pkgs.bashInteractive;
    extraGroups = [ "wheel" ];
    hashedPassword = "!";
  };

  security.sudo.wheelNeedsPassword = false;

  environment.persistence."/persist" = {
    directories = [
      "/var/lib/nixos"
      "/var/lib/hermes"
    ];
    users.agent.directories = [
      ".hermes"
      ".local/bin"
      ".local/share"
      ".cache"
    ];
  };

  services.hermes-agent = {
    enable = true;
    # Headless browser for the agent: lightpanda is on the service PATH and in
    # the per-user profile, so `lightpanda fetch|serve|mcp` works from both the
    # agent and an SSH shell.
    extraPackages = [ pkgs.lightpanda ];
    package = myNixInputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.minimal;
    addToSystemPackages = true;
    user = "agent";
    group = "users";
    createUser = false;
    # Keep Hermes' workspace inside its persistent state, without a host mount.
    workingDirectory = "/var/lib/hermes/workspace";
    container.enable = false;
  };

  # The flake source is part of the system closure. Seed a writable copy in
  # Hermes' persistent workspace once, so it can edit and rebuild this VM's
  # config without a host checkout mount.
  system.activationScripts.hermes-config-source = lib.stringAfter [ "hermes-agent-setup" ] ''
    ${hermesConfigSourceScript}
  '';

  # Ash boots the system closure directly, so NixOS activation scripts are not
  # run on first boot. Seed the persistent workspace from a boot-time unit too.
  systemd.services.hermes-config-source = {
    description = "Seed Hermes' writable NixOS flake workspace";
    wantedBy = [ "multi-user.target" ];
    before = [ "hermes-agent.service" ];
    after = [ "var-lib-hermes.mount" ];
    requires = [ "var-lib-hermes.mount" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${hermesConfigSourceScript}";
    };
  };

  # Run Hermes natively as the Ash SSH user so it can edit the config, install
  # user packages, and rebuild this guest. This deliberately removes systemd's
  # privilege-escalation and filesystem guards: the agent already has
  # passwordless sudo inside this disposable VM.
  systemd.services.hermes-agent.serviceConfig = {
    NoNewPrivileges = lib.mkForce false;
    ProtectSystem = lib.mkForce false;
  };

  environment.systemPackages = with pkgs; [
    bashInteractive
    nixos-rebuild
    coreutils
    curl
    git
    gnutar
    gnugrep
    gawk
    findutils
    python3
    uv
    xz
  ];

  # Hermes and its tools are intentionally user-managed in this VM. The agent
  # can install/remove packages in its user profile and rebuild this config.
  # Passwordless wheel sudo is root-equivalent inside the guest only.
  nix.settings.trusted-users = [
    "root"
    "agent"
  ];
}
