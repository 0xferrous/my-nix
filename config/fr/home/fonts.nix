{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    nerd-fonts.recursive-mono
    nerd-fonts._0xproto
    nerd-fonts.symbols-only
    recursive
    open-sans
    noto-fonts
    cantarell-fonts
    roboto
  ];

  fonts.fontconfig.enable = lib.mkDefault true;
}
