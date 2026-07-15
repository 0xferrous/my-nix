{ pkgs, ... }:
with pkgs;
[
  # Network and web tools
  xh
  wget
  aria2
  websocat
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
