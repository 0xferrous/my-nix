# Pending changes

Rolling log of experiments, partial attempts, blocked work, and upcoming changes.

## In progress / queued

- [ ] hints follow-up — unresolved issues:
  - Electron/Chromium still need `--force-renderer-accessibility`; `ACCESSIBILITY_ENABLED=1` alone is not enough, and `~/.config/electron-flags.conf` is not honored by Nixpkgs Electron wrappers.
  - Signal works with AT-SPI only when launched with `--force-renderer-accessibility`; normal launch falls back to noisy OpenCV hints.
  - Kitty likely cannot expose useful AT-SPI hints; prefer kitty-native `kitten hints`.
  - OpenCV fallback produces hundreds of poor hints in unsupported apps; decide whether to disable or tune it.
  - Still need a GTK sanity test (`pavucontrol`, `nautilus`, etc.) to confirm the AT-SPI setup is sound.
  - The AT-SPI warning `Unknown object '/org/a11y/atspi/cache'` remains; unclear if harmful.
  - Overlay debounce is currently a `0.25s` workaround for launch-key leakage.
