--!nonstrict
-- Kitty pane switcher panel.
--
-- Lists every Kitty pane across OS windows and tabs, searches them, and focuses
-- the selected pane with `kitten @ focus-window`, which also switches tab and
-- OS window. Noctalia runs outside Kitty, so the remote-control socket is
-- resolved explicitly from the `socket` setting, `KITTY_LISTEN_ON`, or by
-- discovering every `$XDG_RUNTIME_DIR/kitty*` socket (kitty appends `-<pid>`),
-- instead of assuming an inherited Kitty environment. Multiple kitty
-- processes are queried and their pane trees merged.

local kitty = require("./kitty.luau")
local fetch = require("./fetch.luau")

local STATUS_LOADING = "loading"
local STATUS_READY = "ready"
local STATUS_ERROR = "error"

local entries = {}
local results = {}
local status = STATUS_LOADING
local errorMessage = nil
local errorHint = nil
local query = ""
local queryKey = 1
local selection = 1
local closeButton = true
local socketTargets = {}

-- Collapsed tree groups, keyed "os:<os_key>" or "tab:<os_key>:<tab_id>".
local collapsed = {}
-- Panes visible after filtering + collapse, in render order. `selection`
-- indexes this list; a pane row's `paneIndex` matches it.
local visiblePanes = {}
-- Set after a refresh so the focused pane starts selected.
local selectFocused = true

-- The panel renders a sliding window of rows around the selection instead of a
-- scroll container: there is no scroll-to-selected API, so keeping the window
-- centred on `selection` is what keeps the active row on screen.
local PAGE_SIZE = 7

-- Held arrow keys. The host coalesces OS key repeat into one press, so the
-- panel repeats itself from frame ticks while a chord is held.
local REPEAT_DELAY_MS = 350
local REPEAT_INTERVAL_MS = 60
local heldChord = nil
local repeatElapsed = 0
local nextRepeatMs = REPEAT_DELAY_MS

local render

local function tr(key)
  return noctalia.tr(key)
end

local function hasQuery()
  return noctalia.string.trim(query) ~= ""
end

local function recomputeResults()
  results = kitty.search(entries, query)
  if selection > #results then
    selection = #results
  end
  if selection < 1 then
    selection = 1
  end
end

-- First and last row indices to render, keeping the selected pane's row inside
-- the window (inclusive, 1-based).
local function windowBounds(rows)
  local total = #rows
  if total == 0 then
    return 0, -1
  end
  local size = math.min(PAGE_SIZE, total)
  local selectedRow = 1
  for index, row in ipairs(rows) do
    if row.kind == "pane" and row.paneIndex == selection then
      selectedRow = index
      break
    end
  end
  local start = selectedRow - math.floor(size / 2)
  if start < 1 then
    start = 1
  end
  if start > total - size + 1 then
    start = total - size + 1
  end
  return start, start + size - 1
end

local function moveSelection(delta)
  local count = #visiblePanes
  if count == 0 then
    return
  end
  local nextSelection = selection + delta
  if nextSelection < 1 then
    nextSelection = 1
  elseif nextSelection > count then
    nextSelection = count
  end
  if nextSelection ~= selection then
    selection = nextSelection
    render()
  end
end

local function setError(message, hint)
  status = STATUS_ERROR
  errorMessage = message
  errorHint = hint
  entries = {}
  results = {}
  visiblePanes = {}
  render()
end

local function refresh()
  status = STATUS_LOADING
  errorMessage = nil
  errorHint = nil
  selectFocused = true
  render()

  if not noctalia.commandExists("kitten") then
    setError(tr("errors.kitten-missing"), tr("errors.kitten-missing-hint"))
    return
  end

  fetch.fetch(function(result)
    socketTargets = result.sockets
    if #result.sockets == 0 then
      setError(tr("errors.socket-missing"), tr("errors.socket-missing-hint"))
      return
    end
    if #result.entries == 0 and #result.failed > 0 then
      setError(tr("errors.remote-failed"), table.concat(result.failed, "\n"))
      return
    end
    entries = result.entries
    status = STATUS_READY
    recomputeResults()
    render()
  end)
end

local function activate(entry)
  if entry == nil then
    return
  end
  fetch.focus(entry)
  panel.close()
end

local function header()
  local children = {
    ui.glyph({ name = "cat", size = 18, color = "primary" }),
    ui.label({
      text = tr("panel.title"),
      fontSize = 16,
      fontWeight = "bold",
      color = "on_surface",
      flexGrow = 1,
    }),
  }
  if status == STATUS_READY then
    table.insert(children, ui.label({
      text = tostring(#results) .. " / " .. tostring(#entries),
      color = "on_surface_variant",
      fontSize = 12,
    }))
  end
  table.insert(children, ui.button({
    glyph = status == STATUS_LOADING and "loader" or "refresh",
    variant = "ghost",
    enabled = status ~= STATUS_LOADING,
    tooltip = tr("panel.refresh"),
    onClick = "onRefreshClicked",
  }))
  if closeButton then
    table.insert(children, ui.button({
      glyph = "close",
      variant = "ghost",
      tooltip = tr("panel.close"),
      onClick = "onCloseClicked",
    }))
  end
  return ui.row({ align = "center", gap = 8 }, children)
end

local function selectionContext()
  local entry = visiblePanes[selection]
  if entry == nil then
    return nil
  end
  local os = "OS window " .. tostring(entry.os_index)
  if entry.os_title ~= nil and entry.os_title ~= "" then
    os = os .. " · " .. entry.os_title
  end
  local children = {
    ui.glyph({
      name = entry.focused and "circle-filled" or "app-window",
      size = 12,
      color = entry.focused and "primary" or "on_surface_variant",
    }),
    ui.label({ text = os, color = "primary", fontWeight = "bold", maxLines = 1 }),
    ui.label({ text = "›", color = "outline", fontSize = 12 }),
    ui.label({
      text = entry.tab_title or "",
      color = "on_surface_variant",
      maxLines = 1,
      flexGrow = 1,
    }),
  }
  return ui.row({
    key = "selection-context",
    align = "center",
    gap = 8,
    paddingH = 10,
    paddingV = 6,
    radius = 6,
    fill = "surface_variant/0.45",
  }, children)
end

local function searchInput()
  return ui.input({
    key = "query-" .. tostring(queryKey),
    value = query,
    placeholder = tr("panel.search"),
    focus = true,
    onChange = "onQueryChange",
  })
end

local function errorBand()
  local rows = {
    ui.row({ align = "center", gap = 8 }, {
      ui.glyph({ name = "alert-triangle", size = 16, color = "error" }),
      ui.label({ text = errorMessage or "", color = "error", flexGrow = 1 }),
      ui.button({ text = tr("panel.retry"), onClick = "onRefreshClicked" }),
    }),
  }
  if errorHint ~= nil and errorHint ~= "" then
    table.insert(rows, ui.label({
      text = errorHint,
      color = "on_surface_variant",
      fontSize = 12,
      maxLines = 4,
    }))
  end
  return ui.column({
    gap = 4,
    paddingH = 12,
    paddingV = 10,
    radius = 8,
    fill = "error_container/0.4",
  }, rows)
end

local function toggleCollapse(key)
  if collapsed[key] then
    collapsed[key] = nil
  else
    collapsed[key] = true
  end
  render()
end

local function disclosure(open)
  return ui.glyph({
    name = open and "chevron-down" or "chevron-right",
    size = 12,
    color = "on_surface_variant",
  })
end

local function osRow(group)
  local open = not collapsed["os:" .. group.key]
  local title = "OS window " .. tostring(group.entry.os_index)
  if group.entry.os_title ~= nil and group.entry.os_title ~= "" then
    title = title .. "  ·  " .. group.entry.os_title
  end
  return ui.row({
    key = "os-" .. group.key,
    gap = 8,
    align = "center",
    paddingH = 10,
    paddingV = 6,
    radius = 6,
    fill = "surface_variant/0.45",
    onClick = function()
      toggleCollapse("os:" .. group.key)
    end,
  }, {
    disclosure(open),
    ui.glyph({ name = "app-window", size = 14, color = "primary" }),
    ui.label({ text = title, fontWeight = "bold", color = "primary", flexGrow = 1, maxLines = 1 }),
    ui.label({ text = tostring(group.count), fontSize = 12, color = "on_surface_variant" }),
  })
end

local function tabRow(group, tab)
  local key = "tab:" .. group.key .. ":" .. tab.key
  local open = not collapsed[key]
  return ui.row({
    key = key,
    gap = 8,
    align = "center",
    paddingH = 10,
    paddingV = 4,
    radius = 6,
    onClick = function()
      toggleCollapse(key)
    end,
  }, {
    ui.box({ width = 22 }),
    disclosure(open),
    ui.glyph({ name = "corner-down-right", size = 12, color = "on_surface_variant" }),
    ui.label({ text = tab.entry.tab_title, color = "on_surface_variant", flexGrow = 1, maxLines = 1 }),
    ui.label({ text = tostring(tab.count), fontSize = 12, color = "on_surface_variant" }),
  })
end

local function paneRow(row, tree)
  local entry = row.entry
  local isSelected = row.paneIndex == selection
  local subtitle
  if tree then
    subtitle = entry.cwd
  else
    subtitle = kitty.breadcrumbText(entry)
    if entry.cwd ~= nil and entry.cwd ~= "" then
      subtitle = subtitle .. "  ·  " .. entry.cwd
    end
  end

  local command = entry.cmd
  if entry.fg_cmds ~= nil and entry.fg_cmds ~= "" then
    command = entry.fg_cmds
  end

  local children = {}
  if tree then
    table.insert(children, ui.box({ width = 44 }))
  end
  table.insert(children, ui.glyph({
    name = entry.focused and "circle-filled" or "circle",
    size = 12,
    color = entry.focused and "primary" or "outline",
  }))
  table.insert(children, ui.column({ gap = 2, flexGrow = 1 }, {
    ui.label({
      text = entry.display_title,
      maxLines = 1,
      fontWeight = entry.focused and "bold" or "normal",
      color = "on_surface",
    }),
    ui.label({
      text = subtitle or "",
      maxLines = 1,
      fontSize = 12,
      color = "on_surface_variant",
    }),
  }))
  table.insert(children, ui.column({ gap = 2 }, {
    ui.label({ text = command or "", maxLines = 1, fontSize = 12, color = "on_surface_variant" }),
    ui.label({
      text = "#" .. tostring(entry.win_id),
      fontSize = 12,
      color = entry.focused and "primary" or "on_surface_variant",
    }),
  }))

  return ui.row({
    key = "pane-" .. tostring(entry.socket) .. "-" .. tostring(entry.win_id),
    gap = 10,
    align = "center",
    paddingH = 10,
    paddingV = 6,
    radius = 6,
    -- Always set fill: the reconciler only applies a fill when the prop is
    -- present, so passing nil would leave a retained row highlighted forever.
    fill = isSelected and "primary/0.18" or "surface/0",
    onClick = function()
      activate(entry)
    end,
  }, children)
end

-- Groups the current results into OS windows then tabs, preserving order.
local function buildGroups()
  local groups = {}
  local byOs = {}
  for _, result in ipairs(results) do
    local entry = result.entry
    local group = byOs[entry.os_key]
    if group == nil then
      group = { key = entry.os_key, entry = entry, count = 0, tabs = {}, byTab = {} }
      byOs[entry.os_key] = group
      table.insert(groups, group)
    end
    group.count = group.count + 1
    local tabKey = tostring(entry.tab_id)
    local tab = group.byTab[tabKey]
    if tab == nil then
      tab = { key = tabKey, entry = entry, count = 0, entries = {} }
      group.byTab[tabKey] = tab
      table.insert(group.tabs, tab)
    end
    tab.count = tab.count + 1
    table.insert(tab.entries, entry)
  end
  return groups
end

-- Flattens the current results into render rows. With no query this is the
-- collapsible OS window → tab → pane tree; with a query it is the flat ranked
-- result list. Rebuilds `visiblePanes`, which `selection` indexes.
local function buildRows()
  local rows = {}
  visiblePanes = {}
  if hasQuery() then
    for index, result in ipairs(results) do
      table.insert(visiblePanes, result.entry)
      table.insert(rows, { kind = "pane", entry = result.entry, paneIndex = index })
    end
    return rows
  end

  local paneIndex = 0
  for _, group in ipairs(buildGroups()) do
    table.insert(rows, { kind = "os", group = group })
    if not collapsed["os:" .. group.key] then
      for _, tab in ipairs(group.tabs) do
        table.insert(rows, { kind = "tab", group = group, tab = tab })
        if not collapsed["tab:" .. group.key .. ":" .. tab.key] then
          for _, entry in ipairs(tab.entries) do
            paneIndex = paneIndex + 1
            table.insert(visiblePanes, entry)
            table.insert(rows, { kind = "pane", entry = entry, paneIndex = paneIndex })
          end
        end
      end
    end
  end
  return rows
end

-- Renders only the sliding window of rows, so the selected pane is always on
-- screen without a scroll-to-selected API.
local function listChildren(rows, start, finish, tree)
  local children = {}
  for index = start, finish do
    local row = rows[index]
    if row == nil then
      break
    end
    if row.kind == "os" then
      table.insert(children, osRow(row.group))
    elseif row.kind == "tab" then
      table.insert(children, tabRow(row.group, row.tab))
    else
      table.insert(children, paneRow(row, tree))
    end
  end
  return children
end

local function body(rows)
  if status == STATUS_ERROR then
    return errorBand()
  end
  if status == STATUS_LOADING and #entries == 0 then
    return ui.column({ align = "center", gap = 8, paddingV = 24 }, {
      ui.label({ text = tr("panel.loading"), color = "on_surface_variant" }),
    })
  end
  if rows == nil or #rows == 0 then
    return ui.column({ align = "center", gap = 8, paddingV = 24 }, {
      ui.glyph({ name = "mood-empty", size = 24, color = "on_surface_variant" }),
      ui.label({
        text = #entries == 0 and tr("panel.no-panes") or tr("panel.empty"),
        color = "on_surface_variant",
      }),
    })
  end
  local start, finish = windowBounds(rows)
  return ui.scroll({ flexGrow = 1, gap = 2 }, listChildren(rows, start, finish, not hasQuery()))
end

local function footer()
  local children = {
    ui.label({
      text = tr("panel.hint"),
      color = "on_surface_variant",
      fontSize = 12,
      flexGrow = 1,
    }),
  }
  if #socketTargets > 0 then
    table.insert(children, ui.label({
      text = table.concat(socketTargets, "  "),
      color = "on_surface_variant",
      fontSize = 12,
      maxLines = 1,
    }))
  end
  return ui.row({ align = "center", gap = 8 }, children)
end

render = function()
  local rows = nil
  if status == STATUS_READY then
    rows = buildRows()
    if #visiblePanes > 0 then
      if selection > #visiblePanes then
        selection = #visiblePanes
      end
      if selection < 1 then
        selection = 1
      end
      if selectFocused then
        for index, entry in ipairs(visiblePanes) do
          if entry.focused then
            selection = index
            break
          end
        end
      end
    end
    selectFocused = false
  end

  local content = {
    header(),
    searchInput(),
  }
  local context = selectionContext()
  if context ~= nil then
    table.insert(content, context)
  end
  table.insert(content, body(rows))
  table.insert(content, footer())
  panel.render(ui.column({ flexGrow = 1, gap = 10 }, content))
end

function onOpen(_context)
  query = ""
  queryKey = queryKey + 1
  selection = 1
  heldChord = nil
  refresh()
end

function onClose()
  heldChord = nil
  panel.setNeedsFrameTick(false)
end

function onRefreshClicked()
  refresh()
end

function onCloseClicked()
  panel.close()
end

function onQueryChange(value)
  query = type(value) == "string" and value or ""
  recomputeResults()
  selection = 1
  render()
end

local function startRepeat(chord)
  heldChord = chord
  repeatElapsed = 0
  nextRepeatMs = REPEAT_DELAY_MS
  panel.setNeedsFrameTick(true)
end

local function stopRepeat(chord)
  if heldChord == chord then
    heldChord = nil
    panel.setNeedsFrameTick(false)
  end
end

function onKey(chord, pressed)
  if chord == "up" or chord == "down" then
    if pressed then
      moveSelection(chord == "down" and 1 or -1)
      startRepeat(chord)
    else
      stopRepeat(chord)
    end
    return
  end
  if not pressed then
    return
  end
  if chord == "enter" then
    local entry = visiblePanes[selection]
    if entry ~= nil then
      activate(entry)
    end
  elseif chord == "ctrl+r" then
    refresh()
  end
end

-- The host coalesces one physical key press into one `onKey` press, so a held
-- arrow key repeats here instead of from OS key repeat.
function onFrameTick(deltaMs)
  if heldChord == nil then
    return
  end
  repeatElapsed = repeatElapsed + (tonumber(deltaMs) or 0)
  while repeatElapsed >= nextRepeatMs do
    moveSelection(heldChord == "down" and 1 or -1)
    nextRepeatMs = nextRepeatMs + REPEAT_INTERVAL_MS
  end
end

function onIpc(event, _payload)
  if event == "refresh" then
    refresh()
  end
end
