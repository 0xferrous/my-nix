{ lib, ... }:
{
  fr.symlinks.configFiles."hunk/config.toml".target = "config/fr/home/hunk/config.toml";

  programs.git.settings.core.pager = lib.mkDefault "hunk pager";

  programs.jujutsu.settings.ui = {
    pager = lib.mkDefault [
      "hunk"
      "pager"
    ];
    diff-formatter = lib.mkDefault ":git";
  };
}
