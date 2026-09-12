{ lib, ... }:
{
  programs.nushell.settings = {
    show_banner = lib.mkDefault false;
    edit_mode = lib.mkDefault "vi";
    buffer_editor = lib.mkDefault "nvim";
    use_kitty_protocol = lib.mkDefault true;
    cursor_shape = {
      vi_insert = lib.mkDefault "line";
      vi_normal = lib.mkDefault "block";
    };
  };
}
