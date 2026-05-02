{ ... }:
{
  programs.wofi = {
    enable = true;
    style = ''
      * {
          font-family: "RecMonoCasual Nerd Font", monospace;
          font-size: 14px;
      }
    '';
  };
}
