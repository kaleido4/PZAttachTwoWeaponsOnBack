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
            near(mirror:getRotate():z(), -source:getRotate():z(), what .. " rotate z")
        end
    end
end)

test("a rifle on Back 2 goes over the other shoulder", function()
    -- MaleBody rifle_back: offset 0.008 -0.102 0.061, rotate -49 11 0
    local mirror = getModelScript("Base.MaleBody"):getAttachmentById("atwob_rifle_back")
    near(mirror:getOffset():y(), 0.102, "offset y")
    near(mirror:getRotate():x(), 49, "rotate x")
    near(mirror:getRotate():y(), 11, "rotate y")
    eq(mirror:getBone(), "Bip01_BackPack", "bone")
end)

test("adding them again adds nothing", function()
    eq(ATWOB.addModelAttachments(), 0, "added")
end)

test("adding them to reloaded scripts adds them again", function()
    MODEL_SCRIPTS = loadCharacterModels()
    eq(ATWOB.addModelAttachments(), #BODIES * count(ATWOB.BACK_LOCATIONS), "added")
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
