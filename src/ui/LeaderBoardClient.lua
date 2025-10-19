local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GetPlayersStats = ReplicatedStorage:WaitForChild("RequestLeaderboardData")
local scrollingFrame = script.Parent

local listLayout = scrollingFrame:FindFirstChildOfClass("UIListLayout")

local template = Instance.new("TextLabel")
template.Size = UDim2.new(1, 0, 0, 30)
template.BackgroundTransparency = 0
template.TextColor3 = Color3.new(1, 0, 0.0156863)
template.Font = Enum.Font.Gotham
template.TextScaled = true

-- Nettoie l'ancienne liste
local function clearLeaderboard()
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

local function updateCanvasSize()
	task.defer(function()
		scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
	end)
end

-- Met a jour l'UI
local function updateLeaderboard(data)
	
	clearLeaderboard()

	for i, entry in ipairs(data) do
		
		local ok,name = pcall(Players.GetNameFromUserIdAsync, Players, entry.UserId)
		if not ok then name = "Unknown" end

		local label = template:Clone()
		label.Text  = string.format("%d. %s - $%s", i, name, tostring(entry.Money))
		label.LayoutOrder = i
		label.Parent = scrollingFrame
	end
	
	updateCanvasSize()
end

GetPlayersStats.OnClientEvent:Connect(updateLeaderboard)

GetPlayersStats:FireServer()