-- Other hotbar mods, loaded from the Steam Workshop folder when they are installed,
-- in the game's load order: vanilla, then this mod ("AttachTwoWeaponsOnBack/..."),
-- then theirs, then OnGameBoot.
dofile(ROOT .. "/tests/harness.lua")
dofile(VANILLA .. "shared/NPCs/AttachedLocations.lua")
dofile(VANILLA .. "client/Hotbar/ISHotbarAttachDefinition.lua")
dofile(VANILLA .. "client/Hotbar/ISHotbar.lua")
dofile(VANILLA .. "shared/TimedActions/ISAttachItemHotbar.lua")
dofile(VANILLA .. "client/TimedActions/ISDetachItemHotbar.lua")
MODEL_SCRIPTS = loadCharacterModels()
dofile(MOD .. "shared/AttachTwoWeaponsOnBack/ATWOB_Shared.lua")
dofile(MOD .. "client/AttachTwoWeaponsOnBack/ATWOB_Hotbar.lua")

-- Reorder The Hotbar (workshop 2903771337), next to the game in the Steam library.
local REORDER_THE_HOTBAR = "../../workshop/content/108600/2903771337/mods/ReorderTheHotbar/42.0/media/lua/client/ReorderTheHotbar/ReorderTheHotbar_ISHotbar.lua"

print("ATWOB compatibility")

if not pcall(readfile, REORDER_THE_HOTBAR) then
    print("  skipped: Reorder The Hotbar is not installed")
else
    dofile(REORDER_THE_HOTBAR)
    fire("OnGameBoot")

    -- A character with a belt, the bolt cutters on Back 2 and a hammer on the left belt.
    local function setUp()
        local chr = newCharacter()
        chr:wear(newBelt())
        local hotbar = newHotbar(chr)
        hotbar:update()
        hotbar:update()
        local bolt = chr:addItem(newItem("BigBlade", { name = "BoltCutters" }))
        local hammer = chr:addItem(newItem("Hammer"))
        attach(hotbar, bolt, 2)
        attach(hotbar, hammer, 3)
        return chr, hotbar, bolt, hammer
    end

    test("Reorder The Hotbar: items stay on their slots when worn items change", function()
        local chr, hotbar, bolt, hammer = setUp()
        chr:wear(newItem(nil, { name = "Hat" }))
        clothingUpdated(hotbar)
        hotbar:update()
        eq(slotTypes(hotbar), "Back,ATWOB_Back2,SmallBeltLeft,SmallBeltRight", "slots")
        eq(hotbar.attachedItems[2], bolt, "bolt cutters on Back 2")
        eq(hotbar.attachedItems[3], hammer, "hammer on the left belt")
        eq(hotbar.availableSlot[2].item, bolt, "its own record of Back 2's item")
        checkModel(hotbar)
    end)

    test("Reorder The Hotbar: items are on their slots after loading the save", function()
        local chr, hotbar, bolt, hammer = setUp()
        chr:wear(newItem(nil, { name = "Hat" }))
        clothingUpdated(hotbar)
        chr.attached = {}
        hotbar = newHotbar(chr)
        hotbar:update()
        hotbar:update()
        eq(hotbar.attachedItems[hotbar:getThisSlotIndex("ATWOB_Back2")], bolt, "bolt cutters on Back 2")
        eq(hotbar.attachedItems[hotbar:getThisSlotIndex("SmallBeltLeft")], hammer, "hammer on the left belt")
        checkModel(hotbar)
    end)
end

finish("ATWOB compatibility")
