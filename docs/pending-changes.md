# Pending changes

Rolling log of experiments, partial attempts, blocked work, and upcoming changes.

## In progress / queued

- [ ] iron-proxy × ash — token injection on the Ash VM bridge:
  - Host package `packages.iron-proxy` (v0.49.0 source build with the
    expired-certificate cache patch from upstream PR #235, not in nixpkgs)
    and NixOS module `fr.iron-proxy` (tunnel listener on
    `192.168.127.1:8080`, MITM CA in `/var/lib/iron-proxy`, loopback high
    ports for the always-on http/https/metrics listeners to avoid Caddy on
    `:80`/`:443`). Verified end-to-end: inject mode and swap mode both
    deliver real secrets upstream with no secret leak in audit logs.
  - Guest side wired: `security.pki.certificateFiles` trusts the committed
    `modules/nixos/iron-proxy-ca.crt` (10y CA generated 2026-08-09), and
    `HTTP_PROXY/HTTPS_PROXY/ALL_PROXY=http://192.168.127.1:8080` with
    `NO_PROXY=localhost,127.0.0.0/8,192.168.127.0/24,.ash.local,.ts.net,100.64.0.0/10`
    are set for both the system and Home Manager sessions. Nix-daemon and
    agent-auto-switch intentionally bypass the proxy (no system-wide env).
  - Live on the host: guest audit entries show
    `tunnel.target=httpbingo.org:443` allow/200 through MITM
    (guest 192.168.127.112), and the httpbingo.org `TEST_API_KEY` inject
    entry (commit 3f70c85) verified working — guest sees
    `Authorization: Bearer sk-test-verify-123` upstream and the audit shows
    the `injected` annotation.
  - Remaining: point agent tools (codex/opencode/gh) at placeholders (inject
    mode) or proxy tokens (swap mode) for the actual secrets to swap.
  - Open question: per-VM token isolation and whether to add an `allowlist`
    in warn mode for the free audit data.

- [ ] hints follow-up — unresolved issues:
  - Electron/Chromium still need `--force-renderer-accessibility`; `ACCESSIBILITY_ENABLED=1` alone is not enough, and `~/.config/electron-flags.conf` is not honored by Nixpkgs Electron wrappers.
  - Signal works with AT-SPI only when launched with `--force-renderer-accessibility`; normal launch falls back to noisy OpenCV hints.
  - Kitty likely cannot expose useful AT-SPI hints; prefer kitty-native `kitten hints`.
  - OpenCV fallback produces hundreds of poor hints in unsupported apps; decide whether to disable or tune it.
  - Still need a GTK sanity test (`pavucontrol`, `nautilus`, etc.) to confirm the AT-SPI setup is sound.
  - The AT-SPI warning `Unknown object '/org/a11y/atspi/cache'` remains; unclear if harmful.
  - Overlay debounce is currently a `0.25s` workaround for launch-key leakage.
