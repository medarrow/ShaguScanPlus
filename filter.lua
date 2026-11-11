if ShaguScan.disabled then return end

local filter = { }

filter.player = function(unit)
  return UnitIsPlayer(unit) and true or false
end

filter.npc = function(unit)
  return not UnitIsPlayer(unit) and true or false
end

filter.infight = function(unit)
  return UnitAffectingCombat(unit) and true or false
end

filter.dead = function(unit)
  return UnitIsDead(unit) and true or false
end

filter.alive = function(unit)
  return not UnitIsDead(unit) and true or false
end

filter.horde = function(unit)
  return UnitFactionGroup(unit) == "Horde" and true or false
end

filter.alliance = function(unit)
  return UnitFactionGroup(unit) == "Alliance" and true or false
end

filter.hardcore = function(unit)
  return string.find((UnitPVPName(unit) or ""), "Still Alive") and true or false
end

filter.pve = function(unit)
  return not UnitIsPVP(unit) and true or false
end

filter.pvp = function(unit)
  return UnitIsPVP(unit) and true or false
end

filter.icon = function(unit)
  return GetRaidTargetIndex(unit) and true or false
end

filter.normal = function(unit)
  local elite = UnitClassification(unit)
  return elite == "normal" and true or false
end

filter.elite = function(unit)
  local elite = UnitClassification(unit)
  return (elite == "elite" or elite == "rareelite") and true or false
end

filter.rare = function(unit)
  local elite = UnitClassification(unit)
  return (elite == "rare" or elite == "rareelite") and true or false
end

filter.rareelite = function(unit)
  local elite = UnitClassification(unit)
  return elite == "rareelite" and true or false
end

filter.worldboss = function(unit)
  local elite = UnitClassification(unit)
  return elite == "worldboss" and true or false
end

filter.hostile = function(unit)
  return UnitIsEnemy("player", unit) and true or false
end

filter.neutral = function(unit)
  return not UnitIsEnemy("player", unit) and not UnitIsFriend("player", unit) and true or false
end

filter.friendly = function(unit)
  return UnitIsFriend("player", unit) and true or false
end

filter.attack = function(unit)
  return UnitCanAttack("player", unit) and true or false
end

filter.noattack = function(unit)
  return not UnitCanAttack("player", unit) and true or false
end

filter.pet = function(unit)
  local player = UnitIsPlayer(unit) and true or false
  local controlled = UnitPlayerControlled(unit) and true or false
  local pet = not player and controlled and true or false
  return pet and true or false
end

filter.nopet = function(unit)
  local player = UnitIsPlayer(unit) and true or false
  local controlled = UnitPlayerControlled(unit) and true or false
  local pet = not player and controlled and true or false
  return not pet and true or false
end

filter.human = function(unit)
  local _, race = UnitRace(unit)
  return race == "Human" and true or false
end

filter.orc = function(unit)
  local _, race = UnitRace(unit)
  return race == "Orc" and true or false
end

filter.dwarf = function(unit)
  local _, race = UnitRace(unit)
  return race == "Dwarf" and true or false
end

filter.nightelf = function(unit)
  local _, race = UnitRace(unit)
  return race == "NightElf" and true or false
end

filter.undead = function(unit)
  local _, race = UnitRace(unit)
  return race == "Scourge" and true or false
end

filter.tauren = function(unit)
  local _, race = UnitRace(unit)
  return race == "Tauren" and true or false
end

filter.gnome = function(unit)
  local _, race = UnitRace(unit)
  return race == "Gnome" and true or false
end

filter.troll = function(unit)
  local _, race = UnitRace(unit)
  return race == "Troll" and true or false
end

filter.goblin = function(unit)
  local _, race = UnitRace(unit)
  return race == "Goblin" and true or false
end

filter.highelf = function(unit)
  local _, race = UnitRace(unit)
  return race == "BloodElf" and true or false
end

filter.warlock = function(unit)
  local _, class = UnitClass(unit)
  local player = UnitIsPlayer(unit)

  return player and class == "WARLOCK" and true or false
end

filter.warrior = function(unit)
  local _, class = UnitClass(unit)
  local player = UnitIsPlayer(unit)

  return player and class == "WARRIOR" and true or false
end

filter.hunter = function(unit)
  local _, class = UnitClass(unit)
  local player = UnitIsPlayer(unit)

  return player and class == "HUNTER" and true or false
end

filter.mage = function(unit)
  local _, class = UnitClass(unit)
  local player = UnitIsPlayer(unit)

  return player and class == "MAGE" and true or false
end

filter.priest = function(unit)
  local _, class = UnitClass(unit)
  local player = UnitIsPlayer(unit)

  return player and class == "PRIEST" and true or false
end

filter.druid = function(unit)
  local _, class = UnitClass(unit)
  local player = UnitIsPlayer(unit)

  return player and class == "DRUID" and true or false
end

filter.paladin = function(unit)
  local _, class = UnitClass(unit)
  local player = UnitIsPlayer(unit)

  return player and class == "PALADIN" and true or false
end

filter.shaman = function(unit)
  local _, class = UnitClass(unit)
  local player = UnitIsPlayer(unit)

  return player and class == "SHAMAN" and true or false
end

filter.rogue = function(unit)
  local _, class = UnitClass(unit)
  local player = UnitIsPlayer(unit)

  return player and class == "ROGUE" and true or false
end

filter.aggro = function(unit)
  return UnitExists(unit .. "target") and UnitIsUnit(unit .. "target", "player") and true or false
end

filter.noaggro = function(unit)
  return not UnitExists(unit .. "target") or not UnitIsUnit(unit .. "target", "player") and true or false
end

filter.pfquest = function(unit)
  return pfQuest and pfMap and pfMap.tooltips and UnitName(unit) and pfMap.tooltips[UnitName(unit)] and true or false
end

filter.range = function(unit)
  return CheckInteractDistance(unit, 4) and true or false
end

local level = nil
filter.level = function(unit, args)
  level = tonumber(args)
  return level and UnitLevel(unit) == level and true or false
end

local level = nil
filter.minlevel = function(unit, args)
  level = tonumber(args)
  return level and UnitLevel(unit) >= level and true or false
end

local level = nil
filter.maxlevel = function(unit, args)
  level = tonumber(args)
  return level and UnitLevel(unit) <= level and true or false
end

filter.name = function(unit, name)
  -- "name" without text has no argument (true); match plain text, not patterns
  name = strlower(type(name) == "string" and name or "")
  unit = strlower(UnitName(unit) or "")
  return string.find(unit, name, 1, true) and true or false
end

local health, healthmax = nil, nil
filter.hurt = function(unit)
  health, healthmax = UnitHealth(unit), UnitHealthMax(unit)
  return healthmax and healthmax > 0 and health < healthmax and true or false
end

filter.unhurt = function(unit)
  health, healthmax = UnitHealth(unit), UnitHealthMax(unit)
  return healthmax and healthmax > 0 and health >= healthmax and true or false
end

-- UnitIsTappedByPlayer is true when you (or your group) tagged the unit,
-- UnitIsTapped is true when anyone tagged it.
filter.tagged = function(unit)
  return UnitIsTappedByPlayer(unit) and true or false
end

filter.notagged = function(unit)
  return not UnitIsTappedByPlayer(unit) and true or false
end

filter.othertagged = function(unit)
  return UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) and true or false
end

filter.noothertagged = function(unit)
  return not (UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit)) and true or false
end

-- Filters below require UnitXP SP3. UnitXP("nop", "nop") is its
-- documented presence check; it raises an error when unavailable.
local unitxp = type(UnitXP) == "function" and pcall(UnitXP, "nop", "nop") and true or false
ShaguScan.unitxp = unitxp

if unitxp then
  filter.inlos = function(unit)
    return UnitXP("inSight", "player", unit) and true or false
  end

  local distance, current = nil, nil
  filter.distance = function(unit, args)
    distance = tonumber(args)
    if not distance then return false end
    current = UnitXP("distanceBetween", "player", unit)
    return current and current <= distance and true or false
  end

  filter.imbehind = function(unit)
    return UnitXP("behind", "player", unit) and true or false
  end

  filter.imnotbehind = function(unit)
    return not UnitXP("behind", "player", unit) and true or false
  end

  filter.behindme = function(unit)
    return UnitXP("behind", unit, "player") and true or false
  end

  filter.notbehindme = function(unit)
    return not UnitXP("behind", unit, "player") and true or false
  end
else
  -- Leave these filters undefined so the UI skips them, and tell the
  -- player once the chat frame is ready.
  local notify = CreateFrame("Frame", nil, UIParent)
  notify:SetScript("OnUpdate", function()
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Shagu|cffffffffScanPlus:|cffffaaaa Couldn't detect UnitXP SP3. " ..
      "Filters disabled: inlos, distance, imbehind, imnotbehind, behindme, notbehindme.")
    this:Hide()
  end)
end

ShaguScan.filter = filter
