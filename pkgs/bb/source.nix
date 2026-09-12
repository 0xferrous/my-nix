{
  stdenv,
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_9,
  nodejs_22,
  python3,
  codex,
  git,
  pi,
  providerPkgs ? [
    codex
    pi
  ],
  pkg-config,

  electron,

  makeDesktopItem,
  gsettings-desktop-schemas,
  glib,
  gtk3,
  gtk4,
  libGL,
  sourceOverride ? null,
  pnpmDepsHashOverride ? null,
}:

let
  pname = "bb-source";
  version = "0.43.0";
  pnpm = pnpm_9;
  pnpmWorkspaces = [
    "bb-app..."
    "@bb/app..."
    "@bb/plugin-build..."
    "@bb/server..."
    "@bb/cli..."
    "@bb/host-daemon..."
    "@bb/plugin-interaction-contracts..."
    "@bb/plugin-api-map..."
    "@bb/desktop..."
    "./plugins/*..."
  ];
  pnpmInstallFlags = [
    "--config.supportedArchitectures.os=linux"
    "--config.supportedArchitectures.cpu=x64"
    "--config.supportedArchitectures.libc=glibc"
  ];
  # electron_41 is the wrapped Electron package; .dist/.headers/.version pass
  # through to the unwrapped runtime that electron-builder should package.
  electronDist = electron.dist;
  electronVersion = electron.version;
  nodejs = nodejs_22;
  runtimePath = lib.makeBinPath ([ git ] ++ providerPkgs);
  source =
    if sourceOverride == null then
      fetchFromGitHub {
        owner = "get-bb";
        repo = "bb";
        rev = "desktop-v${version}";
        hash = "sha256-8bZcqbZ24rkIVpqjv18TTJcb4AOoihpsqtCHrAhkR/Y=";
      }
    else
      sourceOverride;
  desktopItem = makeDesktopItem {
    name = "bb-desktop";
    desktopName = "bb";
    exec = "bb-desktop %U";
    terminal = false;
    icon = "bb-desktop";
    startupWMClass = "bb";
    comment = "Agentic IDE that builds itself";
    categories = [ "Development" ];
  };
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version;
  inherit pnpmInstallFlags pnpmWorkspaces;

  src = source;

  patches = [ ./patches/non-posix-shell-path-probe.patch ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm pnpmInstallFlags pnpmWorkspaces;
    fetcherVersion = 3;
    hash =
      if pnpmDepsHashOverride == null then
        "sha256-7Y/7NK7nuK18ehgwcRr0qZRd0DJNhuPgRIV6m6za4DQ="
      else
        pnpmDepsHashOverride;
  };

  nativeBuildInputs = [
    nodejs
    pkg-config
    pnpm
    pnpmConfigHook
    python3
  ];

  buildPhase = ''
    runHook preBuild

    export npm_config_nodedir=${electron.headers}
    export npm_config_runtime=electron
    export npm_config_target=${electronVersion}
    export npm_config_build_from_source=true

    better_sqlite_dir=$(echo node_modules/.pnpm/better-sqlite3@*/node_modules/better-sqlite3)
    pnpm --dir "$better_sqlite_dir" run install
    test -f "$better_sqlite_dir/build/Release/better_sqlite3.node"

    pnpm exec turbo run build --filter=bb-app --output-logs=new-only
    pnpm --dir apps/desktop run build
    node -e '
      const fs = require("fs");
      const config = JSON.parse(fs.readFileSync("apps/desktop/electron-builder.config.json", "utf8"));
      delete config.afterPack;
      fs.writeFileSync("apps/desktop/.nix-electron-builder.json", JSON.stringify(config));
    '
    # Build an unpacked directory (linux-unpacked) instead of an AppImage. The
    # native package installs that tree directly; there is no AppImage to wrap.
    pnpm --dir apps/desktop exec electron-builder --linux --dir --x64 --publish never \
      --config .nix-electron-builder.json \
      -c.electronDist=${electronDist} \
      -c.electronVersion=${electronVersion}
    test -d apps/desktop/release/linux-unpacked

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -d $out/lib/bb
    cp -r apps/desktop/release/linux-unpacked/. $out/lib/bb/

    # node-pty ships a native spawn-helper that must be executable.
    find $out/lib/bb/resources/app.asar.unpacked -path '*node-pty*spawn-helper' \
      -exec chmod 755 {} + 2>/dev/null || true

    for bb_node_entry in \
      $out/lib/bb/resources/app.asar.unpacked/node_modules/bb-app/dist/bb-app.js \
      $out/lib/bb/resources/app.asar.unpacked/node_modules/bb-app/dist/bb-host-daemon.js \
      $out/lib/bb/resources/app.asar.unpacked/node_modules/bb-app/dist/bb-server.js \
      $out/lib/bb/resources/app.asar.unpacked/node_modules/bb-app/dist/bb.js \
      $out/lib/bb/resources/app.asar.unpacked/node_modules/bb-app/host-daemon/dist/bb; do
      substituteInPlace "$bb_node_entry" --replace-fail '#!/usr/bin/env node' "#!${nodejs}/bin/node"
    done

    install -d $out/bin
    cat > $out/bin/bb-desktop <<'EOF'
#!/usr/bin/env bash
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
export PATH="${runtimePath}:${nodejs}/bin:''${PATH:-}"
export XDG_DATA_DIRS="${glib.getSchemaDataDirPath gsettings-desktop-schemas}:''${XDG_DATA_DIRS:-}"
export GSETTINGS_SCHEMAS_PATH="${glib.getSchemaDataDirPath gsettings-desktop-schemas}:''${GSETTINGS_SCHEMAS_PATH:-}"
export LD_LIBRARY_PATH="${lib.makeLibraryPath [ libGL gtk3 gtk4 glib ]}:${lib.getLib stdenv.cc.cc}/lib:''${LD_LIBRARY_PATH:-}"
export BB_APP_SURFACE=desktop

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

exec "${placeholder "out"}/lib/bb/bb" "''${flags[@]}" "$@"
EOF
    cat > $out/bin/bb <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export PATH="${runtimePath}:${nodejs}/bin:''${PATH:-}"
exec "${placeholder "out"}/lib/bb/resources/app.asar.unpacked/node_modules/bb-app/dist/bb.js" "$@"
EOF
    cat > $out/bin/bb-app <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export PATH="${runtimePath}:${nodejs}/bin:''${PATH:-}"
export LD_LIBRARY_PATH="${lib.makeLibraryPath [ libGL gtk3 gtk4 glib ]}:${lib.getLib stdenv.cc.cc}/lib:''${LD_LIBRARY_PATH:-}"
export BB_APP_SURFACE=web

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

export ELECTRON_RUN_AS_NODE=1
exec "${placeholder "out"}/lib/bb/bb" "${placeholder "out"}/lib/bb/resources/app.asar.unpacked/node_modules/bb-app/dist/bb-app.js" "$@"
EOF
    chmod 755 $out/bin/bb-desktop $out/bin/bb $out/bin/bb-app

    install -Dm644 apps/desktop/assets/icon.png \
      $out/share/icons/hicolor/1024x1024/apps/bb-desktop.png
    install -Dm644 ${desktopItem}/share/applications/bb-desktop.desktop \
      $out/share/applications/bb-desktop.desktop

    runHook postInstall
  '';

  meta = {
    description = "Agentic IDE that builds itself (source-built native Electron package)";
    homepage = "https://getbb.dev";
    changelog = "https://github.com/get-bb/bb/releases/tag/desktop-v${version}";
    downloadPage = "https://github.com/get-bb/bb/releases";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    license = lib.licenses.mit;
    mainProgram = "bb-desktop";
    platforms = [ "x86_64-linux" ];
  };
})
