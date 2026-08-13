{
  pkgs,
  ...
}:
let
  quietXwaylandSatellite = pkgs.writeShellScriptBin "xwayland-satellite" ''
    export RUST_LOG="''${RUST_LOG:-error}"
    exec ${pkgs.xwayland-satellite}/bin/xwayland-satellite "$@"
  '';
  virtioVulkanIcd = "${pkgs.mesa}/share/vulkan/icd.d/virtio_icd.x86_64.json";
in
{
  imports = [
    ./nixos.nix
  ];

  # Ash's shared GPU mode exposes QEMU's Venus VirtIO-GPU device. Restrict
  # Vulkan discovery to the matching Mesa guest driver instead of probing
  # unrelated host-native or gfxstream ICDs.
  environment.sessionVariables.VK_DRIVER_FILES = virtioVulkanIcd;

  environment.systemPackages = with pkgs; [
    vulkan-tools
    llama-cpp-vulkan
    waypipe
    quietXwaylandSatellite
  ];

  # The shared GPU is experimental and belongs only in nash guests.
  hardware.graphics.enable = true;
  boot.kernelModules = [ "virtio_gpu" ];
}
