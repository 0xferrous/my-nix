{
  config,
  lib,
  pkgs,
  home-manager,
  myNixInputs,
  nix-index-database,
  impermanence,
  includeCodexDesktop ? true,
  useCustomNushell ? true,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  AIPackages = myNixInputs.llm-agents.packages.${system};
  nvimPackage = if config.boot.isContainer then pkgs.neovim else pkgs.frsNvimPackage;
  impermanenceRoot = "/persist";
  cfg = config.fr.agent.selfUpdate;
  binaryCaches = [
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
  options.fr.agent.impermanence.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Persist the agent state through impermanence.";
  };

  options.fr.agent.selfUpdate = {
    enable = lib.mkEnableOption "automatic agent NixOS and Home Manager updates";
    workspace = lib.mkOption {
      type = lib.types.str;
      default = "/home/agent/dev/fr/my-nix";
      description = "Mounted flake workspace used for automatic updates.";
    };
    nixosTarget = lib.mkOption {
      type = lib.types.str;
      default = "agent";
      description = "NixOS configuration selected by the automatic system update.";
    };
    homeTarget = lib.mkOption {
      type = lib.types.str;
      default = "agent";
      description = "Home Manager configuration selected by the automatic user update.";
    };
  };

  imports = [
    impermanence.nixosModules.impermanence
    nix-index-database.nixosModules.nix-index
  ];

  config = {
    nixpkgs.overlays = [
      (import ../../pkgs/overlay.nix {
        inputs = myNixInputs;
        inherit useCustomNushell;
      })
    ]
    # The patched libgit2 is needed by the Ash workspace VM, but applying it
    # globally to container-style targets forces Nix itself and its test suite
    # to rebuild.
    ++ lib.optional (!config.boot.isContainer) (
      _final: prev: {
        libgit2 = prev.libgit2.overrideAttrs {
          src = myNixInputs.libgit2-patched;
        };
      }
    );

    # Allow only the unfree ChatGPT/Codex desktop app (codex-desktop); the rest
    # of the agent VM stays on free software.
    nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "codex-desktop";
    nixpkgs.config.permittedInsecurePackages = [
      "gradle-7.6.6"
      "pnpm-9.15.9"
    ];

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = map (cache: cache.url) binaryCaches;
      trusted-public-keys = map (cache: cache.key) binaryCaches;
      trusted-substituters = map (cache: cache.url) binaryCaches;
    };

    environment.sessionVariables = {
      EDITOR = "nvim";
      PLANNOTATOR_REMOTE = "1";
      PLANNOTATOR_PORT = "19432";
    };

    # Agent workloads commonly run many file watchers and subprocesses in the
    # same long-lived SSH or user-systemd session. Keep their descriptor ceiling
    # comfortably above systemd's default and apply it consistently to services,
    # user services, and PAM-created login sessions.
    systemd.settings.Manager.DefaultLimitNOFILE = "1048576:1048576";
    systemd.user.settings.Manager.DefaultLimitNOFILE = "1048576:1048576";

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

    fonts.packages = with pkgs; [
      recursive
      nerd-fonts.recursive-mono
    ];

    environment.systemPackages =
      with pkgs;
      [
        git
        kitty.terminfo
        nix
        nh
        poetry
        python3
        uv
        AIPackages.codex
        AIPackages.opencode
        home-manager
        nvimPackage
      ]
      ++ lib.optional includeCodexDesktop codex-desktop
      ++ lib.optional (system == "x86_64-linux") pkgs.ironclaw;

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

    services.tailscale.enable = true;
    services.journald.storage = "persistent";

    systemd.timers.agent-auto-switch = lib.mkIf cfg.enable {
      description = "Trigger the agent NixOS self-update right after boot";
      wantedBy = [ "timers.target" ];
      timerConfig.OnBootSec = "0s";
    };

    systemd.services.agent-auto-switch = lib.mkIf cfg.enable {
      description = "Rebuild agent NixOS from the configured flake";
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "nix-daemon.service"
        "agent-home-switch.service"
      ];
      environment.NO_COLOR = "1";
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "infinity";
      };
      script = ''
        echo "agent-auto-switch: starting, waiting for flake workspace"
        attempts=0
        while [ "$attempts" -lt 60 ]; do
          if ${pkgs.util-linux}/bin/findmnt ${lib.escapeShellArg cfg.workspace} >/dev/null 2>&1; then
            break
          fi
          attempts=$((attempts + 1))
          echo "agent-auto-switch: flake workspace not mounted yet (attempt $attempts/60); retrying in 5s"
          ${pkgs.coreutils}/bin/sleep 5
        done
        if [ "$attempts" -ge 60 ]; then
          echo "agent-auto-switch: flake workspace did not appear after 300s; aborting" >&2
          exit 1
        fi

        if ${pkgs.systemd}/bin/systemctl is-active --quiet nixos-rebuild-switch-to-configuration.service 2>/dev/null; then
          echo "agent-auto-switch: a switch is already activating; skipping this run" >&2
          exit 0
        fi

        ${pkgs.util-linux}/bin/flock -n /run/agent-auto-switch.lock ${pkgs.bash}/bin/bash -c '
          set -e
          ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch \
            --flake ${lib.escapeShellArg "${cfg.workspace}#${cfg.nixosTarget}"} \
            --accept-flake-config
        '
      '';
    };

    systemd.timers.agent-home-switch = lib.mkIf cfg.enable {
      description = "Trigger the agent Home Manager rebuild after the NixOS switch";
      wantedBy = [ "timers.target" ];
      timerConfig.OnBootSec = "0s";
    };

    systemd.services.agent-home-switch = lib.mkIf cfg.enable {
      description = "Rebuild agent Home Manager config from the configured flake";
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
        echo "agent-home-switch: starting, waiting for flake workspace"
        attempts=0
        while [ "$attempts" -lt 60 ]; do
          if ${pkgs.util-linux}/bin/findmnt ${lib.escapeShellArg cfg.workspace} >/dev/null 2>&1; then
            break
          fi
          attempts=$((attempts + 1))
          ${pkgs.coreutils}/bin/sleep 5
        done
        if [ "$attempts" -ge 60 ]; then
          echo "agent-home-switch: flake workspace did not appear after 300s; aborting" >&2
          exit 1
        fi

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
          ${pkgs.home-manager}/bin/home-manager switch \
            --flake ${lib.escapeShellArg "${cfg.workspace}#${cfg.homeTarget}"}
        '
      '';
    };

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

    environment.persistence.${impermanenceRoot} = lib.mkIf config.fr.agent.impermanence.enable {
      files = lib.optional (!config.boot.isContainer) "/etc/machine-id";
      directories = [
        "/var/lib/nixos"
        "/var/lib/tailscale"
        "/var/log/journal"
      ];
      users.agent.files = [ ];
      users.agent.directories = [
        ".cargo"
        ".codex"
        ".config/Codex"
        ".bb"
        ".config/bb"
        ".bb-machines"
        ".foundry"
        ".config/gh"
        ".config/git"
        ".config/herdr"
        ".ironclaw"
        ".t3"
        ".config/T3 Code (Alpha)"
        ".config/t3code"
        ".config/systemd/user"
        ".config/jj"
        ".local/state/nix"
        ".config/nushell"
        ".omp"
        ".config/opencode"
        ".config/ai.opencode.desktop"
        ".config/ai.opencode.desktop.dev"
        ".local/share/opencode"
        ".local/state/opencode"
        ".cache/opencode"
        ".pi"
        ".cache/pypoetry"
        ".config/pypoetry"
        ".local/share/pypoetry"
        ".prime"
        ".config/sops"
        ".ssh"
        ".supermaven"
        ".cache/uv"
        ".local/share/uv"
        ".local/share/zoxide"
      ];
    };

    system.stateVersion = "26.05";
  };
}
