local RNGStyleLaserVFX = {}

local EffectsFolder = workspace:FindFirstChild("Effects") or workspace

function RNGStyleLaserVFX.FireMeshLaser(origin, direction, length)
	if not EffectsFolder then return end

	-- === Noyau du laser ===
	local laser = Instance.new("Part")
	laser.Anchored = true
	laser.CanCollide = false
	laser.Size = Vector3.new(1, 1, length) -- axe Z = longueur
	laser.CFrame = CFrame.new(origin, origin + direction) * CFrame.new(0, 0, -length/2)
		* CFrame.Angles(math.rad(90), 0, 0) -- on aligne Y sur Z
	laser.Material = Enum.Material.Neon
	laser.Color = Color3.fromRGB(100, 180, 255)
	laser.Transparency = 0
	laser.Parent = EffectsFolder

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	mesh.Scale = Vector3.new(6, length/2, 6) -- Y = longueur/2, XZ = epaisseur
	mesh.Parent = laser

	-- === Halo externe ===
	local halo = Instance.new("Part")
	halo.Anchored = true
	halo.CanCollide = false
	halo.Size = Vector3.new(1, 1, length)
	halo.CFrame = laser.CFrame
	halo.Material = Enum.Material.Neon
	halo.Color = Color3.fromRGB(180, 240, 255)
	halo.Transparency = 0.6
	halo.Parent = EffectsFolder

	local haloMesh = Instance.new("SpecialMesh")
	haloMesh.MeshType = Enum.MeshType.Cylinder
	haloMesh.Scale = Vector3.new(10, length/2, 10) -- plus large
	haloMesh.Parent = halo

	-- === Lumiere ===
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 200, 255)
	light.Brightness = 1
	light.Range = 100
	light.Parent = laser

	-- === Particules de distorsion ===
	local distortion = Instance.new("ParticleEmitter")
	distortion.Texture = "rbxassetid://10849662557"
	distortion.Rate = 40
	distortion.Lifetime = NumberRange.new(0.3,0.6)
	distortion.Speed = NumberRange.new(0,0)
	distortion.Size = NumberSequence.new(2,0)
	distortion.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.3), NumberSequenceKeypoint.new(1,1)})
	distortion.Color = ColorSequence.new(Color3.fromRGB(180,240,255))
	distortion.ZOffset = 2
	distortion.LockedToPart = true
	distortion.Parent = halo

	-- === Arcs electriques ===
	local arcs = Instance.new("ParticleEmitter")
	arcs.Texture = "rbxassetid://446111271"
	arcs.Rate = 15
	arcs.Lifetime = NumberRange.new(0.2, 0.4)
	arcs.Speed = NumberRange.new(10, 20)
	arcs.Size = NumberSequence.new(0.8, 0)
	arcs.Color = ColorSequence.new(Color3.fromRGB(120,200,255))
	arcs.ZOffset = 3
	arcs.Parent = laser

	-- === Impact ===
	local impact = Instance.new("Part")
	impact.Anchored = true
	impact.CanCollide = false
	impact.Shape = Enum.PartType.Ball
	impact.Material = Enum.Material.Neon
	impact.Color = Color3.fromRGB(200, 240, 255)
	impact.Size = Vector3.new(8,8,8)
	impact.CFrame = CFrame.new(origin + direction * length)
	impact.Parent = EffectsFolder

	local impactBurst = Instance.new("ParticleEmitter")
	impactBurst.Texture = "rbxassetid://243098098"
	impactBurst.Rate = 0
	impactBurst.Lifetime = NumberRange.new(0.5,0.8)
	impactBurst.Speed = NumberRange.new(20,40)
	impactBurst.SpreadAngle = Vector2.new(180,180)
	impactBurst.Size = NumberSequence.new(2,0)
	impactBurst.Color = ColorSequence.new(Color3.fromRGB(200,255,255))
	impactBurst.Parent = impact
	impactBurst:Emit(80)

	-- === Shockwave ===
	local shock = Instance.new("Part")
	shock.Anchored = true
	shock.CanCollide = false
	shock.Material = Enum.Material.Neon
	shock.Shape = Enum.PartType.Ball
	shock.Color = Color3.fromRGB(200,230,255)
	shock.Transparency = 0.4
	shock.Size = Vector3.new(1,1,1)
	shock.CFrame = impact.CFrame
	shock.Parent = EffectsFolder

	task.spawn(function()
		for i = 1, 25 do
			shock.Size += Vector3.new(3,3,3)
			shock.Transparency = i/25
			task.wait(0.03)
		end
		shock:Destroy()
	end)

	-- === Fade out ===
	task.delay(1, function()
		for i = 1, 20 do
			laser.Transparency = i/20
			halo.Transparency = 0.6 + (i/20 * 0.4)
			impact.Transparency = i/20
			light.Brightness *= 0.8
			task.wait(0.05)
		end
		laser:Destroy()
		halo:Destroy()
		impact:Destroy()
	end)
end

return RNGStyleLaserVFX
