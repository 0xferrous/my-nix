{
  fenix,
  ghmd,
  multiverse,
}:
{
  ...
}:
{
  imports = [
    ghmd.nixosModules.default
    multiverse.nixosModules.default
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
