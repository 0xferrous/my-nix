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
          msbHash = "sha256-AaOm1u63FuxyNf5RAj5WLxVKXZuuQ1eGZYC77GCn7RQ=";
          libkrunfwHash = "sha256-K3rAV1cMe4PqQY3biOW28XZ0J8O/NBg3zEcSP9yD4WE=";
        };
        "aarch64-linux" = {
          arch = "aarch64";
          msbHash = "sha256-cp/cOUzGCdspkBuVTc39WaPb8cUmmVARm5HA1s7GoWw=";
          libkrunfwHash = "sha256-WWORabdZFnqDYnRrBrjihdlBSHxplb0R6dnkarvY8ic=";
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
    version = "0.8.1";

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
