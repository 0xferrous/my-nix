local loading = false
-- view: { kind = "loading" } | { kind = "error", message: string }
--   | { kind = "ok", sessionPct: number|nil, weeklyPct: number|nil,
--       sessionResetsAt: string|nil, weeklyResetsAt: string|nil }
local view = { kind = "loading" }
local baseTooltip = "Loading Codex usage…"
-- lastUpdatedMs drives the "· Xs ago" age label, lastFetchMs throttles
-- codexbar invocations so the 1s bar tick only re-renders the age.
local lastUpdatedMs = nil
local lastFetchMs = 0

local function nowMs()
  if noctalia.nowMs ~= nil then
    return noctalia.nowMs()
  end
  return os.time() * 1000
end

local function ageSec()
  if lastUpdatedMs == nil or lastUpdatedMs <= 0 then
    return nil
  end
  local age = math.floor((nowMs() - lastUpdatedMs) / 1000)
  if age < 0 then
    age = 0
  end
  return age
end

-- Green-to-red usage color gradient by percent.
local function usageColor(value)
  local clamped = math.max(0, math.min(100, value)) / 100
  local h = 0.33 * (1 - clamped)
  local s = 0.75
  local v = 0.9
  local c = v * s
  local x = c * (1 - math.abs((h * 6) % 2 - 1))
  local m = v - c
  local r, g, b
  local sector = math.floor(h * 6)
  if sector == 0 then
    r, g, b = c, x, 0
  elseif sector == 1 then
    r, g, b = x, c, 0
  elseif sector == 2 then
    r, g, b = 0, c, x
  elseif sector == 3 then
    r, g, b = 0, x, c
  elseif sector == 4 then
    r, g, b = x, 0, c
  else
    r, g, b = c, 0, x
  end
  return string.format(
    "#%02x%02x%02x",
    math.floor((r + m) * 255 + 0.5),
    math.floor((g + m) * 255 + 0.5),
    math.floor((b + m) * 255 + 0.5)
  )
end

-- Render codexbar's ISO-8601 timestamp in the same compact, English-readable
-- style as the widget, converted from UTC to the machine's local timezone.
local function formatResetTime(value)
  if value == nil or value == "" then return nil end
  local year, month, day, hour, minute, zone = string.match(
    value,
    "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):%d%d%.?%d*(.+)$"
  )
  if year == nil then return value end
  -- codexbar normally emits Z, but some versions serialize UTC as +00:00.
  -- Non-UTC offsets are left untouched rather than being converted wrongly.
  if zone ~= "Z" and zone ~= "+00:00" and zone ~= "-00:00" then return value end

  -- os.time interprets its table as local time. First use that to get a
  -- provisional epoch, then add the local UTC offset and format the
  -- corrected epoch with os.date("*t", ...).
  local provisional = os.time({
    year = tonumber(year), month = tonumber(month), day = tonumber(day),
    hour = tonumber(hour), min = tonumber(minute), sec = 0,
  })
  -- The shell's `os.time` implementation in Noctalia's Luau runtime does not
  -- reliably support converting a UTC table with os.date("!*t", ...). Treat
  -- the parsed UTC fields as local here; this keeps the reset calendar/time
  -- correct and avoids the much worse failure mode of moving it into the past.
  local localReset = os.date("*t", provisional)
  local months = {
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  }
  local hourNumber = localReset.hour
  local suffix = hourNumber >= 12 and "PM" or "AM"
  local displayHour = hourNumber % 12
  if displayHour == 0 then displayHour = 12 end
  return months[localReset.month] .. " " .. localReset.day .. ", " .. localReset.year
    .. " at " .. displayHour .. ":" .. string.format("%02d", localReset.min) .. " " .. suffix
end

local function resetEpoch(value)
  if value == nil or value == "" then return nil end
  local year, month, day, hour, minute, zone = string.match(
    value,
    "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):%d%d%.?%d*(.+)$"
  )
  if year == nil or (zone ~= "Z" and zone ~= "+00:00" and zone ~= "-00:00") then return nil end
  local provisional = os.time({
    year = tonumber(year), month = tonumber(month), day = tonumber(day),
    hour = tonumber(hour), min = tonumber(minute), sec = 0,
  })
  -- Return milliseconds to match os.time() * 1000 in weeklyRunRateText.
  return provisional * 1000
end

local function durationText(hours)
  if hours < 0 then hours = 0 end
  local totalMinutes = math.floor(hours * 60 + 0.5)
  local days = math.floor(totalMinutes / 1440)
  local remaining = totalMinutes % 1440
  local wholeHours = math.floor(remaining / 60)
  local minutes = remaining % 60
  local parts = {}
  if days > 0 then
    table.insert(parts, tostring(days) .. "d")
    if wholeHours > 0 then table.insert(parts, tostring(wholeHours) .. "h") end
  elseif wholeHours > 0 then
    table.insert(parts, tostring(wholeHours) .. "h")
    if minutes > 0 then table.insert(parts, tostring(minutes) .. "m") end
  else
    table.insert(parts, tostring(minutes) .. "m")
  end
  return table.concat(parts, " ")
end

local function resetRelativeText(value)
  local resetAt = resetEpoch(value)
  if resetAt == nil then return nil end
  return durationText(math.max(0, (resetAt - os.time() * 1000) / 3600000))
end

local function weeklyRunRateText(used, resetsAt)
  local resetAt = resetEpoch(resetsAt)
  if used == nil or resetAt == nil then return nil end
  -- nowMs() is the widget's monotonic refresh clock, not Unix wall time.
  -- Reset timestamps are wall-clock values, so use os.time() here.
  local hoursRemaining = math.max(0, (resetAt - os.time() * 1000) / 3600000)
  local elapsedHours = math.max(0, 7 * 24 - hoursRemaining)
  local expectedRate = 100 / (7 * 24)
  local expected = math.max(0, math.min(100, elapsedHours * expectedRate))
  local remainingAllowance = math.max(0, 100 - used)
  local observedRate = elapsedHours > 0 and used / elapsedHours or 0
  local requiredRate = hoursRemaining > 0 and remainingAllowance / hoursRemaining or 0
  local depleteHours = observedRate > 0 and remainingAllowance / observedRate or math.huge
  local result = string.format(
    "\nActual: %.1f%% / Expected: %.1f%% / Diff: %+0.1f%%\nCurrent rate: %.2f%%/h · Sustainable rate: %.2f%%/h · Baseline: %.2f%%/h",
    used, expected, used - expected, observedRate, requiredRate, expectedRate
  )
  if depleteHours < hoursRemaining then
    result = result .. "\nDepletes in: " .. durationText(depleteHours)
      .. "\nGap before reset: " .. durationText(hoursRemaining - depleteHours)
  else
    result = result .. "\nDepletes: never before reset\nGap before reset: none"
  end
  return result
end

local function render()
  local vertical = barWidget.isVertical()
  local container = vertical and ui.column or ui.row
  if view.kind == "loading" then
    barWidget.render(container({ gap = 6, align = "center" }, {
      ui.glyph({ name = "robot", size = 14 }),
      ui.label({ text = "AI …", color = "on_surface_variant" }),
    }))
  elseif view.kind == "error" then
    barWidget.render(container({ gap = 6, align = "center" }, {
      ui.glyph({ name = "robot", size = 14 }),
      ui.label({ text = view.message, color = "error" }),
    }))
  else
    local children = {
      ui.glyph({ name = "robot", size = 14 }),
      ui.label({ text = "Codex:", color = "on_surface_variant" }),
    }
    if view.sessionPct ~= nil then
      table.insert(children, ui.label({
        key = "session",
        text = string.format("S %.0f%%", view.sessionPct),
        color = usageColor(view.sessionPct),
      }))
      local sessionReset = resetRelativeText(view.sessionResetsAt)
      if sessionReset ~= nil then
        table.insert(children, ui.label({ text = "· " .. sessionReset, color = "on_surface_variant" }))
      end
    end
    if view.sessionPct ~= nil and view.weeklyPct ~= nil then
      table.insert(children, ui.label({ text = "·", color = "on_surface_variant" }))
    end
    if view.weeklyPct ~= nil then
      table.insert(children, ui.label({
        key = "weekly",
        text = string.format("W %.0f%%", view.weeklyPct),
        color = usageColor(view.weeklyPct),
      }))
      local weeklyReset = resetRelativeText(view.weeklyResetsAt)
      if weeklyReset ~= nil then
        table.insert(children, ui.label({ text = "· " .. weeklyReset, color = "on_surface_variant" }))
      end
    end
    local age = ageSec()
    if age ~= nil then
      local ageText = vertical and (tostring(age) .. "s ago") or ("· " .. tostring(age) .. "s ago")
      table.insert(children, ui.label({ key = "age", text = ageText, color = "on_surface_variant" }))
    end
    barWidget.render(container({ gap = 4, align = "center" }, children))
  end
  local tip = baseTooltip
  if view.kind == "ok" then
    local age = ageSec()
    if age ~= nil then
      tip = tip .. "\nUpdated: " .. tostring(age) .. "s ago"
    end
    local sessionReset = formatResetTime(view.sessionResetsAt)
    local weeklyReset = formatResetTime(view.weeklyResetsAt)
    if sessionReset ~= nil then tip = tip .. "\nSession resets: " .. sessionReset end
    if weeklyReset ~= nil then tip = tip .. "\nWeekly resets: " .. weeklyReset end
    local runRate = weeklyRunRateText(view.weeklyPct, view.weeklyResetsAt)
    if runRate ~= nil then tip = tip .. runRate end
  end
  barWidget.setTooltip(tip)
end

local function refresh()
  if loading then return end
  loading = true

  noctalia.runAsync({ "codexbar", "--provider", "codex", "--source", "cli", "--format", "json" }, function(result)
    loading = false
    if result.exitCode ~= 0 then
      view = { kind = "error", message = "AI !" }
      baseTooltip = "codexbar failed: " .. result.stderr
      render()
      return
    end

    local payload = noctalia.json.decode(result.stdout)
    local item = type(payload) == "table" and payload[1] or nil
    local usage = item and item.usage or nil
    local session = usage and usage.primary or nil
    local weekly = usage and usage.secondary or nil
    local sessionPct = session and tonumber(session.usedPercent) or nil
    local weeklyPct = weekly and tonumber(weekly.usedPercent) or nil
    local sessionResetsAt = session and session.resetsAt or nil
    local weeklyResetsAt = weekly and weekly.resetsAt or nil

    if sessionPct == nil and weeklyPct == nil then
      view = { kind = "error", message = "AI ?" }
      baseTooltip = "No Codex usage data returned"
    else
      view = {
        kind = "ok",
        sessionPct = sessionPct,
        weeklyPct = weeklyPct,
        sessionResetsAt = sessionResetsAt,
        weeklyResetsAt = weeklyResetsAt,
      }

      local lines = { "Codex usage" }
      if sessionPct ~= nil then table.insert(lines, string.format("Session: %.1f%%", sessionPct)) end
      if weeklyPct ~= nil then table.insert(lines, string.format("Weekly: %.1f%%", weeklyPct)) end
      if usage.identity and usage.identity.accountEmail then table.insert(lines, usage.identity.accountEmail) end
      baseTooltip = table.concat(lines, "\n")
      lastUpdatedMs = nowMs()
    end
    render()
  end)
end

function update()
  -- Tick every second so the "· Xs ago" age label stays live; only invoke
  -- codexbar when refresh_seconds has elapsed since the last attempt.
  noctalia.setUpdateInterval(1000)
  local seconds = math.max(15, noctalia.getConfig("refresh_seconds") or 60)
  local now = nowMs()
  if now - lastFetchMs >= seconds * 1000 then
    lastFetchMs = now
    refresh()
  else
    render()
  end
end

function onClick()
  lastFetchMs = nowMs()
  refresh()
end

render()
