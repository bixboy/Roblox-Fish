--!strict
--[[
        UiHider
        Helper that temporarily hides ScreenGuis except for a whitelist and
        allows restoring them later.
]]

local Players = game:GetService("Players")

export type HiddenGuiList = { ScreenGui }

local UiHider = {}
UiHider.__index = UiHider

local function toMap(exempt: { Instance }): { [Instance]: boolean }
        local map: { [Instance]: boolean } = {}
        for _, instance in ipairs(exempt) do
                map[instance] = true
        end
        return map
end

local function ensureTable(value: any?): { Instance }
        if not value then
                return {}
        end

        if typeof(value) == "table" then
                return value :: { Instance }
        end

        return { value :: Instance }
end

function UiHider.Hide(exempt: { Instance }?): HiddenGuiList
        local player = Players.LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui")
        local exemptMap = toMap(ensureTable(exempt))
        local hidden: HiddenGuiList = {}

        for _, descendant in ipairs(playerGui:GetDescendants()) do
                if descendant:IsA("ScreenGui") and descendant.Enabled and not exemptMap[descendant] then
                        if descendant.Name ~= "ToolTipGui" then
                                descendant.Enabled = false
                                table.insert(hidden, descendant)
                        end
                end
        end

        return hidden
end

function UiHider.Restore(hidden: HiddenGuiList?)
        if not hidden then
                return
        end

        for _, gui in ipairs(hidden) do
                if gui and gui.Parent then
                        gui.Enabled = true
                end
        end
end

-- Backwards compatibility with legacy API names
UiHider.HideOtherUI = UiHider.Hide
UiHider.RestoreUI = UiHider.Restore

return UiHider
