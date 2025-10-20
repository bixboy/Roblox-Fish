local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ServerStorage     = game:GetService("ServerStorage")
local Workspace         = game:GetService("Workspace")

local placeRemote         = ReplicatedStorage.Remotes:WaitForChild("PlaceRequest")
local cancelRemote        = ReplicatedStorage.Remotes:WaitForChild("CancelPlacementRequest")
local PreviewRequest      = ReplicatedStorage.Remotes:WaitForChild("PreviewRequest")
local RemoveObjectRequest = ReplicatedStorage.Remotes:WaitForChild("RemoveObjectRequest")

local PlacementRules   = require(ServerStorage.Modules:WaitForChild("PlacementRules"))
local PlotManager      = require(ServerStorage.Modules:WaitForChild("PlotManager"))
local SupportManager   = require(ServerStorage.Modules:WaitForChild("SupportManager"))
local AquariumManager  = require(ServerStorage.Modules:WaitForChild("AquariumManager"))
local InventoryManager = require(ServerStorage.Modules:WaitForChild("InventoryManager"))
local EconomyManager   = require(ServerStorage.Modules:WaitForChild("EconomyManager"))
local ItemCatalog      = require(ServerStorage.Data:WaitForChild("ItemCatalog"))

local GRID_SIZE  = 5
local RAY_HEIGHT = 100
local RAY_DEPTH  = 200


-- UTILITAIRES ----------------------------------------------------------------

local function warnAndReject(msg, ...)
	warn(msg, ...)
	return false
end


local function validateArgs(path, cf)
	
	if type(path) ~= "string" then return nil, "Path must be a string" end
	if typeof(cf) ~= "CFrame" then return nil, "CFrame must be a CFrame" end
	
	if not PlacementRules.ALLOWED_PATHS[path] then
		return nil, "Path not allowed: "..path
	end
	
	return true
end


local function fetchTemplate(path)
	
	local node = ReplicatedStorage
	for segment in path:gmatch("[^.]+") do
		
		node = node and node:FindFirstChild(segment)
		if not node then
			return nil 
		end
	end
	
	return node
end


local function snapToGrid(position)
	
	local x = math.floor(position.X / GRID_SIZE + 0.5) * GRID_SIZE
	local z = math.floor(position.Z / GRID_SIZE + 0.5) * GRID_SIZE
	
	return Vector3.new(x, 0, z)
end


local function makeRaycastParams(player)
	
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	
	local ignoredInstances = { player.Character }

	for _, plot in ipairs(CollectionService:GetTagged("Plot")) do
		table.insert(ignoredInstances, plot)
	end
	
	params.FilterDescendantsInstances = ignoredInstances
	
	return params
end


local function getGroundY(positionXZ, player)
	
	local origin = positionXZ + Vector3.new(0, RAY_HEIGHT, 0)
	local direction = Vector3.new(0, -RAY_DEPTH, 0)
	
	local result = Workspace:Raycast(origin, direction, makeRaycastParams(player))
	if result then
		
		return result.Position.Y
	else
		return 0
	end
	
end


local function halfHeightFor(template)
	
	if template:IsA("Model") then
		
		local _, size = template:GetBoundingBox()
		return size.Y / 2
		
	elseif template:IsA("BasePart") then
		
		return template.Size.Y / 2
	else
		
		return 0
	end
	
end


local function computeFinalCFrame(receivedCFrame, template, player)
	
	local posXZ      = snapToGrid(Vector3.new(receivedCFrame.X, 0, receivedCFrame.Z))
	local groundY    = getGroundY(posXZ, player)
	local halfHeight = halfHeightFor(template)

	local serverCFrame = CFrame.new(posXZ.X, groundY + halfHeight, posXZ.Z) * (receivedCFrame - receivedCFrame.Position)

	local diff = (receivedCFrame.Position - serverCFrame.Position).Magnitude
	local finalCFrame = diff > PlacementRules.MAX_OFFSET and serverCFrame or receivedCFrame

	return finalCFrame
end


local function isColliding(cframe, template, plotPart)
	
	local ghost = template:Clone()
	ghost.Parent = Workspace

	if ghost:IsA("Model") then
		if not ghost.PrimaryPart then
			ghost.PrimaryPart = ghost:FindFirstChildWhichIsA("BasePart")
		end
		if ghost.PrimaryPart then
			ghost:SetPrimaryPartCFrame(cframe)
		else
			ghost:MoveTo(cframe.Position)
		end
	elseif ghost:IsA("BasePart") then
		ghost.CFrame = cframe
	end

	for _, part in ipairs(ghost:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = true
		end
	end

	game:GetService("RunService").Heartbeat:Wait()

	local collides = false
	local checkParts = {}

	if ghost:IsA("Model") and ghost.PrimaryPart then
		
		checkParts = ghost.PrimaryPart:GetTouchingParts()
	elseif ghost:IsA("BasePart") then
		
		checkParts = ghost:GetTouchingParts()
	end

	for _, part in ipairs(checkParts) do
		
		if part:IsDescendantOf(plotPart) and not CollectionService:HasTag(part, "Plot") then
			collides = true
			break
		end
	end

	ghost:Destroy()
	return collides
end


-- === Remote Handler ===

placeRemote.OnServerInvoke = function(player, objectPath, receivedCFrame)
		
	-- 1) validation basique
	local ok, err = validateArgs(objectPath, receivedCFrame)
	if not ok then 
		
		return warnAndReject(err) 
	end

	-- 2) le joueur a-t-il un plot ?
	local plotPart = PlotManager:GetPlotOf(player)
	if not plotPart then
		
		return warnAndReject("Player has no plot:", player)
	end

	-- 3) fetch template
	local template = fetchTemplate(objectPath)
	if not template then
		
		return warnAndReject("Template not found:", objectPath)
	end

	-- 4) catalogue d'items & paiement
	local item = ItemCatalog[template.Name]
	if not item then
		
		return warnAndReject("Item not in catalog:", template.Name)
	end
	
	if not EconomyManager:RemoveMoney(player, item.Price) then
		
		return warnAndReject("Insufficient funds for:", item.Name)
	end

	-- 5) calcul du placement final
	local finalCFrame = computeFinalCFrame(receivedCFrame, template, player)

	-- 6.1) verification de la distance joueur?objet
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - finalCFrame.Position).Magnitude > PlacementRules.MAX_PLACE_DIST then
		
		return warnAndReject("Placement too far from player")
	end

	-- 6.2) test de collision
	if isColliding(finalCFrame, template, plotPart) then
		return warnAndReject("Placement collision avec un objet existant")
	end
	
	-- 7) creation et positionnement du clone
	local clone = template:Clone()
	if clone:IsA("Model") then

		if not clone.PrimaryPart then

			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart")
		end

		if clone.PrimaryPart then

			clone:SetPrimaryPartCFrame(finalCFrame)
		else

			clone:MoveTo(finalCFrame.Position)
		end

	elseif clone:IsA("BasePart") then


		local offsets = {}
		for _, child in ipairs(template:GetChildren()) do

			if child:IsA("BasePart") then

				offsets[child.Name] = child.Position - template.Position
			end

		end

		clone.CFrame = finalCFrame

		for _, child in ipairs(clone:GetChildren()) do

			if child:IsA("BasePart") and offsets[child.Name] then

				child.Position = clone.Position + offsets[child.Name]
			end

		end

	end

	-- 8) finalisation : parent, tags, enregistrement
        clone.Parent = plotPart
        clone:SetAttribute("TemplatePath", objectPath)
        CollectionService:AddTag(clone, "Object")
	
	PlotManager:AddObject(player, plotPart, clone)

	if #clone:GetTags("Support") > 0 then
		SupportManager:InitSupport(clone)
	end

	return true
end


RemoveObjectRequest.OnServerEvent:Connect(function(player, instanceToRemove)
	
	-- 1) verif plot
	local plotPart = PlotManager:GetPlotOf(player)
	if not plotPart or not instanceToRemove:IsDescendantOf(plotPart) then
		
		warn("RemoveObject: hors du plot")
		return
	end
	
	-- 2) verif owner
	if not PlotManager:GetPlayerOwnObject(player, instanceToRemove) then
		
		warn(("RemoveObject: %s n'est pas proprio de %s"):format(player.Name, instanceToRemove:GetFullName()))
		return
	end

	-- 3) recuperer l'ID et nettoyer memoire
	local objectId = instanceToRemove:GetAttribute("ObjectId")
	if objectId then
		
		PlotManager:RemoveObject(player, objectId)
	end

	-- 4) nettoyage visuel
	if CollectionService:HasTag(instanceToRemove, "Support") then
		
		for _, ch in ipairs(instanceToRemove:GetChildren()) do
			
			if CollectionService:HasTag(ch, "Aquarium") then
				
				local manager = AquariumManager.Get(ch)
				if manager then
										
					local fishMap = manager._instance and manager._instance.FishMap
					if fishMap then
						
						for _, fishInfo in pairs(fishMap) do
							InventoryManager:AddFish(player, fishInfo)
						end
					end
					
					manager:Destroy()
				end

				ch:Destroy()
			end
		end
	end

	instanceToRemove:Destroy()
end)


-- Preview renvoyee uniquement au joueur
PreviewRequest.OnServerEvent:Connect(function(player, objectPath)
	
	if typeof(objectPath) ~= "string" then 
		
		warn("This path is not Valid")
		
		return 
	end
	
	if not PlacementRules.ALLOWED_PATHS[objectPath] then

		warn("This path is not Allowed")

		return 
	end
	
	PreviewRequest:FireClient(player, objectPath)
end)

cancelRemote.OnServerEvent:Connect(function(player)
	cancelRemote:FireClient(player)
end)