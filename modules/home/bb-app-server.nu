#!/usr/bin/env nu

# Start bb-app with BB_APP_URL from the service environment when supplied;
# otherwise derive it from this machine's Tailscale MagicDNS name. This lets a
# per-machine systemd user drop-in override the URL without changing repo
# config. The OS hostname is deliberately not used: the Tailscale hostname can
# differ from it (e.g. OS `nixos` vs Tailscale `fr-vm`).

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
  bb_app: string,
  tailscale: string,
  server_bind_host: string,
] {
  if ($env.BB_APP_URL? | default "" | is-empty) {
    mut host = (tailscale-dns-name $tailscale)
    for _ in 1..15 {
      if ($host | is-not-empty) { break }
      sleep 1sec
      $host = (tailscale-dns-name $tailscale)
    }

    if ($host | is-not-empty) {
      let port = ($env.BB_SERVER_PORT? | default "38886")
      $env.BB_APP_URL = $"http://($host):($port)"
    }
  }

  exec $bb_app --server-bind-host $server_bind_host
}
