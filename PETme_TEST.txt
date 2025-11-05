-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Local player
local player = Players.LocalPlayer

-- Function to test "Pet Me" ailment
local function testPetMe(petName, petUniqueID)
    -- Check if pet exists in workspace
    local petModel = Workspace:FindFirstChild("Pets") and Workspace.Pets:FindFirstChild(petName)
    if not petModel then
        warn("Pet not found in workspace!")
        return
    end

    -- Focus on the pet
    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/FocusPet"):FireServer(petModel)
    end)
    if not success then
        warn("Failed to focus pet: " .. tostring(err))
        return
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
        return
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
        return
    end
    print("Successfully applied performance modifiers")

    -- Progress the "Pet Me" ailment
    success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("AilmentsAPI/ProgressPetMeAilment"):InvokeServer(petUniqueID)
    end)
    if not success then
        warn("Failed to progress 'Pet Me' ailment: " .. tostring(err))
        return
    end
    print("Successfully progressed 'Pet Me' ailment")

    -- Unfocus the pet
    success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/UnfocusPet"):FireServer(petModel)
    end)
    if not success then
        warn("Failed to unfocus pet: " .. tostring(err))
        return
    end
    print("Successfully unfocused pet")
end

-- Example usage:
-- Replace "Dog" with your pet's name and "2_36450beb795640eab92dd1d333d8732b" with your pet's unique ID
testPetMe("Dog", "2_36450beb795640eab92dd1d333d8732b")
