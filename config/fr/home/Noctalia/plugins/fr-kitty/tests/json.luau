--!nonstrict
-- Minimal JSON decoder for the parser tests. The plugin itself uses
-- `noctalia.json.decode`; this keeps the test harness self-contained.

local M = {}

local function skipWhitespace(text, index)
  while index <= #text do
    local char = text:sub(index, index)
    if char == " " or char == "\t" or char == "\n" or char == "\r" then
      index = index + 1
    else
      break
    end
  end
  return index
end

local parseValue

local function parseString(text, index)
  index = index + 1 -- opening quote
  local out = {}
  while index <= #text do
    local char = text:sub(index, index)
    if char == '"' then
      return table.concat(out), index + 1
    elseif char == "\\" then
      local escape = text:sub(index + 1, index + 1)
      if escape == '"' or escape == "\\" or escape == "/" then
        table.insert(out, escape)
        index = index + 2
      elseif escape == "b" then
        table.insert(out, "\b")
        index = index + 2
      elseif escape == "f" then
        table.insert(out, "\f")
        index = index + 2
      elseif escape == "n" then
        table.insert(out, "\n")
        index = index + 2
      elseif escape == "r" then
        table.insert(out, "\r")
        index = index + 2
      elseif escape == "t" then
        table.insert(out, "\t")
        index = index + 2
      elseif escape == "u" then
        local code = tonumber(text:sub(index + 2, index + 5), 16)
        index = index + 6
        if code ~= nil and code >= 0xD800 and code <= 0xDBFF then
          -- High surrogate: pair it with the following low surrogate.
          if text:sub(index, index + 1) == "\\u" then
            local low = tonumber(text:sub(index + 2, index + 5), 16)
            if low ~= nil and low >= 0xDC00 and low <= 0xDFFF then
              code = 0x10000 + ((code - 0xD800) * 0x400) + (low - 0xDC00)
              index = index + 6
            end
          end
        end
        table.insert(out, utf8.char(code or 0xFFFD))
      else
        error("invalid escape sequence: \\" .. escape)
      end
    else
      table.insert(out, char)
      index = index + 1
    end
  end
  error("unterminated string")
end

local function parseNumber(text, index)
  local start = index
  while index <= #text and text:sub(index, index):match("[%d%.eE%+%-]") do
    index = index + 1
  end
  return tonumber(text:sub(start, index - 1)), index
end

local function parseArray(text, index)
  index = skipWhitespace(text, index + 1)
  local out = {}
  if text:sub(index, index) == "]" then
    return out, index + 1
  end
  while true do
    local value
    value, index = parseValue(text, index)
    table.insert(out, value)
    index = skipWhitespace(text, index)
    local char = text:sub(index, index)
    if char == "," then
      index = skipWhitespace(text, index + 1)
    elseif char == "]" then
      return out, index + 1
    else
      error("expected ',' or ']' at " .. tostring(index))
    end
  end
end

local function parseObject(text, index)
  index = skipWhitespace(text, index + 1)
  local out = {}
  if text:sub(index, index) == "}" then
    return out, index + 1
  end
  while true do
    local key
    key, index = parseString(text, index)
    index = skipWhitespace(text, index)
    if text:sub(index, index) ~= ":" then
      error("expected ':' at " .. tostring(index))
    end
    local value
    value, index = parseValue(text, skipWhitespace(text, index + 1))
    out[key] = value
    index = skipWhitespace(text, index)
    local char = text:sub(index, index)
    if char == "," then
      index = skipWhitespace(text, index + 1)
    elseif char == "}" then
      return out, index + 1
    else
      error("expected ',' or '}' at " .. tostring(index))
    end
  end
end

parseValue = function(text, index)
  index = skipWhitespace(text, index)
  local char = text:sub(index, index)
  if char == '"' then
    return parseString(text, index)
  elseif char == "{" then
    return parseObject(text, index)
  elseif char == "[" then
    return parseArray(text, index)
  elseif char == "t" then
    return true, index + 4
  elseif char == "f" then
    return false, index + 5
  elseif char == "n" then
    return nil, index + 4
  else
    return parseNumber(text, index)
  end
end

function M.decode(text)
  local value, index = parseValue(text, 1)
  index = skipWhitespace(text, index)
  if index <= #text then
    error("trailing content at " .. tostring(index))
  end
  return value
end

return M
