-- Simple Anti-Lag Script for Roblox

-- Disable shadows and reduce rendering quality
game:GetService("Lighting").GlobalShadows = false
settings().Rendering.QualityLevel = 1

-- Optimize terrain water effects
local Terrain = workspace:FindFirstChildWhichIsA("Terrain")
if Terrain then
    Terrain.WaterWaveSize = 0
    Terrain.WaterWaveSpeed = 0
    Terrain.WaterReflectance = 0
    Terrain.WaterTransparency = 1
end

-- Disable fog
local Lighting = game:GetService("Lighting")
Lighting.FogEnd = 9e9
Lighting.FogStart = 9e9

-- Optimize parts: disable shadows and simplify materials
for _, part in ipairs(workspace:GetDescendants()) do
    if part:IsA("BasePart") then
        part.CastShadow = false
        part.Material = "Plastic"
    elseif part:IsA("Decal") then
        part.Transparency = 1
    elseif part:IsA("ParticleEmitter") or part:IsA("Trail") then
        part.Lifetime = NumberRange.new(0)
    end
end

-- Disable post-processing effects
for _, effect in ipairs(Lighting:GetDescendants()) do
    if effect:IsA("PostEffect") then
        effect.Enabled = false
    end
end

-- Automatically destroy lag-inducing objects as they spawn
workspace.DescendantAdded:Connect(function(child)
    if child:IsA("ForceField") or child:IsA("Sparkles") or child:IsA("Smoke") or child:IsA("Fire") then
        task.wait() -- Wait a frame to avoid errors
        child:Destroy()
    elseif child:IsA("BasePart") then
        child.CastShadow = false
    end
end)

print("Anti-lag optimizations applied!")
