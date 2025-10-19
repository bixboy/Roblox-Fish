-- ServerStorage.Modules.FurnitureData

local ReplicatedStorage = game:GetService("ReplicatedStorage")


local FurnitureData = {
	
	Chest = {
		Name        = "Chest",
		DisplayName = "Beau Coffre",
		ModelName   = "ChestModel",
	},
	
	Bridge = {
		Name        = "Bridge",
		DisplayName = "Beau Pont",
		ModelName   = "BridgeModel",
	}
	
}

for furniture, data in pairs(FurnitureData) do
	
	local modelName = data.ModelName
	
	local furnitureModelsFolder = ReplicatedStorage.Assets:FindFirstChild("FishModels")
	
	if not furnitureModelsFolder then
		
		warn("Furniture Models folder est introuvable dans ReplicatedStorage !")
		
	elseif not furnitureModelsFolder:FindFirstChild(modelName) then
		
		warn("Module manquant pour", furniture, "(attendu :", modelName .. ")")
		
	end
	
end

return FurnitureData