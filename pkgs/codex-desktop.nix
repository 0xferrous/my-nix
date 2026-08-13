# The ChatGPT desktop app for Linux (a.k.a. the Codex desktop app), in
# preview.
#
# Not packaged upstream: nixpkgs only has the macOS build (`chatgpt`),
# served from a versioned `sidekick` URL. OpenAI publishes the Linux builds
# only as .deb/.rpm under a moving `codex-app-prod/.../latest/` URL, so this
# is a fixed-output derivation over the amd64 deb, pinned via
# ./codex-desktop-source.nix (bump with ./update.sh).
#
# The app is a closed-source Electron bundle that ships its own Chromium
# runtime, the open-source Apache-2.0 `codex` CLI, and native node modules
# (node-hid, serialport, better-sqlite3) under resources/app.asar.unpacked.
# autoPatchelfHook rewrites RPATHs against the nixpkgs libs below; the
# chrome-sandbox setuid helper cannot be installed from the store, so the
# launcher passes --no-sandbox (same tradeoff as most Electron packages).
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  gsettings-desktop-schemas,
  # Runtime deps from the deb's `Depends` plus Electron's usual extras and
  # the libs for the bundled native node modules.
  alsa-lib,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  graphite2,
  gtk3,
  libX11,
  libdrm,
  libglvnd,
  libnotify,
  libpulseaudio,
  libusb1,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxshmfence,
  libxxf86vm,
  mesa,
  nspr,
  nss,
  openssl_3,
  pango,
  qt5,
  qt6,
  udev,
  xz,
}:

let
  source = import ./codex-desktop-source.nix;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "codex-desktop";
  inherit (source) version;

  src = fetchurl {
    inherit (source.src) url hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    graphite2
    gtk3
    libX11
    libdrm
    libglvnd
    libnotify
    libpulseaudio
    libusb1
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    libxrender
    libxshmfence
    libxxf86vm
    mesa
    nspr
    nss
    openssl_3
    pango
    qt5.qtbase.out
    qt6.qtbase.out
    stdenv.cc.cc.lib
    udev
    xz
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" unpacked
    sourceRoot=unpacked
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib" "$out/bin" "$out/share/applications" "$out/share/pixmaps"
    cp -a usr/lib/chatgpt "$out/lib/"
    cp usr/share/applications/chatgpt.desktop "$out/share/applications/"
    cp usr/share/pixmaps/chatgpt.png "$out/share/pixmaps/"

    # Drop musl-only native prebuilds (Alpine-style builds) before patching:
    # they are never loaded on glibc systems and auto-patchelf cannot satisfy
    # their libc.musl dependency from the nix store.
    find "$out/lib/chatgpt" -type d -name '*-musl' -prune -exec rm -rf {} +
    find "$out/lib/chatgpt" -type f -name '*.musl.node' -delete

    makeWrapper "$out/lib/chatgpt/ChatGPT" "$out/bin/chatgpt" \
      --prefix XDG_DATA_DIRS : "${gsettings-desktop-schemas}/share/gsettings-schemas:$out/share" \
      --add-flags "--no-sandbox"

    runHook postInstall
  '';

  meta = {
    description = "ChatGPT desktop app for Linux (bundles the Codex agent), preview build";
    homepage = "https://developers.openai.com/codex/app";
    changelog = "https://help.openai.com/en/articles/9703738-macos-app-release-notes";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = lib.platforms.linux;
    mainProgram = "chatgpt";
  };
})
