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
    "socketActivation"
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

        socketActivation = {
          enable = lib.mkEnableOption "SSH-triggered agentspace VM startup";

          sshHost = lib.mkOption {
            type = lib.types.str;
            default = name;
            description = "SSH host alias that should activate/connect to this VM.";
          };

          socketPath = lib.mkOption {
            type = lib.types.str;
            default = "%t/agentspace-${name}.sock";
            description = "User systemd socket path used as the activation trigger.";
          };

          identityFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional SSH identity file used by the generated SSH host alias for this VM.";
          };
        };
      };
    }
  );

  sandboxConfigOf = vmCfg: builtins.removeAttrs vmCfg wrapperOptionNames;

  mkLaunchProgram =
    sandboxConfig: agentspaceInput.lib.mkLaunch (agentspaceInput.lib.mkSandbox sandboxConfig);

  mkVmPackage =
    name: vmCfg:
    let
      launchProgram = mkLaunchProgram (sandboxConfigOf vmCfg);
    in
    pkgs.writeShellScriptBin vmCfg.packageName ''
      exec ${lib.escapeShellArg launchProgram} "$@"
    '';

  enabledVms = lib.filterAttrs (_: vm: vm.enable) cfg.vms;
  socketVms = lib.filterAttrs (_: vm: vm.enable && vm.socketActivation.enable) cfg.vms;

  mkSocketUnitName = name: "agentspace-${name}-activate";

  mkStateDir =
    name: vmCfg:
    let
      sandboxConfig = sandboxConfigOf vmCfg;
    in
    sandboxConfig.persistence.baseDir or ".agentspace";

  mkHostName =
    name: vmCfg:
    let
      sandboxConfig = sandboxConfigOf vmCfg;
    in
    sandboxConfig.hostName or "agent-sandbox";

  mkDaemonProgram =
    _name: vmCfg:
    mkLaunchProgram (
      lib.recursiveUpdate (sandboxConfigOf vmCfg) {
        ssh.autoconnect = false;
      }
    );

  mkProxyCommand =
    name: vmCfg:
    let
      stateDir = mkStateDir name vmCfg;
      hostName = mkHostName name vmCfg;
      socketUnit = "${mkSocketUnitName name}.socket";
      serviceUnit = "${mkSocketUnitName name}.service";
    in
    pkgs.writeShellScript "agentspace-${name}-ssh-proxy" ''
      set -euo pipefail

      state_dir=${lib.escapeShellArg stateDir}
      host_name=${lib.escapeShellArg hostName}
      socket_unit=${lib.escapeShellArg socketUnit}
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

          # virtie leaves lock files behind, but holds an flock while the VM is
          # running. If we can take the lock, it is stale and not a running VM.
          if ${pkgs.util-linux}/bin/flock -n "$lock" true; then
            ${pkgs.coreutils}/bin/rm -f "$lock"
            continue
          fi

          printf '%s\n' "$cid"
          return 0
        done
        return 1
      }

      ${pkgs.systemd}/bin/systemctl --user reset-failed "$socket_unit" "$service_unit" >/dev/null 2>&1 || true
      ${pkgs.systemd}/bin/systemctl --user start "$socket_unit" >/dev/null

      cid=""
      if ! cid="$(find_running_cid)"; then
        # No locked virtie CID file means no currently-running VM for this
        # sandbox. Start the long-running virtie service.
        cid=""
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

      # At this point either an existing VM is running, or we started it above.
      # SSH may still be coming up, so retry the final fd-passing proxy until it
      # can hand OpenSSH a connected socket.
      for _ in $(${pkgs.coreutils}/bin/seq 1 240); do
        if ${pkgs.systemd}/lib/systemd/systemd-ssh-proxy "vsock/$cid" 22; then
          exit 0
        fi
        ${pkgs.coreutils}/bin/sleep 0.5
      done

      echo "agentspace: timed out waiting for $host_name SSH on vsock/$cid" >&2
      exit 1
    '';

  socketPackages = lib.mapAttrsToList (
    name: vmCfg:
    pkgs.writeShellScriptBin "ssh-${vmCfg.socketActivation.sshHost}" ''
      exec ${pkgs.openssh}/bin/ssh ${lib.escapeShellArg vmCfg.socketActivation.sshHost} "$@"
    ''
  ) socketVms;
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

    vms = lib.mkOption {
      type = lib.types.attrsOf vmType;
      default = { };
      example = lib.literalExpression ''
        {
          default = {
            persistence.baseDir = "~/.local/share/agentspace/default";
            machine.memory = 8192;
            ssh.authorizedKeys = [ "ssh-ed25519 ..." ];
            workspace.guestDir = "/home/agent/workspace";
            socketActivation = {
              enable = true;
              identityFile = "~/.ssh/agentspace";
            };
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

    home.packages = (lib.mapAttrsToList mkVmPackage enabledVms) ++ socketPackages;

    systemd.user.sockets = lib.mapAttrs' (name: vmCfg: {
      name = mkSocketUnitName name;
      value = {
        Unit.Description = "agentspace ${name} SSH activation socket";
        Socket = {
          ListenStream = vmCfg.socketActivation.socketPath;
          RemoveOnStop = true;
        };
        Install.WantedBy = [ "sockets.target" ];
      };
    }) socketVms;

    systemd.user.services = lib.mapAttrs' (name: vmCfg: {
      name = mkSocketUnitName name;
      value = {
        Unit.Description = "agentspace ${name} VM";
        Service = {
          ExecStart = mkDaemonProgram name vmCfg;
          Restart = "no";
        };
      };
    }) socketVms;

    programs.ssh = lib.mkIf (socketVms != { }) {
      enable = true;
      matchBlocks = lib.mapAttrs' (name: vmCfg: {
        name = vmCfg.socketActivation.sshHost;
        value = {
          user = (sandboxConfigOf vmCfg).user or "agent";
          proxyCommand = "${mkProxyCommand name vmCfg}";
          identityFile = lib.optional (
            vmCfg.socketActivation.identityFile != null
          ) vmCfg.socketActivation.identityFile;
          extraOptions = {
            ProxyUseFdpass = "yes";
            PubkeyAuthentication = "yes";
            CheckHostIP = "no";
            StrictHostKeyChecking = "no";
            UserKnownHostsFile = "/dev/null";
            GlobalKnownHostsFile = "/dev/null";
          };
        };
      }) socketVms;
    };
  };
}
