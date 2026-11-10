if ShaguScanPlus.disabled then return end

local utils = ShaguScanPlus.utils
local settings = ShaguScanPlus.settings

local share = {}

local function print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Shagu|cffffffffScanPlus:|r " .. msg)
end
share.print = print

-- Serializer: writes plain data (strings, numbers, booleans, tables) as a
-- Lua-like table literal. Keys are sorted so the output is stable.
local function serialize(value)
  local t = type(value)
  if t == "string" then
    local escaped = string.gsub(value, "\\", "\\\\")
    escaped = string.gsub(escaped, "\"", "\\\"")
    escaped = string.gsub(escaped, "\n", "\\n")
    return "\"" .. escaped .. "\""
  elseif t == "number" or t == "boolean" then
    return tostring(value)
  elseif t == "table" then
    local keys = {}
    for k in pairs(value) do
      if type(k) == "string" or type(k) == "number" then
        table.insert(keys, k)
      end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

    local out = { "{" }
    for _, k in ipairs(keys) do
      local v = serialize(value[k])
      if v then
        table.insert(out, "[" .. serialize(k) .. "]=" .. v .. ",")
      end
    end
    table.insert(out, "}")
    return table.concat(out)
  end
  return nil
end

-- Parser: reads only what serialize() writes. Pasted codes are never run as
-- Lua code, so a shared string can't execute anything.
local function deserialize(str)
  local pos = 1

  local function fail(msg)
    error(msg .. " (at position " .. pos .. ")", 0)
  end

  local function skip()
    local _, _, p = string.find(str, "^%s*()", pos)
    pos = p
  end

  local function expect(char)
    skip()
    if strsub(str, pos, pos) ~= char then fail("expected '" .. char .. "'") end
    pos = pos + 1
  end

  local parse

  local function parseString()
    pos = pos + 1 -- opening quote
    local out = {}
    while true do
      local s, _, char = string.find(str, "([\\\"])", pos)
      if not s then fail("unterminated string") end
      table.insert(out, strsub(str, pos, s - 1))
      if char == "\"" then
        pos = s + 1
        return table.concat(out)
      end
      local esc = strsub(str, s + 1, s + 1)
      if esc == "n" then
        table.insert(out, "\n")
      elseif esc == "\\" or esc == "\"" then
        table.insert(out, esc)
      else
        fail("invalid escape")
      end
      pos = s + 2
    end
  end

  local function parseTable(depth)
    if depth > 4 then fail("too deeply nested") end
    pos = pos + 1 -- opening brace
    local tbl = {}
    while true do
      skip()
      if strsub(str, pos, pos) == "}" then
        pos = pos + 1
        return tbl
      end
      expect("[")
      skip()
      local key = parse(depth)
      if type(key) ~= "string" and type(key) ~= "number" then fail("invalid key") end
      expect("]")
      expect("=")
      skip()
      tbl[key] = parse(depth)
      skip()
      if strsub(str, pos, pos) == "," then pos = pos + 1 end
    end
  end

  parse = function(depth)
    local char = strsub(str, pos, pos)
    if char == "{" then
      return parseTable(depth + 1)
    elseif char == "\"" then
      return parseString()
    elseif strsub(str, pos, pos + 3) == "true" then
      pos = pos + 4
      return true
    elseif strsub(str, pos, pos + 4) == "false" then
      pos = pos + 5
      return false
    end

    local _, e, num = string.find(str, "^([%-%+%deE%.]+)", pos)
    local value = num and tonumber(num)
    if not value then fail("unexpected input") end
    pos = e + 1
    return value
  end

  skip()
  local result = parse(0)
  skip()
  if pos <= strlen(str) then fail("unexpected trailing data") end
  return result
end

-- LZW compression, borrowed from pfUI (modules/share.lua), which is
-- based on Rochet2's lzw compression.
local function compress(input)
  if type(input) ~= "string" then
    return nil
  end
  local len = strlen(input)
  if len <= 1 then
    return "u"..input
  end

  local dict = {}
  for i = 0, 255 do
    local ic, iic = strchar(i), strchar(i, 0)
    dict[ic] = iic
  end
  local a, b = 0, 1

  local result = {"c"}
  local resultlen = 1
  local n = 2
  local word = ""
  for i = 1, len do
    local c = strsub(input, i, i)
    local wc = word..c
    if not dict[wc] then
      local write = dict[word]
      if not write then
        return nil
      end
      result[n] = write
      resultlen = resultlen + strlen(write)
      n = n+1
      if len <= resultlen then
        return "u"..input
      end
      local str = wc
      if a >= 256 then
        a, b = 0, b+1
        if b >= 256 then
          dict = {}
          b = 1
        end
      end
      dict[str] = strchar(a,b)
      a = a+1
      word = c
    else
      word = wc
    end
  end
  result[n] = dict[word]
  resultlen = resultlen+strlen(result[n])
  n = n+1
  if len <= resultlen then
    return "u"..input
  end
  return table.concat(result)
end

local function decompress(input)
  if type(input) ~= "string" or strlen(input) < 1 then
    return nil
  end

  local control = strsub(input, 1, 1)
  if control == "u" then
    return strsub(input, 2)
  elseif control ~= "c" then
    return nil
  end
  input = strsub(input, 2)
  local len = strlen(input)

  if len < 2 then
    return nil
  end

  local dict = {}
  for i = 0, 255 do
    local ic, iic = strchar(i), strchar(i, 0)
    dict[iic] = ic
  end

  local a, b = 0, 1

  local result = {}
  local n = 1
  local last = strsub(input, 1, 2)
  result[n] = dict[last]
  n = n+1
  for i = 3, len, 2 do
    local code = strsub(input, i, i+1)
    local lastStr = dict[last]
    if not lastStr then
      return nil
    end
    local toAdd = dict[code]
    if toAdd then
      result[n] = toAdd
      n = n+1
      local str = lastStr..strsub(toAdd, 1, 1)
      if a >= 256 then
        a, b = 0, b+1
        if b >= 256 then
          dict = {}
          b = 1
        end
      end
      dict[strchar(a,b)] = str
      a = a+1
    else
      local str = lastStr..strsub(lastStr, 1, 1)
      result[n] = str
      n = n+1
      if a >= 256 then
        a, b = 0, b+1
        if b >= 256 then
          dict = {}
          b = 1
        end
      end
      dict[strchar(a,b)] = str
      a = a+1
    end
    last = code
  end
  return table.concat(result)
end

-- Base64, so the compressed binary data can be copied and pasted as text.
local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64index = {}
for i = 1, 64 do b64index[strsub(b64chars, i, i)] = i - 1 end

local function b64char(n)
  return strsub(b64chars, n + 1, n + 1)
end

local function encode(input)
  local out, groups = {}, 0
  for i = 1, strlen(input), 3 do
    local a, b, c = strbyte(input, i), strbyte(input, i + 1), strbyte(input, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    table.insert(out, b64char(math.floor(n / 262144)))
    table.insert(out, b64char(mod(math.floor(n / 4096), 64)))
    table.insert(out, b and b64char(mod(math.floor(n / 64), 64)) or "=")
    table.insert(out, c and b64char(mod(n, 64)) or "=")

    groups = groups + 1
    if mod(groups, 16) == 0 then table.insert(out, "\n") end
  end
  return table.concat(out)
end

local function decode(input)
  input = string.gsub(input, "%s", "")
  local len = strlen(input)
  if len == 0 or mod(len, 4) ~= 0 then return nil end

  local out = {}
  for i = 1, len, 4 do
    local c1, c2, c3, c4 = strsub(input, i, i), strsub(input, i+1, i+1), strsub(input, i+2, i+2), strsub(input, i+3, i+3)
    local v1, v2 = b64index[c1], b64index[c2]
    local v3 = c3 == "=" and 0 or b64index[c3]
    local v4 = c4 == "=" and 0 or b64index[c4]
    if not v1 or not v2 or not v3 or not v4 then return nil end
    -- padding is only allowed at the very end
    if (c3 == "=" or c4 == "=") and i + 3 ~= len then return nil end
    if c3 == "=" and c4 ~= "=" then return nil end

    local n = v1 * 262144 + v2 * 4096 + v3 * 64 + v4
    table.insert(out, strchar(math.floor(n / 65536)))
    if c3 ~= "=" then table.insert(out, strchar(mod(math.floor(n / 256), 256))) end
    if c4 ~= "=" then table.insert(out, strchar(mod(n, 256))) end
  end
  return table.concat(out)
end

-- Only known settings with the right type are kept; anything missing or
-- invalid falls back to the defaults.
local schema = {
  filter = "string", anchor = "string",
  scale = "number", x = "number", y = "number",
  width = "number", height = "number", spacing = "number", maxrow = "number",
  locked = "boolean", shiftclick = "boolean",
}

share.Sanitize = function(config)
  local clean = {}
  for key, default in pairs(settings.defaults) do
    local value = type(config) == "table" and config[key]
    if type(value) == schema[key] then
      clean[key] = value
    else
      clean[key] = default
    end
  end
  if not utils.IsValidAnchor(clean.anchor) then
    clean.anchor = settings.defaults.anchor
  end
  return clean
end

share.Encode = function(windows)
  local payload = { version = 1, windows = {} }
  for caption, config in pairs(windows) do
    payload.windows[caption] = share.Sanitize(config)
  end
  return encode(compress(serialize(payload)))
end

-- Returns a table of { [caption] = config } and the number of windows,
-- or nil and an error message.
share.Decode = function(text)
  if not text or string.gsub(text, "%s", "") == "" then
    return nil, "Nothing to import. Paste a code first."
  end

  local raw = decode(text)
  local data = raw and decompress(raw)
  if not data then
    return nil, "This is not a valid ShaguScanPlus code."
  end

  local ok, payload = pcall(deserialize, data)
  if not ok or type(payload) ~= "table" or type(payload.windows) ~= "table" then
    return nil, "This is not a valid ShaguScanPlus code."
  end

  local windows, count = {}, 0
  for caption, config in pairs(payload.windows) do
    if type(caption) == "string" and caption ~= "" and type(config) == "table" then
      windows[caption] = share.Sanitize(config)
      count = count + 1
    end
  end

  if count == 0 then
    return nil, "This code doesn't contain any windows."
  end

  return windows, count
end

-- Copy & paste window
share.CreateWindow = function()
  local f = CreateFrame("Frame", "ShaguScanPlusShare", UIParent)
  f:Hide()
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetPoint("CENTER", 0, 0)
  f:SetWidth(420)
  f:SetHeight(300)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetBackdrop(settings.backdrop)
  f:SetBackdropColor(.2, .2, .2, 1)
  f:SetBackdropBorderColor(.2, .2, .2, 1)
  table.insert(UISpecialFrames, "ShaguScanPlusShare")

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontWhite")
  f.title:SetFont(STANDARD_TEXT_FONT, 10)
  f.title:SetPoint("TOP", f, "TOP", 0, -10)

  f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  f.close:SetWidth(20)
  f.close:SetHeight(20)
  f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  f.close:SetScript("OnClick", function() f:Hide() end)

  f.box = CreateFrame("Frame", nil, f)
  f.box:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -28)
  f.box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 34)
  f.box:SetBackdrop(settings.textborder)
  f.box:SetBackdropColor(.1, .1, .1, 1)
  f.box:SetBackdropBorderColor(.2, .2, .2, 1)

  f.scroll = CreateFrame("ScrollFrame", "ShaguScanPlusShareScroll", f.box, "UIPanelScrollFrameTemplate")
  f.scroll:SetPoint("TOPLEFT", f.box, "TOPLEFT", 6, -6)
  f.scroll:SetPoint("BOTTOMRIGHT", f.box, "BOTTOMRIGHT", -26, 6)

  f.text = CreateFrame("EditBox", "ShaguScanPlusShareText", f.scroll)
  f.text:SetMultiLine(true)
  f.text:SetAutoFocus(false)
  f.text:SetFontObject(GameFontHighlightSmall)
  f.text:SetJustifyH("LEFT")
  f.text:SetWidth(370)
  f.text:SetHeight(220)
  f.text:SetScript("OnEscapePressed", function() f:Hide() end)
  f.text:SetScript("OnTextChanged", function()
    -- keep exported codes read-only, so they can't be broken by accident
    if f.mode == "export" and this:GetText() ~= f.value then
      this:SetText(f.value)
      this:HighlightText()
    end
    f.scroll:UpdateScrollChildRect()
  end)
  if ScrollingEdit_OnCursorChanged and ScrollingEdit_OnUpdate then
    f.text:SetScript("OnCursorChanged", function()
      ScrollingEdit_OnCursorChanged(arg1, arg2, arg3, arg4)
    end)
    f.text:SetScript("OnUpdate", function()
      ScrollingEdit_OnUpdate()
    end)
  end
  f.scroll:SetScrollChild(f.text)

  -- clicking anywhere in the text area focuses the edit box
  f.scroll:EnableMouse(true)
  f.scroll:SetScript("OnMouseDown", function() f.text:SetFocus() end)

  f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontWhite")
  f.hint:SetFont(STANDARD_TEXT_FONT, 9)
  f.hint:SetTextColor(.7, .7, .7, 1)
  f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 14)

  f.action = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
  f.action:SetWidth(96)
  f.action:SetHeight(18)
  f.action:SetFont(STANDARD_TEXT_FONT, 10)
  f.action:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
  f.action:SetText("Import")
  f.action:SetScript("OnClick", function()
    if f.onimport and f.onimport(f.text:GetText()) then
      f:Hide()
    end
  end)

  share.window = f
  return f
end

share.ShowWindow = function(mode, title, text, onimport)
  local f = share.window or share.CreateWindow()
  f:Hide()

  f.mode = mode
  f.value = text
  f.onimport = onimport
  f.title:SetText(title)

  if mode == "export" then
    f.hint:SetText("Press Ctrl+C to copy the selected code.")
    f.action:Hide()
  else
    f.hint:SetText("Paste a code with Ctrl+V, then click Import.")
    f.action:Show()
  end

  f:Show()
  f.text:SetText(text or "")
  f.scroll:SetVerticalScroll(0)
  f.text:SetFocus()
  f.text:HighlightText()
end

-- Export one window, or all windows if no caption is given.
share.Export = function(caption)
  local windows, title
  if caption then
    if not ShaguScanPlus_db.config[caption] then
      print("There is no window called \"" .. caption .. "\".")
      return
    end
    windows = { [caption] = ShaguScanPlus_db.config[caption] }
    title = "Export: " .. caption
  else
    windows, title = ShaguScanPlus_db.config, "Export All Windows"
    if not next(windows) then
      print("There are no windows to export.")
      return
    end
  end

  share.ShowWindow("export", title, share.Encode(windows))
end

-- Import into one window (keeping its name), or import all windows from a
-- code if no caption is given.
share.Import = function(caption)
  local title = caption and ("Import: " .. caption) or "Import Windows"

  share.ShowWindow("import", title, "", function(text)
    local windows, count = share.Decode(text)
    if not windows then
      -- on failure, the second value is the error message
      print("|cffffaaaa" .. count)
      return false
    end

    if caption then
      if count > 1 then
        print("|cffffaaaaThis code contains " .. count .. " windows. Use /scan import all to import them.")
        return false
      end
      local _, config = next(windows)
      settings.ApplyConfig(caption, config)
      print("Imported settings into \"" .. caption .. "\".")
    else
      for name, config in pairs(windows) do
        settings.ApplyConfig(name, config)
      end
      print("Imported " .. count .. (count == 1 and " window." or " windows."))
    end

    return true
  end)
end

ShaguScanPlus.share = share
