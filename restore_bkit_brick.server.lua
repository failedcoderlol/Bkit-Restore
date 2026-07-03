-- restore_bkit_brick_gui_v3.lua
-- Bkit Restore + Diagnostics Panel v3
-- Safe use: for your own Roblox place / authorized admin work only.
-- Important: if loaded from a client, Restore/Force Restore can only create a local client copy.
-- Real game-wide restore must run on the server, for example from ServerScriptService in a place you own.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local IS_SERVER = RunService:IsServer()
local LocalPlayer = (not IS_SERVER) and Players.LocalPlayer or nil
local ServerStorage = IS_SERVER and game:GetService("ServerStorage") or nil

local Settings = {
    BrickName = "Brick",
    ParentPath = "ReplicatedStorage",
    Position = Vector3.new(-90, 22, -74),
    Size = Vector3.new(4, 4, 4),
    Color = Color3.fromRGB(192, 192, 192),
    BrickColor = BrickColor.new("Light grey"),
    Material = Enum.Material.Plastic,
    MaterialVariant = "",
    Transparency = 0,
    Reflectance = 0,
    Anchored = true,
    Locked = true,
    Archivable = true,
    Massless = false,
    CanCollide = true,
    CanQuery = true,
    CanTouch = true,
    CastShadow = true,
    CollisionGroup = "Default",
    TopSurface = Enum.SurfaceType.Studs,
    BottomSurface = Enum.SurfaceType.Inlet,
    FrontSurface = Enum.SurfaceType.Smooth,
    BackSurface = Enum.SurfaceType.Smooth,
    LeftSurface = Enum.SurfaceType.Smooth,
    RightSurface = Enum.SurfaceType.Smooth,

    ReplaceExisting = false,
    AutoWatch = false,
    AutoWatchDelay = 2,
    StrictSearch = true,
    IncludeSnippets = true,
    MaxResults = 120,
    MaxScriptChars = 400000,
    ShowNameOnlyMatches = false,
    ServerRestoreOnly = false,
}

local Baseline = nil
local LastScanReport = ""
local LastBrickReport = ""
local LastIntegrityReport = ""
local LastRecreateScript = ""
local MonitorConnections = {}
local AutoThreadRunning = false

local function nowString()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function safeFullName(inst)
    local ok, result = pcall(function()
        return inst:GetFullName()
    end)
    if ok then return result end
    return tostring(inst)
end

local function fmtNum(n)
    if typeof(n) ~= "number" then return tostring(n) end
    return string.format("%.3f", n)
end

local function fmtVec(v)
    if typeof(v) ~= "Vector3" then return tostring(v) end
    return string.format("%.3f, %.3f, %.3f", v.X, v.Y, v.Z)
end

local function fmtColor(c)
    if typeof(c) ~= "Color3" then return tostring(c) end
    return string.format("RGB(%d, %d, %d)", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function vecClose(a, b, eps)
    eps = eps or 0.001
    return typeof(a) == "Vector3" and typeof(b) == "Vector3" and (a - b).Magnitude <= eps
end

local function colorClose(a, b, eps)
    eps = eps or (1 / 255)
    return typeof(a) == "Color3" and typeof(b) == "Color3" and math.abs(a.R - b.R) <= eps and math.abs(a.G - b.G) <= eps and math.abs(a.B - b.B) <= eps
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

local function numberFromText(text, fallback)
    local n = tonumber(tostring(text):match("%-?%d+%.?%d*"))
    if n ~= nil then return n end
    return fallback
end

local function getTargetParent()
    return ReplicatedStorage
end

local function getBrick()
    return getTargetParent():FindFirstChild(Settings.BrickName)
end

local function isLuaSourceContainer(inst)
    return inst:IsA("LuaSourceContainer")
end

local function clipboardSet(text)
    text = tostring(text or "")
    local ok = false
    local err = nil

    if typeof(setclipboard) == "function" then
        ok, err = pcall(setclipboard, text)
        if ok then return true, "Copied to clipboard." end
    end
    if typeof(toclipboard) == "function" then
        ok, err = pcall(toclipboard, text)
        if ok then return true, "Copied to clipboard." end
    end
    if typeof(set_clipboard) == "function" then
        ok, err = pcall(set_clipboard, text)
        if ok then return true, "Copied to clipboard." end
    end

    return false, "Clipboard function not available. The report was placed in the output box."
end

local function serializeValue(value)
    local t = typeof(value)
    if t == "string" then
        return string.format("%q", value)
    elseif t == "number" or t == "boolean" then
        return tostring(value)
    elseif t == "Vector3" then
        return string.format("Vector3.new(%s, %s, %s)", tostring(value.X), tostring(value.Y), tostring(value.Z))
    elseif t == "Vector2" then
        return string.format("Vector2.new(%s, %s)", tostring(value.X), tostring(value.Y))
    elseif t == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", math.floor(value.R * 255 + 0.5), math.floor(value.G * 255 + 0.5), math.floor(value.B * 255 + 0.5))
    elseif t == "CFrame" then
        local components = { value:GetComponents() }
        local parts = {}
        for i, n in ipairs(components) do
            parts[i] = tostring(n)
        end
        return "CFrame.new(" .. table.concat(parts, ", ") .. ")"
    elseif t == "BrickColor" then
        return string.format("BrickColor.new(%q)", value.Name)
    elseif t == "EnumItem" then
        return tostring(value)
    elseif t == "UDim" then
        return string.format("UDim.new(%s, %s)", tostring(value.Scale), tostring(value.Offset))
    elseif t == "UDim2" then
        return string.format("UDim2.new(%s, %s, %s, %s)", tostring(value.X.Scale), tostring(value.X.Offset), tostring(value.Y.Scale), tostring(value.Y.Offset))
    end
    return "nil --[[ unsupported attribute type: " .. tostring(t) .. " ]]"
end

local function readAttributes(inst)
    local ok, attrs = pcall(function()
        return inst:GetAttributes()
    end)
    if ok and type(attrs) == "table" then
        return attrs
    end
    return {}
end

local function readTags(inst)
    local ok, tags = pcall(function()
        return CollectionService:GetTags(inst)
    end)
    if ok and type(tags) == "table" then
        return tags
    end
    return {}
end

local function snapshotBrick(brick)
    if not brick then
        return nil, "Brick missing"
    end
    if not brick:IsA("BasePart") then
        return nil, "Target exists but is not a BasePart: " .. brick.ClassName
    end

    local snap = {
        Path = safeFullName(brick),
        Name = brick.Name,
        ClassName = brick.ClassName,
        ParentName = brick.Parent and brick.Parent.Name or "nil",
        Archivable = brick.Archivable,
        Size = brick.Size,
        CFrame = brick.CFrame,
        Position = brick.Position,
        Orientation = brick.Orientation,
        PivotOffset = brick.PivotOffset,
        Anchored = brick.Anchored,
        Locked = brick.Locked,
        Massless = brick.Massless,
        CanCollide = brick.CanCollide,
        CanQuery = brick.CanQuery,
        CanTouch = brick.CanTouch,
        CollisionGroup = brick.CollisionGroup,
        Material = brick.Material,
        MaterialVariant = brick.MaterialVariant,
        Color = brick.Color,
        BrickColor = brick.BrickColor,
        Transparency = brick.Transparency,
        Reflectance = brick.Reflectance,
        CastShadow = brick.CastShadow,
        TopSurface = brick.TopSurface,
        BottomSurface = brick.BottomSurface,
        FrontSurface = brick.FrontSurface,
        BackSurface = brick.BackSurface,
        LeftSurface = brick.LeftSurface,
        RightSurface = brick.RightSurface,
        CustomPhysicalProperties = brick.CustomPhysicalProperties,
        Attributes = readAttributes(brick),
        Tags = readTags(brick),
        Children = brick:GetChildren(),
    }

    pcall(function() snap.AssemblyMass = brick.AssemblyMass end)
    pcall(function() snap.AssemblyCenterOfMass = brick.AssemblyCenterOfMass end)
    pcall(function() snap.AssemblyLinearVelocity = brick.AssemblyLinearVelocity end)
    pcall(function() snap.AssemblyAngularVelocity = brick.AssemblyAngularVelocity end)

    return snap
end

local function applySnapshotToSettings(snap)
    if not snap then return end
    Settings.BrickName = snap.Name or Settings.BrickName
    Settings.Position = snap.Position or Settings.Position
    Settings.Size = snap.Size or Settings.Size
    Settings.Color = snap.Color or Settings.Color
    Settings.BrickColor = snap.BrickColor or Settings.BrickColor
    Settings.Material = snap.Material or Settings.Material
    Settings.MaterialVariant = snap.MaterialVariant or Settings.MaterialVariant
    Settings.Transparency = snap.Transparency or Settings.Transparency
    Settings.Reflectance = snap.Reflectance or Settings.Reflectance
    Settings.Anchored = snap.Anchored
    Settings.Locked = snap.Locked
    Settings.Archivable = snap.Archivable
    Settings.Massless = snap.Massless
    Settings.CanCollide = snap.CanCollide
    Settings.CanQuery = snap.CanQuery
    Settings.CanTouch = snap.CanTouch
    Settings.CastShadow = snap.CastShadow
    Settings.CollisionGroup = snap.CollisionGroup or Settings.CollisionGroup
    Settings.TopSurface = snap.TopSurface or Settings.TopSurface
    Settings.BottomSurface = snap.BottomSurface or Settings.BottomSurface
    Settings.FrontSurface = snap.FrontSurface or Settings.FrontSurface
    Settings.BackSurface = snap.BackSurface or Settings.BackSurface
    Settings.LeftSurface = snap.LeftSurface or Settings.LeftSurface
    Settings.RightSurface = snap.RightSurface or Settings.RightSurface
end

local function statusLine()
    local brick = getBrick()
    if not brick then
        return "MISSING: ReplicatedStorage." .. Settings.BrickName
    end
    if not brick:IsA("BasePart") then
        return "FOUND, BUT WRONG TYPE: " .. brick.ClassName
    end
    return string.format("OK: %s | Size %.1f, %.1f, %.1f | Pos %.1f, %.1f, %.1f", safeFullName(brick), brick.Size.X, brick.Size.Y, brick.Size.Z, brick.Position.X, brick.Position.Y, brick.Position.Z)
end

local function makeBrickFromSettings()
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
    brick.MaterialVariant = Settings.MaterialVariant or ""
    brick.Color = Settings.Color
    brick.BrickColor = Settings.BrickColor
    brick.Transparency = Settings.Transparency
    brick.Reflectance = Settings.Reflectance
    brick.TopSurface = Settings.TopSurface
    brick.BottomSurface = Settings.BottomSurface
    brick.FrontSurface = Settings.FrontSurface
    brick.BackSurface = Settings.BackSurface
    brick.LeftSurface = Settings.LeftSurface
    brick.RightSurface = Settings.RightSurface
    pcall(function() brick.CollisionGroup = Settings.CollisionGroup end)
    brick.Parent = getTargetParent()
    return brick
end

local function restoreBrick(forceReplace)
    if Settings.ServerRestoreOnly and not IS_SERVER then
        return false, "Server-only mode is ON. Client restore was blocked."
    end

    local existing = getBrick()
    if existing and not forceReplace and not Settings.ReplaceExisting then
        return false, "Brick already exists. Enable Replace Existing or use Force Restore."
    end

    if existing then existing:Destroy() end
    local brick = makeBrickFromSettings()

    local modeNote = IS_SERVER and "server" or "client/local only"
    return true, "Restored " .. safeFullName(brick) .. " (mode: " .. modeNote .. ")"
end

local function backupBrick()
    if not IS_SERVER then
        return false, "Backup requires server-side execution."
    end
    local brick = getBrick()
    if not brick then return false, "No brick exists to back up." end
    local old = ServerStorage:FindFirstChild("BkitBrickBackup")
    if old then old:Destroy() end
    local backup = brick:Clone()
    backup.Name = "BkitBrickBackup"
    backup.Parent = ServerStorage
    return true, "Backup saved to ServerStorage.BkitBrickBackup"
end

local function restoreFromBackup()
    if not IS_SERVER then
        return false, "Restore from backup requires server-side execution."
    end
    local backup = ServerStorage:FindFirstChild("BkitBrickBackup")
    if not backup then return false, "No backup found in ServerStorage." end
    local existing = getBrick()
    if existing then existing:Destroy() end
    local clone = backup:Clone()
    clone.Name = Settings.BrickName
    clone.Parent = getTargetParent()
    return true, "Restored from backup."
end

local function generateRecreateScript(snap)
    snap = snap or snapshotBrick(getBrick())
    if type(snap) ~= "table" then
        snap = {
            Name = Settings.BrickName,
            Size = Settings.Size,
            Position = Settings.Position,
            Anchored = Settings.Anchored,
            Locked = Settings.Locked,
            Archivable = Settings.Archivable,
            CanCollide = Settings.CanCollide,
            CanQuery = Settings.CanQuery,
            CanTouch = Settings.CanTouch,
            CastShadow = Settings.CastShadow,
            Massless = Settings.Massless,
            Material = Settings.Material,
            MaterialVariant = Settings.MaterialVariant,
            Color = Settings.Color,
            BrickColor = Settings.BrickColor,
            Transparency = Settings.Transparency,
            Reflectance = Settings.Reflectance,
            CollisionGroup = Settings.CollisionGroup,
            TopSurface = Settings.TopSurface,
            BottomSurface = Settings.BottomSurface,
            FrontSurface = Settings.FrontSurface,
            BackSurface = Settings.BackSurface,
            LeftSurface = Settings.LeftSurface,
            RightSurface = Settings.RightSurface,
            Attributes = {},
            Tags = {},
        }
    end

    local lines = {}
    table.insert(lines, "-- Generated by Bkit Restore Panel v3")
    table.insert(lines, "-- Real restore must run server-side in a place you own/admin.")
    table.insert(lines, "local ReplicatedStorage = game:GetService(\"ReplicatedStorage\")")
    table.insert(lines, "local existing = ReplicatedStorage:FindFirstChild(" .. string.format("%q", snap.Name or Settings.BrickName) .. ")")
    table.insert(lines, "if existing then existing:Destroy() end")
    table.insert(lines, "")
    table.insert(lines, "local brick = Instance.new(\"Part\")")
    table.insert(lines, "brick.Name = " .. string.format("%q", snap.Name or Settings.BrickName))
    table.insert(lines, "brick.Size = " .. serializeValue(snap.Size or Settings.Size))
    table.insert(lines, "brick.CFrame = CFrame.new(" .. fmtVec(snap.Position or Settings.Position) .. ")")
    table.insert(lines, "brick.Anchored = " .. tostring(snap.Anchored ~= false))
    table.insert(lines, "brick.Locked = " .. tostring(snap.Locked ~= false))
    table.insert(lines, "brick.Archivable = " .. tostring(snap.Archivable ~= false))
    table.insert(lines, "brick.CanCollide = " .. tostring(snap.CanCollide ~= false))
    table.insert(lines, "brick.CanQuery = " .. tostring(snap.CanQuery ~= false))
    table.insert(lines, "brick.CanTouch = " .. tostring(snap.CanTouch ~= false))
    table.insert(lines, "brick.CastShadow = " .. tostring(snap.CastShadow ~= false))
    table.insert(lines, "brick.Massless = " .. tostring(snap.Massless == true))
    table.insert(lines, "brick.Material = " .. tostring(snap.Material or Settings.Material))
    if snap.MaterialVariant and snap.MaterialVariant ~= "" then
        table.insert(lines, "brick.MaterialVariant = " .. string.format("%q", snap.MaterialVariant))
    end
    table.insert(lines, "brick.Color = " .. serializeValue(snap.Color or Settings.Color))
    if snap.BrickColor then
        table.insert(lines, "brick.BrickColor = " .. serializeValue(snap.BrickColor))
    end
    table.insert(lines, "brick.Transparency = " .. tostring(snap.Transparency or 0))
    table.insert(lines, "brick.Reflectance = " .. tostring(snap.Reflectance or 0))
    table.insert(lines, "pcall(function() brick.CollisionGroup = " .. string.format("%q", snap.CollisionGroup or "Default") .. " end)")
    table.insert(lines, "brick.TopSurface = " .. tostring(snap.TopSurface or Settings.TopSurface))
    table.insert(lines, "brick.BottomSurface = " .. tostring(snap.BottomSurface or Settings.BottomSurface))
    table.insert(lines, "brick.FrontSurface = " .. tostring(snap.FrontSurface or Settings.FrontSurface))
    table.insert(lines, "brick.BackSurface = " .. tostring(snap.BackSurface or Settings.BackSurface))
    table.insert(lines, "brick.LeftSurface = " .. tostring(snap.LeftSurface or Settings.LeftSurface))
    table.insert(lines, "brick.RightSurface = " .. tostring(snap.RightSurface or Settings.RightSurface))

    local attrs = snap.Attributes or {}
    local attrCount = 0
    for k, v in pairs(attrs) do
        attrCount += 1
        table.insert(lines, "brick:SetAttribute(" .. string.format("%q", k) .. ", " .. serializeValue(v) .. ")")
    end

    local tags = snap.Tags or {}
    if #tags > 0 then
        table.insert(lines, "local CollectionService = game:GetService(\"CollectionService\")")
        for _, tag in ipairs(tags) do
            table.insert(lines, "CollectionService:AddTag(brick, " .. string.format("%q", tag) .. ")")
        end
    end

    table.insert(lines, "brick.Parent = ReplicatedStorage")
    table.insert(lines, "print(\"[Bkit Restore] ReplicatedStorage.\" .. brick.Name .. \" restored\")")
    return table.concat(lines, "\n")
end

local function brickInfoReport()
    local brick = getBrick()
    local snap, err = snapshotBrick(brick)
    local lines = {}
    table.insert(lines, "=== BKIT BRICK INFO ===")
    table.insert(lines, "Generated: " .. nowString())
    table.insert(lines, "Mode: " .. (IS_SERVER and "Server" or "Client/local"))
    table.insert(lines, "PlaceId: " .. tostring(game.PlaceId))
    table.insert(lines, "JobId: " .. tostring(game.JobId))
    table.insert(lines, "Target: ReplicatedStorage." .. Settings.BrickName)
    table.insert(lines, "Status: " .. statusLine())
    table.insert(lines, "")

    if not snap then
        table.insert(lines, "No snapshot: " .. tostring(err))
        LastBrickReport = table.concat(lines, "\n")
        return LastBrickReport
    end

    table.insert(lines, "Path: " .. snap.Path)
    table.insert(lines, "Class: " .. snap.ClassName)
    table.insert(lines, "")
    table.insert(lines, "--- Properties ---")
    table.insert(lines, "Name = " .. snap.Name)
    table.insert(lines, "ClassName = " .. snap.ClassName)
    table.insert(lines, "Archivable = " .. tostring(snap.Archivable))
    table.insert(lines, "Parent = " .. snap.ParentName)
    table.insert(lines, "Size = " .. fmtVec(snap.Size))
    table.insert(lines, "CFrame = Position " .. fmtVec(snap.Position))
    table.insert(lines, "Position = " .. fmtVec(snap.Position))
    table.insert(lines, "Orientation = " .. fmtVec(snap.Orientation))
    table.insert(lines, "PivotOffset = Position " .. fmtVec(snap.PivotOffset.Position))
    table.insert(lines, "Anchored = " .. tostring(snap.Anchored))
    table.insert(lines, "Locked = " .. tostring(snap.Locked))
    table.insert(lines, "Massless = " .. tostring(snap.Massless))
    table.insert(lines, "CanCollide = " .. tostring(snap.CanCollide))
    table.insert(lines, "CanQuery = " .. tostring(snap.CanQuery))
    table.insert(lines, "CanTouch = " .. tostring(snap.CanTouch))
    table.insert(lines, "CollisionGroup = " .. tostring(snap.CollisionGroup))
    table.insert(lines, "Material = " .. tostring(snap.Material))
    table.insert(lines, "MaterialVariant = " .. tostring(snap.MaterialVariant))
    table.insert(lines, "Color = " .. fmtColor(snap.Color))
    table.insert(lines, "BrickColor = " .. tostring(snap.BrickColor))
    table.insert(lines, "Transparency = " .. tostring(snap.Transparency))
    table.insert(lines, "Reflectance = " .. tostring(snap.Reflectance))
    table.insert(lines, "CastShadow = " .. tostring(snap.CastShadow))
    table.insert(lines, "TopSurface = " .. tostring(snap.TopSurface))
    table.insert(lines, "BottomSurface = " .. tostring(snap.BottomSurface))
    table.insert(lines, "FrontSurface = " .. tostring(snap.FrontSurface))
    table.insert(lines, "BackSurface = " .. tostring(snap.BackSurface))
    table.insert(lines, "LeftSurface = " .. tostring(snap.LeftSurface))
    table.insert(lines, "RightSurface = " .. tostring(snap.RightSurface))
    table.insert(lines, "AssemblyMass = " .. tostring(snap.AssemblyMass))
    table.insert(lines, "AssemblyCenterOfMass = " .. fmtVec(snap.AssemblyCenterOfMass))
    table.insert(lines, "AssemblyLinearVelocity = " .. fmtVec(snap.AssemblyLinearVelocity))
    table.insert(lines, "AssemblyAngularVelocity = " .. fmtVec(snap.AssemblyAngularVelocity))
    table.insert(lines, "CustomPhysicalProperties = " .. tostring(snap.CustomPhysicalProperties))
    table.insert(lines, "")

    table.insert(lines, "--- Attributes ---")
    local attrCount = 0
    for k, v in pairs(snap.Attributes) do
        attrCount += 1
        table.insert(lines, tostring(k) .. " = " .. tostring(v) .. " <" .. typeof(v) .. ">")
    end
    if attrCount == 0 then table.insert(lines, "No attributes.") end
    table.insert(lines, "")

    table.insert(lines, "--- Tags ---")
    if #snap.Tags == 0 then
        table.insert(lines, "No tags or tags not readable.")
    else
        for _, tag in ipairs(snap.Tags) do table.insert(lines, tag) end
    end
    table.insert(lines, "")

    table.insert(lines, "--- Children ---")
    if #snap.Children == 0 then
        table.insert(lines, "No children.")
    else
        for _, child in ipairs(snap.Children) do
            table.insert(lines, safeFullName(child) .. " <" .. child.ClassName .. ">")
        end
    end

    LastBrickReport = table.concat(lines, "\n")
    return LastBrickReport
end

local function sameTemplateProperties(part, snap)
    if not part or not part:IsA("BasePart") or not snap then return false end
    if not vecClose(part.Size, snap.Size, 0.001) then return false end
    if part.Material ~= snap.Material then return false end
    if not colorClose(part.Color, snap.Color) then return false end
    if part.TopSurface ~= snap.TopSurface then return false end
    if part.BottomSurface ~= snap.BottomSurface then return false end
    if part.Anchored ~= snap.Anchored then return false end
    if part.CanCollide ~= snap.CanCollide then return false end
    return true
end

local function ensureBaseline()
    if Baseline then return Baseline end
    local snap = snapshotBrick(getBrick())
    if snap then
        Baseline = snap
    else
        Baseline = {
            Name = Settings.BrickName,
            ClassName = "Part",
            ParentName = "ReplicatedStorage",
            Size = Settings.Size,
            Position = Settings.Position,
            Anchored = Settings.Anchored,
            Locked = Settings.Locked,
            Massless = Settings.Massless,
            CanCollide = Settings.CanCollide,
            CanQuery = Settings.CanQuery,
            CanTouch = Settings.CanTouch,
            CastShadow = Settings.CastShadow,
            CollisionGroup = Settings.CollisionGroup,
            Material = Settings.Material,
            MaterialVariant = Settings.MaterialVariant,
            Color = Settings.Color,
            Transparency = Settings.Transparency,
            Reflectance = Settings.Reflectance,
            TopSurface = Settings.TopSurface,
            BottomSurface = Settings.BottomSurface,
            FrontSurface = Settings.FrontSurface,
            BackSurface = Settings.BackSurface,
            LeftSurface = Settings.LeftSurface,
            RightSurface = Settings.RightSurface,
            Attributes = {},
            Tags = {},
            Children = {},
        }
    end
    return Baseline
end

local function integrityReport()
    local current, err = snapshotBrick(getBrick())
    local base = ensureBaseline()
    local lines = {}
    table.insert(lines, "=== BKIT INTEGRITY CHECK ===")
    table.insert(lines, "Generated: " .. nowString())
    table.insert(lines, "Mode: " .. (IS_SERVER and "Server" or "Client/local"))
    table.insert(lines, "Target: ReplicatedStorage." .. Settings.BrickName)
    table.insert(lines, "Status: " .. statusLine())
    table.insert(lines, "")

    if not current then
        table.insert(lines, "Integrity: 0%")
        table.insert(lines, "FAIL: " .. tostring(err))
        LastIntegrityReport = table.concat(lines, "\n")
        return LastIntegrityReport
    end

    local checks = {
        {"ClassName", current.ClassName, base.ClassName, function(a,b) return a == b end},
        {"Parent", current.ParentName, "ReplicatedStorage", function(a,b) return a == b end},
        {"Size", current.Size, base.Size, vecClose},
        {"Position", current.Position, base.Position, function(a,b) return vecClose(a,b,0.05) end},
        {"Anchored", current.Anchored, base.Anchored, function(a,b) return a == b end},
        {"Locked", current.Locked, base.Locked, function(a,b) return a == b end},
        {"Massless", current.Massless, base.Massless, function(a,b) return a == b end},
        {"CanCollide", current.CanCollide, base.CanCollide, function(a,b) return a == b end},
        {"CanQuery", current.CanQuery, base.CanQuery, function(a,b) return a == b end},
        {"CanTouch", current.CanTouch, base.CanTouch, function(a,b) return a == b end},
        {"CastShadow", current.CastShadow, base.CastShadow, function(a,b) return a == b end},
        {"CollisionGroup", current.CollisionGroup, base.CollisionGroup, function(a,b) return a == b end},
        {"Material", current.Material, base.Material, function(a,b) return a == b end},
        {"MaterialVariant", current.MaterialVariant, base.MaterialVariant, function(a,b) return a == b end},
        {"Color", current.Color, base.Color, colorClose},
        {"Transparency", current.Transparency, base.Transparency, function(a,b) return math.abs((a or 0)-(b or 0)) < 0.001 end},
        {"Reflectance", current.Reflectance, base.Reflectance, function(a,b) return math.abs((a or 0)-(b or 0)) < 0.001 end},
        {"TopSurface", current.TopSurface, base.TopSurface, function(a,b) return a == b end},
        {"BottomSurface", current.BottomSurface, base.BottomSurface, function(a,b) return a == b end},
        {"FrontSurface", current.FrontSurface, base.FrontSurface, function(a,b) return a == b end},
        {"BackSurface", current.BackSurface, base.BackSurface, function(a,b) return a == b end},
        {"LeftSurface", current.LeftSurface, base.LeftSurface, function(a,b) return a == b end},
        {"RightSurface", current.RightSurface, base.RightSurface, function(a,b) return a == b end},
    }

    local passed = 0
    for _, c in ipairs(checks) do
        local name, actual, expected, cmp = c[1], c[2], c[3], c[4]
        local ok = false
        pcall(function() ok = cmp(actual, expected) end)
        if ok then passed += 1 end
    end

    local pct = math.floor((passed / #checks) * 100 + 0.5)
    table.insert(lines, "Integrity: " .. tostring(pct) .. "%")
    table.insert(lines, "Passed: " .. passed .. "/" .. #checks)
    table.insert(lines, "")
    for _, c in ipairs(checks) do
        local name, actual, expected, cmp = c[1], c[2], c[3], c[4]
        local ok = false
        pcall(function() ok = cmp(actual, expected) end)
        local a = tostring(actual)
        local e = tostring(expected)
        if typeof(actual) == "Vector3" then a = fmtVec(actual) end
        if typeof(expected) == "Vector3" then e = fmtVec(expected) end
        if typeof(actual) == "Color3" then a = fmtColor(actual) end
        if typeof(expected) == "Color3" then e = fmtColor(expected) end
        table.insert(lines, (ok and "OK   " or "DIFF ") .. name .. " | current: " .. a .. " | expected: " .. e)
    end

    LastIntegrityReport = table.concat(lines, "\n")
    return LastIntegrityReport
end

local function scanDependencies()
    local target = getBrick()
    local targetName = Settings.BrickName
    local targetPath = "ReplicatedStorage." .. targetName
    local targetSnap = target and snapshotBrick(target) or ensureBaseline()

    local stats = {
        instances = 0,
        baseParts = 0,
        nameMatches = 0,
        cloneCandidates = 0,
        objectValueRefs = 0,
        stringRefs = 0,
        remoteCandidates = 0,
        toolCandidates = 0,
        readableScripts = 0,
        unreadableScripts = 0,
        scriptRefs = 0,
        errors = 0,
    }

    local nameSamples, cloneSamples, objectValueSamples, stringSamples = {}, {}, {}, {}
    local remoteSamples, toolSamples, scriptSamples, lockedScriptSamples, errorSamples = {}, {}, {}, {}, {}

    local function addSample(list, line)
        if #list < Settings.MaxResults then
            table.insert(list, line)
        end
    end

    local okDesc, descendants = pcall(function()
        return game:GetDescendants()
    end)
    if not okDesc then
        descendants = {}
        stats.errors += 1
        addSample(errorSamples, "Could not scan game descendants: " .. tostring(descendants))
    end

    local strictPatterns = {
        "ReplicatedStorage%.Brick",
        "FindFirstChild%(%s*[\"']Brick[\"']%s*%)",
        "WaitForChild%(%s*[\"']Brick[\"']%s*%)",
        "game:GetService%(%s*[\"']ReplicatedStorage[\"']%s*%).-Brick",
        "Brick%s*:%s*Clone%s*%(",
        "ReplicatedStorage%s*:%s*FindFirstChild%(%s*[\"']Brick[\"']%s*%)",
    }

    local loosePatterns = {
        "Brick",
        "Bkit",
        "Build",
        "Delete",
        "Clone%(%s*%)",
        "ReplicatedStorage",
    }

    local remoteNameWords = {"bkit", "build", "brick", "delete", "paint", "resize", "shape", "move", "clone", "event", "remote", "place", "remove"}
    local toolNameWords = {"bkit", "build", "delete", "paint", "resize", "shape", "move", "clone", "copy", "hammer", "brick", "shovel", "sign"}
    local function containsAnyWordLower(text, words)
        text = string.lower(tostring(text or ""))
        for _, word in ipairs(words) do
            if text:find(word, 1, true) then
                return true
            end
        end
        return false
    end

    for i, inst in ipairs(descendants) do
        stats.instances += 1

        if inst:IsA("BasePart") then
            stats.baseParts += 1
        end

        if inst ~= target and inst.Name == targetName then
            stats.nameMatches += 1
            if Settings.ShowNameOnlyMatches then
                addSample(nameSamples, "NAME MATCH: " .. safeFullName(inst) .. " <" .. inst.ClassName .. ">")
            end
        end

        if targetSnap and inst ~= target and inst:IsA("BasePart") and inst.Name == targetName and sameTemplateProperties(inst, targetSnap) then
            stats.cloneCandidates += 1
            addSample(cloneSamples, "CLONE CANDIDATE: " .. safeFullName(inst) .. " | Pos " .. fmtVec(inst.Position))
        end

        if inst:IsA("ObjectValue") then
            local okVal, val = pcall(function() return inst.Value end)
            if okVal and val == target then
                stats.objectValueRefs += 1
                addSample(objectValueSamples, "OBJECTVALUE REF: " .. safeFullName(inst) .. " -> " .. targetPath)
            end
        end

        if inst:IsA("StringValue") or inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
            local okText, text = pcall(function()
                if inst:IsA("StringValue") then return inst.Value end
                return inst.Text
            end)
            if okText and type(text) == "string" and (text:find(targetName, 1, true) or text:find(targetPath, 1, true)) then
                stats.stringRefs += 1
                addSample(stringSamples, "TEXT REF: " .. safeFullName(inst) .. " <" .. inst.ClassName .. "> = " .. text:sub(1, 120))
            end
        end

        if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("BindableEvent") or inst:IsA("BindableFunction") then
            local n = string.lower(inst.Name)
            local p = string.lower(safeFullName(inst))
            if containsAnyWordLower(n, remoteNameWords) or containsAnyWordLower(p, remoteNameWords) then
                stats.remoteCandidates += 1
                addSample(remoteSamples, "REMOTE/BINDABLE: " .. safeFullName(inst) .. " <" .. inst.ClassName .. ">")
            end
        end

        if inst:IsA("Tool") then
            local n = string.lower(inst.Name)
            local p = string.lower(safeFullName(inst))
            if containsAnyWordLower(n, toolNameWords) or containsAnyWordLower(p, toolNameWords) then
                stats.toolCandidates += 1
                local remotes = {}
                for _, d in ipairs(inst:GetDescendants()) do
                    if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") or d:IsA("BindableFunction") then
                        table.insert(remotes, d.Name .. "<" .. d.ClassName .. ">")
                    end
                end
                addSample(toolSamples, "TOOL: " .. safeFullName(inst) .. " | remotes/bindables: " .. (#remotes > 0 and table.concat(remotes, ", ") or "none found"))
            end
        end

        if isLuaSourceContainer(inst) then
            local okSource, source = pcall(function()
                return inst.Source
            end)
            if okSource and type(source) == "string" then
                stats.readableScripts += 1
                if #source > Settings.MaxScriptChars then
                    source = source:sub(1, Settings.MaxScriptChars)
                end
                local patterns = Settings.StrictSearch and strictPatterns or loosePatterns
                local matches = {}
                for _, pattern in ipairs(patterns) do
                    if source:find(pattern) then
                        table.insert(matches, pattern)
                    end
                end
                if #matches > 0 then
                    stats.scriptRefs += 1
                    local line = "SCRIPT REF: " .. safeFullName(inst) .. " <" .. inst.ClassName .. "> | patterns: " .. table.concat(matches, ", ")
                    if Settings.IncludeSnippets then
                        local first = nil
                        for _, pattern in ipairs(patterns) do
                            first = source:find(pattern)
                            if first then break end
                        end
                        if first then
                            local a = math.max(1, first - 140)
                            local b = math.min(#source, first + 220)
                            local snippet = source:sub(a, b):gsub("\r", ""):gsub("\n", " ")
                            line = line .. " | snippet: " .. snippet
                        end
                    end
                    addSample(scriptSamples, line)
                end
            else
                stats.unreadableScripts += 1
                addSample(lockedScriptSamples, "LOCKED SCRIPT: " .. safeFullName(inst) .. " <" .. inst.ClassName .. ">")
            end
        end

        if i % 2500 == 0 then
            task.wait()
        end
    end

    local lines = {}
    table.insert(lines, "=== BKIT DEPENDENCY SCAN V3 ===")
    table.insert(lines, "Generated: " .. nowString())
    table.insert(lines, "Mode: " .. (IS_SERVER and "Server" or "Client/local"))
    table.insert(lines, "Target name: " .. targetName)
    table.insert(lines, "Target object: " .. targetPath)
    table.insert(lines, "Target status: " .. statusLine())
    table.insert(lines, "Strict search: " .. tostring(Settings.StrictSearch))
    table.insert(lines, "Include snippets: " .. tostring(Settings.IncludeSnippets))
    table.insert(lines, "Max results per section: " .. tostring(Settings.MaxResults))
    table.insert(lines, "")

    table.insert(lines, "--- Summary ---")
    table.insert(lines, "Instances searched: " .. stats.instances)
    table.insert(lines, "BaseParts searched: " .. stats.baseParts)
    table.insert(lines, "Name-only matches: " .. stats.nameMatches .. " (usually placed bricks, not real dependencies)")
    table.insert(lines, "Clone candidates: " .. stats.cloneCandidates)
    table.insert(lines, "ObjectValue exact references: " .. stats.objectValueRefs)
    table.insert(lines, "Text/String references: " .. stats.stringRefs)
    table.insert(lines, "Remote/Bindable candidates: " .. stats.remoteCandidates)
    table.insert(lines, "Bkit/build tool candidates: " .. stats.toolCandidates)
    table.insert(lines, "Readable scripts: " .. stats.readableScripts)
    table.insert(lines, "Unreadable scripts: " .. stats.unreadableScripts)
    table.insert(lines, "Script references found: " .. stats.scriptRefs)
    table.insert(lines, "Errors: " .. stats.errors)
    table.insert(lines, "")

    table.insert(lines, "--- Clone Candidates ---")
    if #cloneSamples == 0 then table.insert(lines, "None found.") else for _, v in ipairs(cloneSamples) do table.insert(lines, v) end end
    table.insert(lines, "")

    table.insert(lines, "--- Exact Object References ---")
    if #objectValueSamples == 0 then table.insert(lines, "No ObjectValue references to the template found.") else for _, v in ipairs(objectValueSamples) do table.insert(lines, v) end end
    table.insert(lines, "")

    table.insert(lines, "--- Text/String References ---")
    if #stringSamples == 0 then table.insert(lines, "No readable text/string references found.") else for _, v in ipairs(stringSamples) do table.insert(lines, v) end end
    table.insert(lines, "")

    table.insert(lines, "--- Remote / Bindable Candidates ---")
    if #remoteSamples == 0 then table.insert(lines, "None found.") else for _, v in ipairs(remoteSamples) do table.insert(lines, v) end end
    table.insert(lines, "")

    table.insert(lines, "--- Tool Candidates ---")
    if #toolSamples == 0 then table.insert(lines, "None found.") else for _, v in ipairs(toolSamples) do table.insert(lines, v) end end
    table.insert(lines, "")

    table.insert(lines, "--- Readable Script References ---")
    if #scriptSamples == 0 then table.insert(lines, "No readable script references found.") else for _, v in ipairs(scriptSamples) do table.insert(lines, v) end end
    table.insert(lines, "")

    table.insert(lines, "--- Locked / Unreadable Scripts ---")
    if #lockedScriptSamples == 0 then table.insert(lines, "None.") else for _, v in ipairs(lockedScriptSamples) do table.insert(lines, v) end end
    table.insert(lines, "")

    if Settings.ShowNameOnlyMatches then
        table.insert(lines, "--- Name-only Matches ---")
        if #nameSamples == 0 then table.insert(lines, "None.") else for _, v in ipairs(nameSamples) do table.insert(lines, v) end end
        table.insert(lines, "")
    end

    table.insert(lines, "--- Notes ---")
    table.insert(lines, "Name-only Workspace.Bricks.Brick matches are probably placed bricks cloned from the template.")
    table.insert(lines, "In live games, Script.Source is usually locked, so server dependencies may not be readable from a client.")
    table.insert(lines, "For best dependency results, run this in Studio/server context in a place you own.")

    LastScanReport = table.concat(lines, "\n")
    return LastScanReport
end

local function fullDiagnosticReport()
    local report = table.concat({
        brickInfoReport(),
        "",
        integrityReport(),
        "",
        scanDependencies(),
        "",
        "=== RECREATE SCRIPT ===",
        generateRecreateScript(snapshotBrick(getBrick())),
    }, "\n")
    return report
end

local function disconnectMonitor()
    for _, c in ipairs(MonitorConnections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(MonitorConnections)
end

local function startMonitor(onMessage)
    disconnectMonitor()
    local function msg(s)
        if onMessage then onMessage(s) end
        print("[Bkit Restore Monitor] " .. tostring(s))
    end

    local c1 = ReplicatedStorage.ChildRemoved:Connect(function(child)
        if child.Name == Settings.BrickName then
            local note = "Template removed at " .. nowString() .. ": " .. child.Name
            msg(note)
            if Settings.AutoWatch then
                local ok, result = restoreBrick(true)
                msg("Auto-watch restore: " .. tostring(result))
            end
        end
    end)
    table.insert(MonitorConnections, c1)

    local brick = getBrick()
    if brick then
        local ok, c2 = pcall(function()
            return brick.Destroying:Connect(function()
                msg("Template Destroying signal fired at " .. nowString())
            end)
        end)
        if ok and c2 then table.insert(MonitorConnections, c2) end
    end

    msg("Monitor started for ReplicatedStorage." .. Settings.BrickName)
end

local function setAutoWatch(enabled, onMessage)
    Settings.AutoWatch = enabled
    if enabled then
        startMonitor(onMessage)
    else
        disconnectMonitor()
        if onMessage then onMessage("Monitor stopped.") end
    end

    if enabled and not AutoThreadRunning then
        AutoThreadRunning = true
        task.spawn(function()
            while Settings.AutoWatch do
                if not getBrick() then
                    local ok, result = restoreBrick(true)
                    if onMessage then onMessage("Auto-watch loop: " .. tostring(result)) end
                end
                task.wait(math.max(1, tonumber(Settings.AutoWatchDelay) or 2))
            end
            AutoThreadRunning = false
        end)
    end
end

-- Server mode: no GUI, but still useful as a server restore script.
if IS_SERVER then
    print("[Bkit Restore] Server mode loaded.")
    print("[Bkit Restore] " .. statusLine())
    Baseline = snapshotBrick(getBrick()) or Baseline
    if not getBrick() then
        local ok, msg = restoreBrick(false)
        print("[Bkit Restore] " .. tostring(msg))
    end
    startMonitor(function(msg) print("[Bkit Restore] " .. tostring(msg)) end)
    return
end

-- Client GUI mode.
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("BkitRestoreGuiV3")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "BkitRestoreGuiV3"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 620, 0, 500)
frame.Position = UDim2.new(0.5, -310, 0.5, -250)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderColor3 = Color3.fromRGB(0, 125, 255)
frame.Active = true
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 32)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Bkit Restore + Diagnostics v3"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.Code
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.new(0, 28, 0, 24)
minimize.Position = UDim2.new(1, -64, 0, 4)
minimize.Text = "-"
minimize.TextColor3 = Color3.fromRGB(255, 255, 255)
minimize.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
minimize.Font = Enum.Font.Code
minimize.TextSize = 16
minimize.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 28, 0, 24)
close.Position = UDim2.new(1, -32, 0, 4)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.BackgroundColor3 = Color3.fromRGB(90, 25, 25)
close.Font = Enum.Font.Code
close.TextSize = 14
close.Parent = frame
close.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Custom dragging, less buggy than deprecated Frame.Draggable.
do
    local dragging = false
    local dragStart, startPos
    title.InputBegan:Connect(function(input)
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
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 48)
status.Position = UDim2.new(0, 10, 0, 36)
status.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
status.BorderColor3 = Color3.fromRGB(55, 55, 55)
status.TextColor3 = Color3.fromRGB(230, 230, 230)
status.Font = Enum.Font.Code
status.TextSize = 13
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = statusLine() .. "\nClient GUI ready. Server restore requires server-side execution."
status.Parent = frame

local output = Instance.new("TextBox")
output.Size = UDim2.new(1, -20, 0, 155)
output.Position = UDim2.new(0, 10, 1, -165)
output.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
output.BorderColor3 = Color3.fromRGB(55, 55, 55)
output.TextColor3 = Color3.fromRGB(230, 230, 230)
output.Font = Enum.Font.Code
output.TextSize = 12
output.TextWrapped = false
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.MultiLine = true
output.ClearTextOnFocus = false
output.TextEditable = true
output.Text = "Output/report box. Copy buttons also place text here."
output.Parent = frame

local function setOutput(text)
    output.Text = tostring(text or "")
    output.CursorPosition = 1
end

local function copyOrOutput(text)
    setOutput(text)
    local ok, msg = clipboardSet(text)
    status.Text = msg
end

local function makeLabel(text, x, y, w)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, w or 92, 0, 22)
    label.Position = UDim2.new(0, x, 0, y)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.Code
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    return label
end

local function makeBox(labelText, defaultText, x, y, w)
    makeLabel(labelText, x, y, 90)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, w or 145, 0, 24)
    box.Position = UDim2.new(0, x + 90, 0, y)
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

local nameBox = makeBox("Name", Settings.BrickName, 10, 95, 155)
local posBox = makeBox("Position", "-90, 22, -74", 10, 125, 155)
local sizeBox = makeBox("Size", "4, 4, 4", 10, 155, 155)
local delayBox = makeBox("Delay", "2", 10, 185, 155)
local maxBox = makeBox("Max Results", tostring(Settings.MaxResults), 10, 215, 155)

local toggles = {}
local function makeToggle(text, initial, x, y, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 140, 0, 24)
    b.Position = UDim2.new(0, x, 0, y)
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    b.BorderColor3 = Color3.fromRGB(80, 80, 80)
    b.Font = Enum.Font.Code
    b.TextSize = 12
    b.Parent = frame

    local state = initial
    local function refresh()
        b.Text = text .. ": " .. (state and "ON" or "OFF")
        b.BackgroundColor3 = state and Color3.fromRGB(20, 70, 35) or Color3.fromRGB(35, 35, 35)
    end
    b.MouseButton1Click:Connect(function()
        state = not state
        refresh()
        callback(state)
    end)
    refresh()
    toggles[text] = {button = b, get = function() return state end, set = function(v) state = v; refresh(); callback(state) end}
    return b
end

makeToggle("Replace", Settings.ReplaceExisting, 300, 95, function(v) Settings.ReplaceExisting = v end)
makeToggle("Strict", Settings.StrictSearch, 455, 95, function(v) Settings.StrictSearch = v end)
makeToggle("Snippets", Settings.IncludeSnippets, 300, 125, function(v) Settings.IncludeSnippets = v end)
makeToggle("Name Matches", Settings.ShowNameOnlyMatches, 455, 125, function(v) Settings.ShowNameOnlyMatches = v end)
makeToggle("Server Only", Settings.ServerRestoreOnly, 300, 155, function(v) Settings.ServerRestoreOnly = v end)
makeToggle("Anchored", Settings.Anchored, 455, 155, function(v) Settings.Anchored = v end)
makeToggle("Locked", Settings.Locked, 300, 185, function(v) Settings.Locked = v end)
makeToggle("Collide", Settings.CanCollide, 455, 185, function(v) Settings.CanCollide = v end)
makeToggle("Query", Settings.CanQuery, 300, 215, function(v) Settings.CanQuery = v end)
makeToggle("Touch", Settings.CanTouch, 455, 215, function(v) Settings.CanTouch = v end)
makeToggle("Shadow", Settings.CastShadow, 300, 245, function(v) Settings.CastShadow = v end)
makeToggle("Massless", Settings.Massless, 455, 245, function(v) Settings.Massless = v end)

local function applyGuiSettings()
    Settings.BrickName = nameBox.Text ~= "" and nameBox.Text or "Brick"
    Settings.Position = vectorFromText(posBox.Text, Settings.Position)
    Settings.Size = vectorFromText(sizeBox.Text, Settings.Size)
    Settings.AutoWatchDelay = math.max(1, numberFromText(delayBox.Text, Settings.AutoWatchDelay))
    Settings.MaxResults = math.clamp(math.floor(numberFromText(maxBox.Text, Settings.MaxResults)), 10, 1000)
end

local function makeButton(text, x, y, w, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0, y)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    b.BorderColor3 = Color3.fromRGB(80, 80, 80)
    b.Font = Enum.Font.Code
    b.TextSize = 12
    b.Parent = frame
    b.MouseButton1Click:Connect(function()
        local old = b.Text
        b.Text = "..."
        local ok, err = pcall(function()
            applyGuiSettings()
            callback()
        end)
        if not ok then
            status.Text = "Button error: " .. tostring(err)
        end
        b.Text = old
    end)
    return b
end

makeButton("Check", 10, 255, 70, function()
    local s = statusLine()
    status.Text = s
    setOutput(s)
end)

makeButton("Integrity", 90, 255, 85, function()
    local r = integrityReport()
    status.Text = "Integrity report generated."
    setOutput(r)
end)

makeButton("Load Current", 185, 255, 100, function()
    local snap, err = snapshotBrick(getBrick())
    if not snap then
        status.Text = "Load failed: " .. tostring(err)
        return
    end
    Baseline = snap
    applySnapshotToSettings(snap)
    nameBox.Text = Settings.BrickName
    posBox.Text = fmtVec(Settings.Position)
    sizeBox.Text = fmtVec(Settings.Size)
    status.Text = "Loaded current brick as baseline/settings."
    setOutput(integrityReport())
end)

makeButton("Restore", 295, 255, 80, function()
    local ok, msg = restoreBrick(false)
    status.Text = msg
    setOutput(msg)
end)

makeButton("Force", 385, 255, 65, function()
    local ok, msg = restoreBrick(true)
    status.Text = msg
    setOutput(msg)
end)

local autoButton
autoButton = makeButton("Auto OFF", 460, 255, 85, function()
    setAutoWatch(not Settings.AutoWatch, function(msg)
        status.Text = msg
        output.Text = tostring(msg) .. "\n" .. output.Text
    end)
    autoButton.Text = Settings.AutoWatch and "Auto ON" or "Auto OFF"
end)

makeButton("Copy Info", 10, 290, 90, function()
    copyOrOutput(brickInfoReport())
end)

makeButton("Scan Deps", 110, 290, 90, function()
    status.Text = "Scanning dependencies..."
    task.wait()
    setOutput(scanDependencies())
    status.Text = "Dependency scan finished."
end)

makeButton("Copy Report", 210, 290, 100, function()
    status.Text = "Building full report..."
    task.wait()
    copyOrOutput(fullDiagnosticReport())
end)

makeButton("Copy Recreate", 320, 290, 115, function()
    LastRecreateScript = generateRecreateScript(snapshotBrick(getBrick()))
    copyOrOutput(LastRecreateScript)
end)

makeButton("Backup", 445, 290, 70, function()
    local ok, msg = backupBrick()
    status.Text = msg
    setOutput(msg)
end)

makeButton("From Backup", 525, 290, 85, function()
    local ok, msg = restoreFromBackup()
    status.Text = msg
    setOutput(msg)
end)

makeButton("Remotes", 10, 325, 90, function()
    applyGuiSettings()
    local oldStrict, oldName = Settings.StrictSearch, Settings.ShowNameOnlyMatches
    Settings.StrictSearch = false
    Settings.ShowNameOnlyMatches = false
    local report = scanDependencies()
    Settings.StrictSearch = oldStrict
    Settings.ShowNameOnlyMatches = oldName
    local section = report:match("%-%-%- Remote / Bindable Candidates %-%-%-(.-)%-%-%- Tool Candidates %-%-%-") or report
    setOutput("=== REMOTE / BINDABLE CANDIDATES ===\n" .. section)
    status.Text = "Remote candidates listed."
end)

makeButton("Tools", 110, 325, 80, function()
    applyGuiSettings()
    local report = scanDependencies()
    local section = report:match("%-%-%- Tool Candidates %-%-%-(.-)%-%-%- Readable Script References %-%-%-") or report
    setOutput("=== TOOL CANDIDATES ===\n" .. section)
    status.Text = "Tool candidates listed."
end)

makeButton("Reset", 200, 325, 70, function()
    Settings.BrickName = "Brick"
    Settings.Position = Vector3.new(-90, 22, -74)
    Settings.Size = Vector3.new(4, 4, 4)
    Settings.AutoWatchDelay = 2
    Settings.MaxResults = 120
    nameBox.Text = Settings.BrickName
    posBox.Text = "-90, 22, -74"
    sizeBox.Text = "4, 4, 4"
    delayBox.Text = "2"
    maxBox.Text = "120"
    status.Text = "Reset default v3 settings."
end)

makeButton("Clear", 280, 325, 70, function()
    setOutput("")
    status.Text = "Output cleared."
end)

makeButton("Copy Output", 360, 325, 100, function()
    copyOrOutput(output.Text)
end)

makeButton("Destroy GUI", 470, 325, 110, function()
    gui:Destroy()
end)

local minimized = false
local originalSize = frame.Size
minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    minimize.Text = minimized and "+" or "-"
    for _, child in ipairs(frame:GetChildren()) do
        if child ~= title and child ~= minimize and child ~= close then
            child.Visible = not minimized
        end
    end
    frame.Size = minimized and UDim2.new(0, 620, 0, 34) or originalSize
end)

Baseline = snapshotBrick(getBrick()) or Baseline
LastRecreateScript = generateRecreateScript(snapshotBrick(getBrick()))
status.Text = statusLine() .. "\nClient GUI ready. Use Copy Report for full diagnostics."
