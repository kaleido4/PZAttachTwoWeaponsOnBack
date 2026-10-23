-- Alice's Weapon Sling (workshop 3775549570), loaded from the Steam Workshop
-- folder when it is installed. It replaces ISHotbar:attachItem and the attach
-- action, and moves every item whose location has " Back" in its name beside a
-- worn bag, which would put Back 2's items on the vanilla bag locations.
-- Mods load in the mod list's order, shared files first, then client files:
-- SLING_FIRST (test_compat_sling_first.lua) puts it above this mod in the list.
-- Only its hotbar files are loaded, not the ones for its weapon parts.
dofile(ROOT .. "/tests/harness.lua")

local SLING = "../../workshop/content/108600/3775549570/mods/alicesWeaponSling/42/media/lua/"
local order = SLING_FIRST and "above this mod" or "below this mod"

print("ATWOB compatibility: Alice's Weapon Sling " .. order .. " in the mod list")

if not pcall(readfile, SLING .. "client/AliceWeaponSling_ISHotbar.lua") then
    print("  skipped: Alice's Weapon Sling is not installed")
    finish("ATWOB compatibility: Alice's Weapon Sling")
    return
end

local function loadSling(dir)
    if dir == "shared" then
        dofile(SLING .. "shared/AliceWeaponSling_AttachedLocations.lua")
        dofile(SLING .. "shared/TimedActions/ISAttachItemHotbar_AliceWeaponSling.lua")
    else
        dofile(SLING .. "client/AliceWeaponSling_ISHotbar.lua")
        dofile(SLING .. "client/AliceWeaponSling_ISHotbarAttachDefinition.lua")
    end
end

dofile(VANILLA .. "shared/NPCs/AttachedLocations.lua")
dofile(VANILLA .. "shared/TimedActions/ISAttachItemHotbar.lua")
if SLING_FIRST then loadSling("shared") end
dofile(MOD .. "shared/AttachTwoWeaponsOnBack/ATWOB_Shared.lua")
if not SLING_FIRST then loadSling("shared") end
dofile(VANILLA .. "client/Hotbar/ISHotbarAttachDefinition.lua")
dofile(VANILLA .. "client/Hotbar/ISHotbar.lua")
dofile(VANILLA .. "client/TimedActions/ISDetachItemHotbar.lua")
MODEL_SCRIPTS = loadCharacterModels()
if SLING_FIRST then loadSling("client") end
dofile(MOD .. "client/AttachTwoWeaponsOnBack/ATWOB_Hotbar.lua")
if not SLING_FIRST then loadSling("client") end
fire("OnGameBoot")

local BACK, BACK2 = 1, 2

local function newPlayer(...)
    local chr = newCharacter()
    for _, worn in ipairs({ ... }) do chr:wear(worn) end
    local hotbar = newHotbar(chr)
    hotbar:update()
    hotbar:update()
    return chr, hotbar, chr:addItem(newItem("Rifle", { name = "Shotgun" })), chr:addItem(newItem("BigBlade", { name = "Crowbar" }))
end

-- Pressing the hotbar key: the attach actions run to the end.
local function attachWithAnim(hotbar, item, slotIndex)
    ISTimedActionQueue.actions = {}
    local def = hotbar.availableSlot[slotIndex].def
    hotbar:attachItem(item, def.attachments[item:getAttachmentType()], slotIndex, def, true)
    for _, action in ipairs(ISTimedActionQueue.actions) do
        action:complete()
        action:perform()
    end
end

test("with a bag on, the Back 2 item goes on the mirrored bag location when loading", function()
    local chr, hotbar, shotgun, crowbar = newPlayer(newBackpack())
    attach(hotbar, shotgun, BACK)
    attach(hotbar, crowbar, BACK2)
    eq(shotgun:getAttachedToModel(), "Rifle On Back with Bag", "shotgun on Back")
    eq(crowbar:getAttachedToModel(), "ATWOB Big Blade On Back with Bag", "crowbar on Back 2")
    checkModel(hotbar)
end)

test("with a bag on, the Back 2 item goes on the mirrored bag location with the hotbar key", function()
    local chr, hotbar, shotgun, crowbar = newPlayer(newBackpack())
    attachWithAnim(hotbar, shotgun, BACK)
    attachWithAnim(hotbar, crowbar, BACK2)
    eq(shotgun:getAttachedToModel(), "Rifle On Back with Bag", "shotgun on Back")
    eq(crowbar:getAttachedToModel(), "ATWOB Big Blade On Back with Bag", "crowbar on Back 2")
    eq(hotbar.attachedItems[BACK2], crowbar, "crowbar in the slot")
    checkModel(hotbar)
end)

test("the bag list is back after attaching to Back 2", function()
    local chr, hotbar, shotgun, crowbar = newPlayer(newBackpack())
    attachWithAnim(hotbar, crowbar, BACK2)
    eq(hotbar.replacements.Rifle, "Rifle On Back with Bag", "bag list")
    attachWithAnim(hotbar, shotgun, BACK)
    eq(shotgun:getAttachedToModel(), "Rifle On Back with Bag", "shotgun on Back after it")
end)

test("without a bag, Back 2 is mirrored", function()
    local chr, hotbar, shotgun, crowbar = newPlayer()
    attachWithAnim(hotbar, shotgun, BACK)
    attachWithAnim(hotbar, crowbar, BACK2)
    eq(shotgun:getAttachedToModel(), "Rifle On Back", "shotgun on Back")
    eq(crowbar:getAttachedToModel(), "ATWOB Blade On Back", "crowbar on Back 2")
    checkModel(hotbar)
end)

test("the sling's own back slot still goes beside the bag", function()
    local sling = newItem(nil, { provides = { "AliceSlingBack" }, name = "Sling" })
    local chr, hotbar, shotgun = newPlayer(newBackpack(), sling)
    local index = hotbar:getThisSlotIndex("AliceSlingBack")
    truthy(index, "sling slot")
    attachWithAnim(hotbar, shotgun, index)
    eq(shotgun:getAttachedToModel(), "AliceSlingRifleBag", "rifle on the sling")
end)

finish("ATWOB compatibility: Alice's Weapon Sling")
