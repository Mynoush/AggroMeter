local addonName = ...
local ADDON_VERSION = "1.0.0"

local UPDATE_INTERVAL = 0.10
local DISPLAY_STAGES = 20
local DEFAULT_WIDTH = 116
local DEFAULT_HEIGHT = 8
local DEFAULT_MAX_MARGIN = 20

local COLOR_SAFE = { 0.15, 0.80, 0.25 }
local COLOR_CAUTION = { 1.00, 0.72, 0.10 }
local COLOR_DANGER = { 0.90, 0.18, 0.12 }
local COLOR_UNKNOWN = { 0.45, 0.55, 0.70 }

local TEXT_LIGHT = { 1.00, 1.00, 1.00 }

local MEDIA_PATH = "Interface\\AddOns\\" .. tostring(addonName or "AggroMeter") .. "\\"
local ADDON_ICON = MEDIA_PATH .. "Media\\Textures\\icon.tga"
local SOUND_SOFT = MEDIA_PATH .. "Sounds\\margin_soft.ogg"
local SOUND_MID = MEDIA_PATH .. "Sounds\\margin_mid.ogg"
local SOUND_DANGER = MEDIA_PATH .. "Sounds\\margin_danger.ogg"
local SOUND_STEALTH_NOTICE = MEDIA_PATH .. "Sounds\\stealth_notice.ogg"

local function SanitizeMediaPath(path)
    if type(path) ~= "string" then return path end
    local lower = path:lower()
    if lower:find("^interface\\addons\\aggrowarning") then
        local tail = path:match("^[^\\]+\\[^\\]+\\[^\\]+\\(.+)$")
        if tail then
            path = MEDIA_PATH .. tail
        end
    end
    if path:find("\\Platynator\\", 1, true) then
        path = path:gsub("\\Platynator\\", "\\Styles\\")
    end
    return path
end

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function AsBool(value, fallback)
    if IsSecret(value) then
        return fallback
    end
    if value == nil then
        return fallback
    end
    return value and true or false
end

local function Clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function Round(value)
    return math.floor(value + 0.5)
end

local function Lerp(a, b, t)
    t = Clamp(t or 0, 0, 1)
    return a + ((b - a) * t)
end

local function LerpColor(a, b, t)
    return Lerp(a[1], b[1], t), Lerp(a[2], b[2], t), Lerp(a[3], b[3], t)
end

local function SafeUnitName(unit)
    local name = UnitName(unit)
    if IsSecret(name) or type(name) ~= "string" then
        return nil
    end
    return name
end

local function SafeUnitIsDead(unit)
    if type(UnitIsDeadOrGhost) == "function" then
        local ok, dead = pcall(UnitIsDeadOrGhost, unit)
        if ok and not IsSecret(dead) and dead ~= nil then
            return dead and true or false
        end
    end

    if type(UnitIsDead) == "function" then
        local ok, dead = pcall(UnitIsDead, unit)
        if ok and not IsSecret(dead) and dead ~= nil then
            return dead and true or false
        end
    end

    if type(UnitHealth) == "function" then
        local ok, health = pcall(UnitHealth, unit)
        if ok and not IsSecret(health) and type(health) == "number" then
            return health <= 0
        end
    end

    return false
end

local function UnitHasThreatOnMob(memberUnit, mobUnit)
    if type(UnitThreatSituation) ~= "function" then return false end
    local ok, status = pcall(UnitThreatSituation, memberUnit, mobUnit)
    if ok and not IsSecret(status) and status ~= nil then
        return true
    end
    return false
end

local function SafeThreatState(unit)
    if type(UnitThreatSituation) ~= "function" then
        return false, nil, nil
    end

    local ok, status = pcall(UnitThreatSituation, "player", unit)
    if not ok or IsSecret(status) then
        return false, nil, nil
    end

    if status ~= nil then
        return true, true, status
    end

    if UnitExists("pet") and UnitHasThreatOnMob("pet", unit) then
        return true, true, 1
    end

    return true, false, nil
end

local function PlayerIsActiveAggroTargetInGroup(unit, threatStatus)
    local inGroup = (type(IsInGroup) == "function" and AsBool(IsInGroup(), false))
        or (type(IsInRaid) == "function" and AsBool(IsInRaid(), false))
    if not inGroup then return false end

    if type(threatStatus) == "number" and threatStatus >= 2 then
        return true
    end

    local targetUnit = unit .. "target"
    if UnitExists(targetUnit) and AsBool(UnitIsUnit(targetUnit, "player"), false) then
        if type(UnitAffectingCombat) == "function" then
            local ok, inCombat = pcall(UnitAffectingCombat, unit)
            if ok and not IsSecret(inCombat) and inCombat then
                return true
            end
        else
            return true
        end
    end

    return false
end

local function UnitInGroupCombat(unit)
    local targetUnit = unit .. "target"
    if UnitExists(targetUnit)
        and not AsBool(UnitIsUnit(targetUnit, "player"), false)
        and not AsBool(UnitIsUnit(targetUnit, "pet"), false) then
        if (type(UnitPlayerOrPetInParty) == "function" and AsBool(UnitPlayerOrPetInParty(targetUnit), false))
            or (type(UnitPlayerOrPetInRaid) == "function" and AsBool(UnitPlayerOrPetInRaid(targetUnit), false))
            or (type(UnitInParty) == "function" and AsBool(UnitInParty(targetUnit), false))
            or (type(UnitInRaid) == "function" and AsBool(UnitInRaid(targetUnit), false)) then
            return true
        end
    end

    if type(IsInRaid) == "function" and AsBool(IsInRaid(), false) then
        local n = (type(GetNumGroupMembers) == "function" and GetNumGroupMembers()) or 40
        for i = 1, n do
            local rUnit = "raid" .. i
            if UnitExists(rUnit) and not AsBool(UnitIsUnit(rUnit, "player"), false) then
                if UnitHasThreatOnMob(rUnit, unit) or UnitHasThreatOnMob("raidpet" .. i, unit) then
                    return true
                end
            end
        end
    elseif type(IsInGroup) == "function" and AsBool(IsInGroup(), false) then
        for i = 1, 4 do
            local pUnit = "party" .. i
            if UnitExists(pUnit) then
                if UnitHasThreatOnMob(pUnit, unit) or UnitHasThreatOnMob("partypet" .. i, unit) then
                    return true
                end
            end
        end
    end

    return false
end

local function UnitInOtherCombat(unit)
    if type(UnitIsTapDenied) == "function" then
        local ok, tapped = pcall(UnitIsTapDenied, unit)
        if ok and not IsSecret(tapped) and tapped then
            return true
        end
    end

    if type(UnitAffectingCombat) == "function" then
        local ok, inCombat = pcall(UnitAffectingCombat, unit)
        if ok and not IsSecret(inCombat) and inCombat then
            local _, selfActive = SafeThreatState(unit)
            if not selfActive and not UnitInGroupCombat(unit) then
                return true
            end
        end
    end

    return false
end

local function SafeUnitLevel(unit)
    local level = UnitLevel(unit)
    if IsSecret(level) or type(level) ~= "number" then
        return nil
    end
    return level
end

local function PlayerUsesStealthAggroModel()
    if type(UnitClass) ~= "function" or type(IsStealthed) ~= "function" then
        return false
    end

    local okClass, _, classFile = pcall(UnitClass, "player")
    if not okClass or IsSecret(classFile) or (classFile ~= "ROGUE" and classFile ~= "DRUID") then
        return false
    end

    local okStealth, stealthed = pcall(IsStealthed)
    if not okStealth or IsSecret(stealthed) then
        return false
    end

    return stealthed and true or false
end

local function NPCIDFromUnit(unit)
    local guid = UnitGUID(unit)
    if type(guid) ~= "string" or IsSecret(guid) then
        return nil
    end

    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then
        return nil
    end
    return tonumber(npcID)
end

local function ComputePullRadius(unit)
    local playerLevel = SafeUnitLevel("player")
    local mobLevel = SafeUnitLevel(unit)
    local uncertain = false
    local stealthModelActive = PlayerUsesStealthAggroModel()
    local baseRadius = stealthModelActive and 5 or 20
    local minimumRadius = stealthModelActive and 0 or 5

    if not playerLevel then
        return baseRadius, true, nil, nil
    end

    if not mobLevel then
        mobLevel = playerLevel
        uncertain = true
    elseif mobLevel < 0 then
        mobLevel = playerLevel + 10
        uncertain = true
    end

    local radius = Clamp(baseRadius + (mobLevel - playerLevel), minimumRadius, 45)
    local npcID = NPCIDFromUnit(unit)
    local override = npcID and AggroMeterOverrides and AggroMeterOverrides[npcID]

    if type(override) == "table" then
        if type(override.radius) == "number" then
            radius = Clamp(override.radius, 0, 100)
        elseif type(override.offset) == "number" then
            radius = Clamp(radius + override.offset, 0, 100)
        end
    end

    return radius, uncertain, npcID, override
end

-------------------------------------------------------------------------------
-- Distance brackets
-------------------------------------------------------------------------------

local HARM_ITEMS = {
    [5] = { 8149, 15826, 16308, 17117, 22259, 22432, 206466, 208760, 208855, 209027, 209057, 213036, 221199, 225943 },
    [10] = { 9606, 9618, 9619, 9620, 9621, 10699, 17626, 17689, 226472 },
    [15] = { 4559 },
    [20] = { 1191, 2012, 4388, 10645, 13892, 17757, 18209, 22048, 202251, 227936, 232344 },
    [25] = { 13289 },
    [30] = { 835, 1404, 1434, 1444, 1472, 1704, 1854, 1914, 1995, 2091, 3434, 3441, 4479, 4480, 4481, 4941, 5079, 5457, 6436, 7344, 7734, 9328, 9394, 10588, 10716, 10720, 11170, 11522, 11565, 12288, 12646, 12647, 13213, 13509, 13514, 17202, 17310, 20084, 20908, 21038, 21713, 22200, 22206, 22218, 220649, 228576, 233226 },
    [35] = { 1258, 1399, 1402, 8688, 18904, 220568, 233216 },
    [40] = { 4945, 8348, 191414, 208773, 208843, 209047 },
    [45] = { 221316 },
}

local itemForRange = {}
local itemRangeUnavailable = {}
local pendingItems = {}
local spellCheckers = {}
local checkerCache = nil
local tradeCheckBroken = false
local interactBlocked = false
local interactYards = { [3] = 8, [2] = 9, [4] = 28 }

local function ItemReady(itemID)
    if not (C_Item and C_Item.GetItemInfo) then
        return false
    end

    if C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(itemID) then
        return false
    end

    local ok, result = pcall(C_Item.GetItemInfo, itemID)
    return ok and result ~= nil
end

local function LoadRangeItems()
    if not (C_Item and C_Item.IsItemInRange) then
        return
    end

    for yards, ids in pairs(HARM_ITEMS) do
        if not itemForRange[yards] then
            itemRangeUnavailable[yards] = nil
            for _, itemID in ipairs(ids) do
                if ItemReady(itemID) then
                    itemForRange[yards] = itemID
                    break
                end
                if not pendingItems[itemID] then
                    pendingItems[itemID] = yards
                    if C_Item.RequestLoadItemDataByID then
                        pcall(C_Item.RequestLoadItemDataByID, itemID)
                    end
                end
            end
        end
    end
    checkerCache = nil
end

local function OnItemLoaded(itemID, success)
    local yards = pendingItems[itemID]
    if not yards then return end
    pendingItems[itemID] = nil

    if success then
        itemRangeUnavailable[yards] = nil
        if not itemForRange[yards] and ItemReady(itemID) then
            itemForRange[yards] = itemID
        end
        checkerCache = nil
    end
end

local function LoadSpellRangeChecks()
    wipe(spellCheckers)

    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and
            C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo and
            C_Spell and C_Spell.GetSpellInfo and C_Spell.IsSpellInRange) then
        checkerCache = nil
        return
    end

    local playerBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local seenRange = {}
    local okCount, numLines = pcall(C_SpellBook.GetNumSpellBookSkillLines)
    if not okCount or type(numLines) ~= "number" then
        checkerCache = nil
        return
    end

    for line = 1, numLines do
        local okLine, lineInfo = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
        if okLine and type(lineInfo) == "table" then
            local offset = tonumber(lineInfo.itemIndexOffset) or 0
            local count = tonumber(lineInfo.numSpellBookItems) or 0

            for slot = offset + 1, offset + count do
                local okItem, bookInfo = pcall(C_SpellBook.GetSpellBookItemInfo, slot, playerBank)
                if okItem and type(bookInfo) == "table" and type(bookInfo.spellID) == "number" and not bookInfo.isPassive and not bookInfo.isOffSpec then
                    local spellID = bookInfo.spellID
                    local harmful = true
                    if C_Spell.IsSpellHarmful then
                        local okHarm, isHarm = pcall(C_Spell.IsSpellHarmful, spellID)
                        harmful = okHarm and not IsSecret(isHarm) and isHarm == true
                    elseif C_SpellBook.IsSpellBookItemHarmful then
                        local okHarm, isHarm = pcall(C_SpellBook.IsSpellBookItemHarmful, slot, playerBank)
                        harmful = okHarm and not IsSecret(isHarm) and isHarm == true
                    end

                    if harmful then
                        local okSpell, spellInfo = pcall(C_Spell.GetSpellInfo, spellID)
                        if okSpell and type(spellInfo) == "table" then
                            local minRange = tonumber(spellInfo.minRange) or 0
                            local maxRange = tonumber(spellInfo.maxRange) or 0
                            if minRange <= 0 and maxRange > 0 and maxRange <= 100 then
                                local yards = Round(maxRange)
                                if not seenRange[yards] then
                                    spellCheckers[#spellCheckers + 1] = { yards = yards, spell = spellID }
                                    seenRange[yards] = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    checkerCache = nil
end

local function SetRaceInteractRanges()
    local _, race = UnitRace("player")
    if race == "Tauren" then
        interactYards = { [3] = 6, [2] = 7, [4] = 25 }
    elseif race == "Scourge" then
        interactYards = { [3] = 7, [2] = 8, [4] = 27 }
    else
        interactYards = { [3] = 8, [2] = 9, [4] = 28 }
    end
    checkerCache = nil
end

local function GetCheckers()
    if checkerCache then return checkerCache end

    local checkers = {}
    for yards, ids in pairs(HARM_ITEMS) do
        local itemID = itemForRange[yards]
        if itemID then
            checkers[#checkers + 1] = { yards = yards, item = itemID }
        elseif not itemRangeUnavailable[yards] then
            checkers[#checkers + 1] = { yards = yards, items = ids }
        end
    end

    for _, checker in ipairs(spellCheckers) do
        checkers[#checkers + 1] = checker
    end

    if CheckInteractDistance and not interactBlocked then
        for index, yards in pairs(interactYards) do
            if not (index == 2 and tradeCheckBroken) then
                checkers[#checkers + 1] = { yards = yards, interact = index }
            end
        end
    end

    table.sort(checkers, function(a, b)
        return a.yards < b.yards
    end)

    checkerCache = checkers
    return checkers
end

local function RunChecker(checker, unit)
    local ok, result

    if checker.item then
        if not (C_Item and C_Item.IsItemInRange) then return nil end
        ok, result = pcall(C_Item.IsItemInRange, checker.item, unit)
    elseif checker.items then
        if not (C_Item and C_Item.IsItemInRange) then return nil end
        local gotAnswer = false
        for _, itemID in ipairs(checker.items) do
            local itemOK, itemResult = pcall(C_Item.IsItemInRange, itemID, unit)
            if itemOK and not IsSecret(itemResult) and itemResult ~= nil then
                itemForRange[checker.yards] = itemID
                checkerCache = nil
                ok, result = true, itemResult
                gotAnswer = true
                break
            end
        end
        if not gotAnswer then
            itemRangeUnavailable[checker.yards] = true
            checkerCache = nil
            return nil
        end
    elseif checker.spell then
        if not (C_Spell and C_Spell.IsSpellInRange) then return nil end
        ok, result = pcall(C_Spell.IsSpellInRange, checker.spell, unit)
    else
        if not CheckInteractDistance then return nil end
        ok, result = pcall(CheckInteractDistance, unit, checker.interact)
    end

    if not ok then
        if checker.interact then
            interactBlocked = true
            checkerCache = nil
        end
        return nil
    end

    if IsSecret(result) then
        return nil
    end

    if checker.interact == 2 and result == false and not tradeCheckBroken then
        local duelOK, duel = pcall(CheckInteractDistance, unit, 3)
        if duelOK and not IsSecret(duel) and duel == true then
            tradeCheckBroken = true
            checkerCache = nil
            return nil
        end
    end

    return result and true or false
end

local function MeasureRangeBracket(unit)
    local low = 0
    local usedAny = false

    for _, checker in ipairs(GetCheckers()) do
        local result = RunChecker(checker, unit)
        if result ~= nil then
            usedAny = true
            if result then
                return low, checker.yards, true
            end
            low = checker.yards
        end
    end

    if usedAny and low > 0 then
        return low, nil, true
    end

    return nil, nil, false
end

-------------------------------------------------------------------------------
-- Nameplate UI
-------------------------------------------------------------------------------

local plateRows = {}
local activeRows = {}
local visiblePlateUnits = {}

local defaults = {
    enabled = true,
    showText = true,
    statusText = false,
    warningEnabled = true,
    alertsEnabled = true,
    soundEnabled = true,
    pullAlertEnabled = true,
    stealthNoticeEnabled = true,
    alertButtonPoint = "CENTER",
    alertButtonRelativePoint = "CENTER",
    alertButtonX = 145,
    alertButtonY = -155,
    scale = 1.0,
    width = DEFAULT_WIDTH,
    height = DEFAULT_HEIGHT,
    maxMargin = DEFAULT_MAX_MARGIN,
    offsetY = -5,
    fontSize = 10,
    fontPath = STANDARD_TEXT_FONT,
    fontOutline = true,
    fontBold = false,
    fontShadow = true,
    fontMonochrome = false,
    invertBar = false,
    aggroGraphic = true,
    hideInCombatSelf = true,
    hideInCombatGroup = true,
    hideInCombatOther = true,
    keepGroupAggro = true,
    smoothBar = true,
    fadeNonTarget = false,
    hideFarMobs = false,
    barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
    showFloatingButton = true,
    showMinimapButton = true,
    minimapAngle = 220,
    updateRate = 25,
    unitSystem = "yards",
    language = "en",
}

local function CopyDefaults(source, target)
    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = value
        end
    end
end

local db
local ToggleConfigFrame

-------------------------------------------------------------------------------
-- Localization
-------------------------------------------------------------------------------

local STRINGS = {
    en = {
        -- Config window & Tabs
        CONFIG_TITLE         = "AggroMeter - Settings",
        TAB_APPEARANCE       = "Appearance",
        TAB_ALERTS           = "Alerts & Text",
        TAB_VISIBILITY       = "Visibility",
        -- Section Headers
        SEC_DIMENSIONS       = "Dimensions & Update Speed",
        SEC_STYLE            = "Bar Texture & Typography",
        SEC_BARTEXT          = "General & Bar Text",
        SEC_SCREENALERTS     = "Screen & Sound Warnings",
        SEC_BARAGGRO         = "Nameplate Pull Indicator",
        SEC_COMBATHIDE       = "Hide Bar During Combat",
        SEC_DECLUTTER        = "Screen Declutter & Focus",
        -- Slider labels & tooltips
        SLIDER_OFFSETY       = "Vertical Offset (Y)",
        DESC_OFFSETY         = "Moves the aggro bar up or down relative to the enemy nameplate.",
        SLIDER_FONTSIZE      = "Font Size",
        DESC_FONTSIZE        = "Adjusts the text size inside the aggro bar.",
        SLIDER_WIDTH         = "Bar Width",
        DESC_WIDTH           = "Adjusts the horizontal width of the aggro bar.",
        SLIDER_HEIGHT        = "Bar Height",
        DESC_HEIGHT          = "Adjusts the vertical thickness of the aggro bar.",
        SLIDER_SCALE         = "Bar Scale",
        DESC_SCALE           = "Multiplies the overall size of the bar and its text.",
        SLIDER_UPDATERATE    = "Update Rate",
        DESC_UPDATERATE      = "How many times per second distance checks run. Higher values react faster.",
        -- Font & Texture section
        FONT_LABEL           = "Bar Font:",
        FONT_SELECT_BTN      = "Font: %s",
        DESC_FONT_SELECT     = "Click to choose the font used on the bar, or use < and > to cycle.",
        TEX_SELECT_BTN       = "Bar Texture: %s",
        DESC_TEX_SELECT      = "Click to choose the status bar fill texture, or use < and > to cycle.",
        TEX_DEFAULT          = "Default (Blizzard)",
        FONT_STYLE_LABEL     = "Text Style:",
        STYLE_OUTLINE        = "Outline",
        DESC_STYLE_OUTLINE   = "Adds a thin black border around letters for readability.",
        STYLE_BOLD           = "Bold",
        DESC_STYLE_BOLD      = "Uses a thick outline around letters to make the text bolder.",
        STYLE_SHADOW         = "Shadow",
        DESC_STYLE_SHADOW    = "Renders a subtle drop shadow behind the bar text.",
        STYLE_MONO           = "Mono",
        DESC_STYLE_MONO      = "Renders crisp pixel-aligned text without anti-aliasing.",
        FONT_APPLY           = "Apply",
        FONT_DEFAULT         = "Default (Friz Quadrata)",
        -- Toggle buttons
        BTN_UNIT_TO_METERS   = "Unit: Yards (Click for Meters)",
        BTN_UNIT_TO_YARDS    = "Unit: Meters (Click for Yards)",
        DESC_BTN_UNIT        = "Switches all distance displays between Yards (yd) and Meters (M).",
        BTN_LANG             = "Language: EN (Mudar p/ PT)",
        DESC_BTN_LANG        = "Switches all addon menus and bar labels between English and Portuguese.",
        -- Bottom buttons
        BTN_RESET            = "Reset Defaults",
        DESC_BTN_RESET       = "Restores all sliders, fonts, textures, and options to their default values.",
        BTN_CLOSE            = "Close",
        -- Checkboxes & descriptions
        CHECK_ENABLED        = "Enable Addon",
        DESC_ENABLED         = "Master switch. Enables or disables all aggro bars and warnings.",
        CHECK_SHOWTEXT       = "Show Distance Text",
        DESC_SHOWTEXT        = "Displays remaining safety margin and estimated aggro radius on the bar.",
        CHECK_STATUSTEXT     = "Show State Prefix (SAFE / CAUTION)",
        DESC_STATUSTEXT      = "Adds SAFE or CAUTION before the distance numbers on the bar.",
        CHECK_WARNING        = "5m Proximity Warning (Target)",
        DESC_WARNING         = "Shows a raid-style warning and sound when your current target is within 5m of pulling.",
        CHECK_PULLALERT      = "Screen Pull Alert (AGGRO!)",
        DESC_PULLALERT       = "Flashes 'AGGRO! - Mob Name' in the center of the screen when you pull a mob.",
        CHECK_STEALTH        = "Stealth Detection Warning (!)",
        DESC_STEALTH         = "For Rogues/Druids in stealth: flashes a red '!' before entering a mob's detection radius.",
        CHECK_INVERTBAR      = "Fill Bar on Danger",
        DESC_INVERTBAR       = "Inverts the bar: starts empty when safe and fills up in red as you get closer to pulling.",
        CHECK_AGGROGRAPHIC   = "Flash AGGRO! on Bar (2.2s)",
        DESC_AGGROGRAPHIC    = "Temporarily flashes red circles and 'AGGRO!' inside the bar when a mob aggros you.",
        CHECK_KEEPGROUPAGGRO = "Keep AGGRO! on Bar in Group",
        DESC_KEEPGROUPAGGRO  = "In party/raid, keeps the red 'AGGRO!' bar visible for as long as that mob is targeting you.",
        CHECK_HIDESELF       = "Hide Bar in My Combat",
        DESC_HIDESELF        = "Hides the distance bar once you (or your pet) are already fighting that enemy.",
        CHECK_HIDEGROUP      = "Hide Bar in Group Combat",
        DESC_HIDEGROUP       = "Hides the bar if anyone in your party or raid is already in combat with that enemy.",
        CHECK_HIDEOTHER      = "Hide Bar in Others' Combat",
        DESC_HIDEOTHER       = "Hides the bar if another player outside your group has already pulled or tapped that enemy.",
        CHECK_SMOOTHBAR      = "Smooth Bar Motion",
        DESC_SMOOTHBAR       = "Smoothly glides the bar fill and color instead of jumping in discrete steps.",
        CHECK_FADENONTAR     = "Focus on Target (Dim Others)",
        DESC_FADENONTAR      = "Keeps your target, mouseover, and DANGER mobs at 100% opacity while dimming other mobs to 55%.",
        CHECK_HIDEFAR        = "Hide Far Safe Mobs",
        DESC_HIDEFAR         = "Hides the bar on enemies that are very far away (>20m safety margin), showing it only as you approach.",
        CHECK_SOUND          = "Enable Warning Sounds",
        DESC_SOUND           = "Plays audio cues when approaching aggro range (5m) or when stealth detection triggers.",
        CHECK_MINIMAPBTN     = "Show Minimap Button",
        DESC_MINIMAPBTN      = "Displays the AggroMeter button around the edge of your Minimap.",
        CHECK_FLOATBTN       = "Show Floating Screen Button",
        DESC_FLOATBTN        = "Displays the compact draggable quick-access button on your screen.",
        -- Quick button & minimap tooltip
        TIP_TITLE            = "AggroMeter",
        TIP_STATUS_ON        = "Status: ENABLED",
        TIP_STATUS_OFF       = "Status: DISABLED",
        TIP_LCLICK_CONFIG    = "Left-Click: Open Settings",
        TIP_RCLICK_TOGGLE    = "Right-Click: Enable / Disable Addon",
        TIP_DRAG             = "Drag: Move button",
        -- Distance unit labels
        UNIT_M               = "M",
        UNIT_YD              = "yd",
        LABEL_RANGE          = "Range",
        TEXT_ZERO_RANGE      = "DANGER",
        -- Login message
        LOGIN                = "v%s loaded (by Mynou). Enemy nameplates must be enabled. /am config",
    },
    pt = {
        -- Config window & Tabs
        CONFIG_TITLE         = "AggroMeter - Configura\195\167\195\181es",
        TAB_APPEARANCE       = "Apar\195\170ncia",
        TAB_ALERTS           = "Alertas e Texto",
        TAB_VISIBILITY       = "Visibilidade",
        -- Section Headers
        SEC_DIMENSIONS       = "Dimens\195\181es e Velocidade",
        SEC_STYLE            = "Textura e Tipografia",
        SEC_BARTEXT          = "Geral e Texto da Barra",
        SEC_SCREENALERTS     = "Avisos na Tela e Som",
        SEC_BARAGGRO         = "Indicador de Aggro na Barra",
        SEC_COMBATHIDE       = "Ocultar Barra em Combate",
        SEC_DECLUTTER        = "Limpeza Visual e Foco",
        -- Slider labels & tooltips
        SLIDER_OFFSETY       = "Posi\195\167\195\163o Vertical (Y)",
        DESC_OFFSETY         = "Move a barra de aggro para cima ou para baixo em rela\195\167\195\163o ao nameplate do inimigo.",
        SLIDER_FONTSIZE      = "Tamanho da Fonte",
        DESC_FONTSIZE        = "Ajusta o tamanho do texto exibido dentro da barra.",
        SLIDER_WIDTH         = "Largura da Barra",
        DESC_WIDTH           = "Ajusta a largura horizontal da barra de aggro.",
        SLIDER_HEIGHT        = "Altura da Barra",
        DESC_HEIGHT          = "Ajusta a espessura vertical da barra de aggro.",
        SLIDER_SCALE         = "Escala Geral",
        DESC_SCALE           = "Multiplica o tamanho total da barra e de seus elementos.",
        SLIDER_UPDATERATE    = "Taxa de Leitura",
        DESC_UPDATERATE      = "Quantas vezes por segundo a dist\195\162ncia \195\169 verificada. Valores maiores reagem mais r\195\161pido.",
        -- Font & Texture section
        FONT_LABEL           = "Fonte da Barra:",
        FONT_SELECT_BTN      = "Fonte: %s",
        DESC_FONT_SELECT     = "Clique para abrir a lista de fontes ou use < e > para alternar rapidamente.",
        TEX_SELECT_BTN       = "Textura: %s",
        DESC_TEX_SELECT      = "Clique para escolher a textura de preenchimento da barra ou use < e >.",
        TEX_DEFAULT          = "Padr\195\163o (Blizzard)",
        FONT_STYLE_LABEL     = "Estilo do Texto:",
        STYLE_OUTLINE        = "Contorno",
        DESC_STYLE_OUTLINE   = "Adiciona uma borda preta fina ao redor das letras para facilitar a leitura.",
        STYLE_BOLD           = "Negrito",
        DESC_STYLE_BOLD      = "Aplica um contorno espesso deixando o texto mais forte e destacado.",
        STYLE_SHADOW         = "Sombra",
        DESC_STYLE_SHADOW    = "Desenha uma sombra suave atr\195\161s do texto da barra.",
        STYLE_MONO           = "Mono",
        DESC_STYLE_MONO      = "Renderiza o texto alinhado aos pixels, sem suaviza\195\167\195\163o de borda.",
        FONT_APPLY           = "Aplicar",
        FONT_DEFAULT         = "Padr\195\163o (Friz Quadrata)",
        -- Toggle buttons
        BTN_UNIT_TO_METERS   = "Unidade: Jardas (Usar Metros)",
        BTN_UNIT_TO_YARDS    = "Unidade: Metros (Usar Jardas)",
        DESC_BTN_UNIT        = "Alterna todas as medidas de dist\195\162ncia entre Metros (M) e Jardas (jd).",
        BTN_LANG             = "Idioma: PT (Switch to EN)",
        DESC_BTN_LANG        = "Alterna todos os textos do menu e das barras entre Portugu\195\170s e Ingl\195\170s.",
        -- Bottom buttons
        BTN_RESET            = "Restaurar Padr\195\181es",
        DESC_BTN_RESET       = "Restaura todas as medidas, fontes, texturas e op\195\167\195\181es para os valores originais.",
        BTN_CLOSE            = "Fechar",
        -- Checkboxes & descriptions
        CHECK_ENABLED        = "Ativar Addon",
        DESC_ENABLED         = "Chave geral. Ativa ou desativa todas as barras e alertas do addon.",
        CHECK_SHOWTEXT       = "Mostrar Dist\195\162ncia na Barra",
        DESC_SHOWTEXT        = "Exibe a margem restante at\195\169 puxar aggro e a dist\195\162ncia estimada (Dist.) na barra.",
        CHECK_STATUSTEXT     = "Exibir Prefixo (SAFE / CAUTION)",
        DESC_STATUSTEXT      = "Adiciona a palavra SAFE ou CAUTION antes dos n\195\186meros de dist\195\162ncia na barra.",
        CHECK_WARNING        = "Aviso de Aproxima\195\167\195\163o (5m do Alvo)",
        DESC_WARNING         = "Exibe um alerta central e som quando voc\195\170 chega a 5m ou menos de puxar o seu alvo atual.",
        CHECK_PULLALERT      = "Alerta de Aggro na Tela",
        DESC_PULLALERT       = "Exibe 'AGGRO! - Nome do Mob' no centro da tela no instante em que um inimigo vira em voc\195\170.",
        CHECK_STEALTH        = "Alerta de Detec\195\167\195\163o em Stealth (!)",
        DESC_STEALTH         = "Para Ladinos/Druidas furtivos: exibe um '!' vermelho ao entrar na zona de detec\195\167\195\163o do inimigo.",
        CHECK_INVERTBAR      = "Encher Barra ao Aproximar",
        DESC_INVERTBAR       = "Inverte o preenchimento: a barra fica vazia quando seguro e enche em vermelho conforme o perigo aumenta.",
        CHECK_AGGROGRAPHIC   = "Piscar AGGRO! na Barra (2.2s)",
        DESC_AGGROGRAPHIC    = "Mostra c\195\173rculos vermelhos e 'AGGRO!' piscando na barra por 2.2s quando o mob \195\169 puxado.",
        CHECK_KEEPGROUPAGGRO = "Fixar AGGRO! em Mim (Grupo/Raid)",
        DESC_KEEPGROUPAGGRO  = "Em grupo ou raid, mant\195\169m a barra vermelha 'AGGRO!' acesa enquanto o inimigo estiver virado em voc\195\170.",
        CHECK_HIDESELF       = "Ocultar no Meu Combate",
        DESC_HIDESELF        = "Esconde a barra de dist\195\162ncia assim que voc\195\170 (ou seu pet) j\195\161 estiver lutando contra aquele inimigo.",
        CHECK_HIDEGROUP      = "Ocultar no Combate do Grupo",
        DESC_HIDEGROUP       = "Esconde a barra se qualquer membro do seu grupo ou raid j\195\161 estiver em combate com aquele inimigo.",
        CHECK_HIDEOTHER      = "Ocultar no Combate de Terceiros",
        DESC_HIDEOTHER       = "Esconde a barra se outro jogador fora do seu grupo j\195\161 tiver puxado ou marcado aquele inimigo.",
        CHECK_SMOOTHBAR      = "Anima\195\167\195\163o Suave da Barra",
        DESC_SMOOTHBAR       = "Faz a barra e suas cores deslizarem suavemente em vez de pular em degraus secos.",
        CHECK_FADENONTAR     = "Destacar Apenas o Alvo (55%)",
        DESC_FADENONTAR      = "Mant\195\169m seu alvo, mouseover e mobs em PERIGO em 100% de opacidade, reduzindo os demais para 55%.",
        CHECK_HIDEFAR        = "Ocultar Mobs Muito Distantes",
        DESC_HIDEFAR         = "Esconde a barra de inimigos que est\195\163o longe e seguros (>20m de margem), mostrando s\195\179 ao se aproximar.",
        CHECK_SOUND          = "Ativar Sons de Alerta",
        DESC_SOUND           = "Toca efeitos sonoros ao entrar na zona de aviso (5m) ou no alerta de detec\195\167\195\163o em stealth.",
        CHECK_MINIMAPBTN     = "Mostrar Bot\195\163o no Minimapa",
        DESC_MINIMAPBTN      = "Exibe o \195\173cone padr\195\163o do addon acoplado \195\160 borda do seu Minimapa.",
        CHECK_FLOATBTN       = "Mostrar Bot\195\163o Flutuante",
        DESC_FLOATBTN        = "Exibe o pequeno bot\195\163o discreto de acesso r\195\161pido na tela.",
        TIP_TITLE            = "AggroMeter",
        TIP_STATUS_ON        = "Status: ATIVADO",
        TIP_STATUS_OFF       = "Status: DESATIVADO",
        TIP_LCLICK_CONFIG    = "Clique-Esq: Abrir Configura\195\167\195\181es",
        TIP_RCLICK_TOGGLE    = "Clique-Dir: Ativar / Desativar Addon",
        TIP_DRAG             = "Arraste: Mover bot\195\163o",
        UNIT_M               = "M",
        UNIT_YD              = "jd",
        LABEL_RANGE          = "Dist.",
        TEXT_ZERO_RANGE      = "PERIGO",
        LOGIN                = "v%s carregado (por Mynou). Nameplates inimigas devem estar ativas. /am config",
    },
}

local L = STRINGS.en  -- default; updated by ApplyLanguage() after db loads

local function ApplyLanguage()
    local lang = (db and db.language) or "en"
    L = STRINGS[lang] or STRINGS.en
end

-------------------------------------------------------------------------------
-- Quick-Access Floating Button & Minimap Button
-------------------------------------------------------------------------------

local alertControlFrame
local alertControlButton
local minimapButton
local configFrame
local RefreshAllPlates
local ResetProximityAlertState
local ResetStealthNoticeState

local function AlertModeName()
    if not db or not db.alertsEnabled then return "OFF" end
    if db.soundEnabled then return "ON" end
    return "ICON"
end

local function UpdateAlertControlButton()
    if not db then return end

    if alertControlFrame and alertControlButton then
        alertControlFrame:SetShown(db.showFloatingButton ~= false)
        local isEnabled = db.enabled ~= false
        if isEnabled then
            alertControlButton.border:SetColorTexture(0.28, 0.34, 0.42, 0.90)
            alertControlButton.fill:SetColorTexture(0.07, 0.08, 0.11, 0.85)
            alertControlButton.icon:SetDesaturated(false)
            alertControlButton.icon:SetVertexColor(1.0, 1.0, 1.0, 0.95)
            alertControlButton.dot:SetTexture("Interface\\COMMON\\Indicator-Green")
        else
            alertControlButton.border:SetColorTexture(0.22, 0.22, 0.24, 0.75)
            alertControlButton.fill:SetColorTexture(0.05, 0.05, 0.06, 0.75)
            alertControlButton.icon:SetDesaturated(true)
            alertControlButton.icon:SetVertexColor(0.55, 0.55, 0.55, 0.80)
            alertControlButton.dot:SetTexture("Interface\\COMMON\\Indicator-Red")
        end
    end

    if minimapButton then
        minimapButton:SetShown(db.showMinimapButton ~= false)
        local isEnabled = db.enabled ~= false
        if isEnabled then
            minimapButton.icon:SetDesaturated(false)
            minimapButton.icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
            minimapButton.dot:SetTexture("Interface\\COMMON\\Indicator-Green")
        else
            minimapButton.icon:SetDesaturated(true)
            minimapButton.icon:SetVertexColor(0.55, 0.55, 0.55, 0.85)
            minimapButton.dot:SetTexture("Interface\\COMMON\\Indicator-Red")
        end
    end
end

local function SetAlertMode(mode, announce)
    if not db then return end

    mode = (mode or ""):lower()
    if mode == "all" or mode == "on" or mode == "sound" then
        db.alertsEnabled = true
        db.soundEnabled = true
    elseif mode == "icon" or mode == "visual" or mode == "silent" then
        db.alertsEnabled = true
        db.soundEnabled = false
    elseif mode == "off" or mode == "none" then
        db.alertsEnabled = false
        db.soundEnabled = false
    else
        return false
    end

    UpdateAlertControlButton()
    if announce and DEFAULT_CHAT_FRAME then
        local state = AlertModeName()
        local message
        if state == "ON" then
            message = "alerts ON (sound + visual)"
        elseif state == "ICON" then
            message = "alerts ICON ONLY (visual, no sound)"
        else
            message = "alerts OFF"
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff62d8ffAggroMeter:|r " .. message)
    end
    return true
end

local function ToggleAddonEnabled()
    if not db then return end
    db.enabled = not db.enabled
    db.alertsEnabled = true
    if ResetProximityAlertState then ResetProximityAlertState() end
    if ResetStealthNoticeState then ResetStealthNoticeState() end
    if RefreshAllPlates then RefreshAllPlates() end
    UpdateAlertControlButton()
    if configFrame and configFrame:IsShown() and configFrame.Refresh then
        configFrame:Refresh()
    end
end

_G.AggroMeter_OnAddonCompartmentClick = function(_, buttonName)
    if buttonName == "RightButton" then
        ToggleAddonEnabled()
    elseif ToggleConfigFrame then
        ToggleConfigFrame()
    end
end

local function ShowQuickButtonTooltip(owner, anchor)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_TOP")
    GameTooltip:AddLine(L.TIP_TITLE or "AggroMeter", 1.00, 0.82, 0.00)
    if db and db.enabled then
        GameTooltip:AddLine(L.TIP_STATUS_ON, 0.40, 0.95, 0.50)
    else
        GameTooltip:AddLine(L.TIP_STATUS_OFF, 0.95, 0.35, 0.35)
    end
    GameTooltip:AddLine(L.TIP_LCLICK_CONFIG, 0.50, 0.85, 1.00)
    GameTooltip:AddLine(L.TIP_RCLICK_TOGGLE, 0.85, 0.88, 0.92)
    GameTooltip:AddLine(L.TIP_DRAG, 0.65, 0.68, 0.72)
    GameTooltip:Show()
end

local function SaveAlertControlPosition()
    if not alertControlFrame or not db then return end
    local point, _, relativePoint, x, y = alertControlFrame:GetPoint(1)
    db.alertButtonPoint = point or "CENTER"
    db.alertButtonRelativePoint = relativePoint or "CENTER"
    db.alertButtonX = x or 0
    db.alertButtonY = y or 0
end

local function UpdateMinimapButtonPosition()
    if not minimapButton or not Minimap or not db then return end
    local angle = math.rad(db.minimapAngle or 220)
    local w = (Minimap:GetWidth() or 140) / 2 + 6
    local h = (Minimap:GetHeight() or 140) / 2 + 6
    local x = math.cos(angle) * w
    local y = math.sin(angle) * h
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
    if minimapButton or not Minimap or not db then
        UpdateMinimapButtonPosition()
        UpdateAlertControlButton()
        return
    end

    local btn = CreateFrame("Button", "AggroMeterMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel((Minimap:GetFrameLevel() or 2) + 8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(24, 24)
    bg:SetPoint("CENTER", btn, "CENTER", 0, 1)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetVertexColor(0.08, 0.08, 0.10, 0.90)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 1)
    icon:SetTexture(ADDON_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local dot = btn:CreateTexture(nil, "OVERLAY")
    dot:SetSize(10, 10)
    dot:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
    dot:SetTexture("Interface\\COMMON\\Indicator-Green")
    btn.dot = dot

    btn:SetScript("OnClick", function(self, mouseButton)
        if self.suppressClick then return end
        if mouseButton == "RightButton" then
            ToggleAddonEnabled()
            if GameTooltip and GameTooltip:IsOwned(self) then
                ShowQuickButtonTooltip(self, "ANCHOR_LEFT")
            end
        else
            if ToggleConfigFrame then ToggleConfigFrame() end
        end
    end)

    btn:SetScript("OnDragStart", function(self)
        self.suppressClick = true
        self:SetScript("OnUpdate", function()
            if not Minimap then return end
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale() or 1
            cx, cy = cx / scale, cy / scale
            if mx and my then
                db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
                UpdateMinimapButtonPosition()
            end
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if C_Timer and C_Timer.After then
            C_Timer.After(0.10, function() self.suppressClick = nil end)
        else
            self.suppressClick = nil
        end
    end)

    btn:SetScript("OnEnter", function(self)
        ShowQuickButtonTooltip(self, "ANCHOR_LEFT")
    end)
    btn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    minimapButton = btn
    UpdateMinimapButtonPosition()
end

local function CreateAlertControl()
    if not db then return end
    -- Ensure alertsEnabled is not stuck off from legacy 3-state button
    db.alertsEnabled = true

    CreateMinimapButton()

    if alertControlFrame then
        UpdateAlertControlButton()
        return
    end

    alertControlFrame = CreateFrame("Frame", "AggroMeterAlertControlFrame", UIParent)
    alertControlFrame:SetSize(28, 28)
    alertControlFrame:SetMovable(true)
    alertControlFrame:SetClampedToScreen(true)
    alertControlFrame:ClearAllPoints()
    alertControlFrame:SetPoint(
        db.alertButtonPoint or "CENTER",
        UIParent,
        db.alertButtonRelativePoint or "CENTER",
        db.alertButtonX or 145,
        db.alertButtonY or -155
    )

    alertControlButton = CreateFrame("Button", "AggroMeterAlertControlButton", alertControlFrame)
    alertControlButton:SetAllPoints(alertControlFrame)
    alertControlButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    alertControlButton:RegisterForDrag("LeftButton")
    alertControlButton:SetAlpha(0.65)

    alertControlButton.border = alertControlButton:CreateTexture(nil, "BACKGROUND")
    alertControlButton.border:SetAllPoints(alertControlButton)

    alertControlButton.fill = alertControlButton:CreateTexture(nil, "BORDER")
    alertControlButton.fill:SetPoint("TOPLEFT", alertControlButton, "TOPLEFT", 1, -1)
    alertControlButton.fill:SetPoint("BOTTOMRIGHT", alertControlButton, "BOTTOMRIGHT", -1, 1)

    alertControlButton.icon = alertControlButton:CreateTexture(nil, "ARTWORK")
    alertControlButton.icon:SetPoint("TOPLEFT", alertControlButton, "TOPLEFT", 3, -3)
    alertControlButton.icon:SetPoint("BOTTOMRIGHT", alertControlButton, "BOTTOMRIGHT", -3, 3)
    alertControlButton.icon:SetTexture(ADDON_ICON)
    alertControlButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    alertControlButton.hl = alertControlButton:CreateTexture(nil, "HIGHLIGHT")
    alertControlButton.hl:SetPoint("TOPLEFT", alertControlButton, "TOPLEFT", 1, -1)
    alertControlButton.hl:SetPoint("BOTTOMRIGHT", alertControlButton, "BOTTOMRIGHT", -1, 1)
    alertControlButton.hl:SetColorTexture(0.45, 0.75, 1.00, 0.18)

    alertControlButton.dot = alertControlButton:CreateTexture(nil, "OVERLAY")
    alertControlButton.dot:SetSize(9, 9)
    alertControlButton.dot:SetPoint("BOTTOMRIGHT", alertControlButton, "BOTTOMRIGHT", 1, -1)
    alertControlButton.dot:SetTexture("Interface\\COMMON\\Indicator-Green")

    alertControlButton:SetScript("OnClick", function(self, mouseButton)
        if self.suppressClick or not db then return end
        if mouseButton == "RightButton" then
            ToggleAddonEnabled()
            if GameTooltip and GameTooltip:IsOwned(self) then
                ShowQuickButtonTooltip(self, "ANCHOR_TOP")
            end
        else
            if ToggleConfigFrame then
                ToggleConfigFrame()
            end
        end
    end)

    alertControlButton:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton ~= "LeftButton" then return end
        self:SetScale(0.95)
    end)

    alertControlButton:SetScript("OnMouseUp", function(self)
        self:SetScale(1.00)
    end)

    alertControlButton:SetScript("OnDragStart", function(self)
        self:SetScale(1.00)
        self.suppressClick = true
        alertControlFrame:StartMoving()
    end)

    alertControlButton:SetScript("OnDragStop", function(self)
        alertControlFrame:StopMovingOrSizing()
        SaveAlertControlPosition()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.10, function() self.suppressClick = nil end)
        else
            self.suppressClick = nil
        end
    end)

    alertControlButton:SetScript("OnEnter", function(self)
        self:SetAlpha(1.00)
        ShowQuickButtonTooltip(self, "ANCHOR_TOP")
    end)
    alertControlButton:SetScript("OnLeave", function(self)
        self:SetAlpha(0.65)
        if GameTooltip then GameTooltip:Hide() end
    end)

    UpdateAlertControlButton()
end

local function EvaluateHostility(unit)
    if AsBool(UnitIsUnit(unit, "player"), false) then
        return false, "self"
    end

    local exists = UnitExists(unit)
    if IsSecret(exists) or not exists then
        return false, "missing"
    end

    if SafeUnitIsDead(unit) then
        return false, "dead"
    end

    local attackable = UnitCanAttack("player", unit)
    if IsSecret(attackable) then
        return true, "attackability-secret"
    end
    if not attackable then
        return false, "not-attackable"
    end

    local enemy
    if type(UnitIsEnemy) == "function" then
        local ok, value = pcall(UnitIsEnemy, "player", unit)
        if ok and not IsSecret(value) then
            enemy = value and true or false
            if enemy then
                return true, "UnitIsEnemy"
            end
        end
    end

    local reaction
    if type(UnitReaction) == "function" then
        local ok, value = pcall(UnitReaction, "player", unit)
        if ok and not IsSecret(value) and type(value) == "number" then
            reaction = value
            if value <= 3 then
                return true, "UnitReaction=" .. tostring(value)
            end
        end
    end

    local selectionType
    if type(UnitSelectionType) == "function" then
        local ok, value = pcall(UnitSelectionType, unit, true)
        if ok and not IsSecret(value) and type(value) == "number" then
            selectionType = value
            if value == 0 or value == 1 then
                return true, "UnitSelectionType=" .. tostring(value)
            end
        end
    end

    if enemy == false then
        return false, "UnitIsEnemy=false"
    end
    if reaction ~= nil or selectionType ~= nil then
        return false, "neutral/friendly"
    end

    return true, "attackable-fallback"
end

local function UnitIsHostileMob(unit)
    local tracked = EvaluateHostility(unit)
    return tracked
end

local function PlateAnchor(plate)
    local unitFrame = plate.UnitFrame
    if unitFrame and not unitFrame:IsForbidden() and unitFrame.healthBar then
        return unitFrame.healthBar
    end
    return plate
end

local function BuildFontFlags()
    if not db then return "OUTLINE" end
    local parts = {}
    if db.fontMonochrome then
        parts[#parts + 1] = "MONOCHROME"
    end
    if db.fontBold then
        parts[#parts + 1] = "THICKOUTLINE"
    elseif db.fontOutline ~= false then
        parts[#parts + 1] = "OUTLINE"
    end
    return table.concat(parts, ",")
end

local DEFAULT_BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

local function ApplyRowTexture(row)
    if not row or not row.bar then return end
    local tex = (db and db.barTexture) or DEFAULT_BAR_TEXTURE
    if type(tex) == "string" and tex:find("\\Platynator\\", 1, true) then
        tex = tex:gsub("\\Platynator\\", "\\Styles\\")
        if db then db.barTexture = tex end
    end
    local ok = pcall(row.bar.SetStatusBarTexture, row.bar, tex)
    if not ok then
        row.bar:SetStatusBarTexture(DEFAULT_BAR_TEXTURE)
    end
end

local function ApplyRowFont(row)
    if not row or not row.text then return end
    local fontPath = (db and db.fontPath) or STANDARD_TEXT_FONT
    local fontSize = (db and db.fontSize) or 10
    local flags = BuildFontFlags()
    local ok = pcall(row.text.SetFont, row.text, fontPath, fontSize, flags)
    if not ok then
        row.text:SetFont(STANDARD_TEXT_FONT, fontSize, flags)
    end
    if db and db.fontShadow == false then
        row.text:SetShadowColor(0, 0, 0, 0)
        row.text:SetShadowOffset(0, 0)
    else
        row.text:SetShadowColor(0, 0, 0, 1)
        row.text:SetShadowOffset(1, -1)
    end
    ApplyRowTexture(row)
end

local function CreatePlateRow(plate)
    local row = CreateFrame("Frame", nil, plate)
    row:SetFrameLevel(plate:GetFrameLevel() + 15)
    row:SetSize(db.width, db.height + 10)
    row:SetScale(db.scale or 1.0)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
    row.bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
    row.bg:SetColorTexture(0.03, 0.03, 0.03, 0.78)

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -2)
    row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 2)
    ApplyRowTexture(row)
    row.bar:SetMinMaxValues(0, db.maxMargin)
    row.bar:SetValue(0)

    row.textOverlay = CreateFrame("Frame", nil, row)
    row.textOverlay:SetAllPoints(row)
    row.textOverlay:SetFrameLevel(row.bar:GetFrameLevel() + 5)

    row.text = row.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("CENTER", row.textOverlay, "CENTER", 0, 0)
    row.text:SetJustifyH("CENTER")
    row.text:SetTextColor(unpack(TEXT_LIGHT))
    row.text:SetShadowColor(0, 0, 0, 1)
    row.text:SetShadowOffset(1, -1)

    row.aggroCircleLeft = row.textOverlay:CreateTexture(nil, "OVERLAY")
    row.aggroCircleLeft:SetTexture("Interface\\COMMON\\Indicator-Red")
    row.aggroCircleLeft:SetSize(14, 14)
    row.aggroCircleLeft:SetPoint("LEFT", row.bar, "LEFT", 3, 0)
    row.aggroCircleLeft:Hide()

    row.aggroCircleRight = row.textOverlay:CreateTexture(nil, "OVERLAY")
    row.aggroCircleRight:SetTexture("Interface\\COMMON\\Indicator-Red")
    row.aggroCircleRight:SetSize(14, 14)
    row.aggroCircleRight:SetPoint("RIGHT", row.bar, "RIGHT", -3, 0)
    row.aggroCircleRight:Hide()

    ApplyRowFont(row)
    row.text:SetText("")

    return row
end

local function FormatRadius(radius)
    local useMeters = db and db.unitSystem == "meters"
    local unit = useMeters and (L.UNIT_M or "M") or (L.UNIT_YD or "yd")
    local val  = useMeters and Round(radius * 0.9144) or Round(radius)
    return (L.LABEL_RANGE or "Range") .. " " .. val .. " " .. unit
end

local function FormatMargin(low, high, radius)
    if type(low) ~= "number" then
        return nil, nil, nil, "NO RANGE"
    end

    local useMeters = db and db.unitSystem == "meters"
    local YD_TO_M   = 0.9144
    local unit      = useMeters and (L.UNIT_M or "M") or (L.UNIT_YD or "yd")
    local lowMargin  = low - radius
    local highMargin = high and (high - radius) or nil

    local function FmtVal(yd)
        if useMeters then
            return math.max(0, Round(yd * YD_TO_M))
        else
            return math.max(0, Round(yd))
        end
    end

    if highMargin and highMargin <= 0 then
        return 0, lowMargin, highMargin, "0 " .. unit
    end

    if highMargin and lowMargin <= 0 then
        local upper = FmtVal(highMargin)
        local value = math.max(0, highMargin / 2)
        return value, lowMargin, highMargin, "0-" .. upper .. " " .. unit
    end

    if highMargin then
        local lo = FmtVal(lowMargin)
        local hi = math.max(lo, FmtVal(highMargin))
        local value = math.max(0, (lowMargin + highMargin) / 2)
        if lo == hi then
            return value, lowMargin, highMargin, lo .. " " .. unit
        end
        return value, lowMargin, highMargin, lo .. "-" .. hi .. " " .. unit
    end

    local lo    = FmtVal(lowMargin)
    local value = math.max(0, lowMargin + 2.5)
    return value, lowMargin, nil, lo .. "+ " .. unit
end

local function QuantizeMargin(value)
    local normalized = Clamp((value or 0) / db.maxMargin, 0, 1)
    if normalized <= 0 then return 0 end
    local stage = math.ceil(normalized * DISPLAY_STAGES)
    return (stage / DISPLAY_STAGES) * db.maxMargin
end

local function MarginState(value, lowMargin, highMargin)
    if highMargin and highMargin <= 0 then
        return "DANGER"
    end
    if highMargin and lowMargin and lowMargin <= 0 then
        return "DANGER"
    end
    if (value or 0) <= 8 then
        return "CAUTION"
    end
    return "SAFE"
end

local function MarginColor(value, lowMargin, highMargin)
    if highMargin and highMargin <= 0 then
        return unpack(COLOR_DANGER)
    end

    if highMargin and lowMargin and lowMargin <= 0 then
        return LerpColor(COLOR_DANGER, COLOR_CAUTION, 0.35)
    end

    value = Clamp(value or 0, 0, db.maxMargin or DEFAULT_MAX_MARGIN)

    if value <= 5 then
        return LerpColor(COLOR_DANGER, COLOR_CAUTION, value / 5)
    elseif value <= 15 then
        return LerpColor(COLOR_CAUTION, COLOR_SAFE, (value - 5) / 10)
    end

    return unpack(COLOR_SAFE)
end

local function SetRowTextColor(row, state)
    row.text:SetTextColor(unpack(TEXT_LIGHT))
    row.text:SetAlpha(1)
end

local function AnimateRowBar(row, frameDelta)
    if not row or not row:IsShown() or not row.bar then return end
    if row.pullFlashUntil and GetTime and GetTime() < row.pullFlashUntil then
        return
    end
    local target = row.targetBarValue
    if type(target) ~= "number" then return end

    if db and db.smoothBar == false then
        row.currentBarValue = target
        row.bar:SetValue(target)
        if row.targetR then
            row.currentR, row.currentG, row.currentB = row.targetR, row.targetG, row.targetB
            row.bar:SetStatusBarColor(row.targetR, row.targetG, row.targetB)
        end
        return
    end

    local dt = Clamp(frameDelta or 0.016, 0.001, 0.10)
    local current = row.currentBarValue
    if type(current) ~= "number" then
        row.currentBarValue = target
        row.bar:SetValue(target)
    else
        local diff = target - current
        local absDiff = math.abs(diff)
        if absDiff > 0.01 then
            local speed = math.max(3.2, absDiff * 3.6)
            local step = speed * dt
            if absDiff <= step then
                row.currentBarValue = target
            elseif diff > 0 then
                row.currentBarValue = current + step
            else
                row.currentBarValue = current - step
            end
            row.bar:SetValue(row.currentBarValue)
        elseif current ~= target then
            row.currentBarValue = target
            row.bar:SetValue(target)
        end
    end

    if row.targetR then
        if not row.currentR then
            row.currentR, row.currentG, row.currentB = row.targetR, row.targetG, row.targetB
        else
            local colorStep = Clamp(dt * 5.0, 0, 1)
            row.currentR = Lerp(row.currentR, row.targetR, colorStep)
            row.currentG = Lerp(row.currentG, row.targetG, colorStep)
            row.currentB = Lerp(row.currentB, row.targetB, colorStep)
        end
        row.bar:SetStatusBarColor(row.currentR, row.currentG, row.currentB)
    end
end

local function UpdateRow(row, unit, delta)
    local plate = row:GetParent()
    if plate and not plate:IsForbidden() then
        row:SetFrameLevel(plate:GetFrameLevel() + 30)
        if row.textOverlay then
            row.textOverlay:SetFrameLevel(row:GetFrameLevel() + 5)
        end
    end

    if not db.enabled or not UnitIsHostileMob(unit) then
        row.lastSnapshot = nil
        row.currentBarValue = nil
        row.targetBarValue = nil
        row.currentR = nil
        row:Hide()
        return
    end

    local threatKnown, threatActive, threatStatus = SafeThreatState(unit)
    local now = GetTime and GetTime() or 0
    local keepGroupAggro = (db.keepGroupAggro ~= false) and PlayerIsActiveAggroTargetInGroup(unit, threatStatus)
    local showPullGraphic = keepGroupAggro or ((db.aggroGraphic ~= false) and row.pullFlashUntil and (now < row.pullFlashUntil))

    if (threatKnown and threatActive) or keepGroupAggro then
        row.lastSnapshot = nil
        if showPullGraphic then
            row:SetScale(db.scale or 1.0)
            row:SetAlpha(1.0)
            row.bar:SetMinMaxValues(0, db.maxMargin)
            row.bar:SetValue(db.maxMargin)
            row.currentBarValue = db.maxMargin
            row.targetBarValue = db.maxMargin
            local phase = math.floor((now * 8) % 2)
            if phase == 0 then
                row.bar:SetStatusBarColor(1.00, 0.08, 0.04)
                row.bg:SetColorTexture(0.55, 0.02, 0.01, 0.96)
                row.text:SetTextColor(1.00, 1.00, 1.00)
            else
                row.bar:SetStatusBarColor(0.75, 0.04, 0.02)
                row.bg:SetColorTexture(0.12, 0.01, 0.01, 0.92)
                row.text:SetTextColor(1.00, 0.35, 0.30)
            end
            row.text:SetText("AGGRO!")
            if row.aggroCircleLeft then row.aggroCircleLeft:Show() end
            if row.aggroCircleRight then row.aggroCircleRight:Show() end
            row:Show()
            return
        end
        if db.hideInCombatSelf ~= false then
            if row.aggroCircleLeft then row.aggroCircleLeft:Hide() end
            if row.aggroCircleRight then row.aggroCircleRight:Hide() end
            row.currentBarValue = nil
            row.targetBarValue = nil
            row.currentR = nil
            row:Hide()
            return
        end
    end

    if db.hideInCombatGroup ~= false and UnitInGroupCombat(unit) then
        row.lastSnapshot = nil
        row.currentBarValue = nil
        row.targetBarValue = nil
        row.currentR = nil
        if row.aggroCircleLeft then row.aggroCircleLeft:Hide() end
        if row.aggroCircleRight then row.aggroCircleRight:Hide() end
        row:Hide()
        return
    end

    if db.hideInCombatOther ~= false and UnitInOtherCombat(unit) then
        row.lastSnapshot = nil
        row.currentBarValue = nil
        row.targetBarValue = nil
        row.currentR = nil
        if row.aggroCircleLeft then row.aggroCircleLeft:Hide() end
        if row.aggroCircleRight then row.aggroCircleRight:Hide() end
        row:Hide()
        return
    end

    if row.aggroCircleLeft then row.aggroCircleLeft:Hide() end
    if row.aggroCircleRight then row.aggroCircleRight:Hide() end

    row:SetScale(db.scale or 1.0)

    local radius, radiusUncertain, npcID = ComputePullRadius(unit)
    local low, high, haveDistance = MeasureRangeBracket(unit)

    row.bar:SetMinMaxValues(0, db.maxMargin)

    if not haveDistance then
        row.lastSnapshot = {
            radius = radius,
            radiusUncertain = radiusUncertain,
            npcID = npcID,
            stealthModelActive = PlayerUsesStealthAggroModel(),
            haveDistance = false,
        }
        if db.hideFarMobs then
            row.currentBarValue = nil
            row.targetBarValue = nil
            row.currentR = nil
            row:Hide()
            return
        end
        row.targetBarValue = 0
        row.currentBarValue = 0
        row.bar:SetValue(0)
        row.targetR, row.targetG, row.targetB = unpack(COLOR_UNKNOWN)
        row.currentR, row.currentG, row.currentB = row.targetR, row.targetG, row.targetB
        row.bar:SetStatusBarColor(row.targetR, row.targetG, row.targetB)
        row.text:SetText(db.showText and FormatRadius(radius) or "")
        SetRowTextColor(row, "unknown")
        if db.fadeNonTarget and not AsBool(UnitIsUnit(unit, "target"), false) and not AsBool(UnitIsUnit(unit, "mouseover"), false) then
            row:SetAlpha(0.55)
        else
            row:SetAlpha(1.0)
        end
        row:Show()
        return
    end

    local value, lowMargin, highMargin, marginText = FormatMargin(low, high, radius)
    row.lastSnapshot = {
        radius = radius,
        radiusUncertain = radiusUncertain,
        npcID = npcID,
        stealthModelActive = PlayerUsesStealthAggroModel(),
        low = low,
        high = high,
        haveDistance = true,
        value = value,
        lowMargin = lowMargin,
        highMargin = highMargin,
        state = MarginState(value, lowMargin, highMargin),
    }

    if db.hideFarMobs and type(lowMargin) == "number" and lowMargin >= db.maxMargin then
        row.currentBarValue = nil
        row.targetBarValue = nil
        row.currentR = nil
        row:Hide()
        return
    end

    value = Clamp(value or 0, 0, db.maxMargin)
    local displayValue = (db.smoothBar ~= false) and value or QuantizeMargin(value)
    if db.invertBar then
        displayValue = Clamp(db.maxMargin - displayValue, 0, db.maxMargin)
    end

    local r, g, b = MarginColor(value, lowMargin, highMargin)
    row.targetBarValue = displayValue
    row.targetR, row.targetG, row.targetB = r, g, b

    if db.smoothBar == false or row.currentBarValue == nil or not row:IsShown() then
        row.currentBarValue = displayValue
        row.currentR, row.currentG, row.currentB = r, g, b
        row.bar:SetValue(displayValue)
        row.bar:SetStatusBarColor(r, g, b)
    end

    local state = row.lastSnapshot.state
    SetRowTextColor(row, state:lower())

    if db.fadeNonTarget and state ~= "DANGER"
        and not AsBool(UnitIsUnit(unit, "target"), false)
        and not AsBool(UnitIsUnit(unit, "mouseover"), false) then
        row:SetAlpha(0.55)
    else
        row:SetAlpha(1.0)
    end

    local atZeroRange = (highMargin and highMargin <= 0) or (value <= 0)

    if db.showText then
        if atZeroRange then
            row.text:SetText(L.TEXT_ZERO_RANGE or "DANGER")
        else
            local prefix = radiusUncertain and "~" or ""
            local statePrefix = db.statusText and (state .. "  ") or ""
            row.text:SetText(statePrefix .. prefix .. marginText .. "  " .. FormatRadius(radius))
        end
    else
        row.text:SetText("")
    end

    if row.pullFlashUntil and GetTime and GetTime() < row.pullFlashUntil then
        local phase = math.floor((GetTime() * 10) % 2)
        if phase == 0 then
            row.bar:SetStatusBarColor(1.00, 0.05, 0.03)
            row.bg:SetColorTexture(0.45, 0.02, 0.01, 0.95)
        else
            row.bg:SetColorTexture(0.03, 0.03, 0.03, 0.90)
        end
    elseif atZeroRange then
        row.bg:SetColorTexture(0.42, 0.04, 0.02, 0.88)
    else
        row.bg:SetColorTexture(0.03, 0.03, 0.03, 0.78)
    end

    row:Show()
end

-------------------------------------------------------------------------------
-- Local target warning
-------------------------------------------------------------------------------

local lastWarningKey
local lastSoundKey

ResetProximityAlertState = function()
    lastWarningKey = nil
    lastSoundKey = nil
end

local function PlayAggroSound(tier, key)
    if not db or not db.alertsEnabled or not db.soundEnabled or type(PlaySoundFile) ~= "function" then
        return
    end

    if key and key == lastSoundKey then
        return
    end
    lastSoundKey = key

    local path = SOUND_SOFT
    if tier == "danger" then
        path = SOUND_DANGER
    elseif tier == "mid" then
        path = SOUND_MID
    end

    pcall(PlaySoundFile, path, "Master")
end

local STEALTH_NOTICE_REARM_MARGIN = 3
local STEALTH_NOTICE_GLOBAL_COOLDOWN = 0.80
local STEALTH_NOTICE_DISPLAY_TIME = 0.70
local stealthNoticeStates = {}
local stealthNoticeLastAt = -100
local stealthNoticeFrame

local function CreateStealthNoticeFrame()
    if stealthNoticeFrame then return end
    stealthNoticeFrame = CreateFrame("Frame", "AggroMeterStealthNoticeFrame", UIParent)
    stealthNoticeFrame:SetSize(220, 150)
    stealthNoticeFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 135)
    stealthNoticeFrame:SetFrameStrata("HIGH")

    local glyph = stealthNoticeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    glyph:SetPoint("CENTER")
    if STANDARD_TEXT_FONT and glyph.SetFont then
        pcall(glyph.SetFont, glyph, STANDARD_TEXT_FONT, 96, "THICKOUTLINE")
    end
    glyph:SetText("!")
    glyph:SetTextColor(1.00, 0.05, 0.03, 1.00)
    glyph:SetShadowColor(0, 0, 0, 1)
    glyph:SetShadowOffset(3, -3)
    stealthNoticeFrame.glyph = glyph
    stealthNoticeFrame:Hide()

    stealthNoticeFrame:SetScript("OnUpdate", function(self)
        if not self.hideAt then return end
        local now = GetTime and GetTime() or 0
        if now >= self.hideAt then
            self.hideAt = nil
            self:Hide()
            self:SetAlpha(1)
            return
        end
        local remaining = self.hideAt - now
        if remaining < 0.20 then
            self:SetAlpha(Clamp(remaining / 0.20, 0, 1))
        else
            self:SetAlpha(1)
        end
    end)
end

ResetStealthNoticeState = function()
    stealthNoticeStates = {}
    if stealthNoticeFrame then
        stealthNoticeFrame.hideAt = nil
        stealthNoticeFrame:Hide()
        stealthNoticeFrame:SetAlpha(1)
    end
end

local function ShowStealthNotice()
    if SafeUnitIsDead("player") then return end
    CreateStealthNoticeFrame()
    local now = GetTime and GetTime() or 0
    stealthNoticeFrame.hideAt = now + STEALTH_NOTICE_DISPLAY_TIME
    stealthNoticeFrame:SetAlpha(1)
    stealthNoticeFrame:Show()

    if db and db.alertsEnabled and db.soundEnabled and type(PlaySoundFile) == "function" then
        pcall(PlaySoundFile, SOUND_STEALTH_NOTICE, "Master")
    end
end

local function UpdateStealthPreDetectionNotice()
    if not db or not db.enabled or not db.alertsEnabled or not db.warningEnabled or not db.stealthNoticeEnabled then
        ResetStealthNoticeState()
        return
    end
    if SafeUnitIsDead("player") or not PlayerUsesStealthAggroModel() then
        ResetStealthNoticeState()
        return
    end

    local now = GetTime and GetTime() or 0
    local bestEntry
    local seen = {}

    for unit, row in pairs(activeRows) do
        if UnitExists(unit) and not SafeUnitIsDead(unit) and UnitIsHostileMob(unit) then
            local guid = UnitGUID(unit)
            if not IsSecret(guid) and type(guid) == "string" then
                seen[guid] = true
                local state = stealthNoticeStates[guid]
                if not state then
                    state = { inside = false }
                    stealthNoticeStates[guid] = state
                end

                local known, threatActive = SafeThreatState(unit)
                local snap = row and row.lastSnapshot
                local lowMargin = snap and snap.lowMargin
                local highMargin = snap and snap.highMargin
                local readable = snap and snap.haveDistance and type(lowMargin) == "number"

                if known and threatActive then
                    state.inside = false
                elseif readable then
                    local insideStealthDetection = type(lowMargin) == "number" and lowMargin < 0
                    local clearlyOutside = lowMargin > STEALTH_NOTICE_REARM_MARGIN

                    if insideStealthDetection and not state.inside then
                        state.inside = true
                        local score = highMargin or lowMargin
                        if not bestEntry or score < bestEntry.score then
                            bestEntry = { unit = unit, guid = guid, score = score }
                        end
                    elseif clearlyOutside then
                        state.inside = false
                    end
                end
            end
        end
    end

    for guid in pairs(stealthNoticeStates) do
        if not seen[guid] then
            stealthNoticeStates[guid] = nil
        end
    end

    if bestEntry and (now - stealthNoticeLastAt) >= STEALTH_NOTICE_GLOBAL_COOLDOWN then
        stealthNoticeLastAt = now
        ShowStealthNotice()
    end
end

local function TriggerProximityBanner(message, soundTier, soundKey)
    if not db or not db.alertsEnabled then return end

    if SafeUnitIsDead("player") then
        return
    end

    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] then
        pcall(RaidNotice_AddMessage, RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
    elseif UIErrorsFrame and UIErrorsFrame.AddMessage then
        pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, message, 1, 0.18, 0.10, 1)
    end

    if soundTier then
        PlayAggroSound(soundTier, soundKey or message)
    end
end

local function GetTargetProximityAlert(unit)
    if not UnitIsHostileMob(unit) then return nil end

    local radius = ComputePullRadius(unit)
    local low, high, haveDistance = MeasureRangeBracket(unit)
    if not haveDistance or type(low) ~= "number" or type(high) ~= "number" then
        return nil
    end

    local lowMargin = low - radius
    local highMargin = high - radius

    if highMargin <= 0 then
        return "AGGRO ALERT - AT ESTIMATED RANGE", "danger", "range"
    end

    if lowMargin > 5 then
        return nil
    end

    local YD_TO_M = 0.9144
    local lo = math.max(0, lowMargin)
    local hi = math.max(0, highMargin)
    local ceilLo = math.ceil(lo)
    local ceilHi = math.ceil(hi)
    local tier = "soft"
    if ceilHi <= 1 then
        tier = "danger"
    elseif ceilHi <= 3 then
        tier = "mid"
    end

    if ceilLo == ceilHi and ceilHi >= 1 and ceilHi <= 5 then
        return "AGGRO ALERT - " .. Round(ceilHi * YD_TO_M) .. " M", tier, tostring(ceilHi)
    end

    local shownLo = math.max(0, math.floor(lo))
    local shownHi = math.max(shownLo, math.ceil(hi))
    if shownHi <= 1 then
        tier = "danger"
    elseif shownHi <= 3 then
        tier = "mid"
    else
        tier = "soft"
    end
    return "AGGRO ALERT - " .. Round(shownLo * YD_TO_M) .. "-" .. Round(shownHi * YD_TO_M) .. " M", tier, shownLo .. "-" .. shownHi
end

local function UpdateTargetProximityAlert()
    if not db or not db.enabled or not db.alertsEnabled or not db.warningEnabled then
        ResetProximityAlertState()
        return
    end

    if SafeUnitIsDead("player") then
        ResetProximityAlertState()
        return
    end

    local targetExists = UnitExists("target")
    if IsSecret(targetExists) or not targetExists then
        ResetProximityAlertState()
        return
    end

    local guid = UnitGUID("target")
    if IsSecret(guid) then guid = nil end

    if SafeUnitIsDead("target") then
        ResetProximityAlertState()
        return
    end

    local threatKnown, targetThreatActive = SafeThreatState("target")
    if threatKnown and targetThreatActive then
        ResetProximityAlertState()
        return
    end

    if db.hideInCombatGroup ~= false and UnitInGroupCombat("target") then
        ResetProximityAlertState()
        return
    end

    if db.hideInCombatOther ~= false and UnitInOtherCombat("target") then
        ResetProximityAlertState()
        return
    end

    local text, tier, bucket = GetTargetProximityAlert("target")
    if not text then
        ResetProximityAlertState()
        return
    end

    local key = tostring(guid or "target") .. "|" .. text
    if key ~= lastWarningKey then
        lastWarningKey = key
        TriggerProximityBanner(text, tier, tostring(guid or "target") .. "|" .. tostring(bucket or text))
    end
end

-------------------------------------------------------------------------------
-- Actual aggro transition detection
-------------------------------------------------------------------------------

local engagementStates = {}

local function TriggerActualAggroAlert(row, unit, guid)
    if row and GetTime and (db.aggroGraphic ~= false) then
        row.pullFlashUntil = GetTime() + 2.20
        UpdateRow(row, unit)
    end

    if db.alertsEnabled and db.pullAlertEnabled then
        local name = SafeUnitName(unit)
        local message = name and ("AGGRO! - " .. name) or "AGGRO!"
        TriggerProximityBanner(message, "danger", tostring(guid or unit) .. "|actual-aggro")
    end
end

local function UpdateEngagementState(unit, row)
    if SafeUnitIsDead(unit) then
        local deadGUID = UnitGUID(unit)
        if not IsSecret(deadGUID) and type(deadGUID) == "string" then
            engagementStates[deadGUID] = nil
        end
        return
    end

    if not UnitIsHostileMob(unit) then return end

    local guid = UnitGUID(unit)
    if IsSecret(guid) or type(guid) ~= "string" then return end

    local known, threatActive = SafeThreatState(unit)
    if not known then return end

    if row then
        row.engagementGUID = guid
    end

    local state = engagementStates[guid]
    if not state then
        state = {}
        engagementStates[guid] = state
    end

    if state.initialized and threatActive and not state.threatActive then
        TriggerActualAggroAlert(row, unit, guid)
    end

    state.initialized = true
    state.threatActive = threatActive
end

local function ClearUnitEngagementState(unit)
    local guid = UnitGUID(unit)
    if not IsSecret(guid) and type(guid) == "string" then
        engagementStates[guid] = nil
    end
end

local function OnPlateAdded(unit)
    visiblePlateUnits[unit] = true

    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() then return end

    local row = plateRows[plate]
    if not row then
        row = CreatePlateRow(plate)
        plateRows[plate] = row
    end

    row:SetSize(db.width, db.height + 10)
    row:SetScale(db.scale or 1.0)
    row:ClearAllPoints()
    row:SetPoint("TOP", PlateAnchor(plate), "BOTTOM", 0, db.offsetY)
    ApplyRowFont(row)
    row.unit = unit
    activeRows[unit] = row
    UpdateRow(row, unit)
end

local function OnPlateRemoved(unit)
    visiblePlateUnits[unit] = nil
    local row = activeRows[unit]
    if row and row.engagementGUID then
        engagementStates[row.engagementGUID] = nil
        row.engagementGUID = nil
    else
        ClearUnitEngagementState(unit)
    end
    if row then
        row:Hide()
        row.unit = nil
        activeRows[unit] = nil
    end
end

RefreshAllPlates = function()
    for unit, row in pairs(activeRows) do
        row:Hide()
        row.unit = nil
        activeRows[unit] = nil
    end

    for unit in pairs(visiblePlateUnits) do
        OnPlateAdded(unit)
    end
end

-------------------------------------------------------------------------------
-- Config Window (UI)
-------------------------------------------------------------------------------

local function CreateConfigFrame()
    if configFrame then return configFrame end

    local f = CreateFrame("Frame", "AggroMeterConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(430, 480)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

    tinsert(UISpecialFrames, "AggroMeterConfigFrame")

    local titleWidget = f.TitleText
    if titleWidget then titleWidget:SetText(L.CONFIG_TITLE) end

    local function AttachTooltip(widget, getTitleFn, getDescFn)
        widget:HookScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if getTitleFn then
                GameTooltip:AddLine(getTitleFn(), 1.00, 0.82, 0.00)
            end
            if getDescFn then
                local desc = getDescFn()
                if desc and desc ~= "" then
                    GameTooltip:AddLine(desc, 0.90, 0.94, 1.00, true)
                end
            end
            GameTooltip:Show()
        end)
        widget:HookScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
    end

    -- Tabs container (3 pages: 1=Appearance, 2=Alerts & Text, 3=Visibility)
    local pages = {}
    local tabBtns = {}
    local activeTab = 1
    local tabLabelFns = {
        function() return L.TAB_APPEARANCE end,
        function() return L.TAB_ALERTS end,
        function() return L.TAB_VISIBILITY end,
    }

    for i = 1, 3 do
        local page = CreateFrame("Frame", nil, f)
        page:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -64)
        page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 78)
        if i ~= 1 then page:Hide() end
        pages[i] = page

        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(128, 26)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 18 + (i - 1) * 133, -32)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(btn)

        btn.bottomLine = btn:CreateTexture(nil, "ARTWORK")
        btn.bottomLine:SetHeight(2)
        btn.bottomLine:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
        btn.bottomLine:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)

        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)

        tabBtns[i] = btn
    end

    local sectionHeaders = {}
    local function CreateSectionCard(parent, getHeaderFn, yTop, height)
        local card = CreateFrame("Frame", nil, parent)
        card:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yTop)
        card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, yTop)
        card:SetHeight(height)

        card.border = card:CreateTexture(nil, "BACKGROUND")
        card.border:SetAllPoints(card)
        card.border:SetColorTexture(0.28, 0.30, 0.36, 0.55)

        card.bg = card:CreateTexture(nil, "BORDER")
        card.bg:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
        card.bg:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 1)
        card.bg:SetColorTexture(0.06, 0.07, 0.09, 0.72)

        local header = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -10)
        header:SetTextColor(1.00, 0.82, 0.15)
        header.getHeaderFn = getHeaderFn
        header:SetText(getHeaderFn())
        sectionHeaders[#sectionHeaders + 1] = header

        local line = card:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -28)
        line:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -28)
        line:SetColorTexture(0.35, 0.35, 0.42, 0.50)

        return card
    end

    local sliders = {}
    local function CreateSlider(parent, name, getLabelFn, getDescFn, minVal, maxVal, step, xOffset, yOffset, getter, setter, formatStr)
        local slider = CreateFrame("Slider", "AggroMeterSlider_" .. name, parent, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
        slider:SetWidth(174)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)

        local lowText  = _G[slider:GetName() .. "Low"]
        local highText = _G[slider:GetName() .. "High"]
        local text     = _G[slider:GetName() .. "Text"]

        if lowText  then lowText:SetText(tostring(minVal)) end
        if highText then highText:SetText(tostring(maxVal)) end

        local function UpdateLabel(val)
            if text then
                if type(formatStr) == "function" then
                    text:SetText(getLabelFn() .. ": " .. formatStr(val))
                else
                    text:SetText(getLabelFn() .. ": " .. string.format(formatStr or "%d", val))
                end
            end
        end

        slider:SetScript("OnValueChanged", function(self, value)
            if self.suppress then return end
            if step >= 1 then
                value = Round(value)
            else
                value = math.floor(value * 100 + 0.5) / 100
            end
            UpdateLabel(value)
            setter(value)
            RefreshAllPlates()
        end)

        slider.Refresh = function(self)
            self.suppress = true
            local val = getter()
            self:SetValue(val)
            UpdateLabel(val)
            self.suppress = nil
        end

        AttachTooltip(slider, getLabelFn, getDescFn)
        sliders[#sliders + 1] = slider
        return slider
    end

    -- =========================================================================
    -- TAB 1: APPEARANCE
    -- =========================================================================
    local cardDims = CreateSectionCard(pages[1], function() return L.SEC_DIMENSIONS end, -2, 168)

    CreateSlider(cardDims, "OffsetY",
        function() return L.SLIDER_OFFSETY end, function() return L.DESC_OFFSETY end,
        -50, 50, 1, 14, -46,
        function() return db.offsetY or -5 end, function(v) db.offsetY = v end, "%d"
    )
    CreateSlider(cardDims, "FontSize",
        function() return L.SLIDER_FONTSIZE end, function() return L.DESC_FONTSIZE end,
        6, 24, 1, 206, -46,
        function() return db.fontSize or 10 end, function(v) db.fontSize = v end, "%d"
    )
    CreateSlider(cardDims, "Width",
        function() return L.SLIDER_WIDTH end, function() return L.DESC_WIDTH end,
        80, 220, 2, 14, -90,
        function() return db.width or DEFAULT_WIDTH end, function(v) db.width = v end, "%d"
    )
    CreateSlider(cardDims, "Height",
        function() return L.SLIDER_HEIGHT end, function() return L.DESC_HEIGHT end,
        4, 20, 1, 206, -90,
        function() return db.height or DEFAULT_HEIGHT end, function(v) db.height = v end, "%d"
    )
    CreateSlider(cardDims, "Scale",
        function() return L.SLIDER_SCALE end, function() return L.DESC_SCALE end,
        0.75, 1.50, 0.05, 14, -134,
        function() return db.scale or 1.0 end, function(v) db.scale = v end, "%.2f"
    )
    CreateSlider(cardDims, "UpdateRate",
        function() return L.SLIDER_UPDATERATE end, function() return L.DESC_UPDATERATE end,
        5, 60, 1, 206, -134,
        function() return db.updateRate or 25 end, function(v) db.updateRate = v end,
        function(v) return string.format("%d Hz (%d ms)", v, Round(1000 / math.max(1, v))) end
    )

    local cardStyle = CreateSectionCard(pages[1], function() return L.SEC_STYLE end, -176, 158)

    -- Font Section (Prev/Next + Dropdown Button + Popup List)
    local function BuildFontList()
        local fontDir = MEDIA_PATH .. "Media\\Fonts\\"
        local list = {
            { label = L.FONT_DEFAULT,              path = "Fonts\\FRIZQT__.TTF" },
            { label = "Arial Narrow",              path = "Fonts\\ARIALN.TTF"   },
            { label = "Roboto Condensed Bold",     path = fontDir .. "RobotoCondensed-Bold.ttf" },
            { label = "Lato Regular",              path = fontDir .. "Lato-Regular.ttf" },
            { label = "Poppins SemiBold",          path = fontDir .. "Poppins-SemiBold.ttf" },
            { label = "Diablo Heavy",              path = fontDir .. "DiabloHeavy.ttf" },
            { label = "Atkinson Hyperlegible",     path = fontDir .. "AtkinsonHyperlegibleNext-Regular.otf" },
            { label = "Expressway",                path = fontDir .. "Expressway.ttf" },
            { label = "PT Sans Narrow Bold",       path = fontDir .. "PTSansNarrow-Bold.ttf" },
            { label = "FiraSans Bold",             path = fontDir .. "FiraSans-Bold.ttf" },
            { label = "Oswald Regular",            path = fontDir .. "Oswald-Regular.ttf" },
            { label = "Prototype",                 path = fontDir .. "Prototype.ttf" },
            { label = "Accidental Presidency",     path = fontDir .. "AccidentalPresidency.ttf" },
            { label = "Forced Square",             path = fontDir .. "ForcedSquare.ttf" },
            { label = "Trajan Pro SemiBold",       path = fontDir .. "TrajanPro3SemiBold.ttf" },
            { label = "Homespun (Pixel)",          path = fontDir .. "Homespun.ttf" },
            { label = "TrashHand",                 path = fontDir .. "TrashHand.ttf" },
            { label = "Morpheus",                  path = "Fonts\\MORPHEUS.TTF" },
            { label = "Skurri",                    path = "Fonts\\SKURRI.TTF"   },
            { label = "2002",                      path = "Fonts\\2002.TTF"     },
            { label = "2002 Bold",                 path = "Fonts\\2002B.TTF"    },
            { label = "Friends",                   path = "Fonts\\FRIENDS.TTF"  },
            { label = "Nimrod MT",                 path = "Fonts\\NIM_____.ttf" },
        }
        local seen = {}
        for _, item in ipairs(list) do
            seen[item.path:lower()] = true
        end
        if type(LibStub) == "function" then
            local ok, lsm = pcall(LibStub, "LibSharedMedia-3.0", true)
            if ok and lsm and type(lsm.List) == "function" and type(lsm.Fetch) == "function" then
                local names = lsm:List("font")
                if type(names) == "table" then
                    for _, name in ipairs(names) do
                        if #list >= 30 then break end
                        local path = lsm:Fetch("font", name)
                        if type(path) == "string" and not seen[path:lower()] then
                            seen[path:lower()] = true
                            list[#list + 1] = { label = name, path = path }
                        end
                    end
                end
            end
        end
        return list
    end

    local function CurrentFontName()
        local current = (db and db.fontPath) or STANDARD_TEXT_FONT
        local list = BuildFontList()
        for _, item in ipairs(list) do
            if item.path:lower() == current:lower() then
                return item.label
            end
        end
        return current:match("([^\\/]+)%.[^%.]+$") or current
    end

    local fontPrevBtn = CreateFrame("Button", nil, cardStyle, "UIPanelButtonTemplate")
    fontPrevBtn:SetSize(26, 22)
    fontPrevBtn:SetPoint("TOPLEFT", cardStyle, "TOPLEFT", 12, -36)
    fontPrevBtn:SetText("<")

    local fontSelectBtn = CreateFrame("Button", nil, cardStyle, "UIPanelButtonTemplate")
    fontSelectBtn:SetSize(308, 22)
    fontSelectBtn:SetPoint("LEFT", fontPrevBtn, "RIGHT", 4, 0)
    AttachTooltip(fontSelectBtn, function() return string.format(L.FONT_SELECT_BTN, CurrentFontName()) end, function() return L.DESC_FONT_SELECT end)

    local fontNextBtn = CreateFrame("Button", nil, cardStyle, "UIPanelButtonTemplate")
    fontNextBtn:SetSize(26, 22)
    fontNextBtn:SetPoint("LEFT", fontSelectBtn, "RIGHT", 4, 0)
    fontNextBtn:SetText(">")

    local fontMenu = CreateFrame("Frame", "AggroMeterFontMenu", f)
    fontMenu:SetWidth(520)
    fontMenu:SetPoint("TOP", fontSelectBtn, "BOTTOM", 0, -2)
    fontMenu:SetFrameStrata("TOOLTIP")
    fontMenu:SetFrameLevel(f:GetFrameLevel() + 30)
    fontMenu:EnableMouse(true)
    fontMenu:SetClampedToScreen(true)
    fontMenu:Hide()

    fontMenu.border = fontMenu:CreateTexture(nil, "BACKGROUND")
    fontMenu.border:SetAllPoints(fontMenu)
    fontMenu.border:SetColorTexture(0.35, 0.35, 0.40, 0.98)

    fontMenu.bg = fontMenu:CreateTexture(nil, "BORDER")
    fontMenu.bg:SetPoint("TOPLEFT", fontMenu, "TOPLEFT", 1, -1)
    fontMenu.bg:SetPoint("BOTTOMRIGHT", fontMenu, "BOTTOMRIGHT", -1, 1)
    fontMenu.bg:SetColorTexture(0.06, 0.06, 0.08, 0.98)

    local fontMenuItems = {}

    local function UpdateFontSelectBtn()
        fontSelectBtn:SetText(string.format(L.FONT_SELECT_BTN, CurrentFontName()))
        local fs = fontSelectBtn:GetFontString()
        if fs then
            local path = (db and db.fontPath) or STANDARD_TEXT_FONT
            local flags = BuildFontFlags()
            local ok = pcall(fs.SetFont, fs, path, 11, flags)
            if not ok then
                fs:SetFont(STANDARD_TEXT_FONT, 11, flags)
            end
            if db and db.fontShadow == false then
                fs:SetShadowColor(0, 0, 0, 0)
                fs:SetShadowOffset(0, 0)
            else
                fs:SetShadowColor(0, 0, 0, 1)
                fs:SetShadowOffset(1, -1)
            end
        end
    end

    local function CycleFont(delta)
        local list = BuildFontList()
        if #list == 0 then return end
        local current = ((db and db.fontPath) or STANDARD_TEXT_FONT):lower()
        local idx = 1
        for i, item in ipairs(list) do
            if item.path:lower() == current then
                idx = i
                break
            end
        end
        idx = ((idx - 1 + delta) % #list) + 1
        db.fontPath = list[idx].path
        UpdateFontSelectBtn()
        if fontMenu:IsShown() then
            fontMenu:Hide()
        end
        RefreshAllPlates()
    end

    fontPrevBtn:SetScript("OnClick", function() CycleFont(-1) end)
    fontNextBtn:SetScript("OnClick", function() CycleFont(1) end)

    -- Bar Texture Section
    local function BuildTextureList()
        local texDir    = MEDIA_PATH .. "Media\\Textures\\"
        local stylesDir = MEDIA_PATH .. "Media\\Textures\\Styles\\"
        local list = {
            { label = L.TEX_DEFAULT,             path = "Interface\\TargetingFrame\\UI-StatusBar" },
            { label = "Fade Bottom",             path = stylesDir .. "fade-bottom.png" },
            { label = "Fade Top",                path = stylesDir .. "fade-top.png" },
            { label = "Fade Left",               path = stylesDir .. "fade-left.png" },
            { label = "Fade Right",              path = stylesDir .. "fade-right.png" },
            { label = "Bevelled",                path = stylesDir .. "bevelled.png" },
            { label = "Bevelled Edge",           path = stylesDir .. "bevelled-edge.png" },
            { label = "Bevelled Edge (Inv)",     path = stylesDir .. "bevelled-edge-inverted.png" },
            { label = "Bevelled Grey",           path = stylesDir .. "bevelled-grey.png" },
            { label = "Blizzard Cast Bar",       path = stylesDir .. "blizzard-cast-bar.png" },
            { label = "Blizzard Cast (Grey)",    path = stylesDir .. "blizzard-cast-bar-grey.png" },
            { label = "Absorb Narrow",           path = stylesDir .. "blizzard-absorb-narrow.png" },
            { label = "Absorb Narrow (Grey)",    path = stylesDir .. "blizzard-absorb-grey-narrow.png" },
            { label = "Absorb Wide",             path = stylesDir .. "blizzard-absorb.png" },
            { label = "Absorb Wide (Grey)",      path = stylesDir .. "blizzard-absorb-grey.png" },
            { label = "Painted Edge",            path = stylesDir .. "gw2.png" },
            { label = "Clear Glass",             path = stylesDir .. "glass.png" },
            { label = "Glossy",                  path = stylesDir .. "glossy.png" },
            { label = "Segmented Pips",          path = stylesDir .. "ow-pips.png" },
            { label = "Segmented Pips (Narrow)", path = stylesDir .. "ow-pips-narrow.png" },
            { label = "Modern Pips",             path = stylesDir .. "ow2-pips.png" },
            { label = "Modern Pips (BG)",        path = stylesDir .. "ow2-pips-bg.png" },
            { label = "Solid Black",             path = stylesDir .. "black.png" },
            { label = "Solid Grey",              path = stylesDir .. "grey.png" },
            { label = "Solid Grey (Light)",      path = stylesDir .. "light-grey.png" },
            { label = "Solid Grey (Raid)",       path = stylesDir .. "grey-raid.png" },
            { label = "Solid White",             path = stylesDir .. "white.png" },
            { label = "Minimalist",              path = texDir .. "Minimalist.tga" },
            { label = "Smooth",                  path = texDir .. "Smooth.tga" },
            { label = "Flat",                    path = texDir .. "Flat.tga" },
            { label = "Glaze",                   path = texDir .. "Glaze.blp" },
            { label = "BantoBar",                path = texDir .. "BantoBar.tga" },
            { label = "Frosted Glass",           path = texDir .. "Glass.tga" },
            { label = "Vidro",                   path = texDir .. "Vidro.tga" },
            { label = "Texture 2020",            path = texDir .. "Texture2020.tga" },
            { label = "Split Bar",               path = texDir .. "SplitBar.tga" },
            { label = "Hyanda",                  path = texDir .. "Hyanda.tga" },
            { label = "Dark With Line",          path = texDir .. "DarkWithLine.tga" },
            { label = "Raid Bar",                path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
            { label = "Skills Bar",              path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
            { label = "BarFill Smooth",          path = "Interface\\TargetingFrame\\BarFill2" },
        }
        return list
    end

    local function CurrentTextureName()
        local current = (db and db.barTexture) or DEFAULT_BAR_TEXTURE
        local list = BuildTextureList()
        for _, item in ipairs(list) do
            if item.path:lower() == current:lower() then
                return item.label
            end
        end
        return current:match("([^\\/]+)$") or current
    end

    local texPrevBtn = CreateFrame("Button", nil, cardStyle, "UIPanelButtonTemplate")
    texPrevBtn:SetSize(26, 22)
    texPrevBtn:SetPoint("TOPLEFT", cardStyle, "TOPLEFT", 12, -62)
    texPrevBtn:SetText("<")

    local texSelectBtn = CreateFrame("Button", nil, cardStyle, "UIPanelButtonTemplate")
    texSelectBtn:SetSize(308, 22)
    texSelectBtn:SetPoint("LEFT", texPrevBtn, "RIGHT", 4, 0)
    AttachTooltip(texSelectBtn, function() return string.format(L.TEX_SELECT_BTN, CurrentTextureName()) end, function() return L.DESC_TEX_SELECT end)

    local texNextBtn = CreateFrame("Button", nil, cardStyle, "UIPanelButtonTemplate")
    texNextBtn:SetSize(26, 22)
    texNextBtn:SetPoint("LEFT", texSelectBtn, "RIGHT", 4, 0)
    texNextBtn:SetText(">")

    local texMenu = CreateFrame("Frame", "AggroMeterTextureMenu", f)
    texMenu:SetWidth(520)
    texMenu:SetPoint("TOP", texSelectBtn, "BOTTOM", 0, -2)
    texMenu:SetFrameStrata("TOOLTIP")
    texMenu:SetFrameLevel(f:GetFrameLevel() + 30)
    texMenu:EnableMouse(true)
    texMenu:SetClampedToScreen(true)
    texMenu:Hide()

    texMenu.border = texMenu:CreateTexture(nil, "BACKGROUND")
    texMenu.border:SetAllPoints(texMenu)
    texMenu.border:SetColorTexture(0.35, 0.35, 0.40, 0.98)

    texMenu.bg = texMenu:CreateTexture(nil, "BORDER")
    texMenu.bg:SetPoint("TOPLEFT", texMenu, "TOPLEFT", 1, -1)
    texMenu.bg:SetPoint("BOTTOMRIGHT", texMenu, "BOTTOMRIGHT", -1, 1)
    texMenu.bg:SetColorTexture(0.06, 0.06, 0.08, 0.98)

    local texMenuItems = {}

    local function UpdateTextureSelectBtn()
        texSelectBtn:SetText(string.format(L.TEX_SELECT_BTN, CurrentTextureName()))
    end

    local function CycleTexture(delta)
        local list = BuildTextureList()
        if #list == 0 then return end
        local current = ((db and db.barTexture) or DEFAULT_BAR_TEXTURE):lower()
        local idx = 1
        for i, item in ipairs(list) do
            if item.path:lower() == current then
                idx = i
                break
            end
        end
        idx = ((idx - 1 + delta) % #list) + 1
        db.barTexture = list[idx].path
        UpdateTextureSelectBtn()
        if texMenu:IsShown() then
            texMenu:Hide()
        end
        RefreshAllPlates()
    end

    texPrevBtn:SetScript("OnClick", function() CycleTexture(-1) end)
    texNextBtn:SetScript("OnClick", function() CycleTexture(1) end)

    local function PopulateTextureMenu()
        local list = BuildTextureList()
        local itemHeight = 20
        local cols = 3
        local colWidth = 168
        local rows = math.ceil(#list / cols)
        texMenu:SetHeight(rows * itemHeight + 8)
        for i, entry in ipairs(list) do
            local item = texMenuItems[i]
            if not item then
                item = CreateFrame("Button", nil, texMenu)
                item:SetSize(colWidth, itemHeight)

                item.preview = item:CreateTexture(nil, "BACKGROUND")
                item.preview:SetPoint("TOPLEFT", item, "TOPLEFT", 2, -2)
                item.preview:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -2, 2)

                item.hl = item:CreateTexture(nil, "BORDER")
                item.hl:SetAllPoints(item)
                item.hl:SetColorTexture(1.0, 1.0, 1.0, 0.22)
                item.hl:Hide()

                item.label = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                item.label:SetPoint("LEFT", item, "LEFT", 6, 0)
                item.label:SetJustifyH("LEFT")

                item:SetScript("OnEnter", function(self) self.hl:Show() end)
                item:SetScript("OnLeave", function(self) self.hl:Hide() end)
                texMenuItems[i] = item
            end
            local col = (i - 1) % cols
            local rowIdx = math.floor((i - 1) / cols)
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", texMenu, "TOPLEFT", 4 + (col * (colWidth + 4)), -4 - (rowIdx * itemHeight))

            local isSelected = ((db and db.barTexture) or DEFAULT_BAR_TEXTURE):lower() == entry.path:lower()
            item.label:SetText((isSelected and "> " or "   ") .. entry.label)
            pcall(item.preview.SetTexture, item.preview, entry.path)
            if isSelected then
                item.preview:SetVertexColor(0.20, 0.72, 0.30, 0.85)
                item.label:SetTextColor(0.40, 0.95, 1.00)
            else
                item.preview:SetVertexColor(0.18, 0.45, 0.25, 0.55)
                item.label:SetTextColor(1.00, 1.00, 1.00)
            end
            local chosenTex = entry.path
            item:SetScript("OnClick", function()
                db.barTexture = chosenTex
                texMenu:Hide()
                UpdateTextureSelectBtn()
                RefreshAllPlates()
            end)
            item:Show()
        end
        for i = #list + 1, #texMenuItems do
            texMenuItems[i]:Hide()
        end
    end

    local function PopulateFontMenu()
        local list = BuildFontList()
        local itemHeight = 20
        local cols = 3
        local colWidth = 168
        local rows = math.ceil(#list / cols)
        fontMenu:SetHeight(rows * itemHeight + 8)
        local flags = BuildFontFlags()
        for i, entry in ipairs(list) do
            local item = fontMenuItems[i]
            if not item then
                item = CreateFrame("Button", nil, fontMenu)
                item:SetSize(colWidth, itemHeight)

                item.hl = item:CreateTexture(nil, "BACKGROUND")
                item.hl:SetAllPoints(item)
                item.hl:SetColorTexture(0.25, 0.50, 0.80, 0.35)
                item.hl:Hide()

                item.label = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                item.label:SetPoint("LEFT", item, "LEFT", 6, 0)
                item.label:SetPoint("RIGHT", item, "RIGHT", -4, 0)
                item.label:SetJustifyH("LEFT")

                item:SetScript("OnEnter", function(self) self.hl:Show() end)
                item:SetScript("OnLeave", function(self) self.hl:Hide() end)
                fontMenuItems[i] = item
            end
            local col = (i - 1) % cols
            local rowIdx = math.floor((i - 1) / cols)
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", fontMenu, "TOPLEFT", 4 + (col * (colWidth + 4)), -4 - (rowIdx * itemHeight))

            local isSelected = ((db and db.fontPath) or STANDARD_TEXT_FONT):lower() == entry.path:lower()
            item.label:SetText((isSelected and "> " or "   ") .. entry.label)
            local ok1 = pcall(item.label.SetFont, item.label, entry.path, 12, flags)
            if not ok1 then
                item.label:SetFont(STANDARD_TEXT_FONT, 12, flags)
            end
            if isSelected then
                item.label:SetTextColor(0.40, 0.90, 1.00)
            else
                item.label:SetTextColor(1.00, 1.00, 1.00)
            end
            local chosenPath = entry.path
            item:SetScript("OnClick", function()
                db.fontPath = chosenPath
                fontMenu:Hide()
                UpdateFontSelectBtn()
                RefreshAllPlates()
            end)
            item:Show()
        end
        for i = #list + 1, #fontMenuItems do
            fontMenuItems[i]:Hide()
        end
    end

    fontSelectBtn:SetScript("OnClick", function()
        texMenu:Hide()
        if fontMenu:IsShown() then
            fontMenu:Hide()
        else
            PopulateFontMenu()
            fontMenu:Show()
        end
    end)

    texSelectBtn:SetScript("OnClick", function()
        fontMenu:Hide()
        if texMenu:IsShown() then
            texMenu:Hide()
        else
            PopulateTextureMenu()
            texMenu:Show()
        end
    end)

    -- Checkboxes helper with interactive row highlight and contextual tooltip
    local checkboxes = {}
    local function CreateCheck(parent, name, getLabelFn, getDescFn, xOffset, yOffset, getter, setter, rowWidth)
        local cb = CreateFrame("CheckButton", "AggroMeterCheck_" .. name, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
        cb:SetSize(22, 22)

        local cbText = _G[cb:GetName() .. "Text"]
        if cbText then
            cbText:SetText(getLabelFn())
            cbText:SetFontObject("GameFontHighlightSmall")
            cbText:SetTextColor(0.95, 0.95, 0.98)
        end

        cb:SetHitRectInsets(0, -(rowWidth or 140), 0, 0)
        cb:SetScript("OnClick", function(self)
            setter(self:GetChecked() and true or false)
            UpdateFontSelectBtn()
            RefreshAllPlates()
        end)

        cb:HookScript("OnEnter", function(self)
            local lbl = _G[self:GetName() .. "Text"]
            if lbl then lbl:SetTextColor(1.00, 0.85, 0.25) end
        end)
        cb:HookScript("OnLeave", function(self)
            local lbl = _G[self:GetName() .. "Text"]
            if lbl then lbl:SetTextColor(0.95, 0.95, 0.98) end
        end)
        AttachTooltip(cb, getLabelFn, getDescFn)

        cb.Refresh = function(self)
            self:SetChecked(getter() and true or false)
            local lbl = _G[self:GetName() .. "Text"]
            if lbl then lbl:SetText(getLabelFn()) end
        end
        checkboxes[#checkboxes + 1] = cb
        return cb
    end

    -- Font Style Checkboxes inside cardStyle
    CreateCheck(cardStyle, "StyleOutline",
        function() return L.STYLE_OUTLINE end, function() return L.DESC_STYLE_OUTLINE end,
        10, -94, function() return db.fontOutline ~= false end, function(v) db.fontOutline = v end, 65
    )
    CreateCheck(cardStyle, "StyleBold",
        function() return L.STYLE_BOLD end, function() return L.DESC_STYLE_BOLD end,
        106, -94, function() return db.fontBold and true or false end, function(v) db.fontBold = v end, 65
    )
    CreateCheck(cardStyle, "StyleShadow",
        function() return L.STYLE_SHADOW end, function() return L.DESC_STYLE_SHADOW end,
        198, -94, function() return db.fontShadow ~= false end, function(v) db.fontShadow = v end, 65
    )
    CreateCheck(cardStyle, "StyleMono",
        function() return L.STYLE_MONO end, function() return L.DESC_STYLE_MONO end,
        290, -94, function() return db.fontMonochrome and true or false end, function(v) db.fontMonochrome = v end, 60
    )

    -- Bar motion & fill direction inside cardStyle
    CreateCheck(cardStyle, "SmoothBar",
        function() return L.CHECK_SMOOTHBAR end, function() return L.DESC_SMOOTHBAR end,
        10, -124, function() return db.smoothBar ~= false end, function(v) db.smoothBar = v end, 165
    )
    CreateCheck(cardStyle, "InvertBar",
        function() return L.CHECK_INVERTBAR end, function() return L.DESC_INVERTBAR end,
        198, -124, function() return db.invertBar and true or false end, function(v) db.invertBar = v end, 165
    )

    -- =========================================================================
    -- TAB 2: ALERTS & TEXT
    -- =========================================================================
    local cardBarText = CreateSectionCard(pages[2], function() return L.SEC_BARTEXT end, -2, 108)

    CreateCheck(cardBarText, "Enabled",
        function() return L.CHECK_ENABLED end, function() return L.DESC_ENABLED end,
        12, -34, function() return db.enabled end,
        function(v) db.enabled = v; ResetProximityAlertState(); ResetStealthNoticeState(); UpdateAlertControlButton() end, 165
    )
    CreateCheck(cardBarText, "ShowText",
        function() return L.CHECK_SHOWTEXT end, function() return L.DESC_SHOWTEXT end,
        198, -34, function() return db.showText end, function(v) db.showText = v end, 165
    )
    CreateCheck(cardBarText, "StatusText",
        function() return L.CHECK_STATUSTEXT end, function() return L.DESC_STATUSTEXT end,
        12, -64, function() return db.statusText end, function(v) db.statusText = v end, 320
    )

    local cardScreenAlerts = CreateSectionCard(pages[2], function() return L.SEC_SCREENALERTS end, -116, 110)

    CreateCheck(cardScreenAlerts, "Warning",
        function() return L.CHECK_WARNING end, function() return L.DESC_WARNING end,
        12, -34, function() return db.warningEnabled end,
        function(v) db.warningEnabled = v; ResetProximityAlertState() end, 165
    )
    CreateCheck(cardScreenAlerts, "SoundEnabled",
        function() return L.CHECK_SOUND end, function() return L.DESC_SOUND end,
        198, -34, function() return db.soundEnabled ~= false end,
        function(v) db.soundEnabled = v; lastSoundKey = nil end, 165
    )
    CreateCheck(cardScreenAlerts, "PullAlert",
        function() return L.CHECK_PULLALERT end, function() return L.DESC_PULLALERT end,
        12, -66, function() return db.pullAlertEnabled end, function(v) db.pullAlertEnabled = v end, 165
    )
    CreateCheck(cardScreenAlerts, "StealthNotice",
        function() return L.CHECK_STEALTH end, function() return L.DESC_STEALTH end,
        198, -66, function() return db.stealthNoticeEnabled end,
        function(v) db.stealthNoticeEnabled = v; ResetStealthNoticeState() end, 165
    )

    local cardBarAggro = CreateSectionCard(pages[2], function() return L.SEC_BARAGGRO end, -232, 102)

    CreateCheck(cardBarAggro, "AggroGraphic",
        function() return L.CHECK_AGGROGRAPHIC end, function() return L.DESC_AGGROGRAPHIC end,
        12, -34, function() return db.aggroGraphic ~= false end, function(v) db.aggroGraphic = v end, 320
    )
    CreateCheck(cardBarAggro, "KeepGroupAggro",
        function() return L.CHECK_KEEPGROUPAGGRO end, function() return L.DESC_KEEPGROUPAGGRO end,
        12, -64, function() return db.keepGroupAggro ~= false end, function(v) db.keepGroupAggro = v end, 320
    )

    -- =========================================================================
    -- TAB 3: VISIBILITY
    -- =========================================================================
    local cardCombatHide = CreateSectionCard(pages[3], function() return L.SEC_COMBATHIDE end, -2, 134)

    CreateCheck(cardCombatHide, "HideSelf",
        function() return L.CHECK_HIDESELF end, function() return L.DESC_HIDESELF end,
        12, -34, function() return db.hideInCombatSelf ~= false end, function(v) db.hideInCombatSelf = v end, 320
    )
    CreateCheck(cardCombatHide, "HideGroup",
        function() return L.CHECK_HIDEGROUP end, function() return L.DESC_HIDEGROUP end,
        12, -64, function() return db.hideInCombatGroup ~= false end, function(v) db.hideInCombatGroup = v end, 320
    )
    CreateCheck(cardCombatHide, "HideOther",
        function() return L.CHECK_HIDEOTHER end, function() return L.DESC_HIDEOTHER end,
        12, -94, function() return db.hideInCombatOther ~= false end, function(v) db.hideInCombatOther = v end, 320
    )

    local cardDeclutter = CreateSectionCard(pages[3], function() return L.SEC_DECLUTTER end, -142, 164)

    CreateCheck(cardDeclutter, "FadeNonTarget",
        function() return L.CHECK_FADENONTAR end, function() return L.DESC_FADENONTAR end,
        12, -34, function() return db.fadeNonTarget and true or false end, function(v) db.fadeNonTarget = v end, 320
    )
    CreateCheck(cardDeclutter, "HideFarMobs",
        function() return L.CHECK_HIDEFAR end, function() return L.DESC_HIDEFAR end,
        12, -64, function() return db.hideFarMobs and true or false end, function(v) db.hideFarMobs = v end, 320
    )
    CreateCheck(cardDeclutter, "ShowMinimapBtn",
        function() return L.CHECK_MINIMAPBTN end, function() return L.DESC_MINIMAPBTN end,
        12, -94, function() return db.showMinimapButton ~= false end,
        function(v) db.showMinimapButton = v; UpdateAlertControlButton() end, 320
    )
    CreateCheck(cardDeclutter, "ShowFloatBtn",
        function() return L.CHECK_FLOATBTN end, function() return L.DESC_FLOATBTN end,
        12, -124, function() return db.showFloatingButton ~= false end,
        function(v) db.showFloatingButton = v; UpdateAlertControlButton() end, 320
    )

    -- Tab switching logic
    local function SelectTab(idx)
        activeTab = idx
        fontMenu:Hide()
        texMenu:Hide()
        for i = 1, 3 do
            pages[i]:SetShown(i == idx)
            local btn = tabBtns[i]
            btn.label:SetText(tabLabelFns[i]())
            if i == idx then
                btn.bg:SetColorTexture(0.16, 0.20, 0.28, 0.95)
                btn.bottomLine:SetColorTexture(1.00, 0.78, 0.10, 1.00)
                btn.label:SetTextColor(1.00, 0.86, 0.20)
            else
                btn.bg:SetColorTexture(0.07, 0.08, 0.11, 0.80)
                btn.bottomLine:SetColorTexture(0.28, 0.30, 0.36, 0.80)
                btn.label:SetTextColor(0.75, 0.78, 0.84)
            end
        end
    end

    for i = 1, 3 do
        tabBtns[i]:SetScript("OnClick", function() SelectTab(i) end)
    end

    -- Unit toggle button
    local unitBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    unitBtn:SetSize(185, 24)
    unitBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 44)
    local function UpdateUnitBtn()
        if db and db.unitSystem == "meters" then
            unitBtn:SetText(L.BTN_UNIT_TO_YARDS)
        else
            unitBtn:SetText(L.BTN_UNIT_TO_METERS)
        end
    end
    unitBtn:SetScript("OnClick", function()
        db.unitSystem = (db.unitSystem == "meters") and "yards" or "meters"
        UpdateUnitBtn()
        RefreshAllPlates()
    end)
    AttachTooltip(unitBtn, function()
        return (db and db.unitSystem == "meters") and L.BTN_UNIT_TO_YARDS or L.BTN_UNIT_TO_METERS
    end, function() return L.DESC_BTN_UNIT end)

    -- Language toggle button
    local langBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    langBtn:SetSize(185, 24)
    langBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 44)
    local function UpdateLangBtn()
        langBtn:SetText(L.BTN_LANG)
    end
    langBtn:SetScript("OnClick", function()
        db.language = (db.language == "pt") and "en" or "pt"
        ApplyLanguage()
        f:Refresh()
        RefreshAllPlates()
    end)
    AttachTooltip(langBtn, function() return L.BTN_LANG end, function() return L.DESC_BTN_LANG end)

    -- Bottom Buttons
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(150, 24)
    resetBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 14)
    resetBtn:SetScript("OnClick", function()
        db.offsetY           = defaults.offsetY
        db.fontSize          = defaults.fontSize
        db.fontPath          = defaults.fontPath
        db.barTexture        = defaults.barTexture
        db.fontOutline       = defaults.fontOutline
        db.fontBold          = defaults.fontBold
        db.fontShadow        = defaults.fontShadow
        db.fontMonochrome    = defaults.fontMonochrome
        db.invertBar         = defaults.invertBar
        db.aggroGraphic      = defaults.aggroGraphic
        db.hideInCombatSelf  = defaults.hideInCombatSelf
        db.hideInCombatGroup = defaults.hideInCombatGroup
        db.hideInCombatOther = defaults.hideInCombatOther
        db.keepGroupAggro    = defaults.keepGroupAggro
        db.smoothBar         = defaults.smoothBar
        db.fadeNonTarget      = defaults.fadeNonTarget
        db.hideFarMobs        = defaults.hideFarMobs
        db.soundEnabled       = defaults.soundEnabled
        db.showMinimapButton  = defaults.showMinimapButton
        db.showFloatingButton = defaults.showFloatingButton
        db.width              = defaults.width
        db.height             = defaults.height
        db.scale              = defaults.scale
        db.updateRate         = defaults.updateRate
        UpdateAlertControlButton()
        f:Refresh()
        RefreshAllPlates()
    end)
    AttachTooltip(resetBtn, function() return L.BTN_RESET end, function() return L.DESC_BTN_RESET end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(110, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 14)
    closeBtn:SetScript("OnClick", function()
        fontMenu:Hide()
        texMenu:Hide()
        f:Hide()
    end)

    f.Refresh = function(self)
        if titleWidget then titleWidget:SetText(L.CONFIG_TITLE) end
        SelectTab(activeTab)
        for _, hdr in ipairs(sectionHeaders) do
            if hdr.getHeaderFn then hdr:SetText(hdr.getHeaderFn()) end
        end
        for _, s in ipairs(sliders) do s:Refresh() end
        for _, cb in ipairs(checkboxes) do cb:Refresh() end
        UpdateFontSelectBtn()
        UpdateTextureSelectBtn()
        fontMenu:Hide()
        texMenu:Hide()
        UpdateUnitBtn()
        UpdateLangBtn()
        resetBtn:SetText(L.BTN_RESET)
        closeBtn:SetText(L.BTN_CLOSE)
    end

    f:SetScript("OnShow", function(self)
        self:Refresh()
    end)
    f:SetScript("OnHide", function()
        fontMenu:Hide()
        texMenu:Hide()
    end)

    configFrame = f
    return f
end

ToggleConfigFrame = function()
    local f = CreateConfigFrame()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

-------------------------------------------------------------------------------
-- Commands / diagnostics
-------------------------------------------------------------------------------

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff62d8ffAggroMeter:|r " .. tostring(message))
end

local function DebugTarget()
    local targetExists = UnitExists("target")
    if IsSecret(targetExists) or not targetExists then
        Print("No readable target.")
        return
    end

    local radius, uncertain, npcID, override = ComputePullRadius("target")
    local low, high, haveDistance = MeasureRangeBracket("target")
    local level = SafeUnitLevel("target")

    local bracket
    if not haveDistance then
        bracket = "unavailable"
    elseif high then
        bracket = low .. "-" .. high .. " yd"
    else
        bracket = low .. "+ yd"
    end

    local name = SafeUnitName("target")
    local attackable
    if type(UnitCanAttack) == "function" then
        local ok, value = pcall(UnitCanAttack, "player", "target")
        if ok and not IsSecret(value) then attackable = value and true or false end
    end
    local reaction
    if type(UnitReaction) == "function" then
        local ok, value = pcall(UnitReaction, "player", "target")
        if ok and not IsSecret(value) and type(value) == "number" then reaction = value end
    end
    local selectionType
    if type(UnitSelectionType) == "function" then
        local ok, value = pcall(UnitSelectionType, "target", true)
        if ok and not IsSecret(value) and type(value) == "number" then selectionType = value end
    end
    local enemy
    if type(UnitIsEnemy) == "function" then
        local ok, value = pcall(UnitIsEnemy, "player", "target")
        if ok and not IsSecret(value) then enemy = value and true or false end
    end

    Print("target=" .. tostring(name) ..
        " level=" .. tostring(level) ..
        " npcID=" .. tostring(npcID) ..
        " attackable=" .. tostring(attackable) ..
        " reaction=" .. tostring(reaction) ..
        " selection=" .. tostring(selectionType) ..
        " enemy=" .. tostring(enemy))
    local tracked, hostilityReason = EvaluateHostility("target")
    Print("radius=" .. (uncertain and "~" or "") .. tostring(Round(radius)) .. " yd" ..
        " distance=" .. bracket ..
        " tracked=" .. tostring(tracked) ..
        " via=" .. tostring(hostilityReason))

    if override and override.note then
        Print("override: " .. tostring(override.note))
    end
end

SLASH_AGGROMETER1 = "/aggrometer"
SLASH_AGGROMETER2 = "/am"
SlashCmdList.AGGROMETER = function(input)
    local command, arg = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()

    if command == "" or command == "help" then
        Print("/am config (open settings) | on | off | alerts [all|icon|off]")
        Print("/am text | status [on|off] | warning [on|off] | sound [on|off] | stealthnotice [on|off] | pullalert [on|off]")
        Print("/am scale <0.75-1.50> | width <80-220> | height <4-20> | offsety <-50 to 50> | fontsize <6-24>")
        Print("/am font <friz|arial|morpheus|skurri|path> | rate <5-60> | unit [meters|yards] | lang [en|pt] | debug | reload")
        return
    end

    if command == "config" or command == "options" or command == "ui" or command == "menu" then
        ToggleConfigFrame()
    elseif command == "on" then
        db.enabled = true
        ResetProximityAlertState()
        ResetStealthNoticeState()
        UpdateAlertControlButton()
        RefreshAllPlates()
        Print("enabled")
    elseif command == "off" then
        db.enabled = false
        ResetProximityAlertState()
        ResetStealthNoticeState()
        UpdateAlertControlButton()
        RefreshAllPlates()
        Print("disabled")
    elseif command == "text" then
        db.showText = not db.showText
        Print("text " .. (db.showText and "on" or "off"))
    elseif command == "status" then
        local choice = (arg or ""):lower()
        if choice == "on" then
            db.statusText = true
        elseif choice == "off" then
            db.statusText = false
        elseif choice == "" then
            db.statusText = not db.statusText
        else
            Print("usage: /am status [on|off]")
            return
        end
        Print("SAFE/CAUTION/DANGER text " .. (db.statusText and "on" or "off"))
    elseif command == "warning" then
        local choice = (arg or ""):lower()
        if choice == "on" then
            db.warningEnabled = true
        elseif choice == "off" then
            db.warningEnabled = false
        elseif choice == "" then
            db.warningEnabled = not db.warningEnabled
        else
            Print("usage: /am warning [on|off]")
            return
        end
        ResetProximityAlertState()
        Print("warning " .. (db.warningEnabled and "on" or "off"))
    elseif command == "alerts" or command == "alert" then
        local choice = (arg or ""):lower()
        if choice == "" then
            local mode = AlertModeName()
            if mode == "ON" then choice = "icon"
            elseif mode == "ICON" then choice = "off"
            else choice = "all" end
        end
        if not SetAlertMode(choice, true) then
            Print("usage: /am alerts [all|icon|off]")
        end
    elseif command == "stealthnotice" or command == "stealthalert" then
        local choice = (arg or ""):lower()
        if choice == "on" then
            db.stealthNoticeEnabled = true
        elseif choice == "off" then
            db.stealthNoticeEnabled = false
        elseif choice == "" then
            db.stealthNoticeEnabled = not db.stealthNoticeEnabled
        else
            Print("usage: /am stealthnotice [on|off]")
            return
        end
        ResetStealthNoticeState()
        Print("Stealth pre-detection alert " .. (db.stealthNoticeEnabled and "on" or "off"))
    elseif command == "sound" then
        local choice = (arg or ""):lower()
        if choice == "on" then
            db.soundEnabled = true
        elseif choice == "off" then
            db.soundEnabled = false
        elseif choice == "" then
            db.soundEnabled = not db.soundEnabled
        else
            Print("usage: /am sound [on|off]")
            return
        end
        lastSoundKey = nil
        UpdateAlertControlButton()
        Print("sound " .. (db.soundEnabled and "on" or "off"))
    elseif command == "pullalert" then
        local choice = (arg or ""):lower()
        if choice == "on" then
            db.pullAlertEnabled = true
        elseif choice == "off" then
            db.pullAlertEnabled = false
        elseif choice == "" then
            db.pullAlertEnabled = not db.pullAlertEnabled
        else
            Print("usage: /am pullalert [on|off]")
            return
        end
        Print("actual aggro alert " .. (db.pullAlertEnabled and "on" or "off"))
    elseif command == "scale" then
        local scale = tonumber(arg)
        if scale then
            db.scale = Clamp(scale, 0.75, 1.50)
            RefreshAllPlates()
            Print(string.format("scale %.2f", db.scale))
        else
            Print("usage: /am scale <0.75-1.50>")
        end
    elseif command == "width" then
        local width = tonumber(arg)
        if width then
            db.width = Clamp(width, 80, 220)
            RefreshAllPlates()
            Print("width " .. db.width)
        else
            Print("usage: /am width <80-220>")
        end
    elseif command == "height" then
        local height = tonumber(arg)
        if height then
            db.height = Clamp(height, 4, 20)
            RefreshAllPlates()
            Print("height " .. db.height)
        else
            Print("usage: /am height <4-20>")
        end
    elseif command == "offsety" or command == "y" then
        local offset = tonumber(arg)
        if offset then
            db.offsetY = Clamp(offset, -50, 50)
            RefreshAllPlates()
            Print("offsetY " .. db.offsetY)
        else
            Print("usage: /am offsety <-50 to 50>")
        end
    elseif command == "fontsize" or command == "size" then
        local size = tonumber(arg)
        if size then
            db.fontSize = Clamp(size, 6, 24)
            RefreshAllPlates()
            Print("fontSize " .. db.fontSize)
        else
            Print("usage: /am fontsize <6-24>")
        end
    elseif command == "font" then
        local choice = (arg or ""):lower()
        if choice == "default" or choice == "friz" then
            db.fontPath = "Fonts\\FRIZQT__.TTF"
        elseif choice == "arial" then
            db.fontPath = "Fonts\\ARIALN.TTF"
        elseif choice == "morpheus" then
            db.fontPath = "Fonts\\MORPHEUS.TTF"
        elseif choice == "skurri" then
            db.fontPath = "Fonts\\SKURRI.TTF"
        elseif choice == "2002" then
            db.fontPath = "Fonts\\2002.TTF"
        elseif choice == "2002b" or choice == "2002bold" then
            db.fontPath = "Fonts\\2002B.TTF"
        elseif choice == "friends" then
            db.fontPath = "Fonts\\FRIENDS.TTF"
        elseif choice == "nimrod" then
            db.fontPath = "Fonts\\NIM_____.ttf"
        elseif arg and arg ~= "" then
            db.fontPath = arg
        else
            Print("usage: /am font <friz|arial|morpheus|skurri|2002|2002b|friends|nimrod|path\\to\\font.ttf>")
            return
        end
        RefreshAllPlates()
        Print("font " .. tostring(db.fontPath))
    elseif command == "invert" or command == "invertbar" then
        local choice = (arg or ""):lower()
        if choice == "on" then
            db.invertBar = true
        elseif choice == "off" then
            db.invertBar = false
        elseif choice == "" then
            db.invertBar = not db.invertBar
        else
            Print("usage: /am invert [on|off]")
            return
        end
        RefreshAllPlates()
        Print("invertBar " .. (db.invertBar and "on" or "off"))
    elseif command == "rate" or command == "updaterate" or command == "fps" then
        local rate = tonumber(arg)
        if rate then
            db.updateRate = Clamp(Round(rate), 5, 60)
            if configFrame and configFrame:IsShown() then
                configFrame:Refresh()
            end
            Print(string.format("updateRate %d Hz (%d ms)", db.updateRate, Round(1000 / db.updateRate)))
        else
            Print("usage: /am rate <5-60>")
        end
    elseif command == "hideself" then
        local choice = (arg or ""):lower()
        if choice == "on" then
            db.hideInCombatSelf = true
        elseif choice == "off" then
            db.hideInCombatSelf = false
        elseif choice == "" then
            db.hideInCombatSelf = (db.hideInCombatSelf == false)
        else
            Print("usage: /am hideself [on|off]")
            return
        end
        RefreshAllPlates()
        Print("hideInCombatSelf " .. (db.hideInCombatSelf and "on" or "off"))
    elseif command == "hidegroup" then
        local choice = (arg or ""):lower()
        if choice == "on" then
            db.hideInCombatGroup = true
        elseif choice == "off" then
            db.hideInCombatGroup = false
        elseif choice == "" then
            db.hideInCombatGroup = (db.hideInCombatGroup == false)
        else
            Print("usage: /am hidegroup [on|off]")
            return
        end
        RefreshAllPlates()
        Print("hideInCombatGroup " .. (db.hideInCombatGroup and "on" or "off"))
    elseif command == "hideother" then
        local choice = (arg or ""):lower()
        if choice == "on" then
            db.hideInCombatOther = true
        elseif choice == "off" then
            db.hideInCombatOther = false
        elseif choice == "" then
            db.hideInCombatOther = (db.hideInCombatOther == false)
        else
            Print("usage: /am hideother [on|off]")
            return
        end
        RefreshAllPlates()
        Print("hideInCombatOther " .. (db.hideInCombatOther and "on" or "off"))
    elseif command == "smooth" then
        local choice = (arg or ""):lower()
        if choice == "on" then
            db.smoothBar = true
        elseif choice == "off" then
            db.smoothBar = false
        elseif choice == "" then
            db.smoothBar = (db.smoothBar == false)
        else
            Print("usage: /am smooth [on|off]")
            return
        end
        RefreshAllPlates()
        Print("smoothBar " .. (db.smoothBar and "on" or "off"))
    elseif command == "dim" or command == "fade" then
        local choice = (arg or ""):lower()
        if choice == "on" then
            db.fadeNonTarget = true
        elseif choice == "off" then
            db.fadeNonTarget = false
        elseif choice == "" then
            db.fadeNonTarget = not db.fadeNonTarget
        else
            Print("usage: /am dim [on|off]")
            return
        end
        RefreshAllPlates()
        Print("fadeNonTarget " .. (db.fadeNonTarget and "on" or "off"))
    elseif command == "hidefar" then
        local choice = (arg or ""):lower()
        if choice == "on" then
            db.hideFarMobs = true
        elseif choice == "off" then
            db.hideFarMobs = false
        elseif choice == "" then
            db.hideFarMobs = not db.hideFarMobs
        else
            Print("usage: /am hidefar [on|off]")
            return
        end
        RefreshAllPlates()
        Print("hideFarMobs " .. (db.hideFarMobs and "on" or "off"))
    elseif command == "keepaggro" or command == "groupaggro" then
        local choice = (arg or ""):lower()
        if choice == "on" then
            db.keepGroupAggro = true
        elseif choice == "off" then
            db.keepGroupAggro = false
        elseif choice == "" then
            db.keepGroupAggro = (db.keepGroupAggro == false)
        else
            Print("usage: /am keepaggro [on|off]")
            return
        end
        RefreshAllPlates()
        Print("keepGroupAggro " .. (db.keepGroupAggro and "on" or "off"))
    elseif command == "debug" then
        local _, build, _, interface = GetBuildInfo()
        local checkerCount = #GetCheckers()
        Print("v=" .. ADDON_VERSION .. " build=" .. tostring(build) .. " interface=" .. tostring(interface) ..
            " checkers=" .. checkerCount .. " spells=" .. #spellCheckers .. " stages=" .. DISPLAY_STAGES ..
            " activePlates=" .. tostring(#C_NamePlate.GetNamePlates()))
        DebugTarget()
    elseif command == "reload" then
        LoadRangeItems()
        LoadSpellRangeChecks()
        SetRaceInteractRanges()
        wipe(engagementStates)
        RefreshAllPlates()
        Print("range data refreshed")
    elseif command == "unit" or command == "units" then
        local choice = (arg or ""):lower()
        if choice == "meters" or choice == "m" then
            db.unitSystem = "meters"
        elseif choice == "yards" or choice == "y" or choice == "yd" then
            db.unitSystem = "yards"
        elseif choice == "" then
            db.unitSystem = (db.unitSystem == "meters") and "yards" or "meters"
        else
            Print("usage: /am unit [meters|yards]")
            return
        end
        RefreshAllPlates()
        Print("unit: " .. (db.unitSystem == "meters" and "meters (M)" or "yards (yd)"))
    elseif command == "lang" or command == "language" then
        local choice = (arg or ""):lower()
        if choice == "en" or choice == "english" then
            db.language = "en"
        elseif choice == "pt" or choice == "portugues" or choice == "portugu\195\170s" then
            db.language = "pt"
        elseif choice == "" then
            db.language = (db.language == "pt") and "en" or "pt"
        else
            Print("usage: /am lang [en|pt]")
            return
        end
        ApplyLanguage()
        if configFrame and configFrame:IsShown() then
            configFrame:Refresh()
        end
        RefreshAllPlates()
        Print("language: " .. (db.language == "pt" and "Portugu\195\170s" or "English"))
    else
        Print("unknown command. Use /am help")
    end
end

-------------------------------------------------------------------------------
-- Events / update loop
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("SPELLS_CHANGED")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= addonName then return end
        AggroMeterDB = AggroMeterDB or {}
        if next(AggroMeterDB) == nil and type(_G.AggroWarningDB) == "table" then
            for key, value in pairs(_G.AggroWarningDB) do
                if key ~= "calibration" and key ~= "calibrationEnabled" and key ~= "calibrationDefault060" then
                    AggroMeterDB[key] = value
                end
            end
        end
        if AggroMeterDB.alertButtonPoint == nil and AggroMeterDB.aiButtonPoint ~= nil then
            AggroMeterDB.alertButtonPoint = AggroMeterDB.aiButtonPoint
            AggroMeterDB.alertButtonRelativePoint = AggroMeterDB.aiButtonRelativePoint
            AggroMeterDB.alertButtonX = AggroMeterDB.aiButtonX
            AggroMeterDB.alertButtonY = AggroMeterDB.aiButtonY
        end
        CopyDefaults(defaults, AggroMeterDB)
        AggroMeterDB.barTexture = SanitizeMediaPath(AggroMeterDB.barTexture)
        AggroMeterDB.fontPath = SanitizeMediaPath(AggroMeterDB.fontPath)
        db = AggroMeterDB
        ApplyLanguage()
        return
    end

    if not db then return end

    if event == "PLAYER_LOGIN" then
        SetRaceInteractRanges()
        LoadRangeItems()
        LoadSpellRangeChecks()
        CreateAlertControl()
        Print(string.format(L.LOGIN, ADDON_VERSION))
    elseif event == "PLAYER_LEVEL_UP" then
        LoadSpellRangeChecks()
        RefreshAllPlates()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        OnPlateAdded(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        OnPlateRemoved(unit)
    elseif event == "SPELLS_CHANGED" then
        LoadSpellRangeChecks()
        RefreshAllPlates()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemID, success = ...
        OnItemLoaded(itemID, success)
    end
end)

local elapsed = 0
eventFrame:SetScript("OnUpdate", function(_, delta)
    if not db or not db.enabled then return end

    if db.smoothBar ~= false then
        for _, row in pairs(activeRows) do
            AnimateRowBar(row, delta)
        end
    end

    elapsed = elapsed + delta
    local interval = 1 / Clamp(db.updateRate or 25, 5, 60)
    if elapsed < interval then return end
    local stepDelta = elapsed
    elapsed = 0

    for unit, row in pairs(activeRows) do
        if UnitExists(unit) then
            UpdateRow(row, unit, stepDelta)
            UpdateEngagementState(unit, row)
        else
            OnPlateRemoved(unit)
        end
    end

    UpdateTargetProximityAlert()
    UpdateStealthPreDetectionNotice()
end)
