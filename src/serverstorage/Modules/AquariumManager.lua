-- ServerStorage/Modules/AquariumManager.lua
local HttpService    = game:GetService("HttpService")
local RunService     = game:GetService("RunService")
local Players        = game:GetService("Players")

local AquariumData     = require(script.Parent.Parent.Data:WaitForChild("AquariumData"))
local AquariumInstance = require(script.Parent:WaitForChild("AquariumInstance"))

local AquariumManager = {}
AquariumManager.__index = AquariumManager

-- etats actifs
local activeManagers  = {}
local activeInstances = {}
local aquariumData    = {} -- mapping Model -> FishMap

-- Utils
local function getFishMap(model)
	return aquariumData[model] or {}
end

function AquariumManager:GetFishListPublic()
	return self._instance and self._instance:GetFishListPublic() or {}
end

function AquariumManager:GetFishListIsEmpty()
	return next(getFishMap(self.Model)) == nil
end

function AquariumManager:GetFishCount()
	
	if not self._instance then return 0 end
	local count = 0
	
	for _ in pairs(self._instance._fishData) do
		count += 1
	end
	
	return count
end

function AquariumManager:GetEggCount()
	
	if not self._instance then return 0 end
	local count = 0
	
	for _ in pairs(self._instance._eggsData) do
		count += 1
	end
	
	return count
end

function AquariumManager:GetTotalCount()
	return self:GetFishCount() + self:GetEggCount()
end

-- ============================================================
-- Instanciation
-- ============================================================
function AquariumManager.new(model, ownerUserId)
	local self = setmetatable({
		Model       = model,
		OwnerUserId = ownerUserId,
	}, AquariumManager)

	activeManagers[model] = self
	aquariumData[model]   = {}

	return self
end

function AquariumManager:Destroy()
	activeManagers[self.Model]  = nil
	activeInstances[self.Model] = nil
	aquariumData[self.Model]    = nil
end

function AquariumManager.Get(model)
	return activeManagers[model]
end

-- ============================================================
-- Placement aquarium
-- ============================================================
function AquariumManager.PlaceAquariumOnSupport(supportModel, aquariumTemplate, ownerUserId)
	local clone = aquariumTemplate:Clone()
	clone.Parent = supportModel

	clone:SetAttribute("AquariumId", HttpService:GenerateGUID(false))
	clone:SetAttribute("Owner", ownerUserId)

	local data = AquariumData.Data[clone.Name]
	if data then
		clone:SetAttribute("MaxFish", data.MaxFish)
	end

	-- Cr�e instance + manager
	local instance = AquariumInstance.new(clone, data, ownerUserId)
	activeInstances[clone] = instance

	local manager = AquariumManager.new(clone, ownerUserId)
	manager._instance = instance
	instance.FishMap  = aquariumData[clone]

	return clone
end

-- ============================================================
-- Proxies vers l'instance
-- ============================================================
function AquariumManager:PlaceFish(fishInfo)       return self._instance and self._instance:PlaceFish(fishInfo) end
function AquariumManager:FeedFishById(fishId)      return self._instance and self._instance:FeedFishById(fishId) end
function AquariumManager:PlaceEgg(eggInfo)         return self._instance and self._instance:PlaceEgg(eggInfo) end
function AquariumManager:PlaceFurniture(name, idx) return self._instance and self._instance:PlaceFurniture(name, idx) end
function AquariumManager:RemoveFurniture(idx)      return self._instance and self._instance:RemoveFurniture(idx) end

function AquariumManager:RemoveFishById(player, fishId)
	if self._instance and self._instance:IsOwner(player) then
		return self._instance:RemoveFishById(fishId)
	end
	return nil, "You are not the owner"
end

function AquariumManager:RemoveEgg(player, eggId)
	if self._instance and self._instance:IsOwner(player) then
		return self._instance:RemoveEggById(eggId)
	end
	return nil, "You are not the owner"
end

-- ============================================================
-- Tick loop
-- ============================================================
function AquariumManager:Tick(dt)
	if self._instance then
		self._instance:Tick(dt)
	end
end

RunService.Heartbeat:Connect(function(dt)
        for model, manager in pairs(activeManagers) do
                if not model:GetAttribute("AquariumId") then
                        continue
                end

                local shouldTick = false
                local instance = activeInstances[model] or manager._instance

                if instance then
                        if next(instance._fishData) or next(instance._eggsData) then
                                shouldTick = true
                        end
                end

                if not shouldTick and next(getFishMap(model)) then
                        shouldTick = true
                end

                if shouldTick then
                        manager:Tick(dt)
                end
        end
end)

-- ============================================================
-- Cleanup joueur
-- ============================================================
Players.PlayerRemoving:Connect(function(player)
	for _, manager in pairs(activeManagers) do
		if manager.OwnerUserId == player.UserId then
			manager:Destroy()
		end
	end
end)

return AquariumManager