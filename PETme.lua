local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local function monitorAilments()
    while true do
        local success, data = pcall(function()
            return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
        end)

        if success and data and data.ailments_manager and data.ailments_manager.ailments then
            print("\n=== ACTIVE AILMENTS MONITOR ===")
            print("Time: " .. os.date("%H:%M:%S"))

            local hasPetMeAilment = false

            for ailmentId, ailmentData in pairs(data.ailments_manager.ailments) do
                print("\n🩺 Ailment ID: " .. ailmentId)

                for action, actionData in pairs(ailmentData) do
                    if action == "pet_me" then
                        hasPetMeAilment = true
                        print("  🐾 **PET ME AILMENT DETECTED**")
                        if type(actionData) == "table" then
                            print("    📦 Pet Me Data:")
                            for key, value in pairs(actionData) do
                                print("      - " .. key .. ": " .. tostring(value))
                            end
                        else
                            print("    📦 Pet Me: " .. tostring(actionData))
                        end
                    elseif type(actionData) == "table" then
                        print("  📦 " .. action .. " (table)")
                    else
                        print("  📦 " .. action .. ": " .. tostring(actionData))
                    end
                end
            end

            if not hasPetMeAilment then
                print("\nNo 'Pet Me' ailment detected.")
            end

            if next(data.ailments_manager.ailments) == nil then
                print("No active ailments")
            end

            print("\n===============================")
        else
            print("❌ Error reading ailments data")
        end

        wait(5) -- Check every 5 seconds
    end
end

-- Start monitoring
monitorAilments()
