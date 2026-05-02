{ ... }:
{
  programs.helix = {
    enable = true;
    settings = {
      theme = "gruvbox_dark_hard";
      editor = {
        line-number = "relative";
        lsp.display-messages = true;
        cursor-shape = {
          normal = "block";
          insert = "bar";
        };
      };
    };
  };
}
