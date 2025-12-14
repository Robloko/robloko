-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Local player
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BaitGiverUI"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false

-- Main Frame (compact, top center)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 200)
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
title.Size = UDim2.new(1, 0, 0, 24)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "🎣 Bait Giver"
title.Font = Enum.Font.SourceSansBold
title.TextSize = 22
title.Parent = mainFrame

-- Give All Toggle Button
local giveAllButton = Instance.new("TextButton")
giveAllButton.Size = UDim2.new(1, -10, 0, 32)
giveAllButton.Position = UDim2.new(0, 5, 0, 30)
giveAllButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
giveAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
giveAllButton.Text = "Give All winter_2025_yarn_beanie_bait [OFF]"
giveAllButton.Font = Enum.Font.SourceSansBold
giveAllButton.TextSize = 16
giveAllButton.Parent = mainFrame
local giveAllCorner = Instance.new("UICorner")
giveAllCorner.CornerRadius = UDim.new(0, 8)
giveAllCorner.Parent = giveAllButton

-- Players Dropdown Frame
local playersDropdownFrame = Instance.new("Frame")
playersDropdownFrame.Size = UDim2.new(1, -10, 0, 50)
playersDropdownFrame.Position = UDim2.new(0, 5, 0, 68)
playersDropdownFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
playersDropdownFrame.BorderSizePixel = 0
playersDropdownFrame.BackgroundTransparency = 0.1
playersDropdownFrame.Parent = mainFrame
local playersCorner = Instance.new("UICorner")
playersCorner.CornerRadius = UDim.new(0, 8)
playersCorner.Parent = playersDropdownFrame

local playersTitle = Instance.new("TextLabel")
playersTitle.Size = UDim2.new(1, 0, 0, 20)
playersTitle.Position = UDim2.new(0, 0, 0, 0)
playersTitle.BackgroundTransparency = 1
playersTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
playersTitle.Text = "Player"
playersTitle.Font = Enum.Font.SourceSansBold
playersTitle.TextSize = 16
playersTitle.TextXAlignment = Enum.TextXAlignment.Left
playersTitle.Parent = playersDropdownFrame

local playersButton = Instance.new("TextButton")
playersButton.Size = UDim2.new(1, 0, 0, 30)
playersButton.Position = UDim2.new(0, 0, 0, 20)
playersButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
playersButton.TextColor3 = Color3.fromRGB(255, 255, 255)
playersButton.Text = "Choose"
playersButton.Font = Enum.Font.SourceSans
playersButton.TextSize = 16
playersButton.Parent = playersDropdownFrame
local playersButtonCorner = Instance.new("UICorner")
playersButtonCorner.CornerRadius = UDim.new(0, 8)
playersButtonCorner.Parent = playersButton

local playersListFrame = Instance.new("ScrollingFrame")
playersListFrame.Size = UDim2.new(1, 0, 0, 200)
playersListFrame.Position = UDim2.new(0, 0, 1, 0)
playersListFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
playersListFrame.BorderSizePixel = 0
playersListFrame.Visible = false
playersListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
playersListFrame.ScrollBarThickness = 6
playersListFrame.Parent = playersDropdownFrame
local playersListCorner = Instance.new("UICorner")
playersListCorner.CornerRadius = UDim.new(0, 8)
playersListCorner.Parent = playersListFrame

-- Available Label (now full width)
local availableLabel = Instance.new("TextLabel")
availableLabel.Size = UDim2.new(1, -10, 0, 32)
availableLabel.Position = UDim2.new(0, 5, 0, 124)
availableLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
availableLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
availableLabel.Text = "Available Bait: 0 (Stacks: 0)"
availableLabel.Font = Enum.Font.SourceSansBold
availableLabel.TextSize = 16
availableLabel.Parent = mainFrame
local availableCorner = Instance.new("UICorner")
availableCorner.CornerRadius = UDim.new(0, 8)
availableCorner.Parent = availableLabel

-- Variables
local selectedPlayer = nil
local baitType = "winter_2025_yarn_beanie_bait"
local baitInventory = {} -- {uid = uniqueId, amount = num}
local totalBaitAmount = 0
local giveAllRunning = false
local giveAllCoroutine = nil

-- Function to update players dropdown
local function updatePlayersDropdown()
    local playersList = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= localPlayer then
            table.insert(playersList, plr.Name)
        end
    end
    table.sort(playersList)
    -- Clear list
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
            print("Selected player: " .. playerName)
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
    end
end)

-- Function to give N stacks to player
local function giveNStacksToPlayer(targetPlayer, numStacks)
    if #baitInventory < numStacks then
        print("Not enough stacks of " .. baitType .. " for " .. targetPlayer.Name)
        return false
    end
    local stacks = {}
    for i = 1, numStacks do
        table.insert(stacks, table.remove(baitInventory, 1))
    end
    print("Giving " .. numStacks .. " stacks of " .. baitType .. " to " .. targetPlayer.Name)
    for i, stack in ipairs(stacks) do
        local args = {
            targetPlayer,
            stack.uid
        }
        local success, result = pcall(function()
            return ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/GiveItem"):InvokeServer(unpack(args))
        end)
        if success then
            print("Gave stack " .. i .. "/" .. numStacks .. " to " .. targetPlayer.Name .. ": " .. stack.uid .. " (Amount: " .. stack.amount .. ")")
            updateBaitInventory() -- Sync after each give
        else
            print("Failed to give stack " .. i .. " to " .. targetPlayer.Name .. ": " .. tostring(result))
            -- Add back if failed
            for j = #stacks, i, -1 do
                table.insert(baitInventory, stacks[j])
            end
            return false
        end
        if i < numStacks then
            task.wait(9)
        end
    end
    return true
end

-- Start continuous Give All
local function startGiveAll()
    while giveAllRunning do
        if selectedPlayer and #baitInventory > 0 then
            giveNStacksToPlayer(selectedPlayer, #baitInventory)
        end
        task.wait(10) -- Scan every 10s
    end
end

-- Give All Button Toggle
giveAllButton.MouseButton1Click:Connect(function()
    giveAllRunning = not giveAllRunning
    if giveAllRunning then
        giveAllButton.Text = "Give All winter_2025_yarn_beanie_bait [ON]"
        giveAllButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
        giveAllCoroutine = coroutine.wrap(startGiveAll)()
    else
        giveAllButton.Text = "Give All winter_2025_yarn_beanie_bait [OFF]"
        giveAllButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    end
end)

-- Initial updates
updatePlayersDropdown()
updateBaitInventory()

-- Periodic refresh
spawn(function()
    while true do
        task.wait(30)
        updateBaitInventory()
        updatePlayersDropdown()
    end
end)

print("Bait Giver UI Loaded! Targets winter_2025_yarn_beanie_bait only. Scan button removed.")
