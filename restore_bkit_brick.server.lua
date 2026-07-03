-- restore_bkit_brick.server.lua
-- Restores the ReplicatedStorage.Brick template used by Bkit building tools IN PROGRESS PROBABLY NOT WORKING

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local existing = ReplicatedStorage:FindFirstChild("Brick")
if existing then
    existing:Destroy()
end

local brick = Instance.new("Part")
brick.Name = "Brick"
brick.Size = Vector3.new(4, 4, 4)
brick.CFrame = CFrame.new(-38, 22, 26)
brick.Anchored = true
brick.Locked = true
brick.Archivable = true
brick.CanCollide = true
brick.CanQuery = true
brick.CanTouch = true
brick.Material = Enum.Material.Plastic
brick.Color = Color3.fromRGB(192, 192, 192)
brick.TopSurface = Enum.SurfaceType.Studs
brick.BottomSurface = Enum.SurfaceType.Inlet
brick.FrontSurface = Enum.SurfaceType.Smooth
brick.BackSurface = Enum.SurfaceType.Smooth
brick.LeftSurface = Enum.SurfaceType.Smooth
brick.RightSurface = Enum.SurfaceType.Smooth
brick.Parent = ReplicatedStorage

print("[Bkit Restore] ReplicatedStorage.Brick restored")
