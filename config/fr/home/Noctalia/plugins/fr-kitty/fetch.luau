--!nonstrict
-- Shared Kitty remote-control helpers for the fr/kitty entries.

local kitty = require("./kitty.luau")

local M = {}

-- `kitten @ ls` embeds each window's environment, which can run to hundreds of
-- KB and makes `noctalia.json.decode` exceed the 25 ms async-callback CPU
-- budget. `ls-filter.jq` reduces it to one unit-separated line per pane in the
-- subprocess (whose CPU is not budgeted); the plugin parses those lines
-- directly. The socket and filter path are passed as positional arguments, so
-- nothing is interpolated into the shell script. Requires `jq` on PATH.
local LS_SCRIPT = [==[if ! command -v jq >/dev/null 2>&1; then echo "jq is required by fr/kitty" >&2; exit 127; fi; out="$(kitten @ --to "$1" ls)" || exit 1; printf '%s' "$out" | jq -r -f "$2"]==]

local function filterPath()
  local dir = noctalia.pluginDir()
  if type(dir) == "string" and dir ~= "" then
    return dir .. "/ls-filter.jq"
  end
  return "ls-filter.jq"
end

-- Explicit `socket` setting, then KITTY_LISTEN_ON, then every
-- `$XDG_RUNTIME_DIR/kitty*` socket (Kitty appends `-<pid>`).
function M.discoverSockets()
  local configured = noctalia.getConfig("socket")
  local listenOn = noctalia.getenv("KITTY_LISTEN_ON")
  local runtime = noctalia.getenv("XDG_RUNTIME_DIR")
  local dirEntries = nil
  if type(runtime) == "string" and runtime ~= "" then
    dirEntries = noctalia.listDir(runtime)
  end
  return kitty.socketCandidates(configured, listenOn, runtime, dirEntries)
end

-- Focuses a pane on the socket it came from, which also switches tab/OS window.
--
-- On Wayland, kitty's `focus-window` only raises the OS window when it holds a
-- valid activation token (`focus_os_window` ignores an empty one). When this
-- runs from the launcher, Noctalia owns the focus so kitty cannot obtain a
-- token and the workspace never switches. As a compositor assist, resolve the
-- kitty OS window by its title in niri and focus it through niri's IPC, which
-- is not token-gated; then let kitty select the pane/tab. On compositors
-- without `niri` this is a no-op and kitty's own activation is all that runs.
--
-- The socket, pane id, OS window title, and delay are positional arguments,
-- never interpolated into the shell script.
local FOCUS_SCRIPT = [==[
# Noctalia's own window provider reaches niri over its socket in-process, but a
# plugin has to shell out, and the systemd user service may not have the niri/jq
# binaries on PATH. Look in the usual profile locations as well.
find_bin() {
  command -v "$1" 2>/dev/null && return 0
  for dir in /run/current-system/sw/bin "$HOME/.nix-profile/bin" "/etc/profiles/per-user/$USER/bin"; do
    if [ -x "$dir/$1" ]; then
      echo "$dir/$1"
      return 0
    fi
  done
  return 1
}

NIRI="$(find_bin niri)"
JQ="$(find_bin jq)"
os_title="$3"
win_id=""
if [ -z "$os_title" ]; then
  :
elif [ -z "$NIRI" ] || [ -z "$JQ" ]; then
  echo "niri/jq not found (niri=${NIRI:-none} jq=${JQ:-none})" >&2
else
  # Resolve the OS window id before kitty runs: focusing a pane changes the OS
  # window title, which would break the title match afterwards.
  win_id="$("$NIRI" msg --json windows 2>/dev/null | "$JQ" -r --arg t "$os_title" '.[] | select((.app_id // "") | test("kitty")) | select(((.title // "") | gsub("^\\s+|\\s+$"; "")) == ($t | gsub("^\\s+|\\s+$"; ""))) | .id' 2>/dev/null | head -n1)"
  [ -n "$win_id" ] || echo "no niri kitty window matched title: $os_title" >&2
fi
# Switch the pane/tab immediately; kitty's internal focus needs no token.
kitten @ --to "$1" focus-window --match "id:$2"
# Switch workspace, re-asserting a few times in case the launcher's close grabs
# focus back. $4 is the delay before the first attempt.
if [ -n "$win_id" ]; then
  for step in "$4" 0.12 0.13 0.15; do
    sleep "$step"
    "$NIRI" msg action focus-window --id "$win_id" >/dev/null
  done
fi
]==]

function M.focus(entry)
  if entry == nil or entry.socket == nil then
    noctalia.log("kitty: focus skipped (no socket)")
    return
  end
  local delayMs = tonumber(noctalia.getConfig("focus_delay_ms")) or 0
  delayMs = math.max(0, math.min(2000, delayMs))
  local delaySeconds = string.format("%.3f", delayMs / 1000)
  noctalia.runAsync(
    {
      "sh",
      "-c",
      FOCUS_SCRIPT,
      "kitty-focus",
      entry.socket,
      tostring(entry.win_id),
      entry.os_title or "",
      delaySeconds,
    },
    function(result)
      if result.exitCode ~= 0 then
        local detail = noctalia.string.trim(result.stderr or "")
        if detail == "" then
          detail = tostring(entry.display_title)
        end
        noctalia.notifyError(noctalia.tr("errors.focus-failed"), detail)
      elseif noctalia.string.trim(result.stderr or "") ~= "" then
        noctalia.log("kitty: focus stderr: " .. noctalia.string.trim(result.stderr))
      end
    end
  )
end

-- Fetches every pane across all discovered sockets. `callback` receives
-- `{ entries = ..., failed = ..., sockets = ... }`.
function M.fetch(callback, timeoutMs)
  local sockets = M.discoverSockets()
  if #sockets == 0 then
    callback({ entries = {}, failed = {}, sockets = sockets })
    return
  end

  local pending = #sockets
  local collected = {}
  local failed = {}

  local function finish()
    kitty.reindex(collected)
    callback({ entries = collected, failed = failed, sockets = sockets })
  end

  for _, socket in ipairs(sockets) do
    local started = noctalia.runAsync({ "sh", "-c", LS_SCRIPT, "kitty-ls", socket, filterPath() }, function(result)
      local ok, err = pcall(function()
        if result.timedOut then
          table.insert(failed, socket .. ": timed out")
        elseif result.exitCode ~= 0 then
          local detail = noctalia.string.trim(result.stderr or "")
          if detail == "" then
            detail = "exit code " .. tostring(result.exitCode)
          end
          table.insert(failed, socket .. ": " .. detail)
        else
          for _, entry in ipairs(kitty.parseLines(result.stdout or "", socket)) do
            table.insert(collected, entry)
          end
        end
      end)
      if not ok then
        noctalia.log("kitty: callback error: " .. tostring(err))
        table.insert(failed, socket .. ": " .. tostring(err))
      end
      pending = pending - 1
      if pending == 0 then
        local finishOk, finishErr = pcall(finish)
        if not finishOk then
          noctalia.log("kitty: finish error: " .. tostring(finishErr))
        end
      end
    end, timeoutMs or 8000)

    if not started then
      noctalia.log("kitty: could not start ls for " .. socket)
      table.insert(failed, socket .. ": " .. noctalia.tr("errors.spawn-failed"))
      pending = pending - 1
      if pending == 0 then
        local finishOk, finishErr = pcall(finish)
        if not finishOk then
          noctalia.log("kitty: finish error: " .. tostring(finishErr))
        end
      end
    end
  end
end

return M
