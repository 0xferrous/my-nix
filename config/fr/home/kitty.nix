{
  config,
  lib,
  ...
}:

let
  autosaveSession = "${config.home.homeDirectory}/.cache/kitty/last-session.kitty-session";
  seedSession = "${config.home.homeDirectory}/dev/fr/my-nix/config/fr/home/kitty/sessions/startup.conf";
in
{
  fr.symlinks.configFiles."kitty" = {
    target = "config/fr/home/kitty";
    recursive = true;
  };

  # Seed the session-restore autosave file on first install, so the very first
  # kitty launch (before autosave_session.py has written anything) restores
  # sessions/startup.conf instead of logging a missing-session error. Never
  # overwrites an existing autosave.
  home.activation.seedKittyAutosaveSession = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    autosave="${autosaveSession}"
    if [ ! -e "$autosave" ]; then
      seed="${seedSession}"
      if [ -f "$seed" ]; then
        mkdir -p "$(dirname "$autosave")"
        cp "$seed" "$autosave"
      fi
    fi
  '';
}
