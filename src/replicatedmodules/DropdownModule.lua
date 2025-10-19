--!strict
--[[
        DropdownModule
        Contextual dropdown implementation that renders options under an anchor
        button. Handles outside clicks, re-entrant toggles, and safe cleanup.
]]

local UserInputService = game:GetService("UserInputService")

export type DropdownOption = string | number | boolean | { Text: string, Value: any }
export type DropdownConfig = {
        AdorneeGui: GuiBase2d,
        Anchor: GuiButton,
        Options: { DropdownOption },
        Callback: (value: any) -> (),
        Width: number?,
        OptionHeight: number?,
        Offset: Vector2?,
}

local DropdownModule = {}
DropdownModule.__index = DropdownModule

local activeDropdowns: { [DropdownModule]: boolean } = setmetatable({}, { __mode = "k" })
local outsideClickConnection: RBXScriptConnection?

local function optionTuple(option: DropdownOption): (string, any)
        if typeof(option) == "table" then
                local map = option :: { Text: string?, Value: any }
                local text = map.Text or tostring(map.Value)
                return text, map.Value
        end

        return tostring(option), option
end

local function isPointInside(guiObject: GuiBase2d, x: number, y: number): boolean
        local position = guiObject.AbsolutePosition
        local size = guiObject.AbsoluteSize

        return x >= position.X
                and x <= position.X + size.X
                and y >= position.Y
                and y <= position.Y + size.Y
end

local function ensureOutsideClickListener()
        if outsideClickConnection then
                return
        end

        outsideClickConnection = UserInputService.InputBegan:Connect(function(input, processed)
                if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                end

                local position = input.Position
                for dropdown in pairs(activeDropdowns) do
                        local frame = dropdown._frame
                        local anchor = dropdown.Anchor
                        if frame and anchor then
                                if isPointInside(frame, position.X, position.Y)
                                        or isPointInside(anchor, position.X, position.Y)
                                then
                                        return
                                end
                        end
                end

                for dropdown in pairs(activeDropdowns) do
                        dropdown:Hide()
                end
        end)
end

function DropdownModule.new(config: DropdownConfig)
        assert(config.AdorneeGui, "DropdownModule: missing AdorneeGui")
        assert(config.Anchor, "DropdownModule: missing Anchor button")
        assert(config.Options and #config.Options > 0, "DropdownModule: Options list is empty")
        assert(type(config.Callback) == "function", "DropdownModule: Callback must be a function")

        local self = setmetatable({}, DropdownModule)
        self.Gui = config.AdorneeGui
        self.Anchor = config.Anchor
        self.Options = config.Options
        self.Callback = config.Callback
        self.Width = config.Width or 160
        self.OptionHeight = config.OptionHeight or 28
        self.Offset = config.Offset or Vector2.zero

        self:_createDropdown()
        ensureOutsideClickListener()

        return self
end

function DropdownModule:_createDropdown()
        local frame = Instance.new("Frame")
        frame.Name = "DropdownMenu"
        frame.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
        frame.BorderSizePixel = 0
        frame.ClipsDescendants = true
        frame.AutomaticSize = Enum.AutomaticSize.Y
        frame.Size = UDim2.new(0, self.Width, 0, 0)
        frame.ZIndex = (self.Anchor.ZIndex or 1) + 10
        frame.Visible = false
        frame.Parent = self.Gui

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 2)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = frame

        for index, option in ipairs(self.Options) do
                local text, value = optionTuple(option)
                local button = Instance.new("TextButton")
                button.Name = string.format("Option_%s", text)
                button.LayoutOrder = index
                button.Size = UDim2.new(1, 0, 0, self.OptionHeight)
                button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
                button.BorderSizePixel = 0
                button.Font = Enum.Font.Gotham
                button.TextSize = 16
                button.Text = text
                button.TextColor3 = Color3.new(1, 1, 1)
                button.AutoButtonColor = true
                button.ZIndex = frame.ZIndex + 1
                button.Parent = frame

                button.MouseButton1Click:Connect(function()
                        self.Callback(value)
                        self:Hide()
                end)
        end

        self._frame = frame
        self:_bindAnchor()
end

function DropdownModule:_bindAnchor()
        self._anchorConnection = self.Anchor.MouseButton1Click:Connect(function()
                if self:IsOpen() then
                        self:Hide()
                else
                        self:Show()
                end
        end)
end

function DropdownModule:IsOpen(): boolean
        return self._frame ~= nil and self._frame.Visible
end

function DropdownModule:Show()
        local frame = self._frame
        if not frame then
                return
        end

        for dropdown in pairs(activeDropdowns) do
                if dropdown ~= self then
                        dropdown:Hide()
                end
        end

        local anchorPos = self.Anchor.AbsolutePosition
        local anchorSize = self.Anchor.AbsoluteSize
        frame.Position = UDim2.fromOffset(anchorPos.X + self.Offset.X, anchorPos.Y + anchorSize.Y + self.Offset.Y)
        frame.Visible = true
        activeDropdowns[self] = true
end

function DropdownModule:Hide()
        local frame = self._frame
        if frame then
                        frame.Visible = false
        end
        activeDropdowns[self] = nil
end

function DropdownModule:Enable()
        if not self._anchorConnection then
                self:_bindAnchor()
        end
end

function DropdownModule:Disable()
        if self._anchorConnection then
                self._anchorConnection:Disconnect()
                self._anchorConnection = nil
        end
        self:Hide()
end

function DropdownModule:Destroy()
        self:Disable()
        local frame = self._frame
        if frame then
                frame:Destroy()
                self._frame = nil
        end
        activeDropdowns[self] = nil
end

return DropdownModule
