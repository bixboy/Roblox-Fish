local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

local NPC_FOLDER = workspace:WaitForChild("NPCs")

local MAX_YAW = 75
local SMOOTH_SPEED = 5
local PLAYER_DISTANCE = 20

local neckInitialC0s = {}
local currentYaws = {} 

local function getYawOffset(targetPos, originPos, facingDir)
	
	local dir = (targetPos - originPos)
	local flatDir = Vector3.new(dir.X, 0, dir.Z)
	if flatDir.Magnitude == 0 then return 0 end
	flatDir = flatDir.Unit

	local flatFacing = Vector3.new(facingDir.X, 0, facingDir.Z)
	if flatFacing.Magnitude == 0 then return 0 end
	flatFacing = flatFacing.Unit

	local dot = math.clamp(flatFacing:Dot(flatDir), -1, 1)
	local angle = math.deg(math.acos(dot))

	local crossY = flatFacing:Cross(flatDir).Y
	if crossY < 0 then angle = -angle end

	return angle
end

RunService.RenderStepped:Connect(function(dt)
	
	local char = localPlayer.Character
	local headPlayer = char and char:FindFirstChild("Head")
	if not headPlayer then return end

	for _, npc in pairs(NPC_FOLDER:GetChildren()) do
		
		local torso = npc:FindFirstChild("Torso")
		local root = npc:FindFirstChild("HumanoidRootPart")
		if not torso or not root then continue end

		local neck
		for _, child in pairs(torso:GetChildren()) do
			if child:IsA("Motor6D") and child.Name == "Neck" then
				neck = child
				break
			end
		end
		
		if not neck then continue end

		if not neckInitialC0s[neck] then
			neckInitialC0s[neck] = neck.C0
			currentYaws[neck] = 0
		end

		local lookToggle = npc:FindFirstChild("LookAtPlayer")
		if not lookToggle then
			lookToggle = Instance.new("BoolValue")
			lookToggle.Name = "LookAtPlayer"
			lookToggle.Value = true
			lookToggle.Parent = npc
		end

		local targetYaw = 0

		local distance = (npc.PrimaryPart.Position - char.PrimaryPart.Position).Magnitude
		if distance <= PLAYER_DISTANCE and lookToggle.Value then
			local yaw = getYawOffset(headPlayer.Position, torso.Position, root.CFrame.LookVector)

			if math.abs(yaw) <= MAX_YAW then
				targetYaw = yaw
			end
		end

		currentYaws[neck] = currentYaws[neck] + (targetYaw - currentYaws[neck]) * math.clamp(dt * SMOOTH_SPEED, 0, 1)
		neck.C0 = neckInitialC0s[neck] * CFrame.Angles(0, 0, math.rad(currentYaws[neck]))
	end
end)