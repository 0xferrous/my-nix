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
  makeFontsConf,
  dpkg,
  autoPatchelfHook,
  bubblewrap,
  makeWrapper,
  perl,
  wrapGAppsHook3,
  gsettings-desktop-schemas,
  # Runtime deps from the deb's `Depends` plus Electron's usual extras and
  # the libs for the bundled native node modules.
  alsa-lib,
  atk,
  cairo,
  cups,
  coreutils,
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
  recursive,
  nerd-fonts,
  udev,
  xz,
}:

let
  source = import ./codex-desktop-source.nix;
  fontsConf = makeFontsConf {
    fontDirectories = [
      recursive
      nerd-fonts.recursive-mono
    ];
  };
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
    perl
    wrapGAppsHook3
  ];

  buildInputs = [
    gsettings-desktop-schemas
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

  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" unpacked
    sourceRoot=unpacked
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib" "$out/libexec" "$out/bin" "$out/share/applications" "$out/share/pixmaps"
    cp -a usr/lib/chatgpt "$out/lib/"
    cp usr/share/applications/chatgpt.desktop "$out/share/applications/"
    cp usr/share/pixmaps/chatgpt.png "$out/share/pixmaps/"

    # Drop musl-only native prebuilds (Alpine-style builds) before patching:
    # they are never loaded on glibc systems and auto-patchelf cannot satisfy
    # their libc.musl dependency from the nix store.
    find "$out/lib/chatgpt" -type d -name '*-musl' -prune -exec rm -rf {} +
    find "$out/lib/chatgpt" -type f -name '*.musl.node' -delete

    # GPU-less VMs need workarounds in the bundled JavaScript. Sentry does not
    # handle getGPUInfo() rejecting when GPU access is disabled, and the native
    # git repository watcher crashes this Electron build with SIGILL. The app
    # also preserves the Nix store's read-only modes when copying bundled
    # plugins, so use cp without preserving modes. Keep replacements the same
    # length so the asar's file offsets stay valid.
    perl -0777pi -e '
      $sentry = s/\Qez(),uz(),Nz()\E/ez(),     Nz()/g;
      $newWatcher = s/\Qlet h=d.start();f.startPromise=h\E/let h=void 0   ;f.startPromise=h/g;
      $existingWatcher = s/\Qr.watcher.start()\E/Promise.resolve()/g;
      $pluginCopy = s/\Qawait y.default.cp(e,t,{recursive:!0,verbatimSymlinks:!0});return\E/await wne(`cp`,[`-r`,`--no-preserve=mode`,`--`,e,t]);return      /g;
      END {
        die "unexpected Sentry GPU integration count: $sentry\n" unless $sentry == 1;
        die "unexpected new git watcher start count: $newWatcher\n" unless $newWatcher == 1;
        die "unexpected existing git watcher start count: $existingWatcher\n" unless $existingWatcher == 1;
        die "unexpected bundled plugin copy count: $pluginCopy\n" unless $pluginCopy == 1;
      }
    ' "$out/lib/chatgpt/resources/app.asar"

    makeWrapper "$out/lib/chatgpt/ChatGPT" "$out/libexec/codex-desktop" \
      --prefix XDG_DATA_DIRS : "$out/share" \
      --prefix PATH : "${lib.makeBinPath [ bubblewrap ]}" \
      --add-flags "--no-sandbox"

    # Electron otherwise prefers X11 even when only a Wayland socket is
    # available, as with waypipe's default server mode. Keep X11 working when
    # no Wayland display is present.
    cat > "$out/bin/chatgpt" <<'EOF'
    #!@shell@
    set -e

    extra_args=()

    # Chromium repeatedly restarts its GPU subprocess when running in an agent
    # VM without a DRM device. Disable GPU access there; the bundled Sentry
    # integration is patched above to tolerate this mode.
    if [[ ! -d /dev/dri ]]; then
      extra_args+=(--disable-gpu)
    fi

    # Older launches may have copied Nix-store modes into the plugin cache.
    # Make those stale directories removable before the app reconciles them.
    bundled_marketplaces="''${CODEX_HOME:-$HOME/.codex}/.tmp/bundled-marketplaces"
    if [[ -d "$bundled_marketplaces" ]]; then
      @chmod@ -R u+w -- "$bundled_marketplaces" || true
    fi

    # Some remote shells do not inherit WAYLAND_DISPLAY even though waypipe
    # has created a socket. Find that socket before Electron falls back to X11.
    runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$EUID}"
    if [[ -z "''${WAYLAND_DISPLAY:-}" ]]; then
      for socket in "$runtime_dir"/wayland-*; do
        if [[ -S "$socket" ]]; then
          export XDG_RUNTIME_DIR="$runtime_dir"
          export WAYLAND_DISPLAY="''${socket##*/}"
          break
        fi
      done
    fi

    if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
      extra_args+=(--ozone-platform=wayland)
    fi

    if [[ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" && -S "''${XDG_RUNTIME_DIR:-}/bus" ]]; then
      export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    fi

    exec @launcher@ "''${extra_args[@]}" "$@"
    EOF
    substituteInPlace "$out/bin/chatgpt" \
      --replace-fail '@shell@' '${stdenv.shell}' \
      --replace-fail '@chmod@' '${coreutils}/bin/chmod' \
      --replace-fail '@launcher@' "$out/libexec/codex-desktop"
    chmod +x "$out/bin/chatgpt"

    runHook postInstall
  '';

  preFixup = ''
    wrapProgram "$out/libexec/codex-desktop" \
      --prefix PATH : '${lib.makeBinPath [ coreutils ]}' \
      --set FONTCONFIG_FILE '${fontsConf}' \
      "''${gappsWrapperArgs[@]}"
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
