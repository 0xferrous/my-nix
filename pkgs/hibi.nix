# Hibi (https://github.com/schmayterling/hibi): local-first desktop editor for
# Markdown notes and documents. Upstream publishes Linux AppImages, so use an
# official release artifact instead of reproducing its Electron build.
# `just update-package hibi` (or the update packages workflow) bumps the
# version, the host hash, and the other architecture's hash.
{
  appimageTools,
  fetchurl,
  lib,
  nix-update,
  stdenv,
  writeShellScript,
}:

let
  pname = "hibi";
  version = "0.2.6";

  platform =
    {
      "x86_64-linux" = {
        asset = "x64";
        hash = "sha256-v4xtmI/ZLZI+EQBS5AJpGB2LYCEF7uDrwTgrXEivWFk=";
      };
      "aarch64-linux" = {
        asset = "arm64";
        hash = "sha256-LtJ9NuI2Ks2D2U550TCPnDMzJFJTmHgG2KA3dAjTnko=";
      };
    }
    .${stdenv.hostPlatform.system} or (throw "hibi is unsupported on ${stdenv.hostPlatform.system}");

  src = fetchurl {
    url = "https://github.com/schmayterling/hibi/releases/download/v${version}/hibi-${version}-linux-${platform.asset}.AppImage";
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

  # Keep the app from treating its immutable Nix store path as a portable
  # AppImage or trying to update itself in place.
  profile = ''
    unset APPIMAGE
  '';

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/com.ryanaque.hibi.desktop \
      $out/share/applications/com.ryanaque.hibi.desktop
    substituteInPlace $out/share/applications/com.ryanaque.hibi.desktop \
      --replace-fail "Exec=AppRun --no-sandbox %U" "Exec=hibi --no-sandbox %U"

    install -Dm444 ${appimageContents}/hibi.png \
      $out/share/icons/hicolor/512x512/apps/hibi.png
    install -Dm444 ${appimageContents}/usr/share/mime/packages/hibi.xml \
      $out/share/mime/packages/hibi.xml
  '';

  meta = {
    description = "Local-first desktop editor for Markdown notes and documents";
    homepage = "https://github.com/schmayterling/hibi";
    changelog = "https://github.com/schmayterling/hibi/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = [ ];
    mainProgram = "hibi";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
