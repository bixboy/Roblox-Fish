local Players = game:GetService("Players")

local PlayerControlManager = {}

local localPlayer = Players.LocalPlayer
local controls = nil

local function initControls()
	if not controls then
		local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
		if playerScripts then
			local playerModule = require(playerScripts:WaitForChild("PlayerModule"))
			controls = playerModule:GetControls()
		end
	end
end

function PlayerControlManager.Disable()
	initControls()
	if controls then
		controls:Disable()
	end
end

function PlayerControlManager.Enable()
	initControls()
	if controls then
		controls:Enable()
	end
end

return PlayerControlManager