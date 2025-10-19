-- ServerScriptService/AdminServer.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local AdminConfig       = require(ServerStorage.Config:WaitForChild("AdminConfig"))
local InventoryManager  = require(ServerStorage.Modules:WaitForChild("InventoryManager"))
local EconomyManager    = require(ServerStorage.Modules:WaitForChild("EconomyManager"))

-- Creation des remotes si absents
local Remotes = ReplicatedStorage:FindFirstChild("Remotes").Admins

local GetIsAdmin     = Remotes:FindFirstChild("GetIsAdmin")
local AdminAction    = Remotes:FindFirstChild("AdminAction")
local AdminInventory = Remotes:WaitForChild("AdminInventory")


-- Verifie si player est admin
local function isAdmin(player)
	
	for _, id in ipairs(AdminConfig.UserIds) do
		
		if player.UserId == id then
			return true
		end
	end
	
	return false
end

GetIsAdmin.OnServerInvoke = function(player)
	return isAdmin(player)
end

local function groupInventory(items)
	
	local grouped = {}
	for _, item in ipairs(items) do
		
		if item and item.Id then
			
			local itemName = item.Name or item.Type or "Unknown"
			local isFish   = (item.Type ~= nil)

			if not grouped[item.Id] then
				grouped[item.Id] = {
					Id     = item.Id,
					Name   = itemName,
					Count  = 0,
					IsFish = isFish,
				}
			end

			grouped[item.Id].Count += 1
		else
			print("[AdminServer] ?? Item invalide re�u :", item)
		end
	end

	-- Transforme en tableau simple
	local result = {}
	for _, entry in pairs(grouped) do
		
		print(string.format("[AdminServer] ? Grouped Item -> Id: %s, Name: %s, Count: %d, IsFish: %s", entry.Id, entry.Name, entry.Count, tostring(entry.IsFish)))
		table.insert(result, entry)
	end
	
	return result
end

-- Gere les actions admin
AdminAction.OnServerEvent:Connect(function(player, action, targetId, data)
	
	if not isAdmin(player) then return end

	local target = Players:GetPlayerByUserId(targetId)
	if not target then return end

	if action == "AddMoney" then
		EconomyManager:AddMoney(target, data.Amount)

	elseif action == "RemoveMoney" then
		EconomyManager:RemoveMoney(target, data.Amount)

	elseif action == "RemoveItem" then
		
		if not data.IsFish then
			InventoryManager:RemoveItem(target, data.ItemId)
		else
			InventoryManager:RemoveFish(target, data.ItemId)
		end

	elseif action == "OpenInventory" then
		local inventory = InventoryManager:GetItems(target)
		local grouped   = groupInventory(inventory)
		AdminInventory:FireClient(player, targetId, grouped)

	elseif action == "Ban" then
		target:Kick("You have been banned by an administrator.")
		-- TODO: ajoute ton systeme de ban persistant (DataStore)
	end
end)