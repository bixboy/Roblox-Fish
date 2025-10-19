-- ServerStorage/Modules/SupportManager.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local ProximityPromptManager = require(ServerStorage.Modules:WaitForChild("ProximityPromptManager"))
local PlotManager            = require(ServerStorage.Modules:WaitForChild("PlotManager"))
local AquariumManager        = require(ServerStorage.Modules:WaitForChild("AquariumManager"))
local AquariumData      = require(ServerStorage.Data:WaitForChild("AquariumData"))

local OpenAquariumUI       = ReplicatedStorage.Remotes.Aquarium:WaitForChild("OpenAquariumSelection")
local OpenFishMgmtUI       = ReplicatedStorage.Remotes.Aquarium:WaitForChild("OpenFishSelectionUI")
local PlaceAquariumRequest = ReplicatedStorage.Remotes.Aquarium:WaitForChild("PlaceAquariumRequest")


local SupportManager = {}
local supports = {}

function SupportManager:InitSupport(supportModel)
	
	local promptPart = supportModel:WaitForChild("PromptPart")
	local prompt     = promptPart:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end

	local anchor = supportModel.AttachPart:WaitForChild("AquariumAttach")
	local meta   = require(supportModel:WaitForChild("ModuleData"))

	supports[supportModel] = {
		
		Anchor   = anchor,
		Meta     = meta,
		Aquarium = nil,
	}

	prompt.Triggered:Connect(function(player)
		
		local currentAquarium = self:GetCurrentAquarium(supportModel)
		ProximityPromptManager:SetEnabledPrompt(player, false)
		
		if currentAquarium then
			
			OpenFishMgmtUI:FireClient(player, currentAquarium)
		else
			
			OpenAquariumUI:FireClient(player, supportModel)
		end
	end)

	PlaceAquariumRequest.OnServerEvent:Connect(function(player, targetSupport, aquariumModel)
		if targetSupport == supportModel then
			
			self:PlaceAquarium(player, supportModel, aquariumModel)
		end
	end)
end

function SupportManager:PlaceAquarium(player, supportModel, aquariumModel)
	
	assert(supportModel and aquariumModel, "SupportModel ou AquariumModel invalide")
	
	local data = supports[supportModel]
	if not data or data.Aquarium then 
		return 
	end
	
	local anchor = data.Anchor
	local meta = data.Meta

	local aquariumMeta = AquariumData.Data[aquariumModel.Name]

	local sizeOrder = { Small = 1, Medium = 2, Large = 3 }
	if sizeOrder[aquariumMeta.Size] > sizeOrder[meta.Size] then
		
		warn("Aquarium trop grand pour ce support")
		return
	end

	local placedAquarium = AquariumManager.PlaceAquariumOnSupport(supportModel, aquariumModel, player.UserId)
	if not placedAquarium then
		
		warn("echec de placement de l'aquarium")
		return
	end

	placedAquarium:SetAttribute("Owner", player.UserId)
	placedAquarium:SetAttribute("TemplatePath", aquariumModel.Name)
	placedAquarium.Parent = supportModel

	local anchorWorldCFrame = anchor.Parent.CFrame * anchor.CFrame
	local offsetY = placedAquarium.PrimaryPart.Size.Y / 2
	local position = anchorWorldCFrame.Position + Vector3.new(0, offsetY, 0)

	placedAquarium:SetPrimaryPartCFrame(CFrame.new(position))

	PlotManager:AddAquariumToSupport(player, supportModel, placedAquarium)
	data.Aquarium = placedAquarium

	return placedAquarium
end

function SupportManager:ReloadAquarium(player, supportModel, aquariumName, fishList, eggList, furnitures)
	
	local template = AquariumData.Templates[aquariumName]
	if not template then 
		
		warn("template is not valid")
		return
	end

	local aquarium = self:PlaceAquarium(player, supportModel, template)
	if not aquarium then 
		
		warn("Aquarium Is not Valid")
		return
	end

	local manager = AquariumManager.Get(aquarium)
	if not manager or not manager._instance then 
		
		warn("Manager or instance is not valid")
		return
	end

	for _, fish in ipairs(fishList) do
		manager._instance:PlaceFish(fish)
	end
	
	for _, egg in ipairs(eggList) do
		warn(egg)
		manager._instance:PlaceEgg(egg)
	end
	
	for _, furni in ipairs(furnitures) do
		manager._instance:PlaceFurniture(furni.Name, furni.Slot)
	end

	return aquarium
end



function SupportManager:RemoveAquarium(supportModel)
	
	local data = supports[supportModel]
	if not data or not data.Aquarium then return end

	data.Aquarium:Destroy()
	data.Aquarium = nil
end

function SupportManager:GetCurrentAquarium(supportModel)
	
	local data = supports[supportModel]
	return data and data.Aquarium or nil
end

return SupportManager