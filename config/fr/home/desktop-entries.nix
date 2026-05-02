{ pkgs, ... }:
let
  makeElementEntry = profileName: {
    type = "Application";
    categories = [
      "Network"
      "InstantMessaging"
      "Chat"
    ];
    exec = "element-desktop --profile ${profileName} --password-store=gnome-libsecret %u";
    comment = "element desktop, profile=${profileName}";
    genericName = "Matrix Client";
    icon = "element";
    name = "Element ${profileName}";
  };
  helium = "helium.desktop";
in
{
  home.packages = [
    pkgs.cosmic-files
    pkgs.railway-wallet
  ];

  xdg.desktopEntries.element-fr-matrix-org = makeElementEntry "fr-matrix-org";
  xdg.desktopEntries.element-fr-nxm-rs = makeElementEntry "fr-nxm-rs";
  xdg.desktopEntries.railway = {
    type = "Application";
    categories = [ ];
    exec = "railway-wallet --enable-features=UseOzonePlatform --ozone-platform=wayland %u";
    genericName = "Wallet";
    name = "Railway wallet";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "com.system76.CosmicFiles.desktop" ];
      # Helium can be added here once it is included in nixpkgs.
      "text/html" = [ helium ];
      "x-scheme-handler/http" = [ helium ];
      "x-scheme-handler/https" = [ helium ];
    };
  };
}
