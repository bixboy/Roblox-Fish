-- ServerScriptService/InventoryServer.server.lua
-- Bridges the client inventory UI with the authoritative InventoryManager.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local InventoryManager = require(ServerStorage.Modules:WaitForChild("InventoryManager"))

local GetInventory = ReplicatedStorage.Remotes:WaitForChild("GetInventory")

GetInventory.OnServerInvoke = function(player, category)
    return InventoryManager:GetDetailedItems(player, category)
end
