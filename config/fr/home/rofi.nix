{ config, pkgs, ... }:
{
  programs.rofi = {
    # package = pkgs.rofi-wayland;
    enable = true;
    cycle = true;
    pass = {
      package = pkgs.rofi-pass-wayland;
      enable = true;
      stores = map (store: store.store_dir) config.fr.pass.stores;
    };
    plugins = with pkgs; [
      rofi-emoji
      rofi-power-menu
      rofi-calc
    ];
    modes = [
      "emoji"
      "drun"
      "run"
      "window"
      "calc"
      "ssh"
    ];
    terminal = "${pkgs.kitty}/bin/kitty";
    theme = "gruvbox-dark-hard";
    font = "RecMonoCasual Nerd Font 14";
  };
}
