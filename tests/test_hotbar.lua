dofile(ROOT .. "/tests/harness.lua")
dofile(VANILLA .. "shared/NPCs/AttachedLocations.lua")
dofile(VANILLA .. "client/Hotbar/ISHotbarAttachDefinition.lua")
dofile(VANILLA .. "client/Hotbar/ISHotbar.lua")
dofile(VANILLA .. "shared/TimedActions/ISAttachItemHotbar.lua")
dofile(VANILLA .. "client/TimedActions/ISDetachItemHotbar.lua")
MODEL_SCRIPTS = loadCharacterModels()
dofile(MOD .. "shared/AttachTwoWeaponsOnBack/ATWOB_Shared.lua")
dofile(MOD .. "client/AttachTwoWeaponsOnBack/ATWOB_Hotbar.lua")
fire("OnGameBoot")

local BACK, BACK2 = 1, 2

local function newPlayer()
    local chr = newCharacter()
    return chr, newHotbar(chr)
end

local function shotgun(chr) return chr:addItem(newItem("Rifle", { name = "Shotgun" })) end
local function crowbar(chr) return chr:addItem(newItem("BigBlade", { name = "Crowbar" })) end

print("ATWOB hotbar")

test("a new character has Back and Back 2 on keys 1 and 2", function()
    local chr, hotbar = newPlayer()
    eq(slotTypes(hotbar), "Back,ATWOB_Back2", "slots")
    eq(table.concat(chr.modData.hotbar, ","), "Back,ATWOB_Back2", "saved slots")
end)

test("Back 2 takes every item Back takes", function()
    local back
    for _, def in ipairs(ISHotbarAttachDefinition) do
        if def.type == "Back" then back = def end
    end
    eq(count(ATWOB.slotDef.attachments), count(back.attachments), "item types")
    for attachmentType, location in pairs(back.attachments) do
        eq(ATWOB.slotDef.attachments[attachmentType], ATWOB.mirrorLocation(location), attachmentType)
    end
end)

test("a shotgun and a crowbar go on the back together, each on its own key", function()
    local chr, hotbar = newPlayer()
    local crowbarItem, shotgunItem = crowbar(chr), shotgun(chr)
    attach(hotbar, crowbarItem, BACK)
    attach(hotbar, shotgunItem, BACK2)
    hotbar:update()
    hotbar:update()
    eq(hotbar.attachedItems[BACK], crowbarItem, "key 1")
    eq(hotbar.attachedItems[BACK2], shotgunItem, "key 2")
    eq(crowbarItem:getAttachedToModel(), "Blade On Back", "crowbar location")
    eq(shotgunItem:getAttachedToModel(), "ATWOB Rifle On Back", "shotgun location")
    checkModel(hotbar)
end)

test("two rifles go on the back together", function()
    local chr, hotbar = newPlayer()
    local first, second = shotgun(chr), shotgun(chr)
    attach(hotbar, first, BACK)
    attach(hotbar, second, BACK2)
    hotbar:update()
    eq(first:getAttachedToModel(), "Rifle On Back", "first")
    eq(second:getAttachedToModel(), "ATWOB Rifle On Back", "second")
    checkModel(hotbar)
end)

test("Back 2 does not take belt items", function()
    local chr, hotbar = newPlayer()
    local hammer = chr:addItem(newItem("Hammer"))
    truthy(not hotbar:canBeAttached(hotbar.availableSlot[BACK2], hammer), "hammer")
    truthy(hotbar:canBeAttached(hotbar.availableSlot[BACK2], shotgun(chr)), "shotgun")
end)

test("Back 2 stays when worn items add and remove slots", function()
    local chr, hotbar = newPlayer()
    local belt = newBelt()
    local shotgunItem = shotgun(chr)
    local hammer = chr:addItem(newItem("Hammer"))
    attach(hotbar, shotgunItem, BACK2)
    chr:wear(belt)
    clothingUpdated(hotbar)
    eq(slotTypes(hotbar), "Back,ATWOB_Back2,SmallBeltLeft,SmallBeltRight", "with a belt")
    attach(hotbar, hammer, 3)
    checkModel(hotbar)
    chr:takeOff(belt)
    clothingUpdated(hotbar)
    eq(slotTypes(hotbar), "Back,ATWOB_Back2", "without the belt")
    eq(hotbar.attachedItems[BACK2], shotgunItem, "shotgun still on Back 2")
    eq(hammer:getAttachedSlot(), -1, "hammer off the hotbar")
    checkModel(hotbar)
end)

test("with a bag on, both back items go beside it, and come back when it is off", function()
    local chr, hotbar = newPlayer()
    local bag = newBackpack()
    local shotgunItem, crowbarItem = shotgun(chr), crowbar(chr)
    attach(hotbar, shotgunItem, BACK)
    attach(hotbar, crowbarItem, BACK2)
    chr:wear(bag)
    clothingUpdated(hotbar)
    eq(shotgunItem:getAttachedToModel(), "Rifle On Back with Bag", "shotgun with a bag")
    eq(crowbarItem:getAttachedToModel(), "ATWOB Big Blade On Back with Bag", "crowbar with a bag")
    checkModel(hotbar)
    chr:takeOff(bag)
    clothingUpdated(hotbar)
    eq(shotgunItem:getAttachedToModel(), "Rifle On Back", "shotgun without the bag")
    eq(crowbarItem:getAttachedToModel(), "ATWOB Blade On Back", "crowbar without the bag")
    checkModel(hotbar)
end)

test("a guitar comes off Back 2 when a bag goes on, like off Back", function()
    local chr, hotbar = newPlayer()
    local guitar = chr:addItem(newItem("Guitar"))
    attach(hotbar, guitar, BACK2)
    eq(guitar:getAttachedToModel(), "ATWOB Guitar", "guitar location")
    chr:wear(newBackpack())
    clothingUpdated(hotbar)
    eq(guitar:getAttachedSlot(), -1, "guitar off the hotbar")
    eq(chr.attached["ATWOB Guitar"], nil, "guitar off the model")
    truthy(not hotbar:canBeAttached(hotbar.availableSlot[BACK2], guitar), "guitar refused")
    checkModel(hotbar)
end)

test("attaching with the animation puts the item on the mirrored bag location", function()
    local chr, hotbar = newPlayer()
    chr:wear(newBackpack())
    clothingUpdated(hotbar)
    local first, second = shotgun(chr), shotgun(chr)
    attach(hotbar, first, BACK)
    local def = hotbar.availableSlot[BACK2].def
    hotbar:attachItem(second, def.attachments.Rifle, BACK2, def, true)
    local action = ISTimedActionQueue.actions[#ISTimedActionQueue.actions]
    eq(action.Type, "ISAttachItemHotbar", "queued action")
    eq(action.slot, "ATWOB Rifle On Back with Bag", "action location")
    action:perform()
    eq(hotbar.attachedItems[BACK2], second, "on Back 2")
    eq(second:getAttachedToModel(), "ATWOB Rifle On Back with Bag", "location")
    checkModel(hotbar)
end)

test("a save from before the mod gets Back 2 as key 2, and its items keep their slots", function()
    local chr = newCharacter()
    chr.modData.hotbar = { "Back", "SmallBeltLeft", "SmallBeltRight" }
    chr:wear(newBelt())
    local saved = {
        { newItem("Rifle", { name = "Shotgun" }), 1, "Back", "Rifle On Back" },
        { newItem("Hammer"), 2, "SmallBeltLeft", "Belt Left" },
        { newItem("Screwdriver"), 3, "SmallBeltRight", "Belt Right Screwdriver" },
    }
    for _, s in ipairs(saved) do
        local item = chr:addItem(s[1])
        item:setAttachedSlot(s[2])
        item:setAttachedSlotType(s[3])
        item:setAttachedToModel(s[4])
    end
    local hotbar = newHotbar(chr)
    hotbar:update()
    eq(slotTypes(hotbar), "Back,ATWOB_Back2,SmallBeltLeft,SmallBeltRight", "slots")
    eq(table.concat(chr.modData.hotbar, ","), "Back,ATWOB_Back2,SmallBeltLeft,SmallBeltRight", "saved slots")
    eq(hotbar.attachedItems[1], saved[1][1], "shotgun on key 1")
    eq(hotbar.attachedItems[2], nil, "Back 2 empty")
    eq(hotbar.attachedItems[3], saved[2][1], "hammer on key 3")
    eq(hotbar.attachedItems[4], saved[3][1], "screwdriver on key 4")
    checkModel(hotbar)
end)

test("a save with the mod loads back the same", function()
    local chr, hotbar = newPlayer()
    chr:wear(newBelt())
    clothingUpdated(hotbar)
    local crowbarItem = crowbar(chr)
    local hammer = chr:addItem(newItem("Hammer"))
    attach(hotbar, crowbarItem, BACK2)
    attach(hotbar, hammer, 3)
    -- Load: a new hotbar from the saved character, nothing on the model yet.
    chr.attached = {}
    hotbar = newHotbar(chr)
    hotbar:update()
    eq(slotTypes(hotbar), "Back,ATWOB_Back2,SmallBeltLeft,SmallBeltRight", "slots")
    eq(hotbar.attachedItems[BACK2], crowbarItem, "crowbar on Back 2")
    eq(hotbar.attachedItems[3], hammer, "hammer on key 3")
    eq(crowbarItem:getAttachedToModel(), "ATWOB Blade On Back", "crowbar location")
    checkModel(hotbar)
end)

test("items go back to their own slots when another mod mixed up the slot numbers", function()
    local chr, hotbar = newPlayer()
    chr:wear(newBelt())
    clothingUpdated(hotbar)
    local crowbarItem = crowbar(chr)
    local hammer = chr:addItem(newItem("Hammer"))
    attach(hotbar, crowbarItem, BACK2)
    attach(hotbar, hammer, 3)
    -- What Reorder The Hotbar leaves behind: the slots in order, the items not.
    crowbarItem:setAttachedSlot(4)
    hammer:setAttachedSlot(2)
    hotbar:reloadIcons()
    hotbar:refresh()
    hotbar:update()
    eq(hotbar.attachedItems[BACK2], crowbarItem, "crowbar on Back 2")
    eq(hotbar.attachedItems[3], hammer, "hammer on the left belt")
    checkModel(hotbar)
end)

local function requireStrength(level)
    SandboxVars.PZAttachTwoWeaponsOnBack.RequiredStrength = level
end

test("with a Strength requirement, Back 2 shows up at that level", function()
    requireStrength(5)
    local chr = newCharacter()
    chr.levels.Strength = 4
    local hotbar = newHotbar(chr)
    chr:wear(newBelt())
    clothingUpdated(hotbar)
    eq(slotTypes(hotbar), "Back,SmallBeltLeft,SmallBeltRight", "below the level")
    local hammer = chr:addItem(newItem("Hammer"))
    attach(hotbar, hammer, 2)
    hotbar:update()
    eq(slotTypes(hotbar), "Back,SmallBeltLeft,SmallBeltRight", "still below the level")
    chr.levels.Strength = 5
    hotbar:update()
    eq(slotTypes(hotbar), "Back,ATWOB_Back2,SmallBeltLeft,SmallBeltRight", "at the level")
    eq(table.concat(chr.modData.hotbar, ","), "Back,ATWOB_Back2,SmallBeltLeft,SmallBeltRight", "saved slots")
    eq(hotbar.attachedItems[3], hammer, "hammer moved to key 3")
    hotbar:update()
    checkModel(hotbar)
    requireStrength(0)
end)

test("when Strength drops below the requirement, Back 2 goes and its item comes off", function()
    requireStrength(5)
    local chr = newCharacter()
    chr.levels.Strength = 5
    local hotbar = newHotbar(chr)
    chr:wear(newBelt())
    clothingUpdated(hotbar)
    local crowbarItem = crowbar(chr)
    local hammer = chr:addItem(newItem("Hammer"))
    attach(hotbar, crowbarItem, BACK2)
    attach(hotbar, hammer, 3)
    ISInventoryPage.renderDirty = false
    chr.levels.Strength = 4
    hotbar:update()
    eq(slotTypes(hotbar), "Back,SmallBeltLeft,SmallBeltRight", "slots")
    eq(ISInventoryPage.renderDirty, true, "inventory window asked to redraw")
    eq(crowbarItem:getAttachedSlot(), -1, "crowbar off the hotbar")
    eq(chr.attached["ATWOB Blade On Back"], nil, "crowbar off the model")
    truthy(chr:getInventory():contains(crowbarItem), "crowbar still in the inventory")
    eq(hotbar.attachedItems[2], hammer, "hammer back on key 2")
    hotbar:update()
    checkModel(hotbar)
    requireStrength(0)
end)

test("Back 2 comes back when Strength is trained back up to the requirement", function()
    requireStrength(5)
    local chr = newCharacter()
    chr.levels.Strength = 5
    local hotbar = newHotbar(chr)
    local crowbarItem = crowbar(chr)
    attach(hotbar, crowbarItem, BACK2)
    chr.levels.Strength = 4
    hotbar:update()
    eq(slotTypes(hotbar), "Back", "after the drop")
    truthy(chr:getInventory():contains(crowbarItem), "crowbar kept in the inventory")
    chr.levels.Strength = 5
    hotbar:update()
    eq(slotTypes(hotbar), "Back,ATWOB_Back2", "trained back up")
    attach(hotbar, crowbarItem, BACK2)
    eq(hotbar.attachedItems[BACK2], crowbarItem, "crowbar goes on Back 2 again")
    checkModel(hotbar)
    requireStrength(0)
end)

test("the slot does not change during a timed action", function()
    requireStrength(5)
    local chr = newCharacter()
    local hotbar = newHotbar(chr)
    chr.levels.Strength = 5
    ISTimedActionQueue.queues[chr] = { queue = { {} } }
    hotbar:update()
    eq(slotTypes(hotbar), "Back", "during the action")
    ISTimedActionQueue.queues[chr] = nil
    hotbar:update()
    eq(slotTypes(hotbar), "Back,ATWOB_Back2", "after it")
    requireStrength(0)
end)

test("a character saved with Back 2 loads without it when below the requirement", function()
    requireStrength(5)
    local chr = newCharacter()
    chr.levels.Strength = 2
    chr.modData.hotbar = { "Back", "ATWOB_Back2", "SmallBeltLeft", "SmallBeltRight" }
    chr:wear(newBelt())
    local saved = {
        { newItem("BigBlade", { name = "Crowbar" }), 2, "ATWOB_Back2", "ATWOB Blade On Back" },
        { newItem("Hammer"), 3, "SmallBeltLeft", "Belt Left" },
        { newItem("Screwdriver"), 4, "SmallBeltRight", "Belt Right Screwdriver" },
    }
    for _, s in ipairs(saved) do
        local item = chr:addItem(s[1])
        item:setAttachedSlot(s[2])
        item:setAttachedSlotType(s[3])
        item:setAttachedToModel(s[4])
    end
    local hotbar = newHotbar(chr)
    hotbar:update()
    eq(slotTypes(hotbar), "Back,SmallBeltLeft,SmallBeltRight", "slots")
    eq(saved[1][1]:getAttachedSlot(), -1, "crowbar off the hotbar")
    eq(hotbar.attachedItems[2], saved[2][1], "hammer on key 2")
    eq(hotbar.attachedItems[3], saved[3][1], "screwdriver on key 3")
    checkModel(hotbar)
    requireStrength(0)
end)

finish("ATWOB hotbar")
