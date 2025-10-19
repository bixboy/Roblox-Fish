--!strict
--[[
        ModularTooltip
        Runtime tooltip/quick action panel used by multiple systems. Provides a
        reusable class with slide/fade animations and safe cleanup.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type TooltipButton = {
        Text: string?,
        Callback: ((buttonData: TooltipButton) -> ())?,
}

export type TooltipConfig = {
        Position: Vector2,
        Buttons: { TooltipButton },
        Render: ((button: TextButton, buttonData: TooltipButton) -> ())?,
}

export type TooltipClass = {
        Hide: (self: TooltipClass) -> (),
        HideImmediate: (self: TooltipClass) -> (),
        Show: (self: TooltipClass, config: TooltipConfig) -> (),
        Destroy: (self: TooltipClass) -> (),
        IsVisible: (self: TooltipClass) -> boolean,
}

local TOOLTIP_PREFAB = ReplicatedStorage.UI:WaitForChild("ToolTipGui")
local SLIDE_TIME = 0.2
local FADE_TIME = 0.2
local BUTTON_PADDING = 6

local Tooltip = {}
Tooltip.__index = Tooltip

function Tooltip.new(playerGui: PlayerGui?): TooltipClass
        local guiParent = playerGui or Players.LocalPlayer:WaitForChild("PlayerGui")

        local self = setmetatable({
                _gui = TOOLTIP_PREFAB:Clone(),
                _buttonsFrame = nil :: Frame?,
                _template = nil :: TextButton?,
                _inputConnection = nil :: RBXScriptConnection?,
                _visible = false,
        }, Tooltip)

        self._gui.Name = "Tooltip"
        self._gui.ResetOnSpawn = false
        self._gui.Parent = guiParent

        local background = self._gui:WaitForChild("Background") :: Frame
        local buttons = background:WaitForChild("ButtonsFrame") :: Frame
        local template = buttons:WaitForChild("ButtonTemplate") :: TextButton

        self._background = background
        self._buttonsFrame = buttons
        self._template = template

        self:HideImmediate()

        return self
end

local function clearButtons(self: TooltipClass)
        local buttons = assert(self._buttonsFrame, "Tooltip missing buttons frame")
        local template = assert(self._template, "Tooltip missing template")

        for _, child in ipairs(buttons:GetChildren()) do
                if child:IsA("GuiObject") and child ~= template then
                        child:Destroy()
                end
        end
end

function Tooltip:HideImmediate()
        clearButtons(self)
        self._gui.Enabled = false
        self._visible = false
        if self._inputConnection then
                self._inputConnection:Disconnect()
                self._inputConnection = nil
        end
end

function Tooltip:IsVisible(): boolean
        return self._visible
end

function Tooltip:Show(config: TooltipConfig)
        assert(config.Position, "Tooltip.Show requires Position")
        assert(config.Buttons and #config.Buttons > 0, "Tooltip.Show requires at least one button")

        clearButtons(self)

        local buttonsFrame = assert(self._buttonsFrame, "Tooltip missing buttons frame")
        local template = assert(self._template, "Tooltip missing template")
        local background = assert(self._background, "Tooltip missing background")

        local totalHeight = 0
        for index, buttonData in ipairs(config.Buttons) do
                local button = template:Clone()
                button.Visible = true
                button.Parent = buttonsFrame
                button.ZIndex = background.ZIndex + 1
                button.TextTransparency = 1
                button.BackgroundTransparency = 1

                if config.Render then
                        config.Render(button, buttonData)
                else
                        button.Text = buttonData.Text or "?"
                end

                button.MouseButton1Click:Connect(function()
                        if buttonData.Callback then
                                task.spawn(buttonData.Callback, buttonData)
                        end
                        self:Hide()
                end)

                button.Position = UDim2.fromOffset(0, totalHeight)
                totalHeight += button.Size.Y.Offset + BUTTON_PADDING
        end

        background.Size = UDim2.new(0, background.Size.X.Offset, 0, totalHeight + BUTTON_PADDING * 2)

        local start = UDim2.fromOffset(config.Position.X, config.Position.Y - background.Size.Y.Offset)
        local finish = UDim2.fromOffset(config.Position.X, config.Position.Y)

        background.Position = start
        self._gui.Enabled = true
        self._visible = true

        background.ZIndex = 100
        for _, child in ipairs(buttonsFrame:GetChildren()) do
                if child:IsA("GuiObject") then
                        child.ZIndex = 101
                end
        end

        TweenService:Create(background, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = finish,
        }):Play()

        for _, child in ipairs(buttonsFrame:GetChildren()) do
                if child:IsA("TextButton") then
                        TweenService:Create(child, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                TextTransparency = 0,
                                BackgroundTransparency = 0,
                        }):Play()
                end
        end

        if not self._inputConnection then
                self._inputConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
                        if gameProcessed then
                                return
                        end

                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                self:Hide()
                        end
                end)
        end
end

function Tooltip:Hide()
        if not self._visible then
                return
        end

        self._visible = false

        if self._inputConnection then
                self._inputConnection:Disconnect()
                self._inputConnection = nil
        end

        local background = assert(self._background, "Tooltip missing background")
        local buttonsFrame = assert(self._buttonsFrame, "Tooltip missing buttons frame")
        local upPosition = background.Position - UDim2.fromOffset(0, background.Size.Y.Offset)

        TweenService:Create(background, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = upPosition,
        }):Play()

        for _, child in ipairs(buttonsFrame:GetChildren()) do
                if child:IsA("TextButton") then
                        TweenService:Create(child, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                                TextTransparency = 1,
                                BackgroundTransparency = 1,
                        }):Play()
                end
        end

        task.delay(math.max(SLIDE_TIME, FADE_TIME), function()
                if not self._visible then
                        self._gui.Enabled = false
                        clearButtons(self)
                end
        end)
end

function Tooltip:Destroy()
        self:HideImmediate()
        self._gui:Destroy()
        self._buttonsFrame = nil
        self._template = nil
        self._background = nil
end

local defaultInstance: TooltipClass?

local Module = {}
Module.__index = Module

function Module.new(playerGui: PlayerGui?): TooltipClass
        return Tooltip.new(playerGui)
end

function Module.get(): TooltipClass
        defaultInstance = defaultInstance or Tooltip.new(nil)
        return defaultInstance
end

return setmetatable(Module, {
        __index = function(_, key)
                return Module.get()[key]
        end,

        __call = function(_, ...)
                return Module.new(...)
        end,
})
