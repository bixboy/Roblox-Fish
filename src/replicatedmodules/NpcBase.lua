--!strict
--[[
        NpcBase
        Minimal helper to trigger dialogue sequences with configured lines.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StartDialogue = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StartDialogue")

export type DialogueLines = { string }

local NpcBase = {}
NpcBase.__index = NpcBase

function NpcBase.new(model: Model, dialogueLines: DialogueLines?): NpcBase
        local self = setmetatable({}, NpcBase)
        self.Model = model
        self.Lines = dialogueLines or {
                "Bonjour étranger.",
                "Tu veux commercer ?",
        }
        return self
end

function NpcBase:TriggerDialogue(player: Player)
        if self.Model and player then
                StartDialogue:FireClient(player, self.Model, self.Lines)
        end
end

return NpcBase
