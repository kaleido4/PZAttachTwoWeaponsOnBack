--[[
    Second Back Slot: a second back slot on the hotbar.

    The slot ("Back 2") takes the same items as the vanilla back slot and puts
    them on the mirrored locations from ATWOB_Shared.lua. ISHotbar is wrapped,
    not copied, so other hotbar mods keep working:
      * haveThisSlot: refresh() drops every slot that is not the back slot or
        one a worn item provides. Ours stays, like the back slot.
      * loadPosition: adds the slot after the back slot (key 2) on a new
        character, and to saves made without the mod. With a Strength
        requirement (sandbox), the slot only shows up from that level.
      * update: adds or takes away the slot as soon as Strength crosses the
        requirement while playing, and makes sure the model the character is
        drawn with has the Back 2 attachments.
      * refresh (wrapped at boot, after other mods): puts items back on their
        own slots when another hotbar mod mixed up the slot numbers.
      * attachItem / canBeAttached: with a bag on, vanilla moves back items
        beside it, but only for slots named "Back". Ours does the same with the
        mirrored "with Bag" locations. attachItem is wrapped at boot, after
        other mods, like the attach action: while an item goes on our slot,
        other mods do not see the bag list, so they cannot move it again.
--]]

require "Hotbar/ISHotbar"
require "Hotbar/ISHotbarAttachDefinition"
require "TimedActions/ISAttachItemHotbar"

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
    -- The inventory window lists the item with the equipped ones until it is
    -- rebuilt; the vanilla detach action asks for that the same way.
    ISInventoryPage.renderDirty = true
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

-- The model the character is drawn with needs the Back 2 attachments: a body
-- mod can draw characters with its own model (HumanVisual:setForceModelScript),
-- and scripts can be loaded again after boot. Each model is checked once.
local checkedModels = {}
function ATWOB.checkModel(chr)
    local visual = chr.getHumanVisual and chr:getHumanVisual()
    local script = visual and visual:getModelScript()
    if script and not checkedModels[script] then
        checkedModels[script] = true
        if ATWOB.addMirrors(script) > 0 then
            chr:resetModelNextFrame()
        end
    end
end

-- Strength, and the sandbox option, can change while playing: the slot follows
-- on the next frame, where vanilla also drops hotbar items that no longer fit.
-- Not during a timed action, which may be about to use a slot index.
local original_update = ISHotbar.update
function ISHotbar:update()
    ATWOB.checkModel(self.chr)
    local queue = ISTimedActionQueue.queues[self.chr]
    if not (queue and #queue.queue > 0) and ATWOB.updateSlot(self) then
        ATWOB.fixAttachedSlots(self)
        self:reloadIcons()
        self:savePosition()
    end
    return original_update(self)
end

-- Another hotbar mod can move slots and leave items on the wrong slot number:
-- vanilla's update then drops every item whose slot cannot hold it. Reorder The
-- Hotbar does it whenever worn items change, since it only expects "Back" to
-- stay: it moves Back 2 to the end, then sorts the slots back before matching
-- the items to them again by their old numbers. The slot type an item saved is
-- still right, so the items are matched to their slots by type again.
function ATWOB.healSlots(hotbar)
    local mixedUp = false
    for index, item in pairs(hotbar.attachedItems) do
        local slotType = item:getAttachedSlotType()
        local slot = hotbar.availableSlot[index]
        if slotType and not (slot and slot.slotType == slotType) then
            mixedUp = true
        end
    end
    if not mixedUp then
        return false
    end
    ATWOB.fixAttachedSlots(hotbar)
    hotbar:reloadIcons()
    if ReorderTheHotbar_Mod then
        -- It also keeps each slot's item on the slot, for dragging slots around.
        for index, slot in pairs(hotbar.availableSlot) do
            slot.item = hotbar.attachedItems[index]
        end
    end
    return true
end

-- Our slot already put its item beside the bag (ATWOB.getLocation). Some mods
-- move every item whose location has " Back" in its name beside the bag, not
-- only on the slot named "Back" like vanilla: Alice's Weapon Sling then puts it
-- on the vanilla bag location, on the first back slot's side. While an item goes
-- on our slot, they see an empty bag list; vanilla does not read it for our slot.
local function withoutBagList(hotbar, fn, ...)
    local replacements = hotbar.replacements
    local empty = {}
    hotbar.replacements = empty
    local ok, result = pcall(fn, ...)
    -- Unless the list was made again in the meantime.
    if hotbar.replacements == empty then
        hotbar.replacements = replacements
    end
    if not ok then
        error(result, 0)
    end
    return result
end

local function installAttachItem()
    local original_attachItem = ISHotbar.attachItem
    function ISHotbar:attachItem(item, slot, slotIndex, slotDef, doAnim)
        if not isOurSlot(slotDef) then
            return original_attachItem(self, item, slot, slotIndex, slotDef, doAnim)
        end
        slot = ATWOB.getLocation(self, item, slot)
        -- Vanilla only checks for "null" without the animation.
        if doAnim and slot == "null" then
            return
        end
        return withoutBagList(self, original_attachItem, self, item, slot, slotIndex, slotDef, doAnim)
    end

    -- The action attaches the item when it is done; a mod can look for the bag there too.
    for _, name in ipairs({ "complete", "perform" }) do
        local original = ISAttachItemHotbar[name]
        if original then
            ISAttachItemHotbar[name] = function(self, ...)
                if self.hotbar and isOurSlot(self.slotDef) then
                    return withoutBagList(self.hotbar, original, self, ...)
                end
                return original(self, ...)
            end
        end
    end
end

-- At boot, once every mod has replaced or wrapped refresh, attachItem and the
-- attach action, so these run after them all.
Events.OnGameBoot.Add(function()
    if ATWOB.healInstalled then
        return
    end
    ATWOB.healInstalled = true
    local original_refresh = ISHotbar.refresh
    function ISHotbar:refresh()
        original_refresh(self)
        ATWOB.healSlots(self)
    end
    installAttachItem()
end)

local original_canBeAttached = ISHotbar.canBeAttached
function ISHotbar:canBeAttached(slot, item)
    if slot and isOurSlot(slot.def) and ATWOB.getLocation(self, item, nil) == "null" then
        return false
    end
    return original_canBeAttached(self, slot, item)
end
