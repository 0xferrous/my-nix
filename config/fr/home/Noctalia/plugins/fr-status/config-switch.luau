local view = { kind = "idle" }
local spinnerFrames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinnerIndex = 1
local lastLogRefreshMs = 0

local function nowSec()
  return os.time()
end

local function nowMs()
  if noctalia.nowMs ~= nil then
    return noctalia.nowMs()
  end
  return nowSec() * 1000
end

local function elapsedText(seconds)
  seconds = math.max(0, math.floor(seconds))
  local minutes = math.floor(seconds / 60)
  local remainder = seconds % 60
  if minutes > 0 then
    return tostring(minutes) .. "m " .. tostring(remainder) .. "s"
  end
  return tostring(remainder) .. "s"
end

-- The switch log is a terminal capture and may contain ANSI escape sequences
-- (colors, cursor movement). Noctalia renders plain text without markup, so
-- strip them instead of showing them literally. Some producers drop the ESC
-- byte but keep the "[...m" tail, so also strip escape-stripped sequences.
local function stripAnsi(text)
  if text == nil or text == "" then
    return ""
  end
  -- ESC-prefixed CSI: colors (SGR), cursor movement, erase, etc.
  text = text:gsub("\27%[[0-?]*[ -/]*[@-~]", "")
  -- OSC: window title and friends, terminated by BEL or ST (ESC backslash).
  text = text:gsub("\27%][^\7\27]*\7", "")
  text = text:gsub("\27%][^\7\27]*\27\\", "")
  -- Any remaining ESC-prefixed escape (e.g. charset selection).
  text = text:gsub("\27.", "")
  -- Escape-stripped CSI tails, e.g. "[32;1m" or "[?2026h" without a leading ESC.
  text = text:gsub("%[[0-9;?]+[A-Za-z]", "")
  -- Remaining control characters except tab and newline.
  text = text:gsub("%c", function(c)
    if c == "\n" or c == "\t" then
      return c
    end
    return ""
  end)
  return text
end

local function render()
  local vertical = barWidget.isVertical()
  local container = vertical and ui.column or ui.row

  if view.kind == "idle" then
    barWidget.render(container({ gap = 0 }, {}))
    barWidget.setTooltip("")
    return
  end

  local label = view.target == "nixos" and "NixOS" or "HM"
  local color = "on_surface_variant"
  local icon = ""
  local text = label
  local tooltip = label .. " configuration switch"

  if view.kind == "running" then
    icon = spinnerFrames[spinnerIndex]
    text = label .. " " .. elapsedText(nowSec() - view.started)
    color = "primary"
    tooltip = tooltip .. " in progress"
  elseif view.kind == "success" then
    icon = "✓"
    text = label .. " " .. elapsedText(view.finished - view.started)
    color = "primary"
    tooltip = tooltip .. " completed successfully"
  else
    icon = "⚠"
    text = label .. " failed"
    color = "error"
    tooltip = tooltip .. " failed with exit code " .. tostring(view.exitCode)
  end

  barWidget.render(container({ gap = 6, align = "center" }, {
    ui.label({ text = icon, color = color }),
    ui.label({ text = text, color = color }),
  }))
  if view.log ~= nil and view.log ~= "" then
    tooltip = tooltip .. "\n\n" .. view.log
  end
  barWidget.setTooltip(tooltip)
end

local function refresh()
  noctalia.runAsync({
    "sh",
    "-c",
    "test -r \"$XDG_RUNTIME_DIR/config-switch-status\" && cat \"$XDG_RUNTIME_DIR/config-switch-status\" || true",
  }, function(result)
    local kind, target, started, finished, exitCode = string.match(
      result.stdout,
      "^(%S+)%s+(%S+)%s+(%d+)%s+(%d+)%s+(%-?%d+)"
    )

    if kind == nil then
      view = { kind = "idle" }
    else
      local finishedNumber = tonumber(finished) or 0
      if kind ~= "running" and finishedNumber > 0 and nowSec() - finishedNumber > 15 then
        view = { kind = "idle" }
      else
        view = {
          kind = kind,
          target = target,
          started = tonumber(started) or nowSec(),
          finished = finishedNumber,
          exitCode = tonumber(exitCode) or 0,
          log = view.log or "",
        }
      end
    end

    local shouldRefreshLog = view.kind ~= "idle" and nowMs() - lastLogRefreshMs >= 500
    if shouldRefreshLog then
      lastLogRefreshMs = nowMs()
      noctalia.runAsync({
        "sh",
        "-c",
        "tail -n 12 \"$XDG_RUNTIME_DIR/config-switch.log\" 2>/dev/null || true",
      }, function(logResult)
        view.log = stripAnsi(logResult.stdout):gsub("%s+$", "")
        render()
      end)
    else
      render()
    end
  end)
end

function update()
  -- Advance the spinner at 10 frames per second while a switch runs.
  noctalia.setUpdateInterval(100)
  spinnerIndex = spinnerIndex % #spinnerFrames + 1
  refresh()
end

render()
