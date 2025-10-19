local ObjectPlacerController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local PLaceUI  = script.Parent
local frame    = PLaceUI:WaitForChild("Frame")
local itemList = frame:WaitForChild("ItemList")
local closeBtn = frame:WaitForChild("CloseButton")
local template = itemList:WaitForChild("ItemButton")

local UIListManager  = require(ReplicatedStorage.Modules:WaitForChild("UIListManager"))

local GetMarketRequest  = ReplicatedStorage.Remotes:WaitForChild("GetMarketItems")
local PreviewRequest    = ReplicatedStorage.Remotes:WaitForChild("PreviewRequest")
local CancelRequest     = ReplicatedStorage.Remotes:WaitForChild("CancelPlacementRequest")

template.Visible = false

local function getSupportsData()

	local ok, items = pcall(function()
		return GetMarketRequest:InvokeServer("Object")
	end)
	
	if not ok or type(items) ~= "table" then
		warn("Erreur en recuperant la liste du marche :", items)
		return {}
	end
	
	return items
end

local function onSupportClick(itemData)

	if itemData.Path == UIListManager.currentSelection then

		CancelRequest:FireServer()
		UIListManager.currentSelection = nil

	else

		PreviewRequest:FireServer(itemData.Path)
		UIListManager.currentSelection = itemData.Path
	end
end

local function renderSupport(button, itemData)
	button.Text = ("%s (%s: %d$)"):format(itemData.Name or "Unknown", itemData.Size, itemData.Price)
end

function ObjectPlacerController.close()

	frame.Visible = false

	if UIListManager.currentSelection then

		CancelRequest:FireServer()
		UIListManager.currentSelection = nil
	end
end

function ObjectPlacerController.Open()
	
	frame.Visible = true
	
	UIListManager.SetupList{
		UiFrame     = frame,
		Template    = template,
		CloseButton = closeBtn,
		GetItems    = getSupportsData,
		OnItemClick = onSupportClick,
		OnClose     = ObjectPlacerController.close,
		RenderItem  = renderSupport,
		AutoClose   = false
	}
end

return ObjectPlacerController
