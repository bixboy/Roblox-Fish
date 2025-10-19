-- ServerStorage.Modules.FishData

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarity = require(script.Parent.Parent.Modules:WaitForChild("FishRarity"))


local FishData = {
	
	Goldfish = {
		Name        = "Goldfish",
		DisplayName = "Poisson rouge",
		ModelName   = "GoldfishModel",
		MaxHunger   = 100,
		HungerDecay = 3,
		GrowthRate  = 5,
		MaxGrowth   = 100,
		Price       = 10,
		Rarity      = Rarity.Common,
		Market      = true,
		Egg = {
			HatchTime    = 15,
			EggModelName = "EggModel"
		}
	},
	
	CatFish = {
		Name        = "CatFish",
		DisplayName = "Poisson Chat",
		ModelName   = "GoldfishModel",
		MaxHunger   = 100,
		HungerDecay = 3,
		GrowthRate  = 5,
		MaxGrowth   = 100,
		Price       = 10,
		Rarity      = Rarity.Rare,
		Market      = true,
		Egg = {
			HatchTime    = 15,
			EggModelName = "EggModel"
		}
	},
	
	BlueMerou = {
		Name        = "BlueMerou",
		DisplayName = "Merou Bleu",
		ModelName   = "GoldfishModel",
		MaxHunger   = 100,
		HungerDecay = 3,
		GrowthRate  = 5,
		MaxGrowth   = 100,
		Price       = 10,
		Rarity      = Rarity.Common,
		Market      = true,
		Egg = {
			HatchTime    = 15,
			EggModelName = "EggModel"
		}
	},
	
	Esturgeon = {
		Name        = "Esturgeon",
		DisplayName = "Esturgeon",
		ModelName   = "GoldfishModel",
		MaxHunger   = 100,
		HungerDecay = 1,
		GrowthRate  = 5,
		MaxGrowth   = 100,
		Price       = 10,
		Rarity      = Rarity.Common,
		Market      = true,
		Egg = {
			HatchTime    = 15,
			EggModelName = "EggModel"
		}
	},

	Tuna = {
		Name        = "Tuna",
		DisplayName = "Thon",
		ModelName   = "GoldfishModel",
		MaxHunger   = 120,
		HungerDecay = 3,
		GrowthRate  = 2,
		MaxGrowth   = 150,
		Price       = 20,
		Rarity      = Rarity.Uncommon,
		Market      = true,
		Egg = {
			HatchTime    = 15,
			EggModelName = "EggModel"
		}
	},

	Shark = {
		Name        = "Shark",
		DisplayName = "Requin",
		ModelName   = "GoldfishModel",
		MaxHunger   = 200,
		HungerDecay = 5,
		GrowthRate  = 1,
		MaxGrowth   = 200,
		Price       = 50,
		Rarity      = Rarity.Rare,
		Market      = false,
		Egg = {
			HatchTime    = 15,
			EggModelName = "EggModel"
		}
	}
	
}

for fishType, data in pairs(FishData) do
	
	local modelName = data.ModelName or fishType
	
	local fishModelsFolder = ReplicatedStorage.Assets:FindFirstChild("FishModels")
	
	if not fishModelsFolder then
		
		warn("FishModels folder est introuvable dans ReplicatedStorage !")
		
	elseif not fishModelsFolder:FindFirstChild(modelName) then
		
		warn("Modele manquant pour", fishType, "(attendu :", modelName .. ")")
		
	end
	
end

return FishData