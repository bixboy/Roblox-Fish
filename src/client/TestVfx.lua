
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WaterSplashEffect = require(ReplicatedStorage.VFX:WaitForChild("WaterSplashEffect"))


while true do
	task.wait(3)

	local position = Vector3.new(
		0,
		5,
		0
	)

	local size = 1
	WaterSplashEffect.CreateWaterSplash(position, size)
end