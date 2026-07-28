{
  pkgs,
  piPackage,
  agentStuffSrc,
  agentStuffPath ? null,
  gitHunk,
  herdr,
  jjHunk,
  plannotatorPiExtension,
  zjRadarCli,
}:
let
  lib = pkgs.lib;
  agentStuffLockHash = builtins.substring 0 12 (
    builtins.hashFile "sha256" "${agentStuffSrc}/package-lock.json"
  );

  # npm-lockfile-fix needs registry access, so only the repaired lockfile is a
  # fixed-output derivation. Including the original lockfile hash in its name
  # prevents Nix from silently reusing it when agent-stuff changes dependencies.
  agentStuffFixedPackageLock =
    pkgs.runCommand "agent-stuff-fixed-package-lock-${agentStuffLockHash}"
      {
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-YJxv0ZRba4avpMJruBMHUPu3g8kpiw+YNyA7P6bf8rQ=";
        nativeBuildInputs = [ pkgs.npm-lockfile-fix ];
      }
      ''
        mkdir -p $out
        cp ${agentStuffSrc}/package-lock.json $out/package-lock.json
        chmod u+w $out/package-lock.json
        npm-lockfile-fix $out/package-lock.json
      '';

  # Keep the full source input-addressed so extension, prompt, skill, and theme
  # updates always change the resulting package and wrapper.
  agentStuffPatchedSrc = pkgs.runCommand "agent-stuff-patched-src" { } ''
    cp -R ${agentStuffSrc} $out
    chmod -R u+w $out
    cp ${agentStuffFixedPackageLock}/package-lock.json $out/package-lock.json
  '';

  agentStuffPackage = pkgs.buildNpmPackage {
    pname = "agent-stuff";
    version = "unstable";
    src = agentStuffPatchedSrc;
    npmDepsHash = "sha256-bBgWVbCWIk6yO/X5hd+2csRKNFZEvQE5LW6x5+EZ5rk=";
    npmDepsFetcherVersion = 2;

    dontNpmBuild = true;
    npmInstallFlags = [
      "--ignore-scripts"
      "--omit=optional"
    ];
    npmPruneFlags = [
      "--ignore-scripts"
      "--omit=optional"
    ];

    postInstall = ''
      mkdir -p $out/share/pi-extensions
      cp -R extensions themes prompts skills package.json $out/share/pi-extensions/
    '';
  };

  herdrPiExtension =
    pkgs.runCommand "herdr-pi-extension-${herdr.version}"
      {
        nativeBuildInputs = [ herdr ];
      }
      ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME/.pi/agent/extensions"
        herdr integration install pi
        cp "$HOME/.pi/agent/extensions/herdr-agent-state.ts" "$out"
      '';

  agentStuffRoot =
    if agentStuffPath == null then "${agentStuffPackage}/share/pi-extensions" else agentStuffPath;

  staticResourceArgs = [
    "--extension"
    "${herdrPiExtension}"
    "--extension"
    "${./pi/zj-radar.ts}"
    "--extension"
    "${plannotatorPiExtension}/share/pi-extensions/plannotator/apps/pi-extension/index.ts"
    "--skill"
    "${gitHunk}/share/git-hunk/skills/git-hunk"
    "--skill"
    "${jjHunk}/share/jj-hunk/skills/jj-hunk"
  ];
in
pkgs.writeShellScriptBin "pi" ''
  export PATH=${
    lib.makeBinPath [
      gitHunk
      jjHunk
      zjRadarCli
    ]
  }:$PATH

  agent_stuff_root=${lib.escapeShellArg agentStuffRoot}
  if [[ "$agent_stuff_root" == "~/"* ]]; then
    agent_stuff_root="$HOME/''${agent_stuff_root:2}"
  fi

  if [[ ! -d "$agent_stuff_root/extensions" \
    || ! -d "$agent_stuff_root/prompts" \
    || ! -d "$agent_stuff_root/skills" \
    || ! -d "$agent_stuff_root/themes" ]]; then
    echo "pi: invalid agent-stuff path: $agent_stuff_root" >&2
    echo "expected extensions/, prompts/, skills/, and themes/ directories" >&2
    exit 2
  fi

  resource_args=(
    ${lib.escapeShellArgs staticResourceArgs}
    --extension "$agent_stuff_root/extensions/notify.ts"
    --extension "$agent_stuff_root/extensions/turn-timer.ts"
    --extension "$agent_stuff_root/extensions/vendored/usage-bar.ts"
    --extension "$agent_stuff_root/extensions/block-sensitive-files.ts"
    --extension "$agent_stuff_root/extensions/followup.ts"
    --extension "$agent_stuff_root/extensions/agent-summary.ts"
    --extension "$agent_stuff_root/extensions/idle-inhibit.ts"
    --extension "$agent_stuff_root/extensions/vendored/read-mode.ts"
    --extension "$agent_stuff_root/extensions/vendored/tps.ts"
    --extension "$agent_stuff_root/extensions/codex-web-search/index.ts"
    --theme "$agent_stuff_root/themes/gruvbox-material-dark-hard.json"
    --prompt-template "$agent_stuff_root/prompts"
    --skill "$agent_stuff_root/skills"
  )

  exec ${piPackage}/bin/pi "''${resource_args[@]}" "$@"
''
