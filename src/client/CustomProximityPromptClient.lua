local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage      = game:GetService("ReplicatedStorage")
local UserInputService       = game:GetService("UserInputService")
local TweenService           = game:GetService("TweenService")

local Players      = game:GetService("Players")
local localPlayer  = Players.LocalPlayer
local playerGui    = localPlayer:WaitForChild("PlayerGui")

local customPrompt = ReplicatedStorage.UI:WaitForChild("CustomPrompt")
local proximityEnabledRemote  = ReplicatedStorage.Remotes:WaitForChild("SetProximityPromptEnabled")



local GamepadButtonImage = {
	[Enum.KeyCode.ButtonX] = "rbxasset://textures/ui/Controls/xboxX.png",
	[Enum.KeyCode.ButtonY] = "rbxasset://textures/ui/Controls/xboxY.png",
	[Enum.KeyCode.ButtonA] = "rbxasset://textures/ui/Controls/xboxA.png",
	[Enum.KeyCode.ButtonB] = "rbxasset://textures/ui/Controls/xboxB.png",
	[Enum.KeyCode.DPadLeft] = "rbxasset://textures/ui/Controls/dpadLeft.png",
	[Enum.KeyCode.DPadRight] = "rbxasset://textures/ui/Controls/dpadRight.png",
	[Enum.KeyCode.DPadUp] = "rbxasset://textures/ui/Controls/dpadUp.png",
	[Enum.KeyCode.DPadDown] = "rbxasset://textures/ui/Controls/dpadDown.png",
	[Enum.KeyCode.ButtonSelect] = "rbxasset://textures/ui/Controls/xboxmenu.png",
	[Enum.KeyCode.ButtonL1] = "rbxasset://textures/ui/Controls/xboxLS.png",
	[Enum.KeyCode.ButtonR1] = "rbxasset://textures/ui/Controls/xboxRS.png"
}

local KeyBoardButtonImage = {}

local KeyboardButtonIconMapping = {}

local KeyCodeToTextMapping = {}

local promptsEnabled = true


local function getScreenGUi()

	local screenGui = playerGui:FindFirstChild("ProximityPrompts")
	if screenGui == nil then
		
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "ProximityPrompts"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = playerGui
		
	end
	
	return screenGui
end


local function createPrompt(prompt, inputType, gui)
	
	local promptUI = customPrompt:Clone()
	
	local keyLabel = promptUI:FindFirstChild("InputKey", true)
	local keyImage = promptUI:FindFirstChild("ImageKey", true)
	
	local promptLabel = promptUI:FindFirstChild("PromptText", true)
	
	local frame = promptUI:FindFirstChild("Frame")
	local textTable = {keyLabel, promptLabel}
	
	if prompt.ObjectText then
		promptLabel.Text = prompt.ActionText.." "..prompt.ObjectText
	else
		promptLabel.Text = prompt.ActionText
	end
	
	
	-- Key Image / Text
	local function updateUiFromPrompt()
		
		if inputType == Enum.ProximityPromptInputType.Gamepad then
			
			local image = GamepadButtonImage[prompt.GamepadKeyCode]
			if image then
				keyImage.Image = image
				keyImage.Visible = true
				keyLabel.Visible = false
			else
				keyImage.Visible = false
				keyLabel.Visible = false
			end

		elseif inputType == Enum.ProximityPromptInputType.Touch then
			keyImage.Image = "rbxasset://textures/ui/Controls/TouchTapIcon.png"
			keyImage.Visible = true
			keyLabel.Visible = false

		else
			-- PC / Keyboard
			local buttonTextString = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
			local buttonTextImage = KeyBoardButtonImage[prompt.KeyboardKeyCode] or KeyboardButtonIconMapping[buttonTextString]

			if buttonTextImage then
				keyImage.Image = buttonTextImage
				keyImage.Visible = true
				keyLabel.Visible = false

			elseif buttonTextString and buttonTextString ~= "" then
				keyLabel.Text = buttonTextString
				keyLabel.Visible = true
				keyImage.Visible = false

			else
				warn("Unsupported KeyboardKeyCode: " .. tostring(prompt.KeyboardKeyCode))
				keyLabel.Visible = false
				keyImage.Visible = false
			end
		end
	end
	
	
	-- Fade In / Fade Out
	local tweensForFadeOut = {}
	local tweensForFadeIn = {}
	local tweenInfoFast = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	-- Fade text (keyLabel)
	for _, object in ipairs(textTable) do
		table.insert(tweensForFadeOut, TweenService:Create(object, tweenInfoFast, { TextTransparency = 1 }))
		table.insert(tweensForFadeIn, TweenService:Create(object, tweenInfoFast, { TextTransparency = 0 }))
		
	end
	
	table.insert(tweensForFadeOut, TweenService:Create(keyImage, tweenInfoFast, { ImageTransparency = 1 }))
	table.insert(tweensForFadeIn, TweenService:Create(keyImage, tweenInfoFast, { ImageTransparency = 0 }))

	-- Fade frame background
	table.insert(tweensForFadeOut, TweenService:Create(frame, tweenInfoFast, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0, 1)
	}))
	table.insert(tweensForFadeIn, TweenService:Create(frame, tweenInfoFast, {
		BackgroundTransparency = 0.5,
		Size = UDim2.fromScale(1, 1)
	}))

	
	-- Made Prompt work on mobile / clickable
	if inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt then
		
		local button = Instance.new("TextButton")
		button.BackgroundTransparency = 1
		button.TextTransparency = 1
		button.Size = UDim2.new(1, 1)
		button.Parent = promptUI
		
		local buttonDown = false
		
		button.InputBegan:Connect(function(input)
		
			if (input.UserInputType == Enum.UserInputType.Touch or inputType.UserInputType == Enum.UserInputType.MouseButton1) and 
				input.UserInputType ~= Enum.UserInputState.Change then
				
				prompt:InputHoldBegin()
				buttonDown = true
				
			end
			
		end)
		
		
		button.InputEnded:Connect(function(input)
			
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1  then
				
				if buttonDown then
					
					buttonDown = false
					prompt:InputHoldEnd()
				end
				
			end
			
		end)
		
		promptUI.Active = true
	end
	
	
	local triggerConnection
	local triggerEndedConnection
	
	triggerConnection = prompt.Triggered:Connect(function()
		if not promptsEnabled then return end
				
		for _, tween in ipairs(tweensForFadeOut) do
			tween:Play()
		end
	end)
	
	triggerEndedConnection = prompt.TriggerEnded:Connect(function()
		if not promptsEnabled then return end
		
		for _, tween in ipairs(tweensForFadeIn) do
			tween:Play()
		end
	end)
	
	
	promptUI.Adornee = prompt.Parent
	promptUI.Parent = gui
	
	updateUiFromPrompt()
	
	for _, tween in ipairs(tweensForFadeIn) do
		
		tween:Play()
	end
	
	
	local function cleanupFunction()
		
		triggerConnection:Disconnect()
		triggerEndedConnection:Disconnect()
		
		for _, tween in ipairs(tweensForFadeOut) do
			
			tween:Play()
		end
		
		wait(0.2)
		
		promptUI.Parent = nil
	end
	
	
	return cleanupFunction
end

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	
	if prompt.Style == Enum.ProximityPromptStyle.Default then return end
	if not promptsEnabled then return end
	
	local player = Players.LocalPlayer
	if prompt:GetAttribute("DisabledForTarget") == player.UserId then
		return
	end
	
	local gui = getScreenGUi()
	
	local cleanupFunction = createPrompt(prompt, inputType, gui)
	prompt.PromptHidden:Wait()
	
	cleanupFunction()
	
end)



proximityEnabledRemote.OnClientEvent:Connect(function(enabled)
	
	promptsEnabled = enabled
	ProximityPromptService.Enabled = promptsEnabled
	
end)