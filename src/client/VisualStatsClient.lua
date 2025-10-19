local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local Players           = game:GetService("Players")

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

local MAX_RAY_DISTANCE = 100
local DISPLAY_DISTANCE = 40


local FishStatsUpdated = ReplicatedStorage.Remotes:WaitForChild("FishStatsUpdated") :: RemoteEvent

local clientFishStats = {}

local function isAquarium(model)
	return model and model:IsA("Model") and model.PrimaryPart and model:FindFirstChild("Visuals")
end


local function createStatsGui(fishVisual)
	
	if fishVisual:FindFirstChild("FishStatsGui") then return end
	
	local adornee
	if fishVisual:IsA("Model") then
		adornee = fishVisual.PrimaryPart or fishVisual:FindFirstChildWhichIsA("BasePart")
	elseif fishVisual:IsA("BasePart") then
		adornee = fishVisual
	end

	if not adornee then return end
	
	
	local gui = Instance.new("BillboardGui")
	gui.Name = "FishStatsGui"
	gui.Size = UDim2.new(0, 200, 0, 60)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = adornee
	gui.Parent = fishVisual

	local label = Instance.new("TextLabel")
	label.Name = "InfoLabel"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.6
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Text = "Loading..."
	label.Parent = gui
	
end


local function updateStatsForAquarium(aquarium)
	
	local visuals = aquarium:FindFirstChild("Visuals")
	if not visuals then return end
	
	local aquariumId = aquarium:GetAttribute("AquariumId")
	if not aquariumId then return end

	local stats = clientFishStats[aquariumId]
	if not stats then
		return
	end

	for _, visual in ipairs(visuals:GetChildren()) do
		createStatsGui(visual)

		local fishId = visual:GetAttribute("FishId")
		local fishStat = fishId and stats[fishId]
		
		local label = visual:FindFirstChild("FishStatsGui") and visual.FishStatsGui:FindFirstChild("InfoLabel")

		if fishStat and label then
			
			label.Text = string.format("?? %d | ?? %d%%\n?? %s%s",
				math.floor(fishStat.Hunger or 0),
				math.floor(fishStat.Growth or 0),
				fishStat.Rarity or "Common",
				(fishStat.IsMature and " ?" or "")
			)
			
		elseif label then
			
			label.Text = "..."
		end
	end
end


-- Remote update listener
FishStatsUpdated.OnClientEvent:Connect(function(aquariumModel, fish)
	
	if typeof(aquariumModel) ~= "Instance" or typeof(fish) ~= "table" then return end
	if not fish.Id then
		warn("? Pas d'ID poisson")
		return
	end
	
	local aquariumId = aquariumModel:GetAttribute("AquariumId")
	if not aquariumId then
		warn("? Pas d'AquariumId sur le modele", aquariumId)
		return
	end

	clientFishStats[aquariumId] = clientFishStats[aquariumId] or {}

	clientFishStats[aquariumId][fish.Id] = {
		Hunger   = fish.Hunger,
		Growth   = fish.Growth,
		IsMature = fish.IsMature,
		Rarity   = fish.Rarity,
	}
	
end)


local function setAquariumStatsVisibility(aquarium, visible)
	
	local visuals = aquarium:FindFirstChild("Visuals")
	if not visuals then return end
	
	
	for _, visual in ipairs(visuals:GetChildren()) do
		
		local gui = visual:FindFirstChild("FishStatsGui")
		if gui then
			gui.Enabled = visible
		end
		
	end
end


local currentAquarium = nil

RunService.RenderStepped:Connect(function()
	
	local mousePos = mouse.Hit.Position
	local origin = mouse.Origin.Position
	local direction = (mousePos - origin).Unit * MAX_RAY_DISTANCE

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {player.Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	local result = Workspace:Raycast(origin, direction, raycastParams)

	local hitAquarium = nil

	if result and result.Instance then
		
		local part = result.Instance
		local model = part:FindFirstAncestorWhichIsA("Model")
		
		if isAquarium(model) then
			
			
			local dist = (model.PrimaryPart.Position - origin).Magnitude
			if dist <= DISPLAY_DISTANCE then
				
				hitAquarium = model
			end
			
		end
	end

	if hitAquarium ~= currentAquarium then
				
		if currentAquarium then
			setAquariumStatsVisibility(currentAquarium, false)
		end
		
		if hitAquarium then
			setAquariumStatsVisibility(hitAquarium, true)
		end
		
		currentAquarium = hitAquarium
	end

	if currentAquarium then
		updateStatsForAquarium(currentAquarium)
	end
	
end)