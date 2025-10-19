-- ServerScriptService/RobuxShopController.lua
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local MarketplaceService  = game:GetService("MarketplaceService")
local Players             = game:GetService("Players")

local ShopData = require(game.ServerStorage.Data.RobuxShopData)

local Remotes            = ReplicatedStorage:WaitForChild("Remotes")
local GetShopDataRF      = Remotes:WaitForChild("GetRobuxShopData")
local BuyProductRE       = Remotes:WaitForChild("RobuxBuyProduct")


local KeyToProduct, ProductToMeta = {}, {}
for _, category in pairs(ShopData) do
	
	for _, item in ipairs(category) do
		
		KeyToProduct[item.Key] = item.ProductId
		ProductToMeta[item.ProductId] = {
			Key        = item.Key,
			RewardType = item.RewardType,
			RewardArgs = item.RewardArgs,
		}
		
	end
end


-- Envoie les donnees au client
GetShopDataRF.OnServerInvoke = function(player)
	return ShopData
end

-- Gestion achat
BuyProductRE.OnServerEvent:Connect(function(player, productKey)
	
	local productId = KeyToProduct[productKey]
	if not productId then
		
		warn(("[Shop] Cle de produit invalide recue de %s : %s"):format(player.Name, tostring(productKey)))
		return
	end
	
	MarketplaceService:PromptProductPurchase(player, productId)
end)


local function giveReward(player, productId)
	
	local meta = ProductToMeta[productId]
	if not meta then
		warn("[Shop] Aucune meta pour productId", productId)
		return false
	end

	if meta.RewardType == "LootBox" then
		
		local InventoryManager = require(game.ServerStorage.Modules.InventoryManager)
		local boxType = meta.RewardArgs.Type
		
		local ok, err = InventoryManager:AddItem(player, boxType)
		if not ok then
			
			warn("[Shop] Impossible d'ajouter la LootBox:", err)
			return false
		end

	elseif meta.RewardType == "Currency" then
		
		local EconomyManager = require(game.ServerStorage.Modules.EconomyManager)
		local amount = meta.RewardArgs.Amount or 0
		
		local ok, err = EconomyManager:AddMoney(player, amount)
		if not ok then
			
			warn("[Shop] Impossible d'ajouter des pieces:", err)
			return false
		end

	else
		
		warn("[Shop] Type de recompense inconnu :", meta.RewardType)
		return false
	end

	return true
end


MarketplaceService.ProcessReceipt = function(receiptInfo)
	
	local player    = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local productId = receiptInfo.ProductId

	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if giveReward(player, productId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn("aaaaaaaa")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end