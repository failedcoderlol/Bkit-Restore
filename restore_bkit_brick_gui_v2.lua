-- export_all_scripts_clipboard_gui.lua
-- One-button GUI script exporter.
-- Copies all readable Script / LocalScript / ModuleScript sources to clipboard.
-- Use only in your own Roblox experience / Studio project.
-- This does NOT bypass locked/protected scripts.

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local function safeFullName(obj)
    local ok, result = pcall(function()
        return obj:GetFullName()
    end)
    return ok and result or tostring(obj)
end

local function copyText(text)
    if typeof(setclipboard) == "function" then
        local ok = pcall(setclipboard, text)
        if ok then return true end
    end

    if typeof(toclipboard) == "function" then
        local ok = pcall(toclipboard, text)
        if ok then return true end
    end

    return false
end

local function readSource(obj)
    local ok, source = pcall(function()
        return obj.Source
    end)

    if ok and type(source) == "string" then
        return true, source
    end

    return false, tostring(source)
end

local function buildExportText(gui)
    local output = {}
    local scanned = 0
    local exported = 0
    local unreadable = 0
    local skipped = 0

    table.insert(output, "=== SCRIPT EXPORT ===")
    table.insert(output, "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(output, "PlaceId: " .. tostring(game.PlaceId))
    table.insert(output, "JobId: " .. tostring(game.JobId))
    table.insert(output, "Note: Only readable sources are exported. Locked/protected scripts are not bypassed.")
    table.insert(output, "")

    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
            scanned += 1

            if gui and (obj == gui or obj:IsDescendantOf(gui)) then
                skipped += 1
            else
                local ok, sourceOrErr = readSource(obj)
                local fullName = safeFullName(obj)

                if ok then
                    exported += 1
                    table.insert(output, "\n\n===== " .. fullName .. " <" .. obj.ClassName .. "> =====\n")
                    table.insert(output, sourceOrErr)
                else
                    unreadable += 1
                    table.insert(output, "\n\n===== UNREADABLE: " .. fullName .. " <" .. obj.ClassName .. "> =====\n")
                    table.insert(output, sourceOrErr)
                end
            end
        end
    end

    table.insert(output, 7, "Scripts scanned: " .. tostring(scanned))
    table.insert(output, 8, "Sources exported: " .. tostring(exported))
    table.insert(output, 9, "Unreadable/locked: " .. tostring(unreadable))
    table.insert(output, 10, "Skipped exporter GUI: " .. tostring(skipped))
    table.insert(output, 11, "")

    return table.concat(output, "\n"), {
        scanned = scanned,
        exported = exported,
        unreadable = unreadable,
        skipped = skipped,
    }
end

local parentGui
if LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui") then
    parentGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
else
    parentGui = CoreGui
end

local old = parentGui:FindFirstChild("ScriptExporterClipboardGUI")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "ScriptExporterClipboardGUI"
gui.ResetOnSpawn = false
gui.Parent = parentGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 430, 0, 210)
frame.Position = UDim2.new(0.5, -215, 0.5, -105)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
frame.BorderColor3 = Color3.fromRGB(0, 125, 255)
frame.Active = true
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 30)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Script Exporter"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.Code
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 30, 0, 24)
close.Position = UDim2.new(1, -36, 0, 3)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.Font = Enum.Font.Code
close.TextSize = 14
close.BackgroundColor3 = Color3.fromRGB(90, 25, 25)
close.BorderColor3 = Color3.fromRGB(80, 80, 80)
close.Parent = frame
close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

local exportButton = Instance.new("TextButton")
exportButton.Size = UDim2.new(1, -20, 0, 50)
exportButton.Position = UDim2.new(0, 10, 0, 40)
exportButton.Text = "EXPORT ALL SCRIPTS"
exportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
exportButton.Font = Enum.Font.Code
exportButton.TextSize = 18
exportButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
exportButton.BorderColor3 = Color3.fromRGB(90, 90, 90)
exportButton.Parent = frame

local statusBox = Instance.new("TextBox")
statusBox.Size = UDim2.new(1, -20, 0, 105)
statusBox.Position = UDim2.new(0, 10, 0, 98)
statusBox.Text = "Click EXPORT ALL SCRIPTS.\nThe export will be copied to clipboard.\nIf clipboard fails, it will be printed to console."
statusBox.TextColor3 = Color3.fromRGB(230, 230, 230)
statusBox.Font = Enum.Font.Code
statusBox.TextSize = 13
statusBox.TextWrapped = true
statusBox.TextXAlignment = Enum.TextXAlignment.Left
statusBox.TextYAlignment = Enum.TextYAlignment.Top
statusBox.ClearTextOnFocus = false
statusBox.MultiLine = true
statusBox.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
statusBox.BorderColor3 = Color3.fromRGB(65, 65, 65)
statusBox.Parent = frame

-- Drag GUI by title
do
    local UserInputService = game:GetService("UserInputService")
    local dragging = false
    local dragStart
    local startPos

    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)

    title.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

exportButton.MouseButton1Click:Connect(function()
    exportButton.Text = "EXPORTING..."
    statusBox.Text = "Scanning scripts..."

    task.spawn(function()
        local ok, result = pcall(function()
            local text, stats = buildExportText(gui)
            local copied = copyText(text)
            return {
                text = text,
                stats = stats,
                copied = copied,
            }
        end)

        if not ok then
            statusBox.Text = "Export failed:\n" .. tostring(result)
            exportButton.Text = "EXPORT ALL SCRIPTS"
            return
        end

        print(result.text)

        if result.copied then
            statusBox.Text =
                "✓ Export complete.\n\n" ..
                "Full export copied to clipboard.\n\n" ..
                "Scripts scanned: " .. tostring(result.stats.scanned) .. "\n" ..
                "Sources exported: " .. tostring(result.stats.exported) .. "\n" ..
                "Unreadable/locked: " .. tostring(result.stats.unreadable) .. "\n" ..
                "Skipped exporter GUI: " .. tostring(result.stats.skipped)
        else
            statusBox.Text =
                "Export complete, but clipboard failed.\n\n" ..
                "The full export was printed to console.\n\n" ..
                "Scripts scanned: " .. tostring(result.stats.scanned) .. "\n" ..
                "Sources exported: " .. tostring(result.stats.exported) .. "\n" ..
                "Unreadable/locked: " .. tostring(result.stats.unreadable)
        end

        exportButton.Text = "EXPORT ALL SCRIPTS"
    end)
end)
