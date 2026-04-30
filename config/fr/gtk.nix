{ pkgs, ... }:
{
  gtk = {
    enable = true;

    theme = {
      name = "Gruvbox-Yellow-Dark";
      # package = pkgs.rose-pine-gtk-theme.override {
      #   src = fetchFromGitHub {
      #     owner = "rose-pine";
      #     repo = "gtk";
      #     rev = "b1a82538a73f97243c7cb8ec7073e344234d6ba6";
      #     hash = "sha256-0p4bmINGKgpINngK8HC8gqIIU3QGjvlCkTM3C+u5r3A=";
      #   };
      # };
      package = pkgs.gruvbox-gtk-theme.override { themeVariants = [ "yellow" ]; };
    };

    iconTheme = {
      name = "rose-pine";
      package = pkgs.rose-pine-icon-theme;
    };

    cursorTheme = {
      name = "BreezeX-RosePineDawn-Linux";
      package = pkgs.rose-pine-cursor;
      size = 24;
    };

    font = {
      name = "Recursive Sans Casual Static";
      size = 11;
    };

    gtk2.extraConfig = ''
      gtk-toolbar-style=GTK_TOOLBAR_ICONS
      gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
      gtk-button-images=0
      gtk-menu-images=0
      gtk-enable-event-sounds=1
      gtk-enable-input-feedback-sounds=0
      gtk-xft-antialias=1
      gtk-xft-hinting=1
      gtk-xft-hintstyle="hintslight"
      gtk-xft-rgba="rgb"
    '';

    gtk3.extraConfig = {
      gtk-toolbar-style = "GTK_TOOLBAR_ICONS";
      gtk-toolbar-icon-size = "GTK_ICON_SIZE_LARGE_TOOLBAR";
      gtk-button-images = false;
      gtk-menu-images = false;
      gtk-enable-event-sounds = true;
      gtk-enable-input-feedback-sounds = false;
      # gtk-xft-antialias = true;
      # gtk-xft-hinting = true;
      gtk-xft-hintstyle = "hintslight";
      gtk-xft-rgba = "rgb";
      gtk-application-prefer-dark-theme = true;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # Set GTK theme environment variable to match
  home.sessionVariables.GTK_THEME = "Gruvbox-Yellow-Dark";
}
