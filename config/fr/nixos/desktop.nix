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

    fr.ash-vm-network.enable = lib.mkDefault true;

    fr.iron-proxy = {
      enable = lib.mkDefault true;
      # Public CA cert committed next to the module; the matching private key
      # lives on the host at /var/lib/iron-proxy/ca.key. Guests (agent/nash)
      # trust the same cert via security.pki.certificateFiles.
      caCertificate = lib.mkDefault ../../../modules/nixos/iron-proxy-ca.crt;
      # Real secrets are read from this root-only file (e.g.
      # TEST_API_KEY=..., OPENAI_API_KEY=..., ANTHROPIC_API_KEY=...).
      environmentFile = lib.mkDefault "/var/lib/iron-proxy/.env";
      # Test entry: verifies token injection end-to-end against httpbingo.org
      # (httpbin.org has been flaky/503). The guest can then run:
      #   curl -s https://httpbingo.org/headers | jq .headers.Authorization
      # and the audit log will show the "injected" annotation.
      transforms = lib.mkDefault [
        {
          name = "secrets";
          config.secrets = [
            {
              source = {
                type = "env";
                var = "TEST_API_KEY";
              };
              inject = {
                header = "Authorization";
                formatter = "Bearer {{ .Value }}";
              };
              rules = [
                {
                  host = "httpbingo.org";
                }
              ];
            }
          ];
        }
      ];
    };

    fr.virtiofs-nix-store = {
      enable = lib.mkDefault true;
    };

    fr.powerManagement = {
      enable = lib.mkDefault true;
      cpu.amdPstate.enable = lib.mkDefault true;
      bluetoothKeyboardWake = {
        enable = lib.mkDefault false;
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

    hardware.uinput.enable = lib.mkDefault true;

    users.users = lib.mkIf (cfg.user != "") {
      ${cfg.user}.extraGroups = [ "uinput" ];
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

    services.gnome.at-spi2-core.enable = lib.mkDefault true;

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
