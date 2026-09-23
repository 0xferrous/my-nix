{ lib, pkgs, ... }:

{
  imports = [ ./module.nix ];

  networking.hostName = "microsandbox";

  nix = {
    enable = true;
    package = pkgs.nix;
    settings = {
      accept-flake-config = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };

  # Keep only the installer tool needed for the next rebuild, and make it
  # explicit rather than relying on nix.enable's default.
  system.disableInstallerTools = true;
  system.tools.nixos-rebuild.enable = true;

  # microsandbox invokes the image-root /init directly instead of using a
  # bootloader. Follow the activated NixOS profile when one exists, while
  # retaining the image generation for the first boot before any switch.
  system.systemBuilderCommands = ''
    ${pkgs.gawk}/bin/awk -v fallback="$out" '
      /^systemConfig=/ {
        print "systemConfig=/nix/var/nix/profiles/system";
        print "if [ ! -x " "\"" "$systemConfig/init" "\"" " ]; then";
        print "    systemConfig=" fallback;
        print "fi";
        next;
      }
      { print }
    ' "$out/init" > "$out/init.tmp"
    mv "$out/init.tmp" "$out/init"
    ${pkgs.coreutils}/bin/chmod 0755 "$out/init"
  '';

  environment.systemPackages = with pkgs; [
    cacert
    git
    home-manager
    nh
    nix
    sudo
  ];

  # Keep a usable bootstrap account available before a replacement flake is
  # activated. Replacement configurations can override these defaults.
  users.users.agent = {
    isNormalUser = lib.mkDefault true;
    uid = lib.mkDefault 1000;
    group = lib.mkDefault "users";
    home = lib.mkDefault "/home/agent";
    createHome = lib.mkDefault true;
    extraGroups = lib.mkDefault [ "wheel" ];
    hashedPassword = lib.mkDefault "!";
  };
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  system.stateVersion = "26.05";
}
