{ pkgs, ... }:
{
  programs.atuin = {
    package = pkgs.atuin;
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    flags = [ "--disable-ctrl-r" ];
    settings = { };
  };
}
