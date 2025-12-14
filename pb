-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Local player
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BaitGiverUI"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false

-- Main Frame (more compact)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 140)  -- Reduced height
mainFrame.Position = UDim2.new(0.5, -150, 0, 20)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.BackgroundTransparency = 0.1
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "🎣 Bait Giver"
title.Font = Enum.Font.SourceSansBold
title.TextSize = 24
title.Parent = mainFrame

-- Available Label (now higher up)
local availableLabel = Instance.new("TextLabel")
availableLabel.Size = UDim2.new(1, -10, 0, 26)
availableLabel.Position = UDim2.new(0, 5, 0, 34)
availableLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
availableLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
availableLabel.Text = "Available Bait: 0 (Stacks: 0)"
availableLabel.Font = Enum.Font.SourceSans
availableLabel.TextSize = 16
availableLabel.TextXAlignment = Enum.TextXAlignment.Center
availableLabel.Parent = mainFrame

local availableCorner = Instance.new("UICorner")
availableCorner.CornerRadius = UDim.new(0, 8)
availableCorner.Parent = availableLabel

-- Players Dropdown Frame
local playersDropdownFrame = Instance.new("Frame")
playersDropdownFrame.Size = UDim2.new(1, -10, 0, 50)
playersDropdownFrame.Position = UDim2.new(0, 5, 0, 66)
playersDropdownFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
playersDropdownFrame.BackgroundTransparency = 0.1
playersDropdownFrame.Parent = mainFrame

local playersCorner = Instance.new("UICorner")
playersCorner.CornerRadius = UDim.new(0, 8)
playersCorner.Parent = playersDropdownFrame

local playersTitle = Instance.new("TextLabel")
playersTitle.Size = UDim2.new(1, 0, 0, 20)
playersTitle.BackgroundTransparency = 1
playersTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
playersTitle.Text = "Target Player"
playersTitle.Font = Enum.Font.SourceSansBold
playersTitle.TextSize = 16
playersTitle.TextXAlignment = Enum.TextXAlignment.Left
playersTitle.PaddingLeft = UDim.new(0, 8)
playersTitle.Parent = playersDropdownFrame

local playersButton = Instance.new("TextButton")
playersButton.Size = UDim2.new(1, 0, 0, 30)
playersButton.Position = UDim2.new(0, 0, 0, 20)
playersButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
playersButton.TextColor3 = Color3.fromRGB(255, 255, 255)
playersButton.Text = "Choose Player"
playersButton.Font = Enum.Font.SourceSans
playersButton.TextSize = 16
playersButton.Parent = playersDropdownFrame

local playersButtonCorner = Instance.new("UICorner")
playersButtonCorner.CornerRadius = UDim.new(0, 8)
playersButtonCorner.Parent = playersButton

local playersListFrame = Instance.new("ScrollingFrame")
playersListFrame.Size = UDim2.new(1, 0, 0, 150)
playersListFrame.Position = UDim2.new(0, 0, 1, 4)
playersListFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
playersListFrame.BorderSizePixel = 0
playersListFrame.Visible = false
playersListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
playersListFrame.ScrollBarThickness = 6
playersListFrame.Parent = playersDropdownFrame

local playersListCorner = Instance.new("UICorner")
playersListCorner.CornerRadius = UDim.new(0, 8)
playersListCorner.Parent = playersListFrame

-- Give All Toggle Button (bottom)
local giveAllButton = Instance.new("TextButton")
giveAllButton.Size = UDim2.new(1, -10, 0, 36)
giveAllButton.Position = UDim2.new(0, 5, 1, -41)
giveAllButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
giveAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
giveAllButton.Text = "Give All winter_2025_yarn_beanie_bait [OFF]"
giveAllButton.Font = Enum.Font.SourceSansBold
giveAllButton.TextSize = 17
giveAllButton.Parent = mainFrame

local giveAllCorner = Instance.new("UICorner")
giveAllCorner.CornerRadius = UDim.new(0, 8)
giveAllCorner.Parent = giveAllButton

-- Variables
local selectedPlayer = nil
local baitType = "winter_2025_yarn_beanie_bait"
local baitInventory = {} -- {uid = uniqueId, amount = num}
local totalBaitAmount = 0
local giveAllRunning = false

-- Function to update players dropdown
local function updatePlayersDropdown()
    local playersList = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= localPlayer then
            table.insert(playersList, plr.Name)
        end
    end
    table.sort(playersList)
    
    for _, child in ipairs(playersListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    for i, playerName in ipairs(playersList) do
        local optionButton = Instance.new("TextButton")
        optionButton.Size = UDim2.new(1, 0, 0, 28)
        optionButton.Position = UDim2.new(0, 0, 0, (i-1)*28)
        optionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        optionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        optionButton.Text = playerName
        optionButton.Font = Enum.Font.SourceSans
        optionButton.TextSize = 16
        optionButton.Parent = playersListFrame
        
        optionButton.MouseButton1Click:Connect(function()
            playersButton.Text = playerName
            selectedPlayer = Players:FindFirstChild(playerName)
            playersListFrame.Visible = false
        end)
    end
    playersListFrame.CanvasSize = UDim2.new(0, 0, 0, #playersList * 28)
end

-- Function to update bait inventory
local function updateBaitInventory()
    baitInventory = {}
    totalBaitAmount = 0
    local success, clientData = pcall(require, ReplicatedStorage.ClientModules.Core.ClientData)
    if success then
        local success2, allData = pcall(clientData.get_data, clientData)
        if success2 and allData[localPlayer.Name] and allData[localPlayer.Name].inventory and allData[localPlayer.Name].inventory.food then
            for uniqueId, foodData in pairs(allData[localPlayer.Name].inventory.food) do
                if foodData.id == baitType then
                    local amount = foodData.amount or 1
                    table.insert(baitInventory, {uid = uniqueId, amount = amount})
                    totalBaitAmount = totalBaitAmount + amount
                end
            end
        end
    end
    availableLabel.Text = "Available Bait: " .. totalBaitAmount .. " (Stacks: " .. #baitInventory .. ")"
end

-- Toggle players dropdown
local playersToggle = false
playersButton.MouseButton1Click:Connect(function()
    playersToggle = not playersToggle
    playersListFrame.Visible = playersToggle
    if playersToggle then
        updatePlayersDropdown()
    end)
end

-- Function to give all stacks to player
local function giveAllStacksToPlayer(targetPlayer)
    if #baitInventory == 0 then
        print("No " .. baitType .. " to give.")
        return
    end
    
    print("Giving all " .. totalBaitAmount .. " " .. baitType .. " to " .. targetPlayer.Name)
    
    for i = #baitInventory, 1, -1 do
        local stack = baitInventory[i]
        local args = {targetPlayer, stack.uid}
        local success, result = pcall(function()
            return ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/GiveItem"):InvokeServer(unpack(args))
        end)
        
        if success then
            table.remove(baitInventory, i)
            updateBaitInventory()
            print("Gave stack (" .. stack.amount .. ") to " .. targetPlayer.Name)
        else
            print("Failed to give stack: " .. tostring(result))
        end
        
        task.wait(9)
    end
end

-- Continuous give all loop
local function startGiveAll()
    while giveAllRunning do
        if selectedPlayer and #baitInventory > 0 then
            giveAllStacksToPlayer(selectedPlayer)
        end
        task.wait(12)
    end
end

-- Give All Toggle
giveAllButton.MouseButton1Click:Connect(function()
    if not selectedPlayer then
        print("Please select a player first!")
        return
    end
    
    giveAllRunning = not giveAllRunning
    if giveAllRunning then
        giveAllButton.Text = "Give All winter_2025_yarn_beanie_bait [ON]"
        giveAllButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
        spawn(startGiveAll)
    else
        giveAllButton.Text = "Give All winter_2025_yarn_beanie_bait [OFF]"
        giveAllButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    end
end)

-- Initial setup
updatePlayersDropdown()
updateBaitInventory()

-- Auto-refresh
spawn(function()
    while true do
        task.wait(20)
        updateBaitInventory()
        if playersListFrame.Visible then
            updatePlayersDropdown()
        end
    end
end)

print("Compact Bait Giver UI Loaded! (winter_2025_yarn_beanie_bait only)")
