{
  lib,
  myNixInputs,
  pkgs,
  ...
}:
let
  vicinaePackage = myNixInputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  programs = {
    devenv = {
      enable = true;
      enableNushellIntegration = true;
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    fish.enable = true;
    fzf = {
      enable = true;
      enableNushellIntegration = true;
    };
    noti.enable = true;
    zoxide.enable = true;
    zoxide.enableZshIntegration = lib.mkForce false;
    zellij.enable = true;
    nh = {
      enable = true;
      clean.enable = true;
      clean.dates = "weekly";
    };
    starship.enable = true;
    # nix-index.enable = true;
    nix-your-shell = {
      enable = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
    };
    nushell = {
      enable = true;
      environmentVariables.DEVENV_SHELL_TYPE = "nu";
    };
    tealdeer = {
      enable = true;
      settings = {
        display.compact = true;
        updates.auto_update = true;
      };
    };
    vicinae = {
      enable = true;
      package = vicinaePackage;
      systemd.enable = true;
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

  home.file.".config/net.imput.helium/NativeMessagingHosts/com.vicinae.vicinae.json".source =
    "${vicinaePackage}/etc/chromium/native-messaging-hosts/com.vicinae.vicinae.json";
}
