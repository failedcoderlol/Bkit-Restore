local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScriptExporter"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 450, 0, 300)
frame.Position = UDim2.new(0.5, -225, 0.5, -150)
frame.Parent = screenGui

local exportButton = Instance.new("TextButton")
exportButton.Size = UDim2.new(1, -20, 0, 50)
exportButton.Position = UDim2.new(0, 10, 0, 10)
exportButton.Text = "Export All Scripts"
exportButton.TextScaled = true
exportButton.Parent = frame

local copyBox = Instance.new("TextBox")
copyBox.Size = UDim2.new(1, -20, 1, -80)
copyBox.Position = UDim2.new(0, 10, 0, 70)
copyBox.MultiLine = true
copyBox.ClearTextOnFocus = false
copyBox.TextWrapped = false
copyBox.TextXAlignment = Enum.TextXAlignment.Left
copyBox.TextYAlignment = Enum.TextYAlignment.Top
copyBox.TextEditable = true
copyBox.Text = ""
copyBox.Parent = frame

exportButton.MouseButton1Click:Connect(function()
	local output = {}

	for _, obj in ipairs(game:GetDescendants()) do
		if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
			local success, source = pcall(function()
				return obj.Source
			end)

			if success then
				table.insert(output, ("\n\n===== %s =====\n"):format(obj:GetFullName()))
				table.insert(output, source)
			end
		end
	end

	local finalText = table.concat(output, "\n")

	copyBox.Text = finalText
	print(finalText)
end)
