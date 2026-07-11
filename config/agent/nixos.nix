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

  environment.systemPackages = with pkgs; [
    git
    jujutsu
    kitty.terminfo
    pi
    poetry
    python3
    uv
    AIPackages.codex
    AIPackages.opencode
    frsNvimPackage
  ];

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
    serviceConfig.Type = "oneshot";
    script = ''
      for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
        if [ -e /dev/virtio-ports/virtle.ready ]; then
          ${pkgs.coreutils}/bin/echo SSH-READY > /dev/virtio-ports/virtle.ready
          exit 0
        fi
        ${pkgs.coreutils}/bin/sleep 1
      done
      echo "virtle ready port did not appear" >&2
      exit 1
    '';
  };

  services.getty.autologinUser = "agent";
  services.qemuGuest.enable = true;
  services.resolved = {
    enable = true;
    dnssec = "allow-downgrade";
    dnsovertls = "opportunistic";
    fallbackDns = [
      "1.1.1.1#cloudflare-dns.com"
      "1.0.0.1#cloudflare-dns.com"
      "9.9.9.9#dns.quad9.net"
      "149.112.112.112#dns.quad9.net"
    ];
    settings.Resolve = {
      Cache = "yes";
      DNSStubListener = "yes";
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
    users.agent = { ... }: {
      imports = [
        ../../modules/home/programs/direnv.nix
        ../../modules/home/programs/foundry.nix
      ];

      home.stateVersion = "26.05";

      programs.devenv = {
        enable = true;
        enableNushellIntegration = true;
      };

      programs.fzf.enableNushellIntegration = true;

      programs.nix-your-shell = {
        enable = true;
        enableNushellIntegration = true;
      };

      programs.nushell = {
        enable = true;
        environmentVariables.DEVENV_SHELL_TYPE = "nu";
      };

      programs.zoxide = {
        enable = true;
        enableZshIntegration = lib.mkForce false;
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

  fileSystems."/nix/store" = {
    neededForBoot = true;
    overlay = {
      lowerdir = [ "/nix/.ro-store" ];
      upperdir = "${impermanenceRoot}/nix-store-overlay/upper";
      workdir = "${impermanenceRoot}/nix-store-overlay/work";
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
    users.agent.directories = [
      ".cache/pypoetry"
      ".cache/uv"
      ".cargo"
      ".codex"
      ".config/pypoetry"
      ".foundry"
      ".local/share/pypoetry"
      ".local/share/uv"
      ".pi"
    ];
  };

  system.stateVersion = "26.05";
}
