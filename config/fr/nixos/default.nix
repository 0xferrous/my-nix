{
  dms,
  fenix,
  ghmd,
}:
{
  ...
}:
{
  imports = [
    ghmd.nixosModules.default
    ../../../modules/nixos/bluetooth-keyboard-wake.nix
    ../../../modules/nixos/desktop-portal.nix
    ../../../modules/nixos/power-management.nix
    ../../../modules/nixos/virtiofsd-nix-store.nix

    ./options.nix
    (import ./desktop.nix { inherit dms; })
    ./dns.nix
    (import ./ghmd.nix { inherit fenix ghmd; })
    ./nix.nix
  ];
}
