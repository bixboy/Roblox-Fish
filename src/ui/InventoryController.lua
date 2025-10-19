local InventoryController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local player       = Players.LocalPlayer
local GetInventory = ReplicatedStorage.Remotes:WaitForChild("GetInventory")

-- UI
local inventoryUI     = script.Parent
local frameBackground = inventoryUI:WaitForChild("FrameBackGround")
local inventoryFrame  = frameBackground:WaitForChild("InventoryFrame")
local scrollFrame     = inventoryFrame:WaitForChild("ScrollingFrame")

local itemTemplate = scrollFrame:WaitForChild("ItemButton")
local closeButton  = frameBackground:WaitForChild("CloseButton")

local categoryFishBtn      = inventoryFrame:WaitForChild("BtnFish")
local categoryFurnitureBtn = inventoryFrame:WaitForChild("BtnFurniture")
local categoryLootBoxBtn   = inventoryFrame:WaitForChild("BtnLootBox")


itemTemplate.Visible    = false
frameBackground.Visible = false

-- Modules
local UIListManager     = require(game.ReplicatedStorage.Modules:WaitForChild("UIListManager"))
local LootboxController = require(player:WaitForChild("PlayerScripts"):WaitForChild("LootboxControllerClient"))

local currentCategory = "Fish"

local function getItemDataList()
	
	local success, items = pcall(function()
		return GetInventory:InvokeServer(currentCategory)
	end)

	if not success or type(items) ~= "table" then
		warn("Erreur recuperation inventaire pour categorie", currentCategory)
		return {}
	end

	local list = {}
	for _, it in ipairs(items) do
		table.insert(list, 
		{
			Text      = it.Name,
			Id        = it.Id,
			Name      = it.Name,
			Price     = it.Price,
			IsLootbox = (it.Type == "Lootbox"),
			LootBoxId = it.LootBoxId,
		})
	end

	return list
end

local function onItemClick(itemData)
	
	if itemData.IsLootbox then
		
		InventoryController.Close()
		LootboxController.Open(itemData)
	else
		
		print("Item clique :", itemData.Name)
	end
end

local function renderItem(button, itemData)
	
	local nameLabel = button:FindFirstChild("NameLabel")
	local priceLabel = button:FindFirstChild("PriceLabel")

	local name = itemData.Name
	if itemData.Count > 1 then
		name = name .. " x".. itemData.Count
	end
	
	nameLabel.Text = name
	priceLabel.Text = tostring(itemData.Price) .. "$"
end

local function refreshList()
	
	UIListManager.SetupList
	{
		UiFrame       = scrollFrame,
		Template      = itemTemplate,
		CloseButton   = closeButton,
		GetItems      = getItemDataList,
		OnItemClick   = onItemClick,
		OnClose       = function()
			frameBackground.Visible = false
		end,
		RenderItem    = renderItem,
		AutoClose     = false,
		StackItems    = true,
		ListContainer = scrollFrame
	}
end



categoryFishBtn.MouseButton1Click:Connect(function()
	currentCategory = "Fish"
	refreshList()
end)

categoryFurnitureBtn.MouseButton1Click:Connect(function()
	currentCategory = "Furniture"
	refreshList()
end)

categoryLootBoxBtn.MouseButton1Click:Connect(function()
	currentCategory = "Other"
	refreshList()
end)



function InventoryController.Open()
	frameBackground.Visible = true
	refreshList()
end

function InventoryController.Close()
	frameBackground.Visible = false
end

return InventoryController
