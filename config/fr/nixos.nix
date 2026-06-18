{ fenix, ghmd }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fr.public;
  homeDir = if cfg.homeDir != null then cfg.homeDir else "/home/${cfg.user}";
  localhostHosts = [ "rustdoc.localhost" ] ++ lib.optionals cfg.ghmd.caddy.enable [ cfg.ghmd.domain ];
  caddyListenAddresses = [
    "127.0.0.1"
    "::1"
  ];
  caddyLogFormat = ''
    output stderr
    format console
  '';
  binaryCacheKeys = {
    "https://0xferrous.cachix.org" =
      "0xferrous.cachix.org-1:p38oLu+8I+EwBW6NCl+ffI8qn+WOtUeRzES/dYNuSUE=";
    "https://numtide.cachix.org" = "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=";
    "https://cache.numtide.com" = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
  };
  binaryCaches = lib.attrNames binaryCacheKeys;
in
{
  imports = [
    ghmd.nixosModules.default
    ../../modules/nixos/desktop-portal.nix
    ../../modules/nixos/virtiofsd-nix-store.nix
  ];

  options.fr.public = {
    enable = lib.mkEnableOption "public NixOS baseline";

    user = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "dmnt";
      description = "Primary username used to derive public baseline defaults.";
    };

    homeDir = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/home/dmnt";
      description = "Home directory override for public baseline defaults.";
    };

    ghmd = {
      enable = lib.mkEnableOption "ghmd service and localhost proxy";

      domain = lib.mkOption {
        type = lib.types.str;
        default = "ghmd.localhost";
        description = "Hostname exposed through Caddy for ghmd.";
      };

      caddy.enable = lib.mkEnableOption "Caddy reverse proxy for ghmd";
    };
  };

  config = lib.mkIf cfg.enable {
    fr.desktopPortal = {
      enable = lib.mkDefault true;
      desktopName = lib.mkDefault "niri";
      portals = lib.mkDefault (
        with pkgs;
        [
          xdg-desktop-portal-gtk
          xdg-desktop-portal-gnome
        ]
      );
      defaultPortal = lib.mkDefault "gtk";
      interfaceOverrides = lib.mkDefault {
        "org.freedesktop.impl.portal.ScreenCast" = "gnome";
        "org.freedesktop.impl.portal.Screenshot" = "gnome";
      };
    };

    fr.virtiofs-nix-store = {
      enable = lib.mkDefault true;
    };

    programs.kdeconnect = {
      enable = lib.mkDefault true;
      package = lib.mkDefault pkgs.kdePackages.kdeconnect-kde;
    };

    assertions = [
      {
        assertion = cfg.user != "";
        message = "Set fr.public.user when fr.public.enable = true.";
      }
    ];

    fr.public.ghmd = {
      enable = lib.mkDefault true;
      caddy.enable = lib.mkDefault true;
    };

    services.ghmd = lib.mkIf cfg.ghmd.enable {
      enable = true;
      package = lib.mkDefault ghmd.packages.${pkgs.system}.default;
      host = lib.mkDefault "127.0.0.1";
      port = lib.mkDefault 9000;
      theme = lib.mkDefault "gruvbox";
      rootDir = lib.mkDefault homeDir;
    };

    systemd.services.ghmd = lib.mkIf cfg.ghmd.enable {
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = lib.mkDefault cfg.user;
        ProtectHome = lib.mkForce false;
      };
    };

    services.caddy = {
      enable = true;
      virtualHosts = {
        "http://${cfg.ghmd.domain}" = lib.mkIf cfg.ghmd.caddy.enable {
          listenAddresses = caddyListenAddresses;
          logFormat = caddyLogFormat;
          extraConfig = ''
            header X-Caddy-Vhost ghmd
            handle_path /__caddy_probe {
              respond "ghmd" 200
            }
            reverse_proxy ${config.services.ghmd.host}:${toString config.services.ghmd.port}
          '';
        };
        "http://rustdoc.localhost" = {
          listenAddresses = caddyListenAddresses;
          logFormat = caddyLogFormat;
          extraConfig = ''
            header X-Caddy-Vhost rustdoc
            handle_path /__caddy_probe {
              respond "rustdoc" 200
            }
            root * ${fenix.packages.${pkgs.system}.complete.rust-docs}/share/doc/rust/html/
            file_server
          '';
        };
      };
    };

    networking.hosts = {
      "127.0.0.1" = localhostHosts;
      "::1" = localhostHosts;
    };

    nix.settings = {
      substituters = binaryCaches;
      trusted-public-keys = lib.attrValues binaryCacheKeys;
      trusted-substituters = binaryCaches;
    };
  };
}
