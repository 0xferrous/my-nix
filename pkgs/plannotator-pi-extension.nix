{
  bun,
  fetchFromGitHub,
  fetchzip,
  lib,
  stdenvNoCC,
  writableTmpDirAsHomeHook,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "plannotator-pi-extension";
  version = "0.24.2";

  # Upstream does not commit the generated browser bundles. The published Pi
  # package contains those assets, while the matching Git tag supplies bun.lock
  # for a reproducible dependency installation.
  src = fetchzip {
    url = "https://registry.npmjs.org/@plannotator/pi-extension/-/pi-extension-${finalAttrs.version}.tgz";
    hash = "sha256-S23An0ynpRS4n3k+2LoSFVbrreZyHImF5xx/OfUFOpw=";
  };

  dependencySrc = fetchFromGitHub {
    owner = "backnotprop";
    repo = "plannotator";
    tag = "v${finalAttrs.version}";
    hash = "sha256-QiHKiHePxCRwGAS0/jh5sq5eAJnpqMhY3hjFWzvcfuE=";
  };

  nodeModules = stdenvNoCC.mkDerivation {
    pname = "${finalAttrs.pname}-node_modules";
    inherit (finalAttrs) version;
    src = finalAttrs.dependencySrc;

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [
      bun
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;
    dontFixup = true;

    buildPhase = ''
      runHook preBuild

      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      # Pi supplies the peer API packages itself. Lifecycle scripts are skipped
      # because node-pty is only used by Plannotator's optional browser terminal;
      # plan, annotation, and code-review flows do not require the native addon.
      bun install \
        --filter @plannotator/pi-extension \
        --frozen-lockfile \
        --ignore-scripts \
        --no-progress \
        --omit peer \
        --production

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/apps/pi-extension
      cp -R node_modules $out/node_modules
      cp -R apps/pi-extension/node_modules $out/apps/pi-extension/node_modules

      runHook postInstall
    '';

    outputHash = "sha256-Qm0h7+f1uepI9thCqPC84EE+sQbkHRyDF+h24u4v9Fc=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    packageRoot=$out/share/pi-extensions/plannotator
    mkdir -p "$packageRoot/apps/pi-extension"
    cp -R . "$packageRoot/apps/pi-extension"
    cp -R ${finalAttrs.nodeModules}/node_modules "$packageRoot/node_modules"
    cp -R ${finalAttrs.nodeModules}/apps/pi-extension/node_modules \
      "$packageRoot/apps/pi-extension/node_modules"

    runHook postInstall
  '';

  meta = {
    description = "Interactive plan and code review extension for Pi";
    homepage = "https://github.com/backnotprop/plannotator";
    license = with lib.licenses; [
      asl20
      mit
    ];
    # The Bun fixed-output dependency tree is platform-specific.
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
