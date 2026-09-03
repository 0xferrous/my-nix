{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fr.nushell-session-vars;
  # Coerce every session variable to a string so toNushell can render it
  # (values may be ints/floats/paths, not just strings).
  envRecord = lib.mapAttrs (_: v: toString v) config.home.sessionVariables;
  # nushell `source` only accepts a parse-time constant, so the path is baked
  # as a const. It must resolve to an existing file when nushell starts, which
  # is why we create the placeholder below (only when absent).
  userEnvFile =
    let
      path =
        if cfg.userEnvFile != null then
          cfg.userEnvFile
        else
          "${config.programs.nushell.configDir}/user-env.nu";
    in
    toString path;
  userEnvDir = lib.dirOf userEnvFile;
  escapeNushellString = s: ''"${lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] s}"'';
  userEnvSource = ''
    # User-editable environment file; sourced last so manual edits win.
    const USER_ENV = ${escapeNushellString userEnvFile}
    source $USER_ENV
  '';
in
{
  options.fr.nushell-session-vars = {
    enable = lib.mkEnableOption "nushell env.nu derived from home.sessionVariables";

    userEnvFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        User-editable environment file sourced by the generated env.nu.
        Defaults to `$configDir/user-env.nu`. Sourced after the session
        variables so manual edits take effect. If absent, an empty placeholder
        is created on activation so nushell always finds it.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && config.programs.nushell.enable) {
    programs.nushell.envFile.text = ''
      load-env ${(lib.hm.nushell.toNushell { }) envRecord}

      ${userEnvSource}
    '';

    home.activation.createNushellSessionVarsUserEnv =
      lib.hm.dag.entryAfter
        [
          "writeBoundary"
        ]
        ''
          ${pkgs.coreutils}/bin/mkdir -p ${pkgs.lib.escapeShellArg userEnvDir}
          if [ ! -e ${pkgs.lib.escapeShellArg userEnvFile} ]; then
            ${pkgs.coreutils}/bin/printf '%s\n' \
              '# User-editable nushell environment file.' \
              '# Sourced by env.nu after home.sessionVariables; edit freely.' \
              > ${pkgs.lib.escapeShellArg userEnvFile}
          fi
        '';
  };
}
