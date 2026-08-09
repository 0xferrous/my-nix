# Pending changes

Rolling log of experiments, partial attempts, blocked work, and upcoming changes.

## In progress / queued

- [ ] iron-proxy × ash — token injection on the Ash VM bridge:
  - Host package `packages.iron-proxy` (v0.49.0 release binary, not in
    nixpkgs) and NixOS module `fr.iron-proxy` (tunnel listener on
    `192.168.127.1:8080`, auto-generated MITM CA in `/var/lib/iron-proxy`,
    loopback high ports for the always-on http/https/metrics listeners to
    avoid Caddy on `:80`/`:443`). Verified end-to-end: inject mode and swap
    mode both deliver real secrets upstream with no secret leak in audit logs.
  - Queued: guest side (`config/agent/nixos.nix`) — trust the proxy CA
    (`security.pki.certificateFiles`; needs a repo-committed `ca.crt` since
    guest closures are built on the host), set
    `HTTPS_PROXY/HTTP_PROXY/ALL_PROXY=http://192.168.127.1:8080` with
    `NO_PROXY=192.168.127.0/24,.ash.local,100.64.0.0/10`, point agent tools
    (codex/opencode) at placeholders or proxy tokens.
  - Open question: per-VM token isolation and whether to add an
    `allowlist` in warn mode for the free audit data.

- [ ] hints follow-up — unresolved issues:
  - Electron/Chromium still need `--force-renderer-accessibility`; `ACCESSIBILITY_ENABLED=1` alone is not enough, and `~/.config/electron-flags.conf` is not honored by Nixpkgs Electron wrappers.
  - Signal works with AT-SPI only when launched with `--force-renderer-accessibility`; normal launch falls back to noisy OpenCV hints.
  - Kitty likely cannot expose useful AT-SPI hints; prefer kitty-native `kitten hints`.
  - OpenCV fallback produces hundreds of poor hints in unsupported apps; decide whether to disable or tune it.
  - Still need a GTK sanity test (`pavucontrol`, `nautilus`, etc.) to confirm the AT-SPI setup is sound.
  - The AT-SPI warning `Unknown object '/org/a11y/atspi/cache'` remains; unclear if harmful.
  - Overlay debounce is currently a `0.25s` workaround for launch-key leakage.
