local loading = false
-- Render model: { kind = "loading" } | { kind = "error", message: string }
--   | { kind = "ok", coins: [{ name, price, change: number|nil, showChange: bool }] }
local view = { kind = "loading" }
local baseTooltip = "Loading cryptocurrency prices…"
-- Millisecond timestamps: lastUpdatedMs tracks the last successful fetch
-- (drives the "· Xs" age label), lastFetchMs throttles fetch attempts so the
-- 1s bar tick only re-renders the age without hammering the API.
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
      ui.glyph({ name = "currency-bitcoin", size = 14 }),
      ui.label({ text = "Crypto …" }),
    }))
  elseif view.kind == "error" then
    barWidget.render(container({ gap = 6, align = "center" }, {
      ui.glyph({ name = "currency-bitcoin", size = 14 }),
      ui.label({ text = view.message, color = "error" }),
    }))
  else
    local children = {
      ui.glyph({ name = "currency-bitcoin", size = 14 }),
    }
    for _, coin in ipairs(view.coins) do
      local changeColor = "on_surface_variant"
      if coin.change ~= nil and coin.change ~= 0 then
        changeColor = coin.change > 0 and "primary" or "error"
      end
      local parts = {
        ui.label({ key = coin.name .. "-name", text = coin.name .. ":", color = "on_surface_variant" }),
        ui.label({ key = coin.name .. "-price", text = coin.price, color = "on_surface" }),
      }
      if coin.showChange and coin.changeText ~= nil then
        table.insert(parts, ui.label({ key = coin.name .. "-change", text = coin.changeText, color = changeColor }))
      end
      table.insert(children, ui.row({ key = coin.name, gap = 4, align = "center" }, parts))
    end
    local age = ageSec()
    if age ~= nil then
      local ageText = vertical and (tostring(age) .. "s") or ("· " .. tostring(age) .. "s")
      table.insert(children, ui.label({ key = "age", text = ageText, color = "on_surface_variant" }))
    end
    barWidget.render(container({ gap = 8, align = "center" }, children))
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

local function displayName(symbol)
  return string.gsub(symbol, "USDT$", "")
end

local function formatPrice(value)
  if value >= 1000 then return string.format("%.0f", value) end
  if value >= 1 then return string.format("%.2f", value) end
  return string.format("%.4f", value)
end

local function formatChange(changePercent)
  return string.format("%+.2f%%", changePercent)
end

local function refresh()
  if loading then return end

  local symbols = noctalia.getConfig("symbols") or { "ETHUSDT", "BTCUSDT", "SOLUSDT" }
  local wanted = {}
  for _, symbol in ipairs(symbols) do
    table.insert(wanted, string.upper(symbol))
  end
  if #wanted == 0 then
    view = { kind = "error", message = "No symbols" }
    baseTooltip = "No symbols configured"
    render()
    return
  end

  -- Fetch only the configured symbols. The unfiltered /ticker/24hr endpoint
  -- returns ~2MB (all symbols) which truncates runAsync/http captures and
  -- breaks JSON parsing; the filtered request is ~2KB.
  local parts = {}
  for _, symbol in ipairs(wanted) do
    table.insert(parts, '"' .. symbol .. '"')
  end
  local url = "https://api.binance.com/api/v3/ticker/24hr?symbols="
    .. noctalia.string.urlEncode("[" .. table.concat(parts, ",") .. "]")

  loading = true
  local accepted = noctalia.http({ url = url }, function(response)
    loading = false
    if not response.ok then
      view = { kind = "error", message = "Fetch failed" }
      baseTooltip = "Crypto request failed (status " .. tostring(response.status) .. ")"
      noctalia.log("crypto: http failed status=" .. tostring(response.status))
      render()
      return
    end

    local payload, err = noctalia.json.decode(response.body)
    if type(payload) ~= "table" then
      view = { kind = "error", message = "Parse failed" }
      baseTooltip = "Could not parse Binance response" .. (err and (": " .. err) or "")
      noctalia.log("crypto: json decode failed: " .. tostring(err))
      render()
      return
    end

    local bySymbol = {}
    for _, item in ipairs(payload) do
      if type(item) == "table" and item.symbol then
        bySymbol[item.symbol] = item
      end
    end

    local showPercentages = noctalia.getConfig("show_percentages") ~= false
    local coins = {}
    local details = {}
    for _, symbol in ipairs(wanted) do
      local item = bySymbol[symbol]
      if item then
        local price = tonumber(item.lastPrice)
        local change = tonumber(item.priceChangePercent)
        if price ~= nil then
          table.insert(coins, {
            name = displayName(symbol),
            price = formatPrice(price),
            change = change,
            showChange = showPercentages,
            changeText = (showPercentages and change ~= nil) and formatChange(change) or nil,
          })
          table.insert(details, symbol .. ": " .. formatPrice(price) .. (change and string.format(" (%+.2f%%)", change) or ""))
        end
      end
    end

    if #coins == 0 then
      view = { kind = "error", message = "No data" }
      baseTooltip = "No configured symbols returned"
    else
      view = { kind = "ok", coins = coins }
      baseTooltip = table.concat(details, "\n")
      lastUpdatedMs = nowMs()
    end
    render()
  end)

  if not accepted then
    loading = false
    view = { kind = "error", message = "Fetch failed" }
    baseTooltip = "Crypto request not started (offline mode?)"
    render()
  end
end

function update()
  -- Tick every second so the "· Xs" age label stays live; only fetch when
  -- refresh_seconds has elapsed since the last attempt.
  noctalia.setUpdateInterval(1000)
  local seconds = math.max(5, noctalia.getConfig("refresh_seconds") or 5)
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
