-- NRI_Conditions.lua
-- Rule conditions. A rule matches a unit when ALL of its selected conditions are true.
NRI_Conditions = {}

local Conditions = NRI_Conditions
local Utils = NRI_Utils
local Safe = Utils.Safe

---------------------------------------------------------
-- Catalog, grouped like the options show them.

Conditions.GROUPS = {
    { key = "attack",    conditions = { "can-attack", "cannot-attack" } },
    { key = "combat",    conditions = { "in-combat", "out-combat" } },
    { key = "player_combat", conditions = { "player-in-combat", "player-out-combat" } },
    { key = "alignment", conditions = { "friend", "hostile", "neutral" } },
    { key = "special",   conditions = { "player", "npc", "minion" } },
    { key = "class",     conditions = { "class-rare", "class-elite", "class-worldboss", "class-normal",
                                        "class-minor", "class-trivial" } },
    { key = "location",  conditions = { "loc-world", "loc-resting", "loc-dungeon", "loc-raid",
                                        "loc-pvp", "loc-delve" } },
    { key = "elite",     conditions = { "elite-boss", "elite-miniboss", "elite-caster", "elite-melee",
                                        "elite-trivial" } },
    { key = "delve",     conditions = { "delve-boss", "delve-elite", "delve-rare", "delve-caster",
                                        "delve-melee", "delve-trivial" } },
    { key = "target",    conditions = { "is-target", "not-target" } },
    { key = "modifier",  conditions = { "mod-alt", "mod-ctrl", "mod-shift", "mod-none" } },
    { key = "modifier_toggle", conditions = { "toggle-alt", "toggle-ctrl", "toggle-shift" } },
}

---------------------------------------------------------
-- Location (shared by all plates, refreshed on zone events)

local location = { kind = "world", resting = false }

function Conditions.UpdateLocation()
    local _, instanceType = IsInInstance()
    local kind = "world"
    if instanceType == "party" then
        kind = "dungeon"
    elseif instanceType == "raid" then
        kind = "raid"
    elseif instanceType == "pvp" or instanceType == "arena" then
        kind = "pvp"
    elseif instanceType == "scenario" then
        local isDelve = C_PartyInfo and Safe(C_PartyInfo.IsDelveInProgress)
        kind = isDelve and "delve" or "scenario"
    end
    location.kind = kind
    location.resting = IsResting() and true or false
end

---------------------------------------------------------
-- Modifier toggles: each press of the key flips its condition (for this session).

Conditions.toggles = { alt = false, ctrl = false, shift = false }

local MODIFIER_KEYS = {
    LALT = "alt", RALT = "alt",
    LCTRL = "ctrl", RCTRL = "ctrl",
    LSHIFT = "shift", RSHIFT = "shift",
}

-- MODIFIER_STATE_CHANGED payload. Returns the toggle ("alt", "ctrl", "shift") that changed, if any.
function Conditions.OnModifierChanged(key, down)
    local toggle = MODIFIER_KEYS[key]
    if toggle and down == 1 then
        Conditions.toggles[toggle] = not Conditions.toggles[toggle]
        return toggle
    end
    return nil
end

-- Toggle state of a rule: nil when the rule has no toggle condition,
-- otherwise true only when all of its toggles are on.
function Conditions.RuleToggleState(rule, onlyToggle)
    local uses, on = false, true
    for toggle, value in pairs(Conditions.toggles) do
        if rule.criteria["toggle-" .. toggle] then
            uses = uses or (onlyToggle == nil or toggle == onlyToggle)
            on = on and value
        end
    end
    if not uses then
        return nil
    end
    return on
end

---------------------------------------------------------
-- Mob type inside dungeons and delves.
-- Heuristic: bosses are skull level or 2+ levels above you, mini-bosses 1 level above,
-- other elites are split by mana (caster) or not (melee), non-elites are trivial.

local function MobType(state, unit, allowRare)
    local classification = state.classification
    if not classification or state.isPlayer then
        return nil
    end
    local level = Safe(UnitLevel, unit)
    local playerLevel = Safe(UnitEffectiveLevel, "player") or Safe(UnitLevel, "player")
    if level == -1 or classification == "worldboss" then
        return "boss"
    end
    if allowRare and (classification == "rare" or classification == "rareelite") then
        return "rare"
    end
    if classification == "elite" or classification == "rareelite" then
        if level and playerLevel then
            if level >= playerLevel + 2 then
                return "boss"
            elseif level == playerLevel + 1 then
                return "miniboss"
            end
        end
        return state.hasMana and "caster" or "melee"
    end
    return "trivial"
end

---------------------------------------------------------
-- Unit state used by the condition checks (one per refresh)

function Conditions.BuildState(unit)
    local state = {}
    state.canAttack = Safe(UnitCanAttack, "player", unit)
    state.reaction = Safe(UnitReaction, unit, "player")
    state.isPlayer = Safe(UnitIsPlayer, unit)
    state.isMinion = not state.isPlayer and Safe(UnitPlayerControlled, unit) or false
    state.classification = Safe(UnitClassification, unit)
    state.inCombat = Safe(UnitAffectingCombat, unit)
    state.isTarget = Safe(UnitIsUnit, unit, "target")
    state.hasMana = Safe(UnitPowerType, unit) == 0

    local eliteType = MobType(state, unit, false)
    state.eliteType = (location.kind == "dungeon" or location.kind == "raid") and eliteType or nil
    state.delveType = location.kind == "delve" and MobType(state, unit, true) or nil
    return state
end

---------------------------------------------------------
-- Checks

local function IsClass(state, ...)
    for i = 1, select("#", ...) do
        if state.classification == select(i, ...) then
            return true
        end
    end
    return false
end

local CHECKS = {
    ["can-attack"]      = function(s) return s.canAttack == true end,
    ["cannot-attack"]   = function(s) return s.canAttack == false end,

    ["in-combat"]       = function(s) return s.inCombat == true end,
    ["out-combat"]      = function(s) return s.inCombat == false end,

    ["player-in-combat"]  = function() return UnitAffectingCombat("player") and true or false end,
    ["player-out-combat"] = function() return not UnitAffectingCombat("player") end,

    ["friend"]          = function(s) return s.reaction ~= nil and s.reaction >= 5 end,
    ["hostile"]         = function(s) return s.reaction ~= nil and s.reaction <= 3 end,
    ["neutral"]         = function(s) return s.reaction == 4 end,

    ["player"]          = function(s) return s.isPlayer == true end,
    ["npc"]             = function(s) return s.isPlayer == false and not s.isMinion end,
    ["minion"]          = function(s) return s.isMinion == true end,

    ["class-rare"]      = function(s) return IsClass(s, "rare", "rareelite") end,
    ["class-elite"]     = function(s) return IsClass(s, "elite", "rareelite") end,
    ["class-worldboss"] = function(s) return IsClass(s, "worldboss") end,
    ["class-normal"]    = function(s) return IsClass(s, "normal") end,
    ["class-minor"]     = function(s) return IsClass(s, "minus") end,
    ["class-trivial"]   = function(s) return IsClass(s, "trivial") end,

    ["loc-world"]       = function() return location.kind == "world" end,
    ["loc-resting"]     = function() return location.resting end,
    ["loc-dungeon"]     = function() return location.kind == "dungeon" end,
    ["loc-raid"]        = function() return location.kind == "raid" end,
    ["loc-pvp"]         = function() return location.kind == "pvp" end,
    ["loc-delve"]       = function() return location.kind == "delve" end,

    ["elite-boss"]      = function(s) return s.eliteType == "boss" end,
    ["elite-miniboss"]  = function(s) return s.eliteType == "miniboss" end,
    ["elite-caster"]    = function(s) return s.eliteType == "caster" end,
    ["elite-melee"]     = function(s) return s.eliteType == "melee" end,
    ["elite-trivial"]   = function(s) return s.eliteType == "trivial" end,

    ["delve-boss"]      = function(s) return s.delveType == "boss" end,
    ["delve-elite"]     = function(s) return s.delveType == "miniboss" end,
    ["delve-rare"]      = function(s) return s.delveType == "rare" end,
    ["delve-caster"]    = function(s) return s.delveType == "caster" end,
    ["delve-melee"]     = function(s) return s.delveType == "melee" end,
    ["delve-trivial"]   = function(s) return s.delveType == "trivial" end,

    ["is-target"]       = function(s) return s.isTarget == true end,
    ["not-target"]      = function(s) return s.isTarget ~= true end,

    ["mod-alt"]         = function() return IsAltKeyDown() end,
    ["mod-ctrl"]        = function() return IsControlKeyDown() end,
    ["mod-shift"]       = function() return IsShiftKeyDown() end,
    ["mod-none"]        = function() return not IsModifierKeyDown() end,

    ["toggle-alt"]      = function() return Conditions.toggles.alt end,
    ["toggle-ctrl"]     = function() return Conditions.toggles.ctrl end,
    ["toggle-shift"]    = function() return Conditions.toggles.shift end,
}

---------------------------------------------------------
-- Distance bands (rule filters).
-- The game gives addons no exact distance to NPCs, only interact-distance checks,
-- and those only work out of combat. In combat the band is "unknown" and the
-- distance filter does not apply (use the player combat conditions for that).

Conditions.DISTANCE_BANDS = { "close", "medium", "far" }

local INTERACT_TRADE = 2  -- ~11 yards
local INTERACT_FOLLOW = 4 -- ~28 yards

function Conditions.GetDistanceBand(unit)
    if InCombatLockdown() then
        return "unknown"
    end
    local close = Safe(CheckInteractDistance, unit, INTERACT_TRADE)
    if close then
        return "close"
    end
    local medium = Safe(CheckInteractDistance, unit, INTERACT_FOLLOW)
    if medium then
        return "medium"
    elseif close == nil and medium == nil then
        return "unknown"
    end
    return "far"
end

-- True when the rule hides any distance band (so distances must be tracked).
function Conditions.UsesDistance(rule)
    return next(rule.distance_hidden) ~= nil
end

function Conditions.Matches(criteria, state)
    for key, enabled in pairs(criteria) do
        if enabled then
            local check = CHECKS[key]
            if check and not check(state) then
                return false
            end
        end
    end
    return true
end
