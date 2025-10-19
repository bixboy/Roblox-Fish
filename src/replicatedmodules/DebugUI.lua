--!strict
--[[
        DebugUI
        Authorizes debug interfaces based on an admin RemoteFunction.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetIsAdmin = ReplicatedStorage.Remotes.Admins:WaitForChild("GetIsAdmin")

local DebugUI = {}
DebugUI.__index = DebugUI

local function isAdmin(): boolean
        local success, result = pcall(function()
                return GetIsAdmin:InvokeServer()
        end)

        if not success then
                warn("[DebugUI] GetIsAdmin failed:", result)
                return false
        end

        return result == true
end

function DebugUI.IsAuthorized(): boolean
        local player = Players.LocalPlayer
        if not player then
                return false
        end

        return isAdmin()
end

function DebugUI.Init(gui: ScreenGui)
        gui.Enabled = DebugUI.IsAuthorized()
end

return DebugUI
