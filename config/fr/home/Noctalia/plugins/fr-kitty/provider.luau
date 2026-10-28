--!nonstrict
-- Launcher provider: search Kitty panes from Noctalia's built-in launcher
-- (type `/kitty`, or match globally). Reuses the shared parse/search and
-- fetch helpers.

local kitty = require("./kitty.luau")
local fetch = require("./fetch.luau")

local FETCH_TTL_MS = 5000

local entries = {}
local byId = {}
local lastFetchMs = 0
local loading = false
local pendingQuery = nil

local function nowMs()
  if type(noctalia.nowMs) == "function" then
    return noctalia.nowMs()
  end
  return os.time() * 1000
end

local function resultId(entry)
  return tostring(entry.socket) .. "|" .. tostring(entry.win_id)
end

local function publish(query)
  if #entries == 0 and loading then
    launcher.setResults(query, {
      { id = "__loading", title = noctalia.tr("launcher.loading"), glyph = "loader" },
    })
    return
  end

  -- Keep resolved ids across publishes so activation cannot miss a result
  -- whose publishing query was superseded before the launcher dispatched it.
  local results = {}
  for _, match in ipairs(kitty.search(entries, query)) do
    local entry = match.entry
    local id = resultId(entry)
    byId[id] = entry

    local subtitle = kitty.breadcrumbText(entry)
    if entry.cwd ~= nil and entry.cwd ~= "" then
      subtitle = subtitle .. "  ·  " .. entry.cwd
    end

    table.insert(results, {
      id = id,
      title = entry.display_title,
      subtitle = subtitle,
      glyph = "terminal-2",
      score = match.score,
    })
  end
  launcher.setResults(query, results)
end

local function refreshIfStale(query)
  local now = nowMs()
  -- An empty query means the launcher just opened `/kitty`, so refresh even
  -- inside the TTL; typed queries reuse the cache.
  local opened = query == ""
  if loading or (not opened and lastFetchMs ~= 0 and (now - lastFetchMs) < FETCH_TTL_MS) then
    publish(query)
    return
  end

  loading = true
  publish(query)
  fetch.fetch(function(result)
    loading = false
    if #result.entries > 0 or #result.failed == 0 then
      entries = result.entries
    end
    if #result.sockets == 0 then
      noctalia.log("kitty: no remote-control socket found")
    elseif #result.entries == 0 and #result.failed > 0 then
      noctalia.log("kitty: no panes from " .. table.concat(result.failed, "; "))
    end
    lastFetchMs = nowMs()
    if pendingQuery ~= nil then
      publish(pendingQuery)
    end
  end)
end

function onQuery(text)
  pendingQuery = text
  refreshIfStale(text)
end

function onActivate(id)
  local entry = byId[id]
  if entry == nil then
    noctalia.log("kitty: activation missed for result '" .. tostring(id) .. "'")
    return
  end
  fetch.focus(entry)
end
