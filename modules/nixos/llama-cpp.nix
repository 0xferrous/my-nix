{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.llama-cpp;
  hfPython = pkgs.python313.withPackages (ps: [
    ps."huggingface-hub"
    ps."hf-xet"
  ]);
  modelType = lib.types.submodule (
    { name, ... }: {
      options = {
        repo = lib.mkOption {
          type = lib.types.str;
          description = "Hugging Face repository containing the model.";
        };
        file = lib.mkOption {
          type = lib.types.str;
          description = "Model file to download from the repository.";
        };
        mmproj = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional vision projector file to load with the model.";
        };
        revision = lib.mkOption {
          type = lib.types.str;
          default = "main";
          description = "Hugging Face revision to download.";
        };
        description = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Human-readable model description.";
        };
      };
    }
  );
  modelNames = lib.attrNames cfg.models;
  download = pkgs.writeShellScript "llama-cpp-download-models" ''
    set -euo pipefail
    export HF_XET_HIGH_PERFORMANCE="${lib.boolToString cfg.hfXetHighPerformance}"
    export HF_HOME=${lib.escapeShellArg cfg.hfCache}
    ${lib.concatMapStringsSep "\n" (
      name:
      let
        m = cfg.models.${name};
        files = [ m.file ] ++ lib.optional (m.mmproj != null) m.mmproj;
      in
      lib.concatMapStringsSep "\n" (file: ''
        repo_dir=${lib.escapeShellArg "${cfg.hfCache}/models--${lib.replaceStrings [ "/" ] [ "--" ] m.repo}"}
        model_file=${lib.escapeShellArg file}
        cached_model="$(find "$repo_dir/snapshots" -name "$model_file" -print -quit 2>/dev/null || true)"
        if [ -n "$cached_model" ]; then
          echo "Using cached model: $cached_model"
        else
          ${hfPython}/bin/hf download \
            ${lib.escapeShellArg m.repo} ${lib.escapeShellArg file} \
            --revision ${lib.escapeShellArg m.revision} \
            --cache-dir ${lib.escapeShellArg cfg.hfCache}
        fi
      '') files
    ) modelNames}
  '';
  serverArgs = lib.concatStringsSep " " (
    lib.cli.toCommandLine
      (optionName: {
        option = if lib.stringLength optionName > 1 then "--${optionName}" else "-${optionName}";
        sep = " ";
        explicitBool = false;
        formatArg = lib.generators.mkValueStringDefault { };
      })
      (
        builtins.removeAttrs cfg.settings [
          "model"
          "host"
          "port"
        ]
      )
  );
  launch = pkgs.writeShellScript "llama-cpp-launch" ''
    set -euo pipefail
    export HF_HOME=${lib.escapeShellArg cfg.hfCache}
    export LLAMA_CACHE=${lib.escapeShellArg cfg.hfCache}
    exec ${lib.getExe' cfg.package "llama-server"} \
      --host 127.0.0.1 --port ${toString cfg.socketActivation.backendPort} \
      --models-max ${toString cfg.router.modelsMax} \
      ${lib.optionalString cfg.router.modelsAutoload "--models-autoload"} \
      ${serverArgs} "$@"
  '';
in
{
  # NixOS already provides services.llama-cpp.enable, package, and settings.
  # This module adds optional model downloads on top of llama-server's native
  # Hugging Face cache discovery. Every compatible model already in hfCache is
  # exposed by the router; cfg.models only controls what this module downloads.
  options.services.llama-cpp = {
    models = lib.mkOption {
      type = lib.types.attrsOf modelType;
      default = { };
      description = "Optional models to download into the shared Hugging Face cache.";
    };
    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Legacy compatibility value; the router discovers models from the cache.";
    };
    draftModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Legacy compatibility value; model instances are selected by the router.";
    };
    hfCache = lib.mkOption {
      type = lib.types.str;
      default = "/var/cache/llama-cpp/huggingface";
      description = "Hugging Face cache shared by all models.";
    };
    hfXetHighPerformance = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable hf-xet high-performance downloads.";
    };
    router.modelsMax = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 4;
      description = "Maximum number of model instances loaded simultaneously in router mode; 0 means unlimited.";
    };
    router.modelsAutoload = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically load a model when a request names it in router mode.";
    };
    socketActivation.backendPort = lib.mkOption {
      type = lib.types.port;
      default = 18080;
      description = "Loopback port used by llama-server behind the activated socket.";
    };
    socketActivation.idleTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Seconds without proxy activity before the llama.cpp server stops.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.settings.port or 8080 != cfg.socketActivation.backendPort;
        message = "services.llama-cpp.socketActivation.backendPort must differ from settings.port.";
      }
    ];

    systemd.sockets.llama-cpp = {
      description = "Socket for the llama.cpp HTTP server";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = "${cfg.settings.host or "127.0.0.1"}:${toString (cfg.settings.port or 8080)}";
        Service = "llama-cpp-proxy.service";
      };
    };

    systemd.services.llama-cpp = {
      wantedBy = lib.mkForce [ ];
      environment = {
        HF_HOME = cfg.hfCache;
        LLAMA_CACHE = cfg.hfCache;
        HF_XET_HIGH_PERFORMANCE = lib.boolToString cfg.hfXetHighPerformance;
      };
      serviceConfig = {
        ExecStartPre = lib.mkBefore download;
        ExecStart = lib.mkForce launch;
        CacheDirectory = "llama-cpp";
        StopWhenUnneeded = true;
        # Model downloads can exceed systemd's default 90-second startup
        # timeout, especially for multi-GB GGUF files.
        TimeoutStartSec = "infinity";
      };
    };

    systemd.services.llama-cpp-proxy = {
      description = "Socket proxy for the llama.cpp HTTP server";
      requires = [ "llama-cpp.service" ];
      after = [ "llama-cpp.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=${toString cfg.socketActivation.idleTimeout}s 127.0.0.1:${toString cfg.socketActivation.backendPort}";
        Restart = "on-failure";
      };
    };
  };
}
