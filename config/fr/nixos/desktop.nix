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
    hardware.enableRedistributableFirmware = lib.mkDefault true;

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

    # KDE Connect keeps a Bluetooth discovery client around on this setup, which
    # makes the MediaTek Bluetooth controller's post-suspend state harder to
    # recover from. Keep it disabled unless explicitly overridden elsewhere.
    programs.kdeconnect = {
      enable = lib.mkDefault false;
      package = lib.mkDefault pkgs.kdePackages.kdeconnect-kde;
    };

    services.keyd = {
      enable = lib.mkDefault true;
      keyboards.default = {
        # Match only the laptop's built-in AT keyboard.
        ids = lib.mkDefault [ "0001:0001:09b4e68d" ];
        settings.main = {
          # The laptop Fn key is exposed as XF86WakeUp/keyd's "wakeup" key.
          # Remap it to a real Shift modifier before niri sees it.
          wakeup = lib.mkDefault "layer(shift)";
          capslock = lib.mkDefault "layer(shift)";
        };
      };
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
