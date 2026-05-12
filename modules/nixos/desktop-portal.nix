{ config, lib, pkgs, ... }:
let
  cfg = config.fr.desktopPortal;
in
{
  options.fr.desktopPortal = {
    enable = lib.mkEnableOption "desktop portal configuration";

    desktopName = lib.mkOption {
      type = lib.types.str;
      default = "common";
      description = "XDG desktop profile name used under xdg.portal.config, such as common or niri.";
    };

    portals = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-gnome
      ];
      description = "Portal backend packages to add to xdg.portal.extraPortals.";
    };

    defaultPortal = lib.mkOption {
      type = lib.types.str;
      default = "gtk";
      description = "Default portal backend name for xdg.portal.config.<desktop>.default.";
    };

    interfaceOverrides = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        "org.freedesktop.impl.portal.ScreenCast" = "gnome";
        "org.freedesktop.impl.portal.Screenshot" = "gnome";
      };
      description = "Mapping of portal interface names to backend names.";
    };
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    xdg.portal = {
      enable = lib.mkDefault true;
      extraPortals = cfg.portals;
      config.${cfg.desktopName} = lib.mkMerge [
        {
          default = lib.mkDefault cfg.defaultPortal;
        }
        (lib.mapAttrs (_: portal_name: lib.mkDefault portal_name) cfg.interfaceOverrides)
      ];
    };
  };
}
