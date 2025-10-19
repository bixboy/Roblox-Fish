-- ServerStorage/Modules/ShopData
local RobuxShopData = {
	
	LootBoxes = {
		{ Key = "BasicBox",    ProductId = 3336505706, RewardType = "LootBox",   RewardArgs = { Type = "classic_lb" } },
		{ Key = "EpicBox",     ProductId = 3336521160, RewardType = "LootBox",   RewardArgs = { Type = "rare_lb" } },
		-- etc
	},
	
	Moneys = {
		{ Key = "SmallPack",   ProductId = 3345239684, RewardType = "Currency",  RewardArgs = { Amount = 100 }  },
		{ Key = "LargePack",   ProductId = 3345240112, RewardType = "Currency",  RewardArgs = { Amount = 500 }  },
		-- etc
	},
	
}

return RobuxShopData