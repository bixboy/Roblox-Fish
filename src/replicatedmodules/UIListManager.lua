-- UIListManager.lua
local UIListManager = {}

-- Garde les connexions actives pour chaque frame
local activeConnections = {}

-- Nettoie les anciennes connexions
local function disconnectConnections(uiFrame)
	
	if activeConnections[uiFrame] then
		for _, conn in ipairs(activeConnections[uiFrame]) do
			conn:Disconnect()
		end
	end
	
	activeConnections[uiFrame] = {}
end

-- Ajoute une connexion traquee
local function track(uiFrame, conn)
	table.insert(activeConnections[uiFrame], conn)
	return conn
end

-- Supprime tous les anciens items
local function clearList(listContainer, template)
	for _, child in ipairs(listContainer:GetChildren()) do
		if child:IsA("GuiObject") and child ~= template then
			child:Destroy()
		end
	end
end

-- Fonction utilitaire pour stacker
local function isGuid(str)
	
	if type(str) ~= "string" then return false end

	str = str:match("^%s*(.-)%s*$")
	if #str >= 2 and str:sub(1,1) == "{" and str:sub(-1) == "}" then
		str = str:sub(2, -2) end

	if str:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
		return true
	end

	if #str == 32 and str:match("^%x+$") then
		return true
	end

	return false
end

local function stackItems(items)
	
	local stacked = {}
	local lookup  = {}
	
	for _, v in ipairs(items) do
		
		if v.Id and isGuid(v.Id) then
			local new = table.clone(v)
			new.Count = 1
			table.insert(stacked, new)
			
		else
			
			local key = v.Id or v.Text or v.Name or tostring(v)
			if lookup[key] then
				lookup[key].Count = lookup[key].Count + 1
			else
				local new = table.clone(v)
				new.Count = 1
				
				table.insert(stacked, new)
				lookup[key] = new
			end
		end
	end

	return stacked
end

-- ================================
-- Public API
-- ================================
function UIListManager.SetupList(params)
	local uiFrame        = params.UiFrame
	local template       = params.Template
	local closeButton    = params.CloseButton
	local getItems       = params.GetItems        or function() return {} end
	local onItemClick    = params.OnItemClick     or function() end
	local onClose        = params.OnClose         or function() end
	local renderItem     = params.RenderItem
	local autoClose      = params.AutoClose ~= false
	local colorButton    = params.ColorButton
	local listContainer  = params.ListContainer or template.Parent
	local stackEnabled   = params.StackItems

	assert(uiFrame and template and closeButton, "[UIListManager] param�tres invalides")

	-- Reset
	disconnectConnections(uiFrame)
	clearList(listContainer, template)
	template.Visible = false
	
	if uiFrame:IsA("Frame") then 
		
		uiFrame.Visible  = true 
	
	elseif uiFrame:IsA("ScreenGui") then
		
		uiFrame.Enabled = true
	end

	-- Bouton de fermeture
	track(uiFrame, closeButton.MouseButton1Click:Connect(function()

		if uiFrame:IsA("Frame") then 

			uiFrame.Visible  = false 

		elseif uiFrame:IsA("ScreenGui") then

			uiFrame.Enabled = false
		end
		onClose()
	end))
	
	local items = getItems()
	if stackEnabled then
		items = stackItems(items)
	end
	
	-- Creation des items
	for _, itemData in ipairs(items) do
		
		local button = template:Clone()
		button.Visible = true
		button.Parent  = listContainer

		if colorButton then
			button.BackgroundColor3 = colorButton
		end

		-- Rendu custom ou fallback
		if renderItem then
			renderItem(button, itemData)
		else
			
			if button:IsA("TextButton") or button:IsA("TextLabel") then
				
				local txt = itemData.Text or itemData.Name or tostring(itemData.Id) or "Item"
				if stackEnabled and itemData.Count and itemData.Count > 1 then
					
					button.Text = ("%s x%d"):format(txt, itemData.Count)
				else
					button.Text = itemData.Text or "Item"
				end
			else
				
				local label = button:FindFirstChild("NameLabel") or button:FindFirstChildWhichIsA("TextLabel")
				if label then
					
					local txt = itemData.Text or itemData.Name or tostring(itemData.Id) or "Item"
					if stackEnabled and itemData.Count and itemData.Count > 1 then
						
						label.Text = ("%s x%d"):format(txt, itemData.Count)
					else
						label.Text = txt
					end
				end
			end
		end

		-- Clic sur l'item
		track(uiFrame, button.MouseButton1Click:Connect(function()
			
			onItemClick(itemData)
			
			if autoClose then

				if uiFrame:IsA("Frame") then 

					uiFrame.Visible  = false 

				elseif uiFrame:IsA("ScreenGui") then

					uiFrame.Enabled = false
				end
				onClose()
			end
		end))
	end
end

return UIListManager