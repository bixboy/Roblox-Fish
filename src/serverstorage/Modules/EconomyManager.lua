-- ServerStorage/Modules/EconomyManager.lua
local DataStoreService = game:GetService("DataStoreService")
local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")

local INVENTORY_DSTORE = DataStoreService:GetDataStore("MoneyData")
local ORDERED_MONEY_DSTORE = DataStoreService:GetOrderedDataStore("OrderedMoney")

local EconomyManager = {}
local balances = {}  -- balances[player.UserId] = number

-- Charge le solde depuis le DataStore (appele automatiquement)
function EconomyManager:LoadBalance(player)
	
	local key = tostring(player.UserId)
	local ok, stored = pcall(function()
		return INVENTORY_DSTORE:GetAsync(key)
	end)
	
	if ok and type(stored) == "number" then
		balances[player.UserId] = stored
	else
		balances[player.UserId] = 100  -- valeur par defaut
	end
	
	return balances[player.UserId]
end

-- Sauvegarde le solde dans le DataStore
function EconomyManager:SaveBalance(player)
	
	local bal = balances[player.UserId]
	if not bal then return end
	
	pcall(function()
		INVENTORY_DSTORE:SetAsync(tostring(player.UserId), bal)
		ORDERED_MONEY_DSTORE:SetAsync(tostring(player.UserId), bal)
	end)
end

-- Retourne le solde courant
function EconomyManager:GetBalance(player)
	return balances[player.UserId] or 0
end


-- Ajoute de l'argent
function EconomyManager:AddMoney(player, amount)
	
	if type(amount) ~= "number" then 
		return false 
	end
	
	balances[player.UserId] = (balances[player.UserId] or 0) + amount
	
	local stat = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Money")

	if stat then 
		stat.Value = EconomyManager:GetBalance(player) 
	end
	
	return true
end

-- Retire de l�argent si possible
function EconomyManager:RemoveMoney(player, amount)
	
	if type(amount) ~= "number" then 
		return false 
	end
	
	local bal = balances[player.UserId] or 0
	if bal >= amount then
		
		balances[player.UserId] = (balances[player.UserId] or 0) - amount
		
		local stat = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Money")
		if stat then stat.Value = EconomyManager:GetBalance(player) end
		
		return true
	end
		
	return false
end

function EconomyManager:GetTopBalances(count)
	
	local success, pages = pcall(function()
		return ORDERED_MONEY_DSTORE:GetSortedAsync(false, count)
	end)

	if not success or not pages then return {} end

	local topList = {}
	for _, entry in pairs(pages:GetCurrentPage()) do
		table.insert(topList, {
			UserId = tonumber(entry.key),
			Money = entry.value
		})
	end

	return topList
end

-- Hooks auto
Players.PlayerAdded:Connect(function(p)
	EconomyManager:LoadBalance(p)
end)

Players.PlayerRemoving:Connect(function(p)
	EconomyManager:SaveBalance(p)
	balances[p.UserId] = nil
end)

return EconomyManager