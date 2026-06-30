{ config, lib, ... }:
let
  cfg = config.fr.public;
  caddyHosts = lib.attrNames (config.services.caddy.virtualHosts or { });
in
{
  config = lib.mkIf cfg.enable {
    services.resolved = {
      enable = lib.mkDefault true;
      dnssec = lib.mkDefault "allow-downgrade";
      dnsovertls = lib.mkDefault "opportunistic";
      fallbackDns = lib.mkDefault [
        "1.1.1.1#cloudflare-dns.com"
        "1.0.0.1#cloudflare-dns.com"
        "9.9.9.9#dns.quad9.net"
        "149.112.112.112#dns.quad9.net"
      ];
      settings.Resolve = {
        Cache = "yes";
        DNSStubListener = "yes";
      };
    };

    networking = {
      networkmanager.dns = lib.mkDefault "systemd-resolved";
      hosts = lib.mkIf (caddyHosts != [ ]) {
        "127.0.0.1" = caddyHosts;
      };
    };
  };
}
