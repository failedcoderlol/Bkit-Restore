-- restore_bkit_brick_gui_v2.lua
-- Bkit Restore Pro v2
-- For games you own/admin. Server-side restore must run on the server.
-- Client/executor mode can show GUI and inspect what the client can see, but any restore done from client is local-only.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ServerStorage = RunService:IsServer() and game:GetService("ServerStorage") or nil
local UserInputService = RunService:IsClient() and game:GetService("UserInputService") or nil

local Settings = {
    BrickName = "Brick",
    Position = Vector3.new(-38, 22, 26),
    Size = Vector3.new(4, 4, 4),
    Color = Color3.fromRGB(192, 192, 192),
    Transparency = 0,
    Reflectance = 0,
    Material = Enum.Material.Plastic,
    MaterialVariant = "",
    Anchored = true,
    Locked = true,
    Archivable = true,
    CanCollide = true,
    CanQuery = true,
    CanTouch = true,
    CastShadow = true,
    Massless = false,
    TopSurface = Enum.SurfaceType.Studs,
    BottomSurface = Enum.SurfaceType.Inlet,
    FrontSurface = Enum.SurfaceType.Smooth,
    BackSurface = Enum.SurfaceType.Smooth,
    LeftSurface = Enum.SurfaceType.Smooth,
    RightSurface = Enum.SurfaceType.Smooth,
    ReplaceExisting = false,
    AutoWatch = false,
    AutoWatchDelay = 2,
    MaxScanResults = 80,
    IncludeLineSnippets = true,
    StrictScriptSearch = false,
}

local function log(message)
    print("[Bkit Restore Pro] " .. tostring(message))
end

local function safeFullName(obj)
    local ok, result = pcall(function()
        return obj:GetFullName()
    end)
    return ok and result or tostring(obj)
end

local function formatValue(value)
    local t = typeof(value)
    if t == "Vector3" then
        return string.format("Vector3.new(%s, %s, %s)", value.X, value.Y, value.Z)
    elseif t == "Vector2" then
        return string.format("Vector2.new(%s, %s)", value.X, value.Y)
    elseif t == "Color3" then
        local r = math.floor(value.R * 255 + 0.5)
        local g = math.floor(value.G * 255 + 0.5)
        local b = math.floor(value.B * 255 + 0.5)
        return string.format("Color3.fromRGB(%d, %d, %d)", r, g, b)
    elseif t == "CFrame" then
        local x, y, z = value.X, value.Y, value.Z
        local rx, ry, rz = value:ToOrientation()
        if math.abs(rx) < 0.00001 and math.abs(ry) < 0.00001 and math.abs(rz) < 0.00001 then
            return string.format("CFrame.new(%s, %s, %s)", x, y, z)
        end
        return string.format("CFrame.new(%s, %s, %s) * CFrame.fromOrientation(%s, %s, %s)", x, y, z, rx, ry, rz)
    elseif t == "EnumItem" then
        return tostring(value)
    elseif t == "BrickColor" then
        return string.format("BrickColor.new(%q)", value.Name)
    elseif t == "boolean" or t == "number" then
        return tostring(value)
    elseif t == "string" then
        return string.format("%q", value)
    elseif value == nil then
        return "nil"
    end
    return tostring(value)
end

local function humanValue(value)
    local t = typeof(value)
    if t == "Vector3" then
        return string.format("%.3f, %.3f, %.3f", value.X, value.Y, value.Z)
    elseif t == "Color3" then
        return string.format("RGB(%d, %d, %d)", math.floor(value.R * 255 + 0.5), math.floor(value.G * 255 + 0.5), math.floor(value.B * 255 + 0.5))
    elseif t == "CFrame" then
        return string.format("Position %.3f, %.3f, %.3f", value.X, value.Y, value.Z)
    elseif t == "EnumItem" then
        return tostring(value)
    end
    return tostring(value)
end

local function safeGet(obj, prop)
    local ok, val = pcall(function()
        return obj[prop]
    end)
    if ok then
        return true, val
    end
    return false, val
end

local function vectorFromText(text, fallback)
    local nums = {}
    for n in tostring(text):gmatch("%-?%d+%.?%d*") do
        table.insert(nums, tonumber(n))
    end
    if #nums >= 3 then
        return Vector3.new(nums[1], nums[2], nums[3])
    end
    return fallback
end

local function colorFromText(text, fallback)
    local nums = {}
    for n in tostring(text):gmatch("%-?%d+%.?%d*") do
        table.insert(nums, tonumber(n))
    end
    if #nums >= 3 then
        return Color3.fromRGB(math.clamp(nums[1], 0, 255), math.clamp(nums[2], 0, 255), math.clamp(nums[3], 0, 255))
    end
    return fallback
end

local function enumFromName(enumType, text, fallback)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return fallback end
    text = text:gsub("Enum%.%w+%.", "")
    local ok, val = pcall(function()
        return enumType[text]
    end)
    if ok and val then return val end
    return fallback
end

local function getBrick()
    return ReplicatedStorage:FindFirstChild(Settings.BrickName)
end

local function getBrickStatusLine()
    local brick = getBrick()
    if not brick then
        return "MISSING: ReplicatedStorage." .. Settings.BrickName
    end
    if not brick:IsA("BasePart") then
        return "FOUND, BUT WRONG TYPE: " .. brick.ClassName .. " at " .. safeFullName(brick)
    end
    return string.format(
        "OK: %s | Size %.1f, %.1f, %.1f | Pos %.1f, %.1f, %.1f",
        safeFullName(brick),
        brick.Size.X, brick.Size.Y, brick.Size.Z,
        brick.Position.X, brick.Position.Y, brick.Position.Z
    )
end

local function makeBrick()
    local brick = Instance.new("Part")
    brick.Name = Settings.BrickName
    brick.Size = Settings.Size
    brick.CFrame = CFrame.new(Settings.Position)
    brick.Anchored = Settings.Anchored
    brick.Locked = Settings.Locked
    brick.Archivable = Settings.Archivable
    brick.CanCollide = Settings.CanCollide
    brick.CanQuery = Settings.CanQuery
    brick.CanTouch = Settings.CanTouch
    brick.CastShadow = Settings.CastShadow
    brick.Massless = Settings.Massless
    brick.Material = Settings.Material
    brick.Color = Settings.Color
    brick.Transparency = Settings.Transparency
    brick.Reflectance = Settings.Reflectance
    if Settings.MaterialVariant ~= "" then
        pcall(function() brick.MaterialVariant = Settings.MaterialVariant end)
    end
    brick.TopSurface = Settings.TopSurface
    brick.BottomSurface = Settings.BottomSurface
    brick.FrontSurface = Settings.FrontSurface
    brick.BackSurface = Settings.BackSurface
    brick.LeftSurface = Settings.LeftSurface
    brick.RightSurface = Settings.RightSurface
    brick.Parent = ReplicatedStorage
    return brick
end

local function restoreBrick(forceReplace)
    local existing = getBrick()
    if existing and not forceReplace and not Settings.ReplaceExisting then
        return false, "Brick already exists. Use Force Restore or turn Replace Existing ON."
    end

    if existing then
        existing:Destroy()
    end

    local brick = makeBrick()
    local modeNote = RunService:IsServer() and "server" or "client/local-only"
    return true, "Restored " .. safeFullName(brick) .. " (" .. modeNote .. ")"
end

local function loadSettingsFromBrick()
    local brick = getBrick()
    if not brick or not brick:IsA("BasePart") then
        return false, "No valid BasePart found at ReplicatedStorage." .. Settings.BrickName
    end

    Settings.Position = brick.Position
    Settings.Size = brick.Size
    Settings.Color = brick.Color
    Settings.Transparency = brick.Transparency
    Settings.Reflectance = brick.Reflectance
    Settings.Material = brick.Material
    Settings.Anchored = brick.Anchored
    Settings.Locked = brick.Locked
    Settings.Archivable = brick.Archivable
    Settings.CanCollide = brick.CanCollide
    Settings.CanQuery = brick.CanQuery
    Settings.CanTouch = brick.CanTouch
    Settings.CastShadow = brick.CastShadow
    Settings.Massless = brick.Massless
    Settings.TopSurface = brick.TopSurface
    Settings.BottomSurface = brick.BottomSurface
    Settings.FrontSurface = brick.FrontSurface
    Settings.BackSurface = brick.BackSurface
    Settings.LeftSurface = brick.LeftSurface
    Settings.RightSurface = brick.RightSurface
    local ok, matVar = safeGet(brick, "MaterialVariant")
    if ok then Settings.MaterialVariant = matVar or "" end
    return true, "Loaded settings from current brick."
end

local function backupBrick()
    if not RunService:IsServer() then
        return false, "Backup requires server-side execution."
    end

    local brick = getBrick()
    if not brick then
        return false, "No brick exists to back up."
    end

    local old = ServerStorage:FindFirstChild("BkitBrickBackup")
    if old then old:Destroy() end

    local backup = brick:Clone()
    backup.Name = "BkitBrickBackup"
    backup.Parent = ServerStorage
    return true, "Backup saved to ServerStorage.BkitBrickBackup"
end

local function restoreFromBackup()
    if not RunService:IsServer() then
        return false, "Restore from backup requires server-side execution."
    end

    local backup = ServerStorage:FindFirstChild("BkitBrickBackup")
    if not backup then
        return false, "No backup found in ServerStorage."
    end

    local existing = getBrick()
    if existing then existing:Destroy() end

    local clone = backup:Clone()
    clone.Name = Settings.BrickName
    clone.Parent = ReplicatedStorage
    return true, "Restored from backup."
end

local autoThreadRunning = false
local function setAutoWatch(enabled)
    Settings.AutoWatch = enabled
    if enabled and not autoThreadRunning then
        autoThreadRunning = true
        task.spawn(function()
            while Settings.AutoWatch do
                if not getBrick() then
                    local _, msg = restoreBrick(true)
                    log("Auto-watch: " .. tostring(msg))
                end
                task.wait(math.max(1, tonumber(Settings.AutoWatchDelay) or 2))
            end
            autoThreadRunning = false
        end)
    end
end

local propertyList = {
    "Name", "ClassName", "Archivable", "Parent", "Size", "CFrame", "Position", "Orientation", "PivotOffset",
    "Anchored", "Locked", "Massless", "CanCollide", "CanQuery", "CanTouch", "CollisionGroup",
    "Material", "MaterialVariant", "Color", "BrickColor", "Transparency", "Reflectance", "CastShadow",
    "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface",
    "AssemblyMass", "AssemblyCenterOfMass", "AssemblyLinearVelocity", "AssemblyAngularVelocity",
    "CustomPhysicalProperties",
}

local function collectBrickInfo()
    local brick = getBrick()
    local lines = {}
    table.insert(lines, "=== BKIT BRICK INFO ===")
    table.insert(lines, "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(lines, "Mode: " .. (RunService:IsServer() and "Server" or "Client/local"))
    table.insert(lines, "PlaceId: " .. tostring(game.PlaceId))
    table.insert(lines, "JobId: " .. tostring(game.JobId))
    table.insert(lines, "Target: ReplicatedStorage." .. Settings.BrickName)
    table.insert(lines, "Status: " .. getBrickStatusLine())
    table.insert(lines, "")

    if not brick then
        table.insert(lines, "No brick found, so no properties/attributes/children can be read.")
        return table.concat(lines, "\n")
    end

    table.insert(lines, "Path: " .. safeFullName(brick))
    table.insert(lines, "Class: " .. brick.ClassName)
    table.insert(lines, "")
    table.insert(lines, "--- Properties ---")
    for _, prop in ipairs(propertyList) do
        if prop == "ClassName" then
            table.insert(lines, "ClassName = " .. brick.ClassName)
        elseif prop == "Parent" then
            table.insert(lines, "Parent = " .. safeFullName(brick.Parent))
        else
            local ok, val = safeGet(brick, prop)
            if ok then
                table.insert(lines, prop .. " = " .. humanValue(val))
            end
        end
    end

    table.insert(lines, "")
    table.insert(lines, "--- Attributes ---")
    local attrs = brick:GetAttributes()
    local anyAttr = false
    for k, v in pairs(attrs) do
        anyAttr = true
        table.insert(lines, tostring(k) .. " = " .. humanValue(v))
    end
    if not anyAttr then table.insert(lines, "No attributes.") end

    table.insert(lines, "")
    table.insert(lines, "--- Tags ---")
    local okTags, tags = pcall(function() return CollectionService:GetTags(brick) end)
    if okTags and #tags > 0 then
        table.insert(lines, table.concat(tags, ", "))
    else
        table.insert(lines, "No tags or tags not readable.")
    end

    table.insert(lines, "")
    table.insert(lines, "--- Children ---")
    local children = brick:GetChildren()
    if #children == 0 then
        table.insert(lines, "No children.")
    else
        for _, child in ipairs(children) do
            table.insert(lines, child.Name .. " <" .. child.ClassName .. "> " .. safeFullName(child))
        end
    end

    return table.concat(lines, "\n")
end

local function generateRecreateCode()
    local brick = getBrick()
    local use = {}
    if brick and brick:IsA("BasePart") then
        use.Name = brick.Name
        use.Size = brick.Size
        use.CFrame = brick.CFrame
        use.Anchored = brick.Anchored
        use.Locked = brick.Locked
        use.Archivable = brick.Archivable
        use.CanCollide = brick.CanCollide
        use.CanQuery = brick.CanQuery
        use.CanTouch = brick.CanTouch
        use.CastShadow = brick.CastShadow
        use.Massless = brick.Massless
        use.Material = brick.Material
        use.Color = brick.Color
        use.Transparency = brick.Transparency
        use.Reflectance = brick.Reflectance
        use.TopSurface = brick.TopSurface
        use.BottomSurface = brick.BottomSurface
        use.FrontSurface = brick.FrontSurface
        use.BackSurface = brick.BackSurface
        use.LeftSurface = brick.LeftSurface
        use.RightSurface = brick.RightSurface
        local ok, matVar = safeGet(brick, "MaterialVariant")
        use.MaterialVariant = ok and matVar or ""
    else
        use.Name = Settings.BrickName
        use.Size = Settings.Size
        use.CFrame = CFrame.new(Settings.Position)
        use.Anchored = Settings.Anchored
        use.Locked = Settings.Locked
        use.Archivable = Settings.Archivable
        use.CanCollide = Settings.CanCollide
        use.CanQuery = Settings.CanQuery
        use.CanTouch = Settings.CanTouch
        use.CastShadow = Settings.CastShadow
        use.Massless = Settings.Massless
        use.Material = Settings.Material
        use.Color = Settings.Color
        use.Transparency = Settings.Transparency
        use.Reflectance = Settings.Reflectance
        use.TopSurface = Settings.TopSurface
        use.BottomSurface = Settings.BottomSurface
        use.FrontSurface = Settings.FrontSurface
        use.BackSurface = Settings.BackSurface
        use.LeftSurface = Settings.LeftSurface
        use.RightSurface = Settings.RightSurface
        use.MaterialVariant = Settings.MaterialVariant
    end

    local code = {}
    table.insert(code, "local ReplicatedStorage = game:GetService(\"ReplicatedStorage\")")
    table.insert(code, "local existing = ReplicatedStorage:FindFirstChild(" .. formatValue(use.Name) .. ")")
    table.insert(code, "if existing then existing:Destroy() end")
    table.insert(code, "")
    table.insert(code, "local brick = Instance.new(\"Part\")")
    table.insert(code, "brick.Name = " .. formatValue(use.Name))
    table.insert(code, "brick.Size = " .. formatValue(use.Size))
    table.insert(code, "brick.CFrame = " .. formatValue(use.CFrame))
    table.insert(code, "brick.Anchored = " .. tostring(use.Anchored))
    table.insert(code, "brick.Locked = " .. tostring(use.Locked))
    table.insert(code, "brick.Archivable = " .. tostring(use.Archivable))
    table.insert(code, "brick.CanCollide = " .. tostring(use.CanCollide))
    table.insert(code, "brick.CanQuery = " .. tostring(use.CanQuery))
    table.insert(code, "brick.CanTouch = " .. tostring(use.CanTouch))
    table.insert(code, "brick.CastShadow = " .. tostring(use.CastShadow))
    table.insert(code, "brick.Massless = " .. tostring(use.Massless))
    table.insert(code, "brick.Material = " .. formatValue(use.Material))
    table.insert(code, "brick.Color = " .. formatValue(use.Color))
    table.insert(code, "brick.Transparency = " .. tostring(use.Transparency))
    table.insert(code, "brick.Reflectance = " .. tostring(use.Reflectance))
    if use.MaterialVariant and use.MaterialVariant ~= "" then
        table.insert(code, "pcall(function() brick.MaterialVariant = " .. formatValue(use.MaterialVariant) .. " end)")
    end
    table.insert(code, "brick.TopSurface = " .. formatValue(use.TopSurface))
    table.insert(code, "brick.BottomSurface = " .. formatValue(use.BottomSurface))
    table.insert(code, "brick.FrontSurface = " .. formatValue(use.FrontSurface))
    table.insert(code, "brick.BackSurface = " .. formatValue(use.BackSurface))
    table.insert(code, "brick.LeftSurface = " .. formatValue(use.LeftSurface))
    table.insert(code, "brick.RightSurface = " .. formatValue(use.RightSurface))
    table.insert(code, "brick.Parent = ReplicatedStorage")
    table.insert(code, "print(\"[Bkit Restore] ReplicatedStorage.\" .. brick.Name .. \" restored\")")
    return table.concat(code, "\n")
end

local function lineContainsDependency(line, targetName)
    if Settings.StrictScriptSearch then
        return line:find("ReplicatedStorage", 1, true) and line:find(targetName, 1, true)
    end
    if line:find(targetName, 1, true) then return true end
    if line:find("WaitForChild", 1, true) and line:find(targetName, 1, true) then return true end
    if line:find("FindFirstChild", 1, true) and line:find(targetName, 1, true) then return true end
    return false
end

local function scanDependencies()
    local targetName = Settings.BrickName
    local target = getBrick()
    local results = {}
    local scriptsReadable = 0
    local scriptsUnreadable = 0
    local searched = 0

    table.insert(results, "=== BKIT DEPENDENCY SCAN ===")
    table.insert(results, "Target name: " .. targetName)
    table.insert(results, "Target object: " .. (target and safeFullName(target) or "missing"))
    table.insert(results, "Strict search: " .. tostring(Settings.StrictScriptSearch))
    table.insert(results, "Max results: " .. tostring(Settings.MaxScanResults))
    table.insert(results, "")

    local function addResult(text)
        if #results < Settings.MaxScanResults + 10 then
            table.insert(results, text)
        end
    end

    for _, inst in ipairs(game:GetDescendants()) do
        searched += 1
        if #results >= Settings.MaxScanResults + 10 then
            break
        end

        local isLua = inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript")
        if isLua then
            local ok, source = pcall(function() return inst.Source end)
            if ok and type(source) == "string" and source ~= "" then
                scriptsReadable += 1
                if source:find(targetName, 1, true) then
                    addResult("SCRIPT MATCH: " .. safeFullName(inst) .. " <" .. inst.ClassName .. ">")
                    if Settings.IncludeLineSnippets then
                        local added = 0
                        local lineNo = 0
                        for line in (source .. "\n"):gmatch("(.-)\n") do
                            lineNo += 1
                            if lineContainsDependency(line, targetName) then
                                added += 1
                                addResult("  line " .. lineNo .. ": " .. line:sub(1, 180))
                                if added >= 5 then
                                    addResult("  ...more matches hidden")
                                    break
                                end
                            end
                        end
                    end
                end
            else
                scriptsUnreadable += 1
            end
        elseif inst:IsA("ObjectValue") then
            local ok, val = pcall(function() return inst.Value end)
            if ok and val == target then
                addResult("OBJECTVALUE REF: " .. safeFullName(inst) .. " -> " .. safeFullName(target))
            end
        elseif inst:IsA("StringValue") then
            local ok, val = pcall(function() return inst.Value end)
            if ok and type(val) == "string" and val:find(targetName, 1, true) then
                addResult("STRINGVALUE MATCH: " .. safeFullName(inst) .. " = " .. val:sub(1, 180))
            end
        elseif inst.Name == targetName and inst ~= target then
            addResult("NAME MATCH: " .. safeFullName(inst) .. " <" .. inst.ClassName .. ">")
        end
    end

    table.insert(results, "")
    table.insert(results, "--- Scan Summary ---")
    table.insert(results, "Instances searched: " .. tostring(searched))
    table.insert(results, "Readable scripts: " .. tostring(scriptsReadable))
    table.insert(results, "Unreadable scripts: " .. tostring(scriptsUnreadable))
    table.insert(results, "Note: In live games, script Source is often locked. Run in Studio/server context for best results.")
    return table.concat(results, "\n")
end

local function buildFullReport()
    local sections = {}
    table.insert(sections, collectBrickInfo())
    table.insert(sections, "\n")
    table.insert(sections, scanDependencies())
    table.insert(sections, "\n")
    table.insert(sections, "=== RECREATE SCRIPT ===")
    table.insert(sections, generateRecreateCode())
    return table.concat(sections, "\n")
end

local function copyText(text)
    _G.BkitRestoreLastCopiedText = text

    local methods = {}
    if typeof(setclipboard) == "function" then table.insert(methods, setclipboard) end
    if typeof(toclipboard) == "function" then table.insert(methods, toclipboard) end
    if syn and typeof(syn.write_clipboard) == "function" then table.insert(methods, syn.write_clipboard) end
    if Clipboard and typeof(Clipboard.set) == "function" then table.insert(methods, Clipboard.set) end

    for _, method in ipairs(methods) do
        local ok = pcall(function() method(text) end)
        if ok then
            return true, "Copied to clipboard. Also saved at _G.BkitRestoreLastCopiedText"
        end
    end

    print("===== BKIT RESTORE COPY FALLBACK =====")
    print(text)
    print("===== END BKIT RESTORE COPY FALLBACK =====")
    return false, "Clipboard unavailable. Printed to console and saved at _G.BkitRestoreLastCopiedText"
end

if RunService:IsServer() then
    log("Server mode loaded.")
    log(getBrickStatusLine())
    if not getBrick() then
        local _, msg = restoreBrick(false)
        log(msg)
    end
    return
end

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    log("No LocalPlayer. GUI not created.")
    return
end

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("BkitRestoreGui")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "BkitRestoreGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 460, 0, 500)
frame.Position = UDim2.new(0.5, -230, 0.5, -250)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderColor3 = Color3.fromRGB(0, 125, 255)
frame.Active = true
frame.Parent = gui

-- Non-deprecated drag support
local dragging = false
local dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 30)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Bkit Restore Pro v2"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.Code
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local mini = Instance.new("TextButton")
mini.Size = UDim2.new(0, 28, 0, 24)
mini.Position = UDim2.new(1, -64, 0, 3)
mini.Text = "_"
mini.TextColor3 = Color3.fromRGB(255, 255, 255)
mini.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
mini.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 28, 0, 24)
close.Position = UDim2.new(1, -32, 0, 3)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.BackgroundColor3 = Color3.fromRGB(90, 25, 25)
close.Parent = frame
close.MouseButton1Click:Connect(function() gui:Destroy() end)

local status = Instance.new("TextBox")
status.Size = UDim2.new(1, -20, 0, 110)
status.Position = UDim2.new(0, 10, 0, 35)
status.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
status.BorderColor3 = Color3.fromRGB(55, 55, 55)
status.TextColor3 = Color3.fromRGB(230, 230, 230)
status.Font = Enum.Font.Code
status.TextSize = 12
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.ClearTextOnFocus = false
status.MultiLine = true
status.Text = "Loading..."
status.Parent = frame

local function setStatus(text)
    status.Text = tostring(text)
end

local function makeBox(labelText, defaultText, y, w)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 105, 0, 24)
    label.Position = UDim2.new(0, 10, 0, y)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.Code
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, w or 330, 0, 24)
    box.Position = UDim2.new(0, 115, 0, y)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    box.BorderColor3 = Color3.fromRGB(70, 70, 70)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.Code
    box.TextSize = 13
    box.ClearTextOnFocus = false
    box.Text = defaultText
    box.Parent = frame
    return box
end

local y = 155
local nameBox = makeBox("Name", Settings.BrickName, y); y += 28
local posBox = makeBox("Position", "-38, 22, 26", y); y += 28
local sizeBox = makeBox("Size", "4, 4, 4", y); y += 28
local colorBox = makeBox("RGB Color", "192, 192, 192", y); y += 28
local materialBox = makeBox("Material", "Plastic", y); y += 28
local delayBox = makeBox("Watch Delay", "2", y, 95)
local maxBox = makeBox("Max Scan", tostring(Settings.MaxScanResults), y, 95)
maxBox.Position = UDim2.new(0, 345, 0, y)
y += 35

local function applySettingsFromGui()
    Settings.BrickName = nameBox.Text ~= "" and nameBox.Text or "Brick"
    Settings.Position = vectorFromText(posBox.Text, Settings.Position)
    Settings.Size = vectorFromText(sizeBox.Text, Settings.Size)
    Settings.Color = colorFromText(colorBox.Text, Settings.Color)
    Settings.Material = enumFromName(Enum.Material, materialBox.Text, Settings.Material)
    Settings.AutoWatchDelay = tonumber(delayBox.Text) or 2
    Settings.MaxScanResults = math.clamp(tonumber(maxBox.Text) or 80, 10, 500)
end

local function updateBoxesFromSettings()
    nameBox.Text = Settings.BrickName
    posBox.Text = string.format("%.3f, %.3f, %.3f", Settings.Position.X, Settings.Position.Y, Settings.Position.Z)
    sizeBox.Text = string.format("%.3f, %.3f, %.3f", Settings.Size.X, Settings.Size.Y, Settings.Size.Z)
    colorBox.Text = string.format("%d, %d, %d", math.floor(Settings.Color.R * 255 + 0.5), math.floor(Settings.Color.G * 255 + 0.5), math.floor(Settings.Color.B * 255 + 0.5))
    materialBox.Text = tostring(Settings.Material):gsub("Enum.Material.", "")
    delayBox.Text = tostring(Settings.AutoWatchDelay)
    maxBox.Text = tostring(Settings.MaxScanResults)
end

local function makeButton(text, x, yPos, w, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0, yPos)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    b.BorderColor3 = Color3.fromRGB(80, 80, 80)
    b.Font = Enum.Font.Code
    b.TextSize = 12
    b.Parent = frame
    b.MouseButton1Click:Connect(function()
        local ok, err = pcall(callback)
        if not ok then
            setStatus("Button error: " .. tostring(err))
            warn("[Bkit Restore Pro] Button error:", err)
        end
    end)
    return b
end

local buttonY = y
makeButton("Check", 10, buttonY, 70, function()
    applySettingsFromGui()
    setStatus(getBrickStatusLine())
end)
makeButton("Restore", 85, buttonY, 80, function()
    applySettingsFromGui()
    local _, msg = restoreBrick(false)
    setStatus(msg .. "\nWARNING: client mode is local-only; server Bkit needs server-side execution.")
end)
makeButton("Force", 170, buttonY, 65, function()
    applySettingsFromGui()
    local _, msg = restoreBrick(true)
    setStatus(msg .. "\nWARNING: client mode is local-only; server Bkit needs server-side execution.")
end)
local autoButton
autoButton = makeButton("Auto OFF", 240, buttonY, 80, function()
    applySettingsFromGui()
    setAutoWatch(not Settings.AutoWatch)
    autoButton.Text = Settings.AutoWatch and "Auto ON" or "Auto OFF"
    setStatus(Settings.AutoWatch and "Auto-watch enabled." or "Auto-watch disabled.")
end)
local replaceButton
replaceButton = makeButton("Replace OFF", 325, buttonY, 125, function()
    Settings.ReplaceExisting = not Settings.ReplaceExisting
    replaceButton.Text = Settings.ReplaceExisting and "Replace ON" or "Replace OFF"
    setStatus("Replace Existing = " .. tostring(Settings.ReplaceExisting))
end)

buttonY += 34
makeButton("Load Current", 10, buttonY, 105, function()
    applySettingsFromGui()
    local _, msg = loadSettingsFromBrick()
    updateBoxesFromSettings()
    setStatus(msg)
end)
makeButton("Copy Info", 120, buttonY, 90, function()
    applySettingsFromGui()
    local text = collectBrickInfo()
    local _, msg = copyText(text)
    setStatus(msg .. "\n\n" .. text:sub(1, 900))
end)
makeButton("Copy Report", 215, buttonY, 100, function()
    applySettingsFromGui()
    setStatus("Scanning. Wait...")
    task.defer(function()
        local text = buildFullReport()
        local _, msg = copyText(text)
        setStatus(msg .. "\nFull report length: " .. tostring(#text) .. " chars")
    end)
end)
makeButton("Copy Recreate", 320, buttonY, 130, function()
    applySettingsFromGui()
    local text = generateRecreateCode()
    local _, msg = copyText(text)
    setStatus(msg .. "\n\n" .. text:sub(1, 900))
end)

buttonY += 34
makeButton("Scan Deps", 10, buttonY, 95, function()
    applySettingsFromGui()
    setStatus("Scanning dependencies. Wait...")
    task.defer(function()
        local text = scanDependencies()
        setStatus(text:sub(1, 3000))
        _G.BkitRestoreLastDependencyScan = text
    end)
end)
local strictButton
strictButton = makeButton("Strict OFF", 110, buttonY, 90, function()
    Settings.StrictScriptSearch = not Settings.StrictScriptSearch
    strictButton.Text = Settings.StrictScriptSearch and "Strict ON" or "Strict OFF"
    setStatus("Strict search = " .. tostring(Settings.StrictScriptSearch))
end)
local snippetButton
snippetButton = makeButton("Lines ON", 205, buttonY, 80, function()
    Settings.IncludeLineSnippets = not Settings.IncludeLineSnippets
    snippetButton.Text = Settings.IncludeLineSnippets and "Lines ON" or "Lines OFF"
    setStatus("Include line snippets = " .. tostring(Settings.IncludeLineSnippets))
end)
makeButton("Backup", 290, buttonY, 70, function()
    local _, msg = backupBrick()
    setStatus(msg)
end)
makeButton("From Backup", 365, buttonY, 85, function()
    local _, msg = restoreFromBackup()
    setStatus(msg)
end)

buttonY += 34
local toggleNames = {
    "Anchored", "Locked", "CanCollide", "CanQuery", "CanTouch", "CastShadow", "Massless"
}
local x = 10
for _, key in ipairs(toggleNames) do
    local btn
    btn = makeButton(key .. ": " .. (Settings[key] and "ON" or "OFF"), x, buttonY, 105, function()
        Settings[key] = not Settings[key]
        btn.Text = key .. ": " .. (Settings[key] and "ON" or "OFF")
        setStatus(key .. " = " .. tostring(Settings[key]))
    end)
    x += 110
    if x > 350 then
        x = 10
        buttonY += 32
    end
end

buttonY += 36
makeButton("Reset Defaults", 10, buttonY, 120, function()
    Settings.BrickName = "Brick"
    Settings.Position = Vector3.new(-38, 22, 26)
    Settings.Size = Vector3.new(4, 4, 4)
    Settings.Color = Color3.fromRGB(192, 192, 192)
    Settings.Material = Enum.Material.Plastic
    Settings.AutoWatchDelay = 2
    Settings.MaxScanResults = 80
    Settings.ReplaceExisting = false
    Settings.StrictScriptSearch = false
    updateBoxesFromSettings()
    setStatus("Defaults restored.")
end)
makeButton("Copy Loadstring", 140, buttonY, 130, function()
    local url = "https://raw.githubusercontent.com/failedcoderlol/Bkit-Restore/main/restore_bkit_brick.server.lua"
    local text = "loadstring(game:HttpGet(" .. formatValue(url) .. "))()"
    local _, msg = copyText(text)
    setStatus(msg .. "\n" .. text)
end)
makeButton("Destroy GUI", 280, buttonY, 170, function()
    gui:Destroy()
end)

local minimized = false
local originalSize = frame.Size
mini.MouseButton1Click:Connect(function()
    minimized = not minimized
    for _, child in ipairs(frame:GetChildren()) do
        if child ~= title and child ~= close and child ~= mini then
            child.Visible = not minimized
        end
    end
    frame.Size = minimized and UDim2.new(0, 460, 0, 30) or originalSize
    mini.Text = minimized and "+" or "_"
end)

setStatus(getBrickStatusLine() .. "\nClient GUI ready. Use Copy Report to copy properties + dependency scan + recreate script.")
