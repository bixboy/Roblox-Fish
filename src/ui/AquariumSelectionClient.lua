local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local player            = Players.LocalPlayer


local OpenAquarium           = ReplicatedStorage.Remotes.Aquarium:WaitForChild("OpenAquariumSelection")
local GetAquariumList        = ReplicatedStorage.Remotes.Aquarium:WaitForChild("GetAquariumList")
local PlaceAquariumRequest   = ReplicatedStorage.Remotes.Aquarium:WaitForChild("PlaceAquariumRequest")
local proximityEnabledRemote = ReplicatedStorage.Remotes:WaitForChild("SetProximityPromptEnabled")


local PlayerControlManager = require(ReplicatedStorage.Modules:WaitForChild("PlayerControlManager"))
local UIListManager        = require(ReplicatedStorage.Modules:WaitForChild("UIListManager"))


local AquariumUI         = script.Parent
local UIFrame            = AquariumUI:WaitForChild("Frame")
local ListContainer      = UIFrame:WaitForChild("ItemList")
local CloseButton        = UIFrame:WaitForChild("CloseButton")
local itemButtonTemplate = ListContainer:WaitForChild("ItemButton", true)


itemButtonTemplate.Visible = false
AquariumUI.Enabled = false

local selectedSupport = nil


local function getAquariumList()
	
	local ok, result = pcall(function()
		return GetAquariumList:InvokeServer()
	end)

	if not ok then
		warn("Failed to get aquarium list:", result)
		return {}
	end
	
	return result
end


local function onAquariumSelected(itemData)
	PlaceAquariumRequest:FireServer(selectedSupport, itemData.Model)
end


local function onUIClosed()
	
	AquariumUI.Enabled = false
	UIFrame.Visible = false
	
	PlayerControlManager.Enable()
	
	proximityEnabledRemote:FireServer(true)
end


OpenAquarium.OnClientEvent:Connect(function(supportModel)
	
	selectedSupport = supportModel
	AquariumUI.Enabled = true
	UIFrame.Visible = true
	
	PlayerControlManager.Disable()

	UIListManager.SetupList{
		Frame       = UIFrame,
		Template    = itemButtonTemplate,
		CloseButton = CloseButton,
		GetItems    = getAquariumList,
		OnItemClick = onAquariumSelected,
		OnClose     = onUIClosed,
		AutoClose   = true,
		StackItems  = false
	}
end)