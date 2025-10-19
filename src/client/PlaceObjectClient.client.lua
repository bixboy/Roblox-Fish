local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local Players           = game:GetService("Players")

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

local RemoveObjectRequest = ReplicatedStorage.Remotes:WaitForChild("RemoveObjectRequest")
local PreviewEvent        = ReplicatedStorage.Remotes:WaitForChild("PreviewRequest")
local PlaceRequest        = ReplicatedStorage.Remotes:WaitForChild("PlaceRequest")
local CancelRequest       = ReplicatedStorage.Remotes:WaitForChild("CancelPlacementRequest")
local IsMyPlotAt          = ReplicatedStorage.Remotes:WaitForChild("IsMyPlotAt")

local buyEvent            = ReplicatedStorage.Remotes:WaitForChild("BuyItem")
local getMarketItemsRF    = ReplicatedStorage.Remotes:WaitForChild("GetMarketItems")

local TooltipModule = require(ReplicatedStorage.Modules:WaitForChild("ModularTooltip"))

local currentPreviewPath  = nil
local currentPreviewModel = nil

local GRID_SIZE  = 2
local RAY_HEIGHT = 100
local RAY_DEPTH  = 200


-- === Grille de visualisation ===

local GRID_RADIUS = 4
local GRID_HEIGHT_OFFSET = -0.02
local gridParts = {}


local function calculateGridRadius(model)
	if not model then return 4 end -- fallback

	if model:IsA("Model") then
		
		local _, size = model:GetBoundingBox()
		local maxSize = math.max(size.X, size.Z)
		
		return math.ceil(maxSize / GRID_SIZE) + 1
		
	elseif model:IsA("BasePart") then
		
		local maxSize = math.max(model.Size.X, model.Size.Z)
		
		return math.ceil(maxSize / GRID_SIZE) + 1
	else
		
		return 4
	end
end

local function createGridTile()
	
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(GRID_SIZE - 0.2, 0.1, GRID_SIZE - 0.2)
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(0, 172, 0)
	part.Transparency = 0.7
	part.Name = "GridTile"
	part.Parent = Workspace
	
	return part
end


-- === Object Position Calcule === --

local function snapToGrid(position)
	
	local x = math.floor(position.X / GRID_SIZE + 0.5) * GRID_SIZE
	local z = math.floor(position.Z / GRID_SIZE + 0.5) * GRID_SIZE
	
	return Vector3.new(x, 0, z)
end


local function makePreviewRayParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local blacklist = {}
	if player.Character then
		table.insert(blacklist, player.Character)
	end
	
	if currentPreviewModel then
		
		table.insert(blacklist, currentPreviewModel)
		for _, desc in ipairs(currentPreviewModel:GetDescendants()) do
			
			if desc:IsA("BasePart") then
				table.insert(blacklist, desc)
			end
		end
		
	end
	
	if gridParts then
	
		for _, part in ipairs(gridParts) do
			table.insert(blacklist, part)
		end
	end
	
	params.FilterDescendantsInstances = blacklist
	return params
end


local function getGroundY(positionXZ)
	
	local origin = positionXZ + Vector3.new(0, RAY_HEIGHT, 0)
	local direction= Vector3.new(0, -RAY_DEPTH, 0)
	local params = makePreviewRayParams()

	local result = Workspace:Raycast(origin, direction, params)
	return (result and result.Position.Y) or 0
end


local function computeCFrameAt(positionXZ, instance)
	
	local groundY = getGroundY(positionXZ)

	local halfHeight
	if instance:IsA("Model") then
		
		local _, size = instance:GetBoundingBox()
		halfHeight = size.Y / 2
		
	elseif instance:IsA("BasePart") then
		
		halfHeight = instance.Size.Y / 2
	else
		halfHeight = 0
	end

	return CFrame.new(positionXZ.X, groundY + halfHeight, positionXZ.Z)
end


-- === Update Preview Position === --

local Workspace = game:GetService("Workspace")
local OverlapParams = OverlapParams.new()
OverlapParams.FilterType = Enum.RaycastFilterType.Exclude

local function canPlaceObject(previewModel)
	
	-- 1) Construire la liste � ignorer (preview + grille)
	local ignoreList = { previewModel}
	if previewModel:IsA("Model") then
		
		for _, desc in ipairs(previewModel:GetDescendants()) do
			
			if desc:IsA("BasePart") then
				
				table.insert(ignoreList, desc)
			end
			
		end
		
	end
	
	
	-- Ajoute les tiles de la grille a la ignoreList
	for _, tile in ipairs(gridParts) do
		
		table.insert(ignoreList, tile)
	end
	
	
	-- Ajoute le sol a la ignoreList
	local GroundFold = Workspace:FindFirstChild("Ground")
	local Ground = GroundFold:WaitForChild("Sand")
	table.insert(ignoreList, Ground)
	
	
	-- Ajoute les plots a la ignoreList
	for _, plotPart in ipairs(CollectionService:GetTagged("Plot")) do
		
		-- if plotPart:GetAttribute("Owner") == player.UserId then
		
		table.insert(ignoreList, plotPart)
		
		-- end
	end



	-- 2) Pour chaque BasePart du preview, tester l'OBB
	local partsToCheck = previewModel:IsA("Model") and previewModel:GetDescendants() or { previewModel }
	for _, part in ipairs(partsToCheck) do
		if part:IsA("BasePart") then
			
			-- Met a jour les exclusions
			OverlapParams.FilterDescendantsInstances = ignoreList

			-- Recupere les hits
			local hits = Workspace:GetPartBoundsInBox(part.CFrame, part.Size, OverlapParams)
			for _, hit in ipairs(hits) do
				
				if hit and hit.CanCollide and not table.find(ignoreList, hit) then
					
					-- print pour debug
					warn(("Collision detectee ! PreviewPart=%s heurte %s"):format(part.Name, hit:GetFullName()))
					
					return false
				end
				
			end
		end
	end

	return true
end

local function updatePreview()
	
	if not currentPreviewModel then return end

	local camera = Workspace.CurrentCamera
	local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local rayParams = makePreviewRayParams()
	
	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 999, rayParams)
	if not result then return end


	local hitPos = result.Position
	local gridXZ = snapToGrid(hitPos)
	local basePos = Vector3.new(gridXZ.X, hitPos.Y, gridXZ.Z)


	local halfHeight
	if currentPreviewModel:IsA("Model") then
		
		local _, size = currentPreviewModel:GetBoundingBox()
		halfHeight = size.Y / 2
		
	else
		halfHeight = currentPreviewModel.Size.Y / 2
	end


	local yaw = currentPreviewModel:GetAttribute("PreviewYaw") or 0
	local finalCFrame = CFrame.new(basePos + Vector3.new(0, halfHeight, 0)) * CFrame.Angles(0, yaw, 0)


	if currentPreviewModel:IsA("Model") then
		
		if currentPreviewModel.PrimaryPart then
			
			currentPreviewModel:SetPrimaryPartCFrame(finalCFrame)
		else
			
			currentPreviewModel:MoveTo(finalCFrame.Position)
		end
	else
		currentPreviewModel.CFrame = finalCFrame
	end
	
	
	-- === Grid Draw === --
	
	local radius = calculateGridRadius(currentPreviewModel)
	local centerPos = Vector3.new(gridXZ.X, getGroundY(gridXZ) + GRID_HEIGHT_OFFSET, gridXZ.Z)

	local index = 1
	for x = -radius, radius do
		
		for z = -radius, radius do
			
			local pos = centerPos + Vector3.new(x * GRID_SIZE, 0, z * GRID_SIZE)

			local tile = gridParts[index]
			if not tile then
				tile = createGridTile()
				gridParts[index] = tile
			end

			tile.Position = pos
			index += 1
		end
	end
	
end


-- Quand serveur demande une preview
PreviewEvent.OnClientEvent:Connect(function(objectPath)
	
	-- === Cleanup === --
	if currentPreviewModel then
		currentPreviewModel:Destroy()
		currentPreviewModel = nil
		currentPreviewPath  = nil
	end
	
	if clickConnection then
		clickConnection:Disconnect()
		clickConnection = nil
	end

	currentPreviewPath = objectPath


	-- === Clone Template === --
	local template = ReplicatedStorage
	for _, seg in ipairs(string.split(objectPath, ".")) do
		
		template = template:FindFirstChild(seg)
		if not template then return warn("Template introuvable", objectPath) end
	end
	
	local clone = template:Clone()
	clone.Name = "PreviewModel"
	clone.Parent = Workspace


	if clone:IsA("Model") and not clone.PrimaryPart then
		clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart")
	end


	-- === Ghost Parts === --
	local function ghostPart(p)
	
		local instance = p
		
		if instance:IsA("Model") then
			for _, p in ipairs(instance:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Transparency = 0.2
					p.CanCollide = false
				end
			end
			
			
			if instance.PrimaryPart and not instance:FindFirstChildOfClass("Highlight") then
				local hl = Instance.new("Highlight")
				hl.Name = "GhostHighlight"
				hl.FillColor = Color3.fromRGB(0, 255, 0)
				hl.FillTransparency = 0.5
				hl.OutlineTransparency = 1
				hl.Adornee = instance
				hl.Parent = instance
			end
			
		elseif instance:IsA("BasePart") then
			instance.Transparency = 0.2
			instance.CanCollide = false

			if not instance:FindFirstChildOfClass("Highlight") then
				local hl = Instance.new("Highlight")
				hl.Name = "GhostHighlight"
				hl.FillColor = Color3.fromRGB(0, 255, 0)
				hl.FillTransparency = 0.5
				hl.OutlineTransparency = 1
				hl.Adornee = instance
				hl.Parent = instance
			end
		end
	end
	
	if clone:IsA("Model") then
		for _, p in ipairs(clone:GetDescendants()) do ghostPart(p) end
	else
		ghostPart(clone)
	end


	-- === Biend To Update === --
	currentPreviewModel = clone
	currentPreviewModel:SetAttribute("PreviewYaw", 0)
	RunService:BindToRenderStep("UpdatePreview", Enum.RenderPriority.Camera.Value + 1, updatePreview)
	
	local clickConnection
	
	
	-- Place Object and Clear
	clickConnection = mouse.Button1Down:Connect(function()
		
		if not currentPreviewModel then return end
		
		if canPlaceObject(currentPreviewModel) then
			
			local finalCFrame
			if currentPreviewModel:IsA("Model") and currentPreviewModel.PrimaryPart then

				finalCFrame = currentPreviewModel.PrimaryPart.CFrame

			elseif currentPreviewModel:IsA("BasePart") then

				finalCFrame = currentPreviewModel.CFrame
			else
				
				return
			end
			
			local worldPos = finalCFrame.Position
			local ok = IsMyPlotAt:InvokeServer(worldPos)
			
			if not ok then
				warn("?? Tu n'es pas sur ton terrain, impossible de construire ici.")
				return
			end
			
				
			local ok, err = PlaceRequest:InvokeServer(currentPreviewPath, finalCFrame)
			if ok then

				if false then

					RunService:UnbindFromRenderStep("UpdatePreview")	
					currentPreviewPath = nil

					-- Disconect Button
					if clickConnection then

						clickConnection:Disconnect()
						clickConnection = nil
					end

					-- Clear Grid
					for _, tile in ipairs(gridParts) do
						if tile and tile:IsDescendantOf(Workspace) then
							tile:Destroy()
						end
					end
					table.clear(gridParts)

					if currentPreviewModel then
						currentPreviewModel:Destroy()
						currentPreviewModel = nil
						currentPreviewPath  = nil
					end

				end
			end
				
			
			return
		end
		
		warn("Placement impossible : collision detectee !")
	end)
	
end)


local pressedObject

mouse.Button2Down:Connect(function()
	
	local unitRay = Workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
	local rayParams = RaycastParams.new()
	
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { player.Character }

	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 25, rayParams)
	if result then
		local partHit  = result.Instance
		local modelHit = partHit:FindFirstAncestorWhichIsA("Model")

		if modelHit and CollectionService:HasTag(modelHit, "Object") then
			pressedObject = modelHit
		else
			pressedObject = nil
		end
	else
		pressedObject = nil
	end
end)

-- Quand on relache clic droit
mouse.Button2Up:Connect(function()
	
	local unitRay = Workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
	local rayParams = RaycastParams.new()
	
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { player.Character }

	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 25, rayParams)
	if not result then
		
		TooltipModule:Hide()
		pressedObject = nil
		
		return
	end

	local partHit  = result.Instance
	local modelHit = partHit:FindFirstAncestorWhichIsA("Model")

	if modelHit and pressedObject == modelHit and CollectionService:HasTag(modelHit, "Object") then
		local pos = Vector2.new(mouse.X, mouse.Y)

		TooltipModule:Show{
			Position = pos,
			Buttons = {
				{
					Text = "Remove",
					Callback = function()
						RemoveObjectRequest:FireServer(modelHit)
					end,
				}
			},
			Render = function(button, data)
				button.Text = data.Text
			end
		}
	else
		
		TooltipModule:Hide()
	end

	-- Reset a chaque release
	pressedObject = nil
end)

UserInputService.InputBegan:Connect(function(input, gp)
	
	if not gp and input.UserInputType == Enum.UserInputType.MouseButton1 then
		TooltipModule:Hide()
	end
	
end)


CancelRequest.OnClientEvent:Connect(function()
	
	if currentPreviewModel then
		currentPreviewModel:Destroy()
		currentPreviewModel = nil
	end

	currentPreviewPath = nil

	RunService:UnbindFromRenderStep("UpdatePreview")

	for _, tile in ipairs(gridParts) do
		if tile and tile:IsDescendantOf(Workspace) then
			tile:Destroy()
		end
	end
	
	table.clear(gridParts)
end)