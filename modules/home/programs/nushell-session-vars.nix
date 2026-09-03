{
  config,
  lib,
  ...
}:
let
  cfg = config.fr.nushell-session-vars;
  # Coerce every session variable to a string so toNushell can render it
  # (values may be ints/floats/paths, not just strings).
  envRecord = lib.mapAttrs (_: v: toString v) config.home.sessionVariables;
in
{
  options.fr.nushell-session-vars = {
    enable = lib.mkEnableOption "nushell env.nu derived from home.sessionVariables";
  };

  config = lib.mkIf (cfg.enable && config.programs.nushell.enable) {
    programs.nushell.envFile.text = ''
      load-env ${(lib.hm.nushell.toNushell { }) envRecord}
    '';
  };
}
