dofile(ROOT .. "/tests/harness.lua")
dofile(VANILLA .. "shared/NPCs/AttachedLocations.lua")
dofile(VANILLA .. "client/Hotbar/ISHotbarAttachDefinition.lua")
MODEL_SCRIPTS = loadCharacterModels()
dofile(MOD .. "shared/AttachTwoWeaponsOnBack/ATWOB_Shared.lua")

local group = AttachedLocations.getGroup("Human")
local BODIES = { "Base.FemaleBody", "Base.MaleBody" }

local function getDef(list, slotType)
    for _, def in ipairs(list) do
        if def.type == slotType then return def end
    end
    return nil
end

print("ATWOB shared")

test("the back locations and their model attachments match the game's", function()
    for location, attachment in pairs(ATWOB.BACK_LOCATIONS) do
        truthy(group:getLocation(location), location .. " exists")
        eq(group:getLocation(location):getAttachmentName(), attachment, location)
    end
end)

test("every location of the vanilla back slot has a mirror, with and without a bag", function()
    for attachmentType, location in pairs(getDef(ISHotbarAttachDefinition, "Back").attachments) do
        truthy(ATWOB.BACK_LOCATIONS[location], attachmentType .. " -> " .. location)
    end
    for attachmentType, location in pairs(getDef(ISHotbarAttachDefinition.replacements, "Bag").replacement) do
        if location ~= "null" then
            truthy(ATWOB.BACK_LOCATIONS[location], attachmentType .. " with a bag -> " .. location)
        end
    end
end)

test("both body models have every vanilla back attachment", function()
    for _, body in ipairs(BODIES) do
        truthy(getModelScript(body), body)
        for _, attachment in pairs(ATWOB.BACK_LOCATIONS) do
            truthy(getModelScript(body):getAttachmentById(attachment), body .. " " .. attachment)
        end
    end
end)

test("each back location gets a mirror location, on its own model attachment", function()
    for location, attachment in pairs(ATWOB.BACK_LOCATIONS) do
        local mirror = group:getLocation(ATWOB.mirrorLocation(location))
        truthy(mirror, ATWOB.mirrorLocation(location))
        eq(mirror:getAttachmentName(), ATWOB.mirrorAttachment(attachment), location)
    end
end)

test("the mirrored attachments are added to both bodies, flipped across the spine", function()
    eq(ATWOB.addModelAttachments(), #BODIES * count(ATWOB.BACK_LOCATIONS), "added")
    for _, body in ipairs(BODIES) do
        local script = getModelScript(body)
        for _, attachment in pairs(ATWOB.BACK_LOCATIONS) do
            local source = script:getAttachmentById(attachment)
            local mirror = script:getAttachmentById(ATWOB.mirrorAttachment(attachment))
            local what = body .. " " .. attachment
            truthy(mirror, what)
            eq(mirror:getBone(), source:getBone(), what .. " bone")
            near(mirror:getOffset():x(), source:getOffset():x(), what .. " offset x")
            near(mirror:getOffset():y(), -source:getOffset():y(), what .. " offset y")
            near(mirror:getOffset():z(), source:getOffset():z(), what .. " offset z")
            near(mirror:getRotate():x(), -source:getRotate():x(), what .. " rotate x")
            near(mirror:getRotate():y(), source:getRotate():y(), what .. " rotate y")
            near(mirror:getRotate():z(), 180 - source:getRotate():z(), what .. " rotate z")
        end
    end
end)

local function axes(attachment)
    local r = attachment:getRotate()
    return {
        rotateAxis(r:x(), r:y(), r:z(), { 1, 0, 0 }),
        rotateAxis(r:x(), r:y(), r:z(), { 0, 1, 0 }),
        rotateAxis(r:x(), r:y(), r:z(), { 0, 0, 1 }),
    }
end

local function mirrored(v)
    return { v[1], -v[2], v[3] }
end

test("an item on Back 2 keeps its length and width mirrored, and is turned over", function()
    for _, body in ipairs(BODIES) do
        local script = getModelScript(body)
        for _, attachment in pairs(ATWOB.BACK_LOCATIONS) do
            local what = body .. " " .. attachment
            local source = axes(script:getAttachmentById(attachment))
            local mirror = axes(script:getAttachmentById(ATWOB.mirrorAttachment(attachment)))
            near(dot(mirror[2], mirrored(source[2])), 1, what .. " length (Y)")
            near(dot(mirror[3], mirrored(source[3])), 1, what .. " width (Z)")
            near(dot(mirror[1], mirrored(source[1])), -1, what .. " side against the back (X)")
        end
    end
end)

test("mirroring the game's right belt attachments gives its left ones", function()
    local close = math.cos(math.rad(20))
    for _, body in ipairs(BODIES) do
        local script = getModelScript(body)
        for _, name in ipairs({ "holster", "nightstick", "meatcleaver", "wrench" }) do
            local right = script:getAttachmentById(name .. "_right")
            local left = script:getAttachmentById(name .. "_left")
            local o, r = right:getOffset(), right:getRotate()
            local ox, oy, oz, rx, ry, rz = ATWOB.mirrorTransform(o:x(), o:y(), o:z(), r:x(), r:y(), r:z())
            local what = body .. " " .. name
            truthy(math.abs(oy - left:getOffset():y()) < 0.03, what .. " offset y " .. oy .. " vs " .. left:getOffset():y())
            local leftAxes = axes(left)
            for i, axis in ipairs({ { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }) do
                local d = dot(rotateAxis(rx, ry, rz, axis), leftAxes[i])
                truthy(d > close, what .. " axis " .. i .. " within 20 degrees (cos " .. d .. ")")
            end
        end
    end
end)

test("a rifle on Back 2 goes over the other shoulder", function()
    -- MaleBody rifle_back: offset 0.008 -0.102 0.061, rotate -49 11 0
    local mirror = getModelScript("Base.MaleBody"):getAttachmentById("atwob_rifle_back")
    near(mirror:getOffset():y(), 0.102, "offset y")
    near(mirror:getRotate():x(), 49, "rotate x")
    near(mirror:getRotate():y(), 11, "rotate y")
    near(mirror:getRotate():z(), 180, "rotate z")
    eq(mirror:getBone(), "Bip01_BackPack", "bone")
end)

test("with a bag on, a crowbar on Back 2 hangs down like the one on Back", function()
    -- The bug seen in game: it pointed up from the bag instead.
    for _, body in ipairs(BODIES) do
        local script = getModelScript(body)
        local source = axes(script:getAttachmentById("big_blade_back_bag"))[2]
        local mirror = axes(script:getAttachmentById("atwob_big_blade_back_bag"))[2]
        truthy(source[3] < -0.9, body .. " vanilla points down")
        truthy(mirror[3] < -0.9, body .. " mirror points down, got " .. mirror[3])
    end
end)

test("adding them again adds nothing", function()
    eq(ATWOB.addModelAttachments(), 0, "added")
end)

test("adding them to reloaded scripts adds them again", function()
    MODEL_SCRIPTS = loadCharacterModels()
    eq(ATWOB.addModelAttachments(), #BODIES * count(ATWOB.BACK_LOCATIONS), "added")
end)

test("a server leaves the body models alone", function()
    MODEL_SCRIPTS = loadCharacterModels()
    local saved = isServer
    isServer = function() return true end
    local ok, added = pcall(ATWOB.addModelAttachments)
    isServer = saved
    truthy(ok, "no error")
    eq(added, 0, "added")
    eq(getModelScript("Base.MaleBody"):getAttachmentById("atwob_rifle_back"), nil, "rifle mirror")
end)

test("when the attachments cannot be made, the locations use the vanilla ones", function()
    MODEL_SCRIPTS = loadCharacterModels()
    local saved = ModelAttachment
    ModelAttachment = nil
    local ok, added = pcall(ATWOB.addModelAttachments)
    ModelAttachment = saved
    truthy(ok, "no error")
    eq(added, 0, "added")
    for location, attachment in pairs(ATWOB.BACK_LOCATIONS) do
        eq(group:getLocation(ATWOB.mirrorLocation(location)):getAttachmentName(), attachment, location)
    end
end)

finish("ATWOB shared")
