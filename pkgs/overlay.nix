{
  inputs,
  system,
}:
final: _prev: {
  fr-frame-summon = final.callPackage ./frame-summon.nix { };
  fr-kbd-backlight = final.callPackage ./keyboard-backlight.nix { };
  git-hunk = final.callPackage ./git-hunk.nix { };
  opensrc = final.callPackage ./opensrc.nix { };
  "install-bin" = final.callPackage ./install-bin.nix { };
  pi = final.callPackage ./pi.nix {
    piPackage = inputs.llm-agents.packages.${system}.pi;
    agentStuffSrc = inputs."agent-stuff";
  };
  frsNvimPackage = inputs.frs-nvim.packages.${system}.default;
}
