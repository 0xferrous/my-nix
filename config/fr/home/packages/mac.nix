# Reference-only macOS package list.
# Not currently imported by ../packages.nix; this package set is maintained Linux-first.
{ pkgs, ... }:
with pkgs;
[
  pinentry_mac
  podman
  vfkit
  lima
  libiconv
  aerospace
  skhd
  yabai
]
