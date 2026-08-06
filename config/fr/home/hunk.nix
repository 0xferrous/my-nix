{ lib, ... }:
{
  xdg.configFile."hunk/config.toml".source = ./hunk/config.toml;

  programs.git.settings.core.pager = lib.mkDefault "hunk pager";

  programs.jujutsu.settings.ui = {
    pager = lib.mkDefault [
      "hunk"
      "pager"
    ];
    diff-formatter = lib.mkDefault ":git";
  };
}
