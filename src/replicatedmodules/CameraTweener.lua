--!strict
--[[
        CameraTweener
        Light-weight helper to smoothly transition the camera between targets
        while remembering the previous player camera state.
]]

local RunService = game:GetService("RunService")

local CameraTweener = {}
CameraTweener.__index = CameraTweener

export type TweenHandle = RBXScriptConnection?

local camera: Camera = workspace.CurrentCamera
local defaultCameraCFrame: CFrame? = nil
local cframeStack: { CFrame } = {}
local activeTween: TweenHandle = nil

local function stopActiveTween()
        if activeTween then
                activeTween:Disconnect()
                activeTween = nil
        end
end

local function playTween(fromCFrame: CFrame, toCFrame: CFrame, duration: number, onComplete: (() -> ())?)
        stopActiveTween()

        local elapsed = 0
        activeTween = RunService.RenderStepped:Connect(function(deltaTime)
                elapsed += deltaTime
                local alpha = math.clamp(elapsed / duration, 0, 1)
                camera.CFrame = fromCFrame:Lerp(toCFrame, alpha)

                if alpha >= 1 then
                        stopActiveTween()
                        if onComplete then
                                task.spawn(onComplete)
                        end
                end
        end)
end

function CameraTweener.ZoomTo(model: Model, offset: Vector3?, duration: number?, onStart: (() -> ())?, onComplete: (() -> ())?)
        assert(model.PrimaryPart, "CameraTweener.ZoomTo requires the target model to have a PrimaryPart")

        table.insert(cframeStack, camera.CFrame)
        if not defaultCameraCFrame then
                defaultCameraCFrame = camera.CFrame
        end

        camera.CameraType = Enum.CameraType.Scriptable
        stopActiveTween()

        if onStart then
                task.spawn(onStart)
        end

        local desiredOffset = offset or Vector3.new(0, 2, 4)
        local targetCFrame = model.PrimaryPart.CFrame * CFrame.new(desiredOffset)
        playTween(cframeStack[#cframeStack], targetCFrame, duration or 0.5, onComplete)
end

function CameraTweener.ReturnToPlayer(duration: number?, onStart: (() -> ())?, onComplete: (() -> ())?)
        stopActiveTween()

        local resumeCFrame = table.remove(cframeStack)
        if not resumeCFrame then
                resumeCFrame = defaultCameraCFrame or camera.CFrame
                defaultCameraCFrame = nil
        end

        if onStart then
                task.spawn(onStart)
        end

        playTween(camera.CFrame, resumeCFrame, duration or 0.5, function()
                camera.CameraType = Enum.CameraType.Custom
                if onComplete then
                        task.spawn(onComplete)
                end
        end)
end

function CameraTweener.Reset()
        stopActiveTween()
        table.clear(cframeStack)
        defaultCameraCFrame = nil
        camera.CameraType = Enum.CameraType.Custom
end

return CameraTweener
