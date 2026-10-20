--[[
    Test harness: assertions, and mocks of the bits of the game the mod and the
    vanilla hotbar use. The vanilla code itself (ISHotbar, the attach/detach
    actions, the slot and location definitions) is loaded from the game, as are
    the body models, so the mod is tested against them (B42.21).

    The character's attached items follow the game: a location must exist in
    the "Human" group ("no such location" otherwise), and holds one item, so
    attaching a second item there knocks the first one off the model.
--]]

MOD = ROOT .. "/Contents/mods/PZAttachTwoWeaponsOnBack/common/media/lua/"
-- The runner works from the game folder.
VANILLA = "media/lua/"

local passed, failed = 0, 0

function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. ": " .. tostring(err))
    end
end

function finish(suite)
    print(suite .. ": " .. passed .. " passed, " .. failed .. " failed")
    if failed > 0 then error(suite .. ": " .. failed .. " test(s) failed") end
end

function eq(actual, expected, what)
    if actual ~= expected then
        error((what or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

function near(actual, expected, what)
    if math.abs(actual - expected) > 0.0001 then
        error((what or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

function truthy(v, what)
    if not v then error((what or "value") .. ": expected true, got " .. tostring(v)) end
end

function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function javaList(t)
    return {
        size = function() return #t end,
        get = function(_, i) return t[i + 1] end,
    }
end

---------------------------------------------------------------------------
-- Globals
---------------------------------------------------------------------------

function require() end

table.wipe = table.wipe or function(t)
    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end
    for _, k in ipairs(keys) do t[k] = nil end
end

Events = setmetatable({}, { __index = function(events, name)
    local event = { handlers = {} }
    function event.Add(fn) table.insert(event.handlers, fn) end
    rawset(events, name, event)
    return event
end })

function fire(name, ...)
    for _, fn in ipairs(Events[name].handlers) do fn(...) end
end

SandboxVars = { PZAttachTwoWeaponsOnBack = {} }
Perks = { Strength = "Strength" }

function getNumActivePlayers() return 1 end
function isClient() return false end
function isServer() return false end
function getDebug() return false end
function getText(key) return key end
function getTextOrNull() return nil end
function getTexture() return nil end
function syncItemFields() end

---------------------------------------------------------------------------
-- Attached locations
---------------------------------------------------------------------------

AttachedLocations = { groups = {} }

function AttachedLocations.getGroup(id)
    local group = AttachedLocations.groups[id]
    if group then return group end
    group = { locations = {} }
    function group:getOrCreateLocation(name)
        local location = self.locations[name]
        if not location then
            location = {}
            function location:setAttachmentName(attachment) self.attachmentName = attachment end
            function location:getAttachmentName() return self.attachmentName end
            self.locations[name] = location
        end
        return location
    end
    function group:getLocation(name) return self.locations[name] end
    function group:checkValid(name)
        if not self.locations[name] then error("no such location \"" .. tostring(name) .. "\"") end
    end
    AttachedLocations.groups[id] = group
    return group
end

---------------------------------------------------------------------------
-- Model scripts
---------------------------------------------------------------------------

local function vector(x, y, z)
    local v = { vx = x, vy = y, vz = z }
    function v:x() return self.vx end
    function v:y() return self.vy end
    function v:z() return self.vz end
    function v:set(x2, y2, z2)
        self.vx, self.vy, self.vz = x2, y2, z2
        return self
    end
    return v
end

ModelAttachment = {}

function ModelAttachment.new(id)
    local a = { id = id, offset = vector(0, 0, 0), rotate = vector(0, 0, 0), scale = 1, zOffset = 0 }
    function a:getId() return self.id end
    function a:getBone() return self.bone end
    function a:setBone(bone)
        -- Like the game: ModelAttachment.setBone trims the name.
        if bone == nil then error("Cannot invoke \"String.trim()\" because \"bone\" is null") end
        self.bone = bone
    end
    function a:getOffset() return self.offset end
    function a:getRotate() return self.rotate end
    function a:getScale() return self.scale end
    function a:setScale(scale) self.scale = scale end
    function a:getZOffset() return self.zOffset end
    function a:setZOffset(zOffset) self.zOffset = zOffset end
    return a
end

function newModelScript(fullType)
    local s = { fullType = fullType, attachments = {} }
    function s:getFullType() return self.fullType end
    function s:getAttachmentById(id)
        for _, a in ipairs(self.attachments) do
            if a:getId() == id then return a end
        end
        return nil
    end
    function s:addAttachment(a)
        table.insert(self.attachments, a)
        return a
    end
    function s:getAttachmentCount() return #self.attachments end
    function s:getAttachment(i) return self.attachments[i + 1] end
    return s
end

-- A body mod's own model: a copy of a vanilla body's attachments, moved a bit.
function copyModelScript(fullType, from, shift)
    local s = newModelScript(fullType)
    for _, a in ipairs(from.attachments) do
        if not string.find(a:getId(), "^atwob_") then
            local copy = ModelAttachment.new(a:getId())
            copy:setBone(a:getBone())
            copy:getOffset():set(a:getOffset():x() + (shift or 0), a:getOffset():y(), a:getOffset():z())
            copy:getRotate():set(a:getRotate():x(), a:getRotate():y(), a:getRotate():z())
            table.insert(s.attachments, copy)
        end
    end
    return s
end

MODEL_SCRIPTS = {}

function getScriptManager()
    return { getAllModelScripts = function() return javaList(MODEL_SCRIPTS) end }
end

local NUMBER = "(%-?[%d.]+)"
local VECTOR = NUMBER .. "%s+" .. NUMBER .. "%s+" .. NUMBER

-- The character models with their attachments, read from the game's script file.
function loadCharacterModels()
    return loadModels("media/scripts/generated/models_characters.txt")
end

-- The models in one of the game's model script files, with their attachments.
function loadModels(path)
    local scripts = {}
    local text = readfile(path)
    for name, body in string.gmatch(text, "model%s+([%w_]+)%s*(%b{})") do
        local script = newModelScript("Base." .. name)
        for id, block in string.gmatch(body, "attachment%s+([%w_]+)%s*(%b{})") do
            local a = ModelAttachment.new(id)
            local ox, oy, oz = string.match(block, "offset%s*=%s*" .. VECTOR)
            local rx, ry, rz = string.match(block, "rotate%s*=%s*" .. VECTOR)
            if ox then a:getOffset():set(tonumber(ox), tonumber(oy), tonumber(oz)) end
            if rx then a:getRotate():set(tonumber(rx), tonumber(ry), tonumber(rz)) end
            local bone = string.match(block, "bone%s*=%s*([%w_]+)")
            if bone then a:setBone(bone) end
            table.insert(script.attachments, a)
        end
        table.insert(scripts, script)
    end
    return scripts
end

-- Where a model's own axis points once attached: Rx(rx) Ry(ry) Rz(rz) applied
-- to it, like the game's rotateXYZ (degrees).
function rotateAxis(rx, ry, rz, axis)
    local x, y, z = axis[1], axis[2], axis[3]
    local s, c = math.sin(math.rad(rz)), math.cos(math.rad(rz))
    x, y = x * c - y * s, x * s + y * c
    s, c = math.sin(math.rad(ry)), math.cos(math.rad(ry))
    x, z = x * c + z * s, -x * s + z * c
    s, c = math.sin(math.rad(rx)), math.cos(math.rad(rx))
    y, z = y * c - z * s, y * s + z * c
    return { x, y, z }
end

function dot(a, b)
    return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

function getModelScript(fullType)
    for _, script in ipairs(MODEL_SCRIPTS) do
        if script:getFullType() == fullType then return script end
    end
    return nil
end

---------------------------------------------------------------------------
-- UI and timed actions
---------------------------------------------------------------------------

UIFont = { Small = 0 }
UIManager = { getMoodleUI = function() return nil end }
ISInventoryPage = {}
ISInventoryPaneContextMenu = { transferIfNeeded = function() end }

function getTextManager()
    return {
        getFontHeight = function() return 15 end,
        MeasureStringX = function() return 10 end,
    }
end

function getCore()
    return {
        getScreenWidth = function() return 1920 end,
        getScreenHeight = function() return 1080 end,
    }
end

function getPlayerScreenLeft() return 0 end
function getPlayerScreenTop() return 0 end
function getPlayerScreenWidth() return 1920 end
function getPlayerScreenHeight() return 1080 end

ISPanelJoypad = {}

function ISPanelJoypad:derive(type)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.Type = type
    return o
end

function ISPanelJoypad:new(x, y, width, height)
    local o = { x = x, y = y, width = width, height = height, visible = true }
    setmetatable(o, self)
    self.__index = self
    return o
end

function ISPanelJoypad:setWidth(width) self.width = width end
function ISPanelJoypad:getWidth() return self.width end
function ISPanelJoypad:setX(x) self.x = x end
function ISPanelJoypad:setY(y) self.y = y end
function ISPanelJoypad:isVisible() return self.visible end
function ISPanelJoypad:setVisible(visible) self.visible = visible end
function ISPanelJoypad:getMouseX() return -1 end
function ISPanelJoypad:getMouseY() return -1 end

ISBaseTimedAction = {}

function ISBaseTimedAction:derive(type)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.Type = type
    return o
end

function ISBaseTimedAction.new(self, character)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    return o
end

function ISBaseTimedAction:adjustMaxTime(maxTime) return maxTime end
function ISBaseTimedAction:perform() end

ISTimedActionQueue = { queues = {}, actions = {} }

function ISTimedActionQueue.add(action)
    table.insert(ISTimedActionQueue.actions, action)
end

HOTBARS = {}

function getPlayerHotbar(playerNum)
    return HOTBARS[playerNum]
end

---------------------------------------------------------------------------
-- Characters and items
---------------------------------------------------------------------------

function newItem(attachmentType, options)
    options = options or {}
    local item = {
        attachmentType = attachmentType,
        attachedSlot = -1,
        provides = options.provides,
        replacement = options.replacement,
        name = options.name or attachmentType,
    }
    function item:getAttachmentType() return self.attachmentType end
    function item:getAttachedSlot() return self.attachedSlot end
    function item:setAttachedSlot(index) self.attachedSlot = index end
    function item:getAttachedSlotType() return self.attachedSlotType end
    function item:setAttachedSlotType(slotType) self.attachedSlotType = slotType end
    function item:getAttachedToModel() return self.attachedToModel end
    function item:setAttachedToModel(location) self.attachedToModel = location end
    function item:isBroken() return false end
    function item:getAttachmentsProvided() return self.provides and javaList(self.provides) end
    function item:getAttachmentReplacement() return self.replacement end
    function item:getTexture() return nil end
    function item:getDisplayName() return self.name end
    return item
end

-- A belt and a backpack, as worn items.
function newBelt() return newItem(nil, { provides = { "SmallBeltLeft", "SmallBeltRight" }, name = "Belt" }) end
function newBackpack() return newItem(nil, { replacement = "Bag", name = "Backpack" }) end

local function indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
    return nil
end

function newCharacter()
    local group = AttachedLocations.getGroup("Human")
    local chr = { modData = {}, worn = {}, items = {}, attached = {}, knockedOff = {}, levels = {} }
    function chr:getModData() return self.modData end
    function chr:getPerkLevel(perk) return self.levels[perk] or 0 end
    -- The model the character is drawn with (none unless a test sets one).
    chr.modelResets = 0
    function chr:getHumanVisual()
        local owner = self
        return { getModelScript = function() return owner.modelScript end }
    end
    function chr:resetModelNextFrame() self.modelResets = self.modelResets + 1 end
    function chr:transmitModData() end
    function chr:getPlayerNum() return 0 end
    function chr:getVehicle() return nil end
    function chr:isHandItem() return false end
    function chr:isEquipped() return false end
    function chr:isTimedActionInstant() return false end
    function chr:SetVariable() end
    function chr:getWornItems()
        local worn = self.worn
        return {
            size = function() return #worn end,
            getItemByIndex = function(_, i) return worn[i + 1] end,
        }
    end
    function chr:getInventory()
        local items = self.items
        return {
            getItems = function() return javaList(items) end,
            contains = function(_, item) return indexOf(items, item) ~= nil end,
        }
    end
    function chr:addItem(item)
        table.insert(self.items, item)
        return item
    end
    function chr:wear(item)
        if not indexOf(self.items, item) then table.insert(self.items, item) end
        table.insert(self.worn, item)
    end
    function chr:takeOff(item)
        table.remove(self.worn, indexOf(self.worn, item))
    end
    function chr:setAttachedItem(location, item)
        group:checkValid(location)
        self:removeAttachedItem(item)
        local previous = self.attached[location]
        if previous then table.insert(self.knockedOff, previous) end
        self.attached[location] = item
    end
    function chr:getAttachedItem(location)
        group:checkValid(location)
        return self.attached[location]
    end
    function chr:removeAttachedItem(item)
        local found
        for location, attached in pairs(self.attached) do
            if attached == item then found = location end
        end
        if found then self.attached[found] = nil end
    end
    return chr
end

function newHotbar(chr)
    local hotbar = ISHotbar:new(chr)
    HOTBARS[0] = hotbar
    return hotbar
end

-- The worn items changed: what OnClothingUpdated and the next update() do.
function clothingUpdated(hotbar)
    hotbar.needsRefresh = true
    hotbar:update()
end

-- Attaches an item to a slot without the animation, like after the timed action.
function attach(hotbar, item, slotIndex)
    local slot = hotbar.availableSlot[slotIndex]
    hotbar:attachItem(item, slot.def.attachments[item:getAttachmentType()], slotIndex, slot.def, false)
end

function slotTypes(hotbar)
    local types = {}
    for i, slot in ipairs(hotbar.availableSlot) do types[i] = slot.slotType end
    return table.concat(types, ",")
end

-- Every item on the hotbar sits in its slot and on the model at its location,
-- and no item was knocked off the model by another.
function checkModel(hotbar)
    for index, item in pairs(hotbar.attachedItems) do
        eq(item:getAttachedSlot(), index, item.name .. " slot index")
        eq(hotbar.availableSlot[index].slotType, item:getAttachedSlotType(), item.name .. " slot type")
        eq(hotbar.chr.attached[item:getAttachedToModel()], item, item.name .. " on the model at " .. tostring(item:getAttachedToModel()))
    end
    eq(#hotbar.chr.knockedOff, 0, "items knocked off the model")
end
