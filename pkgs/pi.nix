{
  pkgs,
  piPackage,
  agentStuffSrc,
  gitHunk,
  herdr,
  jjHunk,
  plannotatorPiExtension,
  zjRadarCli,
}:
let
  lib = pkgs.lib;
  agentStuffFixedSrc =
    pkgs.runCommand "agent-stuff-fixed-src"
      {
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-X6xxhjNaj/Ok6YJPkBr5chv7QEMR+qs38u9UJBx0pfc=";
        nativeBuildInputs = [ pkgs.npm-lockfile-fix ];
      }
      ''
        cp -R ${agentStuffSrc} $out
        chmod -R u+w $out
        npm-lockfile-fix $out/package-lock.json
      '';

  agentStuffPackage = pkgs.buildNpmPackage {
    pname = "agent-stuff";
    version = "unstable";
    src = agentStuffFixedSrc;
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

  resourceArgs = [
    "--extension"
    "${herdrPiExtension}"
    "--extension"
    "${./pi/zj-radar.ts}"
    "--extension"
    "${plannotatorPiExtension}/share/pi-extensions/plannotator/apps/pi-extension/index.ts"
    "--extension"
    "${agentStuffPackage}/share/pi-extensions/extensions/notify.ts"
    "--extension"
    "${agentStuffPackage}/share/pi-extensions/extensions/turn-timer.ts"
    "--extension"
    "${agentStuffPackage}/share/pi-extensions/extensions/vendored/usage-bar.ts"
    "--extension"
    "${agentStuffPackage}/share/pi-extensions/extensions/block-sensitive-files.ts"
    "--extension"
    "${agentStuffPackage}/share/pi-extensions/extensions/followup.ts"
    "--extension"
    "${agentStuffPackage}/share/pi-extensions/extensions/agent-summary.ts"
    "--extension"
    "${agentStuffPackage}/share/pi-extensions/extensions/idle-inhibit.ts"
    "--extension"
    "${agentStuffPackage}/share/pi-extensions/extensions/vendored/read-mode.ts"
    "--extension"
    "${agentStuffPackage}/share/pi-extensions/extensions/vendored/tps.ts"
    "--extension"
    "${agentStuffPackage}/share/pi-extensions/extensions/codex-web-search/index.ts"
    "--theme"
    "${agentStuffPackage}/share/pi-extensions/themes/gruvbox-material-dark-hard.json"
    "--prompt-template"
    "${agentStuffPackage}/share/pi-extensions/prompts"
    "--skill"
    "${agentStuffPackage}/share/pi-extensions/skills"
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
  exec ${piPackage}/bin/pi ${lib.escapeShellArgs resourceArgs} "$@"
''
