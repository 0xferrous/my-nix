local function render(percent, state)
  if percent == nil then
    desktopWidget.render(ui.label({
      text = "Battery unavailable",
      fontSize = 28,
      color = "on_surface",
    }))
    return
  end

  -- UPower reports a full battery as `fully-charged` rather than
  -- `charging` while the charger remains connected.
  local pluggedIn = state == "charging"
    or state == "fully-charged"
    or state == "pending-charge"
  local status = state == "charging" and "charging"
    or pluggedIn and "plugged in"
    or "not charging"
  local glyph = pluggedIn and "battery-charging" or "battery-4"
  desktopWidget.render(ui.row({ gap = 10, align = "center" }, {
    ui.glyph({ name = glyph, size = 30, color = "on_surface" }),
    ui.label({
      text = tostring(percent) .. "% · " .. status,
      fontSize = 28,
      color = "on_surface",
    }),
  }))
end

local function refresh()
  noctalia.runAsync({
    "sh",
    "-c",
    "upower -i /org/freedesktop/UPower/devices/DisplayDevice 2>/dev/null",
  }, function(result)
    if result.exitCode ~= 0 then
      render(nil)
      return
    end

    local value = string.match(result.stdout, "percentage:%s*(%d+)%%")
    local state = string.match(result.stdout, "state:%s*(%S+)")
    render(value, state)
  end)
end

function update()
  noctalia.setUpdateInterval(30 * 1000)
  refresh()
end

refresh()
