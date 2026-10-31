{
  pkgs,
  lib ? pkgs.lib,
  nix-update-script,
}:

let
  version = "0.7.3";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "opensrc";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/vercel-labs/opensrc/releases/download/v${version}/opensrc-linux-x64";
    hash = "sha256-L0ciacLAXlbQmMlnvpp476nC0jOJspPuPeyULW9iyII=";
  };

  dontUnpack = true;

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

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
