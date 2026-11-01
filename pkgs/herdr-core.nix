{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  nushell,
  writeShellScript,
}:
let
  pname = "herdr-core";
  version = "0.1.16";
  release =
    {
      x86_64-linux = {
        url = "https://releases.herdr.dev/core/${version}/herdr-core-linux-x86_64.tar.gz";
        hash = "sha256-WNaGEXbcb+kFtYiA1b/weplZvmE6mOXWa0WDsEts+kU=";
      };
      aarch64-linux = {
        url = "https://releases.herdr.dev/core/${version}/herdr-core-linux-aarch64.tar.gz";
        hash = "sha256-tlcxN9cLr/JPs0bJV6mHmva9xMZBGIzfnkensqZ3vJI=";
      };
    }
    .${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  inherit pname version;
  src = fetchurl release;
  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -d $out/libexec/${pname} $out/bin
    tar -xzf $src -C $out/libexec/${pname}
    chmod 755 $out/libexec/${pname}/herdr-core
    makeWrapper $out/libexec/${pname}/herdr-core $out/bin/herdr-core \
      --set SHELL ${nushell}/bin/nu
    ln -s herdr-core $out/bin/hc
    runHook postInstall
  '';

  # The release manifest carries the version and both hashes that nix-update
  # cannot derive on its own; herdr-update.sh bumps the pin from it.
  passthru.updateScript = writeShellScript "update-${pname}" ''
    set -euo pipefail
    ${stdenv.shell} ${./herdr-update.sh} "''${UPDATE_NIX_ATTR_PATH:-${pname}}"
  '';

  meta = {
    description = "Persistent terminal and agent session manager for Herdr";
    homepage = "https://github.com/herdrdev/herdr-core";
    license = lib.licenses.asl20;
    mainProgram = "herdr-core";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
