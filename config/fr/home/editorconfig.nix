{ lib, ... }:
{
  editorconfig = {
    enable = lib.mkDefault true;
    settings = {
      "*.sol" = {
        indent_style = "space";
        indent_size = 4;
      };
      "*.{lua,js,ts}" = {
        indent_style = "space";
        indent_size = 2;
      };
    };
  };
}
