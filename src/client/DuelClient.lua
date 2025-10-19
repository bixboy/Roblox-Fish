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


local duelTemplates = ReplicatedStorage:WaitForChild("UI"):WaitForChild("DuelTemplates")
local duelUi = {}
local fishSelected = nil
local activeConnections = {}

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
local function openBattleUI(duelId, challengerFish, receiverFish)
	
	local panel = duelUi.BattleUI
	if not panel then return end
	
	clearConnections()
	showTemplate(panel)

	findDescendant(panel,"LeftName").Text  = challengerFish.Type or "???"
	findDescendant(panel,"RightName").Text = receiverFish.Type or "???"

	local atkBtn = findDescendant(panel,"AttackButton")
	local passBtn = findDescendant(panel,"PassButton")

	if atkBtn then
		table.insert(activeConnections, atkBtn.MouseButton1Click:Connect(function()
			DuelUpdate:FireServer({duelId=duelId, action="attack"})
		end))
	end

	if passBtn then
		table.insert(activeConnections, passBtn.MouseButton1Click:Connect(function()
			DuelUpdate:FireServer({duelId=duelId, action="pass"})
		end))
	end
	
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
	
	if payload.state == "start" then
		
		clearConnections()
		hideTemplate(duelUi.IncomingChallenge)
		hideTemplate(duelUi.ResultPanel)
		openBattleUI(payload.duelId, payload.challengerFish, payload.receiverFish)
		
		local panel = duelUi.BattleUI
		if panel then
			
			findDescendant(panel, "LeftHPBar").Fill.Size =
				UDim2.new(payload.challengerFish.HP / payload.challengerFish.MaxHP, 0, 1, 0)

			findDescendant(panel, "RightHPBar").Fill.Size =
				UDim2.new(payload.receiverFish.HP / payload.receiverFish.MaxHP, 0, 1, 0)

			findDescendant(panel, "LeftName").Text =
				(payload.challengerFish.OrigData and payload.challengerFish.OrigData.Name) or "???"
			
			findDescendant(panel, "RightName").Text =
				(payload.receiverFish.OrigData and payload.receiverFish.OrigData.Name) or "???"

			local atkBtn  = findDescendant(panel, "AttackButton")
			local passBtn = findDescendant(panel, "PassButton")

			local isMyTurn =
				(payload.currentTurn == "challenger" and player.UserId == payload.challengerId)
				or (payload.currentTurn == "receiver" and player.UserId == payload.receiverId)

			if atkBtn and passBtn then
				atkBtn.Visible = isMyTurn
				passBtn.Visible = isMyTurn
			end

			local turnLabel = findDescendant(panel, "PlayerTurn")
			if turnLabel then
				
				if payload.currentTurn == "challenger" then
					
					local pl = Players:GetPlayerByUserId(payload.challengerId)
					turnLabel.Text = (pl and pl.Name or "???") .. " joue"
				else
					local pl = Players:GetPlayerByUserId(payload.receiverId)
					turnLabel.Text = (pl and pl.Name or "???") .. " joue"
				end
			end
		end
		
		warn("Duel started!")
	end

	if payload.state == "update" then
		warn("Duel updated!")

		local panel = duelUi.BattleUI
		if panel then
			local chal = payload.challengerStats
			local recv = payload.receiverStats

			findDescendant(panel, "LeftHPBar").Fill.Size =
				UDim2.new(chal.HP / chal.MaxHP, 0, 1, 0)

			findDescendant(panel, "RightHPBar").Fill.Size =
				UDim2.new(recv.HP / recv.MaxHP, 0, 1, 0)

			findDescendant(panel, "LeftName").Text =
				(chal.OrigData and chal.OrigData.Name) or "???"

			findDescendant(panel, "RightName").Text =
				(recv.OrigData and recv.OrigData.Name) or "???"

			-- Indication de tour
			local atkBtn = findDescendant(panel, "AttackButton")
			local passBtn = findDescendant(panel, "PassButton")

			local isMyTurn = 
				(payload.currentTurn == "challenger" and player.UserId == payload.challengerId)
				or (payload.currentTurn == "receiver" and player.UserId == payload.receiverId)

			if isMyTurn then
				if atkBtn then atkBtn.Visible = true end
				if passBtn then passBtn.Visible = true end
			else
				if atkBtn then atkBtn.Visible = false end
				if passBtn then passBtn.Visible = false end
			end

			if payload.currentTurn == "challenger" then
				
				local pl = Players:GetPlayerByUserId(payload.challengerId)
				findDescendant(panel, "PlayerTurn").Text = (pl and pl.Name or "???") .. " joue"
				
			elseif payload.currentTurn == "receiver" then
				
				local pl = Players:GetPlayerByUserId(payload.receiverId)
				findDescendant(panel, "PlayerTurn").Text = (pl and pl.Name or "???") .. " joue"
			end
		end
	end

	if payload.state == "end" then
		
		closeAllDuelUI()
		clearConnections()
		
		local res = duelUi.ResultPanel
		showTemplate(res)
		
		findDescendant(res,"ResultLabel").Text = payload.winner.." a gagn� le duel !"
		
		table.insert(activeConnections, findDescendant(res, "OkButton").MouseButton1Click:Connect(function()
			closeAllDuelUI()
			clearConnections()
			fishSelected = nil
		end))
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