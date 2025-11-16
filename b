-- Small Test Function for Baby Ailment Completion
-- Usage: Call testBabyAilmentCompletion() to run once
-- Assumes ReplicatedStorage, Players, etc. are available

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Tasks = {"hungry","sleepy","thirsty","bored","dirty","camping","sick","school","hot_spring","salon","pizza_party"}

local function testBabyAilmentCompletion()
    print("Testing Baby Ailment Completion...")
    
    -- Optional: Switch to Baby team first (uncomment if needed)
    -- pcall(function()
    --     ReplicatedStorage.API["TeamAPI/ChooseTeam"]:InvokeServer("Babies", true)
    -- end)
    
    local ailmentsGui = player.PlayerGui:FindFirstChild("AilmentsMonitorApp") and player.PlayerGui.AilmentsMonitorApp:FindFirstChild("Ailments")
    if not ailmentsGui then
        warn("Ailments GUI not found!")
        return
    end
    
    local completedCount = 0
    for _, ailment in ipairs(Tasks) do
        local ailmentGui = ailmentsGui:FindFirstChild(ailment)
        if ailmentGui then
            local success, result = pcall(function()
                -- Using FireServer for BabyAilmentCompleted (adjust to InvokeServer if needed)
                return ReplicatedStorage.API["AilmentsAPI/BabyAilmentCompleted"]:FireServer(ailment)
            end)
            if success then
                completedCount = completedCount + 1
                print("Completed ailment: " .. ailment)
            else
                warn("Failed to complete " .. ailment .. ": " .. tostring(result))
            end
            wait(0.1) -- Small delay
        else
            print("Ailment not present: " .. ailment)
        end
    end
    
    print("Test completed. Ailments processed: " .. completedCount .. "/" .. #Tasks)
    
    -- Optional: Switch back to Parents (uncomment if needed)
    -- pcall(function()
    --     ReplicatedStorage.API["TeamAPI/ChooseTeam"]:InvokeServer("Parents", true)
    -- end)
end

-- To run the test: testBabyAilmentCompletion()
