{
  pkgs,
  lib,
  system,
  myNixInputs,
  ...
}:
with pkgs;
[
  # AMD GPU
  ollama-rocm
  amdgpu_top

  # Wayland screen recording
  wf-recorder
  wl-screenrec

  # Wayland compositors and utilities
  cage
  wofi-pass
  wofi-emoji
  wlr-which-key
  xwayland-satellite
  cosmic-files
  slurp

  # Rofi-based menus
  myNixInputs.frs-xofi-menus.packages.x86_64-linux.rofi-dfl-dir
  bluetui
  rofi-bluetooth
  rofi-network-manager
  rofi-systemd
  rofi-pulse-select

  # Browsers (hardcoded x86_64-linux in original, keep platform-pinned)
  myNixInputs.zen-browser.packages.x86_64-linux.twilight
  myNixInputs.helium.packages.${system}.default

  # GNOME / GTK
  nwg-displays
  nwg-look
  gnome-font-viewer
  gnome-tweaks
  gnome.gvfs

  # Linux system libraries
  pcsclite

  # EWW widget system
  eww

  # PulseAudio / ALSA
  pulseaudio
  pamixer
  pavucontrol
  pasystray
  playerctl
  brightnessctl

  # Linux networking
  unixtools.ifconfig
  usbutils
  nftables

  # Linux containers and virtualization
  distrobox
  samba
  swtpm
  gvisor

  # Systemd / D-Bus
  libsecret
  showmethekey

  # Man pages
  man-pages-posix
  man-pages

  # Linux desktop
  emacs-pgtk
  libreoffice-qt6
  fractal

  # FUSE
  google-drive-ocamlfuse

  # Monitor control
  ddcutil
  ddcui

  # Uncertain macOS support — keeping in linux.nix
  myNixInputs.agent-box.packages.${system}.portal
  myNixInputs.wifitui.packages.${system}.default
  numr
  railway-wallet
  global-platform-pro
  spacer
  podman
]
