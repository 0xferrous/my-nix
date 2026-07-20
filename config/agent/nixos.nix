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
  devEssentialsPackages = import ../shared/packages/dev-essentials.nix { inherit pkgs; };
  impermanenceRoot = "/persist";
  binaryCaches = [
    {
      url = "http://10.0.2.2:5000?priority=30";
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
    ];
    substituters = map (cache: cache.url) binaryCaches;
    trusted-public-keys = map (cache: cache.key) binaryCaches;
    trusted-substituters = map (cache: cache.url) binaryCaches;
  };

  environment.sessionVariables = {
    EDITOR = "nvim";
    HARMONIA_CACHE_URL = "http://10.0.2.2:5000";
  };

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

  # dbus-broker live-reloads policy when the Nix store overlay changes during a
  # switch. In the agent VM this can briefly observe missing config symlinks and
  # leave the bus with a policy that denies even root's systemd calls.
  services.dbus.implementation = "dbus";

  services.resolved = {
    enable = true;
    settings.Resolve = {
      Cache = "yes";
      DNSOverTLS = "opportunistic";
      DNSSEC = "allow-downgrade";
      DNSStubListener = "yes";
      FallbackDNS = [
        "1.1.1.1#cloudflare-dns.com"
        "1.0.0.1#cloudflare-dns.com"
        "9.9.9.9#dns.quad9.net"
        "149.112.112.112#dns.quad9.net"
      ];
    };
  };
  services.tailscale.enable = true;

  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];

  environment.shells = [ pkgs.nushell ];

  users.users.agent = {
    isNormalUser = true;
    uid = 1000;
    group = "users";
    home = "/home/agent";
    createHome = true;
    shell = pkgs.nushell;
    extraGroups = [ "wheel" ];
    hashedPassword = "!";
  };

  security.sudo.wheelNeedsPassword = false;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit myNixInputs;
    };
    users.agent =
      { ... }:
      {
        imports = [
          ../../modules/home/programs/direnv.nix
          ../../modules/home/programs/foundry.nix
        ];

        home.stateVersion = "26.05";

        programs.devenv = {
          enable = true;
          enableNushellIntegration = true;
        };

        programs.fzf = {
          enable = true;
          enableNushellIntegration = true;
        };

        programs.carapace = {
          enable = true;
          enableNushellIntegration = true;
        };

        programs.nix-your-shell = {
          enable = true;
          enableNushellIntegration = true;
        };

        programs.nushell = {
          enable = true;
          environmentVariables.DEVENV_SHELL_TYPE = "nu";
          settings.show_banner = false;
        };

        programs.zoxide = {
          enable = true;
          enableNushellIntegration = true;
          enableZshIntegration = lib.mkForce false;
          options = [
            "--cmd"
            "cd"
          ];
        };

        fr.direnv = {
          enable = true;
          devenv.enable = true;
          poetry.enable = true;
          layoutDir = {
            enable = true;
            baseDir = "/home/agent/.cache/direnv/layouts";
          };
        };
      };
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

  fileSystems."/nix/.ro-store" = {
    device = "ro-store";
    fsType = "virtiofs";
    neededForBoot = true;
    options = [ "ro" ];
  };

  fileSystems."/run/ash/shares/ro" = {
    device = "shares-ro";
    fsType = "virtiofs";
    neededForBoot = true;
    options = [ "ro" ];
  };

  fileSystems."/run/ash/shares/rw" = {
    device = "shares-rw";
    fsType = "virtiofs";
    neededForBoot = true;
  };

  fileSystems."/nix/store" = {
    neededForBoot = true;
    # VirtioFS cannot store trusted.overlay.* xattrs, but it can store
    # user.overlay.* xattrs. userxattr tells overlayfs to use the latter, which
    # lets the host-backed share act as the writable upper layer.
    options = [ "userxattr" ];
    overlay = {
      lowerdir = [ "/nix/.ro-store" ];
      upperdir = "/run/ash/shares/rw/guest-store-upper";
      workdir = "/run/ash/shares/rw/guest-store-work";
    };
  };

  fileSystems.${impermanenceRoot} = {
    device = "/dev/disk/by-label/persist";
    fsType = "ext4";
    neededForBoot = true;
  };

  environment.persistence.${impermanenceRoot} = {
    directories = [
      "/nix/var/nix"
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
      ".config/jj"
      ".config/pypoetry"
      ".foundry"
      ".local/state/nix"
      ".local/share/pypoetry"
      ".local/share/uv"
      ".local/share/zoxide"
      ".pi"
      ".supermaven"
    ];
  };

  system.stateVersion = "26.05";
}
