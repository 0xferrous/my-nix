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
  impermanenceInput = cfg.impermanence.input;

  wrapperOptionNames = [
    "enable"
    "packageName"
    "sshConnect"
    "impermanence"
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

          sshAgentForwarding = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether to forward the host SSH agent into this VM over SSH.";
          };

          gpgAgentForwarding = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether to forward the host GnuPG agent socket into this VM over SSH.";
            };

            localSocket = lib.mkOption {
              type = lib.types.str;
              default = "/run/user/1000/gnupg/S.gpg-agent.extra";
              description = "Host GnuPG extra-agent socket path exposed to the VM.";
            };

            remoteSocket = lib.mkOption {
              type = lib.types.str;
              default = "~/.gnupg/S.gpg-agent";
              description = "Guest socket path created by SSH RemoteForward for the forwarded GnuPG agent.";
            };
          };
        };

        impermanence = {
          enable = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Whether to enable impermanence for this VM. Null inherits fr.agentspace.impermanence.enable.";
          };

          persistRoot = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Per-VM persistent root mount path. Null inherits fr.agentspace.impermanence.persistRoot.";
          };

          imageName = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Per-VM persistent disk image name. Null inherits fr.agentspace.impermanence.imageName.";
          };

          size = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = null;
            description = "Per-VM persistent disk image size in MiB. Null inherits fr.agentspace.impermanence.size.";
          };

          hideMounts = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Per-VM impermanence hideMounts override. Null inherits fr.agentspace.impermanence.hideMounts.";
          };

          directories = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
            description = "Additional guest directories persisted for this VM.";
          };

          files = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
            description = "Additional guest files persisted for this VM.";
          };
        };
      };
    }
  );

  sandboxConfigOf =
    name: vmCfg:
    let
      vmSandboxConfig = builtins.removeAttrs vmCfg wrapperOptionNames;
      vmImpermanence = vmCfg.impermanence;
      sharedNixStoreShareSocket = {
        nixStoreShareSocket = (import ../common.nix).nixStoreShareSocketPath;
      };
      impermanenceEnabled =
        if vmImpermanence.enable != null then vmImpermanence.enable else cfg.impermanence.enable;
      inheritVmOrGlobal = value: global: if value != null then value else global;
      impermanencePersistRoot = inheritVmOrGlobal vmImpermanence.persistRoot cfg.impermanence.persistRoot;
      impermanenceImageName = inheritVmOrGlobal vmImpermanence.imageName cfg.impermanence.imageName;
      impermanenceSize = inheritVmOrGlobal vmImpermanence.size cfg.impermanence.size;
      impermanenceHideMounts = inheritVmOrGlobal vmImpermanence.hideMounts cfg.impermanence.hideMounts;
      defaultExtraModules = [
        {
          environment.enableAllTerminfo = true;
        }
      ]
      ++ lib.optionals impermanenceEnabled [
        impermanenceInput.nixosModules.impermanence
        {
          environment.persistence.${impermanencePersistRoot} = {
            hideMounts = impermanenceHideMounts;
            directories = [ "/var/lib/nixos" ] ++ cfg.impermanence.directories ++ vmImpermanence.directories;
            files = cfg.impermanence.files ++ vmImpermanence.files;
          };

          fileSystems.${impermanencePersistRoot}.neededForBoot = true;

          microvm.volumes = [
            {
              image = "${cfg.baseDir}/${name}/${impermanenceImageName}";
              mountPoint = impermanencePersistRoot;
              fsType = "ext4";
              size = impermanenceSize;
              autoCreate = true;
            }
          ];
        }
      ];
      mergedConfig = lib.recursiveUpdate (
        {
          hostName = name;
          persistence.baseDir = "${cfg.baseDir}/${name}";
          workspace.addCurrentDir = false;
        }
        // sharedNixStoreShareSocket
      ) vmSandboxConfig;
      vmAuthorizedKeys =
        cfg.authorizedKeys ++ lib.attrByPath [ "ssh" "authorizedKeys" ] [ ] vmSandboxConfig;
      vmWriteFiles = lib.recursiveUpdate cfg.commonWriteFiles (vmSandboxConfig.writeFiles or { });
    in
    lib.recursiveUpdate mergedConfig {
      ssh.authorizedKeys = vmAuthorizedKeys;
      writeFiles = vmWriteFiles;
      extraModules =
        defaultExtraModules
        ++ [ cfg.defaultNixosModule ]
        ++ cfg.commonNixosModules
        ++ (vmSandboxConfig.extraModules or [ ]);
      homeModules = [
        cfg.defaultHmModule
      ]
      ++ cfg.commonHomeModules
      ++ (vmSandboxConfig.homeModules or [ ]);
    };

  mkLaunchProgram =
    sandboxConfig: agentspaceInput.lib.mkLaunch (agentspaceInput.lib.mkSandbox sandboxConfig);

  mkVmLaunchProgram = name: vmCfg: mkLaunchProgram (sandboxConfigOf name vmCfg);

  mkVmSystems = import ../../lib/mkAgentspaceVmSystems.nix;
  mkVmApps = import ../../lib/mkAgentspaceVmApps.nix;

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

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "ssh-ed25519 AAAA..." ];
      description = "Common SSH authorized keys passed to every agentspace VM.";
    };

    commonWriteFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Common writeFiles entries merged into every agentspace VM.";
    };

    apps = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      default = { };
      description = ''
        Flake app definitions for enabled agentspace VMs, suitable for exposing
        from a consuming flake's `apps.<system>` output.
      '';
    };

    impermanence = {
      enable = lib.mkEnableOption "impermanence persistence for agentspace VMs";

      input = lib.mkOption {
        type = lib.types.raw;
        default = myNixInputs.impermanence or null;
        defaultText = lib.literalExpression "myNixInputs.impermanence";
        description = "impermanence flake input providing nixosModules.impermanence.";
      };

      persistRoot = lib.mkOption {
        type = lib.types.str;
        default = "/persist";
        description = "Guest path used as the impermanence persistent root.";
      };

      hideMounts = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether impermanence bind mounts should be hidden from tools like findmnt.";
      };

      imageName = lib.mkOption {
        type = lib.types.str;
        default = "persist.img";
        description = "Disk image name, stored under each VM's persistence base directory, for the impermanence persistent root.";
      };

      size = lib.mkOption {
        type = lib.types.ints.positive;
        default = 4096;
        description = "Size of the impermanence persistent root disk image in MiB.";
      };

      directories = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        default = [ ];
        example = [ "/var/lib/tailscale" ];
        description = "Guest directories persisted for every agentspace VM.";
      };

      files = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        default = [ ];
        description = "Guest files persisted for every agentspace VM.";
      };
    };

    defaultHmModule = lib.mkOption {
      type = lib.types.raw;
      default = {
        programs.gpg.enable = lib.mkDefault true;
        services.gpg-agent.enable = lib.mkDefault false;
      };
      description = "Default Home Manager module added to every agentspace VM before commonHomeModules and per-VM homeModules.";
    };

    defaultNixosModule = lib.mkOption {
      type = lib.types.raw;
      default = {
        services.openssh.settings = {
          AllowStreamLocalForwarding = lib.mkDefault "yes";
          AllowTcpForwarding = lib.mkDefault "yes";
          DisableForwarding = lib.mkDefault false;
          StreamLocalBindUnlink = lib.mkDefault "yes";
        };

        systemd.tmpfiles.rules = [
          "d /run/user/1000 0700 agent users - -"
          "d /run/user/1000/gnupg 0700 agent users - -"
          "r /run/user/1000/gnupg/S.gpg-agent - - - - -"
        ];

        systemd.services.agentspace-tmpfiles-create = {
          description = "Create agentspace runtime tmpfiles";
          wantedBy = [ "multi-user.target" ];
          after = [ "systemd-tmpfiles-setup.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "/run/current-system/systemd/bin/systemd-tmpfiles --create";
          };
        };
      };
      description = "Default NixOS module added to every agentspace VM after built-in defaults and before commonNixosModules/per-VM extraModules.";
    };

    commonHomeModules = lib.mkOption {
      type = lib.types.listOf lib.types.raw;
      default = [ ];
      description = "Home Manager modules added to every agentspace VM declared by this module after defaultHmModule.";
    };

    commonNixosModules = lib.mkOption {
      type = lib.types.listOf lib.types.raw;
      default = [ ];
      description = "NixOS modules added to every agentspace VM declared by this module after defaultNixosModule.";
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
      {
        assertion = !cfg.impermanence.enable || impermanenceInput != null;
        message = "fr.agentspace.impermanence.input must be set, or pass flake inputs as _module.args.myNixInputs.";
      }
    ];

    fr.agentspace.apps = mkVmApps {
      agentspace = agentspaceInput;
      inherit lib;
      systems = mkVmSystems {
        agentspace = agentspaceInput;
        inherit lib;
        vms = enabledVms;
      };
    };

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
            ForwardAgent = if vmCfg.sshConnect.sshAgentForwarding then "yes" else "no";
            CheckHostIP = "no";
            StrictHostKeyChecking = "no";
            UserKnownHostsFile = "/dev/null";
            GlobalKnownHostsFile = "/dev/null";
          }
          // lib.optionalAttrs vmCfg.sshConnect.gpgAgentForwarding.enable {
            # TODO: Consider native socket sharing via VM mounts instead of SSH
            # RemoteForward if agentspace/microvm supports that cleanly.
            StreamLocalBindUnlink = "yes";
            RemoteForward = "${vmCfg.sshConnect.gpgAgentForwarding.remoteSocket} ${vmCfg.sshConnect.gpgAgentForwarding.localSocket}";
          };
        };
      }) sshVms;
    };
  };
}
