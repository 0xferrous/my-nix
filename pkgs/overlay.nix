{
  inputs,
  system,
}:
final: _prev: {
  fr-kbd-backlight = final.callPackage ./keyboard-backlight.nix { };
  git-hunk = final.callPackage ./git-hunk.nix { };
  opensrc = final.callPackage ./opensrc.nix { };
  pi = final.callPackage ./pi.nix {
    piPackage = inputs.llm-agents.packages.${system}.pi;
    agentStuffSrc = inputs."agent-stuff";
  };
}
