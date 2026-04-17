local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.LocalPlayer

-- Function to check if 'trade_license' exists in the inventory/toys
local function hasTradeLicense()
    -- pcall prevents the script from breaking if Character/Backpack loads slowly
    local success, result = pcall(function()
        local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
        -- Checks if the tool is currently equipped
        if character:FindFirstChild("trade_license") then
            return true
        end
        -- Checks Backpack (inventory)
        if localPlayer.Backpack:FindFirstChild("trade_license") then
            return true
        end
        return false
    end)
    
    if success then
        return result
    else
        warn("Inventory check failed, retrying...")
        return false
    end
end

-- Function to click the dialog button
local function clickDialogButton()
    repeat task.wait() until localPlayer:FindFirstChild("PlayerGui")
    
    local button = localPlayer.PlayerGui:FindFirstChild("DialogApp")
        and localPlayer.PlayerGui.DialogApp:FindFirstChild("Dialog")
        and localPlayer.PlayerGui.DialogApp.Dialog:FindFirstChild("NormalDialog")
        and localPlayer.PlayerGui.DialogApp.Dialog.NormalDialog:FindFirstChild("Buttons")
        and localPlayer.PlayerGui.DialogApp.Dialog.NormalDialog.Buttons:FindFirstChild("ButtonTemplate")

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

-- Function for the main Trade License sequence
local function runTradeSequence()
    local args1 = {"Interiors", "TradeLicenseZone"}
    ReplicatedStorage:WaitForChild("API"):WaitForChild("DownloadsAPI/Download"):InvokeServer(unpack(args1))

    local args2 = {"Interior", "TradeLicenseZone"}
    ReplicatedStorage:WaitForChild("_package"):WaitForChild("playadopt.me"):WaitForChild("PerformanceLogger"):WaitForChild("logPlayerState"):FireServer(unpack(args2))

    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/BeginQuiz"):FireServer()
    task.wait(15)

    local args3 = {"safe"}
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AnswerQuizQuestion"):FireServer(unpack(args3))
    task.wait(15)

    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AnswerQuizQuestion"):FireServer(unpack(args3))
    task.wait(15)

    local args4 = {"not safe"}
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AnswerQuizQuestion"):FireServer(unpack(args4))

    ReplicatedStorage:WaitForChild("API"):WaitForChild("JournalAPI/CommitCollection"):FireServer()

    local args5 = {"2_7735857bb1824329b0b2bc49d4497e93"}
    ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(unpack(args5))

    local args6 = {"SafetyHub", "TradeLicenseZone", {studs_ahead_of_door = 9, start_transparency = 1}}
    ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/SendPassiveDoorEnter"):FireServer(unpack(args6))

    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/EndQuiz"):FireServer()
end

-- ========================
-- EXECUTION STARTS HERE
-- ========================

print("🔍 Checking initial inventory for Trade License...")
if hasTradeLicense() then
    print("✅ Trade License already found in inventory! No need to run the script.")
    return
end

print("🚀 Trade License not found. Running initial sequence...")
runTradeSequence()
task.wait(5)

-- Initial Dialog Click attempt
clickDialogButton()
task.wait(2)

-- Loop until Trade License is found
while not hasTradeLicense() do
    warn("🔄 Trade License still not found. Re-running sequence...")
    
    -- Run the extended requirement flags first
    local flagArgs = {"has_talked_to_trade_quest_npc", true}
    ReplicatedStorage:WaitForChild("API"):WaitForChild("SettingsAPI/SetBooleanFlag"):FireServer(unpack(flagArgs))
    ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/MarkEnteredDoorTime"):FireServer()

    -- Run the main sequence again
    runTradeSequence()
    
    -- Wait and click the dialog button again
    task.wait(5)
    clickDialogButton()
    
    -- Small buffer before checking the inventory again to allow the server to update
    task.wait(3) 
end

print("🎉 Success! Trade License has been acquired!")
