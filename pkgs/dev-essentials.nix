{
  pkgs,
  AIPackages,
}:
pkgs.symlinkJoin {
  name = "dev-essentials";
  paths = import ../config/shared/packages/dev-essentials.nix {
    inherit pkgs AIPackages;
  };
}
