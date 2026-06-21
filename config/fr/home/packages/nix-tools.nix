{
  pkgs,
  myNixInputs,
  system,
  ...
}:
let
  noogle-cli = pkgs.rustPlatform.buildRustPackage {
    pname = "noogle-cli";
    version = "0.1.1";
    src = myNixInputs.noogle-cli;
    cargoHash = "sha256-4xW9aYtLz7w6ARATVMXI/RpLmhfsJNJQQkjetcvhlZw=";
    postUnpack = ''
      cp ${myNixInputs.noogle.packages.${system}.data-json} $sourceRoot/data.json
    '';
    meta.mainProgram = "noogle";
  };
in
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
  noogle-cli
  comma
  nix-output-monitor

  # Secrets
  age
  myNixInputs.agenix.packages.${system}.default
]
