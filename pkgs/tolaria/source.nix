# Tolaria (https://github.com/refactoringhq/tolaria): desktop app for
# managing markdown knowledge bases (Tauri 2 + React/TypeScript).
#
# Not in nixpkgs and no upstream Nix build support; the official Linux
# distribution is the GitHub-release amd64 deb (pinned via
# ./source-lock.nix, bump with ./update.sh). The deb is a stock
# Tauri bundle whose `Depends` is just libwebkit2gtk-4.1 and libgtk-3: a
# single dynamically-linked binary in /usr/bin plus the bundled MCP server
# (a CommonJS Node bundle) and agent docs under /usr/lib/Tolaria.
# autoPatchelfHook rewrites the binary's RPATH against the nixpkgs libs
# below, and the deb layout (bin/../lib/Tolaria) is preserved so the
# binary's mcp-server path probing keeps working. The bundled MCP server
# spawns a system `node` binary at runtime for the external AI tooling flow
# (documented in upstream's README), so the wrapper puts nodejs on PATH; the
# app works without it.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  # Runtime deps from the deb's `Depends` plus the binary's remaining
  # DT_NEEDED entries (libsoup-3.0 is pulled in dynamically by WebKit).
  gtk3,
  webkitgtk_4_1,
  libsoup_3,
  gdk-pixbuf,
  glib,
  dbus,
  openssl_3,
  nodejs,
  # Needed by the tauri-plugin-deep-link setup hook, which shells out to
  # `update-desktop-database` (desktop-file-utils) and `xdg-mime`
  # (xdg-utils) to register the tolaria URL scheme handler.
  desktop-file-utils,
  xdg-utils,
}:

let
  source = import ./source-lock.nix;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "tolaria";
  inherit (source) version;

  src = fetchurl {
    inherit (source.src) url hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    wrapGAppsHook3
  ];

  buildInputs = [
    gdk-pixbuf
    glib
    gtk3
    webkitgtk_4_1
    libsoup_3
    dbus
    openssl_3
    stdenv.cc.cc.lib
  ];
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" unpacked
    sourceRoot=unpacked
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # Keep the deb layout (bin/../lib/Tolaria): the binary locates the
    # bundled mcp-server relative to the executable.
    mkdir -p "$out"
    cp -a usr/bin usr/lib usr/share "$out/"

    runHook postInstall
  '';

  preFixup = ''
    # node is needed at runtime by the bundled MCP server (external AI
    # tooling flow); desktop-file-utils' `update-desktop-database` and
    # xdg-utils' `xdg-mime` are invoked by the deep-link plugin's setup hook
    # to register the tolaria URL scheme handler. The rest of the GTK
    # environment comes from wrapGAppsHook3's gappsWrapperArgs.
    #
    # Note: wrapGAppsHook3 wraps in place, so the real binary is shipped as
    # `bin/.tolaria-wrapped` and the deep-link handler .desktop records that
    # raw path in `Exec`. Opening a `tolaria://` link via the OS launches the
    # raw binary without these PATH entries, so the deep-link scheme handler
    # (and the external AI/MCP flow) expects `nodejs`, `desktop-file-utils`
    # and `xdg-utils` on the user's PATH too, as on a standard desktop
    # distro. Launching the app normally (`.desktop` → `bin/tolaria`) uses
    # the wrapper and works out of the box.
    gappsWrapperArgs+=(
      --prefix PATH : '${
        lib.makeBinPath [
          nodejs
          desktop-file-utils
          xdg-utils
        ]
      }'
    )
  '';

  meta = {
    description = "Desktop app for managing markdown knowledge bases";
    homepage = "https://tolaria.md";
    changelog = "https://github.com/refactoringhq/tolaria/releases";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = lib.platforms.linux;
    mainProgram = "tolaria";
  };
})
