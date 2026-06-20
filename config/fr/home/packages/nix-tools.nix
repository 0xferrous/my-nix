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

  # Nix utilities
  nurl
  nix-init
  nix-search-tv
  myNixInputs.noogle-cli.packages.${system}.default
  comma
  nix-output-monitor

  # Secrets
  age
  myNixInputs.agenix.packages.${system}.default
]
