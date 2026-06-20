{ pkgs, ... }:
with pkgs;
[
  # Network and web tools
  httpie
  xh
  wget
  aria2
  websocat
  doggo
  whois
  dnscrypt-proxy

  # Privacy and security
  mitmproxy

  # Security and encryption
  gnupg
  sequoia-sq

  # VPN
  mullvad-vpn
  wiremix

  # Testing and quality
  ookla-speedtest
]
