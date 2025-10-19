-- ReplicatedStorage.Modules.TooltipModule
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Reference du prefab de tooltip dans ReplicatedStorage
local tooltipPrefab = ReplicatedStorage.UI:WaitForChild("ToolTipGui")

local Tooltip = {}
Tooltip.__index = Tooltip

-- Animation settings
local SLIDE_TIME = 0.2
local FADE_TIME  = 0.2
local PADDING    = 8

function Tooltip.new()
	local self = setmetatable({}, Tooltip)

	-- Clone dans le PlayerGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = tooltipPrefab:Clone()
	gui.Name = "TooltipRuntime"
	gui.Parent = playerGui

	self.UI         = gui
	self.Frame      = gui:WaitForChild("Background")
	self.Buttons    = self.Frame:WaitForChild("ButtonsFrame")
	self.Template   = self.Buttons:WaitForChild("ButtonTemplate")

	self.IsVisible  = false
	self._inputConn = nil	

	self:HideImmediate()
	return self
end

-- Immediately hide without animation
function Tooltip:HideImmediate()
	self.UI.Enabled = false
	self.IsVisible = false

	if self._inputConn then
		self._inputConn:Disconnect()
		self._inputConn = nil
	end

	-- cleanup
	for _, child in ipairs(self.Buttons:GetChildren()) do
		if child:IsA("GuiObject") and child ~= self.Template then
			child:Destroy()
		end
	end
end

function Tooltip:_onGlobalClick(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		self:Hide()
	end
end

-- Show
function Tooltip:Show(config)
	if not (config and config.Position and config.Buttons) then 
		return 
	end

	-- cleanup
	for _, child in ipairs(self.Buttons:GetChildren()) do
		if child:IsA("GuiObject") and child ~= self.Template then
			child:Destroy()
		end
	end

	-- create buttons
	local totalHeight = 0
	for i, btnData in ipairs(config.Buttons) do
		local btn = self.Template:Clone()
		btn.Visible  = true
		btn.Parent   = self.Buttons
		btn.Position = UDim2.new(0, 0, 0, (i-1) * (btn.Size.Y.Offset + PADDING))

		btn.Active = true
		btn.Selectable = true
		btn.AutoButtonColor = true
		btn.TextTransparency = 1

		if config.Render then
			config.Render(btn, btnData)
		else
			btn.Text = btnData.Text or "?"
		end

		btn.MouseButton1Click:Connect(function()
			pcall(btnData.Callback, btnData)
			self:Hide()
		end)

		if not self._inputConn then
			self._inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
				self:_onGlobalClick(input, gameProcessed)
			end)
		end

		totalHeight = totalHeight + btn.Size.Y.Offset + PADDING
	end

	local padding_total = PADDING * 2
	self.Frame.Size     = UDim2.new(0, self.Frame.Size.X.Offset, 0, totalHeight + padding_total)

	local pos = config.Position
	local startPos = UDim2.fromOffset(pos.X, pos.Y - (totalHeight + padding_total))
	local endPos   = UDim2.fromOffset(pos.X, pos.Y)

	self.Frame.Position = startPos
	self.UI.Enabled     = true
	self.IsVisible      = true

	self.Frame.ZIndex = 50
	for _, b in ipairs(self.Buttons:GetChildren()) do
		if b:IsA("GuiObject") then
			b.ZIndex = 51
		end
	end

	TweenService:Create(self.Frame, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quad), {Position = endPos}):Play()
	for _, btn in ipairs(self.Buttons:GetChildren()) do
		if btn:IsA("TextButton") then
			TweenService:Create(btn, TweenInfo.new(FADE_TIME), {TextTransparency = 0}):Play()
		end
	end
end

-- Hide with slide-up and fade-out
function Tooltip:Hide()
	if not self.IsVisible then return end

	self.IsVisible   = false
	local currentPos = self.Frame.Position
	local upPos      = UDim2.new(
		currentPos.X.Scale, currentPos.X.Offset,
		currentPos.Y.Scale, currentPos.Y.Offset - self.Frame.Size.Y.Offset
	)

	if self._inputConn then
		self._inputConn:Disconnect()
		self._inputConn = nil
	end

	TweenService:Create(self.Frame, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quad), {Position = upPos}):Play()

	for _, btn in ipairs(self.Buttons:GetChildren()) do
		if btn:IsA("TextButton") then
			TweenService:Create(btn, TweenInfo.new(FADE_TIME), {TextTransparency = 1}):Play()
		end
	end

	delay(math.max(SLIDE_TIME, FADE_TIME), function()
		self.UI.Enabled = false
	end)
end

return Tooltip.new()