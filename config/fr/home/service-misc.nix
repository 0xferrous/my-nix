{ lib, pkgs, ... }:
{
  services.opensnitch-ui.enable = true;

  services.home-manager.autoExpire = {
    enable = true;
    frequency = "weekly";
    timestamp = "7d";
    store.cleanup = false;
  };

  services.ssh-tpm-agent.enable = true;

  services.wluma = {
    enable = false; # niri does not support wluma
    systemd.enable = false;
  };

  services.clipcat = {
    enable = false;
    enableSystemdUnit = false;
  };

  # `services.agent-portal` comes from the Home Manager module exposed by
  # github:0xferrous/agent-box, imported by the `homeConfigs.fr` flake wrapper.
  services.agent-portal.enable = true;

  systemd.user.services.agent-portal-host.Service.Environment = lib.mkAfter [
    "RUST_LOG=debug"
    "RUST_BACKTRACE=1"
  ];

  services.gnome-keyring.enable = true;

  services.wispd = {
    enable = false;
    rustLog = "info,wisp_source=debug,wispd=debug";
  };

  services.easyeffects = {
    enable = true;
    # TODO: add this
  };

  services.activitywatch = {
    enable = true;
    watchers = {
      aw-watcher-afk = {
        package = pkgs.activitywatch;
        settings = {
          timeout = 300;
          poll_time = 2;
        };
      };
      aw-watcher-window-wayland = {
        package = pkgs.aw-watcher-window-wayland;
        settings = {
          poll_time = 1;
        };
      };
    };
  };

  services.cliphist.enable = true;
}
