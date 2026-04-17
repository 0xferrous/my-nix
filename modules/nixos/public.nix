{ ghmd }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fr.public;
  homeDir = if cfg.homeDir != null then cfg.homeDir else "/home/${cfg.user}";
in
{
  imports = [ ghmd.nixosModules.default ];

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
    assertions = [
      {
        assertion = cfg.homeDir != null || cfg.user != "";
        message = "Set fr.public.user or fr.public.homeDir when fr.public.enable = true.";
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

    services.caddy = lib.mkIf cfg.ghmd.caddy.enable {
      enable = true;
      virtualHosts."http://${cfg.ghmd.domain}".extraConfig = ''
        reverse_proxy ${config.services.ghmd.host}:${toString config.services.ghmd.port}
      '';
    };

    networking.hosts = lib.mkIf cfg.ghmd.caddy.enable {
      "127.0.0.1" = [ cfg.ghmd.domain ];
    };
  };
}
