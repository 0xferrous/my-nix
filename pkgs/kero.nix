{
  lib,
  stdenv,
  buildGoModule,
  go_1_27,
  fetchurl,
  makeWrapper,
  source,
  alsa-lib,
  cairo,
  fontconfig,
  gdk-pixbuf,
  glib,
  gtk3,
  gtk-layer-shell,
  harfbuzz,
  libayatana-appindicator,
  libepoxy,
  libGL,
  libpulseaudio,
  libsecret,
  libsoup_3,
  pango,
  sqlite,
  webkitgtk_4_1,
  libx11,
  libxtst,
}:
let
  version = (builtins.fromJSON (builtins.readFile "${source}/mygo.json")).version;
  ghosttyVt = {
    x86_64-linux = {
      name = "libghostty-vt.so";
      url = "https://github.com/egoist/mygo/releases/download/libghostty-vt-befcdfd2c3a1/libghostty-vt-linux-amd64.so";
      hash = "sha256-nc2K8N5nd4pWH0NstnOp+xc4vo+gCEna1JYGuu0eV9c=";
    };
    aarch64-linux = {
      name = "libghostty-vt.so";
      url = "https://github.com/egoist/mygo/releases/download/libghostty-vt-befcdfd2c3a1/libghostty-vt-linux-arm64.so";
      hash = "sha256-+xY/jxIyBpVnUfHE8DA7QImVE7fcFxqKuNhbp81UG8A=";
    };
  };
  system = stdenv.hostPlatform.system;
  vt = ghosttyVt.${system};
  vtLib = fetchurl {
    inherit (vt) url hash;
  };
  runtimeLibs = [
    alsa-lib
    cairo
    fontconfig
    gdk-pixbuf
    glib
    gtk3
    gtk-layer-shell
    harfbuzz
    libayatana-appindicator
    libepoxy
    libGL
    libpulseaudio
    libsecret
    libsoup_3
    pango
    sqlite
    webkitgtk_4_1
    libx11
    libxtst
  ];
in
(buildGoModule.override { go = go_1_27; }) {
  pname = "kero";
  inherit version;
  src = source;
  patches = [ ./kero-runtime-libs.patch ];
  vendorHash = "sha256-THQzo0XaNZKZla8XypjOnXkfeJNpoIY0EKdlN/OjzLI=";
  ldflags = [
    "-X"
    "github.com/egoist/mygo.production=1"
  ];
  env.CGO_ENABLED = "0";

  nativeBuildInputs = [ makeWrapper ];

  # The pinned nixpkgs Go 1.27 toolchain is currently a release candidate;
  # keep the released source's patch-level go directive compatible with it.
  postPatch = ''
    substituteInPlace go.mod --replace-fail 'go 1.27.3' 'go 1.27'
  '';

  postConfigure = ''
    substituteInPlace vendor/modules.txt --replace-fail 'go 1.27.3' 'go 1.27'
  '';

  # The tests render native UI and depend on fonts unavailable in the sandbox.
  doCheck = false;

  postInstall = ''
    mkdir -p $out/libexec/kero/fonts
    mv $out/bin/kero $out/libexec/kero/kero
    cp -r resources/fonts/. $out/libexec/kero/fonts/
    cp ${vtLib} $out/libexec/kero/${vt.name}

    install -Dm644 resources/icon.png \
      $out/share/icons/hicolor/1024x1024/apps/kero.png

    install -Dm644 /dev/stdin $out/share/applications/kero.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Kero
    Comment=A terminal for coding agents
    Exec=kero
    Icon=kero
    Terminal=false
    Categories=Development;TerminalEmulator;
    StartupWMClass=kero
    EOF

    makeWrapper $out/libexec/kero/kero $out/bin/kero \
      --set KERO_NIX_RUNTIME_LIBS 1 \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
  '';

  meta = {
    description = "A terminal for coding agents, with sessions that outlive the window";
    homepage = "https://github.com/egoist/kero";
    license = lib.licenses.mit;
    mainProgram = "kero";
    platforms = builtins.attrNames ghosttyVt;
  };
}
