-- Client/ShopController.lua
local ReplicatedStorage      = game:GetService("ReplicatedStorage")
local Players                = game:GetService("Players")
local MarketplaceService     = game:GetService("MarketplaceService")

local player                 = Players.LocalPlayer

local Remotes                = ReplicatedStorage:WaitForChild("Remotes")
local BuyProduct             = Remotes:WaitForChild("RobuxBuyProduct")
local GetShopData            = Remotes:WaitForChild("GetRobuxShopData")

-- UI
local ShopUI                 = script.Parent
local MainFrame              = ShopUI:WaitForChild("ShopFrame")
local ScrollFrame            = MainFrame:WaitForChild("ScrollingFrame")
local CloseButton            = MainFrame:WaitForChild("CloseButton")

-- Config
local ListsConfig = {
	{
		Name      = "LootBoxes",
		Frame     = ScrollFrame:WaitForChild("LootBoxFrame"),
		RemoteKey = "LootBoxes",
	},
	{
		Name      = "Moneys",
		Frame     = ScrollFrame:WaitForChild("MoneyFrame"),
		RemoteKey = "Moneys",
	}
}

-- Template commun a tous
local Template = MainFrame:WaitForChild("ItemTemplate")
Template.Visible = false

-- Clear frame
local function clearFrame(frame)
	
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("TextButton") and child ~= Template then
			child:Destroy()
		end
	end
	
end

-- Recupere une table de donnees par categorie
local function fetchAllData()
	
	local ok, raw = pcall(function()
		return GetShopData:InvokeServer()
	end)
	
	if not ok or type(raw) ~= "table" then
		warn("Shop: impossible de recuperer les donnees")
		return {}
	end
	
	return raw
end

-- Construit une liste dans un frame donne
local function buildList(frame, items)
	clearFrame(frame)

	for _, entry in ipairs(items) do
		
		local info = MarketplaceService:GetProductInfo(entry.ProductId, Enum.InfoType.Product)
		if not info then
			warn("Shop: produit introuvable", entry.ProductId)
		else
			
			local btn = Template:Clone()
			btn.Visible     = true
			btn.Name        = entry.Key
			btn.Parent      = frame

			local icon = btn:FindFirstChild("Icon")
			if icon and info.IconImageAssetId then
				icon.Image = "rbxassetid://" .. tostring(info.IconImageAssetId)
			end

			btn:FindFirstChild("NameLabel").Text  = info.Name
			btn:FindFirstChild("PriceLabel").Text = tostring(info.PriceInRobux) .. " R$"

			btn.MouseButton1Click:Connect(function()
				BuyProduct:FireServer(entry.Key)
			end)
		end
	end
end

-- Fonction publique Open
local ShopController = {}

function ShopController.Open()
	MainFrame.Visible = true

	local allData = fetchAllData()
	for _, cfg in ipairs(ListsConfig) do
		
		local items = allData[cfg.RemoteKey] or {}
		buildList(cfg.Frame, items)
		
	end
end

function ShopController.Close()
	MainFrame.Visible = false
end

-- Fermeture via bouton
CloseButton.MouseButton1Click:Connect(function()
	ShopController.Close()
end)

return ShopController