-- ReplicatedStorage/Modules/DebugUI.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetIsAdmin = ReplicatedStorage.Remotes.Admins:WaitForChild("GetIsAdmin")

local DebugUI = {}
DebugUI.__index = DebugUI

local function queryIsAdmin()
	-- RemoteFunction ? InvokeServer
	local ok, result = pcall(function()
		return GetIsAdmin:InvokeServer()
	end)
	if not ok then
		warn("[DebugUI] GetIsAdmin failed:", result)
		return false
	end
	return result == true
end

function DebugUI:IsAuthorized()
	local player = Players.LocalPlayer
	if not player then return false end

	if queryIsAdmin() then
		print("[DebugUI] UserId:", player.UserId, "is admin")
		return true
	end
	return false
end

function DebugUI.Init(gui)
	if not DebugUI:IsAuthorized() then
		gui.Enabled = false
	else
		gui.Enabled = true
	end
end

return DebugUI