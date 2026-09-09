{
  config,
  lib,
  pkgs,
  ...
}:
let
  noctaliaDir = ./Noctalia;
  statusPluginDir = noctaliaDir + "/plugins/fr-status";
  # One entry per connector used across kanshi profiles. Clocks share a
  # 1920x1080 reference canvas (rescaled per real output); login geometry
  # is the editor-captured center on the same basis.
  lockscreenOutputs = [
    {
      short = "edp";
      output = "eDP-1";
      loginCx = 720.0;
      loginCy = 627.0;
      width = 1440.0;
      height = 900.0;
    }
    {
      short = "dp1";
      output = "DP-1";
      loginCx = 960.0;
      loginCy = 898.0;
      width = 1920.0;
      height = 1080.0;
    }
    {
      short = "dp2";
      output = "DP-2";
      loginCx = 960.0;
      loginCy = 898.0;
      width = 1920.0;
      height = 1080.0;
    }
    {
      short = "hdmi";
      output = "HDMI-A-1";
      loginCx = 960.0;
      loginCy = 898.0;
      width = 1920.0;
      height = 1080.0;
    }
  ];
  lockscreenClock = output: {
    type = "clock";
    inherit output;
    cx = 960.0;
    cy = 150.0;
    placement_width = 1920.0;
    placement_height = 1080.0;
    settings.format = "{:%a %b %d %H:%M:%S}";
  };
  # Only non-default keys; the shell backfills the rest. No media or
  # weather info row on the lock screen.
  lockscreenLoginSettings = {
    show_media = false;
    show_weather = false;
  };
  # Main-bar lanes, single source: the eDP-1 override derives trimmed
  # lanes from these via filter/map, so base changes propagate.
  mainBarStart = [
    "launcher"
    "taskbar"
    "active-window"
  ];
  mainBarEnd = [
    "media"
    "weather"
    "clock"
    "battery"
    "group:connectivity"
    "tray"
    "control-center"
    "privacy"
    "notifications"
    "notes"
  ];
in
{
  # Noctalia shell config, mirroring config/fr/home/dank-material-shell.nix
  # where Noctalia has an equivalent. Ported DMS behavior:
  # - dark mode, gruvbox-material accents (custom palette file wired under
  #   customPalettes below; tried the builtin "Gruvbox" palette once — the
  #   material tones won)
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
          # UI-chosen extras, captured here so nix stays the source.
          community_palette = "Oxocarbon";
          wallpaper_scheme = "m3-content";
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

        # Noctalia-internal idle handling via ext-idle-notify (no swayidle:
        # do NOT add swayidle to the niri config). Standard flow:
        # lock -> screen-off -> suspend (mirrors the retired swayidle
        # 300/330/600 timeouts).
        idle.behavior."screen-off" = {
          timeout = 330;
          action = "screen_off";
          enabled = true;
        };

        idle.behavior.suspend = {
          timeout = 600;
          action = "suspend";
          enabled = true;
        };

        lockscreen = {
          enabled = true;
        };

        # Lockscreen layout owned here (nix is the source). Login boxes
        # need explicit entries only to change their settings (no media or
        # weather info row); everything else is defaulted and auto-sized.
        # Positions ride on reference canvases that Noctalia rescales
        # proportionally to the real output (see PlacementMapper), so
        # center-top stays center-top on any size. One entry per connector
        # is still required (a widget renders on exactly one surface;
        # unknown output names are silently skipped). NOTE: applies only
        # while settings.toml has no [lockscreen_widgets] section — the
        # startup round-trip (loadSnapshotFromConfig ->
        # saveSnapshotToConfig) re-pins a stated enabled flag and
        # widget_order over these; see the activation pruning below.
        lockscreen_widgets = {
          enabled = true;
          widget_order =
            (map (o: "lockscreen-login-box@${o.output}") lockscreenOutputs)
            ++ (map (o: "clock-${o.short}") lockscreenOutputs);
          widget = builtins.listToAttrs (
            builtins.concatMap (o: [
              {
                name = "lockscreen-login-box@${o.output}";
                value = {
                  type = "login_box";
                  inherit (o) output;
                  cx = o.loginCx;
                  cy = o.loginCy;
                  placement_width = o.width;
                  placement_height = o.height;
                  settings = lockscreenLoginSettings;
                };
              }
              {
                name = "clock-${o.short}";
                value = lockscreenClock o.output;
              }
            ]) lockscreenOutputs
          );
        };

        osd = {
          position = "bottom_center";
          position_vertical = "bottom_center";
          offset_y = 20;
        };

        dock = {
          enabled = false;
        };

        plugins = {
          enabled = [
            "fr/status"
            "noctalia/notes"
          ];
          auto_update = "none";
        };

        bar.order = [
          "main"
          "bottom"
        ];

        bar.main = {
          position = "top";
          font_scale = 1.1;
          # Full-width bars on all screens: zeroed end/edge margins and
          # square corners (bar `capsule` only toggles per-widget pills,
          # which stay on). eDP-1 inherits this; its override below only
          # carries small-screen budgeting (font scale, lanes).
          capsule = true;
          capsule_border = "outline";
          margin_ends = 0;
          margin_edge = 0;
          radius = 0;
          monitor."eDP-1" = {
            # Small-screen relief, laptop only (widget settings like
            # display/max_length are global; lanes and font scale are
            # per-monitor). Drops weather from the laptop bar, derived
            # from mainBarEnd so base changes propagate, and swaps in
            # the compact active-window; taskbar width budgets (below)
            # apply everywhere.
            font_scale = 1.0;
            start = map (w: if w == "active-window" then "active-window-compact" else w) mainBarStart;
            end = builtins.filter (w: w != "weather") mainBarEnd;
          };
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
          start = mainBarStart;
          center = [ ];
          end = mainBarEnd;
        };

        bar.bottom = {
        };

        bar.bottom = {
          position = "bottom";
          font_scale = 1.1;
          capsule = true;
          capsule_border = "outline";
          margin_ends = 0;
          margin_edge = 0;
          radius = 0;
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
          # Full title on externals; the laptop lane swaps in the compact
          # variant below (widget settings are global-only, lanes are
          # per-monitor).
          "active-window" = {
            type = "active_window";
          };
          # Laptop variant: icon only with a tight width budget so the top
          # bar fits small screens (no wrapping upstream).
          "active-window-compact" = {
            type = "active_window";
            max_length = 120;
            display = "icon_only";
          };
          # DMS-style workspace pills: one capsule per workspace holding that
          # workspace's window icons (needs per-window workspace info from
          # the compositor; stays flat if unavailable).
          "taskbar" = {
            type = "taskbar";
            group_by_workspace = true;
            show_workspace_label = true;
            # Keep "icons"; switch to "dots" if the bar still overflows on
            # small screens (upstream has no wrapping).
            workspace_group_content = "icons";
            show_active_indicator = true;
            # Width budgets so titles shrink/vanish instead of overflowing.
            taskbar_max_width = 400;
            window_title_max_width = 100;
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
          "notes" = {
            type = "noctalia/notes:notes";
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

    # Noctalia round-trips the effective lockscreen layout back into
    # settings.toml on startup/output change (loadSnapshotFromConfig ->
    # saveSnapshotToConfig): tables deep-merge but the stated enabled flag
    # and widget_order replace the declarative ones, so a stale state
    # section would shadow lockscreen_widgets above forever. Prune it on
    # every switch so nix stays the source; Noctalia re-seeds state from
    # these values on next start (it watches both files and hot-reloads).
    # Consequence: Toggle Editor arrangements are reverted by the next
    # switch — rearrange in nix instead.
    home.activation.noctaliaPruneLockscreenState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      stateFile="${config.home.homeDirectory}/.local/state/noctalia/settings.toml"
      if [ -f "$stateFile" ] && grep -q '^\[lockscreen_widgets\]' "$stateFile"; then
        ${pkgs.gnused}/bin/sed -i '/^\[lockscreen_widgets\]/,/^\[/ { /^\[/!d; /^\[lockscreen_widgets\]/d }' "$stateFile"
      fi
    '';

    xdg.dataFile."noctalia/plugins/fr-status" = {
      source = statusPluginDir;
      recursive = true;
    };
  };
}
