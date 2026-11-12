-- NRI_Detect.lua
-- Finds which roles a nameplate unit has.
NRI_Detect = {}

local Detect = NRI_Detect
local Utils = NRI_Utils
local Roles = NRI_Roles
local Safe = Utils.Safe

local serviceCache = {} -- npcID -> { role = true } from subtitle/name (session)
local questCache = {}   -- unit GUID -> bool, cleared on quest log changes

---------------------------------------------------------
-- Tooltip

local QUEST_LINE_TYPES = {}
do
    local lineTypes = Enum and Enum.TooltipDataLineType
    if lineTypes then
        for _, name in ipairs({ "QuestObjective", "QuestTitle", "QuestPlayer" }) do
            if lineTypes[name] then
                QUEST_LINE_TYPES[lineTypes[name]] = true
            end
        end
    end
end

local function GetTooltipLines(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then
        return nil
    end
    local data = Safe(C_TooltipInfo.GetUnit, unit)
    return data and data.lines
end

local function LineText(line)
    local text = line and line.leftText
    if type(text) ~= "string" or Utils.IsSecret(text) then
        return nil
    end
    return text
end

-- The NPC subtitle is the line under the name, unless that line is the level line.
local function GetSubtitle(lines)
    local text = lines and LineText(lines[2])
    if not text or text == "" then
        return nil
    end
    if LEVEL and text:find(LEVEL, 1, true) then
        return nil
    end
    return (text:gsub("^<", ""):gsub(">$", ""))
end

local function AddKeywordRoles(target, text, keywords)
    if not text then
        return
    end
    text = text:lower()
    for role, list in pairs(keywords) do
        for _, keyword in ipairs(list) do
            if text:find(keyword, 1, true) then
                target[role] = true
                break
            end
        end
    end
end

-- Whole-subtitle match, with an optional rank in front ("Journeyman Blacksmith").
local function AddTitleRoles(target, text, titles)
    if not text then
        return
    end
    text = strtrim(text:lower())
    for _, rank in ipairs(Roles.SUBTITLE_RANKS) do
        if text:sub(1, #rank + 1) == rank .. " " then
            text = text:sub(#rank + 2)
            break
        end
    end
    for role, list in pairs(titles) do
        for _, title in ipairs(list) do
            if text == title then
                target[role] = true
                break
            end
        end
    end
end

---------------------------------------------------------
-- Services (subtitle + NPC name)

local function GetServices(unit, npcID)
    local services = npcID and serviceCache[npcID]
    if not services then
        services = {}
        local lines = GetTooltipLines(unit)
        local subtitle = GetSubtitle(lines)
        AddKeywordRoles(services, subtitle, Roles.SUBTITLE_KEYWORDS)
        AddTitleRoles(services, subtitle, Roles.SUBTITLE_TITLES)
        AddKeywordRoles(services, lines and LineText(lines[1]) or Safe(UnitName, unit), Roles.NAME_KEYWORDS)
        if npcID and lines then
            serviceCache[npcID] = services
        end
    end
    return services
end

---------------------------------------------------------
-- Quest objective

local function IsQuestUnit(unit)
    local guid = Safe(UnitGUID, unit)
    if guid and questCache[guid] ~= nil then
        return questCache[guid]
    end

    local related = C_QuestLog and Safe(C_QuestLog.UnitIsRelatedToActiveQuest, unit) or false
    if not related then
        local lines = GetTooltipLines(unit)
        if lines then
            for _, line in ipairs(lines) do
                if line.type and QUEST_LINE_TYPES[line.type] then
                    related = true
                    break
                end
            end
        end
    end

    if guid then
        questCache[guid] = related
    end
    return related
end

---------------------------------------------------------
-- State roles

local STATE_CHECKS = {
    quest_objective = function(unit, s) return not s.isPlayer and IsQuestUnit(unit) end,
    targeting_you   = function(unit) return Safe(UnitIsUnit, unit .. "target", "player") end,
    boss            = function(unit, s)
        return s.classification == "worldboss" or (not s.isPlayer and Safe(UnitLevel, unit) == -1)
    end,
    rare            = function(_, s) return s.classification == "rare" or s.classification == "rareelite" end,
    elite           = function(_, s) return s.classification == "elite" or s.classification == "rareelite" end,
    caster          = function(_, s) return not s.isPlayer and s.hasMana end,
    in_combat       = function(_, s) return s.inCombat end,
    attackable      = function(_, s) return s.canAttack end,
    hostile         = function(_, s) return s.reaction ~= nil and s.reaction <= 3 end,
    neutral         = function(_, s) return s.reaction == 4 end,
    friendly        = function(_, s) return s.reaction ~= nil and s.reaction >= 5 end,
    tapped          = function(unit) return Safe(UnitIsTapDenied, unit) end,
    battle_pet      = function(unit)
        return Safe(UnitIsWildBattlePet, unit) or Safe(UnitIsBattlePetCompanion, unit)
    end,
}

---------------------------------------------------------
-- Public

-- Returns the wanted roles the unit has, in catalog order.
function Detect.GetRoles(unit, state, wanted)
    local result = {}
    local services
    for _, role in ipairs(Roles.LIST) do
        if wanted[role.key] then
            local has
            if role.source == "service" then
                if not state.isPlayer then
                    services = services or GetServices(unit, Utils.GetNpcID(unit))
                    has = services[role.key]
                end
            else
                local check = STATE_CHECKS[role.key]
                has = check and check(unit, state)
            end
            if has then
                result[#result + 1] = role.key
            end
        end
    end
    return result
end

function Detect.ClearQuestCache()
    wipe(questCache)
end

function Detect.ClearServiceCache()
    wipe(serviceCache)
end
