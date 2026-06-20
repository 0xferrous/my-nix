{ config, lib, ... }:
let
  cfg = config.fr.public;
  binaryCacheKeys = {
    "https://0xferrous.cachix.org" =
      "0xferrous.cachix.org-1:p38oLu+8I+EwBW6NCl+ffI8qn+WOtUeRzES/dYNuSUE=";
    "https://numtide.cachix.org" = "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=";
    "https://cache.numtide.com" = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
  };
  binaryCaches = lib.attrNames binaryCacheKeys;
in
{
  config = lib.mkIf cfg.enable {
    nix.settings = {
      substituters = binaryCaches;
      trusted-public-keys = lib.attrValues binaryCacheKeys;
      trusted-substituters = binaryCaches;
    };
  };
}
