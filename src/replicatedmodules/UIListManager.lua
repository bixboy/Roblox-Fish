--!strict
--[[
	UIListManager
	Declarative helper for rendering lists of buttons/items inside scrolling
	frames. Handles connection cleanup, stacking, custom rendering, and
	auto-closing logic for modal panels.
]]

local UIListManager = {}

export type RenderParams = {
	UiFrame: GuiObject | ScreenGui,
	Template: GuiObject,
	CloseButton: GuiButton,
	ListContainer: Instance?,
	GetItems: (() -> { any })?,
	OnItemClick: ((itemData: any) -> ())?,
	OnClose: (() -> ())?,
	RenderItem: ((button: GuiObject, itemData: any) -> ())?,
	AutoClose: boolean?,
	ColorButton: Color3?,
	StackItems: boolean?,
}

local trackedConnections: { [Instance]: { RBXScriptConnection } } = {}

--#region Utility

local function ensureConnectionBucket(container: Instance)
	if not trackedConnections[container] then
		trackedConnections[container] = {}
	end
end

local function bind(container: Instance, connection: RBXScriptConnection)
	ensureConnectionBucket(container)
	table.insert(trackedConnections[container], connection)
	return connection
end

local function disconnectTracked(container: Instance)
	local connections = trackedConnections[container]
	if not connections then
		return
	end

	for _, connection in ipairs(connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end

	trackedConnections[container] = nil
end

local function clearList(container: Instance?, template: GuiObject)
	
	if not container then
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		if child ~= template and child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	
end

local function sanitizeGuid(value: string): string
	
	local trimmed: string = (value:match("^%s*(.-)%s*$") or value)
	if #trimmed >= 2 and trimmed:sub(1,1) == "{" and trimmed:sub(-1) == "}" then
		return trimmed:sub(2, -2)
	end
	
	return trimmed
end


local function isGuid(value: unknown): boolean
	
	if typeof(value) ~= "string" then
		return false
	end
	
	local normalized = sanitizeGuid(value)
	
	return normalized:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
		or (#normalized == 32 and normalized:match("^%x+$") ~= nil)
end

local function cloneItemData(itemData: any): any
	
	if type(itemData) == "table" then
		
		if table.clone then
			return table.clone(itemData)
		else
			
			local new = {}
			for k, v in pairs(itemData) do
				new[k] = v
			end
			
			return new
		end
	end
	
	return { Value = itemData }
end

local function buildStack(items: { any }): { any }
	
	local aggregated: { any } = {}
	local lookup: { [string]: any } = {}

	for _, item in ipairs(items) do
		local entry = cloneItemData(item)
		entry.Count = entry.Count or 1

		if entry.Id and isGuid(entry.Id) then
			table.insert(aggregated, entry)
			continue
		end

		local key = entry.Id or entry.Text or entry.Name or tostring(entry)
		local existing = lookup[key]
		if existing then
			existing.Count += entry.Count
		else
			lookup[key] = entry
			table.insert(aggregated, entry)
		end
	end

	return aggregated
end

local function setFrameVisibility(frame: GuiObject | ScreenGui, isVisible: boolean)
	if frame:IsA("ScreenGui") then
		frame.Enabled = isVisible
	else
		(frame :: GuiObject).Visible = isVisible
	end
end

--#endregion

local function defaultGetItems(): { any }
	return {}
end

local function defaultOnItemClick(_: any)
end

local function defaultOnClose()
end

--#region Public API

function UIListManager.Close(uiFrame: GuiObject | ScreenGui)
	setFrameVisibility(uiFrame, false)
	disconnectTracked(uiFrame)
end

function UIListManager.SetupList(params: RenderParams)
	assert(params.UiFrame, "[UIListManager] UiFrame is required")
	assert(params.Template, "[UIListManager] Template is required")
	assert(params.CloseButton, "[UIListManager] CloseButton is required")

	local uiFrame = params.UiFrame
	local template = params.Template
	local closeButton = params.CloseButton

	local listContainer = params.ListContainer or template.Parent
	local getItems = params.GetItems or defaultGetItems
	local onItemClick = params.OnItemClick or defaultOnItemClick
	local onClose = params.OnClose or defaultOnClose
	local renderItem = params.RenderItem
	local autoClose = params.AutoClose ~= false
	local colorButton = params.ColorButton
	local stackItems = params.StackItems == true

	disconnectTracked(uiFrame)
	ensureConnectionBucket(uiFrame)

	clearList(listContainer, template)
	template.Visible = false
	setFrameVisibility(uiFrame, true)

	-- Close button
	if closeButton:IsA("GuiButton") then
		bind(uiFrame, closeButton.MouseButton1Click:Connect(function()
			setFrameVisibility(uiFrame, false)
			onClose()
			disconnectTracked(uiFrame)
		end))
	end

	local ok, items = pcall(getItems)
	if not ok or type(items) ~= "table" then
		warn("[UIListManager] GetItems must return a table, got:", typeof(items))
		items = {}
	end

	if stackItems then
		items = buildStack(items)
	end

	for _, itemData in ipairs(items) do
		local button = template:Clone()
		button.Visible = true
		button.Parent = listContainer

		if colorButton and (button :: any).BackgroundColor3 ~= nil then
			(button :: GuiObject & { BackgroundColor3: Color3 }).BackgroundColor3 = colorButton
		end

		if renderItem then
			renderItem(button, itemData)
		else
			local label: TextLabel? = button:IsA("TextButton") and (button :: any)
				or button:FindFirstChildWhichIsA("TextLabel")

			local text = itemData.Text or itemData.Name or tostring(itemData.Id or "Item")
			if stackItems and itemData.Count and itemData.Count > 1 then
				text = string.format("%s x%d", text, itemData.Count)
			end

			if button:IsA("TextButton") then
				(button :: TextButton).Text = text
			elseif label then
				label.Text = text
			end
		end

		if button:IsA("GuiButton") then
			bind(uiFrame, button.MouseButton1Click:Connect(function()
				onItemClick(itemData)
				if autoClose then
					setFrameVisibility(uiFrame, false)
					onClose()
					disconnectTracked(uiFrame)
				end
			end))
		end
	end
end

--#endregion

return UIListManager
