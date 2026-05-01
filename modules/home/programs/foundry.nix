{
  lib,
  pkgs,
  myNixInputs,
  ...
}:
let
  foundry-stable = myNixInputs.foundry-stable.defaultPackage.${pkgs.system};
  foundry-nightly = myNixInputs.foundry-nightly.defaultPackage.${pkgs.system};
  components = [
    "cast"
    "forge"
    "anvil"
    "chisel"
  ];
  foundry-mixed = pkgs.symlinkJoin {
    name = "foundry-mixed";
    paths = [ foundry-stable ];
    postBuild = ''
      ${lib.concatMapStringsSep "\n" (x: "ln -s ${foundry-nightly}/bin/${x} $out/bin/n${x}") components}
    '';
  };
in
{
  home.packages = [ foundry-mixed ];
}
