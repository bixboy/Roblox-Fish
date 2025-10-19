-- ServerStorage/Data/ItemCatalog.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function findInstancePath(root, name)

	for _, child in ipairs(root:GetChildren()) do

		if child.Name == name then
			return child:GetFullName()
		end

		local sub = findInstancePath(child, name)
		if sub then
			return sub
		end

	end

	return nil
end

local itemCatalog = {
	
	----- Je sais pas -----
	bite      = { Name = "La grosse bite a dudule", Price = 1000, Type = "Tool" },
	sword01   = { Name = "epee de bois",     Price = 100,   Type = "Tool"       },
	shield01  = { Name = "Bouclier rouille", Price = 75,    Type = "Tool"       },
	potion01  = { Name = "Potion de soin",   Price = 50,    Type = "Consumable" },


	----- Loot-boxes -----
	classic_lb = {
		Name         = "Coffre Classique",
		Price        = 200,
		Type         = "Lootbox",
		LootBoxId    = "classic_lb",
	},
	
	rare_lb = {
		Name         = "Coffre Rare",
		Price        = 500,
		Type         = "Lootbox",
		LootBoxId    = "rare_lb",
	},
	
	epic_lb = {
		Name         = "Coffre epique",
		Price        = 1000,
		Type         = "Lootbox",
		LootBoxId    = "epic_lb",
	},
	
	
	----- Objects -----
	GoodSmallSupport = {
		Name         = "Beau Petit Support",
		Price        = 100,
		Type         = "Support",
		Size         = "Small",
	},
	
	SmallSupport = {
		Name         = "Support moche",
		Price        = 10,
		Type         = "Support",
		Size         = "Small",
	},
	
	Tree = {
		Name         = "Arbre",
		Price        = 20,
		Type         = "Object",
		Size         = "Small",
	},
	
	----- Furnitures -----
	Chest = {
		Name         = "Beau Coffre",
		Price        = 100,
		Type         = "Furniture",
		Size         = "Small",
	},

	Bridge = {
		Name         = "Beau Pont",
		Price        = 10,
		Type         = "Furniture",
		Size         = "Small",
	},
	
}

for key, data in pairs(itemCatalog) do

	local fullName = findInstancePath(ReplicatedStorage, key)
	if fullName then

		local path = fullName:gsub("^ReplicatedStorage%.", "")
		data.Path = path
	else

		warn(("ItemCatalog: impossible de trouver '%s' dans ReplicatedStorage"):format(key))
		data.Path = nil
	end

end

return itemCatalog