{
  pkgs,
  myNixInputs,
  system,
  ...
}:
with pkgs;
[
  # Package management
  cachix
  nixpkgs-fmt
  nixfmt
  nixfmt-tree
  flake-utils

  # Nix utilities
  nurl
  nix-init
  # myNixInputs.noogle-cli.packages.${system}.default

  # Secrets
  age
  myNixInputs.agenix.packages.${system}.default
]
