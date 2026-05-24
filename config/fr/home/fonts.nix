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

  # Stronger than Home Manager's built-in standalone default (`false`), while
  # still allowing consuming configs to override with mkForce.
  fonts.fontconfig.enable = lib.mkDefault true;
}
