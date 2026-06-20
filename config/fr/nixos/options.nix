{ lib, ... }:
{
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
}
