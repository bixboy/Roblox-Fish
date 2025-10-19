--!strict
--[[
        PlayerControlManager
        Centralized access to the Roblox default PlayerModule controls with lazy
        initialization and safety guards for studio runs.
]]

local Players = game:GetService("Players")

local PlayerControlManager = {}
PlayerControlManager.__index = PlayerControlManager

local controls: any

local function ensureControls()
        if controls then
                return controls
        end

        local localPlayer = Players.LocalPlayer
        if not localPlayer then
                return nil
        end

        local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
        if not playerScripts then
                return nil
        end

        local success, playerModule = pcall(function()
                return require(playerScripts:WaitForChild("PlayerModule"))
        end)

        if success and playerModule then
                controls = playerModule:GetControls()
        end

        return controls
end

function PlayerControlManager.Disable()
        local manager = ensureControls()
        if manager then
                manager:Disable()
        end
end

function PlayerControlManager.Enable()
        local manager = ensureControls()
        if manager then
                manager:Enable()
        end
end

return PlayerControlManager
