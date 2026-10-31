{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libcap_ng,
  nix-update,
  writeShellScript,
}:

stdenv.mkDerivation (
  finalAttrs:
  let
    releaseBase = "https://github.com/superradcompany/microsandbox/releases/download/v${finalAttrs.version}";

    platform =
      {
        "x86_64-linux" = {
          arch = "x86_64";
          msbHash = "sha256-AiMLDQzKtNpIfJYoLvBrw2amA/C5UgHpmc+eE98xdn4=";
          libkrunfwHash = "sha256-OFTvzT/mJVKPoAIH2XWG2XkNuMQ2u2iBpDmGYEM20Y4=";
        };
        "aarch64-linux" = {
          arch = "aarch64";
          msbHash = "sha256-zmuF1x1zFl2YJ0XTuFxCVgMVe4Ui9T8oeyBqT1At4tE=";
          libkrunfwHash = "sha256-LOxmK8AxNNQm8xKqnXK/vRnYdvbznTY5XLTTSGIZTU4=";
        };
      }
      .${stdenv.hostPlatform.system}
        or (throw "microsandbox is unsupported on ${stdenv.hostPlatform.system}");

    msb = fetchurl {
      url = "${releaseBase}/msb-linux-${platform.arch}";
      hash = platform.msbHash;
    };

    libkrunfw = fetchurl {
      url = "${releaseBase}/libkrunfw-linux-${platform.arch}.so";
      hash = platform.libkrunfwHash;
    };

    # nix-update derives the version from the GitHub release and needs pkg.src;
    # the arm64 copies of both artifacts live in this same file and are
    # refreshed separately from the aarch64 package set.
    updateScript = writeShellScript "update-microsandbox" ''
      set -euo pipefail
      attr="''${UPDATE_NIX_ATTR_PATH:-microsandbox}"
      ${lib.getExe nix-update} --flake "$attr"
      ${stdenv.shell} ${./update-arch-hash.sh} "$attr" x86_64-linux libkrunfw
      ${stdenv.shell} ${./update-arch-hash.sh} "$attr" aarch64-linux src
      ${stdenv.shell} ${./update-arch-hash.sh} "$attr" aarch64-linux libkrunfw
    '';
  in
  {
    pname = "microsandbox";
    version = "0.7.11";

    passthru = {
      src = msb;
      inherit libkrunfw;
      updateScript = updateScript;
    };

    dontUnpack = true;
    dontStrip = true;

    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [
      libcap_ng
      stdenv.cc.cc.lib
    ];

    installPhase = ''
      install -Dm755 ${msb} $out/bin/msb
      install -Dm755 ${libkrunfw} $out/lib/libkrunfw.so.5.6.1
      ln -s libkrunfw.so.5.6.1 $out/lib/libkrunfw.so.5
      ln -s libkrunfw.so.5.6.1 $out/lib/libkrunfw.so
    '';

    meta = {
      description = "Lightweight microVM sandboxes for Linux";
      homepage = "https://github.com/superradcompany/microsandbox";
      license = lib.licenses.asl20;
      mainProgram = "msb";
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
  }
)
