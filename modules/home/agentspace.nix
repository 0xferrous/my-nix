{
  config,
  lib,
  pkgs,
  myNixInputs ? { },
  ...
}:
let
  cfg = config.fr.agentspace;

  agentspaceInput = cfg.input;

  wrapperOptionNames = [
    "enable"
    "packageName"
    "sshConnect"
  ];

  vmType = lib.types.submodule (
    { name, ... }:
    {
      freeformType = lib.types.attrsOf lib.types.anything;

      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to install a launch wrapper for this agentspace VM.";
        };

        packageName = lib.mkOption {
          type = lib.types.str;
          default = "agentspace-${name}";
          description = "Name of the generated Home Manager package/bin for this VM.";
        };

        sshConnect = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to add an SSH host that starts this VM when needed.";
          };

          host = lib.mkOption {
            type = lib.types.str;
            default = name;
            description = "SSH host alias that starts/connects to this VM.";
          };

          identityFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional SSH identity file for this VM host alias.";
          };
        };
      };
    }
  );

  sandboxConfigOf =
    name: vmCfg:
    let
      vmSandboxConfig = builtins.removeAttrs vmCfg wrapperOptionNames;
      defaultExtraModules = [
        {
          environment.enableAllTerminfo = true;
        }
      ];
      mergedConfig = lib.recursiveUpdate {
        hostName = name;
        persistence.baseDir = "${cfg.baseDir}/${name}";
        workspace.addCurrentDir = false;
      } vmSandboxConfig;
    in
    mergedConfig
    // {
      extraModules =
        defaultExtraModules ++ cfg.commonNixosModules ++ (vmSandboxConfig.extraModules or [ ]);
      homeModules = cfg.commonHomeModules ++ (vmSandboxConfig.homeModules or [ ]);
    };

  mkLaunchProgram =
    sandboxConfig: agentspaceInput.lib.mkLaunch (agentspaceInput.lib.mkSandbox sandboxConfig);

  mkVmLaunchProgram = name: vmCfg: mkLaunchProgram (sandboxConfigOf name vmCfg);

  mkVmApp = name: vmCfg: {
    type = "app";
    program = mkVmLaunchProgram name vmCfg;
  };

  mkVmPackage =
    name: vmCfg:
    let
      launchProgram = mkVmLaunchProgram name vmCfg;
    in
    pkgs.writeShellScriptBin vmCfg.packageName ''
      exec ${lib.escapeShellArg launchProgram} "$@"
    '';

  enabledVms = lib.filterAttrs (_: vm: vm.enable) cfg.vms;
  sshVms = lib.filterAttrs (_: vm: vm.enable && vm.sshConnect.enable) cfg.vms;

  mkServiceUnitName = name: "agentspace-${name}";

  mkStateDir =
    name: vmCfg:
    let
      sandboxConfig = sandboxConfigOf name vmCfg;
    in
    sandboxConfig.persistence.baseDir or ".agentspace";

  mkHostName =
    name: vmCfg:
    let
      sandboxConfig = sandboxConfigOf name vmCfg;
    in
    sandboxConfig.hostName;

  mkDaemonProgram =
    name: vmCfg:
    mkLaunchProgram (
      lib.recursiveUpdate (sandboxConfigOf name vmCfg) {
        ssh.autoconnect = false;
      }
    );

  mkProxyCommand =
    name: vmCfg:
    let
      stateDir = mkStateDir name vmCfg;
      hostName = mkHostName name vmCfg;
      serviceUnit = "${mkServiceUnitName name}.service";
    in
    pkgs.writeShellScript "agentspace-${name}-ssh-proxy" ''
      set -euo pipefail

      state_dir=${lib.escapeShellArg stateDir}
      host_name=${lib.escapeShellArg hostName}
      service_unit=${lib.escapeShellArg serviceUnit}

      find_running_cid() {
        local lock cid
        for lock in "$state_dir"/"$host_name"-vsock-*.lock; do
          [ -e "$lock" ] || continue
          cid="''${lock##*-vsock-}"
          cid="''${cid%.lock}"
          if [ -z "$cid" ]; then
            continue
          fi
          case "$cid" in
            *[!0-9]*) continue ;;
          esac

          if ${pkgs.util-linux}/bin/flock -n "$lock" true; then
            ${pkgs.coreutils}/bin/rm -f "$lock"
            continue
          fi

          printf '%s\n' "$cid"
          return 0
        done
        return 1
      }

      ${pkgs.systemd}/bin/systemctl --user reset-failed "$service_unit" >/dev/null 2>&1 || true

      cid=""
      if ! cid="$(find_running_cid)"; then
        ${pkgs.systemd}/bin/systemctl --user start "$service_unit" >/dev/null
      fi

      for _ in $(${pkgs.coreutils}/bin/seq 1 600); do
        if [ -n "$cid" ] || cid="$(find_running_cid)"; then
          break
        fi

        if ${pkgs.systemd}/bin/systemctl --user is-failed --quiet "$service_unit"; then
          echo "agentspace: $service_unit failed while starting $host_name" >&2
          ${pkgs.systemd}/bin/journalctl --user -u "$service_unit" -n 40 --no-pager >&2 || true
          exit 1
        fi

        ${pkgs.coreutils}/bin/sleep 0.5
      done

      if [ -z "$cid" ]; then
        echo "agentspace: timed out waiting for $host_name vsock CID in $state_dir" >&2
        exit 1
      fi

      for _ in $(${pkgs.coreutils}/bin/seq 1 240); do
        if ${pkgs.systemd}/lib/systemd/systemd-ssh-proxy "vsock/$cid" 22; then
          exit 0
        fi
        ${pkgs.coreutils}/bin/sleep 0.5
      done

      echo "agentspace: timed out waiting for $host_name SSH on vsock/$cid" >&2
      exit 1
    '';
in
{
  options.fr.agentspace = {
    enable = lib.mkEnableOption "agentspace VM launch wrappers";

    input = lib.mkOption {
      type = lib.types.raw;
      default = myNixInputs.agentspace or null;
      defaultText = lib.literalExpression "myNixInputs.agentspace";
      description = "agentspace flake input providing lib.mkSandbox and lib.mkLaunch.";
    };

    baseDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/vms";
      defaultText = lib.literalExpression "${config.home.homeDirectory}/vms";
      description = "Base directory for agentspace VM persistence state.";
    };

    apps = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      default = { };
      description = ''
        Flake app definitions for enabled agentspace VMs, suitable for exposing
        from a consuming flake's `apps.<system>` output.
      '';
    };

    commonHomeModules = lib.mkOption {
      type = lib.types.listOf lib.types.raw;
      default = [ ];
      description = "Home Manager modules added to every agentspace VM declared by this module.";
    };

    commonNixosModules = lib.mkOption {
      type = lib.types.listOf lib.types.raw;
      default = [ ];
      description = "NixOS modules added to every agentspace VM declared by this module.";
    };

    vms = lib.mkOption {
      type = lib.types.attrsOf vmType;
      default = { };
      example = lib.literalExpression ''
        {
          default = {
            machine.memory = 8192;
            ssh.authorizedKeys = [ "ssh-ed25519 ..." ];
            workspace.guestDir = "/home/agent/workspace";
            sshConnect.identityFile = "~/.ssh/agentspace";
          };
        }
      '';
      description = ''
        Agentspace VM definitions. Each attribute is passed through to
        `agentspace.lib.mkSandbox`, with wrapper-only options consumed by this
        Home Manager module.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = agentspaceInput != null;
        message = "fr.agentspace.input must be set, or pass flake inputs as _module.args.myNixInputs.";
      }
    ];

    fr.agentspace.apps = lib.mapAttrs mkVmApp enabledVms;

    home.packages = lib.mapAttrsToList mkVmPackage enabledVms;

    systemd.user.services = lib.mapAttrs' (name: vmCfg: {
      name = mkServiceUnitName name;
      value = {
        Unit.Description = "agentspace ${name} VM";
        Service = {
          ExecStart = mkDaemonProgram name vmCfg;
          Restart = "no";
        };
      };
    }) sshVms;

    programs.ssh = lib.mkIf (sshVms != { }) {
      enable = true;
      matchBlocks = lib.mapAttrs' (name: vmCfg: {
        name = vmCfg.sshConnect.host;
        value = {
          user = (sandboxConfigOf name vmCfg).user or "agent";
          proxyCommand = "${mkProxyCommand name vmCfg}";
          identityFile = lib.optional (vmCfg.sshConnect.identityFile != null) vmCfg.sshConnect.identityFile;
          extraOptions = {
            ProxyUseFdpass = "yes";
            PubkeyAuthentication = "yes";
            CheckHostIP = "no";
            StrictHostKeyChecking = "no";
            UserKnownHostsFile = "/dev/null";
            GlobalKnownHostsFile = "/dev/null";
          };
        };
      }) sshVms;
    };
  };
}
