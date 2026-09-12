{ config, lib, ... }:
let
  cfg = config.fr.public;
in
{
  config = lib.mkIf cfg.enable {
    virtualisation.incus = {
      enable = lib.mkDefault true;
      ui.enable = lib.mkDefault true;
    };

    users.users = lib.mkIf (cfg.user != "") {
      ${cfg.user}.extraGroups = [ "incus-admin" ];
    };
  };
}
