-- Wait for the player and their character to load
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Create the ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TeleportUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Create the main frame (Centered and Smaller)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 150, 0, 290) -- Reduced size (Width: 150, Height: 290)
mainFrame.Position = UDim2.new(0.5, -75, 0.5, -145) -- Adjusted offset to stay centered
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Add rounded corners to the main frame
local uicorner = Instance.new("UICorner")
uicorner.CornerRadius = UDim.new(0, 6)
uicorner.Parent = mainFrame

-- Create a Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30) -- Reduced height
title.BackgroundTransparency = 1
title.Text = "Teleport Menu"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 16 -- Smaller text
title.Parent = mainFrame

-- Create a List for the buttons
local listLayout = Instance.new("UIListLayout")
listLayout.Parent = mainFrame
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.Padding = UDim.new(0, 4) -- Tighter padding
listLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Define the 10 locations
local locations = {
    CFrame.new(-286.926758, 27.1907673, -1760.88855, -0.855764151, 0, -0.517366052, 0, 1, 0, 0.517366052, 0, -0.855764151),
    CFrame.new(-600.940552, 27.1901321, -1582.34888, -0.981422424, 0, 0.191859722, 0, 1, 0, -0.191859722, 0, -0.981422424),
    CFrame.new(-904.178955, 200.632584, -1366.41895, -0.86605227, 0, 0.499954134, 0, 1, 0, -0.499954134, 0, -0.86605227),
    CFrame.new(-831.363037, 102.905029, -1146.2345, -0.966490626, 1.07659725e-05, -0.256702363, 0.00101638178, 0.999992311, -0.00378476293, 0.256700337, -0.00391884521, -0.966483235),
    CFrame.new(-509.442261, 27.1762543, -1206.65881, 0.987413526, 0, 0.158159822, 0, 1, 0, -0.158159822, 0, 0.987413526),
    CFrame.new(-384.467163, 27.1762543, -1185.1593, 0.634470701, -0, -0.772947013, 0, 1, -0, 0.772947013, 0, 0.634470701),
    CFrame.new(0.749746919, 27.1735649, -1035.1499, 0.991938055, -8.61478547e-05, -0.126723498, 8.61478547e-05, 1, -5.48057051e-06, 0.126723498, -5.48057051e-06, 0.991938055),
    CFrame.new(-88.4760208, 27.1907673, -1779.06201, -0.855764151, 0, -0.517366052, 0, 1, 0, 0.517366052, 0, -0.855764151),
    CFrame.new(-169.093048, 370.914612, -1301.84375, -0.563898802, 0, 0.82584393, 0, 1, 0, -0.82584393, 0, -0.563898802),
    CFrame.new(-27.425993, 59.2052193, -1734.96375, 0.855764151, 0, 0.517366052, 0, 1, 0, -0.517366052, 0, 0.855764151)
}

-- Function to create a teleport button
local function createButton(index, targetCFrame)
    local button = Instance.new("TextButton")
    button.Name = "TeleportButton" .. index
    button.Size = UDim2.new(0, 130, 0, 22) -- Reduced button size
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.SourceSans
    button.TextSize = 14 -- Smaller text
    button.Text = "Location " .. index
    button.Parent = mainFrame
    
    -- Add rounded corners to buttons
    local btnUicorner = Instance.new("UICorner")
    btnUicorner.CornerRadius = UDim.new(0, 4)
    btnUicorner.Parent = button

    -- Teleport logic on click
    button.MouseButton1Click:Connect(function()
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            character.HumanoidRootPart.CFrame = targetCFrame
        end
    end)
end

-- Generate the 10 buttons
for i, cframeData in ipairs(locations) do
    createButton(i, cframeData)
end
