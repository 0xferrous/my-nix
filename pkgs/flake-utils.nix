{
  pkgs,
  lib ? pkgs.lib,
}:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "flake-utils";
  version = "0.1.0";

  src = ./flake-utils.nu;

  dontUnpack = true;

  nativeBuildInputs = [
    pkgs.makeWrapper
    pkgs.nushell
  ];

  installPhase = ''
    install -Dm755 "$src" "$out/libexec/${pname}"
    patchShebangs "$out/libexec/${pname}"
    makeWrapper "$out/libexec/${pname}" "$out/bin/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pkgs.nix ]}
  '';

  meta = {
    description = "Synchronize selected flake input locks across local flakes";
    license = lib.licenses.mit;
    mainProgram = pname;
  };
}
