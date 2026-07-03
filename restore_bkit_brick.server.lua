-- restore_bkit_brick_gui_v5.lua
-- Bkit Restore + Diagnostics v5
-- Fixes from v4:
--   * Does NOT destroy an existing Brick unless forced. It repairs in place so tool LocalScripts keep their Brick reference.
--   * Position is treated as dynamic preview data and ignored by integrity by default.
--   * Client mode can repair/create the local preview Brick and restart local tool scripts.
--   * Server mode actually restores the server ReplicatedStorage.Brick.
--   * GUI uses a clean grid/scroll layout so buttons fit.
--
-- Important:
--   Client/executor loadstring can only fix your LOCAL preview object.
--   To truly restore building for everyone, run this server-side in a place you own/admin.

local VERSION = "v5"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ServerStorage = RunService:IsServer() and game:GetService("ServerStorage") or nil

local IS_SERVER = RunService:IsServer()
local LocalPlayer = not IS_SERVER and Players.LocalPlayer or nil

local Config = {
    BrickName = "Brick",

    -- Position is only a fallback. The Build tool moves ReplicatedStorage.Brick every RenderStepped for preview,
    -- so the current position can be -777,-777,-777 or wherever the preview was last moved.
    DefaultPosition = Vector3.new(-90, 22, -74),
    IgnorePositionIntegrity = true,
    PreserveExistingPosition = true,

    SizeNormal = Vector3.new(4, 4, 4),
    SizeSmall = Vector3.new(1, 1, 1),
    Color = Color3.fromRGB(192, 192, 192),
    BrickColorName = "Light grey",
    Material = Enum.Material.Plastic,
    MaterialVariant = "",
    Transparency = 0,
    Reflectance = 0,
    CollisionGroup = "Default",

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

    AutoWatch = false,
    AutoWatchDelay = 1,
    MaxResults = 80,
    IncludeNameMatches = false,
    IncludeSnippets = true,
    StrictSearch = true,
    ExcludeRobloxCore = true,
    ExcludeOwnGui = true,
}

local function nowString()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function safeFullName(obj)
    local ok, res = pcall(function() return obj:GetFullName() end)
    return ok and res or tostring(obj)
end

local function fmtBool(v)
    return v and "ON" or "OFF"
end

local function fmtVector(v)
    return string.format("%.3f, %.3f, %.3f", v.X, v.Y, v.Z)
end

local function fmtVectorShort(v)
    return string.format("%.1f, %.1f, %.1f", v.X, v.Y, v.Z)
end

local function fmtColor(c)
    return string.format("RGB(%d, %d, %d)", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function vectorFromText(text, fallback)
    local nums = {}
    for n in tostring(text):gmatch("%-?%d+%.?%d*") do
        nums[#nums + 1] = tonumber(n)
    end
    if #nums >= 3 then
        return Vector3.new(nums[1], nums[2], nums[3])
    end
    return fallback
end

local function numberFromText(text, fallback, minValue, maxValue)
    local n = tonumber(tostring(text):match("%-?%d+%.?%d*"))
    if not n then n = fallback end
    if minValue then n = math.max(minValue, n) end
    if maxValue then n = math.min(maxValue, n) end
    return n
end

local function getBrick()
    return ReplicatedStorage:FindFirstChild(Config.BrickName)
end

local function isBrickOk(brick)
    return brick and brick:IsA("BasePart") and brick.Parent == ReplicatedStorage and brick.Name == Config.BrickName
end

local function describeStatus()
    local brick = getBrick()
    if not brick then
        return "MISSING: ReplicatedStorage." .. Config.BrickName
    end
    if not brick:IsA("BasePart") then
        return "FOUND WRONG TYPE: " .. brick.ClassName .. " at " .. safeFullName(brick)
    end
    local mode = IS_SERVER and "Server" or "Client/local"
    return string.format("%s | OK: %s | Size %s | Pos %s", mode, safeFullName(brick), fmtVectorShort(brick.Size), fmtVectorShort(brick.Position))
end

local function applyBrickProperties(brick, options)
    options = options or {}

    brick.Name = Config.BrickName
    brick.Archivable = Config.Archivable
    brick.Anchored = Config.Anchored
    brick.Locked = Config.Locked
    brick.CanCollide = Config.CanCollide
    brick.CanQuery = Config.CanQuery
    brick.CanTouch = Config.CanTouch
    brick.CastShadow = Config.CastShadow
    brick.Massless = Config.Massless
    brick.Material = Config.Material
    pcall(function() brick.MaterialVariant = Config.MaterialVariant end)
    brick.Color = Config.Color
    pcall(function() brick.BrickColor = BrickColor.new(Config.BrickColorName) end)
    brick.Transparency = Config.Transparency
    brick.Reflectance = Config.Reflectance
    pcall(function() brick.CollisionGroup = Config.CollisionGroup end)
    brick.TopSurface = Config.TopSurface
    brick.BottomSurface = Config.BottomSurface
    brick.FrontSurface = Config.FrontSurface
    brick.BackSurface = Config.BackSurface
    brick.LeftSurface = Config.LeftSurface
    brick.RightSurface = Config.RightSurface

    local keepPosition = options.keepPosition
    local position = keepPosition and brick.Position or Config.DefaultPosition
    brick.Size = Config.SizeNormal
    brick.CFrame = CFrame.new(position)
    brick.Parent = ReplicatedStorage
    return brick
end

local function createBrick(keepPosition)
    local brick = Instance.new("Part")
    return applyBrickProperties(brick, { keepPosition = false })
end

local function repairOrCreateBrick(forceRecreate)
    local brick = getBrick()

    if brick and not brick:IsA("BasePart") then
        if forceRecreate then
            brick:Destroy()
            brick = nil
        else
            return false, "ReplicatedStorage." .. Config.BrickName .. " exists but is " .. brick.ClassName .. ". Use Force Recreate."
        end
    end

    if brick and forceRecreate then
        -- Force recreate can break already-running Build LocalScripts because they cached the old Brick reference.
        -- It is provided only for badly corrupted cases.
        brick:Destroy()
        brick = nil
    end

    if brick then
        applyBrickProperties(brick, { keepPosition = Config.PreserveExistingPosition })
        return true, "Repaired existing Brick in place. This preserves Build tool references."
    end

    brick = createBrick(false)
    return true, "Created missing ReplicatedStorage." .. Config.BrickName .. ". Restart/equip Build tool if needed."
end

local function backupBrick()
    if not IS_SERVER then
        return false, "Backup requires server-side execution."
    end
    local brick = getBrick()
    if not brick then return false, "No Brick to back up." end
    local old = ServerStorage:FindFirstChild("BkitBrickBackup")
    if old then old:Destroy() end
    local clone = brick:Clone()
    clone.Name = "BkitBrickBackup"
    clone.Parent = ServerStorage
    return true, "Saved backup to ServerStorage.BkitBrickBackup."
end

local function restoreFromBackup()
    if not IS_SERVER then
        return false, "Restore from backup requires server-side execution."
    end
    local backup = ServerStorage:FindFirstChild("BkitBrickBackup")
    if not backup then return false, "No backup found in ServerStorage." end
    local existing = getBrick()
    if existing and existing:IsA("BasePart") then
        -- Prefer repair existing instance with backup properties instead of destroying it.
        existing.Size = backup.Size
        existing.CFrame = backup.CFrame
        existing.Anchored = backup.Anchored
        existing.Locked = backup.Locked
        existing.CanCollide = backup.CanCollide
        existing.CanQuery = backup.CanQuery
        existing.CanTouch = backup.CanTouch
        existing.CastShadow = backup.CastShadow
        existing.Material = backup.Material
        existing.Color = backup.Color
        existing.TopSurface = backup.TopSurface
        existing.BottomSurface = backup.BottomSurface
        existing.FrontSurface = backup.FrontSurface
        existing.BackSurface = backup.BackSurface
        existing.LeftSurface = backup.LeftSurface
        existing.RightSurface = backup.RightSurface
        existing.Parent = ReplicatedStorage
        return true, "Restored existing Brick in place from backup."
    end
    if existing then existing:Destroy() end
    local clone = backup:Clone()
    clone.Name = Config.BrickName
    clone.Parent = ReplicatedStorage
    return true, "Created Brick from backup."
end

local function isOwnGuiObject(obj)
    if not Config.ExcludeOwnGui then return false end
    local p = obj
    while p do
        if p.Name == "BkitRestoreGuiV5" then return true end
        p = p.Parent
    end
    return false
end

local function isCoreObject(obj)
    if not Config.ExcludeRobloxCore then return false end
    local fn = safeFullName(obj)
    return fn:find("^CoreGui") or fn:find("^Script Context") or fn:find("^RobloxReplicatedStorage")
end

local function shouldSkip(obj)
    return isOwnGuiObject(obj) or isCoreObject(obj)
end

local function lineContainsAny(line, words)
    local low = string.lower(line)
    for _, w in ipairs(words) do
        if low:find(string.lower(w), 1, true) then
            return true
        end
    end
    return false
end

local function getScriptSource(scr)
    local ok, src = pcall(function() return scr.Source end)
    if ok and type(src) == "string" then
        return src
    end
    return nil
end

local function isCloneCandidate(part, template)
    if not part:IsA("BasePart") or not template or not template:IsA("BasePart") then return false end
    if part == template then return false end
    if part.Name ~= Config.BrickName then return false end
    if math.abs(part.Size.X - template.Size.X) > 0.01 then return false end
    if math.abs(part.Size.Y - template.Size.Y) > 0.01 then return false end
    if math.abs(part.Size.Z - template.Size.Z) > 0.01 then return false end
    if part.Material ~= template.Material then return false end
    if (part.Color - template.Color).Magnitude > 0.01 then return false end
    if part.TopSurface ~= template.TopSurface then return false end
    if part.BottomSurface ~= template.BottomSurface then return false end
    return true
end

local function getToolRemoteSummary(tool)
    local parts = {}
    for _, d in ipairs(tool:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") or d:IsA("BindableFunction") then
            parts[#parts + 1] = d.Name .. "<" .. d.ClassName .. ">"
        end
    end
    if #parts == 0 then return "none found" end
    return table.concat(parts, ", ")
end

local function scanDependencies()
    local template = getBrick()
    local lines = {}
    local max = math.max(10, tonumber(Config.MaxResults) or 80)
    local counts = {
        instances = 0,
        baseparts = 0,
        nameMatches = 0,
        cloneCandidates = 0,
        objectRefs = 0,
        textRefs = 0,
        remotes = 0,
        tools = 0,
        readableScripts = 0,
        unreadableScripts = 0,
        scriptRefs = 0,
        skipped = 0,
        errors = 0,
    }
    local buckets = {
        clones = {},
        names = {},
        objectRefs = {},
        textRefs = {},
        remotes = {},
        tools = {},
        scripts = {},
        locked = {},
    }

    local searchWords
    if Config.StrictSearch then
        searchWords = { 'ReplicatedStorage.Brick', 'WaitForChild("Brick")', "WaitForChild('Brick')", 'FindFirstChild("Brick")', "FindFirstChild('Brick')", ':Clone()' }
    else
        searchWords = { "Brick", "Build", "Delete", "Paint", "Shape", "Shovel", "Sign" }
    end

    local all = game:GetDescendants()
    for _, obj in ipairs(all) do
        counts.instances += 1
        if shouldSkip(obj) then
            counts.skipped += 1
            continue
        end

        if obj:IsA("BasePart") then
            counts.baseparts += 1
            if obj.Name == Config.BrickName and obj ~= template then
                counts.nameMatches += 1
                if Config.IncludeNameMatches and #buckets.names < max then
                    buckets.names[#buckets.names + 1] = "NAME MATCH: " .. safeFullName(obj) .. " | Pos " .. fmtVectorShort(obj.Position)
                end
            end
            if template and isCloneCandidate(obj, template) then
                counts.cloneCandidates += 1
                if #buckets.clones < max then
                    buckets.clones[#buckets.clones + 1] = "CLONE CANDIDATE: " .. safeFullName(obj) .. " | Pos " .. fmtVectorShort(obj.Position)
                end
            end
        end

        if obj:IsA("ObjectValue") then
            local ok, val = pcall(function() return obj.Value end)
            if ok and val == template then
                counts.objectRefs += 1
                if #buckets.objectRefs < max then
                    buckets.objectRefs[#buckets.objectRefs + 1] = "OBJECTVALUE REF: " .. safeFullName(obj)
                end
            end
        end

        if obj:IsA("StringValue") then
            local ok, val = pcall(function() return obj.Value end)
            if ok and type(val) == "string" and lineContainsAny(val, searchWords) then
                counts.textRefs += 1
                if #buckets.textRefs < max then
                    buckets.textRefs[#buckets.textRefs + 1] = "STRING REF: " .. safeFullName(obj) .. " = " .. val:sub(1, 160)
                end
            end
        elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            local ok, txt = pcall(function() return obj.Text end)
            if ok and type(txt) == "string" and not isOwnGuiObject(obj) and lineContainsAny(txt, searchWords) then
                counts.textRefs += 1
                if #buckets.textRefs < max then
                    buckets.textRefs[#buckets.textRefs + 1] = "TEXT REF: " .. safeFullName(obj) .. " = " .. txt:sub(1, 160)
                end
            end
        end

        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") or obj:IsA("BindableFunction") then
            local fn = safeFullName(obj)
            local low = string.lower(fn)
            if low:find("build", 1, true) or low:find("delete", 1, true) or low:find("paint", 1, true) or low:find("shape", 1, true) or low:find("shovel", 1, true) or low:find("sign", 1, true) or obj.Name == "Event" then
                counts.remotes += 1
                if #buckets.remotes < max then
                    buckets.remotes[#buckets.remotes + 1] = "REMOTE/BINDABLE: " .. fn .. " <" .. obj.ClassName .. ">"
                end
            end
        end

        if obj:IsA("Tool") then
            local lname = string.lower(obj.Name)
            if lname:find("build", 1, true) or lname:find("delete", 1, true) or lname:find("paint", 1, true) or lname:find("shape", 1, true) or lname:find("shovel", 1, true) or lname:find("sign", 1, true) then
                counts.tools += 1
                if #buckets.tools < max then
                    buckets.tools[#buckets.tools + 1] = "TOOL: " .. safeFullName(obj) .. " | remotes/bindables: " .. getToolRemoteSummary(obj)
                end
            end
        end

        if obj:IsA("LuaSourceContainer") then
            local src = getScriptSource(obj)
            if src then
                counts.readableScripts += 1
                if lineContainsAny(src, searchWords) then
                    counts.scriptRefs += 1
                    if #buckets.scripts < max then
                        local entry = "SCRIPT REF: " .. safeFullName(obj) .. " <" .. obj.ClassName .. ">"
                        if Config.IncludeSnippets then
                            local found = {}
                            local lineNo = 0
                            for line in src:gmatch("[^\r\n]+") do
                                lineNo += 1
                                if lineContainsAny(line, searchWords) then
                                    found[#found + 1] = "  L" .. lineNo .. ": " .. line:sub(1, 180)
                                    if #found >= 6 then break end
                                end
                            end
                            entry = entry .. "\n" .. table.concat(found, "\n")
                        end
                        buckets.scripts[#buckets.scripts + 1] = entry
                    end
                end
            else
                counts.unreadableScripts += 1
                if #buckets.locked < max and not shouldSkip(obj) then
                    buckets.locked[#buckets.locked + 1] = "LOCKED SCRIPT: " .. safeFullName(obj) .. " <" .. obj.ClassName .. ">"
                end
            end
        end
    end

    lines[#lines + 1] = "=== BKIT DEPENDENCY SCAN " .. VERSION .. " ==="
    lines[#lines + 1] = "Generated: " .. nowString()
    lines[#lines + 1] = "Mode: " .. (IS_SERVER and "Server" or "Client/local")
    lines[#lines + 1] = "Target: ReplicatedStorage." .. Config.BrickName
    lines[#lines + 1] = "Target status: " .. describeStatus()
    lines[#lines + 1] = "Strict search: " .. tostring(Config.StrictSearch)
    lines[#lines + 1] = "Max results per section: " .. tostring(max)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "--- Summary ---"
    lines[#lines + 1] = "Instances searched: " .. counts.instances
    lines[#lines + 1] = "Skipped GUI/Core objects: " .. counts.skipped
    lines[#lines + 1] = "BaseParts searched: " .. counts.baseparts
    lines[#lines + 1] = "Name-only matches: " .. counts.nameMatches
    lines[#lines + 1] = "Clone candidates: " .. counts.cloneCandidates
    lines[#lines + 1] = "ObjectValue exact references: " .. counts.objectRefs
    lines[#lines + 1] = "Text/String references: " .. counts.textRefs
    lines[#lines + 1] = "Remote/Bindable candidates: " .. counts.remotes
    lines[#lines + 1] = "Bkit/build tool candidates: " .. counts.tools
    lines[#lines + 1] = "Readable scripts: " .. counts.readableScripts
    lines[#lines + 1] = "Unreadable scripts: " .. counts.unreadableScripts
    lines[#lines + 1] = "Script references found: " .. counts.scriptRefs
    lines[#lines + 1] = ""

    local function addSection(title, list, empty)
        lines[#lines + 1] = "--- " .. title .. " ---"
        if #list == 0 then
            lines[#lines + 1] = empty or "None found."
        else
            for _, item in ipairs(list) do lines[#lines + 1] = item end
            if #list >= max then lines[#lines + 1] = "... trimmed to max results." end
        end
        lines[#lines + 1] = ""
    end

    addSection("Clone Candidates", buckets.clones, "No clone candidates found.")
    if Config.IncludeNameMatches then addSection("Name Matches", buckets.names, "No name matches found.") end
    addSection("Exact Object References", buckets.objectRefs, "No ObjectValue references to the template found.")
    addSection("Text/String References", buckets.textRefs, "No text/string references found.")
    addSection("Remote / Bindable Candidates", buckets.remotes, "No remote/bindable candidates found.")
    addSection("Tool Candidates", buckets.tools, "No build-tool candidates found.")
    addSection("Readable Script References", buckets.scripts, "No readable script references found.")
    addSection("Locked / Unreadable Scripts", buckets.locked, "No locked scripts found or they were excluded.")

    lines[#lines + 1] = "--- Notes ---"
    lines[#lines + 1] = "The Build LocalScript uses ReplicatedStorage.Brick as a moving preview object, so position is dynamic."
    lines[#lines + 1] = "If this runs client-side, it can repair your local preview but cannot restore the server template."
    lines[#lines + 1] = "If Build still does not place blocks after local repair, the server template is missing and needs server-side restore."
    return table.concat(lines, "\n")
end

local function integrityReport()
    local brick = getBrick()
    local lines = {}
    local checks = {}

    local function add(name, current, expected, ok)
        checks[#checks + 1] = { name = name, current = tostring(current), expected = tostring(expected), ok = ok }
    end

    lines[#lines + 1] = "=== BKIT INTEGRITY CHECK " .. VERSION .. " ==="
    lines[#lines + 1] = "Generated: " .. nowString()
    lines[#lines + 1] = "Mode: " .. (IS_SERVER and "Server" or "Client/local")
    lines[#lines + 1] = "Target: ReplicatedStorage." .. Config.BrickName
    lines[#lines + 1] = "Status: " .. describeStatus()
    lines[#lines + 1] = "Ignore dynamic position: " .. tostring(Config.IgnorePositionIntegrity)
    lines[#lines + 1] = ""

    if not brick then
        lines[#lines + 1] = "Integrity: 0%"
        lines[#lines + 1] = "FAIL: Brick is missing."
        return table.concat(lines, "\n")
    end
    if not brick:IsA("BasePart") then
        lines[#lines + 1] = "Integrity: 0%"
        lines[#lines + 1] = "FAIL: Object exists but is not a BasePart. Class: " .. brick.ClassName
        return table.concat(lines, "\n")
    end

    add("ClassName", brick.ClassName, "Part", brick.ClassName == "Part")
    add("Parent", brick.Parent and brick.Parent.Name or "nil", "ReplicatedStorage", brick.Parent == ReplicatedStorage)
    add("Name", brick.Name, Config.BrickName, brick.Name == Config.BrickName)
    add("Size", fmtVector(brick.Size), fmtVector(Config.SizeNormal) .. " or " .. fmtVector(Config.SizeSmall), (brick.Size - Config.SizeNormal).Magnitude < 0.01 or (brick.Size - Config.SizeSmall).Magnitude < 0.01)
    if not Config.IgnorePositionIntegrity then
        add("Position", fmtVector(brick.Position), fmtVector(Config.DefaultPosition), (brick.Position - Config.DefaultPosition).Magnitude < 0.01)
    else
        add("Position", fmtVector(brick.Position), "ignored; Build tool moves it for preview", true)
    end
    add("Anchored", brick.Anchored, Config.Anchored, brick.Anchored == Config.Anchored)
    add("Locked", brick.Locked, Config.Locked, brick.Locked == Config.Locked)
    add("Massless", brick.Massless, Config.Massless, brick.Massless == Config.Massless)
    add("CanCollide", brick.CanCollide, Config.CanCollide, brick.CanCollide == Config.CanCollide)
    add("CanQuery", brick.CanQuery, Config.CanQuery, brick.CanQuery == Config.CanQuery)
    add("CanTouch", brick.CanTouch, Config.CanTouch, brick.CanTouch == Config.CanTouch)
    add("CastShadow", brick.CastShadow, Config.CastShadow, brick.CastShadow == Config.CastShadow)
    add("Material", tostring(brick.Material), tostring(Config.Material), brick.Material == Config.Material)
    add("Color", fmtColor(brick.Color), fmtColor(Config.Color), (brick.Color - Config.Color).Magnitude < 0.01)
    add("Transparency", brick.Transparency, Config.Transparency, math.abs(brick.Transparency - Config.Transparency) < 0.001)
    add("Reflectance", brick.Reflectance, Config.Reflectance, math.abs(brick.Reflectance - Config.Reflectance) < 0.001)
    add("TopSurface", tostring(brick.TopSurface), tostring(Config.TopSurface), brick.TopSurface == Config.TopSurface)
    add("BottomSurface", tostring(brick.BottomSurface), tostring(Config.BottomSurface), brick.BottomSurface == Config.BottomSurface)
    add("FrontSurface", tostring(brick.FrontSurface), tostring(Config.FrontSurface), brick.FrontSurface == Config.FrontSurface)
    add("BackSurface", tostring(brick.BackSurface), tostring(Config.BackSurface), brick.BackSurface == Config.BackSurface)
    add("LeftSurface", tostring(brick.LeftSurface), tostring(Config.LeftSurface), brick.LeftSurface == Config.LeftSurface)
    add("RightSurface", tostring(brick.RightSurface), tostring(Config.RightSurface), brick.RightSurface == Config.RightSurface)

    local pass = 0
    for _, c in ipairs(checks) do if c.ok then pass += 1 end end
    local pct = math.floor((pass / #checks) * 100 + 0.5)
    lines[#lines + 1] = "Integrity: " .. pct .. "%"
    lines[#lines + 1] = "Passed: " .. pass .. "/" .. #checks
    lines[#lines + 1] = ""
    for _, c in ipairs(checks) do
        lines[#lines + 1] = (c.ok and "OK   " or "FAIL ") .. c.name .. " | current: " .. c.current .. " | expected: " .. c.expected
    end
    return table.concat(lines, "\n")
end

local function brickInfo()
    local brick = getBrick()
    local lines = {}
    lines[#lines + 1] = "=== BKIT BRICK INFO " .. VERSION .. " ==="
    lines[#lines + 1] = "Generated: " .. nowString()
    lines[#lines + 1] = "Mode: " .. (IS_SERVER and "Server" or "Client/local")
    lines[#lines + 1] = "PlaceId: " .. tostring(game.PlaceId)
    lines[#lines + 1] = "JobId: " .. tostring(game.JobId)
    lines[#lines + 1] = "Target: ReplicatedStorage." .. Config.BrickName
    lines[#lines + 1] = "Status: " .. describeStatus()
    lines[#lines + 1] = ""

    if not brick then
        lines[#lines + 1] = "No brick found."
        return table.concat(lines, "\n")
    end

    lines[#lines + 1] = "Path: " .. safeFullName(brick)
    lines[#lines + 1] = "Class: " .. brick.ClassName
    lines[#lines + 1] = ""
    if brick:IsA("BasePart") then
        lines[#lines + 1] = "--- Properties ---"
        local props = {
            {"Name", brick.Name},
            {"ClassName", brick.ClassName},
            {"Archivable", brick.Archivable},
            {"Parent", brick.Parent and brick.Parent.Name or "nil"},
            {"Size", fmtVector(brick.Size)},
            {"Position", fmtVector(brick.Position)},
            {"Orientation", fmtVector(brick.Orientation)},
            {"PivotOffset", "Position " .. fmtVector(brick.PivotOffset.Position)},
            {"Anchored", brick.Anchored},
            {"Locked", brick.Locked},
            {"Massless", brick.Massless},
            {"CanCollide", brick.CanCollide},
            {"CanQuery", brick.CanQuery},
            {"CanTouch", brick.CanTouch},
            {"CollisionGroup", brick.CollisionGroup},
            {"Material", tostring(brick.Material)},
            {"MaterialVariant", tostring(brick.MaterialVariant)},
            {"Color", fmtColor(brick.Color)},
            {"BrickColor", tostring(brick.BrickColor)},
            {"Transparency", brick.Transparency},
            {"Reflectance", brick.Reflectance},
            {"CastShadow", brick.CastShadow},
            {"TopSurface", tostring(brick.TopSurface)},
            {"BottomSurface", tostring(brick.BottomSurface)},
            {"FrontSurface", tostring(brick.FrontSurface)},
            {"BackSurface", tostring(brick.BackSurface)},
            {"LeftSurface", tostring(brick.LeftSurface)},
            {"RightSurface", tostring(brick.RightSurface)},
            {"AssemblyMass", brick.AssemblyMass},
            {"AssemblyCenterOfMass", fmtVector(brick.AssemblyCenterOfMass)},
            {"AssemblyLinearVelocity", fmtVector(brick.AssemblyLinearVelocity)},
            {"AssemblyAngularVelocity", fmtVector(brick.AssemblyAngularVelocity)},
        }
        for _, p in ipairs(props) do
            lines[#lines + 1] = p[1] .. " = " .. tostring(p[2])
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "--- Attributes ---"
    local attrs = brick:GetAttributes()
    local anyAttr = false
    for k, v in pairs(attrs) do
        anyAttr = true
        lines[#lines + 1] = tostring(k) .. " = " .. tostring(v)
    end
    if not anyAttr then lines[#lines + 1] = "No attributes." end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "--- Tags ---"
    local okTags, tags = pcall(function() return CollectionService:GetTags(brick) end)
    if okTags and #tags > 0 then
        for _, t in ipairs(tags) do lines[#lines + 1] = t end
    else
        lines[#lines + 1] = "No tags or tags not readable."
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "--- Children ---"
    local children = brick:GetChildren()
    if #children == 0 then
        lines[#lines + 1] = "No children."
    else
        for _, c in ipairs(children) do lines[#lines + 1] = c.Name .. " <" .. c.ClassName .. ">" end
    end
    return table.concat(lines, "\n")
end

local function recreateScript()
    return [[-- Generated by Bkit Restore Panel v5
-- Run server-side in ServerScriptService or Studio Command Bar.
-- This repairs the existing Brick in place when possible so Build LocalScripts keep their reference.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local brick = ReplicatedStorage:FindFirstChild("Brick")
if brick and not brick:IsA("BasePart") then
    brick:Destroy()
    brick = nil
end
if not brick then
    brick = Instance.new("Part")
    brick.Name = "Brick"
    brick.Parent = ReplicatedStorage
end
brick.Name = "Brick"
brick.Size = Vector3.new(4, 4, 4)
-- Position is dynamic; the Build tool moves this part for preview.
-- Use this fallback only when creating a missing brick.
if brick.Position.Magnitude == 0 then
    brick.CFrame = CFrame.new(-90, 22, -74)
end
brick.Anchored = true
brick.Locked = true
brick.Archivable = true
brick.CanCollide = true
brick.CanQuery = true
brick.CanTouch = true
brick.CastShadow = true
brick.Massless = false
brick.Material = Enum.Material.Plastic
brick.Color = Color3.fromRGB(192, 192, 192)
brick.BrickColor = BrickColor.new("Light grey")
brick.Transparency = 0
brick.Reflectance = 0
pcall(function() brick.CollisionGroup = "Default" end)
brick.TopSurface = Enum.SurfaceType.Studs
brick.BottomSurface = Enum.SurfaceType.Inlet
brick.FrontSurface = Enum.SurfaceType.Smooth
brick.BackSurface = Enum.SurfaceType.Smooth
brick.LeftSurface = Enum.SurfaceType.Smooth
brick.RightSurface = Enum.SurfaceType.Smooth
print("[Bkit Restore] Server Brick repaired/created at " .. brick:GetFullName())]]
end

local function fullReport()
    return table.concat({ brickInfo(), "", integrityReport(), "", scanDependencies(), "", "=== RECREATE SCRIPT ===", recreateScript() }, "\n")
end

local autoThreadRunning = false
local function setAutoWatch(enabled, outputFn)
    Config.AutoWatch = enabled
    if enabled and not autoThreadRunning then
        autoThreadRunning = true
        task.spawn(function()
            while Config.AutoWatch do
                local brick = getBrick()
                if not isBrickOk(brick) then
                    local ok, msg = repairOrCreateBrick(false)
                    if outputFn then outputFn("Auto-watch: " .. msg) end
                end
                task.wait(math.max(0.25, tonumber(Config.AutoWatchDelay) or 1))
            end
            autoThreadRunning = false
        end)
    end
end

local function restartLocalToolScripts()
    if IS_SERVER or not LocalPlayer then
        return false, "Restart Tool Scripts is client-only."
    end
    local containers = {}
    if LocalPlayer:FindFirstChild("Backpack") then containers[#containers + 1] = LocalPlayer.Backpack end
    if LocalPlayer.Character then containers[#containers + 1] = LocalPlayer.Character end

    local restarted = 0
    local names = {}
    for _, container in ipairs(containers) do
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local lname = string.lower(tool.Name)
                if lname:find("build", 1, true) or lname:find("delete", 1, true) or lname:find("paint", 1, true) or lname:find("shape", 1, true) or lname:find("shovel", 1, true) or lname:find("sign", 1, true) then
                    for _, d in ipairs(tool:GetDescendants()) do
                        if d:IsA("LocalScript") then
                            local ok = pcall(function()
                                d.Disabled = true
                                task.wait()
                                d.Disabled = false
                            end)
                            if ok then
                                restarted += 1
                                names[#names + 1] = tool.Name .. "/" .. d.Name
                            end
                        end
                    end
                end
            end
        end
    end
    if restarted == 0 then
        return false, "No local Bkit tool scripts restarted. Try unequipping/re-equipping or rejoining after restore."
    end
    return true, "Restarted " .. restarted .. " LocalScript(s): " .. table.concat(names, ", ")
end

local function copyText(text)
    local copied = false
    local methods = {
        function() return setclipboard(text) end,
        function() return toclipboard(text) end,
        function() return set_clipboard(text) end,
        function() return Clipboard and Clipboard.set and Clipboard.set(text) end,
    }
    for _, fn in ipairs(methods) do
        local ok = pcall(fn)
        if ok then copied = true break end
    end
    return copied
end

local function runServerMode()
    print("[Bkit Restore " .. VERSION .. "] Server mode loaded.")
    local ok, msg = repairOrCreateBrick(false)
    print("[Bkit Restore " .. VERSION .. "] " .. msg)
    setAutoWatch(true, function(m) print("[Bkit Restore " .. VERSION .. "] " .. m) end)
end

if IS_SERVER then
    runServerMode()
    return
end

-- CLIENT GUI
local function makeGui()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local old = playerGui:FindFirstChild("BkitRestoreGuiV5")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "BkitRestoreGuiV5"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "Frame"
    frame.Size = UDim2.new(0, 620, 0, 430)
    frame.Position = UDim2.new(0.5, -310, 0.5, -215)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    frame.BorderColor3 = Color3.fromRGB(0, 125, 255)
    frame.Active = true
    frame.Parent = gui

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 34)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Bkit Restore + Diagnostics " .. VERSION
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.Code
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 32, 0, 26)
    minBtn.Position = UDim2.new(1, -70, 0, 4)
    minBtn.Text = "_"
    minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    minBtn.Font = Enum.Font.Code
    minBtn.TextSize = 14
    minBtn.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 32, 0, 26)
    closeBtn.Position = UDim2.new(1, -36, 0, 4)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.BackgroundColor3 = Color3.fromRGB(100, 35, 35)
    closeBtn.Font = Enum.Font.Code
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -16, 0, 170)
    content.Position = UDim2.new(0, 8, 0, 42)
    content.BackgroundTransparency = 1
    content.Parent = frame

    local function makeLabel(text, x, y)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0, 78, 0, 24)
        l.Position = UDim2.new(0, x, 0, y)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = Color3.fromRGB(230, 230, 230)
        l.Font = Enum.Font.Code
        l.TextSize = 13
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = content
        return l
    end

    local function makeBox(label, text, x, y, w)
        makeLabel(label, x, y)
        local b = Instance.new("TextBox")
        b.Size = UDim2.new(0, w, 0, 24)
        b.Position = UDim2.new(0, x + 82, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        b.BorderColor3 = Color3.fromRGB(70, 70, 70)
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.Code
        b.TextSize = 13
        b.Text = text
        b.ClearTextOnFocus = false
        b.Parent = content
        return b
    end

    local nameBox = makeBox("Name", Config.BrickName, 0, 0, 165)
    local posBox = makeBox("Fallback Pos", fmtVectorShort(Config.DefaultPosition), 0, 30, 165)
    local sizeBox = makeBox("Normal Size", fmtVectorShort(Config.SizeNormal), 0, 60, 165)
    local smallBox = makeBox("Small Size", fmtVectorShort(Config.SizeSmall), 0, 90, 165)
    local delayBox = makeBox("Watch Delay", tostring(Config.AutoWatchDelay), 0, 120, 165)
    local maxBox = makeBox("Max Results", tostring(Config.MaxResults), 0, 150, 165)

    local buttonArea = Instance.new("Frame")
    buttonArea.Size = UDim2.new(0, 335, 0, 160)
    buttonArea.Position = UDim2.new(0, 270, 0, 0)
    buttonArea.BackgroundTransparency = 1
    buttonArea.Parent = content

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, 105, 0, 26)
    grid.CellPadding = UDim2.new(0, 6, 0, 6)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = buttonArea

    local output = Instance.new("TextBox")
    output.Name = "Output"
    output.Size = UDim2.new(1, -16, 1, -224)
    output.Position = UDim2.new(0, 8, 0, 218)
    output.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
    output.BorderColor3 = Color3.fromRGB(70, 70, 70)
    output.TextColor3 = Color3.fromRGB(235, 235, 235)
    output.Font = Enum.Font.Code
    output.TextSize = 12
    output.TextXAlignment = Enum.TextXAlignment.Left
    output.TextYAlignment = Enum.TextYAlignment.Top
    output.TextWrapped = false
    output.MultiLine = true
    output.ClearTextOnFocus = false
    output.TextEditable = true
    output.Text = "Ready. Click Repair Local, then Restart Tools.\nServer restore must run server-side to make building work for everyone."
    output.Parent = frame

    local minimized = false
    local originalSize = frame.Size
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        content.Visible = not minimized
        output.Visible = not minimized
        frame.Size = minimized and UDim2.new(0, 620, 0, 34) or originalSize
        minBtn.Text = minimized and "+" or "_"
    end)

    -- Manual drag so it works in modern Roblox.
    local dragging = false
    local dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local function setOut(text, doCopy)
        output.Text = tostring(text)
        output.CursorPosition = 1
        if doCopy then
            local ok = copyText(output.Text)
            if ok then
                output.Text = "Copied to clipboard.\n\n" .. output.Text
            else
                output.Text = "Clipboard function not available. Select/copy manually below.\n\n" .. output.Text
            end
        end
    end

    local function applyGuiConfig()
        Config.BrickName = nameBox.Text ~= "" and nameBox.Text or "Brick"
        Config.DefaultPosition = vectorFromText(posBox.Text, Config.DefaultPosition)
        Config.SizeNormal = vectorFromText(sizeBox.Text, Config.SizeNormal)
        Config.SizeSmall = vectorFromText(smallBox.Text, Config.SizeSmall)
        Config.AutoWatchDelay = numberFromText(delayBox.Text, Config.AutoWatchDelay, 0.25, 60)
        Config.MaxResults = math.floor(numberFromText(maxBox.Text, Config.MaxResults, 5, 500))
    end

    local function makeButton(text, fn)
        local b = Instance.new("TextButton")
        b.Text = text
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        b.BorderColor3 = Color3.fromRGB(80, 80, 80)
        b.Font = Enum.Font.Code
        b.TextSize = 12
        b.Parent = buttonArea
        b.MouseButton1Click:Connect(function()
            local ok, err = pcall(function()
                applyGuiConfig()
                fn(b)
            end)
            if not ok then setOut("Button error: " .. tostring(err)) end
        end)
        return b
    end

    makeButton("Check", function() setOut(describeStatus()) end)
    makeButton("Integrity", function() setOut(integrityReport()) end)
    makeButton("Repair Local", function()
        local ok, msg = repairOrCreateBrick(false)
        setOut(msg .. "\n\n" .. describeStatus() .. "\n\nNext: click Restart Tools. If building still fails, server restore is required.")
    end)
    makeButton("Force Local", function()
        local ok, msg = repairOrCreateBrick(true)
        setOut(msg .. "\n\nWarning: force recreate may require Restart Tools / rejoin because old LocalScripts may cache the old Brick.")
    end)
    makeButton("Restart Tools", function()
        local ok, msg = restartLocalToolScripts()
        setOut(msg .. "\n\nAfter this, equip Build and try again.")
    end)
    makeButton("Copy Info", function() setOut(brickInfo(), true) end)
    makeButton("Scan Deps", function() setOut(scanDependencies(), true) end)
    makeButton("Copy Report", function() setOut(fullReport(), true) end)
    makeButton("Copy Server", function() setOut(recreateScript(), true) end)

    local autoBtn
    autoBtn = makeButton("Auto: OFF", function(btn)
        setAutoWatch(not Config.AutoWatch, function(m) setOut(m .. "\n\n" .. describeStatus()) end)
        btn.Text = "Auto: " .. fmtBool(Config.AutoWatch)
        setOut("Auto-watch " .. (Config.AutoWatch and "enabled" or "disabled") .. ".")
    end)

    local ignoreBtn
    ignoreBtn = makeButton("Ignore Pos: ON", function(btn)
        Config.IgnorePositionIntegrity = not Config.IgnorePositionIntegrity
        btn.Text = "Ignore Pos: " .. fmtBool(Config.IgnorePositionIntegrity)
        setOut("Ignore dynamic position in integrity = " .. tostring(Config.IgnorePositionIntegrity))
    end)

    makeButton("Load Current", function()
        local brick = getBrick()
        if brick and brick:IsA("BasePart") then
            nameBox.Text = brick.Name
            posBox.Text = fmtVectorShort(brick.Position)
            sizeBox.Text = fmtVectorShort(brick.Size)
            Config.DefaultPosition = brick.Position
            Config.SizeNormal = brick.Size
            setOut("Loaded current Brick values into GUI.\nNote: position is dynamic preview data, not usually a restore requirement.")
        else
            setOut("No BasePart Brick found to load.")
        end
    end)
    makeButton("Backup", function() local ok, msg = backupBrick(); setOut(msg) end)
    makeButton("From Backup", function() local ok, msg = restoreFromBackup(); setOut(msg) end)
    makeButton("Clear", function() output.Text = "" end)
    makeButton("Copy Output", function() setOut(output.Text, true) end)

    setOut(describeStatus() .. "\n\nTip: Click Repair Local, then Restart Tools. For real server repair, paste Copy Server code into ServerScriptService/Studio Command Bar.")
end

makeGui()
