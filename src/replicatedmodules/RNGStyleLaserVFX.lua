--!strict
--[[
        RNGStyleLaserVFX
        Procedural mesh-based laser effect inspired by RNG-style attacks.
]]

local EffectsFolder = workspace:FindFirstChild("Effects") or workspace

local RNGStyleLaserVFX = {}

local function createPart(size: Vector3, cframe: CFrame, color: Color3, transparency: number, parent: Instance)
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Material = Enum.Material.Neon
        part.Size = size
        part.CFrame = cframe
        part.Color = color
        part.Transparency = transparency
        part.Parent = parent
        return part
end

function RNGStyleLaserVFX.FireMeshLaser(origin: Vector3, direction: Vector3, length: number)
        if length <= 0 then
                return
        end

        local folder = EffectsFolder
        local axisCFrame = CFrame.new(origin, origin + direction)
        local laserCFrame = axisCFrame * CFrame.new(0, 0, -length / 2) * CFrame.Angles(math.rad(90), 0, 0)

        local laser = createPart(Vector3.new(1, 1, length), laserCFrame, Color3.fromRGB(100, 180, 255), 0, folder)
        local laserMesh = Instance.new("SpecialMesh")
        laserMesh.MeshType = Enum.MeshType.Cylinder
        laserMesh.Scale = Vector3.new(6, length / 2, 6)
        laserMesh.Parent = laser

        local halo = createPart(Vector3.new(1, 1, length), laserCFrame, Color3.fromRGB(180, 240, 255), 0.6, folder)
        local haloMesh = Instance.new("SpecialMesh")
        haloMesh.MeshType = Enum.MeshType.Cylinder
        haloMesh.Scale = Vector3.new(10, length / 2, 10)
        haloMesh.Parent = halo

        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(150, 200, 255)
        light.Brightness = 1
        light.Range = 100
        light.Parent = laser

        local distortion = Instance.new("ParticleEmitter")
        distortion.Texture = "rbxassetid://10849662557"
        distortion.Rate = 40
        distortion.Lifetime = NumberRange.new(0.3, 0.6)
        distortion.Speed = NumberRange.new(0, 0)
        distortion.Size = NumberSequence.new(2, 0)
        distortion.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.3),
                NumberSequenceKeypoint.new(1, 1),
        })
        distortion.Color = ColorSequence.new(Color3.fromRGB(180, 240, 255))
        distortion.ZOffset = 2
        distortion.LockedToPart = true
        distortion.Parent = halo

        local arcs = Instance.new("ParticleEmitter")
        arcs.Texture = "rbxassetid://446111271"
        arcs.Rate = 15
        arcs.Lifetime = NumberRange.new(0.2, 0.4)
        arcs.Speed = NumberRange.new(10, 20)
        arcs.Size = NumberSequence.new(0.8, 0)
        arcs.Color = ColorSequence.new(Color3.fromRGB(120, 200, 255))
        arcs.ZOffset = 3
        arcs.Parent = laser

        local impactPosition = origin + direction * length
        local impact = createPart(Vector3.new(8, 8, 8), CFrame.new(impactPosition), Color3.fromRGB(200, 240, 255), 0, folder)
        impact.Shape = Enum.PartType.Ball

        local impactBurst = Instance.new("ParticleEmitter")
        impactBurst.Texture = "rbxassetid://243098098"
        impactBurst.Rate = 0
        impactBurst.Lifetime = NumberRange.new(0.5, 0.8)
        impactBurst.Speed = NumberRange.new(20, 40)
        impactBurst.SpreadAngle = Vector2.new(180, 180)
        impactBurst.Size = NumberSequence.new(2, 0)
        impactBurst.Color = ColorSequence.new(Color3.fromRGB(200, 255, 255))
        impactBurst.Parent = impact
        impactBurst:Emit(80)

        local shockwave = createPart(Vector3.new(1, 1, 1), CFrame.new(impactPosition), Color3.fromRGB(200, 230, 255), 0.4, folder)
        shockwave.Shape = Enum.PartType.Ball

        task.spawn(function()
                for step = 1, 25 do
                        shockwave.Size += Vector3.new(3, 3, 3)
                        shockwave.Transparency = step / 25
                        task.wait(0.03)
                end
                shockwave:Destroy()
        end)

        task.delay(1, function()
                for alpha = 1, 20 do
                        local value = alpha / 20
                        laser.Transparency = value
                        halo.Transparency = 0.6 + value * 0.4
                        impact.Transparency = value
                        light.Brightness *= 0.8
                        task.wait(0.05)
                end

                laser:Destroy()
                halo:Destroy()
                impact:Destroy()
        end)
end

return RNGStyleLaserVFX
