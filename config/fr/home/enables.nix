{ lib, ... }:
{
  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    fish.enable = true;
    noti.enable = true;
    zoxide.enable = true;
    zoxide.enableZshIntegration = lib.mkForce false;
    zellij.enable = true;
    nh = {
      enable = true;
      clean.enable = true;
      clean.dates = "weekly";
    };
    # nix-index.enable = true;
    nix-your-shell = {
      enable = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
    };
    nushell.enable = true;
    tealdeer = {
      enable = true;
      settings = {
        display.compact = true;
        updates.auto_update = true;
      };
    };
    # television = {
    #   enable = true;
    #   enableZshIntegration = true;
    #   enableFishIntegration = true;
    # };
    # nix-search-tv = {
    #   enable = true;
    #   # enableTelevisionIntegration = true;
    #   # settings = {
    #   #   # Custom configuration for nix-search-tv
    #   #   channels = [
    #   #     {
    #   #       name = "packages";
    #   #       channel = "unstable";
    #   #     }
    #   #     {
    #   #       name = "options";
    #   #       channel = "unstable";
    #   #     }
    #   #   ];
    #   # };
    # };
  };
}
