{
  lib,
  pkgs,
  home-manager,
  impermanence,
  myNixInputs,
  nix-index-database,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  AIPackages = myNixInputs.llm-agents.packages.${system};
  agentPortalWrappers = myNixInputs.ash.packages.${system}.agent-portal-wrappers;
  impermanenceRoot = "/persist";
  ashHostCacheUrl = "http://192.168.127.1:5000";
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
    ../../modules/nixos/ash-vm-mdns.nix
    myNixInputs.ash-stable.nixosModules.ashGuest
    impermanence.nixosModules.impermanence
    nix-index-database.nixosModules.nix-index
  ];

  virtualisation.ash-guest = {
    enable = true;
    user = "agent";
    emptyPassword = false;
    sshReadySignal = {
      afterUnits = [ "agent-home-switch.service" ];
      requiredUnits = [ "agent-home-switch.service" ];
    };
  };

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

  # Allow only the unfree ChatGPT/Codex desktop app (codex-desktop); the rest
  # of the agent VM stays on free software.
  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "codex-desktop";

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

  # nix (via libgit2) refuses to open git repos not owned by the current user.
  # The my-nix workspace share is owned by `agent`, but agent-auto-switch runs
  # as root, so mark the repo safe in the system gitconfig.
  environment.etc."gitconfig".text = ''
    [safe]
      directory = /home/agent/dev/fr/my-nix
  '';

  environment.sessionVariables = {
    EDITOR = "nvim";
    HARMONIA_CACHE_URL = ashHostCacheUrl;
    PLANNOTATOR_REMOTE = "1";
    PLANNOTATOR_PORT = "19432";
    # Route agent-tool HTTP(S) egress through the host iron-proxy tunnel so it
    # can inject real credentials; the proxy is configured with secrets-only
    # transforms (no allowlist), so nothing is blocked. The Ash bridge, host
    # cache (192.168.127.1:5000), mDNS, and Tailscale stay in NO_PROXY.
    HTTP_PROXY = "http://192.168.127.1:8080";
    HTTPS_PROXY = "http://192.168.127.1:8080";
    ALL_PROXY = "http://192.168.127.1:8080";
    http_proxy = "http://192.168.127.1:8080";
    https_proxy = "http://192.168.127.1:8080";
    all_proxy = "http://192.168.127.1:8080";
    NO_PROXY = "localhost,127.0.0.0/8,192.168.127.0/24,.ash.local,.ts.net,100.64.0.0/10";
    no_proxy = "localhost,127.0.0.0/8,192.168.127.0/24,.ash.local,.ts.net,100.64.0.0/10";
    # rustls-based tools (obscura, etc.) ignore the system trust store and
    # default to bundled webpki roots; point them at the NixOS bundle, which
    # includes the iron-proxy CA via security.pki.certificateFiles below, so
    # HTTPS through the MITM tunnel verifies.
    SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
    # Node does not consult the system trust store; point it at the iron-proxy
    # MITM CA so bundled/proxied HTTPS (and injected credentials) verify in
    # Node-based tooling too (e.g. the codex-desktop bundled node runtime).
    NODE_EXTRA_CA_CERTS = ../../modules/nixos/iron-proxy-ca.crt;
  };

  # Trust the host iron-proxy MITM CA so proxied HTTPS (and the injected
  # credentials) verify cleanly in the guest. The cert is committed next to
  # the fr.iron-proxy module; the matching private key never leaves the host.
  security.pki.certificateFiles = [ ../../modules/nixos/iron-proxy-ca.crt ];

  # Agent workloads commonly run many file watchers and subprocesses in the
  # same long-lived SSH or user-systemd session. Keep their descriptor ceiling
  # comfortably above systemd's default and apply it consistently to services,
  # user services, and PAM-created login sessions.
  systemd.settings.Manager.DefaultLimitNOFILE = "1048576:1048576";
  systemd.user.settings.Manager.DefaultLimitNOFILE = "1048576:1048576";

  # Electron workloads such as codex-desktop can exceed the agent VM's 4 GiB
  # of RAM. Compressed swap prevents the kernel from killing renderers under
  # short-lived memory pressure without requiring persistent disk swap.
  zramSwap = {
    enable = true;
    memoryPercent = 100;
  };

  security.pam.loginLimits = [
    {
      domain = "*";
      type = "-";
      item = "nofile";
      value = "1048576";
    }
  ];

  environment.systemPackages = with pkgs; [
    kitty.terminfo
    poetry
    python3
    uv
    AIPackages.codex
    AIPackages.opencode
    codex-desktop
    home-manager
    frsNvimPackage
    ironclaw
    agentPortalWrappers
  ];

  environment.shellAliases = {
    vi = "nvim";
    vim = "nvim";
    vimdiff = "nvim -d";
  };

  fr.ash-vm-mdns.enable = true;

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

  # Self-update: rebuild this VM from the my-nix flake right after boot so
  # config changes made on the host reach the VM without manual steps. The
  # timers fire almost immediately; the services wait on their real
  # prerequisites (network-online, nix-daemon, the my-nix share) instead of
  # delaying the trigger. The workspace share is a plain virtiofs mount
  # created by Ash after boot (it only appears in /proc/self/mountinfo, not as
  # a systemd mount unit), so poll for it rather than ordering after a unit.
  # Every echo and all of the nixos-rebuild output lands in journald under
  # this unit for debugging.
  #
  # Deliberately NOT wantedBy multi-user.target: a switch's activation
  # re-triggers multi-user.target, which NixOS orders after its wantedBy
  # units, so a switch running inside such a unit deadlocks on its own
  # activation. A boot timer decouples the switch from that transaction.
  systemd.timers.agent-auto-switch = {
    description = "Trigger the agent NixOS self-update right after boot";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "0s";
    };
  };

  systemd.services.agent-auto-switch = {
    description = "Rebuild agent NixOS from the my-nix flake";
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "nix-daemon.service"
      # The NixOS switch runs after the fast, user-level home-manager switch:
      # it re-triggers multi-user.target and restarts sshd, so it stays last.
      "agent-home-switch.service"
    ];
    environment.NO_COLOR = "1";
    serviceConfig = {
      Type = "oneshot";
      # Rebuilds can be slow on a cold cache; never let systemd kill them.
      TimeoutStartSec = "infinity";
    };
    script = ''
      echo "agent-auto-switch: starting, waiting for my-nix share"
      attempts=0
      while [ "$attempts" -lt 60 ]; do
        if ${pkgs.util-linux}/bin/findmnt /home/agent/dev/fr/my-nix >/dev/null 2>&1; then
          break
        fi
        attempts=$((attempts + 1))
        echo "agent-auto-switch: my-nix share not mounted yet (attempt $attempts/60); retrying in 5s"
        ${pkgs.coreutils}/bin/sleep 5
      done
      if [ "$attempts" -ge 60 ]; then
        echo "agent-auto-switch: my-nix share did not appear after 60 attempts (300s); aborting" >&2
        exit 1
      fi
      echo "agent-auto-switch: my-nix share is up"

      # nixos-rebuild-ng activates through a fixed-name transient unit
      # (nixos-rebuild-switch-to-configuration.service). If a switch is already
      # activating (e.g. a manual one), skip instead of colliding with it.
      if ${pkgs.systemd}/bin/systemctl is-active --quiet nixos-rebuild-switch-to-configuration.service 2>/dev/null; then
        echo "agent-auto-switch: a switch is already activating; skipping this run" >&2
        exit 0
      fi

      # Serialize with any other instance of this service.
      ${pkgs.util-linux}/bin/flock -n /run/agent-auto-switch.lock ${pkgs.bash}/bin/bash -c '
        set -e
        echo "agent-auto-switch: starting nixos-rebuild switch"
        ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch \
          --flake /home/agent/dev/fr/my-nix#agent \
          --accept-flake-config
        echo "agent-auto-switch: switch completed successfully"
      '
      rc=$?
      if [ "$rc" -ne 0 ]; then
        echo "agent-auto-switch: switch failed (or lock busy); see journal for details" >&2
        exit "$rc"
      fi
    '';
  };

  # Home-manager is deliberately NOT wired into nixos-rebuild (the NixOS module
  # was removed); the agent home config is rebuilt by this boot timer instead.
  # The home switch runs first (fast, user-level, no sshd disruption) and the
  # NixOS switch is ordered after it.
  systemd.timers.agent-home-switch = {
    description = "Trigger the agent home-manager rebuild after the NixOS switch";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "0s";
    };
  };

  systemd.services.agent-home-switch = {
    description = "Rebuild agent home-manager config from the my-nix flake";
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "nix-daemon.service"
    ];
    path = [
      pkgs.home-manager
      pkgs.nix
      pkgs.git
    ];
    environment = {
      NO_COLOR = "1";
      # Activation runs as the agent user and needs the user session bus.
      XDG_RUNTIME_DIR = "/run/user/1000";
      DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1000/bus";
      NIX_CONFIG = "accept-flake-config = true";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "agent";
      TimeoutStartSec = "infinity";
    };
    script = ''
      echo "agent-home-switch: starting, waiting for my-nix share"
      attempts=0
      while [ "$attempts" -lt 60 ]; do
        if ${pkgs.util-linux}/bin/findmnt /home/agent/dev/fr/my-nix >/dev/null 2>&1; then
          break
        fi
        attempts=$((attempts + 1))
        echo "agent-home-switch: my-nix share not mounted yet (attempt $attempts/60); retrying in 5s"
        ${pkgs.coreutils}/bin/sleep 5
      done
      if [ "$attempts" -ge 60 ]; then
        echo "agent-home-switch: my-nix share did not appear after 60 attempts (300s); aborting" >&2
        exit 1
      fi
      echo "agent-home-switch: my-nix share is up; starting home-manager switch"

      # The timer fires right after boot, so the user session bus may not be up
      # yet; home-manager activation needs it for systemctl --user.
      attempts=0
      while [ ! -S /run/user/1000/bus ]; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 60 ]; then
          echo "agent-home-switch: user session bus not found after 60s; continuing anyway" >&2
          break
        fi
        ${pkgs.coreutils}/bin/sleep 1
      done

      ${pkgs.util-linux}/bin/flock -n /run/user/1000/agent-home-switch.lock ${pkgs.bash}/bin/bash -c '
        set -e
        echo "agent-home-switch: running home-manager switch"
        ${pkgs.home-manager}/bin/home-manager switch \
          --flake /home/agent/dev/fr/my-nix#agent
        echo "agent-home-switch: switch completed successfully"
      '
      rc=$?
      if [ "$rc" -ne 0 ]; then
        echo "agent-home-switch: switch failed (or lock busy); see journal for details" >&2
        exit "$rc"
      fi
    '';
  };

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

  boot.kernel.sysctl = {
    "fs.inotify.max_queued_events" = 65536;
    "fs.inotify.max_user_instances" = 1048576;
    "fs.inotify.max_user_watches" = 2097152;
    "kernel.unprivileged_userns_clone" = 1;
    "vm.vfs_cache_pressure" = 1000;
  };

  services.journald.storage = "persistent";

  environment.persistence.${impermanenceRoot} = {
    files = [
      "/etc/machine-id"
    ];
    directories = [
      "/var/lib/nixos"
      "/var/lib/tailscale"
      "/var/log/journal"
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
      ".config/sops"
      ".config/nushell"
      ".foundry"
      ".ironclaw"
      ".local/state/nix"
      ".local/share/pypoetry"
      ".local/share/uv"
      ".local/share/zoxide"
      ".omp"
      ".pi"
      ".prime"
      ".ssh"
      ".supermaven"
    ];
  };

  system.stateVersion = "26.05";
}
