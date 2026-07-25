{
  inputs,
  pkgs,
  system,
}:
let
  hermesAgent = inputs.hermes-agent.packages.${system}.minimal;
  upstreamDesktop = builtins.readFile "${inputs.hermes-agent}/nix/desktop.nix";
  patchedDesktop =
    builtins.replaceStrings
      [ "sha256-zi/QMwRZ0+FwE9XTE+DiSIeJXAwxmLKEaBWD5W3pMOI=" ]
      [ "sha256-zOl8rx6woWh7aeRUOlkTMviKc/EAQQX6nr/MxAx1ZPI=" ]
      upstreamDesktop;
in
assert upstreamDesktop != patchedDesktop;
pkgs.callPackage (builtins.toFile "hermes-desktop.nix" patchedDesktop) {
  inherit hermesAgent;
  inherit (hermesAgent) hermesNpmLib;
}
