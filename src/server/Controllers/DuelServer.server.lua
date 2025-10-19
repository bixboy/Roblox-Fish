-- ServerScriptService/Controllers/DuelServer.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fight")
local ChallengePlayer    = Remotes:WaitForChild("ChallengePlayer")
local ChallengeResponse  = Remotes:WaitForChild("ChallengeResponse")
local UpdateChallengeUi  = Remotes:WaitForChild("UpdateChallengeUi")
local DuelUpdate         = Remotes:WaitForChild("DuelUpdate")

local DuelManager = require(game.ServerStorage.Modules:WaitForChild("DuelManager"))

-- Stocke les duels actifs par duelId
local ActiveDuels = {}

-- Fonctions utilitaires
local function sendToBoth(duel, remote, ...)
	
	if duel.challenger then
		remote:FireClient(duel.challenger, ...)
	end
	
	if duel.receiver then
		remote:FireClient(duel.receiver, ...)
	end
end

local function clearDuel(duelId)
	ActiveDuels[duelId] = nil
	DuelManager:ClearDuel(duelId)
end

-- Creation du duel
ChallengePlayer.OnServerEvent:Connect(function(player, targetPlayer)
	
	if not targetPlayer or not targetPlayer:IsA("Player") then
		return end

	for _, duel in pairs(ActiveDuels) do
		
		if duel.challenger == player or duel.receiver == player or
			duel.challenger == targetPlayer or duel.receiver == targetPlayer then
			return
		end
	end
	
	local dmId, data = DuelManager:CreateChallenge(player, targetPlayer, clearDuel)
	if not dmId then
		warn(data)
		return
	end

	local duel = {
		challenger = player,
		receiver = targetPlayer,
		
		started = false,
		
		challengerFish = nil,
		challengerReady = false,
		challengerFishName = nil,
		
		receiverFish = nil,
		receiverReady = false,
		receiverFishName = nil
	}
	
	ActiveDuels[dmId] = duel

	-- Notifie les deux joueurs
	ChallengePlayer:FireClient(duel.receiver, dmId, duel.challenger.Name, player.UserId, false) 
	ChallengePlayer:FireClient(duel.challenger, dmId, duel.receiver.Name, player.UserId, false)
end)

-- Reponse du receveur
ChallengeResponse.OnServerEvent:Connect(function(player, duelId, accepted)
	
	local duel = ActiveDuels[duelId]
	if not duel then return end

	if not accepted then
		sendToBoth(duel, ChallengeResponse, false)
		clearDuel(duelId)
		return
	end

	-- Envoie confirmation aux deux
	ChallengePlayer:FireClient(duel.receiver, duelId, duel.challenger.Name, duel.challenger.UserId, true)
	ChallengePlayer:FireClient(duel.challenger, duelId, duel.receiver.Name, duel.receiver.UserId, true)
end)

-- Ready + choix du poisson
UpdateChallengeUi.OnServerEvent:Connect(function(player, duelId, playerReady, fishInfos)
	
	local duel = ActiveDuels[duelId]
	if not duel then
		return end
	
	if duel.started then
		return end
	
	if not fishInfos then
		return end

	-- FishInfos doit etre {id=..., name=...}
	if player == duel.challenger and fishInfos then
		
		duel.challengerFish     = fishInfos.id
		duel.challengerFishName = fishInfos.name
		duel.challengerReady    = playerReady
	elseif player == duel.receiver and fishInfos then
		
		duel.receiverFish     = fishInfos.id
		duel.receiverFishName = fishInfos.name
		duel.receiverReady    = playerReady
	end
	
	-- si les deux sont prets ? demarrer duel
	if duel.challengerReady and duel.receiverReady 
		and duel.challengerFish and duel.receiverFish 
		and not duel.started then

		local chalStats = DuelManager:BuildCombatStats(duel.challengerFishName)
		local recvStats = DuelManager:BuildCombatStats(duel.receiverFishName)

		duel.challengerStats = chalStats
		duel.receiverStats   = recvStats

		local ok, errorMsg = DuelManager:AcceptChallenge(duelId, duel.receiverFish, duel.challengerFish)
		if not ok then
			warn(errorMsg)

			sendToBoth(duel, ChallengeResponse, false)
			clearDuel(duelId)
			return
		end

		duel.started = true
		return
	end

	-- notifier adversaire
	if duel.challengerFish then
		UpdateChallengeUi:FireClient(duel.receiver, duelId, {
			player = duel.challenger.Name,
			fishSelected = duel.challengerFishName
		})
	end
	
	if duel.receiverFish then
		UpdateChallengeUi:FireClient(duel.challenger, duelId, {
			player = duel.receiver.Name,
			fishSelected = duel.receiverFishName
		})
	end
end)

-- Creation du ProximityPrompt
local function createDuelPrompt(targetPlayer)
	
	local char = targetPlayer.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if hrp:FindFirstChild("DuelPrompt") then return end

	local prox = Instance.new("ProximityPrompt")
	prox.Name = "DuelPrompt"
	prox.ActionText = "Challenge"
	prox.ObjectText = targetPlayer.Name
	prox.HoldDuration = 0
	prox.RequiresLineOfSight = false
	prox.MaxActivationDistance = 10
	prox.Style = Enum.ProximityPromptStyle.Custom
	prox.Parent = hrp

	prox.Triggered:Connect(function(playerWhoTriggered)
		print(playerWhoTriggered.Name.." a demander un duel avec "..targetPlayer.Name)
	end)
end

-- Gestion des joueurs
Players.PlayerAdded:Connect(function(pl)
	
	pl.CharacterAdded:Connect(function()
		createDuelPrompt(pl)
	end)
	
end)

for _, pl in ipairs(Players:GetPlayers()) do
	
	if pl.Character then
		createDuelPrompt(pl)
	end
	
	pl.CharacterAdded:Connect(function()
		createDuelPrompt(pl)
	end)
end

-- Nettoyage si un joueur quitte
Players.PlayerRemoving:Connect(function(pl)
	
	for duelId, duel in pairs(ActiveDuels) do
		
		if duel.challenger == pl or duel.receiver == pl then
			
			sendToBoth(duel, DuelUpdate, {duelId = duelId, state = "cancel"})
			clearDuel(duelId)
		end
	end
end)


DuelUpdate.OnServerEvent:Connect(function(player, payload)
	
	local duelId = payload.duelId
	local action = payload.action
	if not duelId or not action then
		return end
	
	warn(action)

	DuelManager:TakeTurn(duelId, player, action)
end)