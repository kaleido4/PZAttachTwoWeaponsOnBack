--[[
    Test only: with any backpack on, the first back slot puts rifles and
    shotguns on this mod's spot, like a backpack mod rewriting the vanilla bag's
    spots (Noir's Rifle Slings does that for its own items).
--]]

require "Hotbar/ISHotbarAttachDefinition"

for _, def in ipairs(ISHotbarAttachDefinition.replacements) do
    if def.type == "Bag" then
        def.replacement.Rifle = "Test Rifle On Bag"
    end
end
