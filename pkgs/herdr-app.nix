{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  libxcb,
  libxkbcommon,
  wayland,
  vulkan-loader,
  herdr-core,
}:
let
  pname = "herdr-app";
  version = "0.1.9";
  release =
    {
      x86_64-linux = {
        url = "https://releases.herdr.dev/app/${version}/herdr-app-linux-x86_64.tar.gz";
        hash = "sha256-2m97QPbEFsW03vjbz4t2Z30Cvk9LRdBqTWWHZoUOC0U=";
      };
      aarch64-linux = {
        url = "https://releases.herdr.dev/app/${version}/herdr-app-linux-aarch64.tar.gz";
        hash = "sha256-M235p/7CWbFKDfYwWLRfniLGFzBdEjrj+XE0hq8Ge14=";
      };
    }
    .${stdenv.hostPlatform.system};
  runtimeLibs = [
    stdenv.cc.cc.lib
    libxcb
    libxkbcommon
    wayland
    vulkan-loader
  ];
in
stdenv.mkDerivation {
  inherit pname version;
  src = fetchurl release;
  sourceRoot = "herdr-app";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = runtimeLibs;

  installPhase = ''
    runHook preInstall
    install -Dm755 herdr-app $out/libexec/herdr-app/herdr-app
    install -Dm644 herdr-app.svg $out/share/icons/hicolor/scalable/apps/herdr-app.svg
    install -Dm644 LICENSE $out/share/licenses/${pname}/LICENSE
    install -Dm644 THIRD-PARTY-NOTICES $out/share/doc/${pname}/THIRD-PARTY-NOTICES

    makeWrapper $out/libexec/herdr-app/herdr-app $out/bin/herdr-app \
      --prefix PATH : ${lib.makeBinPath [ herdr-core ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}

    install -Dm644 /dev/stdin $out/share/applications/herdr-app.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Herdr
    Comment=Terminals and coding agents that keep running
    Exec=herdr-app
    Icon=herdr-app
    Terminal=false
    Categories=Development;
    StartupWMClass=herdr-app
    EOF
    runHook postInstall
  '';

  meta = {
    description = "Desktop app for terminals and coding agents";
    homepage = "https://github.com/herdrdev/herdr-app";
    license = lib.licenses.asl20;
    mainProgram = "herdr-app";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
