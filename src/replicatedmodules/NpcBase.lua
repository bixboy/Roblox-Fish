local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StartDialogue = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StartDialogue")

local NpcBase = {}
NpcBase.__index = NpcBase

function NpcBase.new(model, dialogueLines)
	
	local self = setmetatable({}, NpcBase)
	
	self.Model = model
	self.Lines = dialogueLines or {
		"Bonjour etranger.",
		"Tu veux commercer ?"
	}
	
	return self
	
end

function NpcBase:TriggerDialogue(player)
	
	if self.Model and player then
		StartDialogue:FireClient(player, self.Model, self.Lines)
	end
	
end

return NpcBase