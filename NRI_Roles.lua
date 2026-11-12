-- NRI_Roles.lua
-- The role catalog: every icon the addon can show, and how each role is recognised.
NRI_Roles = {}

local Roles = NRI_Roles

---------------------------------------------------------
-- Role categories (options grouping)

Roles.CATEGORIES = { "quest", "unit", "service" }

---------------------------------------------------------
-- Catalog. List order = display order of the icons on a plate.
-- Each role has an icon of the same name in Icons\.
--   source "state"    : read live from the unit
--   source "service"  : NPC subtitle (or name)

Roles.LIST = {
    -- Quest
    { key = "quest_objective", category = "quest",   source = "state" },

    -- Services
    { key = "innkeeper",       category = "service", source = "service" },
    { key = "vendor",          category = "service", source = "service" },
    { key = "repair",          category = "service", source = "service" },
    { key = "trainer",         category = "service", source = "service" },
    { key = "flight_master",   category = "service", source = "service" },
    { key = "stable_master",   category = "service", source = "service" },
    { key = "banker",          category = "service", source = "service" },
    { key = "auctioneer",      category = "service", source = "service" },
    { key = "mail",            category = "service", source = "service" },
    { key = "transmog",        category = "service", source = "service" },
    { key = "barber",          category = "service", source = "service" },
    { key = "item_upgrade",    category = "service", source = "service" },
    { key = "portal",          category = "service", source = "service" },
    { key = "battlemaster",    category = "service", source = "service" },
    { key = "guild",           category = "service", source = "service" },
    { key = "spirit_healer",   category = "service", source = "service" },

    -- Unit state
    { key = "targeting_you",   category = "unit",    source = "state" },
    { key = "boss",            category = "unit",    source = "state" },
    { key = "rare",            category = "unit",    source = "state" },
    { key = "elite",           category = "unit",    source = "state" },
    { key = "caster",          category = "unit",    source = "state" },
    { key = "in_combat",       category = "unit",    source = "state" },
    { key = "attackable",      category = "unit",    source = "state" },
    { key = "hostile",         category = "unit",    source = "state" },
    { key = "neutral",         category = "unit",    source = "state" },
    { key = "friendly",        category = "unit",    source = "state" },
    { key = "tapped",          category = "unit",    source = "state" },
    { key = "battle_pet",      category = "unit",    source = "state" },
}

Roles.BY_KEY = {}
for index, role in ipairs(Roles.LIST) do
    role.index = index
    Roles.BY_KEY[role.key] = role
end

---------------------------------------------------------
-- Subtitle keywords (lower case, plain find). One keyword can give several roles.
-- enUS only for now.

Roles.SUBTITLE_KEYWORDS = {
    innkeeper     = { "innkeeper" },
    trainer       = { "trainer", "instructor" },
    flight_master = { "flight master", "flightmaster", "wind rider master", "gryphon master",
                      "hippogryph master", "bat handler", "dragonhawk master", "wyvern master" },
    stable_master = { "stable master", "stablemaster" },
    banker        = { "banker", "guild bank", "void storage" },
    auctioneer    = { "auctioneer", "auction house" },
    mail          = { "postmaster", "mail carrier", "mailbox" },
    transmog      = { "transmogrif" },
    barber        = { "barber", "stylist" },
    item_upgrade  = { "upgrade" },
    portal        = { "portal", "teleportation" },
    battlemaster  = { "battlemaster", "arena organizer" },
    guild         = { "guild master" },
    spirit_healer = { "spirit healer", "spirit guide" },
    repair        = { "armorer", "armorsmith", "weaponsmith", "repair" },
    vendor        = { "vendor", "merchant", "goods", "supplies", "supplier", "provisioner",
                      "quartermaster", "trader", "tradesman", "reagent", "food", "drink",
                      "baker", "butcher", "fishmonger", "grocer", "weapon", "armor", "bowyer",
                      "gunsmith", "fletcher", "poison", "tabard", "outfitter", "clothier",
                      "purveyor", "peddler", "salesman", "dealer", "wares", "emporium", "shop",
                      "vintner", "wine", "cheese", "fruit", "mushroom", "bread", "arrow",
                      "ammunition", "bartender", "barkeep", "mounts", "pets" },
}

-- Whole-subtitle titles (lower case), optionally after a rank: "Blacksmith", "Journeyman Blacksmith".
-- Classic-era clients title profession trainers by the profession itself. Matching the
-- whole subtitle keeps vendors like "Blacksmithing Supplies" out.
Roles.SUBTITLE_RANKS = { "apprentice", "journeyman", "expert", "artisan", "master", "grand master", "grandmaster" }

Roles.SUBTITLE_TITLES = {
    trainer = { "alchemist", "blacksmith", "enchanter", "engineer", "gnome engineer", "goblin engineer",
                "herbalist", "leatherworker", "miner", "skinner", "tailor", "cook", "fisherman",
                "jewelcrafter", "scribe", "inscriber", "archaeologist", "physician", "surgeon" },
}

-- NPC names that are a service by themselves (no subtitle).
Roles.NAME_KEYWORDS = {
    spirit_healer = { "spirit healer", "spirit guide" },
}

function Roles.Label(key)
    local L = LibStub("AceLocale-3.0"):GetLocale("NpcRoleIcons")
    return L["NRI.role." .. key]
end
