{
  pkgs,
  piPackage,
  agentStuffSrc,
  gitHunk,
  jjHunk,
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

  resourceArgs = [
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
    ]
  }:$PATH
  exec ${piPackage}/bin/pi ${lib.escapeShellArgs resourceArgs} "$@"
''
