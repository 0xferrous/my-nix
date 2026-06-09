{
  lib,
  pkgs,
  impermanence,
  ...
}:
let
  impermanenceRoot = "/persist";
  opensshSettings = {
    AllowStreamLocalForwarding = lib.mkDefault "yes";
    AllowTcpForwarding = lib.mkDefault "yes";
    DisableForwarding = lib.mkDefault false;
    PasswordAuthentication = lib.mkDefault true;
    PermitEmptyPasswords = lib.mkDefault "yes";
    StreamLocalBindUnlink = lib.mkDefault "yes";
  };
in
{
  imports = [
    impermanence.nixosModules.impermanence
  ];

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

  services.openssh = {
    enable = true;
    settings = opensshSettings;
  };

  systemd.services.virtie-ssh-signal = {
    wantedBy = [ "multi-user.target" ];
    requires = [ "sshd.service" ];
    after = [ "sshd.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.coreutils}/bin/echo SSH-READY > /dev/virtio-ports/virtie.ready
    '';
  };

  services.getty.autologinUser = "agent";

  users.users.agent = {
    isNormalUser = true;
    uid = 1000;
    group = "users";
    home = "/home/agent";
    createHome = true;
    extraGroups = [ "wheel" ];
    hashedPassword = "";
  };

  security.sudo.wheelNeedsPassword = false;

  systemd.tmpfiles.rules = [
    "d /run/user/1000 0700 agent users - -"
    "d /run/user/1000/gnupg 0700 agent users - -"
    "r /run/user/1000/gnupg/S.gpg-agent - - - - -"
  ];

  systemd.services.agentspace-tmpfiles-create = {
    description = "Create agentspace runtime tmpfiles";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/run/current-system/systemd/bin/systemd-tmpfiles --create";
    };
  };

  boot.loader.grub.enable = false;

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtiofs"
    "ext4"
  ];

  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "mode=0755"
      "size=2G"
    ];
  };

  fileSystems."/nix/store" = {
    device = "ro-store";
    fsType = "virtiofs";
    neededForBoot = true;
    options = [ "ro" ];
  };

  fileSystems.${impermanenceRoot} = {
    device = "/dev/disk/by-label/persist";
    fsType = "ext4";
    neededForBoot = true;
  };

  environment.persistence.${impermanenceRoot} = {
    directories = [
      "/var/lib/nixos"
      "/var/lib/tailscale"
    ];
  };

  system.stateVersion = "26.05";
}
