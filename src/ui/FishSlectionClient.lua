-- Client/FishSelectionClien.lua

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService  = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

-- Remotes
local Remotes             = ReplicatedStorage:WaitForChild("Remotes")
local AquariumFolder      = Remotes.Aquarium

local GetInventoryRF      = Remotes.GetInventory
local SetProximityPrompt  = Remotes.SetProximityPromptEnabled

local OpenFishUIRE        = AquariumFolder.OpenFishSelectionUI
local AquariumAction      = AquariumFolder.AquariumAction
local GetAquariumFishList = AquariumFolder.GetAquariumFishList

-- Modules
local InteractionHelper = require(ReplicatedStorage.Modules.InteractionHelper).new()
local PlayerControl     = require(ReplicatedStorage.Modules.PlayerControlManager)
local TooltipModule     = require(ReplicatedStorage.Modules.ModularTooltip).new()
local UIListManager     = require(ReplicatedStorage.Modules.UIListManager)
local CameraTweener     = require(ReplicatedStorage.Modules.CameraTweener)
local UiHider           = require(ReplicatedStorage.Modules.UiHider)

-- UI References
local FishUI           = script.Parent
local Frame            = FishUI.Frame
local ListContainer    = Frame.ItemList
local Template         = ListContainer.ItemButton
local CloseButton      = Frame.CloseButton
local MaxFishNumber    = Frame.MaxFishNumber
local FishListButton   = Frame.FishListButton
local InvFishButton    = Frame.InventoryButton
local InvFurnituresBtn = Frame.FurnituresButton
local Title            = Frame.Title

-- Constants
local ZOOM_OFFSET = Vector3.new(0,1,4)
local ZOOM_TIME   = 0.6
local RETURN_TIME = 0.6

-- State
local selectedAquarium
local hiddenUI
local fishConns = {}
local FishNumber = 0
local FurnitureNumber = 0

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function clearFishConns()
	for _, c in ipairs(fishConns) do c:Disconnect() end
	fishConns = {}
end

local function setupFishConnections(aquariumModel, onItemClick)
	clearFishConns()

	for _, fishModel in ipairs(aquariumModel.Visuals:GetChildren()) do
		
		local part = fishModel.PrimaryPart or fishModel:FindFirstChildWhichIsA("BasePart")
		if part then
			
			local cd = part:FindFirstChildOfClass("ClickDetector")
			if cd then
				
				cd.MaxActivationDistance = 32
				table.insert(fishConns, cd.RightMouseClick:Connect(function(p)
					if p ~= player then return end
					
					local TempFishId = fishModel:GetAttribute("FishId")

					TooltipModule:Show {
						Position = Vector2.new(mouse.X, mouse.Y),
						Buttons = 
						{
							{ Text = "Feed", 
								Callback = function()
									
									AquariumAction:InvokeServer("FeedFish", aquariumModel, {FishId = TempFishId})
									
								end 
							},
							{ Text = "Take", 
								Callback = function()
								
									local ok = AquariumAction:InvokeServer("TakeFish", aquariumModel, {FishId = TempFishId})
									if ok then
										onItemClick({ Data = { Id = fishModel:GetAttribute("FishId") }}) 
									end
									
								end 
							},
						},
						Render = function(button, btnData) 
							button.Text = btnData.Text end
					}
				end))
			end
		end
	end
end

local function updateItemCount(mode)
	
	if not selectedAquarium then
		return end

	if mode == "Fish" then

		local fishCount = 0
		for _, item in ipairs(selectedAquarium.Visuals:GetChildren()) do
			
			if CollectionService:HasTag(item, "Fish") then
				fishCount += 1
			end
		end

		FishNumber = fishCount

		local maxFish = selectedAquarium:GetAttribute("MaxFish") or 0
		MaxFishNumber.Text = ("%d / %d"):format(fishCount, maxFish)

	elseif mode == "Furniture" then

		local usedSlots = 0
		for _, item in ipairs(selectedAquarium.Visuals:GetChildren()) do
			
			if CollectionService:HasTag(item, "Furniture") then
				usedSlots += 1
			end
		end

		FurnitureNumber = usedSlots

		local maxSlots = selectedAquarium:GetAttribute("MaxFurnitures") or 0
		MaxFishNumber.Text = ("%d / %d"):format(usedSlots, maxSlots)
	end
end

local function fetchFishData(remote, listUpdater)

	local ok, items = pcall(function() 
		return remote:InvokeServer(listUpdater)
	end)

	if not ok or type(items) ~= "table" then
		warn("[FishUI] failed to fetch data:", items)
		return {}
	end

	local immatureList, eggList, matureList = {}, {}, {}

	for _, entry in ipairs(items) do
		-- Normalisation du type
		local fishType = entry.DataName or entry.Type
		local fishName = entry.Name or fishType or "Unknown Fish"

		-- oeuf
		if entry.Type == "Egg" or entry.Egg then
			local hatchNow   = entry.Hatch or 0
			local hatchTotal = entry.MaxHatch or entry.HatchTime or 0

			table.insert(eggList, {
				Text = string.format("%s Egg - (%ds / %ds)", fishName, hatchNow, hatchTotal),
				Data = 
				{
					Id       = entry.Id,
					Type     = fishType,
					Egg      = true,
					Hatch    = hatchNow,
					MaxHatch = hatchTotal,
					Rarity   = entry.Rarity,
				},
			})

			-- Poisson
		else
			local fishData = {
				Text = string.format("%s - (H:%.1f, G:%.1f)%s",
					fishName,
					entry.Hunger or 0,
					entry.Growth or 0,
					entry.IsMature and " ?" or ""
				),
				Data = 
				{
					Id       = entry.Id,
					Type     = fishType,
					Hunger   = entry.Hunger,
					Growth   = entry.Growth,
					IsMature = entry.IsMature,
					Rarity   = entry.Rarity,
				},
			}

			if entry.IsMature then
				table.insert(matureList, fishData)
			else
				table.insert(immatureList, fishData)
			end
		end
	end

	-- Ordre : Immature -> Egg -> Mature
	local finalList = {}
	for _, v in ipairs(immatureList) do table.insert(finalList, v) end
	for _, v in ipairs(eggList) do table.insert(finalList, v) end
	for _, v in ipairs(matureList) do table.insert(finalList, v) end

	updateItemCount("Fish")
	return finalList
end

local function fetchFurnitureInventory()
	
	local ok, furnitures = pcall(function()
		return GetInventoryRF:InvokeServer("Furniture")
	end)

	if not ok or type(furnitures) ~= "table" then 
		return {} 
	end

	local placedList = {}
	local invList    = {}

	for _, furn in ipairs(furnitures) do
		table.insert(invList, 
		{
			Text = furn.Name,
			Data = furn,
		})
	end

	if selectedAquarium and selectedAquarium:FindFirstChild("Visuals") then
		for _, part in ipairs(selectedAquarium.Visuals:GetChildren()) do
			if CollectionService:HasTag(part, "Furniture") then
				local slotId   = part:GetAttribute("SlotId")
				local furnName = part:GetAttribute("Name")

				table.insert(placedList,
					{
					Text = string.format(
						"<b>%s</b> <i>(Slot: %i)</i>\n <font color=\"#ff0000\">Click for take</font>",
						furnName, slotId
					),
					Data = 
					{
						SlotId   = slotId,
						Name     = furnName,
						Placed   = true,
						Instance = part,
					},
				})
			end
		end
	end

	local finalList = {}
	for _, v in ipairs(placedList) do table.insert(finalList, v) end
	for _, v in ipairs(invList) do table.insert(finalList, v) end

	updateItemCount("Furniture")
	return finalList
end

local function fetchFishInventory()
	return fetchFishData(GetInventoryRF, "FishEgg")
end

local function fetchFishInAquarium()
	
	if not selectedAquarium then 
		warn("Aquarium is not valid")
		return {} 
	end
	
	return fetchFishData(GetAquariumFishList, selectedAquarium)
end

--------------------------------------------------------------------------------
-- Callbacks
--------------------------------------------------------------------------------
local function onInventoryFishClick(itemData)
	
	if itemData.Data.Egg then
		AquariumAction:InvokeServer("PlaceEgg", selectedAquarium, { EggId = itemData.Data.Id })
	else
		AquariumAction:InvokeServer("PlaceFish", selectedAquarium, { FishId = itemData.Data.Id })
	end
	
	task.delay(0.2, function()
		setupFishConnections(selectedAquarium, onAquariumFishClick)
		updateItemCount("Fish")
		
		if FishNumber == selectedAquarium:GetAttribute("MaxFish") then
			Title.Text = "Aquarium"
			
			UIListManager.SetupList{
				UiFrame      = Frame,
				Template     = Template,
				CloseButton  = CloseButton,
				ListContainer= ListContainer,
				GetItems     = fetchFishInAquarium,
				OnItemClick  = onAquariumFishClick,
				OnClose      = closeUI,
				AutoClose    = false,
				ColorButton = FishListButton.BackgroundColor3,
				StackItems  = false
			}
			
		else
			
			UIListManager.SetupList{
				UiFrame      = Frame,
				Template     = Template,
				CloseButton  = CloseButton,
				ListContainer= ListContainer,
				GetItems     = fetchFishInventory,
				OnItemClick  = onInventoryFishClick,
				OnClose      = closeUI,
				AutoClose    = false,
				ColorButton = InvFishButton.BackgroundColor3,
				StackItems  = false
			}
		end
	end)
end

function onAquariumFishClick(itemData)
	
	if itemData.Data.Egg then
		AquariumAction:InvokeServer("TakeEgg", selectedAquarium, { EggId = itemData.Data.Id })
	else
		AquariumAction:InvokeServer("TakeFish", selectedAquarium, { FishId = itemData.Data.Id })
	end
	
	task.delay(0.2, function()
		setupFishConnections(selectedAquarium, onAquariumFishClick)
		updateItemCount("Fish")
		
		if FishNumber == 0 then
			Title.Text = "Inventory"
			
			UIListManager.SetupList{
				UiFrame      = Frame,
				Template     = Template,
				CloseButton  = CloseButton,
				ListContainer= ListContainer,
				GetItems     = fetchFishInventory,
				OnItemClick  = onInventoryFishClick,
				OnClose      = closeUI,
				AutoClose    = false,
				ColorButton = InvFishButton.BackgroundColor3,
				StackItems  = false
			}
		end
	end)
end

function onFurnitureClick(itemData)
	
	
	if itemData.Data.Placed then
		AquariumAction:InvokeServer("RemoveFurniture", selectedAquarium, 
		{
				slotIndex = itemData.Data.SlotId
		})
	
		task.delay(0.2, function()
			
			updateItemCount("Furniture")
			UIListManager.SetupList{
				UiFrame     = Frame,
				Template    = Template,
				CloseButton = CloseButton,
				GetItems    = fetchFurnitureInventory,
				OnItemClick = onFurnitureClick,
				OnClose     = closeUI,
				AutoClose   = false,
				ColorButton = InvFurnituresBtn.BackgroundColor3,
				StackItems  = true
			}
		end)
	else

		local maxSlots = selectedAquarium:GetAttribute("MaxFurnitures") or 0
		local buttons = {}

		for i = 1, maxSlots do
			table.insert(buttons, 
				{
					Text = "Place in Slot " .. i,
					Callback = function()
						AquariumAction:InvokeServer("PlaceFurniture", selectedAquarium, 
							{
								FurnitureId = itemData.Data.Id,
								slotIndex   = i,
							})
						
						task.delay(0.2, function()
							
							updateItemCount("Furniture")
							UIListManager.SetupList{
								UiFrame     = Frame,
								Template    = Template,
								CloseButton = CloseButton,
								GetItems    = fetchFurnitureInventory,
								OnItemClick = onFurnitureClick,
								OnClose     = closeUI,
								AutoClose   = false,
								ColorButton = InvFurnituresBtn.BackgroundColor3,
								StackItems  = true
							}
						end)
					end
				})
		end

		TooltipModule:Show{
			Position = Vector2.new(mouse.X, mouse.Y),
			Buttons  = buttons,
			Render   = function(button, btnData)
				button.Text = btnData.Text end
		}
	end
end

--------------------------------------------------------------------------------
-- UI Control
--------------------------------------------------------------------------------
function closeUI()
	
	FishUI.Enabled = false
	TooltipModule:HideImmediate()
	SetProximityPrompt:FireServer(true)
	
	clearFishConns()
	
	UiHider.RestoreUI(hiddenUI) 
	PlayerControl.Enable() 
	CameraTweener.ReturnToPlayer(RETURN_TIME)
end

OpenFishUIRE.OnClientEvent:Connect(function(aquariumModel)

	selectedAquarium = aquariumModel
	FishUI.Enabled = true

	hiddenUI = UiHider.HideOtherUI(FishUI)
	InteractionHelper:disableModel(aquariumModel, aquariumModel.Visuals:GetChildren())

	clearFishConns()
	setupFishConnections(selectedAquarium, onAquariumFishClick)

	Title.Text = "Inventory"
	UIListManager.SetupList{
		UiFrame     = Frame,
		Template    = Template,
		CloseButton = CloseButton,
		GetItems    = fetchFishInventory,
		OnItemClick = onInventoryFishClick,
		OnClose     = closeUI,
		AutoClose   = false,
		ColorButton = InvFishButton.BackgroundColor3,
		StackItems  = false
	}

	CameraTweener.ZoomTo(aquariumModel, ZOOM_OFFSET, ZOOM_TIME, function()
		PlayerControl.Disable()
	end)
end)

FishListButton.MouseButton1Click:Connect(function()
	
	Title.Text = "Aquarium"
	UIListManager.SetupList{
		UiFrame     = Frame,
		Template    = Template,
		CloseButton = CloseButton,
		GetItems    = fetchFishInAquarium,
		OnItemClick = onAquariumFishClick,
		OnClose     = closeUI,
		AutoClose   = false,
		ColorButton = FishListButton.BackgroundColor3,
		StackItems  = false
	}
	
	setupFishConnections(selectedAquarium, onAquariumFishClick)
end)

InvFishButton.MouseButton1Click:Connect(function()
	
	Title.Text = "Inventory"
	UIListManager.SetupList{
		UiFrame     = Frame,
		Template    = Template,
		CloseButton = CloseButton,
		GetItems    = fetchFishInventory,
		OnItemClick = onInventoryFishClick,
		OnClose     = closeUI,
		AutoClose   = false,
		ColorButton = InvFishButton.BackgroundColor3,
		StackItems  = false
	}
	
	clearFishConns()
end)

InvFurnituresBtn.MouseButton1Click:Connect(function()

	Title.Text = "Furnitures"
	UIListManager.SetupList{
		UiFrame     = Frame,
		Template    = Template,
		CloseButton = CloseButton,
		GetItems    = fetchFurnitureInventory,
		OnItemClick = onFurnitureClick,
		OnClose     = closeUI,
		AutoClose   = false,
		ColorButton = InvFurnituresBtn.BackgroundColor3,
		StackItems  = true
	}
	
	clearFishConns()
end)