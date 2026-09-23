{ pkgs, ... }:

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

  environment.systemPackages = with pkgs; [
    cacert
    git
    nix
  ];

  system.stateVersion = "26.05";
}
