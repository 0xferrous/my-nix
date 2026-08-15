{
  lib,
  pkgs,
  myNixInputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  zjRadar = myNixInputs.zj-radar.packages.${system};
  zjRadarPlugin =
    pkgs.runCommand "zellij-plugin-zj-radar.wasm"
      {
        pname = "zellij-zj-radar";
        meta.platforms = lib.platforms.unix;
      }
      ''
        cp ${zjRadar.default}/bin/zj_radar.wasm "$out"
      '';
  ashDbusProxy = myNixInputs.ash.packages.${system}."ash-dbus-proxy";
in
{
  imports = [
    ../../modules/home/programs/direnv.nix
    ../../modules/home/programs/foundry.nix
    ../fr/home/hunk.nix
  ];

  home = {
    username = "agent";
    homeDirectory = "/home/agent";
    stateVersion = "26.05";
    packages = [
      pkgs.obscura
      myNixInputs.codexbar.packages.${system}.default
      myNixInputs.ash.packages.${system}.agent-portal-wrappers
      myNixInputs.ash.packages.${system}."ash-dbus-proxy"
    ];
    # Same iron-proxy tunnel as the system session, so user systemd services
    # and shells started outside a login session also route egress through it.
    sessionVariables = {
      HTTP_PROXY = "http://192.168.127.1:8080";
      HTTPS_PROXY = "http://192.168.127.1:8080";
      ALL_PROXY = "http://192.168.127.1:8080";
      NO_PROXY = "localhost,127.0.0.0/8,192.168.127.0/24,.ash.local,100.64.0.0/10";
      # rustls-based tools (e.g. obscura) ignore the system trust store and
      # default to bundled webpki roots; the NixOS bundle includes the
      # iron-proxy CA (security.pki.certificateFiles), so proxied HTTPS
      # verifies through the MITM tunnel.
      SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
      # Bun/Node ignore the system trust store; point them at the iron-proxy
      # MITM CA so proxied HTTPS (and injected credentials) verify in user
      # systemd services and non-login shells too.
      NODE_EXTRA_CA_CERTS = ../../modules/nixos/iron-proxy-ca.crt;
    };
  };

  # Nushell creates a starter config when this file is absent. Remove it before
  # Home Manager links its declarative replacement.
  home.activation.removeNushellStarterConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ -e "$HOME/.config/nushell/config.nu" ] && [ ! -L "$HOME/.config/nushell/config.nu" ]; then
      rm -f "$HOME/.config/nushell/config.nu"
    fi
  '';

  # virtiofs shares return ESTALE when git creates loose objects via its
  # default hardlink+unlink pattern (see fs/fuse inode handling). Rename-based
  # creation avoids it; see git config core.createobject.
  programs.git = {
    enable = true;
    settings = {
      core = {
        createobject = "rename";
      };
    };
  };

  programs.herdr = {
    enable = true;
    settings = {
      onboarding = false;
      theme.name = "gruvbox";
      experimental.kitty_graphics = true;
      # Direct Alt+arrow pane focus instead of prefix chords (prefix+h/j/k/l).
      keys = {
        focus_pane_left = "alt+left";
        focus_pane_down = "alt+down";
        focus_pane_up = "alt+up";
        focus_pane_right = "alt+right";
      };
      ui.sidebar.spaces.rows = [
        [
          "state_icon"
          "workspace"
        ]
        [
          "branch"
          "git_status"
          "$jj_status"
        ]
      ];
    };
  };

  systemd.user.services.ash-dbus-proxy = {
    Unit.Description = "Ash host notification D-Bus bridge";
    Service = {
      ExecStart = "${ashDbusProxy}/bin/ash-dbus-proxy connect --listen %t/ash-dbus-proxy/bus.sock --cid 2 --managed";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services = {
    herdr = {
      Unit.Description = "Herdr agent multiplexer server";
      Service = {
        ExecStart = "${pkgs.herdr}/bin/herdr server";
        LimitNOFILE = 1048576;
        Restart = "on-failure";
      };
      Install.WantedBy = [ "default.target" ];
    };

    herdr-jj-reporter = {
      Unit = {
        Description = "Report Jujutsu status to Herdr workspace metadata";
        After = [ "herdr.service" ];
        Requires = [ "herdr.service" ];
      };
      Service = {
        ExecStart = "${pkgs.nushell}/bin/nu ${./herdr-jj-reporter.nu}";
        Environment = "PATH=${
          lib.makeBinPath [
            pkgs.herdr
            pkgs.jujutsu
          ]
        }";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };

  programs.devenv = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.nix-your-shell = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.nushell = {
    enable = true;
    environmentVariables.DEVENV_SHELL_TYPE = "nu";
    settings.show_banner = false;
    # Load after the fzf/zoxide snippets supplied by Home Manager.
    extraConfig = lib.mkAfter (builtins.readFile ../shared/nushell/kitty-ssh-cwd.nu);
  };

  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
    enableZshIntegration = lib.mkForce false;
    options = [
      "--cmd"
      "cd"
    ];
  };

  programs.zellij = {
    enable = true;
    plugins = [ zjRadarPlugin ];
    layouts.radar-sidebar = ./zellij-radar.kdl;
    settings = {
      default_layout = "radar-sidebar";
      theme = "gruvbox-dark";
      pane_frames = false;
      plugins."zj-radar" = {
        density = "cards";
        glyphs = "nerd";
        naming = "managed";
        # Zellij 0.44 can delay the initial ModeUpdate for `attach --create`
        # sessions. Seed Gruvbox immediately; a later mode update still wins.
        theme_bg = "#3c3836";
        theme_fg = "#fbf1c7";
        # Match Zellij's built-in gruvbox-dark text colors exactly: unselected
        # uses #3c3836, selected uses #504945, and both use #fbf1c7 text.
        theme_rail_bg = "#3c3836";
        theme_idle_bg = "#3c3836";
        theme_agent_bg = "#3c3836";
        theme_active_bg = "#504945";
        theme_flash_bg = "#504945";
        theme_dim_fg = "#fbf1c7";
        theme_idle_fg = "#fbf1c7";
        theme_stale_fg = "#fbf1c7";
      };
    };
  };

  fr.direnv = {
    enable = true;
    devenv.enable = true;
    poetry.enable = true;
    layoutDir = {
      enable = true;
      baseDir = "/home/agent/.cache/direnv/layouts";
    };
  };
}
