{
  desktopPortal = import ./desktop-portal.nix;
  k3sMicrovm = import ./k3s-microvm.nix;
  virtiofsdNixStore = import ./virtiofsd-nix-store.nix;
}
