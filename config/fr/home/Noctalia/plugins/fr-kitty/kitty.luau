--!nonstrict
-- Pure parsing and search helpers for the JSON tree returned by
-- `kitten @ ls`. This module deliberately depends on no host globals (no
-- `noctalia.*`), so it can be unit tested outside Noctalia.

local M = {}

local function trim(text)
  if type(text) ~= "string" then
    return ""
  end
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(text)
  return string.lower(text or "")
end

local function nonempty(text)
  if type(text) ~= "string" then
    return nil
  end
  local trimmed = trim(text)
  if trimmed == "" then
    return nil
  end
  return trimmed
end

-- The basename of a command path, without arguments.
local function basename(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  path = path:gsub("/+$", "")
  local name = path:match("([^/]+)$")
  return nonempty(name)
end

local function joinCmdline(cmdline)
  if type(cmdline) ~= "table" then
    return nil
  end
  local parts = {}
  for _, argument in ipairs(cmdline) do
    if type(argument) == "string" then
      table.insert(parts, argument)
    end
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, " ")
end

-- Normalizes one socket spec into the value kitty's `--to` option expects. An
-- explicit `unix:`/`tcp:`/`fd:` scheme passes through untouched; anything else is
-- treated as a Unix socket path.
function M.normalizeSocket(raw)
  local value = trim(raw)
  if value == "" then
    return nil
  end
  if value:match("^unix:") or value:match("^tcp:") or value:match("^fd:") then
    return value
  end
  return "unix:" .. value
end

-- Returns the ordered list of sockets to query.
--
-- Kitty appends `-<pid>` to a `listen_on` value (unless it contains
-- `{kitty_pid}`), and each kitty process listens on its own PID-suffixed
-- socket. So a configured socket or `KITTY_LISTEN_ON` wins outright; otherwise
-- every `$XDG_RUNTIME_DIR/kitty*` entry is a candidate. The launcher queries
-- all candidates and merges the trees.
function M.socketCandidates(configured, kittyListenOn, xdgRuntimeDir, dirEntries)
  local direct = M.normalizeSocket(configured)
  if direct ~= nil then
    return { direct }
  end
  direct = M.normalizeSocket(kittyListenOn)
  if direct ~= nil then
    return { direct }
  end

  local runtime = trim(xdgRuntimeDir)
  if runtime == "" or type(dirEntries) ~= "table" then
    return {}
  end

  local candidates = {}
  for _, name in ipairs(dirEntries) do
    if type(name) == "string" and name:match("^kitty") then
      table.insert(candidates, "unix:" .. runtime .. "/" .. name)
    end
  end
  table.sort(candidates)
  return candidates
end

-- Builds the weighted, lower-cased haystack used for a single pane. Keeping
-- this in one place means the launcher's search and the tests route through
-- the exact same matching rules.
local function buildFields(entry)
  local fields = {}
  local function add(text, weight)
    if type(text) == "string" and text ~= "" then
      table.insert(fields, { text = lower(text), weight = weight })
    end
  end

  add(entry.title, 10)
  add(entry.cwd, 6)
  add(tostring(entry.win_id), 12)
  add("#" .. tostring(entry.win_id), 12)
  add(entry.cmd, 8)
  add(entry.cmdline_text, 6)
  add(entry.tab_title, 4)
  add(entry.os_title, 3)
  add(entry.fg_cmds, 9)
  add(entry.fg_cmdlines, 7)
  add(entry.fg_cwds, 5)
  return fields
end

-- The OS window title as the compositor shows it: the active window's title,
-- not `wm_name`/`wm_class` (which are the `--name`/`--class` options, usually
-- just "kitty").
local function activeOsTitle(os_window, os_index)
  local tabs = os_window.tabs
  if type(tabs) == "table" then
    for _, tab in ipairs(tabs) do
      if type(tab) == "table" and tab.is_active == true and type(tab.windows) == "table" then
        for _, window in ipairs(tab.windows) do
          if type(window) == "table" and window.is_active == true then
            local title = nonempty(window.title)
            if title ~= nil then
              return title
            end
          end
        end
      end
    end
  end
  return nonempty(os_window.wm_name)
    or nonempty(os_window.wm_class)
    or ("OS window " .. tostring(os_index))
end

-- Flattens one `kitten @ ls` tree into records per Kitty pane. `socket` is
-- the remote-control target the tree came from, so focus actions and grouping
-- stay correct when several kitty processes are merged together.
--
-- The returned records carry both the raw-ish fields the launcher renders and
-- a private `fields` list used by `M.score`. OS windows, tabs, and panes with a
-- malformed/empty shape are skipped rather than erroring so a partial kitty
-- response still yields a usable list.
function M.parse(tree, socket)
  local entries = {}
  if type(tree) ~= "table" then
    return entries
  end

  for os_index, os_window in ipairs(tree) do
    if type(os_window) == "table" then
      local os_title = activeOsTitle(os_window, os_index)
      local os_focused = os_window.is_focused == true
      local tabs = os_window.tabs
      if type(tabs) == "table" then
        for tab_index, tab in ipairs(tabs) do
          if type(tab) == "table" then
            local tab_title = nonempty(tab.title) or ("Tab " .. tostring(tab_index))
            local tab_id = tab.id
            local tab_focused = tab.is_focused == true
            local windows = tab.windows
            if type(windows) == "table" then
              for win_index, window in ipairs(windows) do
                if type(window) == "table" and type(window.id) == "number" then
                  local fg_cmds = {}
                  local fg_cmdlines = {}
                  local fg_cwds = {}
                  local fg_processes = window.foreground_processes
                  if type(fg_processes) == "table" then
                    for _, process in ipairs(fg_processes) do
                      if type(process) == "table" then
                        local command = joinCmdline(process.cmdline)
                        if command ~= nil then
                          table.insert(fg_cmdlines, command)
                          local name = basename(command:match("^%S+"))
                          if name ~= nil then
                            table.insert(fg_cmds, name)
                          end
                        end
                        local process_cwd = nonempty(process.cwd)
                        if process_cwd ~= nil then
                          table.insert(fg_cwds, process_cwd)
                        end
                      end
                    end
                  end

                  local cmdline = window.cmdline
                  local cmd = basename(type(cmdline) == "table" and cmdline[1] or nil)
                  local title = nonempty(window.title)

                  local entry = {
                    os_id = os_window.id,
                    os_key = (socket or "") .. "#" .. tostring(os_window.id),
                    os_index = os_index,
                    os_title = os_title,
                    os_focused = os_focused,
                    socket = socket,
                    tab_id = tab_id,
                    tab_index = tab_index,
                    tab_title = tab_title,
                    tab_focused = tab_focused,
                    win_id = window.id,
                    win_index = win_index,
                    title = title,
                    display_title = title or cmd or ("pane " .. tostring(window.id)),
                    cwd = nonempty(window.cwd),
                    pid = window.pid,
                    cmd = cmd,
                    cmdline = cmdline,
                    cmdline_text = joinCmdline(cmdline),
                    fg_cmds = table.concat(fg_cmds, " "),
                    fg_cmdlines = table.concat(fg_cmdlines, " "),
                    fg_cwds = table.concat(fg_cwds, " "),
                    fg_processes = fg_processes,
                    focused = window.is_focused == true,
                    active = window.is_active == true,
                    needs_attention = window.needs_attention == true,
                    at_prompt = window.at_prompt == true,
                  }
                  entry.fields = buildFields(entry)
                  table.insert(entries, entry)
                end
              end
            end
          end
        end
      end
    end
  end

  return entries
end

local FIELD_SEP = "\31" -- ASCII unit separator

local function splitFields(line)
  local fields = {}
  local pos = 1
  while true do
    local sep = string.find(line, FIELD_SEP, pos, true)
    if sep == nil then
      table.insert(fields, string.sub(line, pos))
      return fields
    end
    table.insert(fields, string.sub(line, pos, sep - 1))
    pos = sep + 1
  end
end

local function truthy(value)
  return value == "true" or value == "1"
end

-- Parses the compact unit-separated lines emitted by `ls-filter.jq` (one pane
-- per line, 19 fields). This deliberately avoids `noctalia.json.decode` of the
-- full `kitten @ ls` payload, which is large enough to exceed the async
-- callback CPU budget. Field order matches `ls-filter.jq`.
function M.parseLines(text, socket)
  local entries = {}
  if type(text) ~= "string" then
    return entries
  end

  local osIndex = 0
  local tabIndex = 0
  local lastOsKey = nil
  local lastTabKey = nil

  for line in string.gmatch(text, "[^\n]+") do
    local f = splitFields(line)
    if #f >= 19 and f[1] ~= "" then
      local osId = f[1]
      local osKey = (socket or "") .. "#" .. osId
      if osKey ~= lastOsKey then
        osIndex = osIndex + 1
        tabIndex = 0
        lastOsKey = osKey
        lastTabKey = nil
      end
      local tabKey = osKey .. ":" .. f[4]
      if tabKey ~= lastTabKey then
        tabIndex = tabIndex + 1
        lastTabKey = tabKey
      end

      local title = f[9] ~= "" and f[9] or nil
      local cmd = f[11] ~= "" and f[11] or nil
      local entry = {
        os_id = tonumber(osId) or osId,
        os_key = osKey,
        os_index = osIndex,
        os_title = f[2] ~= "" and f[2] or nil,
        os_focused = truthy(f[3]),
        socket = socket,
        tab_id = tonumber(f[4]) or f[4],
        tab_index = tabIndex,
        tab_title = f[5] ~= "" and f[5] or ("Tab " .. tostring(tabIndex)),
        tab_focused = truthy(f[6]),
        tab_active = truthy(f[7]),
        win_id = tonumber(f[8]) or f[8],
        win_index = 1,
        title = title,
        display_title = title or cmd or ("pane " .. tostring(f[8])),
        cwd = f[10] ~= "" and f[10] or nil,
        cmd = cmd,
        cmdline_text = f[12] ~= "" and f[12] or nil,
        fg_cmds = f[13],
        fg_cmdlines = f[14],
        fg_cwds = f[15],
        focused = truthy(f[16]),
        active = truthy(f[17]),
        needs_attention = truthy(f[18]),
        at_prompt = truthy(f[19]),
      }
      entry.fields = buildFields(entry)
      table.insert(entries, entry)
    end
  end

  return entries
end

-- Reassigns global, 1-based OS window ordinals after several per-socket trees
-- are concatenated, so `os_index` stays meaningful across processes. Entries
-- from the same OS window must be contiguous (they are when appended socket by
-- socket).
function M.reindex(entries)
  local ordinal = 0
  local lastKey = nil
  for _, entry in ipairs(entries or {}) do
    if entry.os_key ~= lastKey then
      ordinal = ordinal + 1
      lastKey = entry.os_key
    end
    entry.os_index = ordinal
  end
end

-- The pane the current Kitty focus sits on, or nil.
function M.focused(entries)
  for _, entry in ipairs(entries or {}) do
    if entry.focused then
      return entry
    end
  end
  return nil
end

local function fieldScore(field, needle)
  local index = string.find(field.text, needle, 1, true)
  if index == nil then
    return nil
  end
  local score = field.weight * 100
  if field.text == needle then
    score = score + 50
  end
  if index == 1 then
    score = score + 20
  end
  -- Shorter haystacks beat longer ones at the same weight.
  score = score - (#field.text * 0.01)
  return score
end

-- Scores one lower-cased query token against a pane. Returns nil when the
-- token matches nothing, otherwise a higher-is-better number.
function M.score(entry, token)
  if token == "" then
    return 0
  end
  local best = nil
  for _, field in ipairs(entry.fields or {}) do
    local score = fieldScore(field, token)
    if score ~= nil and (best == nil or score > best) then
      best = score
    end
  end
  return best
end

-- Field aliases accepted as `field:value` in a query.
local FIELD_ALIASES = {
  os = "os",
  tab = "tab",
  pane = "pane",
  id = "pane",
  window = "pane",
  process = "process",
  proc = "process",
  cmd = "process",
  command = "process",
  cwd = "cwd",
  dir = "cwd",
  title = "title",
  socket = "socket",
}

-- Matches one text field, preferring an exact match (or exact word) over a
-- plain substring. Returns a score or nil.
local function textMatch(text, value, weight)
  if type(text) ~= "string" or text == "" or value == "" then
    return nil
  end
  local haystack = lower(text)
  local index = string.find(haystack, value, 1, true)
  if index == nil then
    return nil
  end
  local score = weight
  if haystack == value then
    score = score + 30
  else
    for word in string.gmatch(haystack, "%S+") do
      if word == value then
        score = score + 15
        break
      end
    end
  end
  if index == 1 then
    score = score + 5
  end
  return score
end

local function bestOf(fields, value, weight)
  local best = nil
  for _, field in ipairs(fields) do
    local score = textMatch(field, value, weight)
    if score ~= nil and (best == nil or score > best) then
      best = score
    end
  end
  return best
end

local function numericEqual(value, ...)
  for _, candidate in ipairs({ ... }) do
    if candidate ~= nil and tostring(candidate) == value then
      return true
    end
  end
  return false
end

-- Matches a `field:value` filter against a pane. Returns a score or nil.
local function matchFilter(entry, field, value)
  if value == "" then
    return nil
  end
  if field == "os" then
    if numericEqual(value, entry.os_index, entry.os_id) then
      return 30
    end
    return textMatch(entry.os_title, value, 20)
  elseif field == "tab" then
    if numericEqual(value, entry.tab_index, entry.tab_id) then
      return 40
    end
    return textMatch(entry.tab_title, value, 35)
  elseif field == "pane" then
    if numericEqual(value, entry.win_id) then
      return 100
    end
    return nil
  elseif field == "process" then
    return bestOf({ entry.cmd, entry.cmdline_text, entry.fg_cmds, entry.fg_cmdlines }, value, 80)
  elseif field == "cwd" then
    return bestOf({ entry.cwd, entry.fg_cwds }, value, 60)
  elseif field == "title" then
    return bestOf({ entry.title, entry.display_title }, value, 90)
  elseif field == "socket" then
    return textMatch(entry.socket, value, 20)
  end
  return nil
end

-- Parses a lower-cased query into `field:value` filters and generic terms.
-- A leading `-` negates either kind.
local function parseQuery(query)
  local filters = {}
  local generic = {}
  for raw in string.gmatch(query, "%S+") do
    local token = raw
    local negate = false
    if #token > 1 and token:sub(1, 1) == "-" then
      negate = true
      token = token:sub(2)
    end
    local field, value = token:match("^([%a_]+):(.*)$")
    if field ~= nil and FIELD_ALIASES[field] ~= nil then
      table.insert(filters, { field = FIELD_ALIASES[field], value = value, negate = negate })
    else
      table.insert(generic, { value = token, negate = negate })
    end
  end
  return filters, generic
end

-- Searches panes with space-separated, case-insensitive tokens. Every positive
-- token must match; `-token` must not. Generic tokens search every field, while
-- `field:value` filters one attribute (`process`, `os`, `tab`, `pane`/`id`,
-- `cwd`, `title`, `socket`). The pane's score is the sum of its matches; ties
-- keep the upstream `kitten @ ls` order.
function M.search(entries, query)
  local results = {}
  local normalized = lower(trim(query))

  if normalized == "" then
    for index, entry in ipairs(entries or {}) do
      table.insert(results, { entry = entry, score = 0, index = index })
    end
    return results
  end

  local filters, generic = parseQuery(normalized)

  for index, entry in ipairs(entries or {}) do
    local total = 0
    local matched = true

    for _, term in ipairs(filters) do
      local score = matchFilter(entry, term.field, term.value)
      if term.negate then
        if score ~= nil then
          matched = false
          break
        end
      elseif score == nil then
        matched = false
        break
      else
        total = total + score
      end
    end

    if matched then
      for _, term in ipairs(generic) do
        local score = M.score(entry, term.value)
        if term.negate then
          if score ~= nil then
            matched = false
            break
          end
        elseif score == nil then
          matched = false
          break
        else
          total = total + score
        end
      end
    end

    if matched then
      table.insert(results, { entry = entry, score = total, index = index })
    end
  end

  table.sort(results, function(left, right)
    if left.score ~= right.score then
      return left.score > right.score
    end
    return left.index < right.index
  end)

  return results
end

-- Breadcrumb segments for a pane: OS window, tab title, pane title.
function M.breadcrumb(entry)
  return {
    os = entry.os_title,
    tab = entry.tab_title,
    pane = entry.display_title,
  }
end

-- A one-line breadcrumb, e.g. `OS window 2 · ops — kitty › 97: work › notes.md`.
function M.breadcrumbText(entry)
  local os = "OS window " .. tostring(entry.os_index)
  if entry.os_title ~= nil and entry.os_title ~= "" and entry.os_title ~= os then
    os = os .. " · " .. entry.os_title
  end
  local tab = entry.tab_title
  if entry.tab_id ~= nil then
    tab = tostring(entry.tab_id) .. ": " .. tab
  end
  return table.concat({ os, tab, entry.display_title }, " › ")
end

return M
