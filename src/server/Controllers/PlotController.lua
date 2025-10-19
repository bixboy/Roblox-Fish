	-- ServerScriptService/PlotController.lua
	local CollectionService = game:GetService("CollectionService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local PlotManager      = require(game.ServerStorage.Modules:WaitForChild("PlotManager"))
	local SupportManager   = require(game.ServerStorage.Modules:WaitForChild("SupportManager"))
	local AquariumManager  = require(game.ServerStorage.Modules:WaitForChild("AquariumManager"))


	local function onPromptTriggered(player, plotPart)
		
		local ok, err = PlotManager:ClaimPlot(player, plotPart)
		if not ok then
			
			warn(("%s n'a pas pu revendiquer %s : %s"):format(player.Name, plotPart.Name, err))
			return
		end
				

		-- Reload de tous les objets places
		for _, info in ipairs(PlotManager:GetObjects(player)) do
					
			-- Reconstruit le template
			local template = ReplicatedStorage
			for segment in string.gmatch(info.Path, "[^%.]+") do
				
				template = template and template.Assets:FindFirstChild(segment, true)
				
				if not template then
					
					warn("Template introuvable au reload :", info.Path)
					break
				end
				
			end
			
			if not template then 
				continue end

			-- Clone + positionne
			local clone = template:Clone()
			clone.Parent = plotPart
			
			clone:SetAttribute("TemplatePath", info.Path)
			clone:SetAttribute("ObjectId",     info.Id)
			clone:AddTag("Object")
			
			PlotManager:RegisterObjectOwner(player, clone)

			-- Calcul du CFrame
			local center = plotPart.Position
			local ofs    = Vector3.new(unpack(info.Offset or {0,0,0}))
			local angs   = info.Angles or {0,0,0}
			local cf     = CFrame.new(center + ofs) * CFrame.Angles(unpack(angs))

			if clone:IsA("Model") then
				
				if not clone.PrimaryPart then
					
					local root = clone:FindFirstChild("Root") or clone:FindFirstChildWhichIsA("BasePart")
					if root then clone.PrimaryPart = root end
				end
				
				if clone.PrimaryPart then
					
					clone:SetPrimaryPartCFrame(cf)
				end
				
			elseif clone:IsA("BasePart") then
				
				clone.CFrame = cf
			end
			
			
			-- Si c'est un support
			if CollectionService:HasTag(clone, "Support") then
				
				SupportManager:InitSupport(clone)

				if info.Aquarium then
					
					local aquariumName = info.Aquarium.Path
					local fishList     = info.Aquarium.Fish
					local eggList      = info.Aquarium.Eggs
					local furnitures   = info.Aquarium.Furniture

					local AquariumData = require(game.ServerStorage.Data.AquariumData)

					local aquariumTemplate = AquariumData.Templates[aquariumName]
					if not aquariumTemplate then
						continue end

					SupportManager:ReloadAquarium(player, clone, aquariumName, fishList, eggList, furnitures)
				end
				
			end
			
		end
			
	end

	for _, plotPart in ipairs(CollectionService:GetTagged("Plot")) do
		
		local promptPart = plotPart:FindFirstChild("PromptPart")
		
		local prompt = promptPart:FindFirstChild("ProximityPrompt")
		if not prompt then
			
			prompt = Instance.new("ProximityPrompt")
			prompt.ActionText            = "Revendiquer"
			prompt.ObjectText            = "Terrain"
			prompt.HoldDuration          = 0.5
			prompt.MaxActivationDistance = 10
			prompt.Parent                = plotPart
			
		end
		
		prompt.Triggered:Connect(function(player)
			onPromptTriggered(player, plotPart)
		end)
		
	end

	CollectionService:GetInstanceAddedSignal("Plot"):Connect(function(plotPart)
		
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText            = "Revendiquer"
		prompt.ObjectText            = "Terrain"
		prompt.HoldDuration          = 0.5
		prompt.MaxActivationDistance = 10
		prompt.Parent                = plotPart
		
		prompt.Triggered:Connect(function(player)
			onPromptTriggered(player, plotPart)
		end)
		
	end)


	local IsMyPlotRF = ReplicatedStorage.Remotes:WaitForChild("IsMyPlotAt")
	IsMyPlotRF.OnServerInvoke = function(player, worldPos)
		
		return PlotManager:PlayerOwnsPlotAt(player, worldPos)
		
	end