local promptPart = script.Parent:WaitForChild("PromptPart")
local prompt = promptPart:WaitForChild("ProximityPrompt")

local dialogues = require(script:WaitForChild("DialogueLines"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StartDialogue = ReplicatedStorage.Remotes:WaitForChild("StartDialogue")


prompt.ObjectText = script.Parent.Name

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DialogueDoneRemote = ReplicatedStorage:FindFirstChild("DialogueDoneRemote")

if not DialogueDoneRemote then
	

	DialogueDoneRemote = Instance.new("RemoteEvent")
	DialogueDoneRemote.Name = "DialogueDoneRemote"
	DialogueDoneRemote.Parent = ReplicatedStorage

	print("[Server] DialogueDoneRemote cr��")

end

prompt.Triggered:Connect(function(player)
	print("[Server] Prompt d�clench� par:", player.Name)

	if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
		
		StartDialogue:FireClient(player, script.Parent, dialogues.Lines)

		print("[Server] Dialogue envoy� au client", player.Name)
	end
end)
