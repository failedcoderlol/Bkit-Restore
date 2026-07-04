-- restore_bkit_brick_gui_v7.lua
-- Bkit Restore + Diagnostics v7
-- IMPORTANT:
-- Client/local execution can only repair your local preview object.
-- To actually restore building for the server, place this same file in ServerScriptService
-- or run the SERVER RESTORE code in a server/admin context for a place you own.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CFG = {
    BrickName = "Brick",
    Size = Vector3.new(4, 4, 4),
    PreviewPosition = Vector3.new(-777, -777, -777), -- dynamic preview position, not required for integrity
    Color = Color3.fromRGB(192, 192, 192),
    BrickColor = BrickColor.new("Light grey"),
    Material = Enum.Material.Plastic,
    TopSurface = Enum.SurfaceType.Studs,
    BottomSurface = Enum.SurfaceType.Inlet,
    FrontSurface = Enum.SurfaceType.Smooth,
    BackSurface = Enum.SurfaceType.Smooth,
    LeftSurface = Enum.SurfaceType.Smooth,
    RightSurface = Enum.SurfaceType.Smooth,
    Anchored = true,
    Locked = true,
    Archivable = true,
    CanCollide = true,
    CanQuery = true,
    CanTouch = true,
    CastShadow = true,
    Massless = false,
    CollisionGroup = "Default",
    Transparency = 0,
    Reflectance = 0,
    AutoHealDelay = 1,
}

local function vec(v)
    return string.format("%.3f, %.3f, %.3f", v.X, v.Y, v.Z)
end

local function safeFullName(x)
    local ok, name = pcall(function() return x:GetFullName() end)
    return ok and name or tostring(x)
end

local function getBrick()
    local b = ReplicatedStorage:FindFirstChild(CFG.BrickName)
    if b and b:IsA("Part") then
        return b
    end
    return nil
end

local function applyBrickProperties(brick, includePosition)
    brick.Name = CFG.BrickName
    brick.Size = CFG.Size
    if includePosition then
        brick.CFrame = CFrame.new(CFG.PreviewPosition)
    end
    brick.Anchored = CFG.Anchored
    brick.Locked = CFG.Locked
    brick.Archivable = CFG.Archivable
    brick.CanCollide = CFG.CanCollide
    brick.CanQuery = CFG.CanQuery
    brick.CanTouch = CFG.CanTouch
    brick.CastShadow = CFG.CastShadow
    brick.Massless = CFG.Massless
    brick.Material = CFG.Material
    brick.Color = CFG.Color
    brick.BrickColor = CFG.BrickColor
    brick.Transparency = CFG.Transparency
    brick.Reflectance = CFG.Reflectance
    pcall(function() brick.CollisionGroup = CFG.CollisionGroup end)
    brick.TopSurface = CFG.TopSurface
    brick.BottomSurface = CFG.BottomSurface
    brick.FrontSurface = CFG.FrontSurface
    brick.BackSurface = CFG.BackSurface
    brick.LeftSurface = CFG.LeftSurface
    brick.RightSurface = CFG.RightSurface
    brick.Parent = ReplicatedStorage
    return brick
end

local function createOrRepairBrick(includePosition)
    local brick = getBrick()
    local madeNew = false

    local wrong = ReplicatedStorage:FindFirstChild(CFG.BrickName)
    if wrong and not wrong:IsA("Part") then
        wrong:Destroy()
        brick = nil
    end

    if not brick then
        brick = Instance.new("Part")
        madeNew = true
    end

    applyBrickProperties(brick, includePosition)
    return brick, madeNew
end

local function serverRestoreSource()
    return [[-- Bkit SERVER restore/healer
-- Put this in ServerScriptService in a place you own/admin.
-- This is the part that actually fixes building for everyone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CFG = {
    BrickName = "Brick",
    Size = Vector3.new(4, 4, 4),
    PreviewPosition = Vector3.new(-777, -777, -777),
    Color = Color3.fromRGB(192, 192, 192),
    BrickColor = BrickColor.new("Light grey"),
    Material = Enum.Material.Plastic,
    TopSurface = Enum.SurfaceType.Studs,
    BottomSurface = Enum.SurfaceType.Inlet,
    FrontSurface = Enum.SurfaceType.Smooth,
    BackSurface = Enum.SurfaceType.Smooth,
    LeftSurface = Enum.SurfaceType.Smooth,
    RightSurface = Enum.SurfaceType.Smooth,
}

local function apply(brick)
    brick.Name = CFG.BrickName
    brick.Size = CFG.Size
    brick.CFrame = CFrame.new(CFG.PreviewPosition)
    brick.Anchored = true
    brick.Locked = true
    brick.Archivable = true
    brick.CanCollide = true
    brick.CanQuery = true
    brick.CanTouch = true
    brick.CastShadow = true
    brick.Massless = false
    brick.Material = CFG.Material
    brick.Color = CFG.Color
    brick.BrickColor = CFG.BrickColor
    brick.Transparency = 0
    brick.Reflectance = 0
    pcall(function() brick.CollisionGroup = "Default" end)
    brick.TopSurface = CFG.TopSurface
    brick.BottomSurface = CFG.BottomSurface
    brick.FrontSurface = CFG.FrontSurface
    brick.BackSurface = CFG.BackSurface
    brick.LeftSurface = CFG.LeftSurface
    brick.RightSurface = CFG.RightSurface
    brick.Parent = ReplicatedStorage
    return brick
end

local function ensureBrick()
    local existing = ReplicatedStorage:FindFirstChild(CFG.BrickName)
    if existing and not existing:IsA("Part") then
        existing:Destroy()
        existing = nil
    end
    if not existing then
        existing = Instance.new("Part")
    end
    return apply(existing)
end

ensureBrick()
print("[Bkit Server Restore] ReplicatedStorage.Brick restored/healed.")

ReplicatedStorage.ChildRemoved:Connect(function(child)
    if child.Name == CFG.BrickName then
        task.defer(function()
            ensureBrick()
            warn("[Bkit Server Restore] Brick was removed and has been restored.")
        end)
    end
end)

while task.wait(1) do
    local ok, err = pcall(ensureBrick)
    if not ok then
        warn("[Bkit Server Restore] Heal error:", err)
    end
end]]
end

-- SERVER MODE: this is the real fix when placed in ServerScriptService.
if RunService:IsServer() then
    local brick = createOrRepairBrick(true)
    print("[Bkit Restore v7] Server mode: ReplicatedStorage.Brick restored/healed at " .. safeFullName(brick))

    ReplicatedStorage.ChildRemoved:Connect(function(child)
        if child.Name == CFG.BrickName then
            task.defer(function()
                local b = createOrRepairBrick(true)
                warn("[Bkit Restore v7] Brick was removed; restored " .. safeFullName(b))
            end)
        end
    end)

    task.spawn(function()
        while task.wait(CFG.AutoHealDelay) do
            pcall(function()
                createOrRepairBrick(false)
            end)
        end
    end)

    return
end

-- CLIENT MODE GUI
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local old = PlayerGui:FindFirstChild("BkitRestoreGuiV7")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "BkitRestoreGuiV7"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Name = "Frame"
frame.Size = UDim2.new(0, 720, 0, 500)
frame.Position = UDim2.new(0.5, -360, 0.5, -250)
frame.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
frame.BorderColor3 = Color3.fromRGB(0, 125, 255)
frame.Active = true
frame.Parent = gui

local function makeText(parent, text, pos, size, fontSize)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Text = text
    t.Position = pos
    t.Size = size
    t.Font = Enum.Font.Code
    t.TextSize = fontSize or 13
    t.TextColor3 = Color3.fromRGB(235, 235, 235)
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = Enum.TextYAlignment.Center
    t.Parent = parent
    return t
end

local title = makeText(frame, "Bkit Restore + Diagnostics v7", UDim2.new(0, 10, 0, 0), UDim2.new(1, -80, 0, 30), 17)

local close = Instance.new("TextButton")
close.Text = "X"
close.Font = Enum.Font.Code
close.TextSize = 14
close.TextColor3 = Color3.fromRGB(255,255,255)
close.BackgroundColor3 = Color3.fromRGB(90,25,25)
close.BorderColor3 = Color3.fromRGB(80,80,80)
close.Size = UDim2.new(0, 36, 0, 24)
close.Position = UDim2.new(1, -42, 0, 3)
close.Parent = frame
close.MouseButton1Click:Connect(function() gui:Destroy() end)

local mini = Instance.new("TextButton")
mini.Text = "_"
mini.Font = Enum.Font.Code
mini.TextSize = 14
mini.TextColor3 = Color3.fromRGB(255,255,255)
mini.BackgroundColor3 = Color3.fromRGB(35,35,35)
mini.BorderColor3 = Color3.fromRGB(80,80,80)
mini.Size = UDim2.new(0, 36, 0, 24)
mini.Position = UDim2.new(1, -82, 0, 3)
mini.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.new(0, 10, 0, 34)
status.Size = UDim2.new(1, -20, 0, 52)
status.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
status.BorderColor3 = Color3.fromRGB(65, 65, 65)
status.TextColor3 = Color3.fromRGB(235, 235, 235)
status.Font = Enum.Font.Code
status.TextSize = 12
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "Client GUI loaded. Client repair can fix preview only. Actual placing requires the server Brick to exist."
status.Parent = frame

local output = Instance.new("TextBox")
output.Position = UDim2.new(0, 10, 0, 285)
output.Size = UDim2.new(1, -20, 1, -295)
output.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
output.BorderColor3 = Color3.fromRGB(65, 65, 65)
output.TextColor3 = Color3.fromRGB(230, 230, 230)
output.Font = Enum.Font.Code
output.TextSize = 12
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.TextWrapped = false
output.MultiLine = true
output.ClearTextOnFocus = false
output.Text = ""
output.Parent = frame

local minimized = false
mini.MouseButton1Click:Connect(function()
    minimized = not minimized
    for _, child in ipairs(frame:GetChildren()) do
        if child ~= title and child ~= close and child ~= mini then
            child.Visible = not minimized
        end
    end
    frame.Size = minimized and UDim2.new(0, 720, 0, 32) or UDim2.new(0, 720, 0, 500)
end)

-- drag
do
    local UIS = game:GetService("UserInputService")
    local dragging, dragStart, startPos
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    title.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function setOut(text)
    output.Text = text
    status.Text = text:sub(1, 240)
end

local function copyText(text)
    local ok = false
    if typeof(setclipboard) == "function" then
        ok = pcall(setclipboard, text)
    elseif typeof(toclipboard) == "function" then
        ok = pcall(toclipboard, text)
    end
    output.Text = text
    status.Text = ok and "Copied to clipboard." or "Clipboard not available; select/copy from output box."
end

local function brickInfo()
    local lines = {}
    table.insert(lines, "=== BKIT BRICK INFO v7 ===")
    table.insert(lines, "Mode: Client/local")
    table.insert(lines, "PlaceId: " .. tostring(game.PlaceId))
    table.insert(lines, "JobId: " .. tostring(game.JobId))
    local b = ReplicatedStorage:FindFirstChild(CFG.BrickName)
    if not b then
        table.insert(lines, "Status: MISSING on client. Server may also be missing it.")
        return table.concat(lines, "\n")
    end
    table.insert(lines, "Path: " .. safeFullName(b))
    table.insert(lines, "Class: " .. b.ClassName)
    if b:IsA("BasePart") then
        table.insert(lines, "Size: " .. vec(b.Size))
        table.insert(lines, "Position: " .. vec(b.Position) .. " (dynamic preview position)")
        table.insert(lines, "Anchored: " .. tostring(b.Anchored))
        table.insert(lines, "Locked: " .. tostring(b.Locked))
        table.insert(lines, "CanCollide: " .. tostring(b.CanCollide))
        table.insert(lines, "CanQuery: " .. tostring(b.CanQuery))
        table.insert(lines, "CanTouch: " .. tostring(b.CanTouch))
        table.insert(lines, "CastShadow: " .. tostring(b.CastShadow))
        table.insert(lines, "Massless: " .. tostring(b.Massless))
        table.insert(lines, "Material: " .. tostring(b.Material))
        table.insert(lines, "Color: RGB(" .. math.floor(b.Color.R*255+0.5) .. ", " .. math.floor(b.Color.G*255+0.5) .. ", " .. math.floor(b.Color.B*255+0.5) .. ")")
        table.insert(lines, "TopSurface: " .. tostring(b.TopSurface))
        table.insert(lines, "BottomSurface: " .. tostring(b.BottomSurface))
    end
    table.insert(lines, "Children: " .. tostring(#b:GetChildren()))
    local attrs = b:GetAttributes()
    local hasAttrs = false
    for k, v in pairs(attrs) do
        if not hasAttrs then table.insert(lines, "--- Attributes ---") end
        hasAttrs = true
        table.insert(lines, tostring(k) .. " = " .. tostring(v))
    end
    if not hasAttrs then table.insert(lines, "Attributes: none") end
    return table.concat(lines, "\n")
end

local function integrity()
    local lines = {}
    table.insert(lines, "=== BKIT INTEGRITY v7 ===")
    table.insert(lines, "Position is ignored because Build moves Brick as a preview object.")
    local b = getBrick()
    if not b then
        table.insert(lines, "FAIL: ReplicatedStorage.Brick missing on client.")
        table.insert(lines, "Client can recreate local preview, but server restore is required if placing fails.")
        return table.concat(lines, "\n")
    end

    local checks = {
        {"Class", b.ClassName, "Part"},
        {"Parent", b.Parent == ReplicatedStorage and "ReplicatedStorage" or safeFullName(b.Parent), "ReplicatedStorage"},
        {"Size", vec(b.Size), vec(CFG.Size)},
        {"Anchored", tostring(b.Anchored), tostring(CFG.Anchored)},
        {"Locked", tostring(b.Locked), tostring(CFG.Locked)},
        {"CanCollide", tostring(b.CanCollide), tostring(CFG.CanCollide)},
        {"CanQuery", tostring(b.CanQuery), tostring(CFG.CanQuery)},
        {"CanTouch", tostring(b.CanTouch), tostring(CFG.CanTouch)},
        {"CastShadow", tostring(b.CastShadow), tostring(CFG.CastShadow)},
        {"Material", tostring(b.Material), tostring(CFG.Material)},
        {"TopSurface", tostring(b.TopSurface), tostring(CFG.TopSurface)},
        {"BottomSurface", tostring(b.BottomSurface), tostring(CFG.BottomSurface)},
    }
    local pass = 0
    for _, c in ipairs(checks) do
        local ok = (c[2] == c[3])
        if ok then pass += 1 end
        table.insert(lines, (ok and "OK   " or "FAIL ") .. c[1] .. " | current: " .. c[2] .. " | expected: " .. c[3])
    end
    table.insert(lines, 2, ("Integrity: %d/%d passed"):format(pass, #checks))
    return table.concat(lines, "\n")
end

local function findTools()
    local containers = {}
    if LocalPlayer.Character then table.insert(containers, LocalPlayer.Character) end
    table.insert(containers, LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack"))

    local tools = {}
    for _, cont in ipairs(containers) do
        for _, child in ipairs(cont:GetChildren()) do
            if child:IsA("Tool") then
                table.insert(tools, child)
            end
        end
    end
    return tools
end

local function toolDebug()
    local lines = {}
    table.insert(lines, "=== BKIT TOOL DEBUG v7 ===")
    local b = getBrick()
    table.insert(lines, "Client Brick: " .. (b and (safeFullName(b) .. " | Pos " .. vec(b.Position)) or "MISSING"))
    table.insert(lines, "Note: if server Brick is missing, placement still fails even when client Brick is OK.")
    local buildGui = PlayerGui:FindFirstChild("Build")
    table.insert(lines, "PlayerGui.Build: " .. (buildGui and "found" or "missing"))
    if buildGui then
        local button = buildGui:FindFirstChild("Button", true)
        table.insert(lines, "Build.Button.Text: " .. (button and tostring(button.Text) or "missing"))
    end

    local tools = findTools()
    table.insert(lines, "Tools found: " .. tostring(#tools))
    for _, tool in ipairs(tools) do
        local remotes = {}
        local scripts = {}
        local preview = tool:FindFirstChild("Preview", true)
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") or d:IsA("BindableFunction") then
                table.insert(remotes, d.Name .. "<" .. d.ClassName .. ">")
            elseif d:IsA("LocalScript") or d:IsA("Script") then
                table.insert(scripts, d.Name .. "<" .. d.ClassName .. ">")
            end
        end
        table.insert(lines, "TOOL: " .. safeFullName(tool))
        table.insert(lines, "  scripts: " .. (#scripts > 0 and table.concat(scripts, ", ") or "none"))
        table.insert(lines, "  remotes: " .. (#remotes > 0 and table.concat(remotes, ", ") or "none"))
        table.insert(lines, "  preview: " .. (preview and (preview.ClassName .. " found") or "none"))
    end
    return table.concat(lines, "\n")
end

local function restartTools()
    local count = 0
    for _, tool in ipairs(findTools()) do
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("LocalScript") then
                pcall(function()
                    d.Disabled = true
                    task.wait()
                    d.Disabled = false
                    count += 1
                end)
            end
        end
    end

    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum:UnequipTools()
        end)
    end

    return "Restarted " .. tostring(count) .. " LocalScript(s). Re-equip Build. If placement still fails, server restore is required."
end

local function clientRepair()
    local brick, madeNew = createOrRepairBrick(false)
    local msg = madeNew
        and "Created ReplicatedStorage.Brick locally. Restart tools/rejoin may be needed for Build script to reference it."
        or "Repaired existing ReplicatedStorage.Brick locally in-place."
    return msg .. "\nPath: " .. safeFullName(brick) .. "\n\nIf you still cannot place, the SERVER Brick is missing; run the server restore in ServerScriptService."
end

local function dependencyScan()
    local lines = {}
    local max = 80
    local target = getBrick()
    table.insert(lines, "=== BKIT DEPENDENCY SCAN v7 ===")
    table.insert(lines, "This client scan cannot prove server Script dependencies.")
    table.insert(lines, "Target: ReplicatedStorage.Brick")
    table.insert(lines, "Status: " .. (target and ("client OK | " .. safeFullName(target)) or "client MISSING"))
    table.insert(lines, "")

    local remotes, tools, objectRefs, clones = {}, {}, {}, {}
    local searched = 0

    local skipRoots = {}
    pcall(function() skipRoots[game:GetService("CoreGui")] = true end)
    skipRoots[gui] = true

    local function skipped(inst)
        if inst == gui or inst:IsDescendantOf(gui) then return true end
        for root in pairs(skipRoots) do
            if inst == root or inst:IsDescendantOf(root) then return true end
        end
        local fn = safeFullName(inst)
        if fn:find("^RobloxReplicatedStorage") or fn:find("^Script Context") then return true end
        return false
    end

    for _, inst in ipairs(game:GetDescendants()) do
        if not skipped(inst) then
            searched += 1
            if inst:IsA("Tool") then
                local n = inst.Name:lower()
                if n:find("build") or n:find("delete") or n:find("paint") or n:find("shape") or n:find("shovel") or n:find("sign") then
                    table.insert(tools, safeFullName(inst))
                end
            elseif inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("BindableEvent") or inst:IsA("BindableFunction") then
                local fn = safeFullName(inst):lower()
                if fn:find("build") or fn:find("delete") or fn:find("paint") or fn:find("shape") or fn:find("shovel") or fn:find("sign") then
                    table.insert(remotes, safeFullName(inst) .. " <" .. inst.ClassName .. ">")
                end
            elseif target and inst:IsA("ObjectValue") and inst.Value == target then
                table.insert(objectRefs, safeFullName(inst))
            elseif target and inst:IsA("BasePart") and inst ~= target and inst.Name == CFG.BrickName then
                if (inst.Size - CFG.Size).Magnitude < 0.01 and inst.Material == CFG.Material and inst.Color == CFG.Color then
                    table.insert(clones, safeFullName(inst) .. " | Pos " .. vec(inst.Position))
                end
            end
        end
    end

    table.insert(lines, "Instances searched: " .. tostring(searched))
    table.insert(lines, "Remote/tool candidates are client-visible only.")
    table.insert(lines, "")
    table.insert(lines, "--- Tool Candidates ---")
    if #tools == 0 then table.insert(lines, "none") end
    for i = 1, math.min(#tools, max) do table.insert(lines, tools[i]) end

    table.insert(lines, "")
    table.insert(lines, "--- Remote / Bindable Candidates ---")
    if #remotes == 0 then table.insert(lines, "none") end
    for i = 1, math.min(#remotes, max) do table.insert(lines, remotes[i]) end

    table.insert(lines, "")
    table.insert(lines, "--- ObjectValue References ---")
    if #objectRefs == 0 then table.insert(lines, "none") end
    for i = 1, math.min(#objectRefs, max) do table.insert(lines, objectRefs[i]) end

    table.insert(lines, "")
    table.insert(lines, "--- Clone Candidates ---")
    if #clones == 0 then
        table.insert(lines, "none found; this can mean no placed bricks currently match the template locally.")
    end
    for i = 1, math.min(#clones, 25) do table.insert(lines, clones[i]) end
    if #clones > 25 then table.insert(lines, "... +" .. tostring(#clones - 25) .. " more") end

    table.insert(lines, "")
    table.insert(lines, "--- Conclusion ---")
    table.insert(lines, "If Repair Local + Restart Tools does not place blocks, the problem is server-side.")
    table.insert(lines, "Use Copy Server Fix and run it in ServerScriptService/admin server context.")
    return table.concat(lines, "\n")
end


local function exportReadableScripts()
    local lines = {}
    local stats = {scanned = 0, exported = 0, locked = 0, skipped = 0}

    table.insert(lines, "=== READABLE SCRIPT EXPORT v7 ===")
    table.insert(lines, "Exports only Script/LocalScript/ModuleScript sources this environment is allowed to read.")
    table.insert(lines, "It does not bypass locked/protected scripts.")
    table.insert(lines, "PlaceId: " .. tostring(game.PlaceId))
    table.insert(lines, "JobId: " .. tostring(game.JobId))
    table.insert(lines, "")

    local function shouldSkip(obj)
        if obj == gui or obj:IsDescendantOf(gui) then return true end
        local fn = safeFullName(obj)
        if fn:find("^CoreGui") or fn:find("^Script Context") or fn:find("^RobloxReplicatedStorage") then return true end
        return false
    end

    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
            stats.scanned += 1
            if shouldSkip(obj) then
                stats.skipped += 1
            else
                local ok, source = pcall(function() return obj.Source end)
                if ok and type(source) == "string" then
                    stats.exported += 1
                    table.insert(lines, "\n\n===== " .. safeFullName(obj) .. " <" .. obj.ClassName .. "> =====\n")
                    table.insert(lines, source)
                else
                    stats.locked += 1
                    table.insert(lines, "\n\n===== LOCKED / UNREADABLE: " .. safeFullName(obj) .. " <" .. obj.ClassName .. "> =====\n")
                    table.insert(lines, tostring(source))
                end
            end
        end
    end

    table.insert(lines, 6, "Scripts scanned: " .. tostring(stats.scanned))
    table.insert(lines, 7, "Sources exported: " .. tostring(stats.exported))
    table.insert(lines, 8, "Locked/unreadable: " .. tostring(stats.locked))
    table.insert(lines, 9, "Skipped internal/gui: " .. tostring(stats.skipped))
    table.insert(lines, 10, "")

    return table.concat(lines, "\n")
end

local function exportBkitToolScriptsOnly()
    local lines = {}
    local found, exported, locked = 0, 0, 0

    table.insert(lines, "=== BKIT TOOL SCRIPT EXPORT v7 ===")
    table.insert(lines, "Exports readable scripts only from Build/Delete/Paint/Shape/Shovel/Sign tools.")
    table.insert(lines, "")

    local wanted = {build=true, delete=true, paint=true, shape=true, shovel=true, sign=true}

    for _, tool in ipairs(findTools()) do
        if tool:IsA("Tool") and wanted[tool.Name:lower()] then
            found += 1
            table.insert(lines, "\n--- TOOL: " .. safeFullName(tool) .. " ---")
            for _, obj in ipairs(tool:GetDescendants()) do
                if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    local ok, source = pcall(function() return obj.Source end)
                    if ok and type(source) == "string" then
                        exported += 1
                        table.insert(lines, "\n===== " .. safeFullName(obj) .. " <" .. obj.ClassName .. "> =====\n")
                        table.insert(lines, source)
                    else
                        locked += 1
                        table.insert(lines, "\n===== LOCKED / UNREADABLE: " .. safeFullName(obj) .. " <" .. obj.ClassName .. "> =====\n")
                        table.insert(lines, tostring(source))
                    end
                end
            end
        end
    end

    table.insert(lines, 3, "Tools found: " .. tostring(found))
    table.insert(lines, 4, "Sources exported: " .. tostring(exported))
    table.insert(lines, 5, "Locked/unreadable: " .. tostring(locked))

    return table.concat(lines, "\n")
end


local function fullReport()
    return table.concat({
        brickInfo(),
        "",
        integrity(),
        "",
        toolDebug(),
        "",
        dependencyScan(),
        "",
        "=== SERVER RESTORE CODE ===",
        serverRestoreSource()
    }, "\n")
end

local function makeBtn(text, col, row, cb)
    local gap = 8
    local x0, y0 = 10, 95
    local w, h = 108, 28
    local b = Instance.new("TextButton")
    b.Text = text
    b.Font = Enum.Font.Code
    b.TextSize = 12
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.BackgroundColor3 = Color3.fromRGB(33,33,33)
    b.BorderColor3 = Color3.fromRGB(80,80,80)
    b.Position = UDim2.new(0, x0 + (w + gap) * col, 0, y0 + (h + gap) * row)
    b.Size = UDim2.new(0, w, 0, h)
    b.Parent = frame
    b.MouseButton1Click:Connect(function()
        local ok, result = pcall(cb)
        if ok and result then
            setOut(result)
        elseif not ok then
            setOut("ERROR:\n" .. tostring(result))
        end
    end)
    return b
end

makeBtn("Info", 0, 0, brickInfo)
makeBtn("Integrity", 1, 0, integrity)
makeBtn("Repair Local", 2, 0, clientRepair)
makeBtn("Restart Tools", 3, 0, restartTools)
makeBtn("Tool Debug", 4, 0, toolDebug)
makeBtn("Scan Deps", 5, 0, dependencyScan)

makeBtn("Copy Info", 0, 1, function() copyText(brickInfo()) end)
makeBtn("Copy Report", 1, 1, function() copyText(fullReport()) end)
makeBtn("Copy Server", 2, 1, function() copyText(serverRestoreSource()) end)
makeBtn("Copy Load", 3, 1, function()
    copyText([[loadstring(game:HttpGet("https://raw.githubusercontent.com/failedcoderlol/Bkit-Restore/main/restore_bkit_brick.server.lua"))()]])
end)
makeBtn("Clear", 4, 1, function() output.Text = ""; return "Output cleared." end)
makeBtn("Destroy GUI", 5, 1, function() gui:Destroy() end)

makeBtn("Best Steps", 0, 2, function()
    return [[Best steps:
1. Click Repair Local.
2. Click Restart Tools.
3. Unequip and re-equip Build.
4. Try placing on a valid target within 24 studs.
5. If it still does not place, client repair is not enough.
6. Run Copy Server code in ServerScriptService/admin server context, then reset/rejoin so Build reloads its local Brick reference.]]
end)

makeBtn("Why Fails", 1, 2, function()
    return [[Why Repair Local may not fix placing:
The Build tool stores this when the LocalScript starts:
local Brick = ReplicatedStorage.Brick

If the real server Brick was deleted, the server cannot clone/place new blocks.
A client can recreate a local preview Brick, but the server will not see that local object.
That is why placing still fails until the server-side ReplicatedStorage.Brick is restored.]]
end)

makeBtn("Client Fix", 2, 2, function()
    local a = clientRepair()
    local b = restartTools()
    return a .. "\n\n" .. b
end)

makeBtn("Server Needed?", 3, 2, function()
    return [[Server restore is needed if:
- ReplicatedStorage.Brick looks OK locally, but Build still fires and no block appears.
- Clone candidates / Workspace.Bricks stay at 0 after trying to build.
- Repair Local + Restart Tools did not help.

A normal client loadstring cannot fix the server's ReplicatedStorage.]]
end)

makeBtn("Recreate Local", 4, 2, function()
    local brick = ReplicatedStorage:FindFirstChild(CFG.BrickName)
    if brick then brick:Destroy() end
    local b = createOrRepairBrick(true)
    return "Destroyed/recreated client-local Brick at " .. safeFullName(b) .. "\nRestart Tools after this."
end)

makeBtn("Copy All", 5, 2, function()
    copyText(fullReport())
end)

makeBtn("Export All", 0, 3, exportReadableScripts)
makeBtn("Copy Export", 1, 3, function()
    copyText(exportReadableScripts())
end)
makeBtn("Bkit Scripts", 2, 3, exportBkitToolScriptsOnly)
makeBtn("Copy BkitSrc", 3, 3, function()
    copyText(exportBkitToolScriptsOnly())
end)
makeBtn("Print Output", 4, 3, function()
    print(output.Text)
    return "Printed current output to console."
end)

setOut([[Loaded v7.

The Build tool uses ReplicatedStorage.Brick as a client preview.
Client/local repair can fix the preview, but if blocks still do not place, the missing object is on the server.

Try:
Repair Local -> Restart Tools -> re-equip Build.
If that fails, use Copy Server and run it server-side.]])
