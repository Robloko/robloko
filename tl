-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Player
local player = Players.LocalPlayer

-- Function to check if trade_license exists in toys
local function hasTradeLicense()
    local success, errorMsg = pcall(function()
        local clientData = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("Core"):WaitForChild("ClientData"))
        local playerData = clientData.get_data()[player.Name]

        if playerData and playerData.inventory and playerData.inventory.toys then
            for toyId, toyData in pairs(playerData.inventory.toys) do
                if toyData.id == "trade_license" then
                    return true
                end
            end
        end
    end)

    if not success then
        warn("Error checking for trade_license: " .. tostring(errorMsg))
    end

    return false
end

-- Function to print all available toys in inventory
local function printAvailableToys()
    local toys = {}

    local success, errorMsg = pcall(function()
        local clientData = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("Core"):WaitForChild("ClientData"))
        local playerData = clientData.get_data()[player.Name]

        if playerData and playerData.inventory and playerData.inventory.toys then
            for toyId, toyData in pairs(playerData.inventory.toys) do
                if toyData.id then
                    table.insert(toys, {
                        id = toyId,
                        name = toyData.id,
                        amount = toyData.amount or 1
                    })
                end
            end
        end
    end)

    if not success then
        print("Error reading toy inventory: " .. tostring(errorMsg))
        return
    end

    if #toys == 0 then
        print("No toys found in your inventory!")
        return
    end

    print("=== AVAILABLE TOYS IN INVENTORY ===")
    for i, toy in ipairs(toys) do
        print(string.format("%d. %s (ID: %s) - Amount: %d", i, toy.name, toy.id, toy.amount))
    end
    print("Total toy items: " .. #toys)
    print("===================================")
end

-- Function to execute the trade license sequence
local function executeTradeLicenseSequence()
    print("Starting trade license sequence...")

    -- Step 1: Set boolean flag
    local args = {
        "has_talked_to_trade_quest_npc",
        true
    }
    game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("SettingsAPI"):WaitForChild("SetBooleanFlag"):FireServer(unpack(args))

    -- Step 2: Mark entered door time
    game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("AdoptAPI"):WaitForChild("MarkEnteredDoorTime"):FireServer()

    -- Step 3: Download TradeLicenseZone
    local args = {
        "Interiors",
        "TradeLicenseZone"
    }
    game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("DownloadsAPI"):WaitForChild("Download"):InvokeServer(unpack(args))

    -- Step 4: Log player state
    local args = {
        "Interior",
        "TradeLicenseZone"
    }
    game:GetService("ReplicatedStorage"):WaitForChild("_package"):WaitForChild("playadopt.me"):WaitForChild("PerformanceLogger"):WaitForChild("logPlayerState"):FireServer(unpack(args))

    -- Step 5: Begin quiz
    game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("TradeAPI"):WaitForChild("BeginQuiz"):FireServer()
    wait(15)

    -- Step 6: Answer quiz questions
    local args = {
        "safe"
    }
    game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("TradeAPI"):WaitForChild("AnswerQuizQuestion"):FireServer(unpack(args))
    wait(15)

    local args = {
        "safe"
    }
    game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("TradeAPI"):WaitForChild("AnswerQuizQuestion"):FireServer(unpack(args))
    wait(15)

    local args = {
        "not safe"
    }
    game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("TradeAPI"):WaitForChild("AnswerQuizQuestion"):FireServer(unpack(args))

    -- Step 7: Commit collection
    game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("JournalAPI"):WaitForChild("CommitCollection"):FireServer()

    -- Step 8: Equip tool
    local args = {
        "2_7735857bb1824329b0b2bc49d4497e93"
    }
    game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("ToolAPI"):WaitForChild("Equip"):InvokeServer(unpack(args))

    -- Step 9: Send passive door enter
    local args = {
        "SafetyHub",
        "TradeLicenseZone",
        {
            studs_ahead_of_door = 9,
            start_transparency = 1
        }
    }
    game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("AdoptAPI"):WaitForChild("SendPassiveDoorEnter"):FireServer(unpack(args))

    -- Step 10: End quiz
    game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("TradeAPI"):WaitForChild("EndQuiz"):FireServer()
    wait(5)

    -- Step 11: Click dialog button if it exists
    repeat task.wait() until player:FindFirstChild("PlayerGui")

    local button = player.PlayerGui:FindFirstChild("DialogApp") and
                   player.PlayerGui.DialogApp:FindFirstChild("Dialog") and
                   player.PlayerGui.DialogApp.Dialog:FindFirstChild("NormalDialog") and
                   player.PlayerGui.DialogApp.Dialog.NormalDialog:FindFirstChild("Buttons") and
                   player.PlayerGui.DialogApp.Dialog.NormalDialog.Buttons:FindFirstChild("ButtonTemplate")

    if button then
        if button.Visible and button.Active and (button:IsA("GuiButton") or button:IsA("TextButton") or button:IsA("ImageButton")) then
            firesignal(button.MouseButton1Down)
            task.wait(0.05)
            firesignal(button.MouseButton1Up)
            firesignal(button.MouseButton1Click)
            print("✅ Successfully clicked the dialog button!")
        else
            warn("⚠️ Button exists but is not visible/active:", button.Visible, button.Active)
        end
    else
        warn("❌ Button not found in the GUI hierarchy!")
    end
end

-- Main function to check for trade_license and execute sequence if needed
local function checkAndGetTradeLicense()
    print("Checking for trade_license in inventory...")
    printAvailableToys()

    if hasTradeLicense() then
        print("✅ trade_license already found in inventory!")
    else
        print("❌ trade_license not found. Starting sequence to obtain it...")
        executeTradeLicenseSequence()

        -- Check again after executing the sequence
        task.wait(10)
        if hasTradeLicense() then
            print("✅ Successfully obtained trade_license!")
        else
            print("❌ Failed to obtain trade_license. Retry or check for errors.")
        end
    end
end

-- Run the main function
checkAndGetTradeLicense()
