{
  pkgs,
  lib ? pkgs.lib,
}:

let
  version = "0.7.2";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "opensrc";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/vercel-labs/opensrc/releases/download/v${version}/opensrc-linux-x64";
    hash = "sha256-YGTm6ksC/Kix6g2qPAq4y5xZcvjYODxhdMahfWzgx9A=";
  };

  dontUnpack = true;
  installPhase = ''
    install -Dm755 "$src" "$out/bin/opensrc"
  '';

  meta = with lib; {
    description = "Fetch and cache source code for packages and repos";
    homepage = "https://github.com/vercel-labs/opensrc";
    license = licenses.asl20;
    mainProgram = "opensrc";
    platforms = [ "x86_64-linux" ];
  };
}
