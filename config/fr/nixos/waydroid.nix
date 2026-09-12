{ pkgs, ... }:
{
  virtualisation.waydroid = {
    enable = true;
    package = pkgs.waydroid-nftables;
  };

  # Allow clipboard sharing between Waydroid and the Wayland session.
  environment.systemPackages = [ pkgs.wl-clipboard ];
}
