{
  lib,
  home-manager,
  myNixInputs,
  pkgs,
  ...
}:
let
  # Keep the low-memory Electron limits specific to the OCI image build. The
  # host agent still uses the normal bbSource derivation.
  bbSourceContainer = pkgs.bbSource.overrideAttrs (old: {
    preBuild = (old.preBuild or "") + ''
      export NODE_OPTIONS="--max-old-space-size=2048"
      export npm_config_jobs=1
      export npm_config_child_concurrency=1
      export MAKEFLAGS=-j1
      export TURBO_CONCURRENCY=1
    '';
  });
in
{
  imports = [
    home-manager.nixosModules.home-manager
    "${myNixInputs.nixpkgs}/nixos/modules/virtualisation/docker-image.nix"
  ];

  # The OCI image supplies a NixOS userspace; smolvm or microsandbox supplies
  # the guest kernel and virtual hardware.
  boot.isContainer = true;
  networking.useHostResolvConf = lib.mkForce false;

  # The shared impermanence configuration remains active; the runtime must
  # mount a persistent guest directory at /persist.

  # Ash is the host VM integration and is not needed inside another VM.
  virtualisation.ash-guest.enable = lib.mkForce false;
  fr.ash-vm-mdns.enable = lib.mkForce false;

  # These boot-time rebuilds expect the Ash workspace share. Re-enable them
  # only after mounting the repository and adapting the target configuration.
  systemd.services.agent-auto-switch.enable = false;
  systemd.services.agent-home-switch.enable = false;
  systemd.timers.agent-auto-switch.enable = false;
  systemd.timers.agent-home-switch.enable = false;

  # zram is supplied by the guest kernel, so leave it out of the first OCI
  # image until the selected runtime's kernel is known to provide it.
  zramSwap.enable = lib.mkForce false;

  # Install the existing agent Home Manager profile into the image rather than
  # waiting for the disabled host-share auto-switch service.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit myNixInputs;
      agentUseBbSource = true;
      bbPackageOverride = bbSourceContainer;
    };
    users.agent = import ./home.nix;
  };
}
