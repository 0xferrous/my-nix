# `fr/status`

Personal Noctalia widgets for the `fr` configuration.

## Entries

- `crypto` — cryptocurrency prices and percentage changes.
- `ai-usage` — Codex usage from `codexbar`.
- `tailscale` — the active Tailscale profile.
- `config-switch` — transient Home Manager/NixOS switch progress and result.
- `battery` — lockscreen battery percentage and charging status, read from
  UPower.

The first four entries are bar widgets. `battery` is a desktop widget used by
`config/fr/home/noctalia.nix` for the lockscreen layout.

## Rendered examples

Examples of the visible bar text include:

- Crypto: `ETH: 3,421.50 +1.24% BTC: 68,210 -0.35%`
- AI usage: `Codex: S 42% · 3h 10m · W 18% · 5d 2h ago`
- Tailscale: `my-profile`
- Config switch: `⠹ HM 18s`, `✓ NixOS 42s`, or `⚠ HM failed`
- Battery: `85% · charging`, `100% · plugged in`, or `42% · not charging`

The exact values depend on the configured symbols and live service responses.

## Tailscale profile names

The Tailscale widget displays the active profile nickname when profile access is
available. Set a nickname when logging in:

```bash
sudo tailscale login --nickname my-profile
```

List the saved profiles and nicknames with:

```bash
sudo tailscale switch --list --json
```

For Noctalia to read profiles without `sudo`, grant the current user operator
access once:

```bash
sudo tailscale set --operator="$USER"
```

If profile access is unavailable, the widget falls back to the Tailscale
account login name.

## Dependencies

- `codexbar` for `ai-usage`.
- `tailscale` for the active-account widget.
- `upower` for the lockscreen battery widget.

## Configuration

The plugin is copied to Noctalia's data directory by Home Manager and enabled
as `fr/status` in `config/fr/home/noctalia.nix`. Widget settings are declared
in `plugin.toml` and configured through Noctalia's normal widget settings.
