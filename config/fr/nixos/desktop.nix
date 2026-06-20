{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fr.public;
in
{
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

    fr.powerManagement = {
      enable = lib.mkDefault true;
      cpu.amdPstate.enable = lib.mkDefault true;
    };

    programs.kdeconnect = {
      enable = lib.mkDefault true;
      package = lib.mkDefault pkgs.kdePackages.kdeconnect-kde;
    };
  };
}
