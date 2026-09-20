{
  lib,
  pkgs,
  myNixInputs,
  agentUseBbSource ? true,
  bbPackageOverride ? null,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  isX86 = system == "x86_64-linux";
  AIPackages = myNixInputs.llm-agents.packages.${system};
  proxy = import ./proxy.nix;
  upstreamOpenCode = myNixInputs.opencode.packages.${system}.opencode;
  opencode = upstreamOpenCode.override {
    node_modules = upstreamOpenCode.node_modules.override {
      hash = "sha256-SVvFPO+KuS67+6XGPhaB3cIuc3XUyM0XVccy5v8afS4=";
    };
  };
  bbPackage =
    if bbPackageOverride != null then
      bbPackageOverride
    else if agentUseBbSource then
      pkgs.bbSource
    else
      null;
  opencodeDesktop =
    (myNixInputs.opencode.packages.${system}.opencode-desktop.override {
      inherit opencode;
    }).overrideAttrs
      (old: {
        # The new-session workspace picker is omitted from production builds, while
        # the bundled server requires this runtime flag for workspace operations.
        env = old.env // {
          OPENCODE_CHANNEL = "beta";
        };
        # The beta build generates only its channel-specific AppStream file,
        # while upstream's Nix install phase always installs the production one.
        postBuild = (old.postBuild or "") + ''
          bun ./scripts/copy-metainfo.ts prod
        '';
        postInstall = (old.postInstall or "") + ''
          wrapProgram "$out/bin/opencode-desktop" \
            --set OPENCODE_EXPERIMENTAL_WORKSPACES true
        '';
      });
  chatgpt = pkgs.symlinkJoin {
    name = "chatgpt-wrapped";
    paths = [ AIPackages.chatgpt ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/chatgpt" \
        --prefix XDG_DATA_DIRS : "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
    '';
  };
  devEssentialsPackages = import ../shared/packages/dev-essentials.nix {
    inherit pkgs AIPackages;
    includeOhMyPi = isX86;
  };
  zjRadar = {
    default = pkgs.zjRadar;
  };
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
  agentPortalWrappers = pkgs.runCommand "agent-portal-wrappers" { } ''
    cp -R ${myNixInputs.ash.packages.${system}.agent-portal-wrappers} "$out"
    chmod -R u+w "$out"
    mv "$out/bin/gh" "$out/bin/gh-portal"
  '';
in
{
  imports = [
    ../../modules/home/programs/direnv.nix
    ../../modules/home/programs/foundry.nix
    ../../modules/home/programs/nushell.nix
    ../../modules/home/programs/nushell-session-vars.nix
    ../fr/home/hunk.nix
  ];

  home = {
    username = "agent";
    homeDirectory = "/home/agent";
    stateVersion = "26.05";
    packages =
      lib.optional (bbPackage != null) bbPackage
      ++ [
        chatgpt
        pkgs.obscura
        pkgs.piDev
        pkgs.waypipe
        pkgs.xwayland-satellite
        myNixInputs.codexbar.packages.${system}.default
        agentPortalWrappers
        myNixInputs.ash.packages.${system}."ash-dbus-proxy"
        AIPackages.opencode2
        opencodeDesktop
      ]
      ++ devEssentialsPackages;
    # Same iron-proxy tunnel as the system session (proxy.sessionEnv plus
    # lowercase proxy.sessionEnvLower — Bun/Node only honor lowercase
    # `no_proxy`), so shells, TUI-spawned background servers, and desktop
    # entries started outside a login session also route egress through it
    # while loopback still bypasses (literals required, Bun ignores CIDR).
    sessionVariables =
      proxy.sessionEnv
      // proxy.sessionEnvLower
      // {
        # Enable upstream ChatGPT's Wayland flags; waypipe supplies WAYLAND_DISPLAY.
        NIXOS_OZONE_WL = "1";
      };
  };

  # systemd user manager (user services, desktop entries, TUI-spawned
  # background server) does not source login-shell sessionVariables, so
  # export the same tunnel env there explicitly. Values must be strings
  # (unlike home.sessionVariables, paths are not coerced), hence toString.
  systemd.user.sessionVariables = lib.mapAttrs (_: v: toString v) (
    proxy.sessionEnv // proxy.sessionEnvLower
  );

  # Nushell creates a starter config when this file is absent. Remove it before
  # Home Manager links its declarative replacement.
  home.activation.removeNushellStarterConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ -e "$HOME/.config/nushell/config.nu" ] && [ ! -L "$HOME/.config/nushell/config.nu" ]; then
      rm -f "$HOME/.config/nushell/config.nu"
    fi
  '';

  # Seed a per-VM bb-app environment drop-in without managing its contents.
  # This lets each agent VM provide its own GitHub token independently.
  home.activation.createBbAppGithubTokenDropin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    token_dir="$HOME/.config/systemd/user/bb-app.service.d"
    token_file="$token_dir/github-token.conf"
    if [ ! -e "$token_file" ]; then
      ${pkgs.coreutils}/bin/mkdir -p "$token_dir"
      ${pkgs.coreutils}/bin/printf '%s\n' \
        '[Service]' \
        'Environment=GITHUB_TOKEN=replace-me' \
        > "$token_file"
      ${pkgs.coreutils}/bin/chmod 600 "$token_file"
    fi
  '';

  # virtiofs shares return ESTALE when git creates loose objects via its
  # default hardlink+unlink pattern (see fs/fuse inode handling). Rename-based
  # creation avoids it; see git config core.createobject.
  programs.git = {
    enable = true;
    includes = [ { path = "~/.config/git/private.config"; } ];
    settings = {
      core = {
        createobject = "rename";
      };
    };
  };

  programs.jujutsu.enable = true;

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

  systemd.user.services = {
    ash-dbus-proxy = {
      Unit.Description = "Ash host notification D-Bus bridge";
      Service = {
        ExecStart = "${ashDbusProxy}/bin/ash-dbus-proxy connect --listen %t/ash-dbus-proxy/bus.sock --cid 2 --managed";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = [ "default.target" ];
    };

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
  }
  // lib.optionalAttrs (bbPackage != null) {
    bb-app = {
      Unit.Description = "bb agent server";
      Service = {
        ExecStart = "${bbPackage}/bin/bb-app --server-bind-host 0.0.0.0";
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

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
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

  fr.nushell-session-vars.enable = true;

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
