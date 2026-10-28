# Lightpanda (https://github.com/lightpanda-io/browser): headless browser
# written in Zig (V8 embedded), built for AI agents and automation. It is not in
# nixpkgs, and upstream's own flake builds it from source (Zig 0.17 plus a
# prebuilt V8 static archive, Rust FFI, snapshot creation), which is far
# heavier than we need for a CLI. Use an official release binary instead.
#
# The Linux release binaries carry a `/lib64/ld-linux-*.so.2` interpreter and
# link against the host glibc, so autoPatchelf rewrites the interpreter for the
# Nix store. `just update-package lightpanda` bumps the version and both
# architecture hashes; each hash is the SHA-256 of the plain release asset.
{
  autoPatchelfHook,
  fetchurl,
  lib,
  nix-update,
  stdenv,
  writeShellScript,
}:

stdenv.mkDerivation (
  finalAttrs:
  let
    pname = "lightpanda";

    platform =
      {
        "x86_64-linux" = {
          asset = "x86_64-linux";
          hash = "sha256-rn0B0mHvueSA4YzjQkUzMyiDhjvPcLEqQyG1cz834Z4=";
        };
        "aarch64-linux" = {
          asset = "aarch64-linux";
          hash = "sha256-rFRt/EPFM0MNqSt1qzbyop2n1jJNXTi69gbvLg2Ek0U=";
        };
      }
      .${stdenv.hostPlatform.system}
        or (throw "${pname} has no prebuilt binary for ${stdenv.hostPlatform.system}");

    src = fetchurl {
      url = "https://github.com/lightpanda-io/browser/releases/download/${finalAttrs.version}/lightpanda-${platform.asset}";
      inherit (platform) hash;
    };

    # nix-update derives the version from the GitHub release; refresh the arm64
    # hash from the aarch64 package set in the same run.
    updateScript = writeShellScript "update-${pname}" ''
      set -euo pipefail
      attr="''${UPDATE_NIX_ATTR_PATH:-${pname}}"
      ${lib.getExe nix-update} --flake "$attr"
      ${stdenv.shell} ${./update-arch-hash.sh} "$attr" aarch64-linux src
    '';
  in
  {
    inherit pname;
    version = "1.0.2";
    inherit src;

    nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];
    buildInputs = lib.optionals stdenv.isLinux [
      stdenv.cc.cc.lib
      stdenv.cc.libc
    ];

    # The source is the bare release binary, not an archive.
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/lightpanda
      runHook postInstall
    '';

    passthru.updateScript = updateScript;

    meta = {
      description = "Headless browser built for AI agents and automation";
      homepage = "https://lightpanda.io";
      changelog = "https://github.com/lightpanda-io/browser/releases/tag/${finalAttrs.version}";
      license = lib.licenses.agpl3Only;
      mainProgram = "lightpanda";
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  }
)
