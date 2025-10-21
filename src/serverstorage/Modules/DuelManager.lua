-- ServerStorage/Modules/DuelManager.lua
--
-- Server side duel engine responsible for orchestrating Pokemon-like
-- fish battles. Combat data (types, moves, base stats) lives inside
-- ReplicatedStorage.Modules.CombatData so designers can rebalance
-- encounters without touching server logic.

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryManager = require(game.ServerStorage.Modules:WaitForChild("InventoryManager"))
local FishData         = require(game.ServerStorage.Data:WaitForChild("FishData"))
local CombatData       = require(ReplicatedStorage.Modules:WaitForChild("CombatData"))

local DuelUpdate        = ReplicatedStorage.Remotes.Fight:WaitForChild("DuelUpdate")

local DuelManager = {}
DuelManager.__index = DuelManager

local activeDuels = {}

local DEFAULT_BASE_STATS = { HP = 50, Attack = 50, Defense = 50, SpAttack = 50, SpDefense = 50, Speed = 50 }
local MAX_STAGE = 6

local STAGE_CACHE = {}
local function getStageMultiplier(stage)
    local clamped = math.clamp(stage or 0, -MAX_STAGE, MAX_STAGE)
    if STAGE_CACHE[clamped] then
        return STAGE_CACHE[clamped]
    end

    local multiplier
    if clamped >= 0 then
        multiplier = (2 + clamped) / 2
    else
        multiplier = 2 / (2 - clamped)
    end

    STAGE_CACHE[clamped] = multiplier
    return multiplier
end

local function computeStat(base, level, isHp)
    base = base or 10
    if isHp then
        return math.floor(((2 * base * level) / 100) + level + 10)
    end
    return math.floor(((2 * base * level) / 100) + 5)
end

local function shallowCopy(t)
    if not t then
        return nil
    end
    local o = {}
    for k, v in pairs(t) do
        o[k] = v
    end
    return o
end

local function computeLevel(fishEntry, fishBaseData)
    local growth = (typeof(fishEntry) == "table" and fishEntry.Growth) or 0
    local maxGrowth = (fishBaseData and fishBaseData.MaxGrowth) or 100
    local ratio = 0
    if maxGrowth > 0 then
        ratio = math.clamp(growth / maxGrowth, 0, 1)
    end

    local level = math.clamp(math.floor(ratio * 99 + 1 + ((fishEntry and fishEntry.IsMature) and 5 or 0)), 1, 100)
    return level
end

local function buildStats(baseStats, level)
    local stats = {}
    stats.HP        = computeStat(baseStats.HP, level, true)
    stats.Attack    = computeStat(baseStats.Attack, level)
    stats.Defense   = computeStat(baseStats.Defense, level)
    stats.SpAttack  = computeStat(baseStats.SpAttack, level)
    stats.SpDefense = computeStat(baseStats.SpDefense, level)
    stats.Speed     = computeStat(baseStats.Speed, level)
    return stats
end

local function serializeCombatantForClient(combatant)
    return {
        Name      = combatant.DisplayName,
        Species   = combatant.SpeciesId,
        Types     = combatant.Types,
        Level     = combatant.Level,
        HP        = combatant.CurrentHP,
        MaxHP     = combatant.Stats.HP,
        Attack    = combatant.Stats.Attack,
        Defense   = combatant.Stats.Defense,
        SpAttack  = combatant.Stats.SpAttack,
        SpDefense = combatant.Stats.SpDefense,
        Speed     = combatant.Stats.Speed,
        OrigData  = shallowCopy(combatant.OriginalFishData),
    }
end

local function serializeMovesForClient(combatant)
    local moves = {}
    for _, move in ipairs(combatant.Moves) do
        moves[#moves + 1] = {
            Id          = move.Id,
            Name        = move.Name,
            Type        = move.Type,
            Category    = move.Category,
            Power       = move.Power,
            Accuracy    = move.Accuracy,
            Priority    = move.Priority,
            PP          = move.PP,
            MaxPP       = move.MaxPP,
            Description = move.Description,
        }
    end
    return moves
end

local function buildPreviewStats(speciesId)
    local species = CombatData.GetSpecies(speciesId)
    local fishBase = FishData[speciesId]

    if not species then
        return {
            Type    = speciesId,
            Types   = { speciesId },
            MaxHP   = 50,
            HP      = 50,
            Attack  = 40,
            Defense = 40,
            Speed   = 40,
            Level   = 50,
            OrigData = shallowCopy(fishBase),
        }
    end

    local level = 50
    local stats = buildStats(species.BaseStats or DEFAULT_BASE_STATS, level)
    return {
        Type     = species.PrimaryType or speciesId,
        Types    = { species.PrimaryType, species.SecondaryType },
        MaxHP    = stats.HP,
        HP       = stats.HP,
        Attack   = stats.Attack,
        Defense  = stats.Defense,
        Speed    = stats.Speed,
        Level    = level,
        DisplayName = species.DisplayName,
        OrigData = shallowCopy(fishBase),
    }
end

local function buildCombatant(fishEntry, ownerId)
    local speciesId = (fishEntry and (fishEntry.Type or fishEntry.DataName)) or fishEntry or "Unknown"
    local fishBaseData = FishData[speciesId]
    local speciesData = CombatData.GetSpecies(speciesId)

    local baseStats = (speciesData and speciesData.BaseStats) or DEFAULT_BASE_STATS
    local level = computeLevel(fishEntry, fishBaseData)
    local stats = buildStats(baseStats, level)

    local displayName = (speciesData and speciesData.DisplayName)
        or (fishBaseData and fishBaseData.DisplayName)
        or speciesId

    local types = {
        (speciesData and speciesData.PrimaryType) or (fishBaseData and fishBaseData.Type) or "Water",
        speciesData and speciesData.SecondaryType,
    }

    local availableMoves = CombatData.GetAvailableMoves(speciesId, level)
    local moves = {}
    local moveMap = {}
    for _, entry in ipairs(availableMoves) do
        local def = entry.Definition
        local move = {
            Id          = entry.Id,
            Name        = def.Name,
            Type        = def.Type,
            Category    = def.Category or "physical",
            Power       = def.Power or 0,
            Accuracy    = def.Accuracy or 100,
            Priority    = def.Priority or 0,
            MaxPP       = def.PP or 5,
            PP          = def.PP or 5,
            Description = def.Description or "",
            CritChance  = def.CritChance,
            Effect      = def.Effect,
        }
        moves[#moves + 1] = move
        moveMap[move.Id] = move
    end

    local combatant = {
        OwnerId          = ownerId,
        SpeciesId        = speciesId,
        DisplayName      = displayName,
        Level            = level,
        Types            = types,
        BaseStats        = shallowCopy(baseStats),
        Stats            = stats,
        CurrentHP        = stats.HP,
        Moves            = moves,
        MoveMap          = moveMap,
        StatStages       = { Attack = 0, Defense = 0, SpAttack = 0, SpDefense = 0, Speed = 0, Accuracy = 0, Evasion = 0 },
        Status           = {},
        OriginalFishData = shallowCopy(fishEntry),
    }

    return combatant
end

local function computeDamage(attacker, defender, move)
    local statStage = (move.Category == "special") and attacker.StatStages.SpAttack or attacker.StatStages.Attack
    local atkStat = (move.Category == "special") and attacker.Stats.SpAttack or attacker.Stats.Attack
    local defStage = (move.Category == "special") and defender.StatStages.SpDefense or defender.StatStages.Defense
    local defStat = (move.Category == "special") and defender.Stats.SpDefense or defender.Stats.Defense

    atkStat = atkStat * getStageMultiplier(statStage)
    defStat = defStat * getStageMultiplier(defStage)

    local baseDamage = (((2 * attacker.Level / 5) + 2) * move.Power * (atkStat / math.max(defStat, 1))) / 50 + 2
    local variance = math.random(85, 100) / 100
    local stab = 1
    for _, t in ipairs(attacker.Types) do
        if t and t == move.Type then
            stab = 1.5
            break
        end
    end

    local typeMultiplier = CombatData.GetTypeMultiplier(move.Type, defender.Types)
    local crit = false
    local critChance = move.CritChance or 0.0625
    if math.random() < critChance then
        crit = true
        baseDamage = baseDamage * 1.5
    end

    local scaled = math.floor(baseDamage * variance * stab * typeMultiplier)
    local damage = (typeMultiplier == 0) and 0 or math.max(1, scaled)
    return damage, typeMultiplier, crit
end

local function applyMoveEffect(effect, attacker, defender, messages)
    if not effect then
        return
    end

    if effect.Kind == "ModifyStat" then
        local target = effect.Target == "opponent" and defender or attacker
        local stat = effect.Stat or "Attack"
        local prev = target.StatStages[stat] or 0
        local newValue = math.clamp(prev + (effect.Stages or 0), -MAX_STAGE, MAX_STAGE)
        target.StatStages[stat] = newValue

        if effect.Message then
            local targetName = target.DisplayName
            table.insert(messages, string.format(effect.Message, targetName))
        end
    end
end

local function pushUpdateToPlayers(duel, state, extra)
    extra = extra or {}
    local chalCombatant = duel.combatants[duel.challengerId]
    local recvCombatant = duel.combatants[duel.targetId]

    local payload = {
        state = state,
        duelId = duel.id,
        challengerId = duel.challengerId,
        receiverId   = duel.targetId,
        challengerStats = serializeCombatantForClient(chalCombatant),
        receiverStats   = serializeCombatantForClient(recvCombatant),
        challengerMoves = serializeMovesForClient(chalCombatant),
        receiverMoves   = serializeMovesForClient(recvCombatant),
        currentTurn     = (duel.turn == duel.challengerId) and "challenger" or "receiver",
        log             = extra.log,
        winner          = extra.winner,
    }

    payload.challengerFish = payload.challengerStats
    payload.receiverFish = payload.receiverStats

    local challenger = Players:GetPlayerByUserId(duel.challengerId)
    local receiver   = Players:GetPlayerByUserId(duel.targetId)

    if challenger then
        DuelUpdate:FireClient(challenger, payload)
    end
    if receiver then
        DuelUpdate:FireClient(receiver, payload)
    end
end

local function finalizeDuel(duel, winnerPlayer, loserPlayer)
    local stakes = duel.stakes or {}

    for _, key in ipairs({ "challenger", "target" }) do
        local stake = stakes[key]
        if stake and stake.fishData then
            local ownerPlayer = Players:GetPlayerByUserId(stake.owner)
            if ownerPlayer then
                local ok, err = InventoryManager:AddFish(ownerPlayer, stake.fishData)
                if not ok then
                    warn("DuelManager: failed to restore fish:", err)
                end
            end
        end
    end

    if duel.endCallBack then
        duel.endCallBack(duel.id)
    end
    activeDuels[duel.id] = nil
end

function DuelManager:CreateChallenge(challenger, target, callBack)
    if not challenger or not target then
        return nil, "invalid players"
    end

    if challenger.UserId == target.UserId then
        return nil, "cannot challenge self"
    end

    local id = HttpService:GenerateGUID(false)
    local duel = {
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

    local chalCombatant = buildCombatant(fish1, duel.challengerId)
    local recvCombatant = buildCombatant(fish2, duel.targetId)

    duel.combatants = {
        [duel.challengerId] = chalCombatant,
        [duel.targetId]     = recvCombatant,
    }

    local first = (chalCombatant.Stats.Speed > recvCombatant.Stats.Speed) and duel.challengerId
        or (recvCombatant.Stats.Speed > chalCombatant.Stats.Speed and duel.targetId
            or ((math.random(0, 1) == 0) and duel.challengerId or duel.targetId))

    duel.turn = first

    pushUpdateToPlayers(duel, "start", {
        log = {
            string.format("%s affronte %s !", chalCombatant.DisplayName, recvCombatant.DisplayName),
        },
    })

    return true, duel
end

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

    if typeof(action) ~= "table" then
        return
    end

    local combat = duel.combatants
    local attacker = combat[player.UserId]

    if not attacker then
        return
    end

    local defenderId = (player.UserId == duel.challengerId) and duel.targetId or duel.challengerId
    local defender = combat[defenderId]

    if not defender then
        return
    end

    local messages = {}

    if action.action == "move" then
        local moveId = action.moveId
        local move = moveId and attacker.MoveMap[moveId]
        if not move then
            DuelUpdate:FireClient(player, {
                state = "notice",
                message = "Ce mouvement est indisponible.",
                duelId = duelId,
            })
            return
        end

        if move.PP <= 0 then
            DuelUpdate:FireClient(player, {
                state = "notice",
                message = "Plus de PP pour cette capacité !",
                duelId = duelId,
            })
            return
        end

        move.PP -= 1
        table.insert(messages, string.format("%s utilise %s !", attacker.DisplayName, move.Name))

        local accuracy = move.Accuracy or 100
        local hit = true
        if accuracy < 100 then
            hit = math.random(1, 100) <= accuracy
        end

        if hit and move.Category ~= "status" and move.Power and move.Power > 0 then
            local damage, multiplier, crit = computeDamage(attacker, defender, move)
            defender.CurrentHP = math.max(0, defender.CurrentHP - damage)

            table.insert(messages, string.format("%s subit %d dégâts.", defender.DisplayName, damage))

            if crit then
                table.insert(messages, "Coup critique !")
            end

            if multiplier > 1 then
                table.insert(messages, "C'est super efficace !")
            elseif multiplier > 0 and multiplier < 1 then
                table.insert(messages, "Ce n'est pas très efficace...")
            elseif multiplier == 0 then
                table.insert(messages, "Cela n'a aucun effet !")
            end

            applyMoveEffect(move.Effect, attacker, defender, messages)
        elseif hit then
            applyMoveEffect(move.Effect, attacker, defender, messages)
        else
            table.insert(messages, "Mais l'attaque échoue !")
        end
    elseif action.action == "pass" then
        table.insert(messages, string.format("%s prend le temps de se repositionner...", attacker.DisplayName))
    else
        return
    end

    if defender.CurrentHP <= 0 then
        duel.state = "finished"
        local winner = Players:GetPlayerByUserId(player.UserId)
        local loser  = Players:GetPlayerByUserId(defenderId)

        table.insert(messages, string.format("%s est K.O.!", defender.DisplayName))

        pushUpdateToPlayers(duel, "end", {
            log = messages,
            winner = (winner and winner.Name) or attacker.DisplayName,
        })

        finalizeDuel(duel, winner, loser)
        return
    end

    duel.turn = defenderId

    pushUpdateToPlayers(duel, "update", {
        log = messages,
    })
end

function DuelManager:GetDuel(id)
    return activeDuels[id]
end

function DuelManager:BuildCombatStats(Type)
    return buildPreviewStats(Type)
end

function DuelManager:BuildPreviewStats(Type)
    return buildPreviewStats(Type)
end

function DuelManager:ClearDuel(id)
    activeDuels[id] = nil
end

return DuelManager
