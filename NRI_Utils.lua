-- NRI_Utils.lua
NRI_Utils = {}

local Utils = NRI_Utils

---------------------------------------------------------
-- Secret-safe API calls.
-- Since Midnight, some unit APIs return "secret" values (in combat, in instances)
-- that addons cannot compare. Those are treated as unknown (nil).

local issecretvalue = issecretvalue

function Utils.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) or false
end

function Utils.Safe(fn, ...)
    if not fn then
        return nil
    end
    local ok, value = pcall(fn, ...)
    if not ok or Utils.IsSecret(value) then
        return nil
    end
    return value
end

---------------------------------------------------------
-- Units

-- Creature-0-[server]-[instance]-[zone]-[npcID]-[spawn]
function Utils.GetNpcID(unit)
    local guid = Utils.Safe(UnitGUID, unit)
    if not guid then
        return nil
    end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcID)
    end
    return nil
end

function Utils.IsNameplateUnit(unit)
    return type(unit) == "string" and unit:find("^nameplate%d") ~= nil
end

---------------------------------------------------------
-- Tables

function Utils.DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = Utils.DeepCopy(v)
    end
    return copy
end

function Utils.Print(msg)
    print("|cff33ccffNpcRoleIcons|r: " .. tostring(msg))
end
