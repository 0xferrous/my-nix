--!nonstrict
-- Parser/search tests for the fr/kitty plugin.
--
-- Run from the plugin directory with:
--   luau tests/kitty_spec.luau -a "$(cat tests/fixture-ls.json)" "$(jq -r -f ls-filter.jq tests/fixture-ls.json)"
-- or use tests/run-tests.sh, which finds luau + jq (falling back to nix).
--
-- The same Kitty snapshot is exercised through both parsers: `parse` (the raw
-- `kitten @ ls` JSON tree) and `parseLines` (the compact output of
-- `ls-filter.jq`, which production uses to stay inside the async CPU budget).

local kitty = require("../kitty")
local json = require("./json")

local rawJson, rawTsv = ...
if rawJson == nil or rawJson == "" then
  error("pass the fixture JSON as the first program argument (-a)")
end
if rawTsv == nil or rawTsv == "" then
  error("pass the ls-filter output as the second program argument (-a)")
end

local failures = 0
local checks = 0

local function check(name, condition)
  checks = checks + 1
  if condition then
    print("ok - " .. name)
  else
    failures = failures + 1
    print("not ok - " .. name)
  end
end

local function suite(label, entries)
  local function search(query)
    return kitty.search(entries, query)
  end

  local function firstId(results)
    if results[1] == nil then
      return nil
    end
    return results[1].entry.win_id
  end

  local function containsId(results, id)
    for _, result in ipairs(results) do
      if result.entry.win_id == id then
        return true
      end
    end
    return false
  end

  local function osWindowCount()
    local seen = {}
    local count = 0
    for _, entry in ipairs(entries) do
      if not seen[entry.os_key] then
        seen[entry.os_key] = true
        count = count + 1
      end
    end
    return count
  end

  check(label .. ": fixture has 9 panes", #entries == 9)
  check(label .. ": fixture has 3 OS windows", osWindowCount() == 3)

  local focused = kitty.focused(entries)
  check(label .. ": exactly one pane is focused", (function()
    local count = 0
    for _, entry in ipairs(entries) do
      if entry.focused then
        count = count + 1
      end
    end
    return count == 1
  end)())
  check(label .. ": focused pane is 220", focused ~= nil and focused.win_id == 220)
  check(label .. ": focused pane is in OS window 2", focused ~= nil and focused.os_index == 2)
  check(label .. ": focused pane is in tab 97", focused ~= nil and focused.tab_id == 97)
  check(label .. ": focused pane cwd is parsed", focused ~= nil and focused.cwd == "/home/dmnt/dev/fr/my-nix")
  check(label .. ": foreground command is parsed", focused ~= nil and focused.fg_cmds == "nvim")
  check(label .. ": command falls back to cmdline", focused ~= nil and focused.cmd == "nu")
  check(label .. ": needs_attention is parsed", (function()
    for _, entry in ipairs(entries) do
      if entry.win_id == 222 then
        return entry.needs_attention == true
      end
    end
    return false
  end)())

  check(label .. ": breadcrumb names OS window, tab, and pane", focused ~= nil
    and kitty.breadcrumbText(focused):find("OS window 2", 1, true) ~= nil
    and kitty.breadcrumbText(focused):find("work", 1, true) ~= nil
    and kitty.breadcrumbText(focused):find("notes.md", 1, true) ~= nil)

  check(label .. ": empty query returns every pane in tree order", (function()
    local results = search("")
    return #results == 9 and firstId(results) == 1
  end)())

  check(label .. ": pane ID search ranks the pane first", firstId(search("220")) == 220)
  check(label .. ": hash-prefixed pane ID search works", firstId(search("#221")) == 221)
  check(label .. ": process name search finds the ssh pane", firstId(search("ssh")) == 221)
  check(label .. ": command search finds cargo", firstId(search("cargo")) == 3)
  check(label .. ": title/tab search finds logs", firstId(search("logs")) == 222)
  check(label .. ": CWD search finds the project panes", (function()
    local results = search("project")
    return #results == 3 and containsId(results, 1) and containsId(results, 2) and containsId(results, 3)
  end)())
  check(label .. ": search is case-insensitive", (function()
    local lowerResults = search("nvim")
    local upperResults = search("NVIM")
    return #lowerResults == #upperResults and firstId(lowerResults) == firstId(upperResults)
  end)())
  check(label .. ": multiple tokens must all match", (function()
    local results = search("nvim notes")
    return #results == 1 and firstId(results) == 220
  end)())
  check(label .. ": unmatched query returns nothing", #search("zzz-nope") == 0)
  check(label .. ": foreground CWD is searchable", containsId(search("Videos"), 300))

  -- Attribute filters ----------------------------------------------------

  check(label .. ": process filter finds the pi pane", (function()
    local results = search("process:pi")
    return #results == 1 and firstId(results) == 302
  end)())
  check(label .. ": cmd aliases process", firstId(search("cmd:pi")) == 302)
  check(label .. ": os filter matches the displayed ordinal", (function()
    local results = search("os:2")
    return #results == 3 and containsId(results, 220) and containsId(results, 221) and containsId(results, 222)
  end)())
  check(label .. ": tab filter matches the tab id", (function()
    local results = search("tab:97")
    return #results == 2 and containsId(results, 220) and containsId(results, 221)
  end)())
  check(label .. ": pane filter matches the pane id", (function()
    local results = search("pane:302")
    return #results == 1 and firstId(results) == 302
  end)())
  check(label .. ": id aliases pane", firstId(search("id:220")) == 220)
  check(label .. ": cwd filter", (function()
    local results = search("cwd:project")
    return #results == 3 and containsId(results, 1) and containsId(results, 2) and containsId(results, 3)
  end)())
  check(label .. ": title filter", firstId(search("title:notes")) == 220)
  check(label .. ": filters combine with generic tokens", (function()
    local results = search("os:2 nvim")
    return #results == 1 and firstId(results) == 220
  end)())
  check(label .. ": negation excludes matches", (function()
    local results = search("-process:pi")
    return #results == 8 and not containsId(results, 302)
  end)())
  check(label .. ": unknown field falls back to plain text", #search("nope:pi") == 0)
end

suite("json", kitty.parse(json.decode(rawJson)))
suite("lines", kitty.parseLines(rawTsv))

-- Socket resolution and tagging -----------------------------------------

check("json parse tags entries with their socket", (function()
  local tagged = kitty.parse(json.decode(rawJson), "unix:/tmp/kitty-1")
  return tagged[1].socket == "unix:/tmp/kitty-1" and tagged[1].os_key == "unix:/tmp/kitty-1#1"
end)())
check("line parse tags entries with their socket", (function()
  local tagged = kitty.parseLines(rawTsv, "unix:/tmp/kitty-2")
  return tagged[1].socket == "unix:/tmp/kitty-2" and tagged[1].os_key == "unix:/tmp/kitty-2#1"
end)())

check("explicit path gains the unix scheme", kitty.normalizeSocket("/tmp/kitty") == "unix:/tmp/kitty")
check("explicit unix target is preserved", kitty.normalizeSocket("unix:/run/user/1000/kitty-1") == "unix:/run/user/1000/kitty-1")
check("tcp targets are preserved", kitty.normalizeSocket("tcp:localhost:1234") == "tcp:localhost:1234")
check("empty socket normalizes to nil", kitty.normalizeSocket("") == nil)

check("explicit setting wins", (function()
  local candidates = kitty.socketCandidates("/tmp/explicit", "unix:/tmp/env", "/run/user/1000", { "kitty-1" })
  return #candidates == 1 and candidates[1] == "unix:/tmp/explicit"
end)())
check("KITTY_LISTEN_ON is honored", (function()
  local candidates = kitty.socketCandidates("", "unix:/tmp/env", "/run/user/1000", { "kitty-1" })
  return #candidates == 1 and candidates[1] == "unix:/tmp/env"
end)())
check("runtime dir is scanned for kitty sockets", (function()
  local candidates = kitty.socketCandidates("", "", "/run/user/1000", { "kitty-222", "bus", "kitty-111", "wayland-0" })
  return #candidates == 2
    and candidates[1] == "unix:/run/user/1000/kitty-111"
    and candidates[2] == "unix:/run/user/1000/kitty-222"
end)())
check("no kitty sockets yields an empty list", #kitty.socketCandidates("", "", "/run/user/1000", { "bus" }) == 0)
check("missing runtime dir yields an empty list", #kitty.socketCandidates("", "", "", { "kitty-1" }) == 0)
check("reindex makes OS ordinals global across sockets", (function()
  local first = kitty.parse(json.decode(rawJson), "unix:/a")
  local second = kitty.parse(json.decode(rawJson), "unix:/b")
  local merged = {}
  for _, entry in ipairs(first) do
    table.insert(merged, entry)
  end
  for _, entry in ipairs(second) do
    table.insert(merged, entry)
  end
  kitty.reindex(merged)
  return merged[1].os_index == 1 and first[#first].os_index == 3 and merged[#merged].os_index == 6
end)())

-- Summary ---------------------------------------------------------------

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then
  error(tostring(failures) .. " test(s) failed")
end
