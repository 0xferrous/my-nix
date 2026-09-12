{
  pkgs,
  bbPackage ? pkgs.bb,
  name,
  remoteUrl,
}:
let
  wrapper = pkgs.writeShellScriptBin "bb-desktop-${name}" ''
    set -euo pipefail

    export XDG_CONFIG_HOME="$HOME/.config/bb-profiles/${name}"
    export BB_DESKTOP_REMOTE_URL=${pkgs.lib.escapeShellArg remoteUrl}

    exec ${bbPackage}/bin/bb-desktop "$@"
  '';
in
{
  package = wrapper;
  desktopEntry = {
    type = "Application";
    categories = [
      "Development"
      "Utility"
    ];
    comment = "BB Desktop (${name})";
    exec = "${wrapper}/bin/bb-desktop-${name} %U";
    genericName = "Agent workspace";
    icon = "bb-desktop";
    name = "BB Desktop ${name}";
  };
}
