local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Function to affect the "Pet Me" ailment
local function affectPetMeAilment(petModel, petUniqueID)
    -- Check if petModel is provided and valid
    if not petModel or not petModel:IsA("Model") then
        warn("No valid pet model provided!")
        return false
    end

    -- Focus on the pet
    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/FocusPet"):FireServer(petModel)
    end)
    if not success then
        warn("Failed to focus pet: " .. tostring(err))
        return false
    end
    print("Successfully focused pet")

    -- Replicate petting animation
    success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/ReplicateActivePerformances"):FireServer(
            petModel,
            {
                FocusPet = true,
                Petting = true
            }
        )
    end)
    if not success then
        warn("Failed to replicate petting: " .. tostring(err))
        return false
    end
    print("Successfully replicated petting")

    -- Apply performance modifiers (e.g., animations)
    success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/ReplicatePerformanceModifiers"):FireServer(
            petModel,
            {
                local_anim_name = "DogSit",
                local_anim_speed = 0.25,
                dont_allow_sit_states = true,
                pause_ailment_chat_bubbles = true,
                eyes_id = "squinting_eyes",
                anim_fade_time = 0.2,
                dont_allow_remote_interaction = true,
                effects = { "love" }
            }
        )
    end)
    if not success then
        warn("Failed to apply performance modifiers: " .. tostring(err))
        return false
    end
    print("Successfully applied performance modifiers")

    -- Progress the "Pet Me" ailment
    success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("AilmentsAPI/ProgressPetMeAilment"):InvokeServer(petUniqueID)
    end)
    if not success then
        warn("Failed to progress 'Pet Me' ailment: " .. tostring(err))
        return false
    end
    print("Successfully progressed 'Pet Me' ailment")

    -- Unfocus the pet
    success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/UnfocusPet"):FireServer(petModel)
    end)
    if not success then
        warn("Failed to unfocus pet: " .. tostring(err))
        return false
    end
    print("Successfully unfocused pet")

    return true
end

-- Example usage:
-- Replace "Dog" with the actual name of your pet model in the workspace
local petName = "Dog"
local petUniqueID = "2_36450beb795640eab92dd1d333d8732b"  -- Replace with your pet's unique ID

local petModel = Workspace:FindFirstChild("Pets") and Workspace.Pets:FindFirstChild(petName)
if petModel then
    affectPetMeAilment(petModel, petUniqueID)
else
    warn("Pet model '" .. petName .. "' not found in workspace!")
end
