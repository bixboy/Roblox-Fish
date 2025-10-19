-- ServerScriptService/InventoryServer.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local InventoryMgr  = require(ServerStorage.Modules:WaitForChild("InventoryManager"))
local itemCatalog   = require(ServerStorage.Data:WaitForChild("ItemCatalog"))
local furnitureData = require(ServerStorage.Data:WaitForChild("FurnitureData"))

local AquariumMgr = require(game.ServerStorage.Modules:WaitForChild("AquariumManager"))
local FishData    = require(game.ServerStorage.Data:WaitForChild("FishData"))

local GetInventory = ReplicatedStorage.Remotes:WaitForChild("GetInventory")

GetInventory.OnServerInvoke = function(player, category)

	local raw = InventoryMgr:GetItems(player)
	local detailed = {}

	for _, entry in ipairs(raw) do
		local item

		-- Furniture
		if category == "Furniture" then
			local f = furnitureData[entry]
			if f then
				item = {
					Id        = entry,
					Name      = f.DisplayName,
					modelName = f.ModelName
				}
				table.insert(detailed, item)
			end
			continue
		end

		-- Item string (catalogue basique)
		if type(entry) == "string" then
			local d = itemCatalog[entry]
			if d then
				item = {
					Id        = entry,
					Name      = d.Name,
					Price     = d.Price,
					Type      = d.Type,
					LootBoxId = d.LootBoxId,
				}
			end

			-- Fish ou Egg (table)
		elseif type(entry) == "table" then

			-- Egg
			if entry.Egg then
				local p = FishData[entry.Type]
				if p then
					item = {
						Id       = entry.Id,
						Type     = "Egg",
						Name     = (p.DisplayName .. " Egg"),
						DataName = entry.Type,
						Hatch    = entry.Hatch,
						Rarity   = p.Rarity,
					}
				end

				-- Fish
			elseif entry.Type then
				local p = FishData[entry.Type]
				if p then
					item = {
						Id       = entry.Id,
						Type     = "Fish",
						Name     = p.DisplayName,
						DataName = entry.Type,
						Price    = p.Price or 0,
						Hunger   = entry.Hunger,
						Growth   = entry.Growth,
						IsMature = entry.IsMature,
						Rarity   = entry.Rarity,
					}
				end
			end
		end

		-- Filtrage par categorie
		if item then
			if category == "Fish" and item.Type == "Fish" then
				table.insert(detailed, item)

			elseif category == "Egg" and item.Type == "Egg" then
				table.insert(detailed, item)

			elseif category == "FishEgg" and (item.Type == "Fish" or item.Type == "Egg") then
				table.insert(detailed, item)

			elseif category == "Other" and (item.Type ~= "Fish" and item.Type ~= "Egg") then
				table.insert(detailed, item)

			elseif category == "All" or category == nil then
				table.insert(detailed, item)
			end
		end
	end

	return detailed
end