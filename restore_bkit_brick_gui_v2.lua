-- export_all_scripts_one_button.lua
-- One-button script exporter.
-- Use only in your own Roblox experience / Studio project.
-- Exports only script Source that the current environment is allowed to read.
-- Does not bypass locked/protected scripts.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local function nowStamp()
    return os.date("%Y-%m-%d_%H-%M-%S")
end

local function safeFullName(obj)
    local ok, result = pcall(function()
        return obj:GetFullName()
    end)
    return ok and result or tostring(obj)
end

local function canReadSource(obj)
    local ok, source = pcall(function()
        return obj.Source
    end)

    if ok and type(source) == "string" then
        return true, source
    end

    return false, tostring(source)
end

local function buildExportText()
    local output = {}
    local stats = {
        scanned = 0,
        exported = 0,
        unreadable = 0,
        skipped = 0,
    }

    table.insert(output, "=== SCRIPT EXPORT ===")
    table.insert(output, "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(output, "PlaceId: " .. tostring(game.PlaceId))
    table.insert(output, "JobId: " .. tostring(game.JobId))
    table.insert(output, "Note: Only readable script sources are exported. Locked/protected scripts are listed but not bypassed.")
    table.insert(output, "")

    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
            stats.scanned += 1

            local fullName = safeFullName(obj)

            -- Skip this exporter GUI's own generated objects to reduce clutter.
            if fullName:find("ScriptExporterOneButton", 1, true) then
                stats.skipped += 1
            else
                local ok, sourceOrErr = canReadSource(obj)

                if ok then
                    stats.exported += 1
                    table.insert(output, "\n\n===== " .. fullName .. " <" .. obj.ClassName .. "> =====\n")
                    table.insert(output, sourceOrErr)
                else
                    stats.unreadable += 1
                    table.insert(output, "\n\n===== UNREADABLE: " .. fullName .. " <" .. obj.ClassName .. "> =====\n")
                    table.insert(output, sourceOrErr)
                end
            end
        end
    end

    table.insert(output, 7, "Scripts scanned: " .. tostring(stats.scanned))
    table.insert(output, 8, "Sources exported: " .. tostring(stats.exported))
    table.insert(output, 9, "Unreadable/locked: " .. tostring(stats.unreadable))
    table.insert(output, 10, "Skipped exporter GUI: " .. tostring(stats.skipped))
    table.insert(output, 11, "")

    return table.concat(output, "\n"), stats
end

local function writeExportFile(text)
    local filename = "script_export_" .. tostring(game.PlaceId) .. "_" .. nowStamp() .. ".txt"

    if typeof(writefile) == "function" then
        writefile(filename, text)
        return true, filename
    end

    return false, "writefile is not available in this environment. Use the output box/clipboard instead."
end

local function copyText(text)
    if typeof(setclipboard) == "function" then
        local ok = pcall(setclipboard, text)
        if ok then
            return true
        end
    end

    if typeof(toclipboard) == "function" then
        local ok = pcall(toclipboard, text)
        if ok then
            return true
        end
    end

    return false
end

local parentGui
if LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui") then
    parentGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
else
    parentGui = game:GetService("CoreGui")
end

local old = parentGui:FindFirstChild("ScriptExporterOneButton")
if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "ScriptExporterOneButton"
gui.ResetOnSpawn = false
gui.Parent = parentGui

local frame = Instance.new("Frame")
frame.Name = "Frame"
frame.Size = UDim2.new(0, 420, 0, 180)
frame.Position = UDim2.new(0.5, -210, 0.5, -90)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
frame.BorderColor3 = Color3.fromRGB(0, 125, 255)
frame.Active = true
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -45, 0, 30)
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
exportButton.Name = "ExportAllScripts"
exportButton.Size = UDim2.new(1, -20, 0, 45)
exportButton.Position = UDim2.new(0, 10, 0, 40)
exportButton.Text = "EXPORT ALL SCRIPTS"
exportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
exportButton.Font = Enum.Font.Code
exportButton.TextSize = 18
exportButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
exportButton.BorderColor3 = Color3.fromRGB(90, 90, 90)
exportButton.Parent = frame

local statusBox = Instance.new("TextBox")
statusBox.Name = "Status"
statusBox.Size = UDim2.new(1, -20, 0, 78)
statusBox.Position = UDim2.new(0, 10, 0, 95)
statusBox.Text = "Click EXPORT ALL SCRIPTS.\nIf file writing is available, the file path will appear here."
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

-- Simple drag from title.
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
        local ok, result, stats = pcall(function()
            local text, exportStats = buildExportText()
            local wrote, pathOrErr = writeExportFile(text)

            local copiedPath = false
            local copiedText = false

            if wrote then
                copiedPath = copyText(pathOrErr)
            else
                copiedText = copyText(text)
            end

            return {
                text = text,
                stats = exportStats,
                wrote = wrote,
                pathOrErr = pathOrErr,
                copiedPath = copiedPath,
                copiedText = copiedText,
            }
        end)

        if not ok then
            statusBox.Text = "Export failed:\n" .. tostring(result)
            exportButton.Text = "EXPORT ALL SCRIPTS"
            return
        end

        if result.wrote then
            statusBox.Text =
                "Export complete.\n" ..
                "File path/name:\n" .. result.pathOrErr .. "\n\n" ..
                "Scripts scanned: " .. tostring(result.stats.scanned) .. "\n" ..
                "Sources exported: " .. tostring(result.stats.exported) .. "\n" ..
                "Unreadable/locked: " .. tostring(result.stats.unreadable) .. "\n" ..
                (result.copiedPath and "Path copied to clipboard." or "Path not copied; copy it from here.")
        else
            statusBox.Text =
                "Export complete, but no file was written.\n" ..
                result.pathOrErr .. "\n\n" ..
                "The full export was copied to clipboard if supported.\n" ..
                "Sources exported: " .. tostring(result.stats.exported)
        end

        print(result.text)
        exportButton.Text = "EXPORT ALL SCRIPTS"
    end)
end)
