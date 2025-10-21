-- StarterPlayerScripts/DuelClient.lua
-- =======================
-- Client-side duel system
-- =======================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player  = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes").Fight

local ChallengePlayer   = Remotes:WaitForChild("ChallengePlayer")
local ChallengeResponse = Remotes:WaitForChild("ChallengeResponse")
local UpdateChallengeUi = Remotes:WaitForChild("UpdateChallengeUi")
local DuelUpdate        = Remotes:WaitForChild("DuelUpdate")

local GetInventory      = Remotes.Parent:WaitForChild("GetInventory")

local UIListManager = require(ReplicatedStorage.Modules:WaitForChild("UIListManager"))
local CombatData    = require(ReplicatedStorage.Modules:WaitForChild("CombatData"))


local duelTemplates = ReplicatedStorage:WaitForChild("UI"):WaitForChild("DuelTemplates")
local duelUi = {}
local fishSelected = nil
local activeConnections = {}

local battleState = {
        duelId = nil,
        myRole = nil,
        moveButtons = {},
        moveConnections = {},
}

-- =====================================
-- Helpers
-- =====================================

local function cloneTemplate(name)
	local t = duelTemplates:FindFirstChild(name)
	return t and t:Clone() or nil
end

local function loadAllTemplates()
	
	for _, name in ipairs({ "FishSelector", "BattleUI", "IncomingChallenge", "ResultPanel" }) do
		
		duelUi[name] = cloneTemplate(name)
		if duelUi[name] then duelUi[name].Parent = nil end
	end
end

local function clearConnections()
        for _, conn in ipairs(activeConnections) do
                if conn.Connected then
                        conn:Disconnect()
                end
        end
        table.clear(activeConnections)

        for _, button in ipairs(battleState.moveButtons) do
                if typeof(button) == "Instance" and button.Destroy then
                        button:Destroy()
                end
        end
        table.clear(battleState.moveButtons)

        for _, conn in ipairs(battleState.moveConnections) do
                if conn.Connected then
                        conn:Disconnect()
                end
        end
        table.clear(battleState.moveConnections)
end

loadAllTemplates()

local function ensureScreenGui()
	
	if duelUi.ScreenGui and duelUi.ScreenGui.Parent then
		return duelUi.ScreenGui
	end
	
	local sg = Instance.new("ScreenGui")
	sg.Name = "DuelUI"
	sg.ResetOnSpawn = false
	sg.Parent = player:WaitForChild("PlayerGui")
	duelUi.ScreenGui = sg
	
	return sg
end

local function showTemplate(inst)
	
	if not inst then return end
	local container = ensureScreenGui()
		
	inst.Parent = container
	if inst:IsA("GuiObject") then inst.Visible = true end
	if inst:IsA("ScreenGui") then inst.Enabled = true end
end

local function hideTemplate(inst)
	
	if not inst then
		return end
	
	if inst:IsA("ScreenGui") then
		inst.Enabled = false
	else
		inst.Visible = false
		inst.Parent = nil
	end
end

local function closeAllDuelUI()
	
        for name, ui in pairs(duelUi) do
                if typeof(ui) == "Instance" then
                        hideTemplate(ui)
                end
        end

        fishSelected = nil
        battleState.duelId = nil
        battleState.myRole = nil
        clearConnections()
end

local function findDescendant(parent, name)

        if not parent then
                return nil end

        if parent.Name == name then
                return parent end

        for _, c in ipairs(parent:GetChildren()) do

                local f = findDescendant(c, name)
                if f then return f end
        end

        return nil
end

local function ensureBattleLog(panel)
        local label = findDescendant(panel, "BattleLog")
        if not label then
                label = Instance.new("TextLabel")
                label.Name = "BattleLog"
                label.BackgroundTransparency = 1
                label.TextColor3 = Color3.new(1, 1, 1)
                label.TextWrapped = true
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.TextYAlignment = Enum.TextYAlignment.Top
                label.Font = Enum.Font.Gotham
                label.TextSize = 18
                label.AnchorPoint = Vector2.new(0, 1)
                label.Size = UDim2.new(1, -20, 0, 120)
                label.Position = UDim2.new(0, 10, 1, -200)
                label.Parent = panel
        end
        return label
end

local function ensureMoveContainer(panel)
        local container = findDescendant(panel, "MoveContainer")
        if not container then
                container = Instance.new("Frame")
                container.Name = "MoveContainer"
                container.AnchorPoint = Vector2.new(1, 1)
                container.Position = UDim2.new(1, -16, 1, -16)
                container.Size = UDim2.new(0, 280, 0, 180)
                container.BackgroundTransparency = 0.25
                container.BackgroundColor3 = Color3.fromRGB(18, 26, 42)
                container.BorderSizePixel = 0
                container.Parent = panel

                local layout = Instance.new("UIGridLayout")
                layout.Name = "Layout"
                layout.CellPadding = UDim2.new(0, 8, 0, 8)
                layout.CellSize = UDim2.new(0.5, -8, 0.5, -8)
                layout.FillDirectionMaxCells = 2
                layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
                layout.VerticalAlignment = Enum.VerticalAlignment.Center
                layout.SortOrder = Enum.SortOrder.LayoutOrder
                layout.Parent = container
        end
        return container
end

local function updateBattleLog(panel, logLines)
        if not panel then return end
        local label = ensureBattleLog(panel)

        if type(logLines) == "string" then
                label.Text = logLines
        elseif type(logLines) == "table" then
                label.Text = table.concat(logLines, "\n")
        else
                label.Text = ""
        end
end

local function renderMoveButtons(panel, moves, duelId, isMyTurn)
        local container = ensureMoveContainer(panel)

        for _, conn in ipairs(battleState.moveConnections) do
                if conn.Connected then
                        conn:Disconnect()
                end
        end
        table.clear(battleState.moveConnections)

        for _, child in ipairs(container:GetChildren()) do
                if child:IsA("TextButton") then
                        child:Destroy()
                end
        end

        table.clear(battleState.moveButtons)

        for index, move in ipairs(moves or {}) do
                local button = Instance.new("TextButton")
                button.Name = "Move_" .. (move.Id or index)
                button.LayoutOrder = index
                button.AutoButtonColor = true
                button.TextWrapped = true
                button.Font = Enum.Font.GothamBold
                button.TextSize = 16
                button.TextColor3 = Color3.new(1, 1, 1)
                button.BackgroundTransparency = 0.1
                button.Size = UDim2.new(0, 0, 0, 0)
                button.Text = string.format("%s\nPP %d/%d", move.Name or "???", move.PP or 0, move.MaxPP or 0)
                button.Parent = container
                button:SetAttribute("MoveId", move.Id)

                local typeInfo = move.Type and CombatData.Types[move.Type]
                if typeInfo and typeInfo.Color then
                        button.BackgroundColor3 = typeInfo.Color:Lerp(Color3.new(0.1, 0.1, 0.2), 0.4)
                else
                        button.BackgroundColor3 = Color3.fromRGB(40, 46, 68)
                end

                local descriptionValue = Instance.new("StringValue")
                descriptionValue.Name = "Description"
                descriptionValue.Value = move.Description or ""
                descriptionValue.Parent = button

                button.Active = isMyTurn and (move.PP or 0) > 0
                button.AutoButtonColor = button.Active
                button.BackgroundTransparency = button.Active and 0.1 or 0.4

                local connection = button.MouseButton1Click:Connect(function()
                        if not button.Active then
                                return
                        end

                        DuelUpdate:FireServer({
                                duelId = duelId,
                                action = "move",
                                moveId = button:GetAttribute("MoveId"),
                        })

                        for _, btn in ipairs(battleState.moveButtons) do
                                if btn:IsA("TextButton") then
                                        btn.Active = false
                                        btn.AutoButtonColor = false
                                end
                        end
                end)

                table.insert(battleState.moveConnections, connection)

                table.insert(battleState.moveButtons, button)
        end
end

local function isMyTurn(payload)
        if not battleState.myRole then
                return false
        end

        return (payload.currentTurn == "challenger" and battleState.myRole == "challenger")
                or (payload.currentTurn == "receiver" and battleState.myRole == "receiver")
end

local function updateTurnIndicator(panel, payload)
        local turnLabel = findDescendant(panel, "PlayerTurn")
        if not turnLabel then
                return
        end

        if payload.currentTurn == "challenger" then
                local pl = Players:GetPlayerByUserId(payload.challengerId)
                turnLabel.Text = ((pl and pl.Name) or "???") .. " joue"
        elseif payload.currentTurn == "receiver" then
                local pl = Players:GetPlayerByUserId(payload.receiverId)
                turnLabel.Text = ((pl and pl.Name) or "???") .. " joue"
        end
end

local function renderBattleState(payload)
        local panel = duelUi.BattleUI
        if not panel then return end

        local chalStats = payload.challengerStats or payload.challengerFish
        local recvStats = payload.receiverStats or payload.receiverFish

        if not chalStats or not recvStats then
                return
        end

        local leftName = findDescendant(panel, "LeftName")
        if leftName then
                local levelText = chalStats.Level and (" Lv." .. tostring(chalStats.Level)) or ""
                leftName.Text = string.format("%s%s", chalStats.Name or "???", levelText)
        end

        local rightName = findDescendant(panel, "RightName")
        if rightName then
                local levelText = recvStats.Level and (" Lv." .. tostring(recvStats.Level)) or ""
                rightName.Text = string.format("%s%s", recvStats.Name or "???", levelText)
        end

        local leftBar = findDescendant(panel, "LeftHPBar")
        if leftBar and leftBar:FindFirstChild("Fill") and chalStats.MaxHP then
                leftBar.Fill.Size = UDim2.new(math.clamp(chalStats.HP / chalStats.MaxHP, 0, 1), 0, 1, 0)
        end

        local rightBar = findDescendant(panel, "RightHPBar")
        if rightBar and rightBar:FindFirstChild("Fill") and recvStats.MaxHP then
                rightBar.Fill.Size = UDim2.new(math.clamp(recvStats.HP / recvStats.MaxHP, 0, 1), 0, 1, 0)
        end

        local passBtn = findDescendant(panel, "PassButton")
        local myMoves = (battleState.myRole == "challenger") and payload.challengerMoves or payload.receiverMoves
        local myTurn = isMyTurn(payload)

        renderMoveButtons(panel, myMoves or {}, payload.duelId, myTurn)

        if passBtn then
                passBtn.Visible = myTurn
                passBtn.Active = myTurn
                passBtn.AutoButtonColor = myTurn
        end

        updateTurnIndicator(panel, payload)
        updateBattleLog(panel, payload.log)
end

-- =====================================
-- Fish Selector
-- =====================================
local function openFishSelector(callback)
	
	local selector = duelUi.FishSelector
	if not selector then return callback(nil) end
	
	local list         = findDescendant(selector, "List")
	local itemTemplate = findDescendant(selector, "ItemTemplate")
	local closeBtn     = findDescendant(selector, "CloseButton")
	local refreshBtn   = findDescendant(selector, "RefreshButton")

	if not list or not itemTemplate then return callback(nil, nil) end
	showTemplate(selector)

	-- Recperer inventaire du joueur
	local items = GetInventory:InvokeServer("Fish")

	-- Transformer en format utilisable par UIListManager
	local fishItems = {}
	for _, fish in ipairs(items) do
		table.insert(fishItems, {
			Text = fish.Name or fish.DataName or "Fish",
			Data = fish,
		})
	end

	-- Utiliser UIListManager
	UIListManager.SetupList{
		UiFrame       = selector,
		Template      = itemTemplate,
		CloseButton   = closeBtn,
		ListContainer = list,
		GetItems      = function() return fishItems end,
		
		OnItemClick   = function(itemData)
			
			hideTemplate(selector)
			if callback then
				callback(itemData.Data.Id, itemData.Data.DataName) end
		end,
		
		OnClose = function()
			
			hideTemplate(selector)
			if callback then 
				callback(nil, nil) end
		end,
		AutoClose = false,
	}

	if refreshBtn then
		table.insert(activeConnections, refreshBtn.MouseButton1Click:Connect(function()
			hideTemplate(selector)
			openFishSelector(callback)
		end))
	end
end

-- =====================================
-- Challenge UI
-- =====================================
local isReady = false
local function openChallengeUI(duelId, isChallenger, opponentName, opponentFishName, challengeAccepted)
	
	clearConnections()
	
	local panel = duelUi.IncomingChallenge
	if not panel then return end
	showTemplate(panel)

	local frameC = findDescendant(panel, "Challenge")
	local frameR = findDescendant(panel, "Reciver")
	if frameC then frameC.Visible = false end
	if frameR then frameR.Visible = false end

	if isChallenger or challengeAccepted then
		
		frameC.Visible = true
		findDescendant(frameC,"NamePlayer1").Text = player.Name
		findDescendant(frameC,"NamePlayer2").Text = opponentName .. (challengeAccepted and "" or " (waiting...)")
		
		findDescendant(frameC,"FishName1").Text  = fishSelected and ("Fish ID:"..fishSelected) or "In selection"
		findDescendant(frameC,"FishName2").Text  = opponentFishName and ("Fish ID:"..opponentFishName) or "In selection"

		local readyBtn  = findDescendant(frameC,"ReadyButton")
		local cancelBtn = findDescendant(frameC,"CancelButton")
		local fishBtn   = findDescendant(frameC,"ChoseFishButton")

		table.insert(activeConnections, readyBtn.MouseButton1Click:Connect(function()
			
			if fishSelected then
				
				isReady = not isReady
				UpdateChallengeUi:FireServer(duelId, isReady, {
					id = fishSelected,
					name = findDescendant(frameC,"FishName1").Text
				})
				
				if isReady then
					readyBtn.Text = "You are ready"
					readyBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
				else
					readyBtn.Text = "Ready ?"
					readyBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
				end
			end
		end))

		-- Fish selection
		if fishBtn then
			table.insert(activeConnections, fishBtn.MouseButton1Click:Connect(function()
				openFishSelector(function(fishId, fishName)
					
					if fishId then
						fishSelected = fishId
						findDescendant(frameC,"FishName1").Text = fishName
						
						UpdateChallengeUi:FireServer(duelId, false, {
							id = fishId,
							name = fishName
						})
						
						if readyBtn then
							readyBtn.Active = true
							readyBtn.AutoButtonColor = true
						end
					end
				end)
			end))
		end

		-- Cancel
		if cancelBtn then
			table.insert(activeConnections, cancelBtn.MouseButton1Click:Connect(function()
				ChallengeResponse:FireServer(duelId, false)
				closeAllDuelUI()
			end))
		end

	else
		-- Receiver UI
		frameR.Visible = true
		findDescendant(frameR,"MessageLabel").Text = opponentName.." vous d�fie"
		
		local acceptBtn = findDescendant(frameR,"AcceptButton")
		local declineBtn = findDescendant(frameR,"DeclineButton")

		if acceptBtn then
			table.insert(activeConnections, acceptBtn.MouseButton1Click:Connect(function()
				ChallengeResponse:FireServer(duelId, true)
				frameR.Visible = false
			end))
		end

		if declineBtn then
			table.insert(activeConnections, declineBtn.MouseButton1Click:Connect(function()
				ChallengeResponse:FireServer(duelId, false)
				closeAllDuelUI()
			end))
		end
	end
end

-- =====================================
-- Battle UI
-- =====================================
local function openBattleUI(payload)

        local panel = duelUi.BattleUI
        if not panel then return end

        clearConnections()
        showTemplate(panel)

        battleState.duelId = payload.duelId
        battleState.myRole = (player.UserId == payload.challengerId) and "challenger" or "receiver"

        local atkBtn = findDescendant(panel,"AttackButton")
        if atkBtn then
                atkBtn.Visible = false
                atkBtn.Active = false
        end

        local passBtn = findDescendant(panel,"PassButton")
        if passBtn then
                passBtn.Text = "Repos"
                table.insert(activeConnections, passBtn.MouseButton1Click:Connect(function()
                        if not battleState.duelId then return end
                        DuelUpdate:FireServer({
                                duelId = battleState.duelId,
                                action = "pass",
                        })
                        passBtn.Active = false
                        passBtn.AutoButtonColor = false
                end))
        end

        renderBattleState(payload)
end

-- =====================================
-- Remote Event Listeners
-- =====================================
ChallengePlayer.OnClientEvent:Connect(function(duelId, opponentName, challengerUserId, challengeAccepted)
	
	local readyBtn = findDescendant(duelUi.IncomingChallenge,"ReadyButton")
	readyBtn.Text = "Ready ?"
	readyBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	isReady = false
	
	local isChallenger = (challengerUserId == player.UserId)
	openChallengeUI(duelId, isChallenger, opponentName, nil, challengeAccepted)
end)

ChallengeResponse.OnClientEvent:Connect(closeAllDuelUI)

UpdateChallengeUi.OnClientEvent:Connect(function(duelId, opponentInfos)
	openChallengeUI(duelId, false, opponentInfos.player, opponentInfos.fishSelected, true)
end)

DuelUpdate.OnClientEvent:Connect(function(payload)

        if not payload or not payload.state then
                return
        end

        if payload.state == "notice" then
                updateBattleLog(duelUi.BattleUI, payload.message)
                return
        end

        if payload.state == "cancel" then
                closeAllDuelUI()
                clearConnections()
                return
        end

        if payload.state == "start" then

                clearConnections()
                hideTemplate(duelUi.IncomingChallenge)
                hideTemplate(duelUi.ResultPanel)
                openBattleUI(payload)
                return
        end

        if not battleState.duelId or battleState.duelId ~= payload.duelId then
                return
        end

        if payload.state == "update" then
                renderBattleState(payload)
                return
        end

        if payload.state == "end" then
                renderBattleState(payload)
                clearConnections()

                local res = duelUi.ResultPanel
                if res then
                        showTemplate(res)
                        local resultLabel = findDescendant(res,"ResultLabel")
                        if resultLabel then
                                local winnerName = payload.winner or "???"
                                resultLabel.Text = winnerName.." a gagné le duel !"
                        end

                        local okBtn = findDescendant(res, "OkButton")
                        if okBtn then
                                table.insert(activeConnections, okBtn.MouseButton1Click:Connect(function()
                                        closeAllDuelUI()
                                        clearConnections()
                                        fishSelected = nil
                                end))
                        end
                end

                battleState.duelId = nil
                battleState.myRole = nil
                return
        end
end)

-- =====================================
-- Proximity Prompt System
-- =====================================
ProximityPromptService.PromptTriggered:Connect(function(prompt, p)
	
	if prompt.Name ~= "DuelPrompt" or p ~= player then 
		return end
	
	local targetChar = prompt.Parent.Parent
	local target = Players:GetPlayerFromCharacter(targetChar)
	
	if target and target.UserId ~= player.UserId then
		ChallengePlayer:FireServer(target)
	end
end)

-- Disable prompt on self
ProximityPromptService.PromptShown:Connect(function(prompt)
	
	if prompt.Parent and prompt.Parent:IsDescendantOf(player.Character) then
		prompt.Enabled = false
	end
end)