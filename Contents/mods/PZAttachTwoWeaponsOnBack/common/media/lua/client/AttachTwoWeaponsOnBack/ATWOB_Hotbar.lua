--[[
    Attach Two Weapons On Back: a second back slot on the hotbar.

    The slot ("Back 2") takes the same items as the vanilla back slot and puts
    them on the mirrored locations from ATWOB_Shared.lua. ISHotbar is wrapped,
    not copied, so other hotbar mods keep working:
      * haveThisSlot: refresh() drops every slot that is not the back slot or
        one a worn item provides. Ours stays, like the back slot.
      * loadPosition: adds the slot after the back slot (key 2) on a new
        character, and to saves made without the mod. With a Strength
        requirement (sandbox), the slot only shows up from that level, checked
        every in-game minute.
      * attachItem / canBeAttached: with a bag on, vanilla moves back items
        beside it, but only for slots named "Back". Ours does the same with the
        mirrored "with Bag" locations.
--]]

require "Hotbar/ISHotbar"
require "Hotbar/ISHotbarAttachDefinition"

ATWOB.SLOT_TYPE = "ATWOB_Back2"

-- Not named "Back": vanilla would then put its items on the vanilla bag
-- locations, where the first back slot's items go.
local slotDef = {
    type = ATWOB.SLOT_TYPE,
    name = "Back 2",
    animset = "back",
    attachments = {},
}
table.insert(ISHotbarAttachDefinition, slotDef)
ATWOB.slotDef = slotDef

-- Takes every item type the vanilla back slot takes (other mods can add some),
-- as long as its location has a mirror.
function ATWOB.syncSlotDef()
    local attachments = {}
    for _, def in ipairs(ISHotbarAttachDefinition) do
        if def.type == "Back" then
            for attachmentType, location in pairs(def.attachments) do
                if ATWOB.BACK_LOCATIONS[location] then
                    attachments[attachmentType] = ATWOB.mirrorLocation(location)
                end
            end
        end
    end
    slotDef.attachments = attachments
end

ATWOB.syncSlotDef()
Events.OnGameBoot.Add(ATWOB.syncSlotDef)

-- Where an item goes on our slot: with a bag on, the mirror of the vanilla bag
-- location, or "null" when it cannot be on the back with a bag (guitars).
function ATWOB.getLocation(hotbar, item, location)
    local replacement = hotbar.replacements and hotbar.replacements[item:getAttachmentType()]
    if replacement == "null" then
        return "null"
    end
    if replacement and ATWOB.BACK_LOCATIONS[replacement] then
        return ATWOB.mirrorLocation(replacement)
    end
    return location
end

-- Sandbox: the Strength level needed for our slot. 0 (the default): everyone has it.
function ATWOB.getRequiredStrength()
    local vars = SandboxVars and SandboxVars.PZAttachTwoWeaponsOnBack
    return vars and vars.RequiredStrength or 0
end

function ATWOB.isUnlocked(chr)
    return chr:getPerkLevel(Perks.Strength) >= ATWOB.getRequiredStrength()
end

local function orderedSlots(hotbar)
    local indices = {}
    for index in pairs(hotbar.availableSlot) do
        table.insert(indices, index)
    end
    table.sort(indices)
    local slots = {}
    for _, index in ipairs(indices) do
        table.insert(slots, hotbar.availableSlot[index])
    end
    return slots
end

-- Puts our slot right after the back slot, so it is key 2 on a new character.
-- In a save from before the mod, the slots after it move up one.
function ATWOB.insertSlot(hotbar)
    local ours = { slotType = slotDef.type, name = slotDef.name, def = slotDef }
    local slots = {}
    for _, slot in ipairs(orderedSlots(hotbar)) do
        table.insert(slots, slot)
        if ours and slot.slotType == "Back" then
            table.insert(slots, ours)
            ours = nil
        end
    end
    if ours then
        table.insert(slots, ours)
    end
    hotbar.availableSlot = slots
end

-- Takes our slot away; its item comes off the back and stays in the inventory.
function ATWOB.removeSlot(hotbar)
    local slots = {}
    for _, slot in ipairs(orderedSlots(hotbar)) do
        if slot.slotType ~= ATWOB.SLOT_TYPE then
            table.insert(slots, slot)
        end
    end
    hotbar.availableSlot = slots
    local items = hotbar.chr:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:getAttachedSlotType() == ATWOB.SLOT_TYPE then
            hotbar.chr:removeAttachedItem(item)
            item:setAttachedSlot(-1)
            item:setAttachedSlotType(nil)
            item:setAttachedToModel(nil)
            if isClient() then
                syncItemFields(hotbar.chr, item)
            end
        end
    end
end

-- Adds or takes away our slot to match the Strength requirement. Returns
-- whether it did; the other slots' items then need fixAttachedSlots.
function ATWOB.updateSlot(hotbar)
    local unlocked = ATWOB.isUnlocked(hotbar.chr)
    if unlocked == hotbar:haveThisSlot(ATWOB.SLOT_TYPE) then
        return false
    end
    if unlocked then
        ATWOB.insertSlot(hotbar)
    else
        ATWOB.removeSlot(hotbar)
    end
    return true
end

-- An item saves both its slot index and its slot type. When slots moved, the
-- index is matched to the type again, like refresh() does when worn items move
-- slots while playing.
function ATWOB.fixAttachedSlots(hotbar)
    local items = hotbar.chr:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local index = item:getAttachedSlot()
        local slotType = item:getAttachedSlotType()
        local slot = hotbar.availableSlot[index]
        if index > -1 and slotType and not (slot and slot.slotType == slotType) then
            local newIndex = hotbar:getThisSlotIndex(slotType)
            if newIndex then
                item:setAttachedSlot(newIndex)
                if isClient() then
                    syncItemFields(hotbar.chr, item)
                end
            end
        end
    end
end

local function isOurSlot(def)
    return def ~= nil and def.type == ATWOB.SLOT_TYPE
end

local original_haveThisSlot = ISHotbar.haveThisSlot
function ISHotbar:haveThisSlot(slotType, list)
    -- Only refresh() passes a list: the slots to keep.
    if slotType == ATWOB.SLOT_TYPE and list and list ~= self.availableSlot then
        return true
    end
    return original_haveThisSlot(self, slotType, list)
end

local original_loadPosition = ISHotbar.loadPosition
function ISHotbar:loadPosition()
    original_loadPosition(self)
    ATWOB.updateSlot(self)
    ATWOB.fixAttachedSlots(self)
end

-- Strength, and the sandbox option, can change while playing. Not during a
-- timed action, which may be about to use a slot index.
Events.EveryOneMinute.Add(function()
    for playerNum = 0, getNumActivePlayers() - 1 do
        local hotbar = getPlayerHotbar(playerNum)
        local queue = hotbar and ISTimedActionQueue.queues[hotbar.chr]
        if hotbar and not (queue and #queue.queue > 0) and ATWOB.updateSlot(hotbar) then
            ATWOB.fixAttachedSlots(hotbar)
            hotbar:reloadIcons()
            hotbar:savePosition()
        end
    end
end)

local original_canBeAttached = ISHotbar.canBeAttached
function ISHotbar:canBeAttached(slot, item)
    if slot and isOurSlot(slot.def) and ATWOB.getLocation(self, item, nil) == "null" then
        return false
    end
    return original_canBeAttached(self, slot, item)
end

local original_attachItem = ISHotbar.attachItem
function ISHotbar:attachItem(item, slot, slotIndex, slotDef, doAnim)
    if isOurSlot(slotDef) then
        slot = ATWOB.getLocation(self, item, slot)
        -- Vanilla only checks for "null" without the animation.
        if doAnim and slot == "null" then
            return
        end
    end
    return original_attachItem(self, item, slot, slotIndex, slotDef, doAnim)
end
