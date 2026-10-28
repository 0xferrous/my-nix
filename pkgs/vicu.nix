# Vicu — a personal task manager desktop app powered by Vikunja.
#
# Not in nixpkgs. Upstream publishes Linux AppImages (x86_64 + arm64) on
# GitHub releases and does not ship a source build we can reuse, so wrap the
# release AppImage in an FHS environment (same approach as pkgs/bb/appimage.nix)
# and install the bundled desktop entry and icon. `just update-package vicu`
# bumps the version and both architecture hashes.
{
  appimageTools,
  fetchurl,
  lib,
  nix-update,
  stdenv,
  writeShellScript,
}:

let
  pname = "vicu";
  version = "2.0.1";
  releaseBase = "https://github.com/rendyhd/Vicu/releases/download/v${version}";

  platform =
    {
      "x86_64-linux" = {
        asset = "x86_64";
        hash = "sha256-MI9DvzdZJrHeUCMLCbjJULcjryUFvK3EKL9OoOPeHgo=";
      };
      "aarch64-linux" = {
        asset = "arm64";
        hash = "sha256-fjZaV5ypOqNquqR8jTrXNMdSBhm7onbDgMWN+DDhPWE=";
      };
    }
    .${stdenv.hostPlatform.system} or (throw "vicu is unsupported on ${stdenv.hostPlatform.system}");

  src = fetchurl {
    url = "${releaseBase}/Vicu-${version}-${platform.asset}.AppImage";
    inherit (platform) hash;
  };

  appimageContents = appimageTools.extract { inherit pname version src; };

  # nix-update derives the version from the GitHub release; the arm64 hash
  # lives in this same file, so refresh it from the aarch64 package set too.
  updateScript = writeShellScript "update-${pname}" ''
    set -euo pipefail
    attr="''${UPDATE_NIX_ATTR_PATH:-${pname}}"
    ${lib.getExe nix-update} --flake "$attr"
    ${stdenv.shell} ${./update-arch-hash.sh} "$attr" aarch64-linux src
  '';
in
appimageTools.wrapAppImage {
  inherit pname version;

  contents = appimageContents;

  # Expose the release artifact the way appimageTools.wrapType2 does: nix-update
  # needs pkg.src to find the version and rewrite the host-system hash.
  passthru = {
    inherit src;
    updateScript = updateScript;
  };

  # The FHS wrapper bypasses the AppImage runtime, so drop APPIMAGE lest the
  # app treat itself as a portable build.
  profile = ''
    unset APPIMAGE
  '';

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/com.rendyhd.vicu.desktop \
      $out/share/applications/com.rendyhd.vicu.desktop
    substituteInPlace $out/share/applications/com.rendyhd.vicu.desktop \
      --replace-fail "Exec=AppRun" "Exec=vicu"
    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/512x512/apps/vicu.png \
      $out/share/icons/hicolor/512x512/apps/vicu.png
  '';

  meta = {
    description = "Personal task manager for your desktop, powered by Vikunja";
    longDescription = ''
      Vicu is a keyboard-driven desktop task manager that talks to a Vikunja
      server. It trades the official frontend's boards and team features for
      fast capture (Quick Entry and Quick View global hotkeys), an
      Inbox/Today/Upcoming/Anytime/Logbook flow, natural-language task input,
      and Obsidian/browser linking.
    '';
    homepage = "https://github.com/rendyhd/Vicu";
    downloadPage = "https://github.com/rendyhd/Vicu/releases";
    changelog = "https://github.com/rendyhd/Vicu/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [
      binaryNativeCode
      binaryBytecode
    ];
    maintainers = [ ];
    mainProgram = "vicu";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
