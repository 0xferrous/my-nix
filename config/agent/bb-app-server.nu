#!/usr/bin/env nu

# Start the bb-app server with BB_APP_URL derived from this machine's
# Tailscale MagicDNS name. bb-app uses BB_APP_URL for generated links, allowed
# browser origins, and the allowed request Host header, so it must be the
# tailnet address (not loopback) for the server to be reachable from other
# devices. The OS hostname is deliberately not used: the Tailscale hostname can
# differ from it (e.g. OS `nixos` vs Tailscale `fr-vm`).

# Return this node's MagicDNS name without the trailing dot, or an empty string
# when Tailscale is not running yet.
def tailscale-dns-name [tailscale: string] {
  try {
    let status = (run-external $tailscale "status" "--json" | from json)
    if $status.BackendState == "Running" and ($status.Self.DNSName? | is-not-empty) {
      $status.Self.DNSName | str trim --right --char "."
    } else {
      ""
    }
  } catch {
    ""
  }
}

def main [
  bb_app: string, # Path to the bb-app executable
  tailscale: string, # Path to the tailscale CLI
] {
  mut host = (tailscale-dns-name $tailscale)
  # Wait briefly for Tailscale on a cold boot before falling back to local-only.
  for _ in 1..15 {
    if ($host | is-not-empty) { break }
    sleep 1sec
    $host = (tailscale-dns-name $tailscale)
  }

  if ($host | is-not-empty) {
    let port = ($env.BB_SERVER_PORT? | default "38886")
    $env.BB_APP_URL = $"http://($host):($port)"
  }

  exec $bb_app --server-bind-host 0.0.0.0
}
