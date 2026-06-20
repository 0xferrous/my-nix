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
in
{
  config = lib.mkIf cfg.enable {
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
      package = lib.mkDefault ghmd.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
            root * ${fenix.packages.${pkgs.stdenv.hostPlatform.system}.complete.rust-docs}/share/doc/rust/html/
            file_server
          '';
        };
      };
    };

    networking.hosts = {
      "127.0.0.1" = localhostHosts;
      "::1" = localhostHosts;
    };
  };
}
