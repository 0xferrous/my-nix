# Copied/adapted from https://github.com/shazow/nixfiles/blob/main/modules/virtiofsd-nix-store.nix
# virtiofsd for /nix/store with socket activation to be run as root.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.fr.virtiofs-nix-store;
  nixStoreShareSocketPath = (import ../common.nix).nixStoreShareSocketPath;
in
{
  options.fr.virtiofs-nix-store = {
    enable = mkEnableOption "virtiofsd for read-only /nix/store share";

    socketGroup = mkOption {
      type = types.str;
      default = "kvm";
      description = "Group owning the virtiofsd socket";
    };

    ownHardening = mkOption {
      type = types.bool;
      default = false;
      description = "Disable virtiofsd's native hardening and have systemd do it instead";
    };
  };

  config = mkIf cfg.enable {
    systemd.sockets."virtiofs-nix-store" = {
      description = "Socket for virtiofsd /nix/store read-only share";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = nixStoreShareSocketPath;
        SocketGroup = cfg.socketGroup;
        SocketMode = "0660";
      };
    };

    systemd.services."virtiofs-nix-store" = {
      description = "virtiofsd for /nix/store";
      requires = [ "virtiofs-nix-store.socket" ];
      after = [ "virtiofs-nix-store.socket" ];

      serviceConfig = mkMerge [
        {
          Type = "simple";
          User = "root";
          Group = "root";
          LimitNOFILE = 1048576;

          ExecStart = pkgs.writeShellScript "virtiofsd-wrapper" ''
            exec ${pkgs.virtiofsd}/bin/virtiofsd \
              --fd=3 \
              --shared-dir=/nix/store \
              --thread-pool-size $(${pkgs.coreutils}/bin/nproc) \
              --posix-acl \
              --xattr \
              --cache=auto \
              --inode-file-handles=mandatory \
              --sandbox=${if cfg.ownHardening then "none" else "namespace"} \
              --readonly
          '';
        }
        (mkIf cfg.ownHardening {
          # Systemd-native hardening options
          PrivateDevices = true;
          PrivateNetwork = true;
          PrivateTmp = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectSystem = "strict";
          ReadOnlyPaths = [ "/nix/store" ];

          # TODO: Maybe move some of these to be included unconditionally?
          RestrictAddressFamilies = [ "AF_UNIX" ];
          ProtectHostname = true;
          ProtectClock = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          NoNewPrivileges = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
        })
      ];
    };
  };
}
