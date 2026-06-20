{
  desktopPortal = import ./desktop-portal.nix;
  k3sMicrovm = import ./k3s-microvm.nix;
  powerManagement = import ./power-management.nix;
  virtiofsdNixStore = import ./virtiofsd-nix-store.nix;
}
