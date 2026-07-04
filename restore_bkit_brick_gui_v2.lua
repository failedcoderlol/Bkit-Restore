local toolbar = plugin:CreateToolbar("Script Exporter")
local button = toolbar:CreateButton(
	"Export Scripts",
	"Collect all script source code",
	""
)

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	true,
	false,
	450,
	300,
	450,
	300
)

local widget = plugin:CreateDockWidgetPluginGui("ScriptExporterGui", widgetInfo)
widget.Title = "Script Exporter"

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
frame.Parent = widget

local exportButton = Instance.new("TextButton")
exportButton.Size = UDim2.new(1, -20, 0, 50)
exportButton.Position = UDim2.new(0, 10, 0, 10)
exportButton.Text = "Export All Scripts to Output"
exportButton.TextScaled = true
exportButton.Parent = frame

local copyBox = Instance.new("TextBox")
copyBox.Size = UDim2.new(1, -20, 1, -80)
copyBox.Position = UDim2.new(0, 10, 0, 70)
copyBox.Text = ""
copyBox.TextWrapped = false
copyBox.TextXAlignment = Enum.TextXAlignment.Left
copyBox.TextYAlignment = Enum.TextYAlignment.Top
copyBox.ClearTextOnFocus = false
copyBox.MultiLine = true
copyBox.Parent = frame

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

exportButton.MouseButton1Click:Connect(function()
	local output = {}

	for _, obj in ipairs(game:GetDescendants()) do
		if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
			table.insert(output, "\n\n===== " .. obj:GetFullName() .. " =====\n")
			table.insert(output, obj.Source)
		end
	end

	local finalText = table.concat(output, "\n")

	copyBox.Text = finalText
	print(finalText)
end)
