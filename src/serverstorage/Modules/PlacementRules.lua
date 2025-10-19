local ConfigPlacer = {}

-- Tolerance maximale entre position client et serveur
ConfigPlacer.MAX_OFFSET = 10

-- Distance maximale entre le joueur et l'objet a placer
ConfigPlacer.MAX_PLACE_DIST = 100

-- Chemins autorises pour le placement d'objets
ConfigPlacer.ALLOWED_PATHS = {
	["Assets.Supports.SmallSupport"] = true,
	["Assets.Supports.GoodSmallSupport"] = true,
	-- ajoute ici tous les chemins autoris�s
}

return ConfigPlacer
