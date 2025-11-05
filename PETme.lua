local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Function to progress the "Pet Me" ailment
local function progressPetMeAilment(petUniqueID)
    local args = { petUniqueID }
    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("AilmentsAPI/ProgressPetMeAilment"):FireServer(unpack(args))
    end)

    if success then
        print("Successfully progressed 'Pet Me' ailment")
        return true
    else
        warn("Failed to progress 'Pet Me' ailment: " .. tostring(err))
        return false
    end
end

-- Function to check the current progress of the "Pet Me" ailment
local function getPetMeProgress(petUniqueID)
    local success, data = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    end)

    if success and data and data.ailments_manager and data.ailments_manager.ailments then
        local petMeData = data.ailments_manager.ailments[petUniqueID] and data.ailments_manager.ailments[petUniqueID].pet_me
        if petMeData then
            return petMeData.progress
        end
    end
    return nil
end

-- Function to finish the "Pet Me" ailment
local function finishPetMeAilment(petUniqueID)
    print("Starting to finish 'Pet Me' ailment for Pet ID: " .. petUniqueID)

    while true do
        local currentProgress = getPetMeProgress(petUniqueID)
        if currentProgress == nil then
            warn("Failed to get current progress for 'Pet Me' ailment")
            break
        end

        print("Current progress: " .. currentProgress)

        -- Check if the ailment is already fully progressed
        if currentProgress >= 1 then
            print("'Pet Me' ailment is fully progressed!")
            break
        end

        -- Progress the ailment
        local success = progressPetMeAilment(petUniqueID)
        if not success then
            warn("Failed to progress 'Pet Me' ailment")
            break
        end

        wait(1) -- Wait a second before progressing again
    end
end

-- Example usage:
local petUniqueID = "2_36450beb795640eab92dd1d333d8732b"

-- Start finishing the "Pet Me" ailment
finishPetMeAilment(petUniqueID)
