{
  inputs,
  system,
}:
final: prev: {
  fzf = final.symlinkJoin {
    inherit (prev.fzf) pname version;
    name = "${prev.fzf.pname}-${prev.fzf.version}";
    meta = builtins.removeAttrs prev.fzf.meta [ "outputsToInstall" ];
    paths = [ prev.fzf ];
    postBuild = ''
      rm "$out/bin/fzf"
      cat > "$out/bin/fzf" <<'EOF'
      #!${final.runtimeShell}
      if [ "$#" -eq 1 ] && [ "$1" = --nushell ]; then
        set -o pipefail
        ${prev.fzf}/bin/fzf --nushell | ${final.gnused}/bin/sed 's/str downcase/str lowercase/g'
      else
        exec ${prev.fzf}/bin/fzf "$@"
      fi
      EOF
      chmod +x "$out/bin/fzf"
    '';
  };

  fr-frame-summon = final.callPackage ./frame-summon.nix { };
  fr-kbd-backlight = final.callPackage ./keyboard-backlight.nix { };
  git-hunk = final.callPackage ./git-hunk.nix { };
  ironclaw = final.callPackage ./ironclaw.nix { };
  jj-hunk = final.callPackage ./jj-hunk.nix { };
  google-authenticator-transfer-decode =
    final.callPackage ./google-authenticator-transfer-decode.nix
      { };
  opensrc = final.callPackage ./opensrc.nix { };
  takopi = final.callPackage ./takopi.nix { };
  "install-bin" = final.callPackage ./install-bin.nix { };
  flake-utils = final.callPackage ./flake-utils.nix { };
  plannotator-pi-extension = final.callPackage ./plannotator-pi-extension.nix { };
  pi = final.callPackage ./pi.nix {
    piPackage = inputs.llm-agents.packages.${system}.pi;
    agentStuffSrc = inputs."agent-stuff";
    gitHunk = final.git-hunk;
    jjHunk = final.jj-hunk;
    plannotatorPiExtension = final.plannotator-pi-extension;
    zjRadarCli = inputs.zj-radar.packages.${system}.zj-radar-cli;
  };
  pi-acp = final.callPackage ./pi-acp.nix { };
  frsNvimPackage = inputs.frs-nvim.packages.${system}.default;
}
