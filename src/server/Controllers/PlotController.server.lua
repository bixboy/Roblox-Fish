-- ServerScriptService/Controllers/PlotController.server.lua
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotManager     = require(game.ServerStorage.Modules:WaitForChild("PlotManager"))
local SupportManager  = require(game.ServerStorage.Modules:WaitForChild("SupportManager"))
local AquariumData    = require(game.ServerStorage.Data:WaitForChild("AquariumData"))

local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local Remotes      = ReplicatedStorage:WaitForChild("Remotes")

local PROMPT_CONFIG = {
        ActionText            = "Revendiquer",
        ObjectText            = "Terrain",
        HoldDuration          = 0.5,
        MaxActivationDistance = 10,
}

local ZERO_VECTOR = Vector3.new()
local ZERO_ANGLES = { 0, 0, 0 }

local function toVector3(values)
        if typeof(values) == "table" then
                return Vector3.new(values[1] or 0, values[2] or 0, values[3] or 0)
        end

        return ZERO_VECTOR
end

local function toAngles(values)
        if typeof(values) == "table" then
                return values[1] or 0, values[2] or 0, values[3] or 0
        end

        return ZERO_ANGLES[1], ZERO_ANGLES[2], ZERO_ANGLES[3]
end

local function findTemplate(path)
        if typeof(path) ~= "string" or path == "" then
                return nil
        end

        local current = AssetsFolder
        for segment in string.gmatch(path, "[^%.]+") do
                current = current and current:FindFirstChild(segment)
                if not current then
                        return AssetsFolder:FindFirstChild(path, true)
                end
        end

        return current
end

local function applyCFrame(instance, cf)
        if instance:IsA("Model") then
                instance:PivotTo(cf)
        elseif instance:IsA("BasePart") then
                instance.CFrame = cf
        end
end

local function reloadAquarium(player, supportInstance, aquariumInfo)
        if not aquariumInfo then
                return
        end

        local aquariumName = aquariumInfo.Path
        if not aquariumName or AquariumData.Templates[aquariumName] == nil then
                warn(("[PlotController] Aquarium template introuvable: %s"):format(tostring(aquariumName)))
                return
        end

        SupportManager:ReloadAquarium(
                player,
                supportInstance,
                aquariumName,
                aquariumInfo.Fish or {},
                aquariumInfo.Eggs or {},
                aquariumInfo.Furniture or {}
        )
end

local function reloadObject(player, plotPart, info)
        local template = findTemplate(info.Path)
        if not template then
                warn(("[PlotController] Template introuvable au reload: %s"):format(tostring(info.Path)))
                return
        end

        local clone = template:Clone()
        clone.Parent = plotPart
        clone:SetAttribute("TemplatePath", info.Path)
        clone:SetAttribute("ObjectId", info.Id)
        clone:AddTag("Object")

        PlotManager:RegisterObjectOwner(player, clone)

        local offset = toVector3(info.Offset)
        local ax, ay, az = toAngles(info.Angles)
        local cf = CFrame.new(plotPart.Position + offset) * CFrame.Angles(ax, ay, az)
        applyCFrame(clone, cf)

        if CollectionService:HasTag(clone, "Support") then
                SupportManager:InitSupport(clone)
                reloadAquarium(player, clone, info.Aquarium)
        end
end

local function onPromptTriggered(player, plotPart)
        local ok, err = PlotManager:ClaimPlot(player, plotPart)
        if not ok then
                warn(("%s n'a pas pu revendiquer %s : %s"):format(player.Name, plotPart.Name, err))
                return
        end

        for _, info in ipairs(PlotManager:GetObjects(player)) do
                reloadObject(player, plotPart, info)
        end
end

local function bindPrompt(plotPart)
        local promptParent = plotPart:FindFirstChild("PromptPart") or plotPart
        local prompt = promptParent:FindFirstChildOfClass("ProximityPrompt")
        if not prompt then
                prompt = Instance.new("ProximityPrompt")
                prompt.Parent = promptParent
        end

        prompt.ActionText            = PROMPT_CONFIG.ActionText
        prompt.ObjectText            = PROMPT_CONFIG.ObjectText
        prompt.HoldDuration          = PROMPT_CONFIG.HoldDuration
        prompt.MaxActivationDistance = PROMPT_CONFIG.MaxActivationDistance

        if not prompt:GetAttribute("__PlotBound") then
                prompt:SetAttribute("__PlotBound", true)
                prompt.Triggered:Connect(function(player)
                        onPromptTriggered(player, plotPart)
                end)
        end
end

for _, plotPart in ipairs(CollectionService:GetTagged("Plot")) do
        bindPrompt(plotPart)
end

CollectionService:GetInstanceAddedSignal("Plot"):Connect(bindPrompt)

local IsMyPlotRF = Remotes:WaitForChild("IsMyPlotAt")
IsMyPlotRF.OnServerInvoke = function(player, worldPos)
        return PlotManager:PlayerOwnsPlotAt(player, worldPos)
end
