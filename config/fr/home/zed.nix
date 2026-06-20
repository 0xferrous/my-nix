{ pkgs, ... }:
{
  programs.zed-editor = {
    enable = true;
    package = pkgs.zed-editor-fhs;
  };

  fr.symlinks.configFiles."zed/settings.json".target = "config/fr/home/zed/settings.json";
}
