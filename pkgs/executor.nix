{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  nix-update-script,
}:

stdenvNoCC.mkDerivation rec {
  pname = "executor";
  version = "1.6.10";

  src = fetchurl {
    url = "https://github.com/UsefulSoftwareCo/executor/releases/download/v${version}/executor-linux-x64.tar.gz";
    hash = "sha256-H1XzWzMImgGqJ/oRuR9rvZJyiEAfNWdpC/epiRDDiC8=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  dontStrip = true;

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  installPhase = ''
    runHook preInstall
    install -Dm755 executor $out/bin/executor
    install -Dm644 mcp-app.html $out/bin/mcp-app.html
    install -Dm644 emscripten-module.wasm $out/bin/emscripten-module.wasm
    install -Dm644 onepassword-core_bg.wasm $out/bin/onepassword-core_bg.wasm
    install -Dm755 libsql.node $out/bin/libsql.node
    install -Dm755 keyring.node $out/bin/keyring.node
    install -Dm755 workerd $out/bin/workerd
    cp -R worker-bundler $out/bin/
    runHook postInstall
  '';

  meta = {
    description = "Shared integration layer for AI agents";
    homepage = "https://executor.sh";
    license = lib.licenses.mit;
    mainProgram = "executor";
    platforms = [ "x86_64-linux" ];
  };
}
