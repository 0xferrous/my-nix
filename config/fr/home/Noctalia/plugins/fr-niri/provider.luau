--!nonstrict
-- Search configured Niri hotkey-overlay entries through resolved KDL binds.

local CACHE_TTL_MS = 5000
local SCRIPT = (noctalia.getenv("HOME") or "") .. "/.config/niri/keybindings.nu"
local binds = {}
local byId = {}
local lastFetchMs = 0
local loading = false
local pendingQuery = nil
local loadError = nil

local function nowMs()
  if type(noctalia.nowMs) == "function" then
    return noctalia.nowMs()
  end
  return os.time() * 1000
end

local function publish(query)
  if loading and #binds == 0 then
    launcher.setResults(query, {
      { id = "__loading", title = "Loading Niri keybindings…", glyph = "loader" },
    })
    return
  end

  if loadError ~= nil and #binds == 0 then
    launcher.setResults(query, {
      {
        id = "__error",
        title = "Couldn't load Niri keybindings",
        subtitle = loadError,
        glyph = "alert-circle",
      },
    })
    return
  end

  local needle = string.lower(query or "")
  local results = {}
  for _, bind in ipairs(binds) do
    local searchable = string.lower(table.concat({ bind.key, bind.title, bind.action }, " "))
    if needle == "" or string.find(searchable, needle, 1, true) then
      local id = bind.key .. "|" .. bind.title
      byId[id] = bind
      table.insert(results, {
        id = id,
        title = bind.title,
        subtitle = bind.key .. (bind.action ~= "" and ("  ·  " .. bind.action) or ""),
        glyph = "keyboard",
      })
    end
  end
  launcher.setResults(query, results)
end

local function refresh(query)
  local now = nowMs()
  if loading or (query ~= "" and lastFetchMs ~= 0 and now - lastFetchMs < CACHE_TTL_MS) then
    publish(query)
    return
  end

  loading = true
  publish(query)
  local started = noctalia.runAsync({ "nu", "-n", SCRIPT }, function(result)
    loading = false
    if result.exitCode ~= 0 then
      loadError = noctalia.string.trim(result.stderr or "keybinding config helper failed")
      binds = {}
      noctalia.log("niri: unable to resolve keybindings: " .. loadError)
    else
      local ok, decoded = pcall(noctalia.json.decode, result.stdout or "")
      if ok and type(decoded) == "table" then
        binds = {}
        for _, bind in ipairs(decoded) do
          -- The Niri overlay includes every explicitly titled action. Keep
          -- hidden/untitled binds out of this search provider.
          if type(bind.title) == "string" and bind.title ~= "" then
            table.insert(binds, {
              key = tostring(bind.key or "?"),
              title = bind.title,
              action = tostring(bind.action or ""),
            })
          end
        end
        loadError = nil
      else
        loadError = "invalid JSON from ~/.config/niri/keybindings.nu"
        binds = {}
        noctalia.log("niri: " .. loadError)
      end
    end
    lastFetchMs = nowMs()
    if pendingQuery ~= nil then
      publish(pendingQuery)
    end
  end, 5000)

  if not started then
    loading = false
    loadError = "could not start Nushell keybinding helper"
    lastFetchMs = nowMs()
    publish(query)
    noctalia.log("niri: " .. loadError)
  end
end

function onQuery(text)
  pendingQuery = text
  refresh(text)
end

function onActivate(id)
  if byId[id] == nil then
    return
  end
  -- Open Niri's built-in overlay for the full, grouped shortcut list.
  noctalia.runAsync({ "niri", "msg", "action", "show-hotkey-overlay" }, function(result)
    if result.exitCode ~= 0 then
      noctalia.log("niri: failed to show hotkey overlay")
    end
  end)
end
