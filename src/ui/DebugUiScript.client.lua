-- LocalScript sous GUI (StarterGui.ScreenGui.LocalScript)
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules et remotes existants
local DebugUI        = require(ReplicatedStorage.Modules:WaitForChild("DebugUI"))
local DropdownModule = require(ReplicatedStorage.Modules:WaitForChild("DropdownModule"))

local GetIsAdmin     = ReplicatedStorage.Remotes.Admins:WaitForChild("GetIsAdmin")
local AdminAction    = ReplicatedStorage.Remotes.Admins:WaitForChild("AdminAction")
local AdminInventory = ReplicatedStorage.Remotes.Admins:WaitForChild("AdminInventory")

-- Init UI
local gui = script.Parent
DebugUI.Init(gui)

local scrollingFrame = gui.Frame.ImageLabel.ScrollingFrame
local addMoneyBtn    = scrollingFrame:WaitForChild("AddMoneyButton", true)
local teleportBtn    = scrollingFrame:WaitForChild("TeleportButton", true)
local playersListBtn = scrollingFrame:WaitForChild("PlayersListButton", true)

local inventoryFrame = gui.Frame.InventoryFrame
local inventoryList  = inventoryFrame.InventoryList
local inventoryTemp  = inventoryList:WaitForChild("ItemEntry", true)

local playerFrame    = gui.Frame.PlayersFrame
local playerList     = playerFrame.PlayersList
local template       = playerList:WaitForChild("PlayerEntry", true)

local listVisible    = false
template.Visible     = false
playerFrame.Visible  = listVisible


local function send(action, targetId, data)
	AdminAction:FireServer(action, targetId, data)
end


-- Creation du dropdown pour l'ajout d'argent
local moneyDropdown = DropdownModule.new({
	AdorneeGui   = gui,
	Anchor       = addMoneyBtn,
	Options      = {
		{ Text = "+ 10$",  Value = 10  },
		{ Text = "+ 50$",  Value = 50  },
		{ Text = "+ 100$", Value = 100 },
		{ Text = "+ 1000$", Value = 1000 },
	},
	Width        = 120,
	OptionHeight = 30,
	Offset       = Vector2.new(0, 4),
	Callback     = function(amount)
		send("AddMoney", Player.UserId, { Amount = amount })
	end,
})
moneyDropdown:Enable()


teleportBtn.MouseButton1Click:Connect(function()
	
	local char = Players.LocalPlayer.Character
	if char then char:MoveTo(Vector3.new(0, 5, 0))end
	
end)

local function createInventory(inv, targetPlayer)
	
	for _, child in ipairs(inventoryList:GetChildren()) do
		if child:IsA("Frame") and child.Name:match("^Item_") and child ~= inventoryTemp then
			child:Destroy()
		end
	end

	inventoryFrame.Visible = true
	inventoryFrame.PlayerName.Text = "Inventory of " ..targetPlayer.Name
	
	inventoryFrame.CloseBtn.MouseButton1Click:Connect(function()
		inventoryFrame.Visible = false
	end)
	
	for _, item in pairs(inv) do
		
		local entry = inventoryTemp:Clone()
		entry.Name = ("Item_%s"):format(item.Id)
		entry.ItemName.Text = ("%s (x%d)"):format(item.Name, item.Count)
		entry.Visible = true
		entry.Parent = inventoryList

		entry.RemoveBtn.MouseButton1Click:Connect(function()
			send("RemoveItem", targetPlayer.UserId, { ItemId = item.Id, IsFish = item.IsFish})
		end)
	end
end

AdminInventory.OnClientEvent:Connect(function(targetId, inv)
	
	local targetPlayer = Players:GetPlayerByUserId(targetId)
	if not targetPlayer then 
		return end
	
	createInventory(inv, targetPlayer)
end)

-- Cr�e une ligne joueur
local function createPlayerEntry(player)
	
	local entry = template:Clone()
	entry.Name           = player.Name
	entry.NameLabel.Text = player.Name
	entry.Parent         = playerList
	entry.Visible        = true
	
	local AddMoneyBtn    = entry.Buttons:WaitForChild("AddMoneyButton")
	local RemoveMoneyBtn = entry.Buttons:WaitForChild("RemoveMoneyButton")
	local InventoryBtn   = entry.Buttons:WaitForChild("InventoryButton")

	local addDropdown = DropdownModule.new({
		AdorneeGui   = gui,
		Anchor       = AddMoneyBtn,
		Options      = {
			{ Text = "+ 10$", Value = 10 },
			{ Text = "+ 50$", Value = 50 },
			{ Text = "+ 100$", Value = 100 },
			{ Text = "+ 1000$", Value = 1000 },
		},
		Width        = 120,
		OptionHeight = 30,
		Offset       = Vector2.new(0, 4),
		Callback     = function(amount)
			send("AddMoney", player.UserId, { Amount = amount })
		end,
	})
	addDropdown:Enable()

	-- Dropdown pour remove money
	local removeDropdown = DropdownModule.new({
		AdorneeGui   = gui,
		Anchor       = RemoveMoneyBtn,
		Options      = {
			{ Text = "- 10$", Value = 10 },
			{ Text = "- 50$", Value = 50 },
			{ Text = "- 100$", Value = 100 },
			{ Text = "- 1000$", Value = 1000 },
		},
		Width        = 120,
		OptionHeight = 30,
		Offset       = Vector2.new(0, 4),
		Callback     = function(amount)
			send("RemoveMoney", player.UserId, { Amount = amount })
		end,
	})
	removeDropdown:Enable()

	-- Inventaire
	InventoryBtn.MouseButton1Click:Connect(function()
		send("OpenInventory", player.UserId, {})
	end)

	return entry
end

-- Populate list au demarrage
for _, plr in ipairs(Players:GetPlayers()) do
	createPlayerEntry(plr)
end

playersListBtn.MouseButton1Click:Connect(function()
	
	listVisible = not listVisible
	playerFrame.Visible = listVisible
end)

Players.PlayerAdded:Connect(function(plr)
	createPlayerEntry(plr)
end)

Players.PlayerRemoving:Connect(function(plr)
	
	local entry = scrollingFrame:FindFirstChild(plr.Name)
	if entry then
		entry:Destroy() 
	end
end)