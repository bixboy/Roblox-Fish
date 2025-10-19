-- ServerScriptService/EconomyController.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local HttpService       = game:GetService("HttpService")
local Players           = game:GetService("Players")


local EconomyManager    = require(ServerStorage.Modules:WaitForChild("EconomyManager"))
local InventoryManager  = require(ServerStorage.Modules:WaitForChild("InventoryManager"))
local itemCatalog       = require(ServerStorage.Data:WaitForChild("ItemCatalog"))
local fishList          = require(ServerStorage.Data:WaitForChild("FishData"))

-- Remotes
local BuyItemRemote     = ReplicatedStorage.Remotes:WaitForChild("BuyItem")
local SellItemRemote    = ReplicatedStorage.Remotes:WaitForChild("SellItem")


-- Cree leaderstats
Players.PlayerAdded:Connect(function(player)
	
	local startingBalance = EconomyManager:LoadBalance(player)
	
	local stats  = Instance.new("Folder")
	stats.Name   = "leaderstats"
	stats.Parent = player

	local money  = Instance.new("IntValue")
	money.Name   = "Money"
	money.Value  = startingBalance
	money.Parent = stats
	
end)


-- Remote: achat
BuyItemRemote.OnServerInvoke = function(player, payload)
	
	local dataEntry, addFn, logName
	if type(payload) == "string" then
		
        dataEntry = itemCatalog[payload]
		if dataEntry then
			
			addFn = function() 
				return InventoryManager:AddItem(player, payload) end
			
            logName = dataEntry.Name
		else
			
            local fishData = fishList[payload]
			if fishData then
				
                dataEntry = fishData
				addFn = function()
					local newId = HttpService:GenerateGUID(false)
					return InventoryManager:AddFish(player, 
					{
						Id       = newId,
                        Type     = payload,
                        Hunger   = 100,
                        Growth   = 0,
                        IsMature = false,
                        Rarity   = fishData.Rarity,
                    })
				end
                logName = "Poisson " .. payload
            end
        end
    end

	if not dataEntry then
		
        warn("BuyItem: item ou poisson introuvable pour", payload)
		return nil
    end

    local price = dataEntry.Price or 0
	if not EconomyManager:RemoveMoney(player, price) then
		
        warn(player.Name, "pas assez d�argent pour", payload)
		return nil, "Money"
    end

    player.leaderstats.Money.Value = EconomyManager:GetBalance(player)

    local ok, err = addFn()
	if not ok then
		
		warn("Inventaire:", err)
		EconomyManager:AddMoney(player, price)
		
        return nil
    end

	warn(("%s a achet� %s pour %d"):format(player.Name, logName, price))
	return itemCatalog[payload]
end



-- Remote: vente
SellItemRemote.OnServerEvent:Connect(function(player, payload)
	
	if typeof(payload) == "table" and #payload >= 1 then
		
		for _, p in ipairs(payload) do
			processSingleSell(player, p) end
	else
		processSingleSell(player, payload)
	end
end)


function processSingleSell(player, payload)
	local key, dataEntry, removeFn

	if type(payload) == "string" then
		
		dataEntry = itemCatalog[payload]
		removeFn = function() 
			return InventoryManager:RemoveItem(player, payload) end
		
		key = payload
		
	elseif type(payload) == "table" and payload.Id then
		
		local inv  = InventoryManager:GetItems(player, "Fish")
		local fish = nil
		
		for _, entry in ipairs(inv) do
			
			if type(entry) == "table" and entry.Id == payload.Id then
				fish = entry.Type
			end
		end
		
		dataEntry = fishList[fish]
		removeFn = function() 
			return InventoryManager:RemoveFish(player, payload.Id) 
		end
		
		key = fish
		
	end

	if not dataEntry or not removeFn then
		
		warn("Vente �chou�e (payload inconnu)", payload)
		return
	end

	local removed, err = removeFn()
	if not removed then
		
		warn("�chec suppression :", key, err)
		return
	end

	local sellPrice = math.floor((dataEntry.Price or 0) * 0.5)
	
	EconomyManager:AddMoney(player, sellPrice)
	player.leaderstats.Money.Value = EconomyManager:GetBalance(player)

	print(("%s a vendu %s pour %d"):format(player.Name,
		dataEntry.Name or key, sellPrice))
end