-- NRI_Display.lua
-- Icon containers attached to the Blizzard nameplate base frames.
-- Every nameplate addon (Platynator, Plater, default UI...) draws on top of these
-- base frames, so the icons work with any of them without touching their code.
NRI_Display = {}

local Display = NRI_Display
local IconSets = NRI_IconSets

---------------------------------------------------------
-- Containers (one per nameplate frame, reused with the plate)

local function GetContainer(plate)
    local container = plate.NRI_Container
    if not container then
        container = CreateFrame("Frame", nil, plate)
        container:SetSize(1, 1)
        container.icons = {}
        plate.NRI_Container = container
    end
    return container
end

-- One icon slot: the texture, a circle mask (used by the spell icon set) and a ring.
local function GetIcon(container, index)
    local icon = container.icons[index]
    if not icon then
        icon = {}
        icon.tex = container:CreateTexture(nil, "OVERLAY", nil, 1)
        icon.mask = container:CreateMaskTexture()
        icon.mask:SetTexture(IconSets.CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        icon.mask:SetAllPoints(icon.tex)
        icon.ring = container:CreateTexture(nil, "OVERLAY", nil, 2)
        icon.ring:SetAllPoints(icon.tex)
        container.icons[index] = icon
    end
    return icon
end

local function HideIcon(icon)
    icon.tex:Hide()
    icon.ring:Hide()
end

---------------------------------------------------------
-- Layout

-- Offset of icon i (0 based) from the container center along the stack axis.
local function StackOffset(i, count, size, spacing, direction)
    local step = size + spacing
    if direction == "center" then
        return -((count - 1) * step) / 2 + i * step
    elseif direction == "left" then
        return -i * step
    end
    return i * step
end

-- layout: the profile (shared layout options and icon set)
function Display.Show(plate, layout, roles)
    local container = GetContainer(plate)

    local count = math.min(#roles, layout.max_icons)
    if count == 0 then
        container:Hide()
        return
    end

    container:ClearAllPoints()
    container:SetPoint("CENTER", plate, layout.anchor, layout.offset_x, layout.offset_y)
    if layout.strata ~= "INHERIT" then
        container:SetFrameStrata(layout.strata)
    else
        container:SetFrameStrata(plate:GetFrameStrata())
    end
    container:SetFrameLevel(plate:GetFrameLevel() + layout.frame_level)
    container:SetAlpha(layout.alpha)

    local size, spacing = layout.icon_size, layout.icon_spacing
    for i = 1, count do
        local icon = GetIcon(container, i)
        local tex = icon.tex
        local offset = StackOffset(i - 1, count, size, spacing, layout.direction)
        tex:ClearAllPoints()
        if layout.orientation == "vertical" then
            -- "left" grows up, "right" grows down
            tex:SetPoint("CENTER", container, "CENTER", 0, -offset)
        else
            tex:SetPoint("CENTER", container, "CENTER", offset, 0)
        end
        tex:SetSize(size, size)
        IconSets.Apply(icon, IconSets.Get(layout.icon_set, roles[i]))
        tex:Show()
    end
    for i = count + 1, #container.icons do
        HideIcon(container.icons[i])
    end
    container:Show()
end

function Display.Hide(plate)
    if plate and plate.NRI_Container then
        plate.NRI_Container:Hide()
    end
end
