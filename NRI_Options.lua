-- NRI_Options.lua
NRI_Options = {}

local Options = NRI_Options
local Utils = NRI_Utils
local Roles = NRI_Roles
local Conditions = NRI_Conditions
local IconSets = NRI_IconSets

local L = LibStub("AceLocale-3.0"):GetLocale("NpcRoleIcons", false)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

Options.APP_NAME = "NpcRoleIcons"
Options.db = nil      -- profile
Options.options = nil

---------------------------------------------------------
-- Defaults

Options.defaults = {
    profile = {
        enabled = true,
        toggle_message = true,
        icon_set = IconSets.DEFAULT,

        -- Layout (shared by all rules)
        anchor = "TOP",
        offset_x = 0,
        offset_y = 0,
        icon_size = 20,
        icon_spacing = 2,
        orientation = "horizontal",
        direction = "center",
        max_icons = 4,
        strata = "INHERIT",
        frame_level = 20,
        alpha = 1,

        -- rules: created by Options.EnsureRules (kept out of AceDB defaults on purpose,
        -- AceDB would merge default rules back into the user's edited list)
    },
}

-- Field defaults of a rule. Missing fields are filled on load.
Options.RULE_DEFAULTS = {
    name = "Rule",
    enabled = true,
    criteria = {},
    roles = {},
    distance_hidden = {}, -- band -> true when the icons are hidden at that distance
}

local function DefaultRules()
    return {
        {
            name = L["NRI.default_rule.friendly"],
            criteria = { ["npc"] = true, ["cannot-attack"] = true },
            roles = {
                quest_objective = true,
                innkeeper = true,
                vendor = true,
                stable_master = true,
                banker = true,
                auctioneer = true,
                barber = true,
                item_upgrade = true,
            },
        },
    }
end

local function FillRule(rule)
    for key, value in pairs(Options.RULE_DEFAULTS) do
        if rule[key] == nil then
            rule[key] = Utils.DeepCopy(value)
        end
    end
    return rule
end

function Options.NewRule(name)
    return FillRule({ name = name })
end

function Options.EnsureRules(profile)
    if type(profile.rules) ~= "table" then
        profile.rules = DefaultRules()
    end
    for _, rule in ipairs(profile.rules) do
        FillRule(rule)
        rule.distance_hidden.unknown = nil -- was an option in early versions
    end
end

---------------------------------------------------------
-- Lists

local optionWidth = 1.6

local function GetAnchorOptions()
    return {
        ["TOPLEFT"] = L["NRI.list.anchor.TOPLEFT"],
        ["TOP"] = L["NRI.list.anchor.TOP"],
        ["TOPRIGHT"] = L["NRI.list.anchor.TOPRIGHT"],
        ["LEFT"] = L["NRI.list.anchor.LEFT"],
        ["CENTER"] = L["NRI.list.anchor.CENTER"],
        ["RIGHT"] = L["NRI.list.anchor.RIGHT"],
        ["BOTTOMLEFT"] = L["NRI.list.anchor.BOTTOMLEFT"],
        ["BOTTOM"] = L["NRI.list.anchor.BOTTOM"],
        ["BOTTOMRIGHT"] = L["NRI.list.anchor.BOTTOMRIGHT"],
    }
end

local function GetStrataOptions()
    return {
        ["INHERIT"] = L["NRI.list.strata.INHERIT"],
        ["BACKGROUND"] = L["NRI.list.strata.BACKGROUND"],
        ["LOW"] = L["NRI.list.strata.LOW"],
        ["MEDIUM"] = L["NRI.list.strata.MEDIUM"],
        ["HIGH"] = L["NRI.list.strata.HIGH"],
        ["DIALOG"] = L["NRI.list.strata.DIALOG"],
    }
end

local STRATA_SORTING = { "INHERIT", "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }

-- Inline group of checkboxes over a set table of the rule (criteria / roles).
-- Used instead of a multiselect, which cannot keep a custom order.
local function ToggleGroup(name, order, field, entries, getRule)
    local args = {}
    for i, entry in ipairs(entries) do
        args[entry.key] = {
            type = "toggle",
            name = entry.label,
            order = i,
            get = function()
                return getRule()[field][entry.key]
            end,
            set = function(_, value)
                getRule()[field][entry.key] = value or nil
                NpcRoleIcons:RefreshAll()
            end,
        }
    end
    return {
        type = "group",
        inline = true,
        name = name,
        order = order,
        args = args,
    }
end

local function GetRoleEntries(category)
    local entries = {}
    for _, role in ipairs(Roles.LIST) do
        if role.category == category then
            entries[#entries + 1] = {
                key = role.key,
                label = function()
                    return IconSets.Markup(Options.db.icon_set, role.key, 18) .. " " .. Roles.Label(role.key)
                end,
            }
        end
    end
    return entries
end

local function GetConditionEntries(group)
    local entries = {}
    for _, key in ipairs(group.conditions) do
        entries[#entries + 1] = { key = key, label = L["NRI.condition." .. key] }
    end
    return entries
end

---------------------------------------------------------
-- Changes

local function OnChanged()
    NpcRoleIcons:RefreshAll()
end

local function Rebuild()
    Options.BuildRules()
    AceConfigRegistry:NotifyChange(Options.APP_NAME)
    OnChanged()
end

---------------------------------------------------------
-- Rule options

local function RuleOptions(index)
    local function Rule()
        return Options.db.rules[index]
    end
    local function Get(info)
        return Rule()[info.arg]
    end
    local function Set(info, value)
        Rule()[info.arg] = value
        OnChanged()
    end

    local conditionArgs = {
        help = {
            type = "description",
            name = L["NRI.options.conditions.help"],
            order = 0,
            fontSize = "medium",
        },
    }
    for i, group in ipairs(Conditions.GROUPS) do
        conditionArgs["group_" .. group.key] = ToggleGroup(L["NRI.condition_group." .. group.key], i,
            "criteria", GetConditionEntries(group), Rule)
    end

    local roleArgs = {
        help = {
            type = "description",
            name = L["NRI.options.icons.help"],
            order = 0,
            fontSize = "medium",
        },
    }
    for i, category in ipairs(Roles.CATEGORIES) do
        roleArgs["roles_" .. category] = ToggleGroup(L["NRI.role_category." .. category], i,
            "roles", GetRoleEntries(category), Rule)
    end

    local filterArgs = {
        help = {
            type = "description",
            name = L["NRI.options.filters.help"],
            order = 0,
            fontSize = "medium",
        },
        header_distance = {
            type = "header",
            name = L["NRI.options.filters.distance"],
            order = 1,
        },
    }
    for i, band in ipairs(Conditions.DISTANCE_BANDS) do
        filterArgs["distance_" .. band] = {
            type = "select",
            name = L["NRI.filter.distance." .. band],
            desc = L["NRI.filter.distance." .. band .. ".desc"],
            values = {
                visible = L["NRI.list.visibility.visible"],
                hidden = L["NRI.list.visibility.hidden"],
            },
            sorting = { "visible", "hidden" },
            order = 1 + i,
            width = "full",
            get = function()
                return Rule().distance_hidden[band] and "hidden" or "visible"
            end,
            set = function(_, value)
                Rule().distance_hidden[band] = value == "hidden" or nil
                OnChanged()
            end,
        }
    end

    local count = #Options.db.rules
    return {
        type = "group",
        name = function()
            local rule = Rule()
            local name = index .. ". " .. (rule.name or "")
            return rule.enabled and name or ("|cff808080" .. name .. "|r")
        end,
        order = index,
        childGroups = "tab",
        get = Get,
        set = Set,
        args = {
            name = {
                type = "input",
                name = L["NRI.options.rule.name"],
                arg = "name",
                order = 1,
                width = optionWidth,
            },
            enabled = {
                type = "toggle",
                name = L["NRI.options.rule.enabled"],
                desc = L["NRI.options.rule.enabled.desc"],
                arg = "enabled",
                order = 2,
            },
            move_up = {
                type = "execute",
                name = L["NRI.options.rule.move_up"],
                order = 3,
                width = "half",
                disabled = index == 1,
                func = function()
                    local rules = Options.db.rules
                    rules[index], rules[index - 1] = rules[index - 1], rules[index]
                    Rebuild()
                end,
            },
            move_down = {
                type = "execute",
                name = L["NRI.options.rule.move_down"],
                order = 4,
                width = "half",
                disabled = index == count,
                func = function()
                    local rules = Options.db.rules
                    rules[index], rules[index + 1] = rules[index + 1], rules[index]
                    Rebuild()
                end,
            },
            delete = {
                type = "execute",
                name = L["NRI.options.rule.delete"],
                order = 5,
                width = "half",
                confirm = true,
                confirmText = L["NRI.options.rule.delete.confirm"],
                func = function()
                    table.remove(Options.db.rules, index)
                    Rebuild()
                end,
            },
            tab_conditions = {
                type = "group",
                name = L["NRI.options.tab_conditions.title"],
                order = 10,
                args = conditionArgs,
            },
            tab_icons = {
                type = "group",
                name = L["NRI.options.tab_icons.title"],
                order = 11,
                args = roleArgs,
            },
            tab_filters = {
                type = "group",
                name = L["NRI.options.tab_filters.title"],
                order = 12,
                args = filterArgs,
            },
        },
    }
end

function Options.BuildRules()
    local args = {
        help = {
            type = "description",
            name = L["NRI.options.rules.help"],
            order = 0,
            fontSize = "medium",
        },
        add_rule = {
            type = "execute",
            name = L["NRI.options.rules.add"],
            order = 1,
            func = function()
                local rules = Options.db.rules
                rules[#rules + 1] = Options.NewRule(L["NRI.options.rules.new_name"] .. " " .. (#rules + 1))
                Rebuild()
            end,
        },
    }
    for index in ipairs(Options.db.rules) do
        args["rule_" .. index] = RuleOptions(index)
    end
    Options.options.args.tab_rules.args = args
end

---------------------------------------------------------
-- Icons tab: icon style + every role with its icon

local function GetIconSetOptions()
    local values, sorting = {}, {}
    for _, set in ipairs(IconSets.LIST) do
        values[set.key] = L["NRI.icon_set." .. set.key]
        sorting[#sorting + 1] = set.key
    end
    return values, sorting
end

local function RoleReferenceArgs()
    local setValues, setSorting = GetIconSetOptions()
    local args = {
        icon_set = {
            type = "select",
            name = L["NRI.options.icon_set"],
            desc = L["NRI.options.icon_set.desc"],
            values = setValues,
            sorting = setSorting,
            order = 0,
            width = optionWidth,
            get = function()
                return Options.db.icon_set
            end,
            set = function(_, value)
                Options.db.icon_set = value
                NpcRoleIcons:RefreshAll()
            end,
        },
    }
    local order = 0
    for _, category in ipairs(Roles.CATEGORIES) do
        order = order + 1
        args["header_" .. category] = {
            type = "header",
            name = L["NRI.role_category." .. category],
            order = order,
        }
        for _, role in ipairs(Roles.LIST) do
            if role.category == category then
                order = order + 1
                args["role_" .. role.key] = {
                    type = "description",
                    name = function()
                        local setKey = Options.db.icon_set
                        local text = IconSets.Markup(setKey, role.key, 32) .. "  |cffffd100" .. Roles.Label(role.key)
                            .. "|r  " .. L["NRI.role." .. role.key .. ".desc"]
                        if IconSets.Get(setKey, role.key).fallback then
                            text = text .. "  |cff808080" .. L["NRI.options.icon_fallback"] .. "|r"
                        end
                        return text
                    end,
                    fontSize = "medium",
                    order = order,
                }
            end
        end
    end
    return args
end

---------------------------------------------------------
-- Options table

local function GeneralGet(info)
    return Options.db[info.arg]
end

local function GeneralSet(info, value)
    Options.db[info.arg] = value
    NpcRoleIcons:ApplySettings()
end

Options.options = {
    type = "group",
    name = L["NRI.title"],
    desc = L["NRI.desc"],
    childGroups = "tab",
    args = {
        tab_general = {
            type = "group",
            name = L["NRI.options.tab_general.title"],
            order = 1,
            get = GeneralGet,
            set = GeneralSet,
            args = {
                enabled = {
                    type = "toggle",
                    name = L["NRI.options.enabled"],
                    desc = L["NRI.options.enabled.desc"],
                    arg = "enabled",
                    order = 1,
                    width = "full",
                },
                toggle_message = {
                    type = "toggle",
                    name = L["NRI.options.toggle_message"],
                    desc = L["NRI.options.toggle_message.desc"],
                    arg = "toggle_message",
                    order = 1.5,
                    width = "full",
                },
                friendly_npc_plates = {
                    type = "toggle",
                    name = L["NRI.options.friendly_npc_plates"],
                    desc = L["NRI.options.friendly_npc_plates.desc"],
                    order = 2,
                    width = "full",
                    get = function()
                        return C_CVar.GetCVarBool("nameplateShowFriendlyNPCs")
                    end,
                    set = function(_, value)
                        if InCombatLockdown() then
                            Utils.Print(L["NRI.msg.combat"])
                            return
                        end
                        C_CVar.SetCVar("nameplateShowFriendlyNPCs", value and "1" or "0")
                    end,
                },
            },
        },
        tab_rules = {
            type = "group",
            name = L["NRI.options.tab_rules.title"],
            order = 2,
            childGroups = "tree",
            args = {},
        },
        tab_layout = {
            type = "group",
            name = L["NRI.options.tab_layout.title"],
            order = 3,
            get = GeneralGet,
            set = GeneralSet,
            args = {
                header_position = {
                    type = "header",
                    name = L["NRI.options.layout.position"],
                    order = 1,
                },
                anchor = {
                    type = "select",
                    name = L["NRI.options.layout.anchor"],
                    desc = L["NRI.options.layout.anchor.desc"],
                    values = GetAnchorOptions,
                    arg = "anchor",
                    order = 2,
                },
                offset_x = {
                    type = "range",
                    name = L["NRI.options.layout.offset_x"],
                    min = -200, max = 200, softMin = -100, softMax = 100, step = 1,
                    arg = "offset_x",
                    order = 3,
                },
                offset_y = {
                    type = "range",
                    name = L["NRI.options.layout.offset_y"],
                    min = -200, max = 200, softMin = -100, softMax = 100, step = 1,
                    arg = "offset_y",
                    order = 4,
                },
                header_icons = {
                    type = "header",
                    name = L["NRI.options.layout.icons"],
                    order = 10,
                },
                icon_size = {
                    type = "range",
                    name = L["NRI.options.layout.icon_size"],
                    min = 6, max = 96, softMin = 8, softMax = 64, step = 1,
                    arg = "icon_size",
                    order = 11,
                },
                icon_spacing = {
                    type = "range",
                    name = L["NRI.options.layout.icon_spacing"],
                    min = -20, max = 40, softMin = 0, softMax = 20, step = 1,
                    arg = "icon_spacing",
                    order = 12,
                },
                max_icons = {
                    type = "range",
                    name = L["NRI.options.layout.max_icons"],
                    min = 1, max = 12, step = 1,
                    arg = "max_icons",
                    order = 13,
                },
                orientation = {
                    type = "select",
                    name = L["NRI.options.layout.orientation"],
                    values = {
                        horizontal = L["NRI.list.orientation.horizontal"],
                        vertical = L["NRI.list.orientation.vertical"],
                    },
                    arg = "orientation",
                    order = 14,
                },
                direction = {
                    type = "select",
                    name = L["NRI.options.layout.direction"],
                    desc = L["NRI.options.layout.direction.desc"],
                    values = {
                        center = L["NRI.list.direction.center"],
                        left = L["NRI.list.direction.left"],
                        right = L["NRI.list.direction.right"],
                    },
                    sorting = { "left", "center", "right" },
                    arg = "direction",
                    order = 15,
                },
                header_layer = {
                    type = "header",
                    name = L["NRI.options.layout.layer"],
                    order = 20,
                },
                strata = {
                    type = "select",
                    name = L["NRI.options.layout.strata"],
                    desc = L["NRI.options.layout.strata.desc"],
                    values = GetStrataOptions,
                    sorting = STRATA_SORTING,
                    arg = "strata",
                    order = 21,
                },
                frame_level = {
                    type = "range",
                    name = L["NRI.options.layout.frame_level"],
                    desc = L["NRI.options.layout.frame_level.desc"],
                    min = 0, max = 500, softMax = 100, step = 1,
                    arg = "frame_level",
                    order = 22,
                },
                alpha = {
                    type = "range",
                    name = L["NRI.options.layout.alpha"],
                    min = 0.05, max = 1, step = 0.05, isPercent = true,
                    arg = "alpha",
                    order = 23,
                },
            },
        },
        tab_roles = {
            type = "group",
            name = L["NRI.options.tab_roles.title"],
            order = 4,
            args = RoleReferenceArgs(),
        },
    },
}
