local RNGStyleLaserVFX = require(game.ReplicatedStorage.Modules:FindFirstChild("RNGStyleLaserVFX"))

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

task.wait(2)

local function fireDemoLaser()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local origin = root.Position + Vector3.new(0, 3, 0)
    local direction = root.CFrame.LookVector
	local length = 100


	RNGStyleLaserVFX.FireMeshLaser(origin, direction, length)
end

