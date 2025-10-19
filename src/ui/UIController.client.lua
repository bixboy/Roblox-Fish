local MainGui = script.Parent

-- On va stocker tous les GUIs ici
local guiList = {}

-- Fonction recursive pour trouver tous les ScreenGuis dans des Folders
local function scanForGUIs(container)
	
	for _, obj in pairs(container:GetChildren()) do
		
		if obj:IsA("ScreenGui") then
			
			guiList[obj.Name] = {
				gui = obj,
				openFunc = nil,
			}

			for _, child in pairs(obj:GetChildren()) do
				if child:IsA("ModuleScript") then
					
					local ok, module = pcall(require, child)
					
					if ok and type(module.Open) == "function" then
						guiList[obj.Name].openFunc = module.Open
					end
				end
			end

		elseif obj:IsA("Folder") and obj.Name ~= "DebugUI" then
			scanForGUIs(obj)
		end
	end
end

-- Ferme tous les GUIs
local function closeAllGUIs()
	
	for _, data in pairs(guiList) do
		data.gui.Enabled = false
	end
end

-- Ouvre un GUI en fermant les autres
local function openGUI(guiName)
	
	local data = guiList[guiName]
	if not data then return end

	closeAllGUIs()
	data.gui.Enabled = true

	if data.openFunc then
		pcall(data.openFunc)
	end
end

-- Demarrage
scanForGUIs(MainGui)

local buttonsFrame = MainGui:WaitForChild("buttonsFrame")
for _, button in ipairs(buttonsFrame:GetChildren()) do
	
	if button:IsA("ImageButton") and button.Name:match("^Open.+Button$") then
		
		local guiName = button.Name:match("^Open(.+)Button$")
		if guiList[guiName] then
			
			button.MouseButton1Click:Connect(function()
				
				if guiList[guiName].gui.Enabled then
					guiList[guiName].gui.Enabled = false
				else
					openGUI(guiName)
				end
				
			end)
			
		end
	end
end

closeAllGUIs()