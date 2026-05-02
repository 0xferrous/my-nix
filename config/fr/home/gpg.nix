{ pkgs, config, ... }:

let
  pinentrySmart = pkgs.writeShellScriptBin "pinentry-smart" ''
    set -euo pipefail

    if [[ -n "''${WAYLAND_DISPLAY:-}" || -n "''${DISPLAY:-}" ]]; then
      "${pkgs.pinentry-rofi}/bin/pinentry-rofi" "$@" || exec "${pkgs.pinentry-tty}/bin/pinentry-tty" "$@"
    else
      exec "${pkgs.pinentry-tty}/bin/pinentry-tty" "$@"
    fi
  '';
in
{
  programs.gpg = {
    enable = true;
    scdaemonSettings = {
      debug-level = "expert";
      log-file = "/tmp/scdaemon.log";
      disable-ccid = true;
    };
  };

  services.gpg-agent = {
    enable = true;
    pinentry = {
      package = pinentrySmart;
      program = "pinentry-smart";
    };
    enableNushellIntegration = true;
    extraConfig = ''
      debug-level expert
      log-file /tmp/gpg-agent.log
    '';
  };

  home.file."${config.programs.gpg.homedir}/common.conf".text = ''
    use-keyboxd
  '';
}
