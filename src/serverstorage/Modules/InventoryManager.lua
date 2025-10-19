-- ServerStorage/InventoryManager.lua
local DataStoreService = game:GetService("DataStoreService")
local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local ServerStorage    = game:GetService("ServerStorage")

local INVENTORY_DS  = DataStoreService:GetDataStore("InventoryData")
local FurnitureData = require(ServerStorage.Data:WaitForChild("FurnitureData"))
local FishData      = require(ServerStorage.Data:WaitForChild("FishData"))
local ItemData      = require(ServerStorage.Data:WaitForChild("ItemCatalog"))

local InventoryManager = {}
InventoryManager.__index = InventoryManager

-- In-memory cache: userId ? { Items = { ... } }
local cache = {}

local function generateId()
	return HttpService:GenerateGUID(false)
end

-- Compresse les items en stacks
local function compressItems(items)
	
	local stacked, lookup = {}, {}

	for _, v in ipairs(items) do
		if type(v) == "string" then
			
			lookup[v] = (lookup[v] or 0) + 1


		elseif type(v) == "table" and v.Egg then -- Egg
			table.insert(stacked, {
				Egg   = true,
				Type  = v.Type,
				Hatch = v.Hatch
			})
		
		elseif type(v) == "table" and v.Type and not v.Egg then -- Poisson
			table.insert(stacked, {
				Type     = v.Type,
				Hunger   = v.Hunger,
				Growth   = v.Growth,
				IsMature = v.IsMature,
				Rarity   = v.Rarity,
			})
		end
	end

	for id, count in pairs(lookup) do
		table.insert(stacked, { Id = id, Count = count })
	end

	return stacked
end

-- Decompresse les stacks en liste normale
local function expandItems(items)
	local expanded = {}

	for _, v in ipairs(items) do
		if type(v) == "table" and v.Id and v.Count then
			
			for i = 1, v.Count do
				table.insert(expanded, v.Id)
			end
			
		elseif type(v) == "table" and v.Egg then -- Egg

			v.Id = generateId()
			table.insert(expanded, v)

		elseif type(v) == "table" and v.Type and not v.Egg then -- Fish
			
			v.Id = generateId()
			table.insert(expanded, v)

		else
			table.insert(expanded, v)
		end
	end

	return expanded
end

-- Internal loader
local function loadData(userId)

	local raw = INVENTORY_DS:GetAsync(userId) or ""
	local success, decoded = pcall(HttpService.JSONDecode, HttpService, raw)

	if success and type(decoded) == "table" and decoded.Items then
		return { Items = expandItems(decoded.Items) }
	end

	return { Items = {} }
end

-- PUBLIC API

function InventoryManager:Load(player)
	
	local userId = tostring(player.UserId)
	cache[userId] = loadData(userId)
	
	return cache[userId]
end

function InventoryManager:Save(player)
	
	local userId = tostring(player.UserId)
	local data   = cache[userId]

	if not data then
		return false, "No data to save" 
	end

	local toSave = 
	{
		Items = compressItems(data.Items)
	}

	local ok, err = pcall(function()
		INVENTORY_DS:SetAsync(userId, HttpService:JSONEncode(toSave))
	end)

	return ok, err
end

function InventoryManager:GetItems(player)
	
	local entry = cache[tostring(player.UserId)]
	
	return entry and entry.Items or {}
end

function InventoryManager:ClearInventory(player)
	
	local userId = tostring(player.UserId)
	cache[userId] = { Items = {} }
	
	pcall(function()
		INVENTORY_DS:SetAsync(userId, HttpService:JSONEncode(cache[userId]))
	end)
	
end

-- Generic adder
function InventoryManager:AddItem(player, entry)
	
	local userId = tostring(player.UserId)
	local data = cache[userId] or self:Load(player)
	
	if type(entry) == "string" then
		
		if not ItemData[entry] then
			return false, ("Unknown item ID '%s'"):format(entry)
		end

	elseif type(entry) == "table" then
		
		if not FishData[entry.Type] then
			return false, ("Invalid table type '%s'"):format(tostring(entry.Type))
		end
		
	else
		
		return false, "Invalid entry type"
	end
	
	table.insert(data.Items, entry)
	
	return true
end

function InventoryManager:AddItemByName(player, itemName, DataType)
	
	local userId = tostring(player.UserId)
	local data = cache[userId] or self:Load(player)
	
	local item
	if DataType == nil then
		
		item = ItemData[itemName]
		
	elseif DataType == "Furniture" then
		
		item = FurnitureData[itemName]		
	end
	
	if item then
		warn(item)

		table.insert(data.Items, item.Name)
		return true
	end
	
	return false
end

-- Fish-specific adder
function InventoryManager:AddFish(player, fishData)
	
	if type(fishData) ~= "table" or not FishData[fishData.Type] then
		return false, "Invalid fish"
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

-- Add egg
function InventoryManager:AddEgg(player, eggData)
	
	if type(eggData) ~= "table" or not eggData.Type then
		return false, "Invalid egg"
	end

	local entry = {
		Id    = eggData.Id,
		Type  = eggData.Type,
		Egg   = true,
		Hatch = eggData.Hatch,
	}

	return self:AddItem(player, entry)
end

-- Removal by predicate
local function removeIf(items, predicate)
	
	for i = 1, #items do
		
		local ok, data = predicate(items[i])
		if ok then
			
			table.remove(items, i)
			return true, data
		end
	end
	
	return false, nil
end

function InventoryManager:RemoveItem(player, itemId)
	
	local items = self:GetItems(player)
	return removeIf(items, function(v) return v == itemId end), "Item not found"
end

function InventoryManager:RemoveFish(player, fishId)
	
	local items = self:GetItems(player)
	local removed, data = removeIf(items, function(v)
		
        if type(v) == "table" and v.Id == fishId then
			return true, v
		end
			
        return false
    end)

    if removed then
        return true, data
    else
        return false, ("No fish with Id %s"):format(fishId)
    end
end

function InventoryManager:RemoveEgg(player, eggId)
	
	local items = self:GetItems(player)
	local removed, data = removeIf(items, function(v)
		
		if type(v) == "table" and v.Egg and v.Id == eggId then
			return true, v
		end
		
		return false
	end)

	if removed then
		return true, data
	else
		return false, ("No egg with Id %s"):format(eggId)
	end
end

-- Automatic hooks
Players.PlayerAdded:Connect(function(p) InventoryManager:Load(p) end)
Players.PlayerRemoving:Connect(function(p) InventoryManager:Save(p) end)

return InventoryManager