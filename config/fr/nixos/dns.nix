{ config, lib, ... }:
let
  cfg = config.fr.public;
  caddyHosts = lib.attrNames (config.services.caddy.virtualHosts or { });
in
{
  config = lib.mkIf cfg.enable {
    services.resolved = {
      enable = lib.mkDefault true;
      settings.Resolve = {
        Cache = "yes";
        DNSOverTLS = lib.mkDefault "opportunistic";
        DNSSEC = lib.mkDefault "allow-downgrade";
        DNSStubListener = "yes";
        DNS = lib.mkDefault [
          "1.1.1.1#cloudflare-dns.com"
          "1.0.0.1#cloudflare-dns.com"
        ];
        FallbackDNS = lib.mkDefault [
          "1.1.1.1#cloudflare-dns.com"
          "1.0.0.1#cloudflare-dns.com"
          "9.9.9.9#dns.quad9.net"
          "149.112.112.112#dns.quad9.net"
        ];
      };
    };

    networking = {
      networkmanager = {
        dns = lib.mkDefault "systemd-resolved";
        # Prefer public resolvers over DHCP-provided router DNS. Some LAN
        # routers time out on UDP/53, adding ~15s to first requests.
        insertNameservers = lib.mkDefault [
          "1.1.1.1"
          "1.0.0.1"
        ];
      };
      hosts = lib.mkIf (caddyHosts != [ ]) {
        "127.0.0.1" = caddyHosts;
      };
    };
  };
}
