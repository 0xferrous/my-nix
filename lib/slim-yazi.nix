# Shared slim yazi build.
#
# Single source for the `optionalDeps` override so identical call sites
# resolve to one derivation. This matters when two package lists land in
# the same buildEnv (e.g. dev-essentials and the termfilechooser TUI
# package in home.packages): two differently-overridden yazi builds of
# the same version collide on /bin/yazi.
#
# Default is empty (no heavy preview/archive helpers like ffmpeg,
# imagemagick, or poppler); pass an explicit list where integrations
# are wanted (see lib/mkAgentBoxImage.nix).
{
  pkgs,
  optionalDeps ? [ ],
}:
pkgs.yazi.override { inherit optionalDeps; }
