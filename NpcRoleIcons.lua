-- NpcRoleIcons.lua
NpcRoleIcons = LibStub("AceAddon-3.0"):NewAddon("NpcRoleIcons", "AceConsole-3.0", "AceEvent-3.0")

local Addon = NpcRoleIcons
local L = LibStub("AceLocale-3.0"):GetLocale("NpcRoleIcons", false)
local Utils = NRI_Utils
local Conditions = NRI_Conditions
local Detect = NRI_Detect
local Display = NRI_Display
local Options = NRI_Options

local MAX_NAMEPLATES = 40
local dirtyUnits = {}
local dirtyAll = false
local flushQueued = false
local DISTANCE_INTERVAL = 0.25
local distanceBands = {} -- unit -> last distance band, only for plates whose rule filters on distance

-- Events that can change any plate.
local REFRESH_ALL_EVENTS = {
    "PLAYER_TARGET_CHANGED",
    "PLAYER_UPDATE_RESTING",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
}

-- Unit events that can change one plate.
local UNIT_EVENTS = {
    "UNIT_FACTION",
    "UNIT_FLAGS",
    "UNIT_CLASSIFICATION_CHANGED",
    "UNIT_LEVEL",
    "UNIT_TARGET",
}

---------------------------------------------------------
-- Addon events

function Addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("NpcRoleIconsDB", Options.defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
    self:LoadProfile()
    self.db.global.learned = nil -- learned interactions were removed

    local options = Options.options
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    options.args.profiles.order = 100
    Options.BuildRules()

    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(Options.APP_NAME, options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(Options.APP_NAME, Options.APP_NAME)

    self:RegisterChatCommand("nri", "SlashCommand")
    self:RegisterChatCommand("npcroleicons", "SlashCommand")
end

function Addon:OnEnable()
    self:SafeRegisterEvent("NAME_PLATE_UNIT_ADDED", "OnPlateAdded")
    self:SafeRegisterEvent("NAME_PLATE_UNIT_REMOVED", "OnPlateRemoved")
    for _, event in ipairs(REFRESH_ALL_EVENTS) do
        self:SafeRegisterEvent(event, "RefreshAll")
    end
    for _, event in ipairs(UNIT_EVENTS) do
        self:SafeRegisterEvent(event, "OnUnitEvent")
    end
    self:SafeRegisterEvent("MODIFIER_STATE_CHANGED", "OnModifierChanged")
    self:SafeRegisterEvent("PLAYER_ENTERING_WORLD", "OnLocationChanged")
    self:SafeRegisterEvent("ZONE_CHANGED_NEW_AREA", "OnLocationChanged")
    self:SafeRegisterEvent("QUEST_LOG_UPDATE", "OnQuestsChanged")
    self:SafeRegisterEvent("UNIT_QUEST_LOG_CHANGED", "OnQuestsChanged")
    self:SafeRegisterEvent("QUEST_DETAIL", "OnQuestOffered")

    Conditions.UpdateLocation()
    self:ApplySettings()
    C_Timer.NewTicker(DISTANCE_INTERVAL, function()
        self:CheckDistances()
    end)
end

-- Unknown events (renamed by a patch) are skipped.
function Addon:SafeRegisterEvent(event, handler)
    pcall(self.RegisterEvent, self, event, handler)
end

function Addon:OnProfileChanged()
    self:LoadProfile()
    Options.BuildRules()
    LibStub("AceConfigRegistry-3.0"):NotifyChange(Options.APP_NAME)
    self:ApplySettings()
end

function Addon:LoadProfile()
    Options.EnsureRules(self.db.profile)
    Options.db = self.db.profile
end

-- Applies every option. Called when a general option changes.
function Addon:ApplySettings()
    self:RefreshAll()
end

function Addon:SlashCommand()
    LibStub("AceConfigDialog-3.0"):Open(Options.APP_NAME)
end

---------------------------------------------------------
-- Refresh (batched to the next frame)

local function Flush()
    flushQueued = false
    if dirtyAll then
        dirtyAll = false
        wipe(dirtyUnits)
        -- Walk the unit tokens rather than the plate frames: plates that were already
        -- shown before we loaded (e.g. after /reload) never send NAME_PLATE_UNIT_ADDED.
        for i = 1, MAX_NAMEPLATES do
            local unit = "nameplate" .. i
            if Utils.Safe(UnitExists, unit) then
                Addon:UpdateUnit(unit)
            end
        end
        return
    end
    for unit in pairs(dirtyUnits) do
        Addon:UpdateUnit(unit)
    end
    wipe(dirtyUnits)
end

local function QueueFlush()
    if not flushQueued then
        flushQueued = true
        C_Timer.After(0, Flush)
    end
end

function Addon:RefreshAll()
    dirtyAll = true
    QueueFlush()
end

function Addon:RefreshUnit(unit)
    dirtyUnits[unit] = true
    QueueFlush()
end

local function FindRule(state)
    for _, rule in ipairs(Options.db.rules) do
        if rule.enabled and Conditions.Matches(rule.criteria, state) then
            return rule
        end
    end
    return nil
end

function Addon:UpdateUnit(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then
        return -- gone, or a forbidden plate (friendly plates inside instances)
    end
    if not Options.db.enabled or not Utils.Safe(UnitExists, unit) then
        distanceBands[unit] = nil
        Display.Hide(plate)
        return
    end

    local state = Conditions.BuildState(unit)
    local rule = FindRule(state)
    if not rule then
        distanceBands[unit] = nil
        Display.Hide(plate)
        return
    end

    -- Filters
    if Conditions.UsesDistance(rule) then
        local band = Conditions.GetDistanceBand(unit)
        distanceBands[unit] = band
        if rule.distance_hidden[band] then
            Display.Hide(plate)
            return
        end
    else
        distanceBands[unit] = nil
    end

    Display.Show(plate, Options.db, Detect.GetRoles(unit, state, rule.roles))
end

-- No event tells when a unit gets closer: poll the plates that filter on distance.
function Addon:CheckDistances()
    for unit, band in pairs(distanceBands) do
        if Conditions.GetDistanceBand(unit) ~= band then
            self:RefreshUnit(unit)
        end
    end
end

---------------------------------------------------------
-- Game events

function Addon:OnPlateAdded(_, unit)
    self:RefreshUnit(unit)
end

function Addon:OnPlateRemoved(_, unit)
    dirtyUnits[unit] = nil
    distanceBands[unit] = nil
    Display.Hide(C_NamePlate.GetNamePlateForUnit(unit))
end

function Addon:OnUnitEvent(_, unit)
    if Utils.IsNameplateUnit(unit) then
        self:RefreshUnit(unit)
    end
end

-- Both hold and toggle modifier conditions can change.
function Addon:OnModifierChanged(_, key, down)
    local toggle = Conditions.OnModifierChanged(key, down)
    if toggle and Options.db.toggle_message then
        self:ShowToggleMessages(toggle)
    end
    self:RefreshAll()
end

-- Top-center message for each enabled rule that uses the toggle that just changed.
function Addon:ShowToggleMessages(toggle)
    for _, rule in ipairs(Options.db.rules) do
        if rule.enabled then
            local on = Conditions.RuleToggleState(rule, toggle)
            if on ~= nil then
                local text = format(on and L["NRI.msg.toggle_on"] or L["NRI.msg.toggle_off"], rule.name or "")
                if on then
                    UIErrorsFrame:AddMessage(text, 0.2, 1, 0.2)
                else
                    UIErrorsFrame:AddMessage(text, 1, 0.3, 0.3)
                end
            end
        end
    end
end

function Addon:OnLocationChanged()
    Conditions.UpdateLocation()
    self:RefreshAll()
    -- Tooltip data and plates can still be settling right after a load screen or /reload.
    C_Timer.After(1, function()
        self:RefreshAll()
    end)
end

function Addon:OnQuestsChanged()
    Detect.ClearQuestCache()
    self:RefreshAll()
end
