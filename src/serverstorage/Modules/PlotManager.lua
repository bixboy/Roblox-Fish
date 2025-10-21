-- ServerStorage/Modules/PlotManager.lua
local CollectionService = game:GetService("CollectionService")
local DataStoreService  = game:GetService("DataStoreService")
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PLOTS_DS = DataStoreService:GetDataStore("PlotData")
local FishData = require(script.Parent.Parent.Data:WaitForChild("FishData"))

local PlotManager = {}
PlotManager.__index = PlotManager

local userPlots    = {}
local plotOwners   = {}
local objectOwners = {}

-- Helpers -------------------------------------------------------------------

local function keyOf(userId) return tostring(userId) end

local function round(n, d)
	local m = 10^d
	return math.floor(n * m + 0.5) / m
end

local function findObjectEntry(userData, supportId)
        for _, obj in ipairs(userData.Objects) do
                if obj.Id == supportId then
                        return obj
                end
        end
        return nil
end

-- Simule la croissance hors-ligne
function PlotManager:_simulateOfflineGrowth(fishList, dt)
	
	if dt <= 0 then return end

	for _, fish in ipairs(fishList) do
		local fd = FishData[fish.Type]
		if not fd then continue end

		local h0 = fish.Hunger or fd.MaxHunger
		fish.Hunger = math.max(0, h0 - fd.HungerDecay * dt)

		if not fish.IsMature then
			
			local hungerRatio = fish.Hunger / fd.MaxHunger
			local deltaG = fd.GrowthRate * dt * hungerRatio
			
			fish.Growth = math.min(fd.MaxGrowth, (fish.Growth or 0) + deltaG)
			fish.IsMature = fish.Growth >= fd.MaxGrowth
		end
	end
end

function PlotManager:Load(player)
	
	local key = keyOf(player.UserId)
	local ok, raw = pcall(function() return PLOTS_DS:GetAsync(key) end)
	local data = { HasClaim = false, LastLogout = nil, Objects = {} }

	if ok and raw then
		
		local success, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if success and type(decoded)=="table" and type(decoded.O)=="table" then
			
			for _, o in ipairs(decoded.O) do
				local entry = {
					Id     = o.i,
					Path   = o.p,
					Offset = o.o,
					Angles = o.a,
				}
				
				if o.q then
					
					local fishList = {}
					if o.q.f then
						for _, f in ipairs(o.q.f) do
							
							local newId = HttpService:GenerateGUID(false)
							table.insert(fishList, {
								Id       = newId,
								Type     = f.t,
								Hunger   = f.h,
								Growth   = f.g,
								IsMature = f.m == 1,
								Rarity   = f.r,
							})
						end
					end
					
					local furnList = {}
					if o.q.u then
						for _, u in ipairs(o.q.u) do
							table.insert(furnList, {
								Name = u.n,
								Slot = u.s,
							})
						end
					end
					
					local eggList = {}
                                        if o.q.e then
                                                for _, e in ipairs(o.q.e) do

                                                        local newId = HttpService:GenerateGUID(false)
                                                        local hatchValue = 0
                                                        if type(e.h) == "number" then
                                                                hatchValue = e.h
                                                        end

                                                        table.insert(eggList, {
                                                                Type  = e.n,
                                                                Hatch = hatchValue,
                                                                Id    = newId
                                                        })
                                                end
                                        end

                        entry.Aquarium = {
						Path      = o.q.p,
						Fish      = fishList,
						Furniture = furnList,
						Eggs      = eggList,
					}
				end
				table.insert(data.Objects, entry)
			end
			data.LastLogout = decoded.L
		end
	end

	-- Applique la croissance hors-ligne
	if data.LastLogout then
		
		local now = os.time()
		local dt = now - data.LastLogout
		
		for _, obj in ipairs(data.Objects) do
			
			if obj.Aquarium then
				self:_simulateOfflineGrowth(obj.Aquarium.Fish, dt) end
		end
		
		data.LastLogout = now
	end

	userPlots[player.UserId] = data
	return data
end

-- Serialise et persiste
function PlotManager:Save(player)
	
	local data = userPlots[player.UserId]
	if not data then return end

        local compact = { L = data.LastLogout, O = {} }
        for _, obj in ipairs(data.Objects) do

                local o = { p = obj.Path, i = obj.Id }

                if type(obj.Offset) == "table" then
                        local offset = {}
                        local hasOffset = false

                        for idx, value in ipairs(obj.Offset) do
                                local rounded = round(value, 3)
                                offset[idx] = rounded
                                if rounded ~= 0 then
                                        hasOffset = true
                                end
                        end

                        if hasOffset then
                                o.o = offset
                        end
                end

                if type(obj.Angles) == "table" then
                        local angles = {}
                        local hasAngles = false

                        for idx, value in ipairs(obj.Angles) do
                                local rounded = round(value, 3)
                                angles[idx] = rounded
                                if rounded ~= 0 then
                                        hasAngles = true
                                end
                        end

                        if hasAngles then
                                o.a = angles
                        end
                end

                if obj.Aquarium then

                        local aquarium = obj.Aquarium
                        local q = {}
                        local hasAquariumData = false

                        if aquarium.Path and aquarium.Path ~= "" then
                                q.p = aquarium.Path
                                hasAquariumData = true
                        end

                        if type(aquarium.Fish) == "table" and #aquarium.Fish > 0 then
                                local ftab = {}
                                for _, f in ipairs(aquarium.Fish) do

                                        local fish = { t = f.Type }
                                        local fishDefaults = FishData[f.Type]

                                        if f.Hunger and fishDefaults and f.Hunger ~= fishDefaults.MaxHunger then
                                                fish.h = round(f.Hunger, 1)
                                        end

                                        if f.Growth and f.Growth > 0 then
                                                fish.g = round(f.Growth, 1)
                                        end

                                        if f.IsMature then
                                                fish.m = 1
                                        end

                                        if f.Rarity and fishDefaults and f.Rarity ~= fishDefaults.Rarity then
                                                fish.r = f.Rarity
                                        end

                                        table.insert(ftab, fish)
                                end

                                if #ftab > 0 then
                                        q.f = ftab
                                        hasAquariumData = true
                                end
                        end

                        if type(aquarium.Furniture) == "table" and #aquarium.Furniture > 0 then
                                local utab = {}
                                for _, u in ipairs(aquarium.Furniture) do
                                        table.insert(utab, { n = u.Name, s = u.Slot })
                                end

                                if #utab > 0 then
                                        q.u = utab
                                        hasAquariumData = true
                                end
                        end

                        if type(aquarium.Eggs) == "table" and #aquarium.Eggs > 0 then
                                local etab = {}
                                for _, e in ipairs(aquarium.Eggs) do
                                        local egg = { n = e.Name }
                                        if type(e.Hatch) == "number" and e.Hatch > 0 then
                                                egg.h = math.floor(e.Hatch)
                                        end
                                        table.insert(etab, egg)
                                end

                                if #etab > 0 then
                                        q.e = etab
                                        hasAquariumData = true
                                end
                        end

                        if hasAquariumData then
                                o.q = q
                        end
                end
                table.insert(compact.O, o)
        end

	pcall(function()
		PLOTS_DS:SetAsync(keyOf(player.UserId), HttpService:JSONEncode(compact))
	end)
	
end

-- Gere la mise a jour des stats cete memoire (poisson ajoute/mis a jour)
function PlotManager:UpdateFishStats(playerUserId, supportModel, fishTable)
	
	local data = userPlots[playerUserId]
	if not data then return end

	local supportId = supportModel:GetAttribute("ObjectId")
	if not supportId then return end

	local obj = findObjectEntry(data, supportId)
	if not obj then return end
	obj.Aquarium = obj.Aquarium or { Path = "", Fish = {} }

	-- Indexe existants
	local existing = {}
	for idx, f in ipairs(obj.Aquarium.Fish) do
		existing[f.Id] = { data=f, idx=idx }
	end

	-- Merge / Insert
	for fishId, info in pairs(fishTable) do
		
		info.Id = fishId
		local ex = existing[fishId]
		if ex then
			
			for k,v in pairs(info) do
				if v ~= nil then 
					ex.data[k] = v
				end
			end
		else
			table.insert(obj.Aquarium.Fish, info)
		end
	end
end

-- Supprime un poisson du support
function PlotManager:RemoveFishFromSupport(playerUserId, supportModel, fishId)
	
	local data = userPlots[playerUserId]
	if not data then return end

	local supportId = supportModel:GetAttribute("ObjectId")
	local obj = findObjectEntry(data, supportId)
	if not (obj and obj.Aquarium) then return end

	for i, f in ipairs(obj.Aquarium.Fish) do
		
		if f.Id == fishId then
			
			table.remove(obj.Aquarium.Fish, i)
			break
		end
	end
	
end

function PlotManager:UpdateEggStats(playerUserId, supportModel, eggsTable)
	
	local data = userPlots[playerUserId]
	if not data then return end

	local supportId = supportModel:GetAttribute("ObjectId")
	if not supportId then return end

	local obj = findObjectEntry(data, supportId)
	if not obj then return end

	obj.Aquarium = obj.Aquarium or { Path = "", Fish = {}, Eggs = {} }
	obj.Aquarium.Eggs = obj.Aquarium.Eggs or {}

	local existing = {}
	for idx, e in ipairs(obj.Aquarium.Eggs) do
		existing[e.Id] = { data = e, idx = idx }
	end

	for eggId, info in pairs(eggsTable) do
		info.Id = eggId
		local ex = existing[eggId]
		if ex then
			for k, v in pairs(info) do
				if v ~= nil then 
					ex.data[k] = v
				end
			end
		else
			table.insert(obj.Aquarium.Eggs, {
				Id    = eggId,
				Name  = info.Type,
				Hatch = info.Hatch
			})
		end
	end
end

function PlotManager:RemoveEggFromSupport(playerUserId, supportModel, eggId)
	
	local data = userPlots[playerUserId]
	if not data then return end

	local supportId = supportModel:GetAttribute("ObjectId")
	if not supportId then return end

	local obj = findObjectEntry(data, supportId)
	if not (obj and obj.Aquarium and obj.Aquarium.Eggs) then return end

	for i, e in ipairs(obj.Aquarium.Eggs) do
		if e.Id == eggId then
			table.remove(obj.Aquarium.Eggs, i)
			break
		end
	end
end

-- Pose un objet / support
function PlotManager:AddObject(player, plotPart, clone)

        local data = userPlots[player.UserId]
        if not (data and data.HasClaim) then return end

        local cf
        if clone:IsA("Model") then
                cf = clone:GetPivot()
        elseif clone:IsA("BasePart") then
                cf = clone.CFrame
        end

        if not cf then
                return
        end

        local center = plotPart.Position
        local ofs = cf.Position - center
        local rx, ry, rz = cf:ToOrientation()

        local newId = HttpService:GenerateGUID(false)
        clone:SetAttribute("ObjectId", newId)

        objectOwners[player.UserId] = objectOwners[player.UserId] or {}
        objectOwners[player.UserId][newId] = true

        local entry = {
                Id      = newId,
                Path    = clone:GetAttribute("TemplatePath") or clone.Name,
                Offset  = { ofs.X, ofs.Y, ofs.Z },
                Angles  = { rx, ry, rz },
        }

        if CollectionService:HasTag(clone, "Support") then
                entry.Aquarium = { Path = "", Fish = {} }
        end

        table.insert(data.Objects, entry)
end

-- Retire un objet du plot
function PlotManager:RemoveObject(player, objectId)
	
	local uid = player.UserId
	local data = userPlots[uid]
	if not data then return end

	for i, obj in ipairs(data.Objects) do
		
		if obj.Id == objectId then
			
			table.remove(data.Objects, i)
			break
		end
	end

	if objectOwners[uid] then
		
		objectOwners[uid][objectId] = nil
		if next(objectOwners[uid]) == nil then
			objectOwners[uid] = nil end
	end

	-- self:Save(player)
end


-- Lie un modele d'aquarium  ason support en memoire
function PlotManager:AddAquariumToSupport(player, supportModel, aquariumInstance)
	
	local data = userPlots[player.UserId]
	if not data then return end

	local entry = findObjectEntry(data, supportModel:GetAttribute("ObjectId"))
	if not entry then return end

	entry.Aquarium = 
	{
		Path = aquariumInstance:GetAttribute("TemplatePath"),
		Fish = {}
	}
end

function PlotManager:AddFurnitureToAquarium(playerId, aquariumModel, furnitureName, slotIndex)
	
	local data = userPlots[playerId]
	if not data then 
		return end

	local supportId = aquariumModel:GetAttribute("ObjectId")
	if not supportId then 
		return end

	local obj = findObjectEntry(data, supportId)
	if not obj then 
		return end
	
	if not obj.Aquarium then 
		return end

	obj.Aquarium.Furniture = obj.Aquarium.Furniture or {}

	local replaced = false
	for _, furn in ipairs(obj.Aquarium.Furniture) do
		if furn.Slot == slotIndex then
			furn.Name = furnitureName
			replaced = true
			break
		end
	end

	if not replaced then
		table.insert(obj.Aquarium.Furniture, 
		{
			Name = furnitureName,
			Slot = slotIndex,
		})
	end
end

function PlotManager:RemoveFurnitureFromAquarium(player, aquariumModel, slotIndex)
	
	local data = userPlots[player]
	if not data then 
		return end

	local supportId = aquariumModel:GetAttribute("ObjectId")
	if not supportId then 
		return end

	local obj = findObjectEntry(data, supportId)
	if not (obj and obj.Aquarium and obj.Aquarium.Furniture) then 
		return end

	for i, furn in ipairs(obj.Aquarium.Furniture) do
		
		if furn.Slot == slotIndex then
			table.remove(obj.Aquarium.Furniture, i)			
			break
		end
	end
end

-- Claim / acces / nettoyage ------------------------------------------------

function PlotManager:ClaimPlot(player, plotPart)

        if not CollectionService:HasTag(plotPart, "Plot") then

                return false, "Terrain non revendiquable"
        end

        local data = userPlots[player.UserId] or self:Load(player)
        if data.HasClaim then

                return false, "Terrain deja revendique"
        end

        plotOwners[plotPart] = player.UserId
        data.HasClaim = true
        data.PlotPart = plotPart

        for _, inst in ipairs(plotPart:GetDescendants()) do

                if inst:GetAttribute("ObjectId") then
                        self:RegisterObjectOwner(player, inst)
                end

        end

        return true
end

function PlotManager:GetPlotOf(player)
        local data = userPlots[player.UserId]
        return data and data.PlotPart or nil
end

function PlotManager:GetObjects(player)
	return (userPlots[player.UserId] or {}).Objects or {}
end

function PlotManager:GetPlotAtPosition(pos)
	
	local result = workspace:Raycast(pos + Vector3.new(0,50,0), Vector3.new(0,-100,0))
	local inst = result and result.Instance
	
	return inst and CollectionService:HasTag(inst,"Plot") and inst or nil
end

function PlotManager:PlayerOwnsPlotAt(player, worldPos)
	
	local plot = self:GetPlotAtPosition(worldPos)
	
	return plot and plotOwners[plot] == player.UserId
end

function PlotManager:ClearData(player)
	
	local userId = player.UserId
	userPlots[userId] = {
		HasClaim    = false,
		LastLogout  = nil,
		Objects     = {}
	}
	-- ecrase le DataStore
	local key = keyOf(userId)
	local ok, err = pcall(function()
		PLOTS_DS:SetAsync(key, HttpService:JSONEncode({ L = nil, O = {} }))
	end)
	
	if not ok then
		warn(("[PlotManager] ClearData failed for %s: %s"):format(player.Name, err))
	end
end

function PlotManager:GetPlayerOwnObject(player, instance)
	
	local uid   = player.UserId
	local objId = instance:GetAttribute("ObjectId")
		
	return objectOwners[uid] and objectOwners[uid][objId]
end

function PlotManager:RegisterObjectOwner(player, instance)
	local uid    = player.UserId
	local objId  = instance:GetAttribute("ObjectId")
	if not objId then return end

	objectOwners[uid] = objectOwners[uid] or {}
	objectOwners[uid][objId] = true
end

-- Auto-load & save on join/leave
game.Players.PlayerAdded:Connect(function(p) PlotManager:Load(p) end)

game.Players.PlayerRemoving:Connect(function(p)
	
	local uid = p.UserId
	local data = userPlots[uid]
	
	if data then
		
		data.LastLogout = os.time()
		PlotManager:Save(p)
		
		if data.HasClaim and data.PlotPart then
			plotOwners[data.PlotPart] = nil
		end
		
	end

	objectOwners[uid] = nil
	userPlots[uid] = nil
end)

return PlotManager
