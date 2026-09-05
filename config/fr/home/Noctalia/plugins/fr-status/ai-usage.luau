local loading = false
-- view: { kind = "loading" } | { kind = "error", message: string }
--   | { kind = "ok", sessionPct: number|nil, weeklyPct: number|nil }
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

-- Port of the DMS AiUsage usageColor(): green -> red gradient by percent.
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

    if sessionPct == nil and weeklyPct == nil then
      view = { kind = "error", message = "AI ?" }
      baseTooltip = "No Codex usage data returned"
    else
      view = { kind = "ok", sessionPct = sessionPct, weeklyPct = weeklyPct }

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
