# Shared iron-proxy tunnel env for the agent guest, imported by both
# config/agent/nixos.nix (system session) and config/agent/home.nix
# (Home Manager session) so the two cannot drift out of sync.
let
  # Host iron-proxy tunnel listener that injects real credentials.
  url = "http://192.168.127.1:8080";
  # Hosts that bypass the tunnel.
  # NOTE: keep literal 127.0.0.1/::1 entries, not just the 127.0.0.0/8
  # CIDR. Bun-based tools (e.g. opencode2) do not honor CIDR ranges in
  # NO_PROXY, so without the literals their localhost traffic goes through
  # the proxy (the opencode2 TUI hangs at "Starting background server...").
  noProxy = "localhost,127.0.0.1,::1,127.0.0.0/8,192.168.127.0/24,.ash.local,.ts.net,100.64.0.0/10";
in
{
  inherit url noProxy;
  # Env shared by both sessions. Each side merges its own extras on top
  # (lowercase variants + login-only vars on the system side, NIXOS_OZONE_WL
  # on the Home Manager side).
  sessionEnv = {
    HTTP_PROXY = url;
    HTTPS_PROXY = url;
    ALL_PROXY = url;
    NO_PROXY = noProxy;
    # rustls-based tools (obscura, etc.) ignore the system trust store and
    # default to bundled webpki roots; point them at the NixOS bundle, which
    # includes the iron-proxy CA, so HTTPS through the MITM tunnel verifies.
    SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
    # Bun/Node ignore the system trust store; point them at the iron-proxy
    # MITM CA so proxied HTTPS (and injected credentials) verify too.
    NODE_EXTRA_CA_CERTS = ../../modules/nixos/iron-proxy-ca.crt;
  };
}
