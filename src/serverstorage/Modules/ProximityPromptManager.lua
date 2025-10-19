local ReplicatedStorage = game:GetService("ReplicatedStorage")

local proximityEnabledRemote  = ReplicatedStorage.Remotes:WaitForChild("SetProximityPromptEnabled")


local ProximityPromptManager = {}

function ProximityPromptManager:SetEnabledPrompt(Player, Enable)
	proximityEnabledRemote:FireClient(Player, Enable)
end

proximityEnabledRemote.OnServerEvent:Connect(function(Player, Enable)
	proximityEnabledRemote:FireClient(Player, Enable)
end)

return ProximityPromptManager
