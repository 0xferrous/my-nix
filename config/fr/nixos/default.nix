{
  fenix,
  ghmd,
  multiverse,
  noctalia-greeter,
}:
{
  ...
}:
{
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
    ../../../modules/nixos/llama-cpp.nix

    ./options.nix
    ./desktop.nix
    ./dns.nix
    (import ./ghmd.nix { inherit fenix ghmd; })
    ./incus.nix
    ./llama-cpp.nix
    ./nix.nix
    ./waydroid.nix
  ];
}
