--!strict
--[[
        InteractionHelper
        Utility object that temporarily disables collisions on models or parts
        and restores them on demand. Designed for placement/interaction flows.
]]

local InteractionHelper = {}
InteractionHelper.__index = InteractionHelper

export type InteractionHelper = {
        _disabledParts: { [BasePart]: { CanCollide: boolean, CanQuery: boolean, CanTouch: boolean } },
        DisableCollision: (self: InteractionHelper, part: BasePart) -> (),
        DisableModel: (self: InteractionHelper, model: Instance, excludes: { Instance }?) -> (),
        Restore: (self: InteractionHelper, part: BasePart) -> (),
        RestoreAll: (self: InteractionHelper) -> (),
}

function InteractionHelper.new(): InteractionHelper
        return setmetatable({
                _disabledParts = {},
        }, InteractionHelper)
end

local function isPartDisabled(self: InteractionHelper, part: BasePart): boolean
        return self._disabledParts[part] ~= nil
end

local function storeState(self: InteractionHelper, part: BasePart)
        self._disabledParts[part] = {
                CanCollide = part.CanCollide,
                CanQuery = part.CanQuery,
                CanTouch = part.CanTouch,
        }
end

function InteractionHelper:DisableCollision(part: BasePart)
        if not part or not part:IsA("BasePart") then
                return
        end

        if isPartDisabled(self, part) then
                return
        end

        storeState(self, part)
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
end

local function shouldExclude(part: BasePart, excludes: { Instance }?): boolean
        if not excludes then
                return false
        end

        for _, exclude in ipairs(excludes) do
                if exclude == part then
                        return true
                end

                if exclude:IsA("Model") and part:IsDescendantOf(exclude) then
                        return true
                end
        end

        return false
end

function InteractionHelper:DisableModel(model: Instance, excludes: { Instance }?)
        if not model then
                return
        end

        for _, descendant in ipairs(model:GetDescendants()) do
                if descendant:IsA("BasePart") and not shouldExclude(descendant, excludes) then
                        self:DisableCollision(descendant)
                end
        end
end

function InteractionHelper:Restore(part: BasePart)
        local original = self._disabledParts[part]
        if not original then
                return
        end

        if part and part.Parent then
                part.CanCollide = original.CanCollide
                part.CanQuery = original.CanQuery
                part.CanTouch = original.CanTouch
        end

        self._disabledParts[part] = nil
end

function InteractionHelper:RestoreAll()
        for part, data in pairs(self._disabledParts) do
                if part and part.Parent then
                        part.CanCollide = data.CanCollide
                        part.CanQuery = data.CanQuery
                        part.CanTouch = data.CanTouch
                end
        end

        table.clear(self._disabledParts)
end

return InteractionHelper
