{ lib, pkgs, ... }:
let
  kittyPortalDbusService = pkgs.writeTextDir "share/dbus-1/services/org.freedesktop.impl.portal.desktop.kitty.service" ''
    [D-BUS Service]
    Name=org.freedesktop.impl.portal.desktop.kitty
    Exec=${pkgs.kitty}/bin/kitten desktop-ui run-server
  '';

  kittyPortalDescriptor = pkgs.writeTextDir "share/xdg-desktop-portal/portals/kitty.portal" ''
    [portal]
    DBusName=org.freedesktop.impl.portal.desktop.kitty
    Interfaces=org.freedesktop.impl.portal.Settings;org.freedesktop.impl.portal.FileChooser;
  '';

  kittyPortalPkg = pkgs.symlinkJoin {
    name = "kitty-desktop-portal";
    paths = [
      kittyPortalDbusService
      kittyPortalDescriptor
    ];
  };
in
{
  config = lib.mkIf pkgs.stdenv.isLinux {
    xdg.portal = {
      enable = lib.mkDefault true;
      extraPortals = lib.mkAfter [
        kittyPortalPkg
        pkgs.xdg-desktop-portal-gtk
      ];
      config = {
        common = {
          "org.freedesktop.impl.portal.Settings" = "kitty;*";
          "org.freedesktop.impl.portal.FileChooser" = "kitty;*";
        };
        cosmic = {
          "org.freedesktop.impl.portal.Settings" = "kitty;*";
          "org.freedesktop.impl.portal.FileChooser" = "kitty;*";
        };
        COSMIC = {
          "org.freedesktop.impl.portal.Settings" = "kitty;*";
          "org.freedesktop.impl.portal.FileChooser" = "kitty;*";
        };
      };
    };

    dbus.packages = [ kittyPortalPkg ];
  };
}
