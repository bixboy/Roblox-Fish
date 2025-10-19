-- AquariumTemplates.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local folder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Aquariums")


local function safeGet(name)
	
	local success, value = pcall(function()
		return folder:WaitForChild(name)
	end)
	
	if not success or not value then
		warn("[AquariumTemplates] Missing template:", name)
	end
	
	return value
end

local Templates = {
	SmallAquarium      = safeGet("SmallAquarium"),
	SmallMocheAquarium = safeGet("SmallMocheAquarium"),
}

local Data = {
	
	SmallAquarium = {
		FriendlyName  = "Petit Aquarium",
		MaxFish       = 1,
		MaxFurnitures = 2,
		Size          = "Small",
		Template      = Templates.SmallAquarium,
	},

	SmallMocheAquarium = {
		FriendlyName  = "Petit Aquarium Moche",
		MaxFish       = 1,
		MaxFurnitures = 2,
		Size          = "Small",
		Template      = Templates.SmallMocheAquarium
	},
}

return {
	Templates = Templates,
	Data      = Data,
}