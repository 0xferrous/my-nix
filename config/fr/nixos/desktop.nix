{ dms }:
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
  imports = [ dms.nixosModules.greeter ];

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
      bluetoothKeyboardWake = {
        enable = lib.mkDefault true;
        usbDevices = lib.mkDefault [
          # Internal MediaTek Bluetooth adapter.
          {
            vendorId = "0e8d";
            productId = "e025";
          }
          # Parent Genesys USB hub for the internal Bluetooth adapter.
          {
            vendorId = "05e3";
            productId = "0610";
          }
        ];
      };
    };

    programs.kdeconnect = {
      enable = lib.mkDefault true;
      package = lib.mkDefault pkgs.kdePackages.kdeconnect-kde;
    };

    programs.niri = {
      enable = lib.mkDefault true;

      # Force the GTK portal for FileChooser. The default Niri module prefers
      # xdg-desktop-portal-gnome via Nautilus, which breaks file dialogs in
      # Helium/Chromium on this setup.
      useNautilus = lib.mkDefault false;
    };

    programs.dank-material-shell.greeter = {
      enable = true;
      compositor.name = "niri";
    };
  };
}
