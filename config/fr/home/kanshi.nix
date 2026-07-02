{
  config,
  lib,
  pkgs,
  ...
}:
let
  onlyExternalExec = "${pkgs.nushell}/bin/nu ${./kanshi-external-only.nu}";
  servicePath = lib.concatStringsSep ":" [
    "${config.home.profileDirectory}/bin"
    "/run/current-system/sw/bin"
    (lib.makeBinPath [
      pkgs.ddcutil
      pkgs.libnotify
      pkgs.nushell
    ])
  ];
in
{
  config = {
    services.kanshi = {
      enable = true;
      settings = [
        {
          profile = {
            name = "only_external";
            outputs = [
              {
                criteria = "DP-1";
                position = "0,0";
              }
              {
                criteria = "HDMI-A-1";
                position = "1920,0";
              }
              {
                criteria = "eDP-1";
                position = "1920,1080";
                status = "disable";
              }
            ];
            exec = [ onlyExternalExec ];
          };
        }
        {
          profile = {
            name = "only_external_dp2";
            outputs = [
              {
                criteria = "DP-2";
                position = "0,0";
              }
              {
                criteria = "HDMI-A-1";
                position = "1920,0";
              }
              {
                criteria = "eDP-1";
                position = "1920,1080";
                status = "disable";
              }
            ];
            exec = [ onlyExternalExec ];
          };
        }
        {
          profile.name = "only_laptop";
          profile.outputs = [
            {
              criteria = "eDP-1";
              status = "enable";
            }
          ];
        }
        {
          profile.name = "laptop_and_external";
          profile.outputs = [
            {
              criteria = "DP-1";
              position = "0,0";
            }
            {
              criteria = "HDMI-A-1";
              position = "1920,0";
            }
            { criteria = "eDP-1"; }
          ];
        }
        {
          profile.name = "laptop_and_external_dp2";
          profile.outputs = [
            {
              criteria = "DP-2";
              position = "0,0";
            }
            {
              criteria = "HDMI-A-1";
              position = "1920,0";
            }
            { criteria = "eDP-1"; }
          ];
        }
        {
          profile.name = "laptop_and_lenovo";
          profile.outputs = [
            {
              criteria = "eDP-1";
              position = "0,0";
            }
            {
              criteria = "HDMI-A-1";
              position = "1920,0";
            }
          ];
        }
      ];
    };

    systemd.user.services.kanshi.Service.Environment = "PATH=${servicePath}";
  };
}
