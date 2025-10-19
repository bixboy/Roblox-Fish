-- ServerScriptService/AquariumController.lua

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AquariumMgr     = require(game.ServerStorage.Modules.AquariumManager)
local InventoryMgr    = require(game.ServerStorage.Modules.InventoryManager)
local PlotManager     = require(game.ServerStorage.Modules.PlotManager)

local AquariumData    = require(game.ServerStorage.Data.AquariumData)
local FishData        = require(game.ServerStorage.Data.FishData)

local Remotes         = ReplicatedStorage.Remotes.Aquarium
local AquariumAction  = Remotes:WaitForChild("AquariumAction")

local GetAquariumList     = Remotes:WaitForChild("GetAquariumList")
local GetAquariumFishList = Remotes:WaitForChild("GetAquariumFishList")

-- Helpers
local function getManager(player, model)
	
    local mgr = AquariumMgr.Get(model)
	if not mgr then

        warn("Invalid aquarium model:", model)
        return nil
	end
	
	if mgr.OwnerUserId ~= player.UserId then
		
        warn("Player", player.Name, "does not own this aquarium")
        return nil
	end
	
    return mgr
end

-- Handler
AquariumAction.OnServerInvoke = function(player, action, aquariumModel, data)
	
	local mgr = getManager(player, aquariumModel)
	if not mgr then 
		return false 
	end

	if action == "PlaceFish" then -- Place Fish
		
		local fishId = data.FishId
		if type(fishId) ~= "string" then
			warn("PlaceFish: FishId must be string", fishId)
			return false
		end

		local FishNumber = mgr:GetTotalCount()
		local MaxFish    = AquariumData.Data[aquariumModel.Name].MaxFish
		
		if FishNumber >= MaxFish then
			warn(("Max Fish Reached: %d/%d"):format(FishNumber, MaxFish))
			return false
		end

		local ok, fishData = InventoryMgr:RemoveFish(player, fishId)
		if not ok then
			warn("Cannot remove fish from inventory")
			return false
		end

		mgr:PlaceFish({
			Id       = fishData.Id,
			Type     = fishData.Type,
			Hunger   = fishData.Hunger,
			Growth   = fishData.Growth,
			IsMature = fishData.IsMature,
			Rarity   = fishData.Rarity,
		})

	elseif action == "TakeFish" then -- Take Fish
		
		local fishId = data.FishId
		
		local info, err = mgr:RemoveFishById(player, fishId)
		if not info then
			warn("TakeFish failed:", err)
			return false
		end

		local support = aquariumModel.Parent
		PlotManager:RemoveFishFromSupport(player.UserId, support, fishId)

		local ok, invErr = InventoryMgr:AddFish(player, info)
		if not ok then
			warn("Cannot add fish back to inventory:", invErr) 
		end
		
		return true

	elseif action == "FeedFish" then -- Feed Fish
		
		local fishId = data.FishId
		mgr:FeedFishById(fishId)
		return true
		
	elseif action == "PlaceEgg" then -- Place Egg
		
		local eggId = data.EggId
		if type(eggId) ~= "string" then
			warn("PlaceFish: EggId must be string", eggId)
			return false
		end

		local FishNumber = mgr:GetTotalCount()
		local MaxFish    = AquariumData.Data[aquariumModel.Name].MaxFish

		if FishNumber >= MaxFish then
			warn(("Max Fish Reached: %d/%d"):format(FishNumber, MaxFish))
			return false
		end

		local ok, eggData = InventoryMgr:RemoveEgg(player, eggId)
		if not ok then
			warn("Cannot remove Egg from inventory")
			return false
		end
		
		mgr:PlaceEgg(eggData)
		return true
		
	elseif action == "TakeEgg" then -- Take Egg
		
		local eggId = data.EggId

		local info, err = mgr:RemoveEgg(player, eggId)
		if not info then
			warn("Take Egg failed:", err)
			return false
		end

		local ok, invErr = InventoryMgr:AddEgg(player, info)
		if not ok then
			warn("Cannot add egg back to inventory:", invErr) 
		end

		return true

	elseif action == "PlaceFurniture" then -- Place Furnitures
		
		local furnitureId = data.FurnitureId
		if not furnitureId then
			warn("PlaceFurniture: missing FurnitureId")
			return false
		end
		
		if mgr:PlaceFurniture(furnitureId, data.slotIndex) then
			
			if not InventoryMgr:RemoveItem(player, furnitureId) then
				
				mgr:RemoveFurniture(data.slotIndex)
				InventoryMgr:AddItemByName(player, data.FurnitureId, "Furniture")
			end
			
			return true
		end
		
	elseif action == "RemoveFurniture" then -- Remove Furniture
		
		return mgr:RemoveFurniture(data.slotIndex)
	end
end

-- ==== Infos utilitaires ====
GetAquariumList.OnServerInvoke = function(player)
	
	local result = {}
	for key, aquariumData in pairs(AquariumData.Data) do
		table.insert(result, {
			Text    = ("%s (%s)"):format(aquariumData.FriendlyName, tostring(aquariumData.Size)),
			Model   = aquariumData.Template,
			MaxFish = aquariumData.MaxFish,
		})
	end
	
	return result
end

GetAquariumFishList.OnServerInvoke = function(player, aquariumModel)
	
	local manager = getManager(player, aquariumModel)
	if not manager then
		warn("Access denied for player", player.Name)
		return {}
	end

	local instance = manager._instance
	if not instance then return {} end

	local result = {}

	-- Poissons
	for fishId, info in pairs(instance._fishData) do
		table.insert(result, {
			Id       = info.Id,
			Type     = info.Type,
			Name     = FishData[info.Type].DisplayName,
			Hunger   = info.Hunger,
			Growth   = info.Growth,
			IsMature = info.IsMature,
			Rarity   = info.Rarity,
		})
	end

	-- oeufs
	for eggId, egg in pairs(instance._eggsData) do
		local fd = FishData[egg.Type]
		if fd then
			table.insert(result, {
				Id       = egg.Id,
				Type     = "Egg",
				Name     = fd.DisplayName,
				Egg      = true,
				Hatch    = egg.Elapsed,
				MaxHatch = egg.HatchTime,
				Rarity   = fd.Rarity,
			})
		end
	end

	return result
end