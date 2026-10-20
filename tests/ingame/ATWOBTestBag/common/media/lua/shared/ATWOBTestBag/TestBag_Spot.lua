--[[
    Test only: a backpack mod's own spot for rifles, like some backpack mods
    bring for their bags. It is the vanilla rifle-with-bag spot moved 20 cm up
    and 10 cm further out to the right, so it is easy to tell apart. With it,
    Second Back Slot should put a rifle on Back 2 beside the bag on the left,
    at the vanilla bag spot's height (its mirror), not behind the bag.
--]]

AttachedLocations.getGroup("Human"):getOrCreateLocation("Test Rifle On Bag"):setAttachmentName("testbag_rifle_back_bag")

local function addSpot()
    local scripts = getScriptManager():getAllModelScripts()
    for i = 0, scripts:size() - 1 do
        local script = scripts:get(i)
        local fullType = script:getFullType()
        if (fullType == "Base.FemaleBody" or fullType == "Base.MaleBody") and not script:getAttachmentById("testbag_rifle_back_bag") then
            local source = script:getAttachmentById("rifle_back_bag")
            if source then
                local o, r = source:getOffset(), source:getRotate()
                local spot = ModelAttachment.new("testbag_rifle_back_bag")
                spot:setBone(source:getBone())
                -- On the back bone Y points to the left (vanilla's is on the right) and Z up.
                spot:getOffset():set(o:x(), o:y() - 0.1, o:z() + 0.2)
                spot:getRotate():set(r:x(), r:y(), r:z())
                script:addAttachment(spot)
                print("ATWOB Test Bag: added the test spot to " .. fullType)
            end
        end
    end
end

Events.OnGameBoot.Add(addSpot)
Events.OnGameStart.Add(addSpot)
