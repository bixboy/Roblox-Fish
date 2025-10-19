-- ServerStorage/Modules/AquariumInstance.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")

local FishData      = require(ServerStorage.Data:WaitForChild("FishData"))
local FurnitureData = require(ServerStorage.Data:WaitForChild("FurnitureData"))
local PlotManager   = require(ServerStorage.Modules:WaitForChild("PlotManager"))
local InventoryMgr  = require(ServerStorage.Modules:WaitForChild("InventoryManager"))

local FishStatsUpdated = ReplicatedStorage.Remotes:WaitForChild("FishStatsUpdated")

local AquariumInstance = {}
AquariumInstance.__index = AquariumInstance

local DEF_MAX_FISH       = 1
local DEF_MAX_FURNITURES = 1

-- ============================================================
-- Constructeur
-- ============================================================
function AquariumInstance.new(model, data, ownerUserId)
	local self = setmetatable({
		Model           = model,
		OwnerUserId     = ownerUserId,
		Visuals         = model:WaitForChild("Visuals"),
		SpawnArea       = model:WaitForChild("SpawnArea"),

		_fishData       = {},
		_eggsData       = {},
		FishVisuals     = {},
		MaxFishCapacity = data.MaxFish or DEF_MAX_FISH,

		_furnitureData  = {},
		FurnitureSlots  = {},
		MaxFurnitures   = data.MaxFurnitures or DEF_MAX_FURNITURES
	}, AquariumInstance)

	for _, slot in ipairs(model:FindFirstChild("Slots") and model.Slots:GetChildren() or {}) do
		if slot:IsA("BasePart") or slot:IsA("Attachment") then
			table.insert(self.FurnitureSlots, slot)
		end
	end

	model:SetAttribute("MaxFurnitures", self.MaxFurnitures)
	return self
end

-- ============================================================
-- Utils
-- ============================================================
local function getRandomPosition(area)
	return area.Position + Vector3.new(
		(math.random() - 0.5) * area.Size.X,
		(math.random() - 0.5) * area.Size.Y,
		(math.random() - 0.5) * area.Size.Z
	)
end

local function round(num, decimals)
	local mult = 10 ^ (decimals or 0)
	return math.floor(num * mult + 0.5) / mult
end

local function getOwnerPlayer(ownerUserId)
	return Players:GetPlayerByUserId(ownerUserId)
end

function AquariumInstance:IsOwner(player)
	return player and player.UserId == self.OwnerUserId
end

-- ============================================================
-- Gestion visuels
-- ============================================================
local function spawnFishVisual(instance, fishId, fishType)
	local data = FishData[fishType]
	if not data then return end

	local template = ReplicatedStorage.Assets.FishModels:FindFirstChild(data.ModelName or fishType)
	if not template then
		warn(("? Aucun mod�le trouv� pour le poisson [%s]"):format(fishType))
		return
	end

	local clone = template:Clone()
	clone.Name  = "Fish_" .. tostring(fishId)
	clone.Parent = instance.Visuals

	CollectionService:AddTag(clone, "Fish")
	clone:SetAttribute("FishId", fishId)

	local spawnPos = getRandomPosition(instance.SpawnArea)
	if clone:IsA("Model") then
		if not clone.PrimaryPart then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart")
			if not clone.PrimaryPart then
				warn("? Mod�le de poisson sans PrimaryPart :", clone.Name)
				return
			end
		end
		clone:SetPrimaryPartCFrame(CFrame.new(spawnPos))
	else
		clone.Position = spawnPos
	end

	instance.FishVisuals[fishId] = clone
end

-- ============================================================
-- Poissons
-- ============================================================
function AquariumInstance:PlaceFish(fishInfo)
	
	if #self._fishData >= self.MaxFishCapacity then
		return nil, "Max fish capacity reached"
	end

	local data = FishData[fishInfo.Type]
	if not data then return end

	self._fishData[fishInfo.Id] = {
		Id       = fishInfo.Id,
		Type     = fishInfo.Type,
		Hunger   = fishInfo.Hunger or data.MaxHunger,
		Growth   = fishInfo.Growth or 0,
		IsMature = fishInfo.IsMature or false,
		Rarity   = fishInfo.Rarity or data.Rarity,
	}

	if self.FishMap then
		self.FishMap[fishInfo.Id] = self._fishData[fishInfo.Id]
	end

	spawnFishVisual(self, fishInfo.Id, fishInfo.Type)
	PlotManager:UpdateFishStats(self.OwnerUserId, self.Model.Parent, self._fishData)

	return fishInfo.Id
end

function AquariumInstance:RemoveFishById(fishId)
	local info = self._fishData[fishId]
	if not info then return end

	self._fishData[fishId] = nil
	if self.FishMap then self.FishMap[fishId] = nil end

	local visual = self.FishVisuals[fishId]
	if visual then
		visual:Destroy()
		self.FishVisuals[fishId] = nil
	end

	return info
end

function AquariumInstance:FeedFishById(fishId)
	local info = self._fishData[fishId]
	if not info then return end

	info.Hunger = math.min(info.Hunger + 20, FishData[info.Type].MaxHunger)

	local player = getOwnerPlayer(self.OwnerUserId)
	if player then
		FishStatsUpdated:FireClient(player, self.Model, info)
	end

	PlotManager:UpdateFishStats(self.OwnerUserId, self.Model.Parent, self._fishData)
end

-- ============================================================
-- oeufs
-- ============================================================
function AquariumInstance:PlaceEgg(eggInfo)
	
	if #self._fishData >= self.MaxFishCapacity then
		warn("Max fish capacity reached")
		return nil, "Max fish capacity reached"
	end

	local data = FishData[eggInfo.Type]
	if not data or not data.Egg then
		warn("Invalid egg type")
		return nil, "Invalid egg type" 
	end

	local spawnPos    = getRandomPosition(self.SpawnArea)
	local eggTemplate = ReplicatedStorage.Assets.EggModels:FindFirstChild(data.Egg.EggModelName)

	local egg = eggTemplate:Clone()
	egg.Name = eggInfo.Id
	egg:PivotTo(CFrame.new(spawnPos))
	egg.Parent = self.Visuals

	self._eggsData[eggInfo.Id] = 
	{
		Id           = eggInfo.Id,
		Type         = eggInfo.Type,
		MaxHatchTime = data.Egg.HatchTime,
		Hatch        = eggInfo.Hatch or 0,
		Instance     = egg
	}
	
	PlotManager:UpdateEggStats(self.OwnerUserId, self.Model.Parent, self._eggsData)

	return eggInfo.Id
end

function AquariumInstance:RemoveEggById(eggId)
	
	local egg = self._eggsData[eggId]
	if not egg then
		return nil, "Egg not found" 
	end
	
	local eggInfo = egg

	if egg.Instance then 
		egg.Instance:Destroy()
	end
	self._eggsData[eggId] = nil
	
	PlotManager:RemoveEggFromSupport(self.OwnerUserId, self.Model.Parent, eggId)

	return eggInfo, true
end

-- ============================================================
-- Tick principal
-- ============================================================
function AquariumInstance:Tick(dt)
	
	-- Gestion des oeufs
	for eggId, egg in pairs(self._eggsData) do
		
		egg.Hatch += dt  
		if egg.Hatch >= egg.MaxHatchTime then

			local stats = FishData[egg.Type]
			if stats then
				self:PlaceFish({
					Id       = "Fish_" .. tostring(self._nextFishId + 1),
					Type     = egg.Type,
					Hunger   = stats.MaxHunger,
					Growth   = 0,
					IsMature = false,
					Rarity   = stats.Rarity
				})
			end

			if egg.Instance then 
				egg.Instance:Destroy() 
			end
			
			self._eggsData[eggId] = nil
		end
	end

	-- Gestion des poissons
	for fishId, fish in pairs(self._fishData) do
		
		local stats = FishData[fish.Type]
		if not stats then continue end

		fish.Hunger = round(math.max(0, fish.Hunger - stats.HungerDecay * dt), 1)

		if not fish.IsMature then
			
			local hungerRatio = fish.Hunger / stats.MaxHunger
			fish.Growth = round(math.min(stats.MaxGrowth, fish.Growth + stats.GrowthRate * dt * hungerRatio), 1)
			
			if fish.Growth >= stats.MaxGrowth then
				fish.IsMature = true end
		end

		local visual = self.FishVisuals[fishId]
		if visual and visual.PrimaryPart then
			
			local growthRatio = fish.Growth / stats.MaxGrowth
			local scale = 0.5 + (1.0 * growthRatio)
			
			visual:SetPrimaryPartCFrame(visual.PrimaryPart.CFrame)
			visual:ScaleTo(scale)
		end

		local player = getOwnerPlayer(self.OwnerUserId)
		if player then
			FishStatsUpdated:FireClient(player, self.Model, fish)
		end
	end

	PlotManager:UpdateFishStats(self.OwnerUserId, self.Model.Parent, self._fishData)
end

-- ============================================================
-- Public
-- ============================================================
function AquariumInstance:GetFishListPublic()
	
	local out = {}
	for _, info in pairs(self._fishData) do
		table.insert(out, { Id = info.Id, Type = info.Type, Rarity = info.Rarity })
	end
	
	return out
end

return AquariumInstance