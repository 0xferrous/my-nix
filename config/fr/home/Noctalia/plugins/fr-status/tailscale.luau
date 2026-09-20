local loading = false
-- view: { kind = "loading" } | { kind = "down", message: string } | { kind = "up", account: string }
local view = { kind = "loading" }
-- Noctalia's glyph registry only knows bundled Tabler names. Render the
-- Nerd Font VPN glyph directly instead.
local vpnGlyph = "󰖂"
local vpnFont = "RecMonoCasual Nerd Font Mono"
local baseTooltip = "Loading active Tailscale account…"
-- lastUpdatedMs drives the "· Xs" age label, lastFetchMs throttles the
-- tailscale invocation so the 1s bar tick only re-renders the age.
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

local function render()
  local vertical = barWidget.isVertical()
  local container = vertical and ui.column or ui.row
  if view.kind == "loading" then
    barWidget.render(container({ gap = 6, align = "center" }, {
      ui.label({ text = vpnGlyph, fontFamily = vpnFont, fontSize = 14, color = "on_surface_variant" }),
      ui.label({ text = "…", color = "on_surface_variant" }),
    }))
  elseif view.kind == "down" then
    barWidget.render(container({ gap = 6, align = "center" }, {
      ui.label({ text = vpnGlyph, fontFamily = vpnFont, fontSize = 14, color = "error" }),
      ui.label({ text = view.message, color = "error" }),
    }))
  else
    local children = {
      ui.label({ text = vpnGlyph, fontFamily = vpnFont, fontSize = 14, color = "primary" }),
      ui.label({ text = view.account, color = "primary" }),
    }
    local age = ageSec()
    if age ~= nil then
      local ageText = vertical and (tostring(age) .. "s") or ("· " .. tostring(age) .. "s")
      table.insert(children, ui.label({ key = "age", text = ageText, color = "on_surface_variant" }))
    end
    barWidget.render(container({ gap = 6, align = "center" }, children))
  end
  local tip = baseTooltip
  if view.kind == "up" then
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

  noctalia.runAsync({ "tailscale", "switch", "--list" }, function(result)
    loading = false
    if result.exitCode ~= 0 then
      view = { kind = "down", message = "TS down" }
      baseTooltip = "Tailscale is unavailable"
      render()
      return
    end

    local account = nil
    local tailnet = nil
    local id = nil
    for line in string.gmatch(result.stdout, "[^\r\n]+") do
      if string.find(line, "%*%s*$") then
        local columns = {}
        for column in string.gmatch(line, "%S+") do table.insert(columns, column) end
        if #columns >= 3 then
          id = columns[1]
          account = string.gsub(columns[#columns], "%*$", "")
          tailnet = table.concat(columns, " ", 2, #columns - 1)
          break
        end
      end
    end

    if account == nil then
      view = { kind = "down", message = "TS down" }
      baseTooltip = "No active Tailscale account"
    else
      view = { kind = "up", account = account }
      baseTooltip = "Account: " .. account .. "\nTailnet: " .. tailnet .. "\nID: " .. id
      lastUpdatedMs = nowMs()
    end
    render()
  end)
end

function update()
  -- Tick every second so the "· Xs" age label stays live; only invoke
  -- tailscale when refresh_seconds has elapsed since the last attempt.
  noctalia.setUpdateInterval(1000)
  local seconds = math.max(10, noctalia.getConfig("refresh_seconds") or 60)
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
