{
  lib,
  myNixInputs,
  pkgs,
  ...
}:
let
  ashHostCacheUrl = "http://192.168.127.1:5000";
  proxy = import ./proxy.nix;
  agentPortalWrappers =
    myNixInputs.ash.packages.${pkgs.stdenv.hostPlatform.system}.agent-portal-wrappers;
in
{
  imports = [
    ../../modules/nixos/ash-vm-mdns.nix
    myNixInputs.ash-stable.nixosModules.ashGuest
  ];

  virtualisation.ash-guest = {
    enable = true;
    user = "agent";
    emptyPassword = false;
    sshReadySignal = {
      afterUnits = [ "agent-home-switch.service" ];
      requiredUnits = [ "agent-home-switch.service" ];
    };
  };

  nix.settings = {
    experimental-features = lib.mkAfter [
      "local-overlay-store"
      "read-only-local-store"
    ];
    substituters = lib.mkBefore [ ashHostCacheUrl ];
    trusted-substituters = lib.mkBefore [ ashHostCacheUrl ];
    trusted-public-keys = lib.mkBefore [
      "nixos-1:TpdALX3FryCxN1I/WG+lhTeme19H/Ka035MJchdsYH4="
    ];
    fsync-metadata = false;
    use-sqlite-wal = false;
  };

  environment.etc."gitconfig".text = ''
    [safe]
      directory = /home/agent/dev/fr/my-nix
  '';

  environment.sessionVariables =
    proxy.sessionEnv
    // proxy.sessionEnvLower
    // {
      HARMONIA_CACHE_URL = ashHostCacheUrl;
    };

  security.pki.certificateFiles = [ ../../modules/nixos/iron-proxy-ca.crt ];
  environment.systemPackages = [ agentPortalWrappers ];

  services.dbus.implementation = "dbus";
  services.resolved = {
    enable = true;
    settings.Resolve = {
      Cache = "yes";
      DNSOverTLS = "yes";
      DNSSEC = "allow-downgrade";
      DNSStubListener = "yes";
      DNS = [
        "1.1.1.1#cloudflare-dns.com"
        "1.0.0.1#cloudflare-dns.com"
      ];
      FallbackDNS = [
        "1.1.1.1#cloudflare-dns.com"
        "1.0.0.1#cloudflare-dns.com"
        "9.9.9.9#dns.quad9.net"
        "149.112.112.112#dns.quad9.net"
      ];
    };
  };

  networking.firewall.enable = false;
  networking.nameservers = lib.mkForce [ ];
  fr.ash-vm-mdns.enable = true;
  fr.agent.selfUpdate.enable = true;
}
