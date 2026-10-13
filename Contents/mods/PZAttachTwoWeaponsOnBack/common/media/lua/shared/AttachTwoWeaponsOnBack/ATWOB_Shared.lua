--[[
    Second Back Slot: the attached locations for the second back slot.

    A character holds one item per attached location, so the second back slot
    cannot reuse the vanilla ones: its item would knock the first one off the
    model. The server checks locations too (an attached item it does not know
    fails with "no such location"), so they are made here, for both sides.

    Each new location points at a new model attachment that mirrors the vanilla
    one across the spine, so the two items cross on the back instead of
    overlapping (in vanilla a shotgun and a crowbar sit at almost the same angle).
--]]

ATWOB = ATWOB or {}

-- The vanilla back locations (NPCs/AttachedLocations.lua) and their model
-- attachments (scripts/generated/models_characters.txt), B42.21: the ones the
-- back slot uses, then the ones it moves to with a bag on.
ATWOB.BACK_LOCATIONS = {
    ["Big Weapon On Back"] = "big_w_back",
    ["Blade On Back"] = "blade_back",
    ["Racket On Back"] = "racket_back",
    ["Shovel Back"] = "shovel_back",
    ["Guitar"] = "back_guitar",
    ["Guitar Acoustic"] = "back_guitar_acoustic",
    ["Pan On Back"] = "fryingpan_back",
    ["Rifle On Back"] = "rifle_back",
    ["Saucepan Back"] = "saucepan_back",

    ["Big Weapon On Back with Bag"] = "big_w_back_bag",
    ["Big Blade On Back with Bag"] = "big_blade_back_bag",
    ["Racket Back with Bag"] = "racket_back_bag",
    ["Shovel Back with Bag"] = "shovel_back_bag",
    ["Pan On Back with Bag"] = "fryingpan_back_bag",
    ["Rifle On Back with Bag"] = "rifle_back_bag",
    ["Saucepan Back with Bag"] = "saucepan_back_bag",
}

function ATWOB.mirrorLocation(location)
    return "ATWOB " .. location
end

function ATWOB.mirrorAttachment(attachment)
    return "atwob_" .. attachment
end

-- Mirrors an attachment's offset and rotation across the spine. Left and right
-- attachments on the body differ by the sign of Y (belt_left/belt_right on the
-- pelvis, webbing_left/right on the spine, backpack_left on the back bone), so
-- Y points to the side and the offset flips Y.
-- A model cannot be mirrored, only turned, so the item keeps its length (its own
-- Y axis) and width (Z) mirrored and is turned over (its X, the side lying
-- against the back). The game rotates X, then Y, then Z (rotateXYZ), which makes
-- that -rx, ry, 180 - rz. The game's own right/left belt attachments follow the
-- same rule (holster_right 179 -2 86, holster_left 179 -2 94).
function ATWOB.mirrorTransform(ox, oy, oz, rx, ry, rz)
    return ox, -oy, oz, -rx, ry, 180 - rz
end

local group = AttachedLocations.getGroup("Human")

for location, attachment in pairs(ATWOB.BACK_LOCATIONS) do
    group:getOrCreateLocation(ATWOB.mirrorLocation(location)):setAttachmentName(ATWOB.mirrorAttachment(attachment))
end

local function getBodyScripts()
    local bodies = {}
    local scripts = getScriptManager():getAllModelScripts()
    for i = 0, scripts:size() - 1 do
        local script = scripts:get(i)
        local fullType = script:getFullType()
        if fullType == "Base.FemaleBody" or fullType == "Base.MaleBody" then
            table.insert(bodies, script)
        end
    end
    return bodies
end

local function addMirror(script, source, id)
    local offset, rotate = source:getOffset(), source:getRotate()
    local ox, oy, oz, rx, ry, rz = ATWOB.mirrorTransform(offset:x(), offset:y(), offset:z(), rotate:x(), rotate:y(), rotate:z())
    local attachment = ModelAttachment.new(id)
    attachment:setBone(source:getBone())
    attachment:getOffset():set(ox, oy, oz)
    attachment:getRotate():set(rx, ry, rz)
    attachment:setScale(source:getScale())
    attachment:setZOffset(source:getZOffset())
    script:addAttachment(attachment)
end

-- Adds the mirrored attachments to the female and male body models, once each,
-- and returns how many it added. Only clients draw the models, so a server skips this.
function ATWOB.addModelAttachments()
    if isServer() then
        return 0
    end
    local added = 0
    local bodies = getBodyScripts()
    for location, attachment in pairs(ATWOB.BACK_LOCATIONS) do
        local id = ATWOB.mirrorAttachment(attachment)
        local failed = false
        for _, script in ipairs(bodies) do
            local source = script:getAttachmentById(attachment)
            if source and not script:getAttachmentById(id) then
                if pcall(addMirror, script, source, id) then
                    added = added + 1
                else
                    failed = true
                end
            end
        end
        if failed then
            -- The slot still works on the vanilla attachment, its item just overlaps the first one.
            print("Second Back Slot: could not add the model attachment " .. id .. ", using " .. attachment)
            group:getOrCreateLocation(ATWOB.mirrorLocation(location)):setAttachmentName(attachment)
        end
    end
    return added
end

Events.OnGameBoot.Add(ATWOB.addModelAttachments)

-- Scripts can be loaded again after boot. If the attachments were missing while
-- the world loaded, rebuild the local players' models so their back items show.
Events.OnGameStart.Add(function()
    if ATWOB.addModelAttachments() > 0 then
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            if player then
                player:resetModelNextFrame()
            end
        end
    end
end)
