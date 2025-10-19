local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local StartDialogue = ReplicatedStorage.Remotes:WaitForChild("StartDialogue")

local PlayerControlManager = require(ReplicatedStorage.Modules:WaitForChild("PlayerControlManager"))
local UiHider              = require(ReplicatedStorage.Modules:WaitForChild("UiHider"))


local travellingTime = 2 -- In seconds

local isInteracting = false

local currentTween
local tweenCompletedConnection
local followCameraConnection
local isInteracting = false

local waitingForUIToClose = false
local nextLineAfterUI = nil
local clonedUI = nil

local HidenUi


-- Players Visibility

local originalStates = {}

local function setAllPlayersVisibility(visible)
	if not visible then
		
		-- Save original state
		originalStates = {}
		for _, player in pairs(game.Players:GetPlayers()) do
			
			local character = player.Character
			if character then
				
				originalStates[player] = {}
				for _, part in pairs(character:GetChildren()) do
					if part:IsA("BasePart") or part:IsA("Decal") then
						originalStates[player][part] = part.Transparency
						part.Transparency = 1
					elseif part:IsA("Accessory") and part:FindFirstChild("Handle") then
						local handle = part.Handle
						originalStates[player][handle] = handle.Transparency
						handle.Transparency = 1
					elseif part:IsA("ParticleEmitter") or part:IsA("BillboardGui") then
						originalStates[player][part] = part.Enabled
						part.Enabled = false
					end
				end
				
				local humanoid = character:FindFirstChild("Humanoid")
				if humanoid then
					originalStates[player]["NameDisplayDistance"] = humanoid.NameDisplayDistance
					humanoid.NameDisplayDistance = 0
				end
				
			end
			
		end
		
	else
		-- Restor state saved
		for player, parts in pairs(originalStates) do
			local character = player.Character
			if character then
				for part, state in pairs(parts) do
					if part and part.Parent then
						if typeof(state) == "number" then
							part.Transparency = state
						elseif typeof(state) == "boolean" then
							part.Enabled = state
						end
					end
				end
				local humanoid = character:FindFirstChild("Humanoid")
				if humanoid and parts["NameDisplayDistance"] then
					humanoid.NameDisplayDistance = parts["NameDisplayDistance"]
				end
			end
		end
		
		originalStates = {}
	end
end


-- Start Dialogues

StartDialogue.OnClientEvent:Connect(function(npcModel, dialogueLines)
	
	if isInteracting then return end
	isInteracting = true
	
	-- Creation du bouton Exit des le debut, dans un ScreenGui a part
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	
	local exitGui = Instance.new("ScreenGui")
	exitGui.Name = "ExitDialogueGui"
	exitGui.ResetOnSpawn = false
	exitGui.Parent = playerGui

	local exitButton = Instance.new("TextButton")
	exitButton.Name = "ExitButton"
	exitButton.Size = UDim2.new(0, 100, 0, 40)
	exitButton.Position = UDim2.new(1, -110, 1, -50) -- en haut a droite
	exitButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	exitButton.TextColor3 = Color3.new(1, 1, 1)
	exitButton.Font = Enum.Font.GothamBold
	exitButton.TextScaled = true
	exitButton.Text = "Exit"
	exitButton.Parent = exitGui
	exitButton.ZIndex = 10
	
	HidenUi = UiHider.HideOtherUI(exitGui)

	-- Fonction pour fermer le dialogue
	local function closeDialogue()
		if not isInteracting then return end
		isInteracting = false

		-- Arreter le tween si en cours
		if currentTween then
			currentTween:Cancel()
			currentTween = nil
		end
		
		if tweenCompletedConnection then
			tweenCompletedConnection:Disconnect()
			tweenCompletedConnection = nil
		end
		
		if followCameraConnection then
			followCameraConnection:Disconnect()
			followCameraConnection = nil
		end

		-- Supprimer les GUI
		local playerGui = localPlayer:WaitForChild("PlayerGui")
		if playerGui:FindFirstChild("ChoiceGui") then
			playerGui.ChoiceGui:Destroy()
		end
		
		if clonedUI then
			clonedUI:Destroy()
			waitingForUIToClose = false
		end
		
		if exitButton then
			exitGui:Destroy()
		end
		
	

		-- reactive le prompt
		local prompt = npcModel:FindFirstChild("PromptPart")
		local proximity = prompt and prompt:FindFirstChild("ProximityPrompt")
		if proximity then
			proximity.Enabled = true
		end

		local humanoid = npcModel:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		end
		
		-- reactive le lookAtPlayer
		local LookAtBool = npcModel:FindFirstChild("LookAtPlayer")
		if LookAtBool then
			LookAtBool.Value = true
		end

		-- rend visible les joueurs
		setAllPlayersVisibility(true)
		
		if HidenUi then
			UiHider.RestoreUI(HidenUi)
			HidenUi = {}
		end

		local currentCamera = workspace.CurrentCamera
		currentCamera.CameraType = Enum.CameraType.Custom

		
		-- Reactive le mouvement des joueurs
		local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
		local playerModule = require(playerScripts:FindFirstChild("PlayerModule"))
		local controls = playerModule:GetControls()
		if controls then
			controls:Enable()
		end


		-- Supprimer le GUI de dialogue
		local head = npcModel:FindFirstChild("Head")
		if head then
			
			local existingGui = head:FindFirstChild("DialogueBillboard")
			if existingGui then 
				existingGui:Destroy() 
			end
			
		end
	end

	exitButton.MouseButton1Click:Connect(closeDialogue)


	-- Check Head
	local head = npcModel:FindFirstChild("Head")
	if not head then 
		
		closeDialogue()
		isInteracting = false
		return 
	end

	
	-- Check GUI
	local existingGui = head:FindFirstChild("DialogueBillboard")
	if existingGui then
		existingGui:Destroy()
	end

	
	-- Check Prompt
	local prompt = npcModel:FindFirstChild("PromptPart")
	local proximity = prompt and prompt:FindFirstChild("ProximityPrompt")
	if proximity then
		proximity.Enabled = false
	else
		isInteracting = false
		return
	end


	-- Check Humanoid
	local humanoid = npcModel:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	else
		isInteracting = false
		return
	end

	
	-- Check Look at bool
	local LookAtBool = npcModel:FindFirstChild("LookAtPlayer")
	if LookAtBool then
		LookAtBool.Value = false
	else
		isInteracting = false
		return
	end
	
	
	-- Disable Movements
	PlayerControlManager.Disable()
	
	setAllPlayersVisibility(false)


	-- ** CutScene Camera Setup **
	
	local currentCamera = workspace.CurrentCamera

	local cameraFolder = npcModel:WaitForChild("CameraPart")
	local camera1 = cameraFolder:WaitForChild("Camera1")

	local npcRoot = npcModel:FindFirstChild("HumanoidRootPart") or npcModel:FindFirstChild("Head")
	if not npcRoot then isInteracting = false return end

	currentCamera.CameraType = Enum.CameraType.Scriptable

	local isTweening = true

	followCameraConnection = RunService.RenderStepped:Connect(function()
		if isTweening then
			local camPos = currentCamera.CFrame.Position
			local lookAt = npcRoot.Position + Vector3.new(0, 1.5, 0)
			currentCamera.CFrame = CFrame.new(camPos, lookAt)
		end
	end)

	local tweenInfo = TweenInfo.new(travellingTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local targetCFrame = CFrame.new(camera1.Position, npcRoot.Position + Vector3.new(0, 1.5, 0))
	local tween = TweenService:Create(currentCamera, tweenInfo, {CFrame = targetCFrame})

	tween:Play()
	
	currentTween = TweenService:Create(currentCamera, tweenInfo, {CFrame = targetCFrame})
	currentTween:Play()



	-- ** Start Dialogues **
	
	tweenCompletedConnection = currentTween.Completed:Connect(function()
		
		if not isInteracting then return end

		isTweening = false
		if followCameraConnection then
			followCameraConnection:Disconnect()
			followCameraConnection = nil
		end

		currentCamera.CFrame = CFrame.new(camera1.Position, npcRoot.Position + Vector3.new(0, 1.5, 0))
		

		-- Creation du BillboardGui pour afficher le dialogue
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "DialogueBillboard"
		billboard.Size = UDim2.new(0, 300, 0, 100)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.Adornee = head
		billboard.AlwaysOnTop = true
		billboard.Parent = head

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0.7, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextWrapped = true
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Parent = billboard
		

		-- Fermeture du pannel

		local showLine
		local function ChoicePanelClosed(closeButton, PanelUi)

			closeButton.MouseButton1Click:Connect(function()
				
				PanelUi:Destroy()
				
				waitingForUIToClose = false
				billboard.Enabled = true

				if nextLineAfterUI then

					showLine(nextLineAfterUI)
					nextLineAfterUI = nil
				end
			end)

		end


		-- Affichage de pannel
		
		local uiFolder = ReplicatedStorage:WaitForChild("UI")

		local function tryCloneUI(actionName)

			if clonedUI then
				clonedUI:Destroy()
				clonedUI = nil
			end

			local uiFolder = ReplicatedStorage:WaitForChild("UI")
			local uiTemplate = uiFolder:FindFirstChild(actionName)

			if uiTemplate then
				clonedUI = uiTemplate:Clone()
				clonedUI.ResetOnSpawn = false
				clonedUI.Parent = localPlayer:WaitForChild("PlayerGui")
				
				billboard.Enabled = false

				local closeButton = clonedUI:FindFirstChild("CloseButton", true)
				if closeButton then
					ChoicePanelClosed(closeButton, clonedUI)
				else
					warn("No CloseButton found in UI:", actionName)
				end

			else
				warn("UI not found for action:", actionName)
			end

		end
		

		-- Creation de l'interface choix
		local playerGui = localPlayer:WaitForChild("PlayerGui")

		local choiceGui = Instance.new("ScreenGui")
		choiceGui.Name = "ChoiceGui"
		choiceGui.ResetOnSpawn = false
		choiceGui.Parent = playerGui

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(0, 400, 0, 200)
		frame.Position = UDim2.new(0.5, -200, 0.8, -100)
		frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		frame.BackgroundTransparency = 0.3
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.Parent = choiceGui

		local choicesFrame = Instance.new("Frame")
		choicesFrame.Size = UDim2.new(1, -20, 0.6, 0)
		choicesFrame.Position = UDim2.new(0, 10, 0.4, 0)
		choicesFrame.BackgroundTransparency = 1
		choicesFrame.Parent = frame
		
		-- Fonction pour vider les choix
		local function clearChoices()
			for _, child in pairs(choicesFrame:GetChildren()) do
				child:Destroy()
			end
			frame.Visible = false
		end

		-- Fonction pour afficher les choix avec gestion du clic
		local function showChoices(choices, onChoiceSelected)
			
			clearChoices()
			frame.Visible = true

			for i, choice in ipairs(choices) do
				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, 0, 0, 40)
				btn.Position = UDim2.new(0, 0, 0, (i - 1) * 45)
				btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
				btn.TextColor3 = Color3.new(1, 1, 1)
				btn.Font = Enum.Font.GothamBold
				btn.TextScaled = true
				btn.Text = choice.Text
				btn.Parent = choicesFrame
				
				
				btn.MouseButton1Click:Connect(function()
					
					if choice.Action then
						
						tryCloneUI(choice.Action)
						
						waitingForUIToClose = true
						nextLineAfterUI = choice.NextLine
						frame.Visible = false
					else
						
						frame.Visible = false
						onChoiceSelected(choice.NextLine)
					end
					
				end)
				
			end
		end

		-- Fonction principale d'affichage des lignes de dialogue
		showLine = function(lineIndex)
						
			-- Fin du dialogue
			if not lineIndex then
				
				billboard:Destroy()
				choiceGui:Destroy()
				exitGui:Destroy()
				
				-- Detruit le pannel afficher 
				if clonedUI and clonedUI.Parent then
					clonedUI:Destroy()
					clonedUI = nil
				end

				if humanoid then
					humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
				end

				pcall(function()
					proximity.Enabled = true
				end)

				currentCamera.CameraType = Enum.CameraType.Custom
				isInteracting = false

				if LookAtBool then
					LookAtBool.Value = true
				end

				setAllPlayersVisibility(true)
				
				if HidenUi then
					UiHider.RestoreUI(HidenUi)
					HidenUi = {}
				end
				
				PlayerControlManager.Enable()

				return
			end
			

			local line = dialogueLines[lineIndex]
			if not line then
				showLine(nil)
				return
			end

			label.Text = ""
			coroutine.wrap(function()
				for i = 1, #line.Text do
					label.Text = line.Text:sub(1, i)
					task.wait(0.03)
				end
			end)()
			
			-- Affichage Des choix
			if line.Choices and #line.Choices > 0 then
				
				showChoices(line.Choices, function(nextLine)
					clearChoices()
					showLine(nextLine)
				end)
				
			else
				
				local duration = line.Duration or 3

				task.delay(duration, function()
					
					if waitingForUIToClose then
						nextLineAfterUI = line.NextLine
					else
						showLine(line.NextLine)
					end
					
				end)
				
			end
			
		end

		showLine(1)
	end)
end)