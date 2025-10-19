-- module InteractionHelper.lua
local InteractionHelper = {}
InteractionHelper.__index = InteractionHelper

function InteractionHelper.new()
	
	local self = setmetatable({
		_disabledParts = {}
	}, InteractionHelper)
	
	return self
end

-- Desactive la collision
function InteractionHelper:disableCollision(part)
	
	if not part:IsA("BasePart") then return end
	if self._disabledParts[part] then return end
	
	-- Sauvegarde
	self._disabledParts[part] = {
		oldCanCollide = part.CanCollide,
		oldCanQuery   = part.CanQuery,
	}
	
	-- Desactivation
	part.CanCollide = false
	part.CanQuery   = false
end
-- Applique disableCollision
function InteractionHelper:disableModel(model, excludes)
	
	excludes = excludes or {}

	for _, part in ipairs(model:GetDescendants()) do
		
		if not part:IsA("BasePart") then
			continue
		end

		local skip = false
		for _, ex in ipairs(excludes) do
			
			if ex:IsA("Model") then
				
				if part:IsDescendantOf(ex) then
					skip = true
					break
				end
				
			elseif ex:IsA("BasePart") then
				
				if part == ex then
					skip = true
					break
				end
				
			end
			
		end

		if not skip then
			self:disableCollision(part)
		end
	end
	
end

-- Restaure TOUS les parts qu'on a desactives
function InteractionHelper:restoreAll()
	
	for part, data in pairs(self._disabledParts) do
		
		if part and part.Parent then
			
			part.CanCollide = data.oldCanCollide
			part.CanQuery   = data.oldCanQuery
		end
	end
	
	-- vider la table
	self._disabledParts = {}
end

return InteractionHelper