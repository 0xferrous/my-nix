{
  agentspace,
  systems,
  lib,
}:
lib.mapAttrs (_name: vmSystem: {
  type = "app";
  program = agentspace.lib.mkLaunch vmSystem;
}) systems
