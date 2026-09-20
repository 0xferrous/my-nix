{
  fenix,
  ghmd,
  multiverse,
  noctalia-greeter,
}:
{
  lib,
  pkgs,
  ...
}:
{
  # Permit the x86_64 host to build and run aarch64-linux derivations through
  # QEMU user-mode emulation. ARM hosts do not need to emulate themselves.
  boot.binfmt.emulatedSystems = lib.optional (
    pkgs.stdenv.hostPlatform.system == "x86_64-linux"
  ) "aarch64-linux";

  imports = [
    ghmd.nixosModules.default
    multiverse.nixosModules.default
    noctalia-greeter.nixosModules.default
    ../../../modules/nixos/ash-vm-network.nix
    ../../../modules/nixos/bluetooth-keyboard-wake.nix
    ../../../modules/nixos/iron-proxy.nix
    ../../../modules/nixos/desktop-portal.nix
    ../../../modules/nixos/power-management.nix
    ../../../modules/nixos/virtiofsd-nix-store.nix

    ./options.nix
    ./desktop.nix
    ./dns.nix
    (import ./ghmd.nix { inherit fenix ghmd; })
    ./incus.nix
    ./nix.nix
    ./waydroid.nix
  ];
}
