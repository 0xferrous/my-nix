{ pkgs, ... }:
with pkgs;
[
  # Screenshot / GUI interaction
  flameshot
  hints

  # Media players and viewers
  mpv
  freetube
  obs-studio

  # Browsers
  google-chrome

  # GUI communication
  halloy
  fluffychat
  element-desktop
]
