local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local leaderboardDataStore = DataStoreService:GetOrderedDataStore("PlayerMoneyLeaderboard")
local EconomyManager       = require(ServerStorage.Modules.EconomyManager)

-- Assure qu'on a un Remote pour envoyer les donnees
local remote = ReplicatedStorage:FindFirstChild("RequestLeaderboardData")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "RequestLeaderboardData"
	remote.Parent = ReplicatedStorage
end

-- Donne les 100 premiers
local function getTopPlayers()
	
	local success, pages = pcall(function()
		return leaderboardDataStore:GetSortedAsync(false, 100)
	end)

	if success and pages then
		
		local data = pages:GetCurrentPage()
		local leaderboard = {}

		for i, entry in ipairs(data) do
			
			table.insert(leaderboard, {
				UserId = entry.key,
				Money = entry.value,
			})
			
		end

		return leaderboard
	end

	return {}
end

-- Repond aux requetes client
remote.OnServerEvent:Connect(function(player)	
	local leaderboard = EconomyManager:GetTopBalances(100)
	remote:FireClient(player, leaderboard)
end)