{
  pkgs,
  piPackage,
  agentStuffSrc,
  gitHunk,
  jjHunk,
}:
let
  lib = pkgs.lib;
  agentStuffPackage = pkgs.buildNpmPackage {
    pname = "agent-stuff";
    version = "unstable";
    src = agentStuffSrc;
    npmDepsHash = "sha256-t0Ek9KQ9pSNXmHVmb/VQumZGosx8rb+iteE/IgM1oJY=";
    dontNpmBuild = true;
    npmInstallFlags = [
      "--ignore-scripts"
      "--omit=optional"
    ];
    npmPruneFlags = [
      "--ignore-scripts"
      "--omit=optional"
    ];
  };

  resourceArgs = [
    "--extension"
    "${agentStuffPackage}/lib/node_modules/pi-extensions/extensions/notify.ts"
    "--extension"
    "${agentStuffPackage}/lib/node_modules/pi-extensions/extensions/turn-timer.ts"
    "--extension"
    "${agentStuffPackage}/lib/node_modules/pi-extensions/extensions/vendored/usage-bar.ts"
    "--extension"
    "${agentStuffPackage}/lib/node_modules/pi-extensions/extensions/block-sensitive-files.ts"
    "--extension"
    "${agentStuffPackage}/lib/node_modules/pi-extensions/extensions/followup.ts"
    "--extension"
    "${agentStuffPackage}/lib/node_modules/pi-extensions/extensions/agent-summary.ts"
    "--extension"
    "${agentStuffPackage}/lib/node_modules/pi-extensions/extensions/idle-inhibit.ts"
    "--extension"
    "${agentStuffPackage}/lib/node_modules/pi-extensions/extensions/vendored/read-mode.ts"
    "--extension"
    "${agentStuffPackage}/lib/node_modules/pi-extensions/extensions/vendored/tps.ts"
    "--extension"
    "${agentStuffPackage}/lib/node_modules/pi-extensions/extensions/codex-web-search/index.ts"
    "--theme"
    "${agentStuffPackage}/lib/node_modules/pi-extensions/themes/gruvbox-material-dark-hard.json"
    "--prompt-template"
    "${agentStuffPackage}/lib/node_modules/pi-extensions/prompts"
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
