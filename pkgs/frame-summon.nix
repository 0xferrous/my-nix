{
  pkgs,
  lib ? pkgs.lib,
}:

pkgs.writeShellApplication {
  name = "frame-summon";
  runtimeInputs = [ pkgs.bun ];
  text = ''
    exec bun ${./frame-summon.js} "$@"
  '';

  meta = with lib; {
    description = "Summon the Frame extension via local JSON-RPC WebSocket";
    mainProgram = "frame-summon";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
