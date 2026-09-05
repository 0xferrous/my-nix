{
  config,
  lib,
  pkgs,
  ...
}:
let
  noctaliaDir = ./Noctalia;
  statusPluginDir = noctaliaDir + "/plugins/fr-status";
in
{
  # Noctalia shell config, mirroring config/fr/home/dank-material-shell.nix
  # where Noctalia has an equivalent. Ported DMS behavior:
  # - dark mode, gruvbox-material accents (custom palette file below; the
  #   builtin "Gruvbox" palette stays available in the Settings UI)
  # - Recursive Sans Casual Static UI font, 24-hour clock with seconds
  # - DMS dual-bar layout: launcher/workspaces/active window on the top-left;
  #   media, weather, clock, status on the top-right; clipboard,
  #   CPU/memory/temperature/disk, idle inhibitor, and custom status widgets
  #   on the bottom bar
  # - weather lookup, clipboard history, notification daemon, lock screen,
  #   system monitor sampling, UI sounds, 5-minute idle lock, no dock,
  #   terminal/compositor theme templates (niri/foot/alacritty/ghostty/
  #   wezterm, matching the DMS matugen template selection)
  # The DMS CryptoPrices, AiUsage, and TailscaleActive widgets are ported to
  # the local fr/status Noctalia plugin (per-widget capsule borders stand in
  # for the DMS outline styling). KDE Connect and per-widget transparency
  # have no direct equivalent.
  config = lib.mkIf pkgs.stdenv.isLinux {
    programs.noctalia = {
      enable = true;
      # The package defaults to the noctalia flake output via
      # noctalia.homeModules.default (imported in ../home.nix).
      # Noctalia is now the primary shell: the systemd user service
      # autostarts it on login (DMS has been retired from the fr config).
      systemd.enable = lib.mkDefault true;
      settings = {
        shell = {
          font_family = "Recursive Sans Casual Static";
          time_format = "{:%H:%M:%S}";
          clipboard_enabled = true;
          # Doc-recommended with the systemd service: launched apps survive
          # shell restarts in their own cgroup.
          launch_apps_as_systemd_services = true;
          # Surface .desktop Actions (e.g. Noctalia's own "Open Settings")
          # in launcher results; without this the bare app entry runs.
          launcher.show_app_actions = true;
          # Popups drop down from the clicked widget instead of opening at
          # bar-center: attach panels to the bar and anchor them near the click.
          panel = {
            clipboard_placement = "attached";
            control_center_placement = "attached";
            open_near_click_clipboard = true;
            open_near_click_control_center = true;
          };
          animation = {
            enabled = true;
            speed = 1.0;
          };
        };

        wallpaper = {
          enabled = true;
          fill_mode = "crop";
        };

        theme = {
          mode = "dark";
          source = "custom";
          custom_palette = "gruvbox-material";
        };

        theme.templates = {
          enable_builtin_templates = true;
          builtin_ids = [
            "niri"
            "foot"
            "alacritty"
            "ghostty"
            "wezterm"
          ];
        };

        notification = {
          enable_daemon = true;
        };

        audio = {
          enable_sounds = true;
        };

        system.monitor = {
          enabled = true;
        };

        weather = {
          enabled = true;
        };

        location = {
          auto_locate = true;
        };

        idle.behavior.lock = {
          timeout = 300;
          action = "lock";
          enabled = true;
        };

        lockscreen = {
          enabled = true;
        };

        dock = {
          enabled = false;
        };

        plugins = {
          enabled = [ "fr/status" ];
          auto_update = "none";
        };

        bar.order = [
          "main"
          "bottom"
        ];

        bar.main = {
          position = "top";
          font_scale = 1.2;
          capsule = true;
          capsule_border = "outline";
          capsule_group = [
            {
              id = "connectivity";
              members = [
                "network"
                "bluetooth"
              ];
              border = "outline";
            }
          ];
          start = [
            "launcher"
            "taskbar"
            "active-window"
          ];
          center = [ ];
          end = [
            "media"
            "weather"
            "clock"
            "battery"
            "group:connectivity"
            "tray"
            "control-center"
            "privacy"
            "notifications"
          ];
        };

        bar.bottom = {
          position = "bottom";
          font_scale = 1.2;
          capsule = true;
          capsule_border = "outline";
          start = [ ];
          center = [ ];
          end = [
            "clipboard"
            "crypto-prices"
            "cpu-usage"
            "memory-usage"
            "cpu-temperature"
            "disk-usage"
            "caffeine"
            "ai-usage"
            "tailscale-active"
          ];
        };

        widget = {
          "active-window".type = "active_window";
          # DMS-style workspace pills: one capsule per workspace holding that
          # workspace's window icons (needs per-window workspace info from
          # the compositor; stays flat if unavailable).
          "taskbar" = {
            type = "taskbar";
            group_by_workspace = true;
            show_workspace_label = true;
            workspace_group_content = "icons";
            show_active_indicator = true;
          };
          "crypto-prices" = {
            type = "fr/status:crypto";
            capsule = true;
            capsule_border = "primary";
            symbols = [
              "ETHUSDT"
              "BTCUSDT"
              "SOLUSDT"
            ];
            refresh_seconds = 5;
            show_percentages = true;
          };
          "cpu-usage" = {
            type = "sysmon";
            stat = "cpu_usage";
          };
          "memory-usage" = {
            type = "sysmon";
            stat = "ram_used";
          };
          "cpu-temperature" = {
            type = "sysmon";
            stat = "cpu_temp";
            visualization = "none";
          };
          "disk-usage" = {
            type = "sysmon";
            stat = "disk_used_pct";
            path = "/";
          };
          "ai-usage" = {
            type = "fr/status:ai-usage";
            capsule = true;
            capsule_border = "secondary";
            refresh_seconds = 60;
          };
          "tailscale-active" = {
            type = "fr/status:tailscale";
            capsule = true;
            capsule_border = "tertiary";
            refresh_seconds = 60;
          };
          clock = {
            format = "{:%a %b %d %H:%M:%S}";
            tooltip_format = "{:%A, %B %d, %Y}";
          };
        };
      };

      customPalettes = {
        gruvbox-material = noctaliaDir + "/palettes/gruvbox-material.json";
      };
    };

    xdg.dataFile."noctalia/plugins/fr-status" = {
      source = statusPluginDir;
      recursive = true;
    };
  };
}
