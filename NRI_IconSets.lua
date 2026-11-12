-- NRI_IconSets.lua
-- Icon styles. Drawn sets are our own TGA files (Tools/make_icons.py), the Warcraft
-- sets reuse the game's own textures (atlases and spell/item icons).
NRI_IconSets = {}

local IconSets = NRI_IconSets

local ICON_DIR = "Interface\\AddOns\\NpcRoleIcons\\Icons\\"
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local BORDER_RING = ICON_DIR .. "Border_Ring"
local SPELL_CROP = { 0.07, 0.93, 0.07, 0.93 } -- cut the dark border baked into game icons

IconSets.DEFAULT = "FantasyBrownMetal"

-- kind "drawn": Icons\<key>\<role>.tga
-- kind "world": game atlases (map, minimap, cursor and nameplate art)
-- kind "spell": game spell/item icons (file IDs), cut in a circle with a ring
IconSets.LIST = {
    { key = "FantasyBright",     kind = "drawn" },
    { key = "FantasyBlackWhite", kind = "drawn" },
    { key = "FantasyBrownMetal", kind = "drawn" },
    { key = "FantasyNoBG",       kind = "drawn" },
    { key = "ScifiNeon",         kind = "drawn" },
    { key = "WarcraftWorld",     kind = "world" },
    { key = "WarcraftSpell",     kind = "spell" },
}

IconSets.BY_KEY = {}
for _, set in ipairs(IconSets.LIST) do
    IconSets.BY_KEY[set.key] = set
end

-- Atlas names checked against the live build atlas list (12.1.5).
local WORLD_ATLASES = {
    quest_objective = "QuestObjective",
    innkeeper       = "Innkeeper",
    vendor          = "Cursor_buy_128",
    repair          = "Repair",
    trainer         = "Profession",
    flight_master   = "FlightMaster",
    stable_master   = "StableMaster",
    banker          = "Banker",
    auctioneer      = "Auctioneer",
    mail            = "Mailbox",
    transmog        = "poi-transmogrifier",
    barber          = "Barbershop-32x32",
    item_upgrade    = "UpgradeItem-32x32",
    portal          = "MagePortalAlliance",
    battlemaster    = "BattleMaster",
    guild           = "UI-Achievement-Guild-Flag-Short",
    spirit_healer   = "poi-soulspiritghost",
    targeting_you   = "Target",
    boss            = "DungeonSkull",
    rare            = "nameplates-icon-elite-silver",
    elite           = "nameplates-icon-elite-gold",
    caster          = "Cursor_cast_128",
    in_combat       = "GarrMission_MissionIcon-Combat",
    attackable      = "Cursor_Attack_128",
    hostile         = "nameplates-icon-flag-horde",
    neutral         = "nameplates-icon-flag-neutral",
    friendly        = "nameplates-icon-flag-alliance",
    tapped          = "vignetteloot-locked",
    battle_pet      = "WildBattlePet",
}

-- File IDs checked against the community listfile (Interface\Icons\<name>).
local SPELL_ICONS = {
    quest_objective = 134269, -- inv_misc_map_01
    innkeeper       = 134414, -- inv_misc_rune_01 (hearthstone)
    vendor          = 133639, -- inv_misc_bag_10
    repair          = 136241, -- trade_blacksmithing
    trainer         = 133741, -- inv_misc_book_09
    flight_master   = 132239, -- ability_mount_gryphon_01
    stable_master   = 132164, -- ability_hunter_beasttaming
    banker          = 132595, -- inv_box_02
    auctioneer      = 133784, -- inv_misc_coin_01
    mail            = 133471, -- inv_letter_15
    transmog        = 132658, -- inv_chest_cloth_17
    barber          = 133800, -- inv_misc_comb_01
    item_upgrade    = 134138, -- inv_misc_gem_variety_01
    portal          = 237508, -- spell_arcane_portaldalaran
    battlemaster    = 132486, -- inv_bannerpvp_02
    guild           = 135026, -- inv_shirt_guildtabard_01
    spirit_healer   = 135955, -- spell_holy_resurrection
    targeting_you   = 132212, -- ability_hunter_snipershot
    boss            = 133730, -- inv_misc_bone_humanskull_01
    rare            = 135753, -- spell_arcane_starfire
    elite           = 134153, -- inv_misc_head_dragon_01
    caster          = 135150, -- inv_staff_13
    in_combat       = 135812, -- spell_fire_flamebolt
    attackable      = 132147, -- ability_dualwield
    hostile         = 135824, -- spell_fire_sealoffire
    neutral         = 135970, -- spell_holy_sealofwisdom
    friendly        = 136078, -- spell_nature_regeneration
    tapped          = 647735, -- inv_misc_lockbox_1
    battle_pet      = 643856, -- inv_pet_battlepettraining
}

---------------------------------------------------------
-- Resolve: role -> icon description
--   { texture = path or fileID, atlas = name, texCoord = {...}, circle = bool, ring = path, fallback = bool }

local cache = {}

local function Drawn(setKey, role)
    return { texture = ICON_DIR .. setKey .. "\\" .. role }
end

local function AtlasExists(atlas)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) ~= nil
end

local function Resolve(set, role)
    if set.kind == "world" then
        local atlas = WORLD_ATLASES[role]
        if atlas and AtlasExists(atlas) then
            return { atlas = atlas }
        end
    elseif set.kind == "spell" then
        local fileID = SPELL_ICONS[role]
        if fileID then
            return { texture = fileID, texCoord = SPELL_CROP, circle = true, ring = BORDER_RING }
        end
    else
        return Drawn(set.key, role)
    end
    -- Missing in this game version: use the default drawn icon.
    local icon = Drawn(IconSets.DEFAULT, role)
    icon.fallback = true
    return icon
end

function IconSets.Get(setKey, role)
    local set = IconSets.BY_KEY[setKey] or IconSets.BY_KEY[IconSets.DEFAULT]
    local setCache = cache[set.key]
    if not setCache then
        setCache = {}
        cache[set.key] = setCache
    end
    local icon = setCache[role]
    if not icon then
        icon = Resolve(set, role)
        setCache[role] = icon
    end
    return icon
end

-- Inline text markup for the options (|T|t or |A|a).
function IconSets.Markup(setKey, role, size)
    local icon = IconSets.Get(setKey, role)
    size = size or 16
    if icon.atlas then
        return "|A:" .. icon.atlas .. ":" .. size .. ":" .. size .. "|a"
    end
    if icon.texCoord then
        local c = icon.texCoord
        return string.format("|T%s:%d:%d:0:0:100:100:%d:%d:%d:%d|t", tostring(icon.texture), size, size,
            c[1] * 100, c[2] * 100, c[3] * 100, c[4] * 100)
    end
    return "|T" .. icon.texture .. ":" .. size .. ":" .. size .. "|t"
end

---------------------------------------------------------
-- Apply to a widget made by Display: { tex = Texture, mask = MaskTexture, ring = Texture }

function IconSets.Apply(widget, icon)
    local tex = widget.tex
    if icon.atlas then
        tex:SetAtlas(icon.atlas, false)
    else
        tex:SetTexture(icon.texture)
    end
    if icon.texCoord then
        tex:SetTexCoord(unpack(icon.texCoord))
    elseif not icon.atlas then
        tex:SetTexCoord(0, 1, 0, 1)
    end

    if icon.circle and not widget.masked then
        tex:AddMaskTexture(widget.mask)
        widget.masked = true
    elseif not icon.circle and widget.masked then
        tex:RemoveMaskTexture(widget.mask)
        widget.masked = false
    end

    if icon.ring then
        widget.ring:SetTexture(icon.ring)
        widget.ring:Show()
    else
        widget.ring:Hide()
    end
end

IconSets.CIRCLE_MASK = CIRCLE_MASK
