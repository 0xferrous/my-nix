from typing import Any

from kitty.fast_data_types import get_boss

KITTEN_SSH_SYMBOL = "🐱 "
SSH_SYMBOL = "🐶 "


def draw_title(data: dict[str, Any]) -> str:
    """Return a prefix describing the active window's SSH connection."""
    tab = get_boss().tab_for_id(data["tab_id"])
    window = tab.active_window if tab is not None else None
    if window is None:
        return ""

    # Check this first because the SSH kitten ultimately runs ssh as well.
    if window.ssh_kitten_cmdline():
        return KITTEN_SSH_SYMBOL
    if window.child_is_remote:
        return SSH_SYMBOL
    return ""
