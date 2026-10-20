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
        end
    end
end)

test("the angles of a rotation give the same rotation back", function()
    for _, angles in ipairs({ { -49, 11, 0 }, { 113, -5, -173 }, { 8, 85, 100 }, { 30, 90, -40 }, { 170, -89.99, 15 } }) do
        local back = { ATWOB.angles(ATWOB.rotation(angles[1], angles[2], angles[3])) }
        for _, axis in ipairs({ { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }) do
            near(dot(rotateAxis(back[1], back[2], back[3], axis), rotateAxis(angles[1], angles[2], angles[3], axis)), 1,
                table.concat(angles, " "))
        end
    end
end)

test("for any rotation, Back 2 mirrors the length and keeps every direction as far out of the back", function()
    local cases = {}
    for _, a in ipairs({ 0, 90, -90, 180, 45 }) do
        for _, b in ipairs({ 0, 90, -90, 89.999, -89.999, 45 }) do
            for _, c in ipairs({ 0, 90, -90, 180 }) do
                table.insert(cases, { a, b, c })
            end
        end
    end
    local seed = 12345
    for _ = 1, 500 do
        local angles = {}
        for i = 1, 3 do
            seed = (seed * 1103515245 + 12345) % 2147483648
            angles[i] = seed / 2147483648 * 360 - 180
        end
        table.insert(cases, angles)
    end
    for _, c in ipairs(cases) do
        local _, _, _, mx, my, mz = ATWOB.mirrorTransform(0, 0, 0, c[1], c[2], c[3])
        local what = table.concat(c, " ")
        for i, axis in ipairs({ { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }) do
            local before, after = rotateAxis(c[1], c[2], c[3], axis), rotateAxis(mx, my, mz, axis)
            truthy(math.abs(after[1] - before[1]) < 1e-9, what .. ": direction " .. i .. " out of the back")
            if i == 2 then
                truthy(math.abs(after[2] + before[2]) < 1e-9 and math.abs(after[3] - before[3]) < 1e-9, what .. ": length")
            end
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

test("an item on Back 2 has its length mirrored, and every part of it as far out of the back", function()
    for _, body in ipairs(BODIES) do
        local script = getModelScript(body)
        for _, attachment in pairs(ATWOB.BACK_LOCATIONS) do
            local what = body .. " " .. attachment
            local source = axes(script:getAttachmentById(attachment))
            local mirror = axes(script:getAttachmentById(ATWOB.mirrorAttachment(attachment)))
            near(dot(mirror[2], mirrored(source[2])), 1, what .. " length (Y)")
            -- Out of the back is X on the back bone: none of the item's directions
            -- may go further in or out, or the item goes into the body.
            for i = 1, 3 do
                near(mirror[i][1], source[i][1], what .. " direction " .. i .. " out of the back")
            end
        end
    end
end)

test("a rifle on Back 2 goes over the other shoulder", function()
    -- MaleBody rifle_back: offset 0.008 -0.102 0.061, rotate -49 11 0: along the
    -- back from the right side down to the left (Y points to the left).
    local source = axes(getModelScript("Base.MaleBody"):getAttachmentById("rifle_back"))[2]
    local mirror = getModelScript("Base.MaleBody"):getAttachmentById("atwob_rifle_back")
    near(mirror:getOffset():y(), 0.102, "offset y")
    local length = axes(mirror)[2]
    truthy(source[2] > 0.5 and length[2] < -0.5, "points the other way across the back")
    near(length[3], source[3], "as far down")
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

test("a body mod's own model gets the Back 2 attachments too, mirrored from its own", function()
    -- Like a body mod drawing characters with its own model (setForceModelScript),
    -- which carries the vanilla back attachments, moved to fit its mesh.
    local body = copyModelScript("TombBody.MaleBody", getModelScript("Base.MaleBody"), 0.01)
    local axe = newModelScript("Base.Axe")
    axe:addAttachment(ModelAttachment.new("world"))
    table.insert(MODEL_SCRIPTS, body)
    table.insert(MODEL_SCRIPTS, axe)
    eq(ATWOB.addModelAttachments(), count(ATWOB.BACK_LOCATIONS), "added, to the body mod's model only")
    for _, attachment in pairs(ATWOB.BACK_LOCATIONS) do
        local source = body:getAttachmentById(attachment)
        local mirror = body:getAttachmentById(ATWOB.mirrorAttachment(attachment))
        truthy(mirror, attachment)
        near(mirror:getOffset():x(), source:getOffset():x(), attachment .. " offset x, from the body mod's own")
        near(mirror:getOffset():y(), -source:getOffset():y(), attachment .. " offset y")
    end
    eq(axe:getAttachmentCount(), 1, "item models are left alone")
end)

-- Transforms as {R = columns, t = offset}: what an attachment does to its model.
local function transform(a)
    local r = a:getRotate()
    return {
        R = { rotateAxis(r:x(), r:y(), r:z(), { 1, 0, 0 }), rotateAxis(r:x(), r:y(), r:z(), { 0, 1, 0 }), rotateAxis(r:x(), r:y(), r:z(), { 0, 0, 1 }) },
        t = { a:getOffset():x(), a:getOffset():y(), a:getOffset():z() },
    }
end

local function apply(R, v)
    return { R[1][1] * v[1] + R[2][1] * v[2] + R[3][1] * v[3],
             R[1][2] * v[1] + R[2][2] * v[2] + R[3][2] * v[3],
             R[1][3] * v[1] + R[2][3] * v[2] + R[3][3] * v[3] }
end

local function compose(A, B)
    local t = apply(A.R, B.t)
    return { R = { apply(A.R, B.R[1]), apply(A.R, B.R[2]), apply(A.R, B.R[3]) },
             t = { t[1] + A.t[1], t[2] + A.t[2], t[3] + A.t[3] } }
end

local function inverse(A)
    local RT = { { A.R[1][1], A.R[2][1], A.R[3][1] }, { A.R[1][2], A.R[2][2], A.R[3][2] }, { A.R[1][3], A.R[2][3], A.R[3][3] } }
    local t = apply(RT, A.t)
    return { R = RT, t = { -t[1], -t[2], -t[3] } }
end

local function at(A, v)
    local p = apply(A.R, v)
    return { p[1] + A.t[1], p[2] + A.t[2], p[3] + A.t[3] }
end

test("the forged frying pan gets a Back 2 version of its own placement, with no bone", function()
    local pan = loadModels("media/scripts/generated/models_weapons.txt")
    for _, script in ipairs(pan) do
        if script:getFullType() == "Base.FryingPanForged" then pan = script end
    end
    table.insert(MODEL_SCRIPTS, pan)
    eq(ATWOB.addModelAttachments(), 2, "added, to the pan's two back attachments")
    local mirror = pan:getAttachmentById("atwob_fryingpan_back")
    truthy(mirror, "atwob_fryingpan_back")
    eq(mirror:getBone(), nil, "bone")
    near(mirror:getRotate():y(), 90, "rotate y, copied")
    eq(group:getLocation("ATWOB Pan On Back"):getAttachmentName(), "atwob_fryingpan_back", "location still on its own attachment")
end)

test("an item with its own placement has every part of it as far out of the back on Back 2", function()
    -- A placement like a weapon mod's (the pan's is only a turn about Y).
    local item = newModelScript("SomeMod.Rifle")
    local own = item:addAttachment(ModelAttachment.new("rifle_back"))
    own:getOffset():set(0.03, -0.02, 0.05)
    own:getRotate():set(10, 20, 30)
    table.insert(MODEL_SCRIPTS, item)
    ATWOB.addModelAttachments()
    for _, body in ipairs(BODIES) do
        local script = getModelScript(body)
        -- The game draws the item at body attachment x inverse of item attachment (then the mesh).
        local back = compose(transform(script:getAttachmentById("rifle_back")), inverse(transform(own)))
        local back2 = compose(transform(script:getAttachmentById("atwob_rifle_back")),
            inverse(transform(item:getAttachmentById("atwob_rifle_back"))))
        -- Points of a pan-sized item, standing out from where it is held.
        for _, point in ipairs({ { 0, 0, 0 }, { 0.2, 0, 0 }, { 0, 0.3, 0 }, { 0, 0, 0.2 }, { 0.1, -0.15, 0.12 } }) do
            near(at(back2, point)[1], at(back, point)[1], body .. " point " .. table.concat(point, " ") .. " out of the back")
        end
    end
end)

test("a backpack mod's own spot gets a Back 2 twin, mirrored on the bodies", function()
    group:getOrCreateLocation("Rifle On Big Bag"):setAttachmentName("rifle_back_bigbag")
    addBodyAttachment("rifle_back_bigbag", "Bip01_BackPack", "rifle_back_bag")
    ATWOB.addTwinLocations()
    ATWOB.addModelAttachments()
    eq(group:getLocation("ATWOB Rifle On Big Bag"):getAttachmentName(), "atwob_rifle_back_bigbag", "twin location")
    for _, body in ipairs(BODIES) do
        local script = getModelScript(body)
        local mirror = script:getAttachmentById("atwob_rifle_back_bigbag")
        truthy(mirror, body .. " mirror")
        near(mirror:getOffset():y(), -script:getAttachmentById("rifle_back_bigbag"):getOffset():y(), body .. " offset y")
    end
    eq(ATWOB.usableTwin("Rifle On Big Bag"), "ATWOB Rifle On Big Bag", "usable")
end)

test("a spot that is not on the back bone gets a twin, for the server, but no mirror", function()
    group:getOrCreateLocation("Rifle On Odd Bag"):setAttachmentName("rifle_oddbag")
    addBodyAttachment("rifle_oddbag", "Bip01_Spine1", "rifle_back_bag")
    ATWOB.addTwinLocations()
    ATWOB.addModelAttachments()
    truthy(group:getLocation("ATWOB Rifle On Odd Bag"), "twin location")
    eq(getModelScript("Base.MaleBody"):getAttachmentById("atwob_rifle_oddbag"), nil, "no mirror")
    eq(ATWOB.usableTwin("Rifle On Odd Bag"), nil, "not usable")
    eq(getModelScript("Base.MaleBody"):getAttachmentById("atwob_belt_left"), nil, "belt spots are not mirrored")
end)

test("twins are made once, and never of twins", function()
    local before = group:size()
    ATWOB.addTwinLocations()
    eq(group:size(), before, "no new locations the second time")
    for i = 0, group:size() - 1 do
        truthy(string.sub(group:getLocationByIndex(i):getId(), 1, 12) ~= "ATWOB ATWOB ", "twin of a twin")
    end
end)

test("adding them to reloaded scripts adds them again", function()
    MODEL_SCRIPTS = loadCharacterModels()
    -- With every location twinned, the bedroll spots (also on the back bone) get one too.
    truthy(ATWOB.addModelAttachments() >= #BODIES * count(ATWOB.BACK_LOCATIONS), "added")
    for _, body in ipairs(BODIES) do
        for _, attachment in pairs(ATWOB.BACK_LOCATIONS) do
            truthy(getModelScript(body):getAttachmentById(ATWOB.mirrorAttachment(attachment)), body .. " " .. attachment)
        end
    end
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
