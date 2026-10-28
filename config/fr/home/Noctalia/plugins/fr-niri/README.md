# `fr/niri`

Noctalia launcher provider for searching explicitly titled Niri binds. Type
`/niri` in the launcher, then search by key, hotkey-overlay title, or action.
Selecting a result opens Niri's built-in hotkey overlay.

The helper reads the active config path (`NIRI_CONFIG`, or
`~/.config/niri/config.kdl`), follows relative `include` files in order, and
applies Niri's same-key bind replacement rule. It lists user-configured titles;
Niri's built-in overlay entries are not included in launcher search.

The plugin is enabled and copied into Noctalia's plugin directory by
`config/fr/home/noctalia.nix`.
