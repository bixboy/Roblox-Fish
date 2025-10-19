local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local HttpService       = game:GetService("HttpService")

local LootboxOpen = ReplicatedStorage.Remotes:WaitForChild("LootboxOpenRequest")

local InventoryManager  = require(ServerStorage.Modules:WaitForChild("InventoryManager"))
local LootboxData       = require(ServerStorage.Data:WaitForChild("LootboxData"))
local fishData          = require(ServerStorage.Data:WaitForChild("FishData"))


-- Fonction pour effectuer un tirage
local function WeightedSample(items, k)
	
	local pool, weights = {}, {}
	for _, entry in ipairs(items) do
		
		table.insert(pool, entry)
		table.insert(weights, entry.Weight)
		
	end

	local result = {}
	for pick = 1, math.min(k, #pool) do
		
		local totalW = 0
		for _, w in ipairs(weights) do
			
			totalW += w 
		end
		
		local r = math.random() * totalW
		
		local cum = 0
		for i, w in ipairs(weights) do
			
			cum += w
			if r <= cum then
				
				table.insert(result, pool[i])
				table.remove(pool, i)
				table.remove(weights, i)
				
				break
			end
			
		end
	end
	
	return result
end

LootboxOpen.OnServerInvoke = function(player, lootbox)
	
	local lootBoxInfo = lootbox
	
	-- 0) Verifier que le joueur possede bien la lootbox et la consommer
	local has, err = InventoryManager:RemoveItem(player, lootBoxInfo.LootBoxId)
	if not has then
		warn(("[Lootbox] %s n'a pas de %s�: %s"):format(player.Name, lootBoxInfo.LootBoxId, err or ""))
		return nil
	end

	-- 1) Verifier la definition
	local boxDef = LootboxData.Boxes[lootBoxInfo.LootBoxId]
	if not boxDef then
		warn("Type de lootbox inconnu:", lootBoxInfo.LootBoxId)
		return nil
	end

	-- 2) Tirage pool gagnant
	local candidates = WeightedSample(boxDef.Fishes, boxDef.SelectionSize or 5)
	if #candidates == 0 then
		warn("Aucun candidat pour", lootBoxInfo.LootBoxId)
		return nil
	end
	
	local winner = candidates[math.random(1, #candidates)]

	-- 3) Ajouter l'egg a l'inventaire
	local stats = fishData[winner.Type]
	if not stats then
		warn("EggData manquant pour�:", winner.Type)
		return nil
	end
	
	local newId = HttpService:GenerateGUID(false)
	local eggEntry = 
	{
			Id    = newId,
			Egg   = true,
			Type  = winner.Type,
			Hatch = 0,
	}
	
	local ok, addErr = InventoryManager:AddEgg(player, eggEntry)
	if not ok then
		
		warn("Impossible d'ajouter l'egg � l'inventaire�:", addErr)
		return nil
	end

	-- 4) Retourner pool + winner
	return {
		Pool    = candidates,
		Winner  = winner,
		Rarity  = stats.Rarity,
		BoxName = winner.Name,
	}
end