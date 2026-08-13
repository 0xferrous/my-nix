#!/usr/bin/env python3
# kitty session autosave (loaded in-process via `watcher autosave_session.py`).
#
# Saves the current kitty state -- OS windows, tabs, layouts/splits, per-window
# cwds, env, titles -- to a session file so the next launch can restore it via
# `startup_session` in kitty.conf.
#
# Coverage:
#   * Exact save on quit (on_quit, fired by the quit action / ctrl+shift+q).
#   * Throttled saves on structural changes (tab bar, focus, resize, shell
#     command start/stop) as a crash/kill safety net, so the file is at most
#     SAVE_INTERVAL_SECONDS stale even if kitty is SIGKILLed or closed via WM.

import os
import time
import traceback
from typing import Any

from kitty.boss import Boss
from kitty.config import atomic_save
from kitty.session import default_save_as_session_opts
from kitty.window import Window

# Set to True to also capture the process currently running in each shell
# (requires shell_integration, which is enabled in kitty.conf) and re-run it on
# restore. WARNING: if you quit while a destructive command (rm, mv, ...) is
# running in a shell, it will be re-executed when the session is restored.
CAPTURE_FOREGROUND_PROCESSES = False

AUTOSAVE_PATH = os.path.expanduser('~/.cache/kitty/last-session.kitty-session')
SAVE_INTERVAL_SECONDS = 30.0

_last_save = 0.0


def _save(boss: Boss, force: bool = False) -> None:
    global _last_save
    now = time.monotonic()
    if not force and now - _last_save < SAVE_INTERVAL_SECONDS:
        return
    if not boss.os_window_map:
        # nothing to save; don't clobber a good snapshot during teardown
        return
    try:
        opts = default_save_as_session_opts()
        if CAPTURE_FOREGROUND_PROCESSES:
            opts.use_foreground_process = True
        session = '\\n'.join(boss.serialize_state_as_session(AUTOSAVE_PATH, opts))
        if session.strip():
            os.makedirs(os.path.dirname(AUTOSAVE_PATH), exist_ok=True)
            atomic_save(session.encode(), AUTOSAVE_PATH)
            _last_save = now
    except Exception:
        traceback.print_exc()


def on_quit(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    if data.get('confirmed'):
        _save(boss, force=True)


def on_tab_bar_dirty(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    _save(boss)


def on_focus_change(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    _save(boss)


def on_resize(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    _save(boss)


def on_cmd_startstop(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    _save(boss)
