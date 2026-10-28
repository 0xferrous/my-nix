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

## Troubleshooting

- Confirm the plugin is enabled: `noctalia msg plugins list | grep fr/niri`.
  The Settings GUI writes a `[plugins].enabled` override to
  `~/.local/state/noctalia/settings.toml`; the Home Manager activation removes
  that override so the declarative list in `config/fr/home/noctalia.nix` wins.
- Run the helper directly: `nu -n ~/.config/niri/keybindings.nu`. It should
  print a JSON array, including the explicitly titled binds.
- Check the provider log: `journalctl --user -u noctalia -e | grep 'niri:'`.
  It reports how many titled bindings were loaded and any helper failure.
- Type `/niri` in the launcher. The provider is not part of the un-prefixed
  global search because `include_in_global_search = false`.
