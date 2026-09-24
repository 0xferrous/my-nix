{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.executor;
  executorPackage = pkgs.callPackage ../../pkgs/executor.nix { };
in
{
  options.services.executor = {
    enable = lib.mkEnableOption "the Executor integration service";

    package = lib.mkOption {
      type = lib.types.package;
      default = executorPackage;
      defaultText = lib.literalExpression "pkgs.callPackage ../../pkgs/executor.nix { }";
      description = "Executor package to run.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "${config.home.homeDirectory}/.local/share/executor";
      defaultText = lib.literalExpression "\${config.home.homeDirectory}/.local/share/executor";
      description = "Persistent Executor data directory, including its database.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which the Executor HTTP service listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4789;
      description = "Port on which the Executor HTTP service listens.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional arguments passed to `executor daemon run`.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.executorDataDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg cfg.dataDir}
    '';

    systemd.user.services.executor = {
      Unit = {
        Description = "Executor integration service";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Install.WantedBy = [ "default.target" ];
      Service = {
        WorkingDirectory = cfg.dataDir;
        Environment = {
          EXECUTOR_DATA_DIR = toString cfg.dataDir;
          EXECUTOR_SUPERVISED = "1";
        };
        ExecStart = lib.escapeShellArgs (
          [
            "${cfg.package}/bin/executor"
            "daemon"
            "run"
            "--foreground"
            "--port"
            (toString cfg.port)
            "--hostname"
            cfg.hostname
          ]
          ++ cfg.extraArgs
        );
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ReadWritePaths = [ cfg.dataDir ];
      };
    };
  };
}
