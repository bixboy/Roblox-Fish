local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ROTATION_DS    = DataStoreService:GetDataStore("ShopRotation")
local GetMarketItems = ReplicatedStorage.Remotes:WaitForChild("GetMarketItems")


local itemCatalog    = require(game.ServerStorage.Data.ItemCatalog)
local fishList       = require(game.ServerStorage.Data.FishData)

-- Intervalle de rotation en secondes
local REFRESH_INTERVAL = 60 * 60

-- Fonction pour piocher N poissons dans la categorie "Fish"
local function rollFish(num)
	
	local pool = {}
	for id, data in pairs(fishList) do
		
		if data.Market == true then
			table.insert(pool, { Id = id, Data = data })
		end
	end
	
	local result = {}
	for i = 1, num do
		
		if #pool == 0 then break end
		
		local idx = math.random(1, #pool)
		local fishId = pool[idx].Id
		table.insert(result, pool[idx].Id)
		
		table.remove(pool, idx)
	end
	
	warn("[rollFish] Resultat final :", table.concat(result, ", "))

	return result
end


local function getOrCreateRotation()
	
	local success, stored = pcall(function()
		
		return ROTATION_DS:GetAsync("Current")
	end)
	
	if not success then
		
		warn("ShopRotation DS read failed:", stored)
		stored = nil
	end

	local now = os.time()
	
	if not stored
		
		or type(stored.LastRefresh) ~= "number"
		or (now - stored.LastRefresh) >= REFRESH_INTERVAL then
		
		-- On reroll
		local newFishList = rollFish(1)  -- par exemple 5 poissons en vitrine
		local toStore = {
			LastRefresh = now,
			FishList    = newFishList,
		}
		
		local ok, err = pcall(function()
			ROTATION_DS:SetAsync("Current", toStore)
		end)
		
		if not ok then
			warn("Failed to write ShopRotation:", err)
		end
		
		return toStore
	end

	return stored
end


-- Expose via RemoteFunction
GetMarketItems.OnServerInvoke = function(player, filterType)
	
	if filterType == "Fish" then
		
		local rotation = getOrCreateRotation()
		local fishIds  = rotation.FishList

		local items = {}
		for _, fishId in ipairs(fishIds) do
			
			local data = fishList[fishId]
			if data then
				
				table.insert(items, {
					Id     = fishId,
					Name   = data.DisplayName or fishId,
					Price  = data.Price,
					Type   = "Fish",
					Rarity = data.Rarity,
				})
				
			end
			
		end

		table.sort(items, function(a,b) return a.Price < b.Price end)
		
		return items
	end
	
	if filterType == "Object" then
		
		local items = {}
		for id, data in pairs(itemCatalog) do
			
			if data.Type == "Object" or data.Type == "Support" then
				
				if not data.Path then continue end
				
				table.insert(items, {
					Id    = id,
					Name  = data.Name,
					Price = data.Price,
					Type  = data.Type,
					Size  = data.Size,
					Path  = data.Path
				})
				
			end
		end
		
		table.sort(items, function(a,b) return a.Price < b.Price end)
		return items
	end

	local rotation = getOrCreateRotation()
	local fishIds  = rotation.FishList

	local items = {}
	for id, data in pairs(itemCatalog) do
		
		if (not filterType or data.Type == filterType) then
			
			local entry = {
				Id    = id,
				Name  = data.Name,
				Price = data.Price,
				Type  = data.Type,
			}
			
			if data.Type == "Lootbox" then
				entry.LootboxType = data.LootboxType
			end
			
			table.insert(items, entry)
		end
	end

	table.sort(items, function(a,b) return a.Price < b.Price end)
	return items
end