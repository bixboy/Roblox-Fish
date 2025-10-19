-- FishCatalogServer.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local GetFishCatalog = Instance.new("RemoteFunction")
GetFishCatalog.Name   = "GetFishCatalog"
GetFishCatalog.Parent = ReplicatedStorage.Remotes

local FishData = require(ServerStorage.Data:WaitForChild("FishData"))

GetFishCatalog.OnServerInvoke = function(player)
	
    local catalog = {}
    for fishType, info in pairs(FishData) do
        table.insert(catalog, {
            Id         = fishType,
            DisplayName= info.DisplayName,
            ModelName  = info.ModelName,
            MaxHunger  = info.MaxHunger,
            HungerDecay= info.HungerDecay,
            GrowthRate = info.GrowthRate,
            MaxGrowth  = info.MaxGrowth,
            Price      = info.Price,
            Rarity     = info.Rarity,
        })
	end
	
    return catalog
end