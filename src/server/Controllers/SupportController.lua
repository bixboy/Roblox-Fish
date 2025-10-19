-- SupportController.lua
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SupportManager = require(game.ServerStorage.Modules.SupportManager)

CollectionService:GetInstanceAddedSignal("Support"):Connect(function(supportModel)
	
	-- SupportManager:InitSupport(supportModel)
end)