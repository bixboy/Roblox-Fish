local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local DropdownModule = {}
DropdownModule.__index = DropdownModule

-- Registry global des dropdowns ouverts
local OpenDropdowns = setmetatable({}, { __mode = "k" })
local GlobalOutsideConn = nil

-- Ferme tous les dropdowns sauf "except"
local function closeAll(except)
	
	for inst in pairs(OpenDropdowns) do
		if inst ~= except then
			inst:Hide()
		end
	end
end

-- Verifie si un point (x,y) est dans un GuiObject
local function isInside(guiObject, x, y)
	
	if not guiObject or not guiObject:IsA("GuiObject") then
		return false end
	
	local absPos = guiObject.AbsolutePosition
	local absSize = guiObject.AbsoluteSize
	
	return (x >= absPos.X and x <= absPos.X + absSize.X
		and y >= absPos.Y and y <= absPos.Y + absSize.Y)
end

-- Ajoute un ecouteur global unique pour fermer au clic hors dropdown
local function ensureGlobalOutsideListener()
	if GlobalOutsideConn then return end

	GlobalOutsideConn = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

		local x, y = input.Position.X, input.Position.Y
		local hitOpen = false

		for inst in pairs(OpenDropdowns) do
			if isInside(inst.Frame, x, y) or isInside(inst.Anchor, x, y) then
				hitOpen = true
				break
			end
		end

		if not hitOpen then
			closeAll(nil) -- ferme tout
		end
	end)
end

-- ================= API =================

function DropdownModule.new(config)
	assert(config.AdorneeGui, "AdorneeGui obligatoire")
	assert(config.Anchor, "Anchor obligatoire")
	assert(config.Options and #config.Options > 0, "Options requises")
	assert(type(config.Callback) == "function", "Callback obligatoire")

	local self = setmetatable({}, DropdownModule)
	self.Gui          = config.AdorneeGui
	self.Anchor       = config.Anchor
	self.Options      = config.Options
	self.Callback     = config.Callback
	self.Width        = config.Width or 120
	self.OptionHeight = config.OptionHeight or 30
	self.Offset       = config.Offset or Vector2.new(0, 0)

	self:_buildDropdown()
	ensureGlobalOutsideListener()

	return self
end

function DropdownModule:_buildDropdown()
	local frame = Instance.new("Frame")
	frame.Name = "DropdownMenu"
	frame.Size = UDim2.new(0, self.Width, 0, 0)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.ZIndex = (self.Anchor.ZIndex or 1) + 10
	frame.Visible = false
	frame.Parent = self.Gui
	self.Frame = frame

	-- Layout
	local layout = Instance.new("UIListLayout")
	layout.Parent = frame
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)

	-- Options
	for i, opt in ipairs(self.Options) do
		
		local text, value = tostring(opt), opt
		if type(opt) == "table" then
			text  = opt.Text or tostring(opt.Value)
			value = opt.Value
		end

		local btn = Instance.new("TextButton")
		btn.Name = "Option_" .. text
		btn.Size = UDim2.new(1, 0, 0, self.OptionHeight)
		btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 18
		btn.Text = text
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.LayoutOrder = i
		btn.Parent = frame

		btn.MouseButton1Click:Connect(function()
			self.Callback(value)
			self:Hide()
		end)
	end

	-- Ajuste la hauteur totale
	local count = #self.Options
	local totalHeight = count * self.OptionHeight + math.max(0, count - 1) * layout.Padding.Offset
	frame.Size = UDim2.new(0, self.Width, 0, totalHeight)

	-- Toggle via l'ancre
	self.Connection = self.Anchor.MouseButton1Click:Connect(function()
		if frame.Visible then
			self:Hide()
		else
			self:Show()
		end
	end)
end

function DropdownModule:Show()
	closeAll(self)

	local anchorPos  = self.Anchor.AbsolutePosition
	local anchorSize = self.Anchor.AbsoluteSize

	-- Place le menu juste sous l'ancre
	local x = anchorPos.X + self.Offset.X
	local y = anchorPos.Y + anchorSize.Y + self.Offset.Y

	self.Frame.Position = UDim2.fromOffset(x, y)
	self.Frame.Visible = true
	OpenDropdowns[self] = true
end

function DropdownModule:Hide()
	if self.Frame then
		self.Frame.Visible = false
	end
	OpenDropdowns[self] = nil
end

function DropdownModule:Enable()
	if not self.Connection then
		self.Connection = self.Anchor.MouseButton1Click:Connect(function()
			if self.Frame.Visible then
				self:Hide()
			else
				self:Show()
			end
		end)
	end
end

function DropdownModule:Disable()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	self:Hide()
end

function DropdownModule:Destroy()
	self:Disable()
	if self.Frame then
		self.Frame:Destroy()
		self.Frame = nil
	end
end

return DropdownModule