-- LootboxController.lua
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Workspace          = game:GetService("Workspace")
local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local Debris             = game:GetService("Debris")

local player             = Players.LocalPlayer
local camera             = Workspace.CurrentCamera

local LootboxOpen        = ReplicatedStorage.Remotes:WaitForChild("LootboxOpenRequest")
local ControlManager     = require(ReplicatedStorage.Modules:WaitForChild("PlayerControlManager"))
local UiHider            = require(ReplicatedStorage.Modules:WaitForChild("UiHider"))

local lootboxZone        = Workspace:WaitForChild("LootboxZone")
local ground             = lootboxZone:WaitForChild("Ground")
local camPoint           = ground:WaitForChild("CameraPoint")
local boxModel           = ground:WaitForChild("LootboxModel")
local billboardPart      = ground:WaitForChild("BillboardPart")
local screenBillboard    = billboardPart:WaitForChild("ScreenBillboard")
local textLabel3D        = screenBillboard:FindFirstChildWhichIsA("TextLabel")

local mainUI             = player:WaitForChild("PlayerGui"):WaitForChild("MainUI")
local lootBoxGui         = mainUI.GameUI:WaitForChild("LootboxRollUI")

local background         = lootBoxGui:WaitForChild("Background")
local titleLabel         = background:WaitForChild("TitleLabel")
local countLabel         = background:WaitForChild("CountLabel")
local exitButton         = background:WaitForChild("ExitButton")

local LootboxController = {}
local HidenUi

-- camera helpers
local function tweenCameraTo(point, duration)
	
	camera.CameraType = Enum.CameraType.Scriptable
	local tween = TweenService:Create(
		camera,
		TweenInfo.new(duration or 1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = point.CFrame }
	)
	
	tween:Play()
	tween.Completed:Wait()
end

local function resetCamera()
	ControlManager.Enable()
	camera.CameraType = Enum.CameraType.Custom
end

-- ================================
-- Animation 3D de la lootbox
-- ================================
local function playBoxAnimation()
	
	local lid = boxModel:FindFirstChild("Lid")
	local base = boxModel:FindFirstChild("Base") or boxModel.PrimaryPart

	if not lid or not base then 
		return end

	for i = 1, 5 do
		lid.CFrame *= CFrame.Angles(0, math.rad(5 * ((i % 2 == 0) and 1 or -1)), 0)
		task.wait(0.05)
	end

	local hingeCFrame = lid.CFrame
	local openTween = TweenService:Create(
		lid,
		TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ CFrame = hingeCFrame * CFrame.Angles(-math.rad(120), 0, 0) }
	)
	
	openTween:Play()

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(0, 255, 255)
	light.Brightness = 3
	light.Range = 15
	light.Parent = base

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxassetid://241594419"
	particles.Rate = 100
	particles.Lifetime = NumberRange.new(0.5, 1)
	particles.Speed = NumberRange.new(5, 10)
	particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
	particles.Parent = base

	Debris:AddItem(light, 2)
	Debris:AddItem(particles, 2)
end

-- ================================
-- Animation UI du roll
-- ================================
local function playRollUI(finalResult, remaining)
	
	local rem = tonumber(remaining) or 0
	countLabel.Text = ("Loot box restantes : %d"):format(rem)

	exitButton.MouseButton1Click:Connect(function()
		lootBoxGui.Enabled = false
		if HidenUi then
			UiHider.RestoreUI(HidenUi)
			HidenUi = {}
		end
		resetCamera()
	end)

	local poolNames = {}
	for _, entry in ipairs(finalResult.Pool) do
		table.insert(poolNames, entry.Name)
	end
	if #poolNames == 0 then
		poolNames = {"???"}
	end

	local idx, totalTime, interval = 1, 2, 0.1
	local elapsed = 0
	while elapsed < totalTime do
		textLabel3D.Text = poolNames[idx]
		idx = idx % #poolNames + 1
		task.wait(interval)
		elapsed += interval
	end

	textLabel3D.Text = ("%s (%s)"):format(finalResult.Winner.Name, finalResult.Rarity)
	titleLabel.Text  = "Vous avez obtenu :"

	local newRem = rem > 0 and rem - 1 or 0
	countLabel.Text = ("Loot box restantes : %d"):format(newRem)

	wait(3)
	lootBoxGui.Enabled = false
	if HidenUi then
		UiHider.RestoreUI(HidenUi)
		HidenUi = {}
	end
	
	resetCamera()
end

-- ================================
-- API publique
-- ================================
function LootboxController.Open(lootbox)
	
	tweenCameraTo(camPoint, 1)
	ControlManager.Disable()
	HidenUi = UiHider.HideOtherUI(lootBoxGui)

	lootBoxGui.Enabled = true
	titleLabel.Text = "Rolling..."
	textLabel3D.Text = "..."

	playBoxAnimation()

	local result, remaining = LootboxOpen:InvokeServer(lootbox)
	if not result then
		warn("Ouverture echouee")
		resetCamera()
		return
	end

	playRollUI(result, remaining)
end

return LootboxController