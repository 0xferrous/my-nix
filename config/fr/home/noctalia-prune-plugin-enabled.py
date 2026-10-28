#!/usr/bin/env python3
"""Drop Noctalia's app-managed [plugins].enabled override.

The Settings GUI writes this array to settings.toml when a plugin is toggled,
and it wins over the declarative config. Removing only that key keeps nix the
source of truth while preserving other plugin settings.
"""

import sys
import tomllib

import tomli_w


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: noctalia-prune-plugin-enabled.py SETTINGS_TOML", file=sys.stderr)
        return 2

    path = sys.argv[1]
    try:
        with open(path, "rb") as handle:
            settings = tomllib.load(handle)
        plugins = settings.get("plugins")
        if isinstance(plugins, dict) and "enabled" in plugins:
            del plugins["enabled"]
            if not plugins:
                settings.pop("plugins", None)
            with open(path, "wb") as handle:
                tomli_w.dump(settings, handle)
    except (OSError, tomllib.TOMLDecodeError) as error:
        print(f"noctalia: leaving {path} unchanged: {error}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
