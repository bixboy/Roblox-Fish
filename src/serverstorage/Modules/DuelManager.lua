-- ServerStorage/Modules/DuelManager.lua
local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")

local InventoryManager = require(game.ServerStorage.Modules:WaitForChild("InventoryManager"))
local FishData         = require(game.ServerStorage.Data:WaitForChild("FishData"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DuelUpdate        = ReplicatedStorage.Remotes.Fight:WaitForChild("DuelUpdate")

local DuelManager = {}
DuelManager.__index = DuelManager

-- ========================
-- CONFIG & STORAGE
-- ========================
local activeDuels = {} -- [duelId] = duelTable
local DUEL_TIMEOUT = 25 -- seconds

-- ========================
-- HELPERS
-- ========================

local function shallowCopy(t)
	if not t then return nil end
	local o = {}
	for k, v in pairs(t) do o[k] = v end
	return o
end

-- Build combat stats from fish type
local function buildCombatStats(Type)
	
	local base = FishData[Type]
	if not base then
		return { MaxHP=50, HP=50, Attack=10, Defense=5, Speed=10, Type=Type }
	end

	local growthRatio = (base.MaxGrowth and base.Growth)
		and math.clamp(base.Growth / base.MaxGrowth, 0, 1) or 0

	local function scale(stat, factor)
		return math.floor(((base[stat] or 10) * (1 + growthRatio * factor)) + 0.5)
	end

	return {
		MaxHP   = scale("HP", 0.5),
		HP      = scale("HP", 0.5),
		Attack  = scale("Attack", 0.4),
		Defense = scale("Defense", 0.4),
		Speed   = scale("Speed", 0.3),
		Type    = Type,
		OrigData = shallowCopy(base),
	}
end

-- Damage formula
local function calcDamage(attacker, defender)
	
	local base = math.max(1, attacker.Attack - (defender.Defense * 0.5))
	
	local variance = 0.85 + (math.random() * 0.3)
	local dmg = math.floor(base * variance + 0.5)
	
	if math.random() < 0.08 then 
		dmg = math.floor(dmg * 1.5) 
	end -- crit
	
	return math.max(1, dmg)
end

-- End duel & handle rewards
local function finalizeDuel(duel, winnerPlayer, loserPlayer)
	
	local stakes = duel.stakes or {}
	local winnerKey = (winnerPlayer.UserId == duel.challengerId) and "challenger" or "target"
	local loserKey  = (winnerKey == "challenger") and "target" or "challenger"

	-- return/give fish
	for _, key in ipairs({winnerKey, loserKey}) do
		
		local stake = stakes[key]
		if stake and stake.fishData then
			
			local ok, err = InventoryManager:AddFish(
				(key == winnerKey) and winnerPlayer or winnerPlayer,
				stake.fishData
			)
			
			if not ok then 
				warn("DuelManager: failed to restore fish:", err)
			end
		end
	end

	local duel = activeDuels[duel.id]
	duel.endCallBack(duel.id)
	duel = nil
end

-- ========================
-- PUBLIC API
-- ========================

-- Create duel request
function DuelManager:CreateChallenge(challenger, target, callBack)
	
	if not challenger or not target then
		return nil, "invalid players"
	end
	
	if challenger.UserId == target.UserId then
		return nil, "cannot challenge self" 
	end

	local id = HttpService:GenerateGUID(false)
	local duel =
	{
		id = id,
		state = "pending",
		endCallBack = callBack,
		
		challengerId = challenger.UserId,
		targetId     = target.UserId,
		
		challengerFishId = nil,
		targetFishId     = nil,
		
		createdAt = os.time(),
		stakes = {},
		turn = nil,
	}
	
	activeDuels[id] = duel
	return id, duel
end

-- Accept duel & init combat
function DuelManager:AcceptChallenge(duelId, targetFishId, challengerFishId)
	
	local duel = activeDuels[duelId]
	if not duel then
		activeDuels[duelId] = nil 
		return false, "duel not found/pending" 
	end
	
	local challenger = Players:GetPlayerByUserId(duel.challengerId)
	local target = Players:GetPlayerByUserId(duel.targetId)
	
	if not target then
		activeDuels[duelId] = nil
		return false, "target left"
	end

	if not challenger then
		activeDuels[duelId] = nil 
		return false, "challenger left"
	end

	-- Remove fishes as stakes
	local ok1, fish1 = InventoryManager:RemoveFish(challenger, challengerFishId)
	local ok2, fish2 = InventoryManager:RemoveFish(target, targetFishId)

	if not ok1 or not ok2 then
		
		activeDuels[duelId] = nil
		return false, "Cant remove fish from inventory"
	end

	duel.stakes = {
		challenger = { owner = duel.challengerId, fishData = fish1 },
		target     = { owner = duel.targetId,     fishData = fish2 },
	}
	duel.state = "active"

	-- Build fighters
	local chalStats = buildCombatStats(fish1.Type or fish1.DataName or fish1.Id)
	local recvStats = buildCombatStats(fish2.Type or fish2.DataName or fish2.Id)
	duel.combat = {
		[duel.challengerId] = chalStats,
		[duel.targetId]     = recvStats,
	}

	-- Who starts?
	local first = (chalStats.Speed > recvStats.Speed) and duel.challengerId
		or (recvStats.Speed > chalStats.Speed and duel.targetId
			or ((math.random(0,1) == 0) and duel.challengerId or duel.targetId))
	
	duel.turn = first
	
	local payload = {
		state = "start",
		duelId = duelId,
		challengerFish = chalStats,
		receiverFish   = recvStats,
		currentTurn    = (duel.turn == duel.challengerId) and "challenger" or "receiver",
		challengerId   = duel.challengerId,
		receiverId     = duel.targetId
	}

	-- Notify clients
	DuelUpdate:FireClient(challenger, payload)
	DuelUpdate:FireClient(target, payload)
	
	warn("Duel Start Combat !!!")

	return true, duel
end

-- Handle a player action
function DuelManager:TakeTurn(duelId, player, action)
	
	local duel = activeDuels[duelId]
	if not duel or duel.state ~= "active" then
		
		warn("Duel not active")
		return 
	end
	
	if player.UserId ~= duel.turn then
		
		warn("Not player turn")
		return
	end

	local combat = duel.combat
	local attacker = combat[player.UserId]
	
	local defenderId = (player.UserId == duel.challengerId) and duel.targetId or duel.challengerId
	local defender = combat[defenderId]
	
	if not attacker or not defender then
		return end

	if action == "attack" then
		
		local dmg = calcDamage(attacker, defender)
		defender.HP = math.max(0, defender.HP - dmg)
		
	elseif action == "pass" then
		-- do nothing, just skip
	end

	-- Check end
	if defender.HP <= 0 then
		
		duel.state = "finished"
		local winner, loser = player, Players:GetPlayerByUserId(defenderId)
		
		finalizeDuel(duel, winner, loser)
		DuelUpdate:FireClient(Players:GetPlayerByUserId(duel.challengerId), 
			{ state="end", winner=winner.Name })
		
		DuelUpdate:FireClient(Players:GetPlayerByUserId(duel.targetId),     
			{ state="end", winner=winner.Name })
		
		return
	end

	-- Switch turn
	duel.turn = defenderId
	DuelUpdate:FireClient(Players:GetPlayerByUserId(duel.challengerId), {
		
		state="update", duelId=duelId, challengerStats=combat[duel.challengerId],
		receiverStats=combat[duel.targetId], currentTurn=(duel.turn==duel.challengerId and "challenger" or "receiver"),
		challengerId=duel.challengerId, receiverId=duel.targetId
	})
	
	DuelUpdate:FireClient(Players:GetPlayerByUserId(duel.targetId), {
		
		state="update", duelId=duelId, challengerStats=combat[duel.challengerId],
		receiverStats=combat[duel.targetId], currentTurn=(duel.turn==duel.challengerId and "challenger" or "receiver"),
		challengerId=duel.challengerId, receiverId=duel.targetId
	})
end

-- Get duel by id
function DuelManager:GetDuel(id)
	return activeDuels[id]
end

-- Expose stat builder
function DuelManager:BuildCombatStats(Type)
	return buildCombatStats(Type)
end

function DuelManager:ClearDuel(id)
	activeDuels[id] = nil
end

return DuelManager