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

-- The rotation the game makes of an attachment's angles (rotateXYZ: X, then Y,
-- then Z, in degrees), as rows.
function ATWOB.rotation(rx, ry, rz)
    local a, b, c = math.rad(rx), math.rad(ry), math.rad(rz)
    local ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
    return {
        { cb * cc, -cb * sc, sb },
        { ca * sc + sa * sb * cc, ca * cc - sa * sb * sc, -sa * cb },
        { sa * sc - ca * sb * cc, sa * cc + ca * sb * sc, ca * cb },
    }
end

-- The angles of such a rotation. Straight up or down about Y (cos 0), X and Z
-- turn about the same line, so all of it goes on X.
function ATWOB.angles(m)
    local cb = math.sqrt(m[1][1] * m[1][1] + m[1][2] * m[1][2])
    local b = math.deg(math.atan2(m[1][3], cb))
    if cb > 0.000000001 then
        return math.deg(math.atan2(-m[2][3], m[3][3])), b, math.deg(math.atan2(-m[1][2], m[1][1]))
    end
    return math.deg(math.atan2(m[3][2], m[2][2])), b, 0
end

-- Mirrors an attachment's offset and rotation across the spine. On the back bone
-- (Bip01_BackPack) X points out of the back, Y to the side (left and right
-- attachments on the body differ by the sign of Y: belt_left/belt_right on the
-- pelvis, backpack_left on the back bone) and Z up, so the offset flips Y.
-- A model cannot be mirrored, only turned, so the item is turned over across
-- one of its own directions as well. The one picked runs across the item's
-- length (its own Y, which is along the item: a crowbar pointed up from the bag
-- when that was flipped) and lies in the back: then every part of the item stays
-- just as far out of the back as on the first back slot, and its length is
-- mirrored. Turning it over across its X instead, which points out of the back,
-- put whatever stands out from the back into the body: a pan came out of the
-- chest.
function ATWOB.mirrorTransform(ox, oy, oz, rx, ry, rz)
    local r = ATWOB.rotation(rx, ry, rz)
    -- Out of the back, in the item's directions, is the first row; the one to
    -- turn over across is square to it and to the item's Y.
    local nx, nz = r[1][3], -r[1][1]
    local length = math.sqrt(nx * nx + nz * nz)
    if length < 0.000001 then
        nx, nz, length = 1, 0, 1
    end
    nx, nz = nx / length, nz / length
    local turn = { { 1 - 2 * nx * nx, 0, -2 * nx * nz }, { 0, 1, 0 }, { -2 * nz * nx, 0, 1 - 2 * nz * nz } }
    local side = { 1, -1, 1 }
    local m = {}
    for i = 1, 3 do
        m[i] = {}
        for j = 1, 3 do
            m[i][j] = side[i] * (r[i][1] * turn[1][j] + r[i][2] * turn[2][j] + r[i][3] * turn[3][j])
        end
    end
    local mx, my, mz = ATWOB.angles(m)
    return ox, -oy, oz, mx, my, mz
end

-- An item model can have an attachment named like the body's, which places the
-- item at it (the game looks for the location's attachment name on both models,
-- AttachedModelNames.initFrom); in vanilla only FryingPanForged has them. The
-- item is drawn at bone x body attachment x inverse of item attachment x mesh
-- (AnimatedModelInstanceRenderData.transformToParent). The item's one is copied
-- as is: the body one already mirrors the item and keeps every part of it as
-- far out of the back (see above), whatever the item attachment does after it.
function ATWOB.mirrorItemTransform(ox, oy, oz, rx, ry, rz)
    return ox, oy, oz, rx, ry, rz
end

local group = AttachedLocations.getGroup("Human")

for location, attachment in pairs(ATWOB.BACK_LOCATIONS) do
    group:getOrCreateLocation(ATWOB.mirrorLocation(location)):setAttachmentName(ATWOB.mirrorAttachment(attachment))
end

-- The location of each vanilla back attachment.
local locationOf = {}
for location, attachment in pairs(ATWOB.BACK_LOCATIONS) do
    locationOf[attachment] = location
end

local VANILLA_BODIES = { ["Base.FemaleBody"] = true, ["Base.MaleBody"] = true }

-- Body attachments are on a bone; an item model's are not.
local function addMirror(script, source, id)
    local bone = source:getBone()
    local mirror = bone and ATWOB.mirrorTransform or ATWOB.mirrorItemTransform
    local offset, rotate = source:getOffset(), source:getRotate()
    local ox, oy, oz, rx, ry, rz = mirror(offset:x(), offset:y(), offset:z(), rotate:x(), rotate:y(), rotate:z())
    local attachment = ModelAttachment.new(id)
    if bone then
        attachment:setBone(bone)
    end
    attachment:getOffset():set(ox, oy, oz)
    attachment:getRotate():set(rx, ry, rz)
    attachment:setScale(source:getScale())
    attachment:setZOffset(source:getZOffset())
    script:addAttachment(attachment)
end

-- Adds the mirror of each vanilla back attachment a model has, once, and
-- returns how many it added.
function ATWOB.addMirrors(script)
    local sources = {}
    for i = 0, script:getAttachmentCount() - 1 do
        local attachment = script:getAttachment(i)
        if locationOf[attachment:getId()] then
            table.insert(sources, attachment)
        end
    end
    local added, isBody = 0, false
    for _, source in ipairs(sources) do
        local attachment = source:getId()
        local id = ATWOB.mirrorAttachment(attachment)
        isBody = isBody or source:getBone() ~= nil
        if not script:getAttachmentById(id) then
            if pcall(addMirror, script, source, id) then
                added = added + 1
            elseif source:getBone() then
                -- The slot still works on the vanilla attachment, its item just overlaps the first one.
                print("Second Back Slot: could not add the model attachment " .. id .. ", using " .. attachment)
                group:getOrCreateLocation(ATWOB.mirrorLocation(locationOf[attachment])):setAttachmentName(attachment)
            end
        end
    end
    if added > 0 and not VANILLA_BODIES[script:getFullType()] then
        print("Second Back Slot: added the Back 2 attachments to the " .. (isBody and "body" or "item")
            .. " model " .. script:getFullType())
    end
    return added
end

-- Adds the mirrored attachments to every model with the vanilla back
-- attachments, and returns how many it added. Those are the vanilla bodies, the
-- ones a body mod draws characters with instead (HumanVisual's
-- forceModelScript), and item models placed by them. Without them, a Back 2
-- item has no attachment on the body and is drawn at the model's root, between
-- the legs, or misses its own placement. Only clients draw the models, so a
-- server skips this.
function ATWOB.addModelAttachments()
    if isServer() then
        return 0
    end
    local added = 0
    local scripts = getScriptManager():getAllModelScripts()
    for i = 0, scripts:size() - 1 do
        added = added + ATWOB.addMirrors(scripts:get(i))
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
