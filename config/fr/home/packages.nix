{
  config,
  lib,
  myNixInputs,
  pkgs,
  pkgsRecent ? pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;

  fenixPackages = myNixInputs.fenix.packages.${system};
  AIPackages = myNixInputs.llm-agents.packages.${system};

  subArgs = {
    inherit
      pkgs
      lib
      config
      myNixInputs
      system
      fenixPackages
      AIPackages
      ;
  };
in
{
  home.packages =
    (import ./packages/cli-tools.nix subArgs)
    ++ (import ./packages/dev.nix subArgs)
    ++ (import ./packages/gui.nix subArgs)
    ++ (import ./packages/network-security.nix subArgs)
    ++ (import ./packages/productivity.nix subArgs)
    ++ (import ./packages/nix-tools.nix subArgs)
    ++ (import ./packages/ai.nix subArgs)
    ++ (lib.optionals pkgs.stdenv.isLinux (import ./packages/linux.nix subArgs))
    ++ (lib.optionals pkgs.stdenv.isDarwin (import ./packages/mac.nix subArgs));
}
