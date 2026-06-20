{ fenix, ghmd }:
{
  ...
}:
{
  imports = [
    ghmd.nixosModules.default
    ../../../modules/nixos/desktop-portal.nix
    ../../../modules/nixos/power-management.nix
    ../../../modules/nixos/virtiofsd-nix-store.nix

    ./options.nix
    ./desktop.nix
    (import ./ghmd.nix { inherit fenix ghmd; })
    ./nix.nix
  ];
}
