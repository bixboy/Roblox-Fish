-- ServerStorage/Modules/InventoryManager.lua
-- Centralized inventory management responsible for persisting, validating,
-- and transforming inventory entries. Runs on the server.

local DataStoreService = game:GetService("DataStoreService")
local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local ServerStorage    = game:GetService("ServerStorage")

local INVENTORY_DS  = DataStoreService:GetDataStore("InventoryData")
local FurnitureData = require(ServerStorage.Data:WaitForChild("FurnitureData"))
local FishData      = require(ServerStorage.Data:WaitForChild("FishData"))
local ItemCatalog   = require(ServerStorage.Data:WaitForChild("ItemCatalog"))

local InventoryManager = {}
InventoryManager.__index = InventoryManager

export type InventoryEntry = string | {
    Id: string?,
    Type: string,
    Hunger: number?,
    Growth: number?,
    IsMature: boolean?,
    Rarity: number?,
    Egg: boolean?,
    Hatch: number?,
}

local EntryKind = {
    CatalogItem = "CatalogItem",
    Fish        = "Fish",
    Egg         = "Egg",
}

-- In-memory cache keyed by userId string
local cache: {[string]: { Items: {InventoryEntry} }} = {}

local function generateId(): string
    return HttpService:GenerateGUID(false)
end

local function identifyEntry(entry: InventoryEntry): string?
    local entryType = typeof(entry)

    if entryType == "string" then
        return EntryKind.CatalogItem
    elseif entryType == "table" then
        if entry.Egg then
            return EntryKind.Egg
        elseif entry.Type ~= nil then
            return EntryKind.Fish
        end
    end

    return nil
end

local function cloneFishEntry(entry)
    return {
        Id       = entry.Id or generateId(),
        Type     = entry.Type,
        Hunger   = entry.Hunger or 0,
        Growth   = entry.Growth or 0,
        IsMature = entry.IsMature == true,
        Rarity   = entry.Rarity,
    }
end

local function cloneEggEntry(entry)
    return {
        Id    = entry.Id or generateId(),
        Type  = entry.Type,
        Egg   = true,
        Hatch = entry.Hatch or 0,
    }
end

local function compressItems(items: {InventoryEntry})
    local stacked, counts = {}, {}

    for _, entry in ipairs(items) do
        local kind = identifyEntry(entry)

        if kind == EntryKind.CatalogItem then
            counts[entry] = (counts[entry] or 0) + 1
        elseif kind == EntryKind.Egg then
            table.insert(stacked, {
                Egg   = true,
                Type  = entry.Type,
                Hatch = entry.Hatch,
                Id    = entry.Id,
            })
        elseif kind == EntryKind.Fish then
            table.insert(stacked, {
                Type     = entry.Type,
                Hunger   = entry.Hunger,
                Growth   = entry.Growth,
                IsMature = entry.IsMature,
                Rarity   = entry.Rarity,
                Id       = entry.Id,
            })
        end
    end

    for itemId, count in pairs(counts) do
        table.insert(stacked, {
            Id    = itemId,
            Count = count,
        })
    end

    return stacked
end

local function expandItems(items)
    local expanded = {}

    for _, entry in ipairs(items) do
        if typeof(entry) ~= "table" then
            table.insert(expanded, entry)
            continue
        end

        if entry.Id and entry.Count then
            for _ = 1, entry.Count do
                table.insert(expanded, entry.Id)
            end
            continue
        end

        if entry.Egg then
            table.insert(expanded, cloneEggEntry(entry))
            continue
        end

        if entry.Type then
            table.insert(expanded, cloneFishEntry(entry))
            continue
        end
    end

    return expanded
end

local function decodeItems(raw)
    if raw == nil or raw == "" then
        return { Items = {} }
    end

    if typeof(raw) == "table" then
        local itemsArray = raw.Items or raw
        if typeof(itemsArray) == "table" then
            return { Items = expandItems(itemsArray) }
        end
        return { Items = {} }
    end

    local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
    if decodeOk and typeof(decoded) == "table" then
        local itemsArray = decoded.Items or decoded
        if typeof(itemsArray) == "table" then
            return { Items = expandItems(itemsArray) }
        end
    end

    return { Items = {} }
end

local function loadData(userId: string)
    local ok, raw = pcall(function()
        return INVENTORY_DS:GetAsync(userId)
    end)

    if not ok then
        warn(("[InventoryManager] Failed to load inventory for %s: %s"):format(userId, tostring(raw)))
        return { Items = {} }
    end

    return decodeItems(raw)
end

local function getCacheEntry(player: Player)
    local userId = tostring(player.UserId)
    local data = cache[userId]

    if not data then
        data = loadData(userId)
        cache[userId] = data
    end

    return userId, data
end

local function validateCatalogItem(itemId: string)
    if ItemCatalog[itemId] or FurnitureData[itemId] then
        return true
    end
    return false, ("Unknown catalog item '%s'"):format(itemId)
end

local function validateFishEntry(entry)
    local config = FishData[entry.Type]
    if not config then
        return false, ("Unknown fish type '%s'"):format(tostring(entry.Type))
    end

    entry.Id       = entry.Id or generateId()
    entry.Hunger   = entry.Hunger or 0
    entry.Growth   = entry.Growth or 0
    entry.IsMature = entry.IsMature == true
    entry.Rarity   = entry.Rarity or config.Rarity

    return true
end

local function validateEggEntry(entry)
    local config = FishData[entry.Type]
    if not config then
        return false, ("Unknown egg type '%s'"):format(tostring(entry.Type))
    end

    entry.Id    = entry.Id or generateId()
    entry.Egg   = true
    entry.Hatch = entry.Hatch or 0

    return true
end

local function normalizeEntry(entry: InventoryEntry)
    local kind = identifyEntry(entry)

    if kind == EntryKind.CatalogItem then
        local ok, err = validateCatalogItem(entry)
        if not ok then
            return nil, err
        end
        return entry
    elseif kind == EntryKind.Fish then
        local clone = cloneFishEntry(entry)
        local ok, err = validateFishEntry(clone)
        if not ok then
            return nil, err
        end
        return clone
    elseif kind == EntryKind.Egg then
        local clone = cloneEggEntry(entry)
        local ok, err = validateEggEntry(clone)
        if not ok then
            return nil, err
        end
        return clone
    end

    return nil, "Unsupported inventory entry"
end

local function removeIf(items, predicate)
    for index, value in ipairs(items) do
        local shouldRemove, payload = predicate(value)
        if shouldRemove then
            table.remove(items, index)
            return true, payload
        end
    end

    return false
end

-- Public API -----------------------------------------------------------------

function InventoryManager:Load(player: Player)
    local userId = tostring(player.UserId)
    cache[userId] = loadData(userId)
    return cache[userId]
end

function InventoryManager:Save(player: Player)
    local userId, data = getCacheEntry(player)

    if not data then
        return false, "No data to save"
    end

    local payload = HttpService:JSONEncode({
        Items = compressItems(data.Items),
    })

    local ok, err = pcall(function()
        INVENTORY_DS:SetAsync(userId, payload)
    end)

    if not ok then
        warn(("[InventoryManager] Failed to save inventory for %s: %s"):format(userId, tostring(err)))
    end

    return ok, err
end

function InventoryManager:GetItems(player: Player)
    local _, data = getCacheEntry(player)
    return data.Items
end

function InventoryManager:ClearInventory(player: Player)
    local userId, data = getCacheEntry(player)
    data.Items = {}
    cache[userId] = data
    return self:Save(player)
end

function InventoryManager:AddItem(player: Player, entry: InventoryEntry)
    local normalized, err = normalizeEntry(entry)
    if not normalized then
        return false, err
    end

    local _, data = getCacheEntry(player)
    table.insert(data.Items, normalized)
    return true
end

function InventoryManager:AddItemByName(player: Player, itemName: string, dataType: string?)
    local entryId

    if dataType == "Furniture" then
        local furniture = FurnitureData[itemName]
        if not furniture then
            return false, ("Unknown furniture '%s'"):format(itemName)
        end
        entryId = itemName
    else
        if not ItemCatalog[itemName] then
            return false, ("Unknown catalog item '%s'"):format(itemName)
        end
        entryId = itemName
    end

    return self:AddItem(player, entryId)
end

function InventoryManager:AddFish(player: Player, fishData)
    if typeof(fishData) ~= "table" then
        return false, "Invalid fish payload"
    end

    local entry = {
        Id       = fishData.Id,
        Type     = fishData.Type,
        Hunger   = fishData.Hunger,
        Growth   = fishData.Growth,
        IsMature = fishData.IsMature,
        Rarity   = fishData.Rarity,
    }

    return self:AddItem(player, entry)
end

function InventoryManager:AddEgg(player: Player, eggData)
    if typeof(eggData) ~= "table" then
        return false, "Invalid egg payload"
    end

    local entry = {
        Id    = eggData.Id,
        Type  = eggData.Type,
        Egg   = true,
        Hatch = eggData.Hatch,
    }

    return self:AddItem(player, entry)
end

function InventoryManager:RemoveItem(player: Player, itemId: string)
    local items = self:GetItems(player)
    local removed = removeIf(items, function(value)
        return value == itemId
    end)

    if removed then
        return true
    end

    return false, ("Item '%s' not found"):format(itemId)
end

function InventoryManager:RemoveFish(player: Player, fishId: string)
    local items = self:GetItems(player)
    local removed, data = removeIf(items, function(value)
        if typeof(value) == "table" and not value.Egg and value.Id == fishId then
            return true, value
        end
        return false
    end)

    if removed then
        return true, data
    end

    return false, ("No fish with Id %s"):format(fishId)
end

function InventoryManager:RemoveEgg(player: Player, eggId: string)
    local items = self:GetItems(player)
    local removed, data = removeIf(items, function(value)
        if typeof(value) == "table" and value.Egg and value.Id == eggId then
            return true, value
        end
        return false
    end)

    if removed then
        return true, data
    end

    return false, ("No egg with Id %s"):format(eggId)
end

local function buildCatalogDetail(itemId)
    local furniture = FurnitureData[itemId]
    if furniture then
        return {
            Id        = itemId,
            Type      = "Furniture",
            Name      = furniture.DisplayName or furniture.Name,
            DataName  = itemId,
            modelName = furniture.ModelName,
        }
    end

    local catalogEntry = ItemCatalog[itemId]
    if catalogEntry then
        return {
            Id        = itemId,
            Type      = catalogEntry.Type,
            Name      = catalogEntry.Name,
            DataName  = itemId,
            Price     = catalogEntry.Price,
            LootBoxId = catalogEntry.LootBoxId,
            Size      = catalogEntry.Size,
            Path      = catalogEntry.Path,
        }
    end

    return nil
end

local function buildFishDetail(entry)
    local fishConfig = FishData[entry.Type]
    if not fishConfig then
        return nil
    end

    return {
        Id       = entry.Id,
        Type     = "Fish",
        Name     = fishConfig.DisplayName,
        DataName = entry.Type,
        Price    = fishConfig.Price or 0,
        Hunger   = entry.Hunger,
        Growth   = entry.Growth,
        IsMature = entry.IsMature,
        Rarity   = entry.Rarity or fishConfig.Rarity,
    }
end

local function buildEggDetail(entry)
    local fishConfig = FishData[entry.Type]
    if not fishConfig then
        return nil
    end

    return {
        Id       = entry.Id,
        Type     = "Egg",
        Name     = (fishConfig.DisplayName or entry.Type) .. " Egg",
        DataName = entry.Type,
        Hatch    = entry.Hatch,
        Rarity   = fishConfig.Rarity,
    }
end

local function matchesCategory(detail, category)
    if category == nil or category == "All" then
        return true
    end

    if category == "FishEgg" then
        return detail.Type == "Fish" or detail.Type == "Egg"
    end

    if category == "Other" then
        return detail.Type ~= "Fish" and detail.Type ~= "Egg"
    end

    return detail.Type == category
end

function InventoryManager:GetDetailedItems(player: Player, category: string?)
    local detailed = {}
    local rawItems = self:GetItems(player)

    for _, entry in ipairs(rawItems) do
        local detail
        local kind = identifyEntry(entry)

        if kind == EntryKind.CatalogItem then
            detail = buildCatalogDetail(entry)
        elseif kind == EntryKind.Fish then
            detail = buildFishDetail(entry)
        elseif kind == EntryKind.Egg then
            detail = buildEggDetail(entry)
        end

        if detail and matchesCategory(detail, category) then
            table.insert(detailed, detail)
        end
    end

    return detailed
end

Players.PlayerAdded:Connect(function(player)
    InventoryManager:Load(player)
end)

Players.PlayerRemoving:Connect(function(player)
    InventoryManager:Save(player)
end)

return InventoryManager
