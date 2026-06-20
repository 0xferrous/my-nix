{
  config,
  lib,
  pkgs,
  ...
}:
let
  dmsDir = ./DankMaterialShell;
  settings = builtins.fromJSON (builtins.readFile (dmsDir + "/settings.json"));
in
{
  config = lib.mkIf pkgs.stdenv.isLinux {
    programs.dank-material-shell = {
      enable = true;
      systemd.enable = true;
      managePluginSettings = true;
      settings = settings // {
        customThemeFile = "${config.home.homeDirectory}/.config/DankMaterialShell/themes/gruvboxMaterial/theme.json";
      };

      plugins = {
        aiUsage = {
          src = dmsDir + "/plugins/AiUsage";
          settings = {
            enabled = true;
            provider = "codex";
            showAbsoluteTimes = true;
          };
        };
        codexBar.enable = true;
        cryptoPrices = {
          src = dmsDir + "/plugins/CryptoPrices";
          settings = {
            enabled = true;
            refreshIntervalSec = 5;
            showPercentages = true;
            symbolsCsv = "ETHUSDT,BTCUSDT,SOLUSDT";
          };
        };
        dankKDEConnect = {
          enable = true;
          settings = {
            enabled = true;
            selectedDeviceId = "193a7c1fa2cf494aa7aabab111173b1d";
          };
        };
        tailscaleActive = {
          src = dmsDir + "/plugins/TailscaleActive";
          settings = {
            enabled = true;
            refreshIntervalSec = 60;
          };
        };
      };
    };

    xdg.configFile = {
      "DankMaterialShell/themes/gruvboxMaterial" = {
        source = dmsDir + "/themes/gruvboxMaterial";
        recursive = true;
      };
      "DankMaterialShell/themes/gruvboxMulti" = {
        source = dmsDir + "/themes/gruvboxMulti";
        recursive = true;
      };
    };
  };
}
