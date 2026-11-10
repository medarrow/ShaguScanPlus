if ShaguScan.disabled then return end

local utils = ShaguScan.utils
local filter = ShaguScan.filter
local settings = ShaguScan.settings

local ui = CreateFrame("Frame", nil, UIParent)

ui.border = {
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 8,
  insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

ui.background = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  tile = true, tileSize = 16, edgeSize = 8,
  insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

ui.frames = {}

ui.CreateRoot = function(parent, caption)
  local frame = CreateFrame("Frame", "ShaguScan"..caption, parent)
  frame.id = caption
  
  frame:RegisterEvent("MODIFIER_STATE_CHANGED")

  frame:SetScript("OnEvent", function(self)
    if event == "MODIFIER_STATE_CHANGED" then
      ui.UpdateMouseState(self)
    end
  end)

  frame:EnableMouse(true)
  --[[frame:SetScript("OnUpdate", function()
    local config = ShaguScan_db.config[this.id]
    if config and config.shiftclick then
      this:EnableMouse(IsShiftKeyDown())
    else
      this:EnableMouse(true)
    end
  end)]]--
  frame:RegisterForDrag("LeftButton")
  frame:SetMovable(true)

  frame:SetScript("OnDragStart", function()
    local config = ShaguScan_db.config[this.id]
    if config and config.locked then return end -- prevent dragging if locked

    this.lock = true
    this:StartMoving()
  end)

  frame:SetScript("OnDragStop", function()
    local config = ShaguScan_db.config[this.id]
    if config and config.locked then
      this:StopMovingOrSizing()
      this.lock = false
      return
    end

    local new_anchor = utils.GetBestAnchor(this)
    local anchor, x, y = utils.ConvertFrameAnchor(this, new_anchor)
    this:ClearAllPoints()
    this:SetPoint(anchor, UIParent, anchor, x, y)

    local anchor, _, _, x, y = this:GetPoint()
    config.anchor, config.x, config.y = anchor, x, y

    this:StopMovingOrSizing()
    this.lock = false
  end)

  -- assign/initialize elements
  frame.CreateBar = ui.CreateBar
  frame.frames = {}

  -- create title text
  frame.caption = frame:CreateFontString(nil, "HIGH", "GameFontWhite")
  frame.caption:SetFont(STANDARD_TEXT_FONT, 9, "THINOUTLINE")
  frame.caption:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -2)
  frame.caption:SetTextColor(1, 1, 1, 1)
  frame.caption:SetText(caption)

  -- create option button
  frame.settings = CreateFrame("Button", nil, frame)
  frame.settings:SetPoint("RIGHT", frame.caption, "LEFT", -2, 0)
  frame.settings:SetWidth(8)
  frame.settings:SetHeight(8)

  frame.settings:SetScript("OnEnter", function()
    frame.settings.tex:SetAlpha(1)
  end)

  frame.settings:SetScript("OnLeave", function()
    frame.settings.tex:SetAlpha(.5)
  end)

  frame.settings.tex = frame.settings:CreateTexture(nil, 'OVERLAY')
  frame.settings.tex:SetTexture("Interface\\AddOns\\ShaguScan\\img\\config")
  frame.settings.tex:SetAllPoints()
  frame.settings.tex:SetAlpha(.5)

  frame.settings:SetScript("OnClick", function()
    settings.OpenConfig(this:GetParent().id)
  end)

  ui.UpdateMouseState(frame)
  
  return frame
end

ui.BarEnter = function()
  this.border:SetBackdropBorderColor(1, 1, 1, 1)
  this.hover = true

  GameTooltip_SetDefaultAnchor(GameTooltip, this)
  GameTooltip:SetUnit(this.guid)
  GameTooltip:Show()
end

ui.BarLeave = function()
  this.hover = false
  GameTooltip:Hide()
end

ui.BarUpdate = function()
  -- animate combat text
  CombatFeedback_OnUpdate(arg1)

  -- update statusbar values
  this.bar:SetMinMaxValues(0, UnitHealthMax(this.guid))
  this.bar:SetValue(UnitHealth(this.guid))

  -- update health bar color (a matching color: modifier wins)
  if this.color then
    this.bar:SetStatusBarColor(this.color[1], this.color[2], this.color[3], 1)
  else
    local hex, r, g, b, a = utils.GetUnitColor(this.guid)
    this.bar:SetStatusBarColor(r, g, b, a)
  end

  -- update caption text
  local level = utils.GetLevelString(this.guid)
  local level_color = utils.GetLevelColor(this.guid)
  local name = UnitName(this.guid)
  this.text:SetText(level_color..level.."|r "..name)

  -- update health bar border
  if this.hover then
    this.border:SetBackdropBorderColor(1, 1, 1, 1)
  elseif UnitAffectingCombat(this.guid) then
    this.border:SetBackdropBorderColor(.8, .2, .2, 1)
  else
    this.border:SetBackdropBorderColor(.2, .2, .2, 1)
  end

  -- show raid icon if existing
  if GetRaidTargetIndex(this.guid) then
    SetRaidTargetIconTexture(this.icon, GetRaidTargetIndex(this.guid))
    this.icon:Show()
  else
    this.icon:Hide()
  end

  -- update target indicator
  if UnitIsUnit("target", this.guid) then
    this.target_left:Show()
    this.target_right:Show()
  else
    this.target_left:Hide()
    this.target_right:Hide()
  end
end

ui.BarClick = function()
  TargetUnit(this.guid)
end

ui.BarEvent = function()
  if arg1 ~= this.guid then return end
  CombatFeedback_OnCombatEvent(arg2, arg3, arg4, arg5)
end

ui.CreateBar = function(parent, guid)
  local frame = CreateFrame("Button", nil, parent)
  frame.guid = guid

  --[[frame:SetScript("OnUpdate", function()
    ui.BarUpdate()

    local config = ShaguScan_db.config[parent.id]
    if config and config.shiftclick then
      frame:EnableMouse(IsShiftKeyDown())
    else
      frame:EnableMouse(true)
    end
  end)]]--

  -- assign required events and scripts
  frame:RegisterEvent("UNIT_COMBAT")
  frame:SetScript("OnEvent", ui.BarEvent)
  frame:SetScript("OnClick", ui.BarClick)
  frame:SetScript("OnEnter", ui.BarEnter)
  frame:SetScript("OnLeave", ui.BarLeave)
  frame:SetScript("OnUpdate", ui.BarUpdate)

  -- create health bar
  local bar = CreateFrame("StatusBar", nil, frame)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(1, .8, .2, 1)
  bar:SetMinMaxValues(0, 100)
  bar:SetValue(20)
  bar:SetAllPoints()
  frame.bar = bar

  -- create caption text
  local text = frame.bar:CreateFontString(nil, "HIGH", "GameFontWhite")
  text:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, -2)
  text:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)
  text:SetFont(STANDARD_TEXT_FONT, 9, "THINOUTLINE")
  text:SetJustifyH("LEFT")
  frame.text = text

  -- create combat feedback text
  local feedback = bar:CreateFontString(guid.."feedback"..GetTime(), "OVERLAY", "NumberFontNormalHuge")
  feedback:SetAlpha(.8)
  feedback:SetFont(DAMAGE_TEXT_FONT, 12, "OUTLINE")
  feedback:SetParent(bar)
  feedback:ClearAllPoints()
  feedback:SetPoint("CENTER", bar, "CENTER", 0, 0)

  frame.feedbackFontHeight = 14
  frame.feedbackStartTime = GetTime()
  frame.feedbackText = feedback

  -- create raid icon textures
  local icon = bar:CreateTexture(nil, "OVERLAY")
  icon:SetWidth(16)
  icon:SetHeight(16)
  icon:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
  icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  icon:Hide()
  frame.icon = icon

  -- create target indicator
  local target_left = bar:CreateTexture(nil, "OVERLAY")
  target_left:SetWidth(8)
  target_left:SetHeight(8)
  target_left:SetPoint("LEFT", frame, "LEFT", -4, 0)
  target_left:SetTexture("Interface\\AddOns\\ShaguScan\\img\\target-left")
  target_left:Hide()
  frame.target_left = target_left

  local target_right = bar:CreateTexture(nil, "OVERLAY")
  target_right:SetWidth(8)
  target_right:SetHeight(8)
  target_right:SetPoint("RIGHT", frame, "RIGHT", 4, 0)
  target_right:SetTexture("Interface\\AddOns\\ShaguScan\\img\\target-right")
  target_right:Hide()
  frame.target_right = target_right

  -- create frame backdrops
  if pfUI and pfUI.uf then
    pfUI.api.CreateBackdrop(frame)
    frame.border = frame.backdrop
  else
    frame:SetBackdrop(ui.background)
    frame:SetBackdropColor(0, 0, 0, 1)

    local border = CreateFrame("Frame", nil, frame.bar)
    border:SetBackdrop(ui.border)
    border:SetBackdropColor(.2, .2, .2, 1)
    border:SetPoint("TOPLEFT", frame.bar, "TOPLEFT", -2,2)
    border:SetPoint("BOTTOMRIGHT", frame.bar, "BOTTOMRIGHT", 2,-2)
    frame.border = border
  end

  -- apply current mouse state
  local config = ShaguScan_db.config[parent.id]
  if config then
    local allow = true
    if config.shiftclick then
      allow = IsShiftKeyDown() and true or false
    end
    frame:EnableMouse(allow)
  end

  return frame
end

ui.UpdateMouseState = function(root)
  local config = ShaguScan_db.config[root.id]
  if not config then return end

  local allow = true

  if config.shiftclick then
    allow = IsShiftKeyDown() and true or false
  end

  root:EnableMouse(allow)

  for guid, frame in pairs(root.frames) do
    frame:EnableMouse(allow)
  end
end

ui:SetAllPoints()
ui:SetScript("OnUpdate", function()
  if ( this.tick or 1) > GetTime() then return else this.tick = GetTime() + .5 end

  -- remove old leftover frames
  for caption, root in pairs(ui.frames) do
    if not ShaguScan_db.config[caption] then
      ui.frames[caption]:Hide()
      ui.frames[caption] = nil
    end
  end

  -- create ui frames based on config values
  for caption, config in pairs(ShaguScan_db.config) do
    -- create root frame if not existing
    ui.frames[caption] = ui.frames[caption] or ui:CreateRoot(caption)
    local root = ui.frames[caption]

    -- ensure mouse state is correct if config changed
    if not root.shiftconf or root.shiftconf ~= config.shiftclick then
      root.shiftconf = config.shiftclick
      ui.UpdateMouseState(root)
    end

    -- skip if locked (due to moving)
    if root.lock then return end

    -- update position based on config
    if not root.pos or root.pos ~= config.anchor..config.x..config.y..config.scale then
      root.pos = config.anchor..config.x..config.y..config.scale
      root:ClearAllPoints()
      root:SetPoint(config.anchor, config.x, config.y)
      root:SetScale(config.scale)
    end

    -- update filter if required
    if not root.filter_conf or root.filter_conf ~= config.filter then
      -- prepare all filter texts and color modifiers
      local invalid
      root.filter, root.colors, invalid = utils.ParseFilterText(config.filter)

      for _, text in ipairs(invalid) do
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Shagu|cffffffffScanPlus:|cffffaaaa Unknown color in \"" ..
          caption .. "\": " .. text)
      end

      -- mark current state of data
      root.filter_conf = config.filter
    end

    -- run through all guids and fill with bars
    local title_size = 12 + config.spacing
    local width, height = config.width, config.height + title_size
    local x, y, count = 0, 0, 0
    for guid, time in pairs(ShaguScan.core.guids) do
      -- apply filters
      local visible = true
      for name, args in pairs(root.filter) do
        if filter[name] then
          visible = visible and filter[name](guid, args)
        end
      end

      -- display element if filters allow it
      if UnitExists(guid) and visible then
        count = count + 1

        if count > config.maxrow then
          count, x = 1, x + config.width + config.spacing
          width = math.max(x + config.width, width)
        end

        y = (count-1) * (config.height + config.spacing) + title_size
        height = math.max(y + config.height + config.spacing, height)

        root.frames[guid] = root.frames[guid] or root:CreateBar(guid)

        -- pick the first color modifier whose filters all match
        local color = nil
        for _, rule in ipairs(root.colors) do
          local match = true
          for _, sub in ipairs(rule.filters) do
            if filter[sub[1]] then
              match = match and filter[sub[1]](guid, sub[2])
            end
          end
          if match then
            color = rule
            break
          end
        end
        root.frames[guid].color = color

        -- update position if required
        if not root.frames[guid].pos or root.frames[guid].pos ~= x..-y then
          root.frames[guid]:ClearAllPoints()
          root.frames[guid]:SetPoint("TOPLEFT", root, "TOPLEFT", x, -y)
          root.frames[guid].pos = x..-y
        end

        -- update sizes if required
        if not root.frames[guid].sizes or root.frames[guid].sizes ~= config.width..config.height then
          root.frames[guid]:SetWidth(config.width)
          root.frames[guid]:SetHeight(config.height)
          root.frames[guid].sizes = config.width..config.height
        end

        root.frames[guid]:Show()
      elseif root.frames[guid] then
        root.frames[guid]:Hide()
        root.frames[guid] = nil
      end
    end

    -- update window size
    root:SetWidth(width)
    root:SetHeight(height)
  end
end)

ShaguScan.ui = ui
