-- ServerStorage/Modules/CombatData.lua
--
-- Centralises combat configuration for duel battles.
-- Designers can tweak fish base stats, learnsets, move power,
-- accuracy, PP and type interactions in one place without touching
-- the combat engine implementation.
--
-- Each fish species references a list of move unlocks; a move becomes
-- usable when the fish level is equal or higher than `UnlockLevel`.
-- Levels are currently derived from the fish growth ratio (0-100%)
-- and clamped between level 1 and 100.
--
-- Type effectiveness multipliers follow the classic Pokémon pattern:
-- 2 for super effective, 0.5 for not very effective and 0 for immune.
-- Any missing combination defaults to 1.

local CombatData = {}

-- Known combat types. Colours are handy for UI feedback.
CombatData.Types = {
    Water    = { DisplayName = "Eau",     Color = Color3.fromRGB(64, 156, 255) },
    Electric = { DisplayName = "Électrik", Color = Color3.fromRGB(255, 220, 65) },
    Plant    = { DisplayName = "Plante",  Color = Color3.fromRGB(90, 192, 90) },
    Earth    = { DisplayName = "Terre",   Color = Color3.fromRGB(182, 142, 88) },
    Ice      = { DisplayName = "Glace",   Color = Color3.fromRGB(150, 220, 255) },
    Dark     = { DisplayName = "Sombre",  Color = Color3.fromRGB(62, 62, 95) },
    Normal   = { DisplayName = "Normal",  Color = Color3.fromRGB(200, 200, 200) },
}

-- Type matchup chart.
CombatData.TypeChart = {
    Water = { Fire = 2, Rock = 2, Earth = 2, Plant = 0.5, Electric = 0.5, Water = 0.5 },
    Electric = { Water = 2, Plant = 0.5, Earth = 0, Electric = 0.5 },
    Plant = { Water = 2, Earth = 2, Plant = 0.5, Fire = 0.5, Ice = 0.5 },
    Earth = { Electric = 2, Plant = 0.5, Water = 0.5 },
    Ice = { Plant = 2, Water = 0.5, Ice = 0.5 },
    Dark = { Psychic = 2, Dark = 0.5 },
    Normal = {},
}

-- Move definitions. `Effect` entries are declarative so they can be
-- applied on the server without additional code changes.
CombatData.Moves = {
    aqua_jet = {
        Name = "Jet d'eau",
        Type = "Water",
        Category = "physical",
        Power = 40,
        Accuracy = 100,
        Priority = 1,
        PP = 25,
        Description = "Attaque aqueuse extrêmement rapide (priorité +1).",
    },
    tidal_wave = {
        Name = "Raz-de-marée",
        Type = "Water",
        Category = "special",
        Power = 80,
        Accuracy = 85,
        PP = 10,
        Description = "Un puissant torrent d'eau qui peut submerger l'adversaire.",
    },
    scale_guard = {
        Name = "Bouclier d'écailles",
        Type = "Normal",
        Category = "status",
        Accuracy = 100,
        PP = 20,
        Description = "Renforce les écailles du lanceur pour augmenter sa défense.",
        Effect = {
            Kind = "ModifyStat",
            Target = "self",
            Stat = "Defense",
            Stages = 1,
            Message = "%s voit sa défense augmenter !",
        },
    },
    focus_current = {
        Name = "Courant focal",
        Type = "Water",
        Category = "status",
        Accuracy = 100,
        PP = 20,
        Description = "Le poisson concentre l'énergie du courant pour augmenter son attaque.",
        Effect = {
            Kind = "ModifyStat",
            Target = "self",
            Stat = "Attack",
            Stages = 1,
            Message = "%s renforce son attaque !",
        },
    },
    fin_slash = {
        Name = "Tranche-nageoire",
        Type = "Normal",
        Category = "physical",
        Power = 55,
        Accuracy = 100,
        PP = 30,
        CritChance = 0.1,
        Description = "Le lanceur taille l'adversaire avec sa nageoire acérée.",
    },
    mud_shot = {
        Name = "Jet de vase",
        Type = "Earth",
        Category = "special",
        Power = 55,
        Accuracy = 95,
        PP = 15,
        Description = "Projette de la vase qui ralentit la cible.",
        Effect = {
            Kind = "ModifyStat",
            Target = "opponent",
            Stat = "Speed",
            Stages = -1,
            Message = "La vitesse de %s baisse !",
        },
    },
    lightning_burst = {
        Name = "Éclair fulgurant",
        Type = "Electric",
        Category = "special",
        Power = 75,
        Accuracy = 90,
        PP = 10,
        Description = "Un arc électrique qui peut terrasser les poissons d'eau.",
    },
    ice_spike = {
        Name = "Pique de glace",
        Type = "Ice",
        Category = "special",
        Power = 65,
        Accuracy = 95,
        PP = 15,
        Description = "Lance un projectile gelé sur l'adversaire.",
    },
    dark_lunge = {
        Name = "Assaut sombre",
        Type = "Dark",
        Category = "physical",
        Power = 70,
        Accuracy = 95,
        PP = 15,
        Description = "Attaque sournoise qui profite de l'ombre de l'océan.",
    },
}

-- Fish combat profiles. Only the values defined here need to change
-- when balancing the duel feature.
CombatData.Species = {
    Goldfish = {
        DisplayName = "Poisson rouge",
        PrimaryType = "Water",
        SecondaryType = nil,
        BaseStats = { HP = 44, Attack = 48, Defense = 43, SpAttack = 50, SpDefense = 50, Speed = 56 },
        MoveSet = {
            { Move = "aqua_jet",    UnlockLevel = 1 },
            { Move = "scale_guard", UnlockLevel = 3 },
            { Move = "tidal_wave",  UnlockLevel = 12 },
        },
    },
    CatFish = {
        DisplayName = "Poisson chat",
        PrimaryType = "Earth",
        SecondaryType = "Water",
        BaseStats = { HP = 60, Attack = 60, Defense = 50, SpAttack = 45, SpDefense = 50, Speed = 40 },
        MoveSet = {
            { Move = "mud_shot",    UnlockLevel = 1 },
            { Move = "fin_slash",   UnlockLevel = 5 },
            { Move = "scale_guard", UnlockLevel = 8 },
        },
    },
    BlueMerou = {
        DisplayName = "Mérou bleu",
        PrimaryType = "Water",
        SecondaryType = "Ice",
        BaseStats = { HP = 52, Attack = 55, Defense = 60, SpAttack = 65, SpDefense = 60, Speed = 48 },
        MoveSet = {
            { Move = "aqua_jet",   UnlockLevel = 1 },
            { Move = "ice_spike",  UnlockLevel = 7 },
            { Move = "focus_current", UnlockLevel = 10 },
        },
    },
    Esturgeon = {
        DisplayName = "Esturgeon",
        PrimaryType = "Water",
        SecondaryType = "Normal",
        BaseStats = { HP = 70, Attack = 60, Defense = 70, SpAttack = 50, SpDefense = 65, Speed = 35 },
        MoveSet = {
            { Move = "scale_guard", UnlockLevel = 1 },
            { Move = "fin_slash",   UnlockLevel = 4 },
            { Move = "tidal_wave",  UnlockLevel = 14 },
        },
    },
    Tuna = {
        DisplayName = "Thon",
        PrimaryType = "Water",
        SecondaryType = "Electric",
        BaseStats = { HP = 55, Attack = 75, Defense = 50, SpAttack = 60, SpDefense = 50, Speed = 78 },
        MoveSet = {
            { Move = "aqua_jet",       UnlockLevel = 1 },
            { Move = "lightning_burst", UnlockLevel = 9 },
            { Move = "focus_current",  UnlockLevel = 6 },
        },
    },
    Shark = {
        DisplayName = "Requin",
        PrimaryType = "Dark",
        SecondaryType = "Water",
        BaseStats = { HP = 70, Attack = 90, Defense = 65, SpAttack = 65, SpDefense = 50, Speed = 85 },
        MoveSet = {
            { Move = "dark_lunge",   UnlockLevel = 1 },
            { Move = "fin_slash",    UnlockLevel = 5 },
            { Move = "tidal_wave",   UnlockLevel = 15 },
            { Move = "focus_current", UnlockLevel = 10 },
        },
    },
}

function CombatData.GetSpecies(speciesId)
    return CombatData.Species[speciesId]
end

function CombatData.GetMove(moveId)
    return CombatData.Moves[moveId]
end

function CombatData.GetTypeDefinition(typeId)
    return CombatData.Types[typeId]
end

function CombatData.GetTypeColor(typeId)
    local typeDef = CombatData.GetTypeDefinition(typeId)
    return typeDef and typeDef.Color or nil
end

function CombatData.GetTypeDisplayName(typeId)
    local typeDef = CombatData.GetTypeDefinition(typeId)
    return (typeDef and typeDef.DisplayName) or typeId
end

function CombatData.GetTypeMultiplier(moveType, defenderTypes)
    if not moveType then
        return 1
    end

    local multiplier = 1
    local typeRow = CombatData.TypeChart[moveType]
    if not typeRow then
        return multiplier
    end

    defenderTypes = defenderTypes or {}
    for _, defType in ipairs(defenderTypes) do
        if defType then
            local bonus = typeRow[defType]
            if bonus then
                multiplier *= bonus
            end
        end
    end

    return multiplier
end

function CombatData.GetAvailableMoves(speciesId, level)
    local species = CombatData.GetSpecies(speciesId)
    if not species then
        return {}
    end

    local available = {}
    local moveSet = species.MoveSet or {}

    for _, entry in ipairs(moveSet) do
        if level >= entry.UnlockLevel then
            local move = CombatData.GetMove(entry.Move)
            if move then
                table.insert(available, {
                    Id = entry.Move,
                    Definition = move,
                })
            end
        end
    end

    if #available == 0 then
        local fallback = CombatData.GetMove("fin_slash")
        if fallback then
            table.insert(available, {
                Id = "fin_slash",
                Definition = fallback,
            })
        end
    end

    return available
end

function CombatData.GetSpeciesDisplayName(speciesId)
    local species = CombatData.GetSpecies(speciesId)
    if species then
        return species.DisplayName or speciesId
    end
    return speciesId
end

return CombatData
