if ShaguScan.disabled then return end

local utils = ShaguScan.utils

local settings = {}

SLASH_SHAGUSCAN1, SLASH_SHAGUSCAN2, SLASH_SHAGUSCAN3, SLASH_SHAGUSCAN4 = "/scan", "/sscan", "/shaguscan", "/shaguscanplus"

SlashCmdList["SHAGUSCAN"] = function(input)
  input = utils.trim(input)
  local command = strlower(input)
  if command == "export all" then
    ShaguScan.share.Export()
    return
  elseif command == "import all" then
    ShaguScan.share.Import()
    return
  elseif command == "list" then
    settings.ListWindows()
    return
  end

  local caption = input and input ~= '' and input or "Scanner"
  settings.OpenConfig(caption)
end

-- Print all scanner windows, sorted by name, with their filters.
settings.ListWindows = function()
  local prefix = "|cffffcc00Shagu|cffffffffScanPlus:|r "
  local names = {}
  for caption in pairs(ShaguScan_db.config) do
    table.insert(names, caption)
  end

  if table.getn(names) == 0 then
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "There are no scanner windows. Create one with /scan <name>.")
    return
  end

  table.sort(names, function(a, b) return strlower(a) < strlower(b) end)

  DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Scanner windows (" .. table.getn(names) .. "):")
  for _, caption in ipairs(names) do
    local filter = ShaguScan_db.config[caption].filter or ""
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffcc00" .. caption .. "|r |cffaaaaaa" .. filter)
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaaOpen a window's settings with /scan <name>.")
end

settings.defaults = {
  filter = "npc,infight,alive",
  scale = 1, anchor = "CENTER", x = 0, y = 0,
  width = 75, height = 12, spacing = 4, maxrow = 20,
  locked = false,
  shiftclick = false,
  hidelabel = false,
}

-- Write a config into the saved settings. An existing config table is
-- updated in place, so open dialogs and windows keep a valid reference.
settings.ApplyConfig = function(caption, config)
  local existing = ShaguScan_db.config[caption]
  if existing then
    for key in pairs(existing) do existing[key] = nil end
    for key, value in pairs(config) do existing[key] = value end
  else
    ShaguScan_db.config[caption] = config
  end

  local dialog = getglobal("ShaguScanConfigDialog"..caption)
  if dialog and dialog.Load then
    dialog.Load(ShaguScan_db.config[caption])
  end
end

settings.backdrop = {
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  tile = true, tileSize = 16, edgeSize = 12,
  insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

settings.textborder = {
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  tile = true, tileSize = 16, edgeSize = 8,
  insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

settings.CreateLabel = function(parent, text)
  local label = parent:CreateFontString(nil, 'HIGH', 'GameFontWhite')
  label:SetFont(STANDARD_TEXT_FONT, 9)
  label:SetText(text)
  label:SetHeight(18)
  return label
end

settings.CreateTextBox = function(parent, text)
  local textbox = CreateFrame("EditBox", nil, parent)
  textbox.ShowTooltip = settings.ShowTooltip

  textbox:SetTextColor(1,.8,.2,1)
  textbox:SetJustifyH("RIGHT")
  textbox:SetTextInsets(5,5,5,5)
  textbox:SetBackdrop(settings.textborder)
  textbox:SetBackdropColor(.1,.1,.1,1)
  textbox:SetBackdropBorderColor(.2,.2,.2,1)

  textbox:SetHeight(18)

  textbox:SetFontObject(GameFontNormal)
  textbox:SetFont(STANDARD_TEXT_FONT, 9)
  textbox:SetAutoFocus(false)
  textbox:SetText((text or ""))

  textbox:SetScript("OnEscapePressed", function(self)
    this:ClearFocus()
  end)

  return textbox
end

settings.ShowTooltip = function(parent, strings)
  GameTooltip:SetOwner(parent, "ANCHOR_RIGHT")
  for id, entry in pairs(strings) do
    if type(entry) == "table" then
      GameTooltip:AddDoubleLine(entry[1], entry[2])
    else
      GameTooltip:AddLine(entry)
    end
  end
  GameTooltip:Show()
end

settings.OpenConfig = function(caption)
  -- Create defconfig if new config (or if the window was deleted)
  if not ShaguScan_db.config[caption] then
    local config = {}
    for key, value in pairs(settings.defaults) do config[key] = value end
    ShaguScan_db.config[caption] = config
  end

  -- Toggle Existing Dialog, showing the current values (the window may have
  -- been moved since, and Save must not move it back)
  local existing = getglobal("ShaguScanConfigDialog"..caption)
  if existing then
    if existing:IsShown() then
      existing:Hide()
    else
      existing.Load(ShaguScan_db.config[caption])
      existing:Show()
    end
    return
  end

  -- Main Dialog
  local dialog = CreateFrame("Frame", "ShaguScanConfigDialog"..caption, UIParent)
  table.insert(UISpecialFrames, "ShaguScanConfigDialog"..caption)
  dialog.id = caption

  -- Save Shortcuts
  local config = ShaguScan_db.config[caption]
  local caption = caption

  dialog:SetFrameStrata("DIALOG")
  dialog:SetPoint("CENTER", 0, 0)
  dialog:SetWidth(264)
  dialog:SetHeight(264)

  dialog:EnableMouse(true)
  dialog:RegisterForDrag("LeftButton")
  dialog:SetMovable(true)
  dialog:SetScript("OnDragStart", function() this:StartMoving() end)
  dialog:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

  dialog:SetBackdrop(settings.backdrop)
  dialog:SetBackdropColor(.2, .2, .2, 1)
  dialog:SetBackdropBorderColor(.2, .2, .2, 1)

  -- Assign functions to dialog
  dialog.CreateTextBox = settings.CreateTextBox
  dialog.CreateLabel = settings.CreateLabel

  -- Save & Reload
  dialog.save = CreateFrame("Button", nil, dialog, "GameMenuButtonTemplate")
  dialog.save:SetWidth(59)
  dialog.save:SetHeight(18)
  dialog.save:SetFont(STANDARD_TEXT_FONT, 10)
  dialog.save:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -8, 8)
  dialog.save:SetText("Save")
  dialog.save:SetScript("OnClick", function()
    local new_caption = utils.trim(dialog.caption:GetText())
    local prefix = "|cffffcc00Shagu|cffffffffScanPlus:|cffffaaaa "

    if new_caption == "" then
      DEFAULT_CHAT_FRAME:AddMessage(prefix .. "The window needs a name.")
      return
    elseif new_caption ~= caption and ShaguScan_db.config[new_caption] then
      DEFAULT_CHAT_FRAME:AddMessage(prefix .. "There already is a window called \"" .. new_caption .. "\".")
      return
    end

    -- fall back to the current values for anything invalid
    local config = ShaguScan_db.config[caption] or settings.defaults
    local function positive(text, current)
      local value = tonumber(text)
      return value and value > 0 and value or current
    end

    local filter = dialog.filter:GetText()
    local width = dialog.width:GetText()
    local height = dialog.height:GetText()
    local spacing = dialog.spacing:GetText()
    local maxrow = dialog.maxrow:GetText()
    local anchor = dialog.anchor:GetText()
    local scale = dialog.scale:GetText()
    local x = dialog.x:GetText()
    local y = dialog.y:GetText()

    -- build new config
    local new_config = {
      filter = filter,
      width = positive(width, config.width),
      height = positive(height, config.height),
      spacing = tonumber(spacing) and tonumber(spacing) >= 0 and tonumber(spacing) or config.spacing,
      maxrow = positive(maxrow, config.maxrow),
      anchor = utils.IsValidAnchor(anchor) and anchor or config.anchor,
      scale = positive(scale, config.scale),
      x = tonumber(x) or config.x,
      y = tonumber(y) or config.y,
      locked = dialog.locked:GetChecked() and true or false,
      shiftclick = dialog.shiftclick:GetChecked() and true or false,
      hidelabel = dialog.hidelabel:GetChecked() and true or false,
    }

    if new_caption == caption then
      settings.ApplyConfig(caption, new_config)
    else
      -- renamed: this dialog stays tied to the old name, so a later
      -- /scan <new name> opens a fresh dialog for the renamed window
      ShaguScan_db.config[caption] = nil
      ShaguScan_db.config[new_caption] = new_config
    end
    dialog:Hide()
  end)

  -- Delete
  dialog.delete = CreateFrame("Button", nil, dialog, "GameMenuButtonTemplate")
  dialog.delete:SetWidth(59)
  dialog.delete:SetHeight(18)
  dialog.delete:SetFont(STANDARD_TEXT_FONT, 10)
  dialog.delete:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 8, 8)
  dialog.delete:SetText("Delete")
  dialog.delete:SetScript("OnClick", function()
    ShaguScan_db.config[caption] = nil
    this:GetParent():Hide()
  end)

  -- Import
  dialog.import = CreateFrame("Button", nil, dialog, "GameMenuButtonTemplate")
  dialog.import:SetWidth(59)
  dialog.import:SetHeight(18)
  dialog.import:SetFont(STANDARD_TEXT_FONT, 10)
  dialog.import:SetPoint("LEFT", dialog.delete, "RIGHT", 4, 0)
  dialog.import:SetText("Import")
  dialog.import:SetScript("OnClick", function()
    ShaguScan.share.Import(caption)
  end)
  dialog.import:SetScript("OnEnter", function()
    settings.ShowTooltip(dialog.import, {
      "Import Settings",
      "|cffaaaaaaPaste a code to replace this window's settings.",
      "|cffaaaaaaThe window keeps its name."
    })
  end)
  dialog.import:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- Export
  dialog.export = CreateFrame("Button", nil, dialog, "GameMenuButtonTemplate")
  dialog.export:SetWidth(59)
  dialog.export:SetHeight(18)
  dialog.export:SetFont(STANDARD_TEXT_FONT, 10)
  dialog.export:SetPoint("RIGHT", dialog.save, "LEFT", -4, 0)
  dialog.export:SetText("Export")
  dialog.export:SetScript("OnClick", function()
    ShaguScan.share.Export(caption)
  end)
  dialog.export:SetScript("OnEnter", function()
    settings.ShowTooltip(dialog.export, {
      "Export Settings",
      "|cffaaaaaaShows a code for this window that can be shared.",
      "|cffaaaaaaUnsaved changes are not included."
    })
  end)
  dialog.export:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  dialog.close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
  dialog.close:SetWidth(20)
  dialog.close:SetHeight(20)
  dialog.close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", 0, 0)
  dialog.close:SetScript("OnClick", function()
    this:GetParent():Hide()
  end)

  -- Caption (Title)
  dialog.caption = dialog:CreateTextBox(caption)
  dialog.caption:SetPoint("TOPLEFT", dialog, "TOPLEFT", 8, -18)
  dialog.caption:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -8, -18)
  dialog.caption:SetFont(STANDARD_TEXT_FONT, 10)
  dialog.caption:SetJustifyH("CENTER")
  dialog.caption:SetHeight(20)

  -- Backdrop
  local backdrop = CreateFrame("Frame", nil, dialog)
  backdrop:SetBackdrop(settings.backdrop)
  backdrop:SetBackdropBorderColor(.2,.2,.2,1)
  backdrop:SetBackdropColor(.2,.2,.2,1)

  backdrop:SetPoint("TOPLEFT", dialog, "TOPLEFT", 8, -40)
  backdrop:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -8, 28)

  backdrop.CreateTextBox = settings.CreateTextBox
  backdrop.CreateLabel = settings.CreateLabel

  backdrop.pos = 8

  -- Filter
  local caption = backdrop:CreateLabel("Filter:")
  caption:SetPoint("TOPLEFT", backdrop, 10, -backdrop.pos)

  dialog.filter = backdrop:CreateTextBox(config.filter)
  dialog.filter:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 60, -backdrop.pos)
  dialog.filter:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", -8, -backdrop.pos)
  dialog.filter:SetScript("OnEnter", function()
    dialog.filter:ShowTooltip({
      "Unit Filters",
      "|cffaaaaaaA comma separated list of filters.",
      " ",
      { "|cffffffffplayer", "Player Characters" },
      { "|cffffffffnpc", "NPC Units" },
      { "|cffffffffinfight", "Infight Units" },
      { "|cffffffffdead", "Dead Units" },
      { "|cffffffffalive", "Living Units" },
      { "|cffffffffhorde", "Horde Units" },
      { "|cffffffffalliance", "Alliance Units" },
      { "|cffffffffhardcore", "Hardcore Players" },
      { "|cffffffffpve", "PvE Units" },
      { "|cffffffffpvp", "PvP Enabled Units" },
      { "|cfffffffficon", "Units With Raid Icons" },
      { "|cffffffffhurt", "Units Below Full Health" },
      { "|cfffffffftagged", "Units Tagged By You" },
      " ",
      "|cffffffffcolor:red(hurt,infight)",
      "|cffaaaaaaColors bars of units matching the filters in brackets.",
      "|cffaaaaaaUse a color name or a hex code like #ff8000.",
      " ",
      "|cffffffffA complete list of filters can be found in the README."
    })
  end)

  dialog.filter:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  backdrop.pos = backdrop.pos + 18

  -- Spacer
  backdrop.pos = backdrop.pos + 9

  -- Width
  local caption = backdrop:CreateLabel("Width:")
  caption:SetPoint("TOPLEFT", backdrop, 10, -backdrop.pos)

  dialog.width = backdrop:CreateTextBox(config.width)
  dialog.width:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 60, -backdrop.pos)
  dialog.width:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", -8, -backdrop.pos)
  dialog.width:SetScript("OnEnter", function()
    dialog.width:ShowTooltip({
      "Health Bar Width",
      "|cffaaaaaaAn Integer Value in Pixels"
    })
  end)

  dialog.width:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  backdrop.pos = backdrop.pos + 18

  -- Height
  local caption = backdrop:CreateLabel("Height:")
  caption:SetPoint("TOPLEFT", backdrop, 10, -backdrop.pos)

  dialog.height = backdrop:CreateTextBox(config.height)
  dialog.height:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 60, -backdrop.pos)
  dialog.height:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", -8, -backdrop.pos)
  dialog.height:SetScript("OnEnter", function()
    dialog.height:ShowTooltip({
      "Health Bar Height",
      "|cffaaaaaaAn Integer Value in Pixels"
    })
  end)

  dialog.height:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  backdrop.pos = backdrop.pos + 18

  -- Spacing
  local caption = backdrop:CreateLabel("Spacing:")
  caption:SetPoint("TOPLEFT", backdrop, 10, -backdrop.pos)

  dialog.spacing = backdrop:CreateTextBox(config.spacing)
  dialog.spacing:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 60, -backdrop.pos)
  dialog.spacing:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", -8, -backdrop.pos)
  dialog.spacing:SetScript("OnEnter", function()
    dialog.spacing:ShowTooltip({
      "Spacing Between Health Bars",
      "|cffaaaaaaAn Integer Value in Pixels"
    })
  end)

  dialog.spacing:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  backdrop.pos = backdrop.pos + 18

  -- Max per Row
  local caption = backdrop:CreateLabel("Max-Row:")
  caption:SetPoint("TOPLEFT", backdrop, 10, -backdrop.pos)

  dialog.maxrow = backdrop:CreateTextBox(config.maxrow)
  dialog.maxrow:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 60, -backdrop.pos)
  dialog.maxrow:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", -8, -backdrop.pos)
  dialog.maxrow:SetScript("OnEnter", function()
    dialog.maxrow:ShowTooltip({
      "Maximum Entries Per Column",
      "|cffaaaaaaA new column will be created once exceeded"
    })
  end)

  dialog.maxrow:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  backdrop.pos = backdrop.pos + 18

  -- Spacer
  backdrop.pos = backdrop.pos + 9

  -- Anchor
  local caption = backdrop:CreateLabel("Anchor:")
  caption:SetPoint("TOPLEFT", backdrop, 10, -backdrop.pos)

  dialog.anchor = backdrop:CreateTextBox(config.anchor)
  dialog.anchor:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 60, -backdrop.pos)
  dialog.anchor:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", -8, -backdrop.pos)
  dialog.anchor:SetScript("OnEnter", function()
    dialog.anchor:ShowTooltip({
      "Window Anchor",
      "|cffaaaaaaThe Anchor From Where Positions Are Calculated.",
      " ",
      {"TOP", "TOPLEFT"},
      {"TOPRIGHT", "CENTER"},
      {"LEFT", "RIGHT"},
      {"BOTTOM", "BOTTOMLEFT"},
      {"BOTTOMRIGHT", ""}
    })
  end)

  dialog.anchor:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  backdrop.pos = backdrop.pos + 18

  -- Scale
  local caption = backdrop:CreateLabel("Scale:")
  caption:SetPoint("TOPLEFT", backdrop, 10, -backdrop.pos)

  dialog.scale = backdrop:CreateTextBox(utils.round(config.scale, 2))
  dialog.scale:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 60, -backdrop.pos)
  dialog.scale:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", -8, -backdrop.pos)
  dialog.scale:SetScript("OnEnter", function()
    dialog.scale:ShowTooltip({
      "Window Scale",
      "|cffaaaaaaA floating point number, 1 equals 100%"
    })
  end)

  dialog.scale:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  backdrop.pos = backdrop.pos + 18

  -- Position-X
  local caption = backdrop:CreateLabel("X-Position:")
  caption:SetPoint("TOPLEFT", backdrop, 10, -backdrop.pos)

  dialog.x = backdrop:CreateTextBox(utils.round(config.x, 2))
  dialog.x:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 60, -backdrop.pos)
  dialog.x:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", -8, -backdrop.pos)
  dialog.x:SetScript("OnEnter", function()
    dialog.x:ShowTooltip({
      "X-Position of Window",
      "|cffaaaaaaA Number in Pixels"
    })
  end)

  dialog.x:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  backdrop.pos = backdrop.pos + 18

  -- Position-Y
  local caption = backdrop:CreateLabel("Y-Position:")
  caption:SetPoint("TOPLEFT", backdrop, 10, -backdrop.pos)

  dialog.y = backdrop:CreateTextBox(utils.round(config.y, 2))
  dialog.y:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 60, -backdrop.pos)
  dialog.y:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", -8, -backdrop.pos)
  dialog.y:SetScript("OnEnter", function()
    dialog.y:ShowTooltip({
      "Y-Position of Window",
      "|cffaaaaaaA Number in Pixels"
    })
  end)

  dialog.y:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  backdrop.pos = backdrop.pos + 18

  -- Spacer
  backdrop.pos = backdrop.pos + 9

  -- Lock Movement
  -- (checkboxes are shrunk from the template's 32px to fit one row each)
  dialog.locked = CreateFrame("CheckButton", nil, backdrop, "UICheckButtonTemplate")
  dialog.locked:SetWidth(20)
  dialog.locked:SetHeight(20)
  dialog.locked:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 6, -backdrop.pos)
  dialog.locked:SetChecked(config.locked and true or false)

  dialog.locked.text = dialog.locked:CreateFontString(nil, "OVERLAY", "GameFontWhite")
  dialog.locked.text:SetFont(STANDARD_TEXT_FONT, 9)
  dialog.locked.text:SetPoint("LEFT", dialog.locked, "RIGHT", 2, 0)
  dialog.locked.text:SetText("Lock Movement")

  dialog.locked:SetScript("OnEnter", function()
    settings.ShowTooltip(dialog.locked, {
    "Lock Frame Position",
    "|cffaaaaaaPrevents the scan window from being dragged."
    })
  end)

  dialog.locked:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  backdrop.pos = backdrop.pos + 20

  -- Shift Required for Mouse Interaction
  dialog.shiftclick = CreateFrame("CheckButton", nil, backdrop, "UICheckButtonTemplate")
  dialog.shiftclick:SetWidth(20)
  dialog.shiftclick:SetHeight(20)
  dialog.shiftclick:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 6, -backdrop.pos)
  dialog.shiftclick:SetChecked(config.shiftclick and true or false)

  dialog.shiftclick.text = dialog.shiftclick:CreateFontString(nil, "OVERLAY", "GameFontWhite")
  dialog.shiftclick.text:SetFont(STANDARD_TEXT_FONT, 9)
  dialog.shiftclick.text:SetPoint("LEFT", dialog.shiftclick, "RIGHT", 2, 0)
  dialog.shiftclick.text:SetText("Require Shift for Mouse")

  dialog.shiftclick:SetScript("OnEnter", function()
    settings.ShowTooltip(dialog.shiftclick, {
      "Require Shift Key",
      "|cffaaaaaaWhen enabled, the scan window will",
      "|cffaaaaaaignore all mouse input unless Shift is held."
    })
  end)

  dialog.shiftclick:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  backdrop.pos = backdrop.pos + 20

  -- Hide Label
  dialog.hidelabel = CreateFrame("CheckButton", nil, backdrop, "UICheckButtonTemplate")
  dialog.hidelabel:SetWidth(20)
  dialog.hidelabel:SetHeight(20)
  dialog.hidelabel:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 6, -backdrop.pos)
  dialog.hidelabel:SetChecked(config.hidelabel and true or false)

  dialog.hidelabel.text = dialog.hidelabel:CreateFontString(nil, "OVERLAY", "GameFontWhite")
  dialog.hidelabel.text:SetFont(STANDARD_TEXT_FONT, 9)
  dialog.hidelabel.text:SetPoint("LEFT", dialog.hidelabel, "RIGHT", 2, 0)
  dialog.hidelabel.text:SetText("Hide Label")

  dialog.hidelabel:SetScript("OnEnter", function()
    settings.ShowTooltip(dialog.hidelabel, {
      "Hide Label",
      "|cffaaaaaaHides the window's title and settings button,",
      "|cffaaaaaaso the health bars start at the top.",
      "|cffaaaaaaUse /scan <name> to open the settings again."
    })
  end)

  dialog.hidelabel:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  backdrop.pos = backdrop.pos + 20

  -- Size the dialog to its content: the inner panel starts 40px below the
  -- top and ends 28px above the bottom (button row); keep 6px padding.
  dialog:SetHeight(40 + backdrop.pos + 6 + 28)

  -- Refresh all fields from a config (used after importing)
  dialog.Load = function(config)
    dialog.caption:SetText(dialog.id)
    dialog.filter:SetText(config.filter or "")
    dialog.width:SetText(tostring(config.width))
    dialog.height:SetText(tostring(config.height))
    dialog.spacing:SetText(tostring(config.spacing))
    dialog.maxrow:SetText(tostring(config.maxrow))
    dialog.anchor:SetText(config.anchor or "")
    dialog.scale:SetText(tostring(utils.round(config.scale, 2)))
    dialog.x:SetText(tostring(utils.round(config.x, 2)))
    dialog.y:SetText(tostring(utils.round(config.y, 2)))
    dialog.locked:SetChecked(config.locked and true or false)
    dialog.shiftclick:SetChecked(config.shiftclick and true or false)
    dialog.hidelabel:SetChecked(config.hidelabel and true or false)
  end
end

ShaguScan.settings = settings
