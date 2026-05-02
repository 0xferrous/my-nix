{ pkgs, ... }:
{
  programs.zed-editor = {
    enable = true;
    package = pkgs.zed-editor-fhs;
    extraPackages = with pkgs; [
      pkg-config
      openssl
    ];
  };

  fr.symlinks.configFiles."zed/settings.json".target = "config/fr/home/zed/settings.json";
}
