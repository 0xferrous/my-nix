{
  config,
  lib,
  pkgs,
  ...
}:
let
  carapaceBin = lib.getExe config.programs.carapace.package;
in
{
  programs.carapace = {
    enable = true;
    # Source carapace manually with mkBefore below so fzf's Nushell integration
    # wraps carapace as its fallback external completer instead of replacing it.
    enableNushellIntegration = lib.mkForce false;
  };

  programs.nushell.extraConfig = lib.mkBefore ''
    source ${
      pkgs.runCommand "carapace-nushell-config-early.nu" { } ''
        ${carapaceBin} _carapace nushell | sed 's|"/homeless-shelter|$"($env.HOME)|g' >> "$out"
      ''
    }
  '';
  programs.caelestia = {
    enable = false;
    systemd = {
      enable = false; # if you prefer starting from your compositor
      target = "graphical-session.target";
      environment = [ ];
    };
    settings = {
      bar.status = {
        showBattery = false;
      };
      paths.wallpaperDir = "~/Images";
    };
    cli = {
      enable = true; # Also add caelestia-cli to path
      settings = {
        theme.enableGtk = false;
      };
    };
  };
}
