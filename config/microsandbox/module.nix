{ lib, pkgs, ... }:

{
  # microsandbox supplies the kernel and boot-time network configuration.
  boot.isContainer = lib.mkDefault true;

  # These services target devices or host facilities that microsandbox does
  # not provide. Keep these as ordinary NixOS defaults so a consuming config
  # can intentionally override them instead of inheriting image-level masks.
  systemd.services."serial-getty@hvc0".enable = lib.mkDefault false;
  systemd.services.systemd-sysctl.enable = lib.mkDefault false;
  systemd.services.dhcpcd.enable = lib.mkDefault false;
  systemd.services.resolvconf.enable = lib.mkDefault false;

  # microsandbox's guest init configures eth0, the default route, and
  # /etc/resolv.conf from its per-sandbox network payload.
  networking.useDHCP = lib.mkDefault false;
  networking.resolvconf.enable = lib.mkDefault false;
  networking.firewall.enable = lib.mkDefault false;

  # Build a runtime CA bundle that preserves the NixOS CA set and adds the
  # per-sandbox microsandbox MITM CA. The original NixOS bundle remains
  # available through /etc/pki/tls/certs/ca-bundle.crt.
  systemd.services.microsandbox-ca-bundle = {
    description = "Trust the microsandbox MITM CA";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    before = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # agentd mounts the per-sandbox CA after the guest filesystem exists.
      while [ ! -s /.msb/tls/ca.pem ]; do
        ${pkgs.coreutils}/bin/sleep 1
      done

      ${pkgs.coreutils}/bin/mkdir -p /run/microsandbox
      ${pkgs.coreutils}/bin/cat \
        /etc/pki/tls/certs/ca-bundle.crt \
        /.msb/tls/ca.pem \
        > /run/microsandbox/ca-bundle.crt

      # agentd sets SSL_CERT_FILE to this path for guest processes. Point it
      # at the writable merged bundle without changing the NixOS source set.
      ${pkgs.coreutils}/bin/rm -f /etc/ssl/certs/ca-certificates.crt
      ${pkgs.coreutils}/bin/ln -s \
        /run/microsandbox/ca-bundle.crt \
        /etc/ssl/certs/ca-certificates.crt
    '';
  };

  # Re-run the one-shot setup after nixos-rebuild has regenerated /etc.
  system.activationScripts.microsandboxCaBundle = {
    text = ''
      ${pkgs.systemd}/bin/systemctl try-restart microsandbox-ca-bundle.service || true
    '';
    deps = [ ];
  };
}
