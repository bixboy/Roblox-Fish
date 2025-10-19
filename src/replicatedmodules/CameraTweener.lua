-- ReplicatedStorage.Modules.CameraTweener
local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")

local CameraTweener = {}
CameraTweener.__index = CameraTweener

-- state
local camera = workspace.CurrentCamera
local homeCFrame
local stack = {}
local activeTween


local function cancelActiveTween()
	if activeTween then
		activeTween:Disconnect()
		activeTween = nil
	end
end


-- Tween entre deux CFrame en un temps donne
local function doTween(fromCF, toCF, duration, onComplete)

	cancelActiveTween()
	
	local elapsed = 0

	activeTween = RunService.RenderStepped:Connect(function(dt)
		
		elapsed = elapsed + dt
		
		local alpha = math.clamp(elapsed / duration, 0, 1)
		camera.CFrame = fromCF:Lerp(toCF, alpha)
		
		if alpha >= 1 then
			
			cancelActiveTween()
			
			if onComplete then 
				pcall(onComplete)
			end
		end
		
	end)
end

-- Zoom vers une Instance (Model.PrimaryPart obligatoire)
function CameraTweener.ZoomTo(model, offset, duration, onStart, onComplete)
	
	assert(model.PrimaryPart, "CameraTweener.ZoomTo: model without PrimaryPart")
	table.insert(stack, camera.CFrame)
	
	if not homeCFrame then
		homeCFrame = camera.CFrame
	end

	camera.CameraType = Enum.CameraType.Scriptable
	cancelActiveTween()
	
	if onStart then pcall(onStart) end

	local ofs = offset or Vector3.new(0, 2, 4)
	local targetCF = model.PrimaryPart.CFrame * CFrame.new(ofs)
	doTween(stack[#stack], targetCF, duration or 0.5, onComplete)
	
end

-- Reviens sur le joueur
function CameraTweener.ReturnToPlayer(duration, onStart, onComplete)
	
	cancelActiveTween()
	
	local resumeCF = table.remove(stack)
	if not resumeCF then
		
		resumeCF  = homeCFrame or camera.CFrame
		homeCFrame = nil
	end
	
	if onStart then pcall(onStart) end
	
	doTween(camera.CFrame, resumeCF, duration or 0.5, function()
		camera.CameraType = Enum.CameraType.Custom
		if onComplete then pcall(onComplete) end
	end)
end

return CameraTweener