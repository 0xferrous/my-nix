{ config, lib, pkgs, ... }:
let
  cfg = config.fr.termfilechooser;

  chooserNames = [
    "yazi"
    "lf"
    "nnn"
    "ranger"
    "superfile"
    "vifm"
  ];

  chooserPackageDefaults = {
    yazi = pkgs.yazi;
    lf = pkgs.lf;
    nnn = pkgs.nnn;
    ranger = pkgs.ranger;
    superfile = pkgs.superfile;
    vifm = pkgs.vifm;
  };

  wrapperScript = "${cfg.package}/share/xdg-desktop-portal-termfilechooser/${cfg.tui.program}-wrapper.sh";
  terminalCommand = lib.concatStringsSep " " cfg.terminal.command;
  spfAlias = pkgs.writeShellScriptBin "spf" ''
    exec ${lib.getExe cfg.tui.package} "$@"
  '';

  configuredWrapper = pkgs.writeShellScript "termfilechooser-${cfg.tui.program}-wrapper" ''
    export TERMCMD=${lib.escapeShellArg terminalCommand}
    exec ${wrapperScript} "$@"
  '';
in
{
  options.fr.termfilechooser = {
    enable = lib.mkEnableOption "xdg-desktop-portal-termfilechooser";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.xdg-desktop-portal-termfilechooser;
      description = "Package providing the xdg-desktop-portal-termfilechooser backend.";
    };

    desktop = lib.mkOption {
      type = lib.types.str;
      default = "common";
      description = "Portal config profile under xdg.portal.config to target, such as common, niri, or hyprland.";
    };

    tui = {
      program = lib.mkOption {
        type = lib.types.enum chooserNames;
        default = "yazi";
        description = "Supported TUI file chooser program to run inside the terminal.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = chooserPackageDefaults.${cfg.tui.program};
        defaultText = lib.literalExpression "pkgs.<package matching config.fr.termfilechooser.tui.program>";
        description = "Package that provides the selected TUI file chooser executable.";
      };

    };

    terminal = {
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = pkgs.kitty;
        defaultText = lib.literalExpression "pkgs.kitty";
        description = "Optional package providing the terminal executable used to host the TUI file chooser.";
      };

      command = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = if cfg.terminal.package != null then [ (lib.getExe cfg.terminal.package) "--title" "termfilechooser" ] else [ ];
        example = [ "${lib.getExe pkgs.foot}" ];
        description = "Command argv used to launch the terminal emulator for the file chooser.";
      };
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          lib.types.str
          lib.types.int
          lib.types.bool
        ]
      );
      default = {
        default_dir = "$HOME";
        open_mode = "suggested";
        save_mode = "suggested";
      };
      example = {
        default_dir = "$HOME/Downloads";
        create_help_file = false;
      };
      description = "Extra [filechooser] settings written to the termfilechooser config file.";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.portal = {
      enable = lib.mkDefault true;
      extraPortals = [
        cfg.package
      ];
      config.${cfg.desktop}."org.freedesktop.impl.portal.FileChooser" = lib.mkDefault [ "termfilechooser" ];
    };

    home.packages = [
      cfg.package
      spfAlias
      cfg.tui.package
    ] ++ lib.optional (cfg.terminal.package != null) cfg.terminal.package;

    xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = lib.generators.toINI { } {
      filechooser = cfg.settings // {
        cmd = configuredWrapper;
      };
    };
  };
}
