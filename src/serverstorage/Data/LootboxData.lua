-- ServerStorage.LootboxData
local LootboxData = {}

LootboxData.Boxes = {
	
	["classic_lb"] = {
		DisplayName   = "Coffre Classique",
		Rarity        = "Common",
		SelectionSize = 5,
		Fishes = {
			{Type = "Goldfish",  Name = "Poisson rouge",  Weight = 50 },
			{Type = "CatFish",   Name = "Poisson Chat",   Weight = 40 },
			{Type = "BlueMerou", Name = "Merou Bleu",     Weight = 20 },
			{Type = "Esturgeon", Name = "Esturgeon",      Weight = 10 },
			{Type = "Tuna",      Name = "Thon",           Weight = 60 },
		},
	},
	
	["rare_lb"] = {
		DisplayName   = "Coffre Rare",
		Rarity        = "Rare",
		SelectionSize = 3,
		Fishes = {
			{Type = "", Name = "Thon Jaune",        Weight = 30 },
			{Type = "", Name = "Requin Fantome",    Weight = 15 },
			{Type = "", Name = "Poisson Licorne",   Weight = 5  },
		},
	},
	
	["epic_lb"] = {
		DisplayName   = "Coffre Epic",
		Rarity        = "Epic",
		SelectionSize = 2,
		Fishes = {
			{Type = "", Name = "Requin Blanc",      Weight = 9  },
			{Type = "", Name = "Dragon des Mers",   Weight = 1  },
		},
	},
	
}

return LootboxData