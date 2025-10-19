local Players = game:GetService("Players")
local player  = Players.LocalPlayer

local mainUI  = player:WaitForChild("PlayerGui"):WaitForChild("MainUI")

local UiHider = {}
UiHider.__index = UiHider


function UiHider.HideOtherUI(exemptUis)
	
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local hiddenList = {}

	-- Uniformise exemptUis en table
	local exemptMap = {}
	if exemptUis then
		
		if typeof(exemptUis) ~= "table" then
			exemptUis = { exemptUis }
		end
		
		for _, gui in ipairs(exemptUis) do
			exemptMap[gui] = true
		end
	end

	-- Parcours tous les descendants
	for _, inst in ipairs(pg:GetDescendants()) do
		
		if inst:IsA("ScreenGui") and inst.Enabled and not exemptMap[inst] then
			
			if inst.Name == "ToolTipGui" then continue end
			
			inst.Enabled = false
			table.insert(hiddenList, inst)
		end
	end

	return hiddenList
end


function UiHider.RestoreUI(hiddenList)
	
	for _, gui in ipairs(hiddenList or {}) do
		
		if gui and gui.Parent then
			gui.Enabled = true
		end
	end
	
end

return UiHider