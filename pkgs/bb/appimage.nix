{
  appimageTools,
  codex,
  fetchurl,
  git,
  lib,
  nodejs_22,
  pi,
  runCommand,
  stdenv,
  writeShellScript,
  providerPkgs ? [
    codex
    pi
  ],
}:

let
  pname = "bb";
  version = "0.42.1";
  nodejs = nodejs_22;
  providerPath = lib.makeBinPath providerPkgs;
  packageRoot = "${patchedContents}/resources/app.asar.unpacked/node_modules/bb-app";
  appPath = "${packageRoot}/dist/bb-app.js";
  cliPath = "${packageRoot}/dist/bb.js";

  src = fetchurl {
    url = "https://github.com/get-bb/bb/releases/download/desktop-v${version}/bb-${version}-x86_64.AppImage";
    hash = "sha256-spFl9c0vBv7rpRw2yoa5YAa/xsSFIZAzZ8AErmPIaXY=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };

  patchedContents = runCommand "${pname}-${version}-contents" { } ''
    cp -r ${appimageContents} $out
    chmod -R u+w $out
    for entry in \
      $out/resources/app.asar.unpacked/node_modules/bb-app/dist/bb-app.js \
      $out/resources/app.asar.unpacked/node_modules/bb-app/dist/bb-host-daemon.js \
      $out/resources/app.asar.unpacked/node_modules/bb-app/dist/bb-server.js \
      $out/resources/app.asar.unpacked/node_modules/bb-app/dist/bb.js \
      $out/resources/app.asar.unpacked/node_modules/bb-app/host-daemon/dist/bb; do
      substituteInPlace "$entry" \
        --replace-fail '#!/usr/bin/env node' '#!${nodejs}/bin/node'
    done
  '';

  wrapped = appimageTools.wrapAppImage {
    inherit pname version;
    contents = patchedContents;
    extraPkgs =
      pkgs:
      [
        git
        nodejs
      ]
      ++ providerPkgs;
    profile = ''
      unset APPIMAGE
    '';
    extraInstallCommands = ''
      install -Dm444 ${appimageContents}/bb.desktop $out/share/applications/bb-desktop.desktop
      substituteInPlace $out/share/applications/bb-desktop.desktop \
        --replace-fail "Exec=AppRun" "Exec=bb-desktop" \
        --replace-fail "Icon=bb" "Icon=bb-desktop"
      for icon in ${appimageContents}/usr/share/icons/hicolor/*/apps/bb.png; do
        size=$(basename "$(dirname "$(dirname "$icon")")")
        install -Dm444 "$icon" "$out/share/icons/hicolor/$size/apps/bb-desktop.png"
      done
    '';
  };

  desktopLauncher = writeShellScript "bb-desktop" ''
    set -euo pipefail

    if [ -n "''${BB_DESKTOP_REMOTE_URL:-}" ]; then
      remote_target_file="''${XDG_CONFIG_HOME:-$HOME/.config}/bb/server-target.json"
      mkdir -p "$(dirname "$remote_target_file")"
      ${nodejs}/bin/node - "$remote_target_file" <<'NODE'
    const fs = require("node:fs");
    const path = require("node:path");

    const rawUrl = (process.env.BB_DESKTOP_REMOTE_URL ?? "").trim();
    let parsedUrl;
    try {
      parsedUrl = new URL(rawUrl);
    } catch {
      process.stderr.write("BB_DESKTOP_REMOTE_URL must be a valid http(s) URL\n");
      process.exit(2);
    }
    if (parsedUrl.protocol !== "http:" && parsedUrl.protocol !== "https:") {
      process.stderr.write("BB_DESKTOP_REMOTE_URL must be a valid http(s) URL\n");
      process.exit(2);
    }
    parsedUrl.hash = "";
    const targetFile = process.argv[2];
    fs.mkdirSync(path.dirname(targetFile), { recursive: true });
    fs.writeFileSync(
      targetFile,
      `''${JSON.stringify({
        connectServer: null,
        customServerUrl: parsedUrl.toString().replace(/\/$/u, ""),
        target: "custom",
      })}\n`,
      "utf8",
    );
NODE
    fi

    flags=(--no-sandbox)
    if [ ! -e /dev/dri ]; then
      flags+=(--use-gl=angle --use-angle=swiftshader)
    fi
    if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
      flags+=(--ozone-platform=wayland)
    fi

    export BB_APP_SURFACE=desktop

    case "''${SHELL:-}" in
      */nu|*/nushell)
        export BB_NIX_ORIGINAL_SHELL="$SHELL"
        export SHELL=/bin/bash
        ;;
    esac

    export PATH="${providerPath}:''${PATH:-/run/current-system/sw/bin:/usr/bin:/bin}"

    if [ -z "''${BB_CODEX_BRIDGE_APP_SERVER_COMMAND:-}" ]; then
      if codex_command=$(command -v codex 2>/dev/null); then
        export BB_CODEX_BRIDGE_APP_SERVER_COMMAND="$codex_command"
      fi
    fi

    if [ -z "''${BB_PI_BRIDGE_COMMAND:-}" ]; then
      if pi_command=$(command -v pi 2>/dev/null); then
        export BB_PI_BRIDGE_COMMAND="$pi_command"
      fi
    fi

    exec ${wrapped}/bin/${pname} "''${flags[@]}" "$@"
  '';

  cliLauncher = writeShellScript "bb" ''
    set -euo pipefail

    export PATH="${providerPath}:''${PATH:-/run/current-system/sw/bin:/usr/bin:/bin}"
    exec ${cliPath} "$@"
  '';

  appLauncher = writeShellScript "bb-app" ''
    set -euo pipefail

    case "''${SHELL:-}" in
      */nu|*/nushell)
        export BB_NIX_ORIGINAL_SHELL="$SHELL"
        export SHELL=/bin/bash
        ;;
    esac

    export PATH="${providerPath}:''${PATH:-/run/current-system/sw/bin:/usr/bin:/bin}"
    export BB_APP_SURFACE=web
    export ELECTRON_RUN_AS_NODE=1
    exec ${wrapped}/bin/${pname} ${appPath} "$@"
  '';
in
stdenv.mkDerivation {
  inherit pname version;
  dontUnpack = true;
  installPhase = ''
    install -d $out/bin
    cp -r ${wrapped}/. $out/
    chmod -R u+w $out
    install -m 755 ${desktopLauncher} $out/bin/bb-desktop
    install -m 755 ${cliLauncher} $out/bin/bb
    install -m 755 ${appLauncher} $out/bin/bb-app
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x $out/bin/bb-desktop
    test -x $out/bin/bb
    test -x $out/bin/bb-app
    ${stdenv.shell} -n $out/bin/bb-desktop
    ${stdenv.shell} -n $out/bin/bb
    ${stdenv.shell} -n $out/bin/bb-app
    runHook postInstallCheck
  '';
  passthru.category = "AI Coding Agents";
  meta = {
    description = "bb desktop app with deterministic Nix provider launch";
    homepage = "https://getbb.app";
    changelog = "https://github.com/get-bb/bb/releases/tag/desktop-v${version}";
    downloadPage = "https://github.com/get-bb/bb/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [
      binaryNativeCode
      binaryBytecode
    ];
    maintainers = [ ];
    mainProgram = "bb-desktop";
    platforms = [ "x86_64-linux" ];
  };
}
