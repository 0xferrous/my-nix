{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fr.services.bbApp;
in
{
  options.fr.services.bbApp = {
    enable = lib.mkEnableOption "the BB agent server";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Package providing the bb-app executable.";
    };

    serverBindHost = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Address on which the BB server listens.";
    };

    deriveUrlFromTailscale = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Derive BB_APP_URL from this machine's Tailscale MagicDNS name.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.bb-app = {
      Unit.Description = "bb agent server";
      Service.ExecStart =
        if cfg.deriveUrlFromTailscale then
          "${pkgs.nushell}/bin/nu ${./bb-app-server.nu} ${cfg.package}/bin/bb-app ${pkgs.tailscale}/bin/tailscale ${cfg.serverBindHost}"
        else
          "${cfg.package}/bin/bb-app --server-bind-host ${cfg.serverBindHost}";
      Service.Restart = "on-failure";
      Service.RestartSec = 2;
      Install.WantedBy = [ "default.target" ];
    };
  };
}
