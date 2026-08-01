{
  lib,
  pkgs,
  home-manager,
  impermanence,
  myNixInputs,
  nix-index-database,
  utils,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  AIPackages = myNixInputs.llm-agents.packages.${system};
  agentPortalWrappers = myNixInputs.ash.packages.${system}.agent-portal-wrappers;
  devEssentialsPackages = import ../shared/packages/dev-essentials.nix { inherit pkgs; };
  impermanenceRoot = "/persist";
  lowerStoreUri = "local?real=/nix/.ro-store&state=/run/ash/shares/ro/guest-store-state&read-only=true";
  upperStoreState = "/run/ash/shares/rw/guest-store-state";
  ashHostCacheUrl = "http://192.168.127.1:5000";
  # Keep the writable store database beside its upper layer. Both must have the
  # same lifetime; persisting the database in /nix/var/nix while rebuilding the
  # Ash shares leaves Nix believing deleted upper-layer paths are still valid.
  # The store overlay is mounted in stage 1, so /proc/mounts records its layer
  # paths with /sysroot prefixes. Nix compares them against the post-switch-root
  # paths and incorrectly rejects the otherwise matching mount.
  agentStoreUri = "local-overlay://?state=${lib.escapeURL upperStoreState}&lower-store=${lib.escapeURL lowerStoreUri}&upper-layer=${lib.escapeURL "/run/ash/shares/rw/guest-store-upper"}&check-mount=false";
  binaryCaches = [
    {
      url = "${ashHostCacheUrl}?priority=30";
      key = "nixos-1:TpdALX3FryCxN1I/WG+lhTeme19H/Ka035MJchdsYH4=";
    }
    {
      url = "https://cache.nixos.org";
      key = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
    }
    {
      url = "https://nix-community.cachix.org";
      key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
    }
    {
      url = "https://numtide.cachix.org";
      key = "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=";
    }
    {
      # llm-agents.nix publishes builds to the Numtide Nix cache.
      url = "https://cache.numtide.com";
      key = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
    }
  ];
  opensshSettings = {
    AllowStreamLocalForwarding = lib.mkDefault "yes";
    AllowTcpForwarding = lib.mkDefault "yes";
    DisableForwarding = lib.mkDefault false;
    KbdInteractiveAuthentication = lib.mkDefault false;
    PasswordAuthentication = lib.mkDefault false;
    PermitRootLogin = lib.mkDefault "no";
    StreamLocalBindUnlink = lib.mkDefault "yes";
  };
in
{
  imports = [
    home-manager.nixosModules.home-manager
    impermanence.nixosModules.impermanence
    nix-index-database.nixosModules.nix-index
  ];

  nixpkgs.overlays = [
    (import ../../pkgs/overlay.nix {
      inputs = myNixInputs;
      system = pkgs.stdenv.hostPlatform.system;
    })
    (_final: prev: {
      libgit2 = prev.libgit2.overrideAttrs {
        src = myNixInputs.libgit2-patched;
      };
    })
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "local-overlay-store"
      "read-only-local-store"
    ];
    substituters = map (cache: cache.url) binaryCaches;
    fsync-metadata = false;
    trusted-public-keys = map (cache: cache.key) binaryCaches;
    trusted-substituters = map (cache: cache.url) binaryCaches;
    # SQLite WAL mode fails with disk I/O errors on Ash's writable VirtioFS
    # share, which backs the local-overlay store state database.
    use-sqlite-wal = false;
  };

  environment.etc."ash/local-overlay-store".text = "";

  environment.sessionVariables = {
    EDITOR = "nvim";
    HARMONIA_CACHE_URL = ashHostCacheUrl;
    PLANNOTATOR_REMOTE = "1";
    PLANNOTATOR_PORT = "19432";
  };

  # Agent workloads commonly run many file watchers and subprocesses in the
  # same long-lived SSH or user-systemd session. Keep their descriptor ceiling
  # comfortably above systemd's default and apply it consistently to services,
  # user services, and PAM-created login sessions.
  systemd.settings.Manager.DefaultLimitNOFILE = "1048576:1048576";
  systemd.user.settings.Manager.DefaultLimitNOFILE = "1048576:1048576";
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "-";
      item = "nofile";
      value = "1048576";
    }
  ];

  # Select the daemon store implementation from the transport Ash records on
  # the kernel command line. Shared mode uses the host-backed local-overlay
  # store; image mode uses the regular local store inside the ext4 image.
  environment.etc."ash/nix-daemon".source = pkgs.writeShellScript "ash-nix-daemon" ''
    store_strategy=shared
    for parameter in $(cat /proc/cmdline); do
      case "$parameter" in
        ash.nix-store=shared) store_strategy=shared ;;
        ash.nix-store=image) store_strategy=image ;;
      esac
    done

    if [ "$store_strategy" = image ]; then
      exec ${pkgs.nix}/bin/nix-daemon --daemon
    fi

    # nix-daemon removes NIX_REMOTE from its process environment, so pass the
    # local-overlay store as an explicit Nix setting.
    exec ${pkgs.nix}/bin/nix-daemon --daemon --option store ${lib.escapeShellArg agentStoreUri}
  '';
  systemd.services.nix-daemon.serviceConfig.ExecStart = lib.mkForce [
    ""
    "/etc/ash/nix-daemon"
  ];

  environment.systemPackages =
    (with pkgs; [
      kitty.terminfo
      pi
      poetry
      python3
      uv
      AIPackages.codex
      AIPackages.opencode
      home-manager
      frsNvimPackage
      ironclaw
      agentPortalWrappers
    ])
    ++ devEssentialsPackages;

  environment.shellAliases = {
    vi = "nvim";
    vim = "nvim";
    vimdiff = "nvim -d";
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;
  programs.nix-ld.enable = true;

  services.openssh = {
    enable = true;
    settings = opensshSettings;
  };

  systemd.services.virtle-ssh-signal = {
    wantedBy = [ "multi-user.target" ];
    requires = [ "sshd.service" ];
    after = [ "sshd.service" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "70s";
    };
    script = ''
      for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
        if [ -e /dev/virtio-ports/virtle.ready ]; then
          # Writing to this virtio console port blocks forever if the host side
          # is not currently reading it (e.g. during nixos-rebuild switch).
          ${pkgs.coreutils}/bin/timeout 2s ${pkgs.bash}/bin/bash -c \
            '${pkgs.coreutils}/bin/echo SSH-READY > /dev/virtio-ports/virtle.ready' \
            || echo "virtle ready port write timed out" >&2
          exit 0
        fi
        ${pkgs.coreutils}/bin/sleep 1
      done
      echo "virtle ready port did not appear" >&2
      exit 0
    '';
  };

  services.getty.autologinUser = "agent";
  services.qemuGuest.enable = true;
  # Virtle's SSH autoprovision action asks QGA to execute `sh` by name.
  systemd.services.qemu-guest-agent.path = [ pkgs.bash ];

  # dbus-broker live-reloads policy when the Nix store overlay changes during a
  # switch. In the agent VM this can briefly observe missing config symlinks and
  # leave the bus with a policy that denies even root's systemd calls.
  services.dbus.implementation = "dbus";

  services.resolved = {
    enable = true;
    settings.Resolve = {
      Cache = "yes";
      DNSOverTLS = "yes";
      DNSSEC = "allow-downgrade";
      DNSStubListener = "yes";
      DNS = [
        "1.1.1.1#cloudflare-dns.com"
        "1.0.0.1#cloudflare-dns.com"
      ];
      FallbackDNS = [
        "1.1.1.1#cloudflare-dns.com"
        "1.0.0.1#cloudflare-dns.com"
        "9.9.9.9#dns.quad9.net"
        "149.112.112.112#dns.quad9.net"
      ];
    };
  };
  services.tailscale.enable = true;

  # Agent VMs run behind the host-only Ash bridge. Allow host access to any
  # service started inside the guest without maintaining a per-port allowlist.
  networking.firewall.enable = false;
  networking.nameservers = lib.mkForce [ ];

  environment.shells = [ pkgs.nushell ];

  users.users.agent = {
    isNormalUser = true;
    uid = 1000;
    group = "users";
    home = "/home/agent";
    createHome = true;
    linger = true;
    shell = pkgs.nushell;
    extraGroups = [ "wheel" ];
    hashedPassword = "!";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGIBIABk26sFfyg3iuOTK+6iZ2RhkiNXEJZ8wmgDUrhB"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit myNixInputs;
    };
    users.agent = import ./home.nix;
  };

  systemd.tmpfiles.rules = [
    "d /run/user/1000 0700 agent users - -"
    "d /run/user/1000/gnupg 0700 agent users - -"
    "r /run/user/1000/gnupg/S.gpg-agent - - - - -"
  ];

  systemd.services.agent-tmpfiles-create = {
    description = "Create agent runtime tmpfiles";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/run/current-system/systemd/bin/systemd-tmpfiles --create";
    };
  };

  boot.loader.grub.enable = false;

  # Keep stage-1 failures debuggable from Ash's interactive serial console.
  boot.initrd.systemd.emergencyAccess = true;

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtiofs"
    "overlay"
    "virtio_console"
    "vsock"
    "vmw_vsock_virtio_transport"
    "ext4"
  ];

  boot.kernelModules = [
    "virtio_console"
    "vsock"
    "vmw_vsock_virtio_transport"
  ];

  boot.kernel.sysctl = {
    "fs.inotify.max_queued_events" = 65536;
    "fs.inotify.max_user_instances" = 1048576;
    "fs.inotify.max_user_watches" = 2097152;
    "kernel.unprivileged_userns_clone" = 1;
    "vm.vfs_cache_pressure" = 1000;
  };

  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "mode=0755"
      "size=2G"
    ];
  };

  # Ash appends ash.nix-store=shared|image to the kernel command line. Enable
  # only the matching root mount during stage 1. The image mount unit must not
  # exist in shared mode: systemd otherwise makes mounts below /sysroot/nix
  # depend implicitly on that parent mount and its block device.
  boot.initrd.systemd.contents."/etc/systemd/system-generators/ash-nix-store-generator".source =
    pkgs.writeShellScript "ash-nix-store-generator" ''
      store_strategy=shared
      for parameter in $(cat /proc/cmdline); do
        case "$parameter" in
          ash.nix-store=shared) store_strategy=shared ;;
          ash.nix-store=image) store_strategy=image ;;
        esac
      done

      case "$store_strategy" in
        shared)
          mount_unit=sysroot-nix-store.mount
          mount_unit_path="/etc/systemd/system/$mount_unit"
          ;;
        image)
          mount_unit=sysroot-nix.mount
          mount_unit_path="$1/$mount_unit"
          cat > "$mount_unit_path" <<'EOF'
      [Unit]
      DefaultDependencies=false
      Before=initrd-fs.target

      [Mount]
      What=/dev/disk/by-label/nix-store
      Where=/sysroot/nix
      Type=ext4
      EOF
          ;;
      esac

      wants_dir="$1/initrd-fs.target.requires"
      mkdir -p "$wants_dir"
      ln -s "$mount_unit_path" "$wants_dir/$mount_unit"
    '';

  boot.initrd.systemd.mounts =
    let
      sharedCondition = [ "ash.nix-store=shared" ];
      initrdMount =
        condition: mount:
        {
          unitConfig = {
            DefaultDependencies = false;
            ConditionKernelCommandLine = condition;
          };
          before = [ "initrd-fs.target" ];
        }
        // mount;
      sharedMountPaths = [
        "/sysroot/nix/.ro-store"
        "/sysroot/run/ash/shares/ro"
        "/sysroot/run/ash/shares/rw"
      ];
      sharedMountUnits = map (path: "${utils.escapeSystemdPath path}.mount") sharedMountPaths;
    in
    [
      (initrdMount sharedCondition {
        what = "ro-store";
        where = "/sysroot/nix/.ro-store";
        type = "virtiofs";
        options = "ro";
      })
      (initrdMount sharedCondition {
        what = "shares-ro";
        where = "/sysroot/run/ash/shares/ro";
        type = "virtiofs";
        options = "ro";
      })
      (initrdMount sharedCondition {
        what = "shares-rw";
        where = "/sysroot/run/ash/shares/rw";
        type = "virtiofs";
      })
      (initrdMount sharedCondition {
        what = "overlay";
        where = "/sysroot/nix/store";
        type = "overlay";
        options = lib.concatStringsSep "," [
          "lowerdir=/sysroot/nix/.ro-store"
          "upperdir=/sysroot/run/ash/shares/rw/guest-store-upper"
          "workdir=/sysroot/run/ash/shares/rw/guest-store-work"
          "userxattr"
        ];
        requires = sharedMountUnits;
        after = sharedMountUnits;
      })
    ];

  fileSystems.${impermanenceRoot} = {
    device = "/dev/disk/by-label/persist";
    fsType = "ext4";
    neededForBoot = true;
  };

  # Shared mode keeps /nix on tmpfs, so persist its regular Nix state. Image
  # mode must leave /nix/var/nix on the Nix store image; otherwise this bind
  # mount shadows the image database that Ash initializes after boot.
  systemd.services.ash-prepare-shared-nix-state = {
    requiredBy = [ "nix-var-nix.mount" ];
    requires = [ "persist.mount" ];
    after = [ "persist.mount" ];
    before = [ "nix-var-nix.mount" ];
    unitConfig = {
      ConditionKernelCommandLine = [ "ash.nix-store=shared" ];
      DefaultDependencies = false;
    };
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.coreutils}/bin/install -d -m 0755 \
        ${impermanenceRoot}/nix/var/nix /nix/var/nix
    '';
  };

  systemd.mounts = [
    {
      wantedBy = [ "local-fs.target" ];
      requires = [ "ash-prepare-shared-nix-state.service" ];
      after = [ "ash-prepare-shared-nix-state.service" ];
      before = [ "local-fs.target" ];
      where = "/nix/var/nix";
      what = "${impermanenceRoot}/nix/var/nix";
      type = "none";
      options = "bind";
      unitConfig = {
        ConditionKernelCommandLine = [ "ash.nix-store=shared" ];
        DefaultDependencies = false;
      };
    }
  ];

  environment.persistence.${impermanenceRoot} = {
    directories = [
      "/var/lib/nixos"
      "/var/lib/tailscale"
    ];
    users.agent.files = [
    ];
    users.agent.directories = [
      ".cache/pypoetry"
      ".cache/uv"
      ".cargo"
      ".codex"
      ".config/gh"
      ".config/git"
      ".config/herdr"
      # IronClaw generates and enables its user unit in this directory.
      ".config/systemd/user"
      ".config/jj"
      ".config/pypoetry"
      ".foundry"
      ".ironclaw"
      ".local/state/nix"
      ".local/share/pypoetry"
      ".local/share/uv"
      ".local/share/zoxide"
      ".pi"
      ".ssh"
      ".supermaven"
    ];
  };

  system.stateVersion = "26.05";
}
