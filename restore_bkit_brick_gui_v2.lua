local output = {}

for _, obj in ipairs(game:GetDescendants()) do
	if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
		table.insert(output, "\n\n===== " .. obj:GetFullName() .. " =====\n")
		table.insert(output, obj.Source)
	end
end

print(table.concat(output, "\n"))
