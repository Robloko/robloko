-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- LocalScript (place this in StarterPlayerScripts or similar)
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- Assuming the path is relative to the local player's PlayerGui
local screenGui = localPlayer:WaitForChild("PlayerGui"):WaitForChild("ScreenGui")
local frame = screenGui:WaitForChild("Frame")

frame.Visible = false

-- Player and Character
local player = Players.LocalPlayer
local character = player.CharacterAdded:Wait()

-- Debug settings
local DEBUG_MODE = true

-- PetFarm variables
local PetFarmMode = false
local petFarmCoroutine = nil
local petFarmPetID = nil
local currentToyID = nil
local currentStrollerID = nil
local currentFoodID = nil

-- Auto PetPen variables
local AutoPetPenMode = false
local autoPetPenCoroutine = nil
local lastPetPenCommitTime = 0

-- Session tracking variables
local sessionBucksEarned = 0
local sessionPotionsEarned = 0
local lastMoneyAmount = 0
local lastPotionAmount = 0

-- Trading variables
local ContinuousMode = false
local continuousCoroutine = nil

-- Auto Accept variables
local AutoAcceptMode = false
local autoAcceptCoroutine = nil

-- Auto Potion variables
local AutoPotionMode = false
local autoPotionCoroutine = nil

-- Ailment to Furniture Mapping
local AILMENT_TASKS = {
    sleepy = "BasicBed",
    hungry = "PetFoodBowl",
    thirsty = "PetWaterBowl",
    dirty = "CheapPetBathtub",
    bored = "Piano",
    toilet = "AilmentsRefresh2024LitterBox",
    play = "THROW_TOY",
    walk = "WALK_HANDLER",
    ride = "STROLLER_HANDLER",
    sick = "HEALING_APPLE",
    mystery = "MYSTERY_HANDLER",
    pet_me = "PET_ME_HANDLER"
}

-- Task cooldowns to prevent spam
local lastTaskTime = {}
local TASK_COOLDOWN = 30 -- seconds

-- Script state
local scriptInitialized = false

-- Pet selection variables
local PetID = nil
local Pet = nil
local PetsShow = {}
local currentSelectedPetKey = nil
local lastValidPetID = nil

-- Priority eggs for Auto PetPen
local priorityEggs = {
    "cracked_egg"
}
local prioritySet = {}
for _, v in ipairs(priorityEggs) do prioritySet[v] = true end

-- Debug function
local function debugPrint(message)
    if not DEBUG_MODE then return end
    local hours = os.date("%H")
    local minutes = os.date("%M")
    local seconds = os.date("%S")
    local timestamp = string.format("[%s:%s:%s]", hours, minutes, seconds)
    print(timestamp .. " " .. message)
end

-- ==================================================================
-- AUTO ACCEPT FUNCTIONS
-- ==================================================================

-- Function to accept and confirm a trade with a specific player
local function acceptAndConfirmTrade(targetPlayer)
    local args = { targetPlayer, true }
    local success1, result1 = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest"):InvokeServer(unpack(args))
    end)
    if success1 then
        task.wait(5)
        pcall(function()
            ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
        end)
        task.wait(9)
        local success3, result3 = pcall(function()
            return ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
        end)
        if success3 then
            debugPrint("Trade with " .. targetPlayer.Name .. " completed successfully!")
            return true
        end
    end
    return false
end

-- Function to scan all players and accept trades
local function scanAndAcceptAllTrades()
    local players = Players:GetPlayers()
    local localPlayer = Players.LocalPlayer
    for _, targetPlayer in ipairs(players) do
        if targetPlayer ~= localPlayer and AutoAcceptMode then
            acceptAndConfirmTrade(targetPlayer)
            task.wait(0.1) -- Small delay to avoid flooding
        end
    end
end

-- Function to continuously scan and accept trades
local function startAutoAcceptTrades()
    while AutoAcceptMode do
        scanAndAcceptAllTrades()
        task.wait(0.1) -- Check every 9 seconds
    end
end

-- Function to toggle Auto Accept mode
local function toggleAutoAcceptMode()
    AutoAcceptMode = not AutoAcceptMode
    if AutoAcceptMode then
        debugPrint("Auto Accept: ENABLED")
        autoAcceptCoroutine = coroutine.wrap(startAutoAcceptTrades)()
    else
        debugPrint("Auto Accept: DISABLED")
        autoAcceptCoroutine = nil
    end
end

-- ==================================================================
-- TRADING FUNCTIONS
-- ==================================================================

-- Function to send trade request
local function sendTradeRequest(targetPlayerName)
    if targetPlayerName == "" or not targetPlayerName then 
        debugPrint("No player name provided for trade")
        return 
    end
    
    local targetPlayer = Players:FindFirstChild(targetPlayerName)
    if not targetPlayer then 
        debugPrint("Player not found: " .. targetPlayerName)
        return 
    end
    
    debugPrint("Sending trade request to: " .. targetPlayerName)
    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/SendTradeRequest"):FireServer(targetPlayer)
    end)
    
    if success then
        debugPrint("Trade request sent successfully")
    else
        debugPrint("Failed to send trade request: " .. tostring(err))
    end
end

-- Function to get all pet IDs from inventory, sorted by priority
local function getAllPetIDsFromInventory()
    local neonAged6 = {}    -- Neon pets aged 6 (highest priority)
    local neonUnder6 = {}   -- Neon pets under age 6 (medium priority)
    local others = {}       -- Non-Neon pets (lowest priority)
    
    local success, errorMsg = pcall(function()
        local clientData = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = clientData.get_data()[player.Name]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for petIndex, petData in pairs(playerData.inventory.pets) do
                -- Add safety checks
                if petData and petData.unique and petData.id and petData.properties then
                    local petName = tostring(petData.id):lower()
                    -- Skip practice_dog and regular dogs/cats
                    if not string.find(petName, "practice_dog") and not (string.find(petName, "dog") or string.find(petName, "cat")) then
                        -- Check if pet is Neon and aged 6
                        if petData.properties.neon and (petData.properties.age or 0) == 6 then
                            table.insert(neonAged6, petData.unique)
                        -- Check if pet is Neon and under age 6
                        elseif petData.properties.neon and (petData.properties.age or 0) < 6 then
                            table.insert(neonUnder6, petData.unique)
                        -- Add non-Neon pets
                        else
                            table.insert(others, petData.unique)
                        end
                    end
                end
            end
        end
    end)
    
    if not success then
        debugPrint("Error getting pet IDs from inventory: " .. tostring(errorMsg))
    end
    
    -- Combine all pets in priority order
    local allPets = {}
    for _, petID in ipairs(neonAged6) do table.insert(allPets, petID) end
    for _, petID in ipairs(neonUnder6) do table.insert(allPets, petID) end
    for _, petID in ipairs(others) do table.insert(allPets, petID) end
    
    return allPets
end

-- Function to add all pets to trade (prioritizing Neon pets aged 6, then Neon pets, then others)
local function addAllPetsToTrade()
    debugPrint("Adding all pets to trade...")
    local petIDs = getAllPetIDsFromInventory()
    if #petIDs == 0 then 
        debugPrint("No pets found to add to trade")
        return 
    end
    
    -- Limit to 18 pets
    local maxPets = math.min(#petIDs, 18)
    debugPrint("Adding " .. maxPets .. " pets to trade")
    
    for i = 1, maxPets do
        local petID = petIDs[i]
        local success, err = pcall(function()
            ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(petID)
        end)
        
        if success then
            debugPrint("Added pet " .. i .. "/" .. maxPets .. " to trade")
        else
            debugPrint("Failed to add pet to trade: " .. tostring(err))
        end
        task.wait(0.2)
    end
    
    debugPrint("Finished adding pets to trade")
end

-- Function to complete the entire trade process
local function completeTradeProcess(targetPlayer)
    local args = { targetPlayer, true }
    local success1, result1 = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest"):InvokeServer(unpack(args))
    end)
    
    if success1 then
        task.wait(2)
        
        -- Add all pets to trade
        addAllPetsToTrade()
        task.wait(3)
        
        -- Accept negotiation
        local success2, result2 = pcall(function()
            ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
        end)
        
        if success2 then
            task.wait(9)
            
            -- Confirm trade
            local success3, result3 = pcall(function()
                ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
            end)
            
            if success3 then
                debugPrint("Trade completed successfully with " .. targetPlayer.Name)
                return true
            end
        end
    end
    
    debugPrint("Trade failed with " .. targetPlayer.Name)
    return false
end

-- Function to scan all players and complete trades
local function scanAndCompleteAllTrades()
    local players = Players:GetPlayers()
    local localPlayer = Players.LocalPlayer
    
    for _, targetPlayer in ipairs(players) do
        if targetPlayer ~= localPlayer and ContinuousMode then
            debugPrint("Attempting trade with: " .. targetPlayer.Name)
            completeTradeProcess(targetPlayer)
            task.wait(0.1)
        end
    end
end

-- Function to continuously scan and complete trades
local function startContinuousAcceptConfirm()
    while ContinuousMode do
        scanAndCompleteAllTrades()
        task.wait(9)
    end
end

-- Toggle function for continuous mode
local function toggleContinuousMode()
    ContinuousMode = not ContinuousMode
    if ContinuousMode then
        debugPrint("Auto Trade: ENABLED")
        continuousCoroutine = coroutine.wrap(startContinuousAcceptConfirm)()
    else
        debugPrint("Auto Trade: DISABLED")
        continuousCoroutine = nil
    end
end

-- ==================================================================
-- AUTO POTION FUNCTIONS
-- ==================================================================

-- Function to find pet_age_potion in inventory
local function findPetAgePotion()
    local potionID = nil
    local success, errorMsg = pcall(function()
        local clientData = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = clientData.get_data()[player.Name]
        if playerData and playerData.inventory and playerData.inventory.food then
            for foodId, foodData in pairs(playerData.inventory.food) do
                if foodData.id and string.lower(foodData.id) == "pet_age_potion" then
                    potionID = foodId
                    debugPrint("Found pet_age_potion: " .. foodId)
                    break
                end
            end
        end
    end)
    
    if not success then
        debugPrint("Error finding pet_age_potion: " .. tostring(errorMsg))
    end
    
    return potionID
end

-- Safely unequip food
local function safelyUnequipFood(foodID)
    if foodID then
        debugPrint("Unequipping food: " .. foodID)
        local args = { foodID }
        local success, result = pcall(function()
            return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Unequip"):InvokeServer(unpack(args))
        end)
        if success then
            debugPrint("Successfully unequipped food")
        else
            debugPrint("Failed to unequip food: " .. tostring(result))
        end
        task.wait(1)
    end
end

-- Function to use pet_age_potion on selected pet
local function usePetAgePotion()
    if not PetID then
        debugPrint("No pet selected for potion use!")
        return false
    end
    
    -- Verify the pet still exists and get its data
    local petExists = false
    local currentPetAge = 0
    pcall(function()
        local clientData = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = clientData.get_data()[player.Name]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for i, v in pairs(playerData.inventory.pets) do
                if v.unique == PetID then
                    petExists = true
                    currentPetAge = v.properties.age or 0
                    break
                end
            end
        end
    end)
    
    if not petExists then
        debugPrint("Selected pet no longer exists in inventory!")
        PetID = nil
        return false
    end
    
    if currentPetAge >= 6 then
        debugPrint("Pet is already age 6, no potion needed")
        return false
    end
    
    local potionID = findPetAgePotion()
    if not potionID then
        debugPrint("No pet_age_potion found in inventory!")
        return false
    end
    
    debugPrint("Using pet_age_potion on selected pet...")
    
    -- Equip potion
    local args1 = {
        potionID,
        {
            use_sound_delay = true,
            equip_as_last = false
        }
    }
    local equipSuccess, equipResult = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(unpack(args1))
    end)
    
    if not equipSuccess then
        debugPrint("Failed to equip potion: " .. tostring(equipResult))
        return false
    end
    
    debugPrint("Potion equipped successfully")
    task.wait(1)
    
    -- Start using potion
    local args2 = {
        potionID,
        "START"
    }
    local startSuccess, startResult = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(args2))
    end)
    
    if not startSuccess then
        debugPrint("Failed to start using potion: " .. tostring(startResult))
        safelyUnequipFood(potionID)
        return false
    end
    
    debugPrint("Potion use started, waiting 1 second...")
    task.wait(1)
    
    -- Create pet object for consumption
    local args3 = {
        "__Enum_PetObjectCreatorType_2",
        {
            additional_consume_uniques = {},
            pet_unique = PetID,
            unique_id = potionID
        }
    }
    local petObjectSuccess, petObjectResult = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject"):InvokeServer(unpack(args3))
    end)
    
    if not petObjectSuccess then
        debugPrint("Failed to create pet object for potion: " .. tostring(petObjectResult))
        safelyUnequipFood(potionID)
        return false
    end
    
    debugPrint("Potion consumed, waiting 2 seconds...")
    task.wait(2)
    
    -- Unequip potion
    safelyUnequipFood(potionID)
    
    debugPrint("Successfully used pet_age_potion on pet")
    return true
end

-- Function to start auto potion feeding
local function startAutoPotionFeeding()
    while AutoPotionMode do
        if not PetID then
            debugPrint("No pet selected for auto potion!")
            AutoPotionMode = false
            break
        end
        
        -- Check if pet is already age 6
        local currentPetAge = 0
        local currentPetType = nil
        local success, errorMsg = pcall(function()
            local clientData = require(ReplicatedStorage.ClientModules.Core.ClientData)
            local playerData = clientData.get_data()[player.Name]
            if playerData and playerData.inventory and playerData.inventory.pets then
                for i, v in pairs(playerData.inventory.pets) do
                    if v.unique == PetID then
                        currentPetAge = v.properties.age or 0
                        currentPetType = tostring(v.id)
                        break
                    end
                end
            end
        end)
        
        if currentPetAge >= 6 then
            debugPrint("Current pet reached age 6, stopping auto potion")
            AutoPotionMode = false
            break
        end
        
        -- Use potion
        local potionUsed = usePetAgePotion()
        if not potionUsed then
            debugPrint("Failed to use potion, stopping auto potion")
            AutoPotionMode = false
            break
        end
        
        -- Wait before next potion use
        task.wait(5)
    end
end

-- Function to toggle auto potion mode
local function toggleAutoPotionMode()
    AutoPotionMode = not AutoPotionMode
    if AutoPotionMode then
        debugPrint("Auto Potion: ENABLED (pet_age_potion only)")
        autoPotionCoroutine = coroutine.wrap(startAutoPotionFeeding)()
    else
        debugPrint("Auto Potion: DISABLED")
        autoPotionCoroutine = nil
    end
end

-- ==================================================================
-- COMPLETE PLAY AILMENT LOGIC - ALL FUNCTIONS DEFINED
-- ==================================================================

-- 1. HARDCODED SQUEAKY BONE (NO BUY, FORCE USE)
local SQUEAKY_BONE_ID = nil
local function getSqueakyBoneID()
    if SQUEAKY_BONE_ID then
        return SQUEAKY_BONE_ID
    end
   
    local success, data = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    end)
   
    if not success or not data or not data.inventory or not data.inventory.toys then
        debugPrint("No inventory or toys data found!")
        return nil
    end
   
    for uniqueId, toyData in pairs(data.inventory.toys) do
        if toyData.id == "squeaky_bone_default" then
            debugPrint("Found squeaky_bone_default → ID: " .. uniqueId)
            SQUEAKY_BONE_ID = uniqueId
            return uniqueId
        end
    end
   
    debugPrint("squeaky_bone_default NOT FOUND in inventory!")
    return nil
end

-- 2. Safely unequip toy
local function safelyUnequipToy()
    if currentToyID then
        debugPrint("Unequipping toy: " .. currentToyID)
        local args = { currentToyID }
        local success, result = pcall(function()
            return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Unequip"):InvokeServer(unpack(args))
        end)
       
        if success then
            debugPrint("Successfully unequipped toy")
        else
            debugPrint("Failed to unequip toy: " .. tostring(result))
        end
       
        currentToyID = nil
        task.wait(1)
    else
        debugPrint("No toy equipped to unequip - skipping")
    end
end

-- 3. Single throw function
local function performThrowToy()
    local toyID = getSqueakyBoneID()
    if not toyID then
        debugPrint("NO squeaky_bone_default → Play ailment skipped")
        return false
    end
   
    debugPrint("Using squeaky_bone_default → " .. toyID)
    currentToyID = toyID
   
    -- EQUIP
    local success1, err1 = pcall(function()
        return ReplicatedStorage.API["ToolAPI/Equip"]:InvokeServer(toyID, {
            use_sound_delay = true,
            equip_as_last = false
        })
    end)
   
    if not success1 then
        debugPrint("Failed to equip toy: " .. tostring(err1))
        safelyUnequipToy()
        return false
    end
   
    task.wait(1.2)
   
    -- START
    local success2, err2 = pcall(function()
        return ReplicatedStorage.API["ToolAPI/ServerUseTool"]:FireServer(toyID, "START")
    end)
   
    if not success2 then
        debugPrint("Failed to start using toy: " .. tostring(err2))
        safelyUnequipToy()
        return false
    end
   
    task.wait(1)
   
    -- TRIGGER PET REACTION
    local success3, err3 = pcall(function()
        return ReplicatedStorage.API["PetObjectAPI/CreatePetObject"]:InvokeServer(
            "__Enum_PetObjectCreatorType_1",
            { reaction_name = "ThrowToyReaction", unique_id = toyID }
        )
    end)
   
    if not success3 then
        debugPrint("Failed to trigger pet reaction: " .. tostring(err3))
        safelyUnequipToy()
        return false
    end
   
    task.wait(1.1)
   
    -- END
    local success4, err4 = pcall(function()
        return ReplicatedStorage.API["ToolAPI/ServerUseTool"]:FireServer(toyID, "END")
    end)
   
    if not success4 then
        debugPrint("Failed to end using toy: " .. tostring(err4))
        safelyUnequipToy()
        return false
    end
   
    debugPrint("squeaky_bone_default throw SUCCESS")
    return true
end

-- 4. Complete throw sequence (3 throws)
local function performThrowToySequence()
    debugPrint("Starting squeaky_bone_default throw sequence (3x)...")
    local toyID = getSqueakyBoneID()
    if not toyID then
        debugPrint("NO squeaky_bone_default → Play ailment skipped")
        return false
    end
   
    local successfulThrows = 0
   
    for i = 1, 3 do
        if not PetFarmMode then
            debugPrint("PetFarm stopped → canceling throw sequence")
            safelyUnequipToy()
            return false
        end
       
        debugPrint("Throw #" .. i .. " with squeaky_bone_default")
        local success, err = pcall(performThrowToy)
       
        if success and err then
            successfulThrows += 1
            debugPrint("Throw #" .. i .. " SUCCESS")
        else
            debugPrint("Throw #" .. i .. " FAILED: " .. tostring(err) .. " → stopping sequence")
            safelyUnequipToy()
            return false
        end
       
        if i < 3 then
            for w = 1, 9 do
                if not PetFarmMode then
                    safelyUnequipToy()
                    return false
                end
                task.wait(1)
            end
        end
    end
   
    safelyUnequipToy()
    local cured = successfulThrows >= 2
    debugPrint("Throw sequence finished: " .. successfulThrows .. "/3 → Play ailment " .. (cured and "CURED" or "NOT CURED"))
    return cured
end

-- 5. Main play ailment handler (THIS ONE CALLS THE OTHERS)
local function handlePlayAilment()
    debugPrint("PLAY AILMENT DETECTED! → Using squeaky_bone_default sequence")
    local toyID = getSqueakyBoneID()
    if not toyID then
        debugPrint("Play ailment FAILED: squeaky_bone_default not found")
        return false
    end
   
    -- NOW performThrowToySequence IS DEFINED AND CAN BE CALLED
    local success, err = pcall(performThrowToySequence)
   
    if success and err then
        debugPrint("Play ailment CURED with squeaky_bone_default")
        return true
    else
        debugPrint("Play ailment FAILED: " .. tostring(err) .. " (no bone or interrupted)")
        safelyUnequipToy()
        return false
    end
end

-- Function to get current money and potions
local function getCurrentMoneyAndPotions()
    local success, clientData = pcall(require, ReplicatedStorage.ClientModules.Core.ClientData)
    if not success then return 0, 0 end
    local success2, allData = pcall(clientData.get_data, clientData)
    if not success2 or not allData[player.Name] then return 0, 0 end
    local playerData = allData[player.Name]
    local money = playerData.money or 0
    local potions = 0
    -- Count potions
    if playerData.inventory and playerData.inventory.food then
        for _, foodData in pairs(playerData.inventory.food) do
            if foodData.id and string.find(string.lower(foodData.id), "potion") then
                potions = potions + (foodData.amount or 1)
            end
        end
    end
    return money, potions
end

-- Function to get recycling points and crystal eggs
local function getRecyclingAndEggData()
    local recyclingPoints = 0
    local crystalEggs = 0
   
    local success, data = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    end)
   
    if success and data then
        -- Get recycling points from saved_points
        if data.pet_recycler_manager and data.pet_recycler_manager.saved_points then
            recyclingPoints = data.pet_recycler_manager.saved_points or 0
        end
       
        -- Count crystal eggs in inventory (pet_recycler_2025_crystal_egg)
        if data.inventory and data.inventory.pets then
            for _, petData in pairs(data.inventory.pets) do
                if petData.id and string.lower(petData.id) == "pet_recycler_2025_crystal_egg" then
                    crystalEggs = crystalEggs + 1
                end
            end
        end
    end
   
    return recyclingPoints, crystalEggs
end

-- Debug function to inspect the data structure
local function debugInspectRecyclerData()
    local success, data = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    end)
   
    if success and data then
        debugPrint("=== DEBUG RECYCLER DATA ===")
        if data.pet_recycler_manager then
            for key, value in pairs(data.pet_recycler_manager) do
                if type(value) == "table" then
                    local count = 0
                    for _ in pairs(value) do count = count + 1 end
                    debugPrint("📁 " .. key .. " [TABLE with " .. count .. " items]")
                else
                    debugPrint("📄 " .. key .. " = " .. tostring(value))
                end
            end
        else
            debugPrint("❌ No pet_recycler_manager found")
        end
       
        debugPrint("=== DEBUG PET INVENTORY ===")
        if data.inventory and data.inventory.pets then
            local eggCount = 0
            for uniqueId, petData in pairs(data.inventory.pets) do
                if petData.id and string.find(string.lower(petData.id), "crystal") then
                    debugPrint("🥚 Found crystal egg: " .. petData.id .. " (ID: " .. uniqueId .. ")")
                    eggCount = eggCount + 1
                end
            end
            debugPrint("Total crystal eggs found: " .. eggCount)
        else
            debugPrint("❌ No pet inventory found")
        end
        debugPrint("=== END DEBUG ===")
    end
end

-- Function to update session earnings
local function updateSessionEarnings()
    local currentMoney, currentPotions = getCurrentMoneyAndPotions()
    -- Calculate session earnings
    if lastMoneyAmount == 0 then lastMoneyAmount = currentMoney end
    if lastPotionAmount == 0 then lastPotionAmount = currentPotions end
    sessionBucksEarned = currentMoney - lastMoneyAmount
    sessionPotionsEarned = currentPotions - lastPotionAmount
    return currentMoney, currentPotions
end

-- Function to get player data
local function getPlayerData()
    local success, data = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    end)
    if not success or not data then
        debugPrint("Failed to get player data")
        return nil
    end
    return data
end

-- Function to find the pet model
local function findPetModel(petUniqueID)
    debugPrint("Searching for pet model with ID: " .. tostring(petUniqueID))
    local data = getPlayerData()
    if not data or not data.inventory or not data.inventory.pets then
        debugPrint("Failed to get player data or pet inventory")
        return nil
    end
    for petID, petData in pairs(data.inventory.pets) do
        if petData.unique == petUniqueID then
            debugPrint("Found matching pet in inventory: " .. tostring(petData.id))
            local petsFolder = Workspace:FindFirstChild("Pets")
            if not petsFolder then
                debugPrint("Pets folder not found")
                return nil
            end
            -- Try exact match first
            local petModel = petsFolder:FindFirstChild(petData.id)
            if petModel then
                debugPrint("Found pet model: " .. petModel.Name)
                return petModel
            end
            -- Try case-insensitive search
            for _, child in pairs(petsFolder:GetChildren()) do
                if string.lower(child.Name) == string.lower(petData.id) then
                    debugPrint("Found pet model (case-insensitive): " .. child.Name)
                    return child
                end
            end
            debugPrint("Pet model not found.")
            return nil
        end
    end
    debugPrint("No pet found with unique ID: " .. tostring(petUniqueID))
    return nil
end

-- Function to focus on the pet using the correct API
local function focusPet(petModel)
    if not petModel then
        debugPrint("No pet model provided")
        return false
    end
    debugPrint("Focusing pet: " .. petModel.Name)
    local args1 = { petModel }
    local success1, err1 = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/FocusPet"):FireServer(unpack(args1))
    end)
    if success1 then
        debugPrint("Successfully focused pet using AdoptAPI/FocusPet")
        task.wait(0.5)
        local args2 = {
            petModel,
            {
                FocusPet = true
            }
        }
        local success2, err2 = pcall(function()
            ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/ReplicateActivePerformances"):FireServer(unpack(args2))
        end)
        if success2 then
            debugPrint("Successfully set performance with focus")
        else
            debugPrint("Failed to set performance: " .. tostring(err2))
        end
        return true
    else
        debugPrint("Failed to focus pet: " .. tostring(err1))
        return false
    end
end

-- Function to unfocus the pet
local function unfocusPet(petModel)
    if not petModel then
        debugPrint("No pet model provided for unfocus")
        return false
    end
    debugPrint("Unfocusing pet: " .. petModel.Name)
    local args = { petModel }
    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/UnfocusPet"):FireServer(unpack(args))
    end)
    if success then
        debugPrint("Successfully unfocused pet")
        return true
    else
        debugPrint("Failed to unfocus pet: " .. tostring(err))
        return false
    end
end

-- Function to set pet in sitting state (like "Pet Me" interaction)
local function setPetSitting(petModel)
    if not petModel then
        debugPrint("No pet model provided")
        return false
    end
    debugPrint("Setting pet to sit state: " .. petModel.Name)
    local sitAnimation = "DogSit"
    if string.find(petModel.Name:lower(), "cat") then
        sitAnimation = "CatSit"
    end
    local args = {
        petModel,
        {
            local_anim_name = sitAnimation,
            local_anim_speed = 1,
            dont_allow_sit_states = true,
            dont_allow_remote_interaction = true,
            anim_fade_time = 0.2
        }
    }
    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/ReplicatePerformanceModifiers"):FireServer(unpack(args))
    end)
    if success then
        debugPrint("Successfully set pet to sit state")
        return true
    else
        debugPrint("Failed to set sit state: " .. tostring(err))
        return false
    end
end

-- Function to progress the "Pet Me" ailment using the correct API
local function progressPetMeAilment(petUniqueID, petModel)
    if not petUniqueID or not petModel then
        debugPrint("Missing pet ID or model")
        return false
    end
    debugPrint("Attempting to progress 'Pet Me' ailment...")
    if not focusPet(petModel) then
        debugPrint("Failed to focus pet for ailment progression")
        return false
    end
    task.wait(0.5)
    if not setPetSitting(petModel) then
        debugPrint("Failed to set pet to sitting state")
        return false
    end
    task.wait(1)
    local possibleEndpoints = {
        "AilmentsAPI/ProgressPetMeAilment",
        "PetAPI/ProgressPetMeAilment",
        "AdoptAPI/ProgressPetMeAilment",
        "PetAPI/ReplicateActivePerformances",
        "PetAPI/ReplicatePerformanceModifiers"
    }
    for _, endpoint in pairs(possibleEndpoints) do
        local remoteEvent = ReplicatedStorage.API:FindFirstChild(endpoint)
        if remoteEvent then
            debugPrint("Trying endpoint: " .. endpoint)
            local args = { petUniqueID }
            local success, err = pcall(function()
                remoteEvent:FireServer(unpack(args))
            end)
            if success then
                debugPrint("Successfully called: " .. endpoint)
                return true
            else
                debugPrint("Failed to call " .. endpoint .. ": " .. tostring(err))
            end
        end
    end
    for _, endpoint in pairs(possibleEndpoints) do
        local remoteEvent = ReplicatedStorage.API:FindFirstChild(endpoint)
        if remoteEvent then
            debugPrint("Trying endpoint with model: " .. endpoint)
            local args = { petModel }
            local success, err = pcall(function()
                remoteEvent:FireServer(unpack(args))
            end)
            if success then
                debugPrint("Successfully called: " .. endpoint)
                return true
            else
                debugPrint("Failed to call " .. endpoint .. ": " .. tostring(err))
            end
        end
    end
    debugPrint("Could not find working endpoint for ailment progression")
    return false
end

-- Main function to handle 'Pet Me' ailment
local function handlePetMeAilment(petUniqueID)
    debugPrint("=== STARTING PET ME AILMENT HANDLING ===")
    local petModel = findPetModel(petUniqueID)
    if not petModel then
        debugPrint("FAILED: Could not find pet model")
        return false
    end
    debugPrint("Using pet: " .. petModel.Name)
    local success = progressPetMeAilment(petUniqueID, petModel)
    if success then
        debugPrint("SUCCESS: Ailment progression attempted")
        task.wait(2)
        debugPrint("Check if the 'Pet Me' ailment progressed in the game")
    else
        debugPrint("FAILED: Could not progress ailment")
    end
    debugPrint("Unfocusing pet...")
    if not unfocusPet(petModel) then
        local args = { Workspace:WaitForChild("Pets"):WaitForChild(petModel.Name) }
        local success, err = pcall(function()
            ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/UnfocusPet"):FireServer(unpack(args))
        end)
        if success then
            debugPrint("Successfully unfocused pet using alternative method")
        else
            debugPrint("Failed to unfocus pet using alternative method: " .. tostring(err))
        end
    end
    debugPrint("=== PET ME AILMENT HANDLING COMPLETED ===")
    return success
end

-- Character validation
local function getValidCharacter()
    local currentChar = player.Character
    if currentChar and currentChar.Parent and currentChar:FindFirstChild("HumanoidRootPart") then
        return currentChar
    end
    debugPrint("Character not found or invalid, waiting for CharacterAdded...")
    character = player.CharacterAdded:Wait()
    local startTime = os.time()
    while os.time() - startTime < 10 do
        if character and character.Parent and character:FindFirstChild("HumanoidRootPart") then
            debugPrint("Character loaded successfully")
            return character
        end
        task.wait(0.5)
    end
    debugPrint("Failed to load valid character after waiting")
    return nil
end

-- Ensure character is spawned and valid
local function ensureCharacterSpawned()
    local char = getValidCharacter()
    if not char then
        debugPrint("Respawning character...")
        game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("TeamAPI/Spawn"):InvokeServer()
        task.wait(5)
        char = getValidCharacter()
    end
    return char
end

-- Check if player is at home
local function isPlayerAtHome()
    local hi = Workspace:FindFirstChild("HouseInteriors")
    if not hi then
        return false
    end
    for _, folder in ipairs(hi:GetChildren()) do
        if string.find(folder.Name, player.Name) then
            return true
        end
    end
    return false
end

-- Find player's pet in workspace
local function findPlayerPetInWorkspace()
    local char = getValidCharacter()
    if not char then
        debugPrint("Cannot find pet: No valid character")
        return nil
    end
    if workspace:FindFirstChild("Pets") then
        for _, petInWorkspace in ipairs(workspace.Pets:GetChildren()) do
            if petInWorkspace:FindFirstChild("Owner") and petInWorkspace.Owner.Value == player then
                return petInWorkspace
            end
        end
    end
    if workspace:FindFirstChild("Pets") then
        for _, petInWorkspace in ipairs(workspace.Pets:GetChildren()) do
            if petInWorkspace:FindFirstChild("PetProperties") then
                local properties = petInWorkspace.PetProperties
                if properties:FindFirstChild("Owner") and properties.Owner.Value == player then
                    return petInWorkspace
                end
            end
        end
    end
    local humanoidRootPart = char:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart and workspace:FindFirstChild("Pets") then
        for _, petInWorkspace in ipairs(workspace.Pets:GetChildren()) do
            if petInWorkspace:FindFirstChild("HumanoidRootPart") then
                local distance = (petInWorkspace.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
                if distance < 20 then
                    return petInWorkspace
                end
            end
        end
    end
    if workspace:FindFirstChild("Pets") then
        for _, petInWorkspace in ipairs(workspace.Pets:GetChildren()) do
            if petInWorkspace:IsA("Model") and petInWorkspace:FindFirstChild("Humanoid") then
                return petInWorkspace
            end
        end
    end
    debugPrint("No pet found in workspace using all search methods")
    return nil
end

-- Ensure pet is equipped
local function ensurePetEquipped(petUniqueID, timeout)
    timeout = timeout or 15
    if not petUniqueID then
        debugPrint("ensurePetEquipped: no petUniqueID provided")
        return false
    end
    if findPlayerPetInWorkspace() then
        debugPrint("Pet already present in workspace")
        return true
    end
    debugPrint("Ensuring pet is equipped: " .. tostring(petUniqueID))
    local success, result = pcall(function()
        return ReplicatedStorage.API["ToolAPI/Equip"]:InvokeServer(petUniqueID)
    end)
    if not success then
        debugPrint("Failed to equip pet: " .. tostring(result))
        return false
    end
    local startTime = os.time()
    while os.time() - startTime < timeout do
        if findPlayerPetInWorkspace() then
            debugPrint("Pet successfully equipped and present in workspace")
            petFarmPetID = petUniqueID
            return true
        end
        task.wait(1)
    end
    debugPrint("Pet did not appear in workspace within timeout")
    return false
end

-- Find strollers in inventory
local function findStrollers()
    local strollers = {}
    local success, errorMsg = pcall(function()
        local clientData = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = clientData.get_data()[player.Name]
        if playerData and playerData.inventory and playerData.inventory.strollers then
            for strollerId, strollerData in pairs(playerData.inventory.strollers) do
                if strollerData.id then
                    table.insert(strollers, {
                        id = strollerId,
                        name = strollerData.id,
                        amount = strollerData.amount or 1
                    })
                end
            end
        end
    end)
    if not success then
        debugPrint("Error finding strollers: " .. tostring(errorMsg))
    end
    return strollers
end

-- Get first available stroller
local function getStrollerID()
    local strollers = findStrollers()
    if #strollers > 0 then
        debugPrint("Found stroller: " .. strollers[1].name .. " (ID: " .. strollers[1].id .. ")")
        return strollers[1].id
    end
    debugPrint("No strollers found in inventory")
    return nil
end

-- Buy healing apple
local function buyHealingApple()
    debugPrint("Buying healing apple from shop...")
    local args = {
        "food",
        "healing_apple",
        {
            buy_count = 1
        }
    }
    local success, result = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/BuyItem"):InvokeServer(unpack(args))
    end)
    if success then
        debugPrint("Successfully purchased healing apple")
        return true
    else
        debugPrint("Failed to buy healing apple: " .. tostring(result))
        return false
    end
end

-- Find healing apple in inventory
local function findHealingApple()
    debugPrint("Scanning inventory for healing apple...")
    local healingAppleID = nil
    local success, errorMsg = pcall(function()
        local clientData = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = clientData.get_data()[player.Name]
        if playerData and playerData.inventory and playerData.inventory.food then
            for foodId, foodData in pairs(playerData.inventory.food) do
                if foodData.id and string.lower(foodData.id) == "healing_apple" then
                    healingAppleID = foodId
                    debugPrint("Found healing apple with ID: " .. foodId)
                    break
                end
            end
        end
    end)
    if not success then
        debugPrint("Error scanning inventory for healing apple: " .. tostring(errorMsg))
    end
    return healingAppleID
end

-- Use healing apple on pet
local function useHealingApple(foodID, petUniqueID)
    if not foodID or not petUniqueID then
        debugPrint("Cannot use healing apple: Missing foodID or petUniqueID")
        return false
    end
    debugPrint("Using healing apple " .. foodID .. " on pet " .. petUniqueID)
    local equipArgs = {
        foodID,
        {
            use_sound_delay = true,
            equip_as_last = false
        }
    }
    local equipSuccess, equipResult = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(unpack(equipArgs))
    end)
    if not equipSuccess then
        debugPrint("Failed to equip healing apple: " .. tostring(equipResult))
        return false
    end
    currentFoodID = foodID
    debugPrint("Successfully equipped healing apple")
    task.wait(2)
    local startArgs = {
        foodID,
        "START"
    }
    local startSuccess, startResult = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(startArgs))
    end)
    if not startSuccess then
        debugPrint("Failed to start using healing apple: " .. tostring(startResult))
        safelyUnequipFood(foodID)
        currentFoodID = nil
        return false
    end
    debugPrint("Started using healing apple, waiting 1 second...")
    task.wait(1)
    local petObjectArgs = {
        "__Enum_PetObjectCreatorType_2",
        {
            additional_consume_uniques = {},
            pet_unique = petUniqueID,
            unique_id = foodID
        }
    }
    local petObjectSuccess, petObjectResult = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject"):InvokeServer(unpack(petObjectArgs))
    end)
    if not petObjectSuccess then
        debugPrint("Failed to create pet object for healing: " .. tostring(petObjectResult))
        safelyUnequipFood(foodID)
        currentFoodID = nil
        return false
    end
    debugPrint("Healing apple consumed, waiting 9 seconds for effect...")
    task.wait(9)
    safelyUnequipFood(foodID)
    currentFoodID = nil
    debugPrint("Successfully used healing apple on pet")
    return true
end

-- Handle sick ailment
local function handleSickAilment()
    debugPrint("SICK AILMENT DETECTED! Starting healing process...")
    local currentPetID = petFarmPetID or PetID
    if not currentPetID then
        debugPrint("No pet ID available for healing")
        return false
    end
    local healingAppleID = findHealingApple()
    if not healingAppleID then
        debugPrint("No healing apple found in inventory, purchasing one...")
        local purchaseSuccess = buyHealingApple()
        if not purchaseSuccess then
            debugPrint("Failed to purchase healing apple")
            return false
        end
        task.wait(2)
        healingAppleID = findHealingApple()
        if not healingAppleID then
            debugPrint("Failed to find healing apple after purchase")
            return false
        end
    end
    local useSuccess = useHealingApple(healingAppleID, currentPetID)
    if useSuccess then
        debugPrint("Successfully handled sick ailment with healing apple")
        return true
    else
        debugPrint("Failed to use healing apple on pet")
        return false
    end
end

-- Safely unequip stroller
local function safelyUnequipStroller()
    if currentStrollerID then
        debugPrint("Unequipping stroller: " .. currentStrollerID)
        local args = { currentStrollerID }
        local success, result = pcall(function()
            return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Unequip"):InvokeServer(unpack(args))
        end)
        if success then
            debugPrint("Successfully unequipped stroller")
        else
            debugPrint("Failed to unequip stroller: " .. tostring(result))
        end
        currentStrollerID = nil
        task.wait(1)
    else
        debugPrint("No stroller equipped to unequip - skipping")
    end
end

-- Handle walk ailment
local function handleWalkAilment()
    debugPrint("WALK AILMENT DETECTED! Starting walk sequence...")
    local currentPetID = petFarmPetID or PetID
    if not currentPetID then
        debugPrint("No pet ID available for walk sequence")
        return false
    end
    debugPrint("Storing current pet ID for re-equip: " .. tostring(currentPetID))
    local args = {
        player,
        true
    }
    local success, result = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/UnsubscribeFromHouse"):InvokeServer(unpack(args))
    end)
    if success then
        debugPrint("Successfully unsubscribed from house")
    else
        debugPrint("Failed to unsubscribe from house: " .. tostring(result))
        return false
    end
    debugPrint("Waiting 5 seconds for transition...")
    task.wait(5)
    debugPrint("Starting walking simulation...")
    for i = 1, 20 do
        if not PetFarmMode then
            debugPrint("PetFarm stopped during walk sequence, cancelling...")
            return false
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, nil)
        debugPrint("Pressing W key...")
        task.wait(1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, nil)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.S, false, nil)
        debugPrint("Pressing S key...")
        task.wait(1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.S, false, nil)
        debugPrint("Walk cycle " .. i .. "/20 completed")
    end
    debugPrint("Walk sequence completed, respawning to return home...")
    local respawnSuccess, respawnResult = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/Spawn"):InvokeServer()
    end)
    if respawnSuccess then
        debugPrint("Successfully respawned to return home")
        task.wait(5)
        debugPrint("Re-equipping pet after respawn...")
        local reequipSuccess = ensurePetEquipped(currentPetID, 10)
        if reequipSuccess then
            debugPrint("Successfully re-equipped pet after respawn")
            task.wait(2)
            return true
        else
            debugPrint("Failed to re-equip pet after respawn")
            return false
        end
    else
        debugPrint("Failed to respawn: " .. tostring(respawnResult))
        return false
    end
end

-- Handle ride ailment
local function handleRideAilment()
    debugPrint("RIDE AILMENT DETECTED! Starting ride sequence with stroller...")
    local currentPetID = petFarmPetID or PetID
    if not currentPetID then
        debugPrint("No pet ID available for ride sequence")
        return false
    end
    debugPrint("Storing current pet ID for re-equip: " .. tostring(currentPetID))
    local args = {
        player,
        true
    }
    local success, result = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/UnsubscribeFromHouse"):InvokeServer(unpack(args))
    end)
    if success then
        debugPrint("Successfully unsubscribed from house")
    else
        debugPrint("Failed to unsubscribe from house: " .. tostring(result))
        return false
    end
    debugPrint("Waiting 5 seconds for transition...")
    task.wait(5)
    local strollerID = getStrollerID()
    if not strollerID then
        debugPrint("No strollers found in inventory!")
        return false
    end
    debugPrint("Equipping stroller: " .. strollerID)
    currentStrollerID = strollerID
    local equipArgs = {
        strollerID,
        {
            use_sound_delay = true,
            equip_as_last = true
        }
    }
    local equipSuccess, equipResult = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(unpack(equipArgs))
    end)
    if not equipSuccess then
        debugPrint("Failed to equip stroller: " .. tostring(equipResult))
        currentStrollerID = nil
        return false
    end
    debugPrint("Successfully equipped stroller, starting walking simulation...")
    task.wait(3)
    debugPrint("Starting walking simulation with stroller...")
    for i = 1, 20 do
        if not PetFarmMode then
            debugPrint("PetFarm stopped during ride sequence, cancelling...")
            safelyUnequipStroller()
            return false
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, nil)
        debugPrint("Pressing W key...")
        task.wait(1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, nil)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.S, false, nil)
        debugPrint("Pressing S key...")
        task.wait(1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.S, false, nil)
        debugPrint("Ride cycle " .. i .. "/20 completed")
    end
    debugPrint("Ride sequence completed, unequipping stroller and respawning to return home...")
    safelyUnequipStroller()
    local respawnSuccess, respawnResult = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/Spawn"):InvokeServer()
    end)
    if respawnSuccess then
        debugPrint("Successfully respawned to return home")
        task.wait(5)
        debugPrint("Re-equipping pet after respawn...")
        local reequipSuccess = ensurePetEquipped(currentPetID, 10)
        if reequipSuccess then
            debugPrint("Successfully re-equipped pet after respawn")
            task.wait(2)
            return true
        else
            debugPrint("Failed to re-equip pet after respawn")
            return false
        end
    else
        debugPrint("Failed to respawn: " .. tostring(respawnResult))
        return false
    end
end

-- Extract furniture data
local function extractFurnitureData(model, folderName)
    local activationParts = {"UseBlock", "Seat1"}
    local folderId = string.match(folderName, "f%-%d+") or folderName
    for _, partName in ipairs(activationParts) do
        local useBlocksFolder = model:FindFirstChild("UseBlocks")
        if useBlocksFolder then
            local part = useBlocksFolder:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                debugPrint("Using " .. partName .. " in UseBlocks folder")
                return {
                    folderId = folderId,
                    partName = partName,
                    position = part.Position,
                    cframe = part.CFrame,
                    model = model
                }
            end
        end
        local part = model:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            debugPrint("Using " .. partName .. " directly in model")
            return {
                folderId = folderId,
                partName = partName,
                position = part.Position,
                cframe = part.CFrame,
                model = model
            }
        end
    end
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            debugPrint("Using fallback part: " .. part.Name)
            return {
                folderId = folderId,
                partName = part.Name,
                position = part.Position,
                cframe = part.CFrame,
                model = model
            }
        end
    end
    return nil
end

-- Find furniture by name
local function findFurnitureByName(name)
    debugPrint("Searching for furniture: " .. name)
    local hi = Workspace:FindFirstChild("HouseInteriors")
    if hi then
        for _, folder in ipairs(hi:GetChildren()) do
            if string.find(folder.Name, player.Name) or string.find(folder.Name, "f%-%d+") then
                local model = folder:FindFirstChild(name)
                if model and model:IsA("Model") then
                    debugPrint("Found " .. name .. " in " .. folder.Name)
                    return extractFurnitureData(model, folder.Name)
                end
            end
        end
    end
    local model = Workspace:FindFirstChild(name, true)
    if model and model:IsA("Model") then
        debugPrint("Found " .. name .. " in workspace (fallback)")
        local folderId = model.Parent and string.match(model.Parent.Name, "f%-%d+") or "unknown"
        return extractFurnitureData(model, folderId)
    end
    debugPrint("Furniture not found: " .. name)
    return nil
end

-- Check and buy missing furniture
local function checkAndBuyMissingFurniture()
    debugPrint("Checking for missing furniture...")
    local missingFurniture = {}
    local pianoFound = findFurnitureByName("Piano")
    if not pianoFound then
        debugPrint("Piano not found, adding to buy list")
        table.insert(missingFurniture, {
            kind = "piano",
            properties = {
                cframe = CFrame.new(14, 0, -16.399999618530273, 1, -3.82137093032941e-15, 8.742277657347586e-08, 3.82137093032941e-15, 1, 0, -8.742277657347586e-08, 0, 1)
            }
        })
    else
        debugPrint("Piano found in house")
    end
    local litterBoxFound = findFurnitureByName("AilmentsRefresh2024LitterBox")
    if not litterBoxFound then
        debugPrint("AilmentsRefresh2024LitterBox not found, adding to buy list")
        table.insert(missingFurniture, {
            kind = "ailments_refresh_2024_litter_box",
            properties = {
                cframe = CFrame.new(9.099609375, 0, -15.100000381469727, 1, -3.82137093032941e-15, 8.742277657347586e-08, 3.82137093032941e-15, 1, 0, -8.742277657347586e-08, 0, 1)
            }
        })
    else
        debugPrint("AilmentsRefresh2024LitterBox found in house")
    end
    if #missingFurniture > 0 then
        debugPrint("Buying " .. #missingFurniture .. " missing furniture items...")
        local args = {missingFurniture}
        local success, result = pcall(function()
            return ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/BuyFurnitures"):InvokeServer(unpack(args))
        end)
        if success then
            debugPrint("Successfully purchased missing furniture")
            task.wait(3)
        else
            debugPrint("Failed to buy furniture: " .. tostring(result))
        end
    else
        debugPrint("All furniture found, no purchases needed")
    end
end

-- Activate furniture
local function activateFurniture(furnitureName, pet)
    local furnitureData = findFurnitureByName(furnitureName)
    if not furnitureData then
        debugPrint("Cannot activate furniture: " .. furnitureName .. " - not found")
        return false
    end
    local args = {
        player,
        furnitureData.folderId,
        furnitureData.partName,
        {
            cframe = furnitureData.cframe
        },
        pet
    }
    debugPrint("Activating " .. furnitureName .. " in folder " .. furnitureData.folderId .. " with part " .. furnitureData.partName)
    local success, result = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/ActivateFurniture"):InvokeServer(unpack(args))
    end)
    if success then
        debugPrint("Successfully activated: " .. furnitureName)
        return true
    else
        debugPrint("Failed to activate: " .. furnitureName .. " - " .. tostring(result))
        return false
    end
end

-- Equip pet
local function equipPet(petID)
    local success, result = pcall(function()
        return ReplicatedStorage.API["ToolAPI/Equip"]:InvokeServer(petID)
    end)
    if success then
        debugPrint("Successfully equipped pet: " .. tostring(petID))
        for i = 1, 15 do
            if findPlayerPetInWorkspace() then
                debugPrint("Pet appeared in workspace after " .. i .. " seconds")
                break
            end
            task.wait(1)
        end
        return true
    else
        debugPrint("Failed to equip pet: " .. tostring(result))
        return false
    end
end

-- Ensure pet is equipped before starting PetFarm
local function ensurePetEquippedBeforeStart(petUniqueID, timeout)
    timeout = timeout or 15
    if not petUniqueID then
        debugPrint("ensurePetEquippedBeforeStart: no petUniqueID provided")
        return false
    end
    debugPrint("Ensuring pet is equipped before starting PetFarm: " .. tostring(petUniqueID))
    petFarmPetID = petUniqueID
    pcall(function()
        ReplicatedStorage.API["ToolAPI/Equip"]:InvokeServer(petUniqueID)
    end)
    local startTime = os.time()
    while os.time() - startTime < timeout do
        if findPlayerPetInWorkspace() then
            debugPrint("Pet is present in workspace (ensurePetEquippedBeforeStart)")
            return true
        end
        task.wait(1)
    end
    debugPrint("Pet did not appear in workspace within timeout")
    return false
end

-- Use furniture with pet
local function useFurnitureWithPet(furnitureName)
    local char = ensureCharacterSpawned()
    if not char then
        debugPrint("Cannot use furniture: No valid character")
        return false
    end
    task.wait(2)
    local petObject = nil
    for attempt = 1, 5 do
        petObject = findPlayerPetInWorkspace()
        if petObject then
            break
        end
        debugPrint("Pet not found in workspace, attempt " .. attempt .. "/5")
        task.wait(2)
    end
    if petObject then
        debugPrint("Found pet for activation: " .. petObject.Name)
        local success = activateFurniture(furnitureName, petObject)
        if success then
            task.wait(20)
            return true
        else
            debugPrint("Failed to activate furniture with pet")
            return false
        end
    else
        debugPrint("No pet found in workspace for activation after multiple attempts")
        if petFarmPetID then
            debugPrint("Re-equipping pet...")
            equipPet(petFarmPetID)
            task.wait(5)
            petObject = findPlayerPetInWorkspace()
            if petObject then
                return useFurnitureWithPet(furnitureName)
            end
        end
        return false
    end
end

-- Detect mystery ailment
local function detectMysteryAilment()
    local data = require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    for ailmentId, ailmentData in pairs(data.ailments_manager.ailments) do
        if ailmentData.mystery then
            debugPrint("MYSTERY AILMENT DETECTED! Ailment ID: " .. ailmentId)
            return ailmentId
        end
    end
    return nil
end

-- Resolve mystery ailment
local function resolveMysteryAilment(ailmentId)
    -- Prioritized list of tasks
    local tasks = {"bored", "sick", "pet me", "sleepy", "dirty", "toilet", "hungry", "thirsty", "walk", "ride"}
    -- Try all tasks for all 3 levels
    for _, chosenAilment in ipairs(tasks) do
        debugPrint("Attempting to resolve mystery ailment as: " .. chosenAilment)
        local allLevelsSuccess = true
        for level = 1, 3 do
            local args = {
                ailmentId,
                "mystery",
                level,
                chosenAilment
            }
            local success, result = pcall(function()
                return ReplicatedStorage:WaitForChild("API"):WaitForChild("AilmentsAPI/ChooseMysteryAilment"):FireServer(unpack(args))
            end)
            if success then
                debugPrint("Successfully resolved mystery ailment level " .. level .. " as " .. chosenAilment)
            else
                debugPrint("Failed to resolve mystery ailment level " .. level .. " as " .. chosenAilment .. ": " .. tostring(result))
                allLevelsSuccess = false
            end
            task.wait(1) -- Wait between levels
        end
        if allLevelsSuccess then
            debugPrint("Successfully resolved all levels of mystery ailment as " .. chosenAilment)
        else
            debugPrint("Failed to resolve all levels of mystery ailment as " .. chosenAilment)
        end
    end
    debugPrint("Finished attempting all tasks for mystery ailment")
    return true
end

-- =============================================================================
-- SMART NEON FUSION SYSTEM - FUSES WHEN 4 PETS OF SAME TYPE REACH AGE 6
-- =============================================================================
local function performNeonFusion()
    debugPrint("Checking for eligible Neon Fusion sets...")
    local fusionsPerformed = 0
    pcall(function()
        local clientData = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = clientData.get_data()[player.Name]
        if not playerData or not playerData.inventory or not playerData.inventory.pets then
            debugPrint("No pet inventory data found!")
            return 0
        end
        -- Step 1: Group all age 6 pets by their type
        local ageSixPetsByType = {}
        for uniqueId, petData in pairs(playerData.inventory.pets) do
            if petData.properties and (petData.properties.age or 0) == 6 and not petData.properties.neon then
                local petType = petData.id
                if not ageSixPetsByType[petType] then
                    ageSixPetsByType[petType] = {}
                end
                table.insert(ageSixPetsByType[petType], {
                    unique_id = uniqueId,
                    name = petType
                })
            end
        end
        -- Step 2: Check each pet type for 4+ pets and perform fusion
        for petType, pets in pairs(ageSixPetsByType) do
            while #pets >= 4 do
                debugPrint(string.format("Found 4+ age 6 pets of type: %s. Attempting Neon Fusion...", petType))
                -- Step 3: Take the first 4 pets of this type
                local fusionSet = {}
                for i = 1, 4 do
                    table.insert(fusionSet, pets[i].unique_id)
                    debugPrint(" - Using pet: " .. pets[i].unique_id)
                end
                -- Step 4: Perform Neon Fusion
                local success, err = pcall(function()
                    return ReplicatedStorage.API:FindFirstChild("PetAPI/DoNeonFusion"):InvokeServer(fusionSet)
                end)
                if success then
                    debugPrint(string.format("SUCCESS: Fused 4 %s into a Neon!", petType))
                    fusionsPerformed = fusionsPerformed + 1
                   
                    -- Remove the fused pets from the array
                    for i = 1, 4 do
                        table.remove(pets, 1)
                    end
                   
                    task.wait(3) -- Wait for server to process
                else
                    debugPrint("FAILED to perform Neon Fusion: " .. tostring(err))
                    break -- Stop trying this pet type if fusion fails
                end
            end
        end
        if fusionsPerformed > 0 then
            debugPrint(string.format("Neon Fusion completed: %d fusions performed", fusionsPerformed))
        else
            debugPrint("No eligible Neon Fusion sets found (need 4 pets of same type at age 6)")
        end
    end)
    return fusionsPerformed
end

-- =============================================================================
-- UPDATED AUTO PETPEN SYSTEM WITH SMART NEON FUSION
-- =============================================================================
-- NUCLEAR PURGE: Remove ALL non-priority trash (orangutan, practice_dog, etc.)
local function purgeNonPriorityGarbage()
    debugPrint("NUCLEAR PURGE: Eliminating garbage from PetPen...")
    local data = require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    local removed = 0
    if not data.idle_progression_manager or not data.idle_progression_manager.active_pets then
        debugPrint("PetPen empty or not loaded")
        return 0
    end
    for uniqueId, _ in pairs(data.idle_progression_manager.active_pets) do
        local pet = data.inventory.pets[uniqueId]
        if pet and pet.id and pet.properties then
            local cleanName = string.lower(pet.id)
            local isNeon = pet.properties.neon
            local age = pet.properties.age or 0
            if not isNeon and not prioritySet[cleanName] then
                debugPrint("REMOVING TRASH: " .. pet.id .. " (Age: " .. age .. ")")
                local success = pcall(function()
                    ReplicatedStorage.API["IdleProgressionAPI/RemovePet"]:FireServer(uniqueId)
                end)
                if success then
                    removed += 1
                    task.wait(0.7)
                else
                    debugPrint("Failed to remove: " .. pet.id)
                end
            end
        end
    end
    debugPrint("NUCLEAR PURGE COMPLETE: Removed " .. removed .. " garbage pets")
    task.wait(2)
    return removed
end

-- SINGLE SOURCE OF TRUTH: Get PetPen state ONCE per cycle
local function getPetPenSnapshot()
    local data = require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    local snapshot = {}
    if data.idle_progression_manager and data.idle_progression_manager.active_pets then
        for uniqueId, _ in pairs(data.idle_progression_manager.active_pets) do
            local pet = data.inventory.pets[uniqueId]
            if pet then
                table.insert(snapshot, {
                    name = pet.id,
                    age = pet.properties.age or 0,
                    neon = pet.properties.neon or false,
                    unique_id = uniqueId
                })
            end
        end
    end
    debugPrint("PETPEN SLOTS: " .. #snapshot .. "/4 filled")
    for i, pet in ipairs(snapshot) do
        local neon = pet.neon and "NEON" or ""
        debugPrint(string.format(" %d. %s (Age: %d) %s", i, pet.name, pet.age, neon))
    end
    return snapshot
end

-- Get available pets (excludes PetPen + age 6+)
local function getAvailablePets(snapshot)
    local data = require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    local inPen = {}
    for _, pet in ipairs(snapshot) do inPen[pet.unique_id] = true end
    local available = {}
    if data.inventory and data.inventory.pets then
        for uniqueId, petData in pairs(data.inventory.pets) do
            if not inPen[uniqueId] and (petData.properties.age or 0) < 6 then
                table.insert(available, {
                    unique_id = uniqueId,
                    name = petData.id,
                    age = petData.properties.age or 0,
                    neon = petData.properties.neon or false
                })
            end
        end
    end
    return available
end

-- Add pets with PERFECT priority
local function addPriorityPets(snapshot)
    local available = getAvailablePets(snapshot)
    local slotsOpen = 4 - #snapshot
    if slotsOpen <= 0 then return 0 end
    local added = 0
    local addedSet = {}
    -- Priority 1: NEON
    for _, pet in ipairs(available) do
        if pet.neon and added < slotsOpen then
            if not addedSet[pet.unique_id] then
                pcall(function() ReplicatedStorage.API["IdleProgressionAPI/AddPet"]:FireServer(pet.unique_id) end)
                debugPrint("Added NEON: " .. pet.name)
                added += 1
                addedSet[pet.unique_id] = true
                task.wait(0.6)
            end
        end
    end
    -- Priority 2: Exact egg match
    for _, eggName in ipairs(priorityEggs) do
        for _, pet in ipairs(available) do
            if pet.name == eggName and added < slotsOpen and not addedSet[pet.unique_id] then
                pcall(function() ReplicatedStorage.API["IdleProgressionAPI/AddPet"]:FireServer(pet.unique_id) end)
                debugPrint("Added PRIORITY: " .. pet.name)
                added += 1
                addedSet[pet.unique_id] = true
                task.wait(0.6)
            end
        end
    end
    -- Auto-buy cracked eggs if still room
    while added < slotsOpen and AutoPetPenMode do
        debugPrint("Buying cracked_egg to fill slot...")
        local bought = pcall(function()
            ReplicatedStorage.API["ShopAPI/BuyItem"]:InvokeServer("pets", "cracked_egg", {buy_count = 1})
        end)
        if bought then
            task.wait(3)
            local newPets = getAvailablePets(getPetPenSnapshot())
            for _, pet in ipairs(newPets) do
                if pet.name == "cracked_egg" and not addedSet[pet.unique_id] then
                    pcall(function() ReplicatedStorage.API["IdleProgressionAPI/AddPet"]:FireServer(pet.unique_id) end)
                    debugPrint("Added PURCHASED cracked_egg")
                    added += 1
                    addedSet[pet.unique_id] = true
                    task.wait(0.6)
                    break
                end
            end
        else
            break
        end
    end
    debugPrint("Added " .. added .. " pets this cycle")
    return added
end

-- MAIN FIXED LOOP WITH SMART NEON FUSION
local function startAutoPetPen()
    while AutoPetPenMode do
        debugPrint("=== AUTO PETPEN CYCLE START ===")
        -- 1. Check for Neon Fusion opportunities FIRST
        local fusionsPerformed = performNeonFusion()
        if fusionsPerformed > 0 then
            debugPrint("Neon Fusion completed, waiting 5 seconds before continuing...")
            task.wait(5)
        end
       
        -- 2. NUCLEAR PURGE (removes orangutan, practice_dog, etc.)
        purgeNonPriorityGarbage()
       
        -- 3. SINGLE SNAPSHOT (fixes double log + desync)
        local snapshot = getPetPenSnapshot()
       
        -- 4. Remove aged pets (now only age 6+ that weren't fused)
        for _, pet in ipairs(snapshot) do
            if pet.age >= 6 then
                debugPrint("Removing aged pet: " .. pet.name .. " (Age: " .. pet.age .. ")")
                pcall(function() ReplicatedStorage.API["IdleProgressionAPI/RemovePet"]:FireServer(pet.unique_id) end)
                task.wait(0.7)
            end
        end
       
        -- 5. Refresh snapshot after removals
        task.wait(2)
        snapshot = getPetPenSnapshot()
       
        -- 6. Add best pets
        addPriorityPets(snapshot)
       
        -- 7. Commit rewards (5 min)
        if os.time() - lastPetPenCommitTime >= 300 then
            pcall(function() ReplicatedStorage.API["IdleProgressionAPI/CommitAllProgression"]:FireServer() end)
            debugPrint("Committed PetPen rewards")
            lastPetPenCommitTime = os.time()
        end
       
        debugPrint("=== AUTO PETPEN CYCLE COMPLETE ===")
        task.wait(60)
    end
end

-- Toggle Auto PetPen
local function toggleAutoPetPenMode()
    AutoPetPenMode = not AutoPetPenMode
    if AutoPetPenMode then
        debugPrint("Auto PetPen: ENABLED (WITH SMART NEON FUSION)")
        lastPetPenCommitTime = os.time()
        autoPetPenCoroutine = coroutine.wrap(startAutoPetPen)()
        task.spawn(purgeNonPriorityGarbage) -- Instant purge on enable
    else
        debugPrint("Auto PetPen: DISABLED")
    end
end

-- =============================================================================
-- MAIN PETFARM FUNCTIONALITY
-- =============================================================================
-- Monitor and handle ailments (UPDATED FUNCTION)
local function monitorAndHandleAilments()
    debugPrint("Starting ailment-only monitoring system...")
    local lastAilmentScanTime = 0
    local SCAN_INTERVAL = 10 -- seconds between scans
    local lastPetCheckTime = 0
    local PET_CHECK_INTERVAL = 10 -- seconds between pet checks
    while PetFarmMode do
        local currentTime = os.time()
        -- Check and re-equip pet every PET_CHECK_INTERVAL seconds
        if currentTime - lastPetCheckTime >= PET_CHECK_INTERVAL then
            local currentPetID = petFarmPetID or PetID
            if currentPetID then
                if not findPlayerPetInWorkspace() then
                    debugPrint("Pet not found in workspace, attempting to re-equip...")
                    local success = ensurePetEquipped(currentPetID, 10)
                    if not success then
                        debugPrint("Failed to re-equip pet, stopping PetFarm")
                        PetFarmMode = false
                        break
                    end
                else
                    debugPrint("Pet is equipped and present in workspace")
                end
            else
                debugPrint("No pet ID available for re-equip, stopping PetFarm")
                PetFarmMode = false
                break
            end
            lastPetCheckTime = currentTime
        end
        local success, data = pcall(function()
            return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
        end)
        if success and data and data.ailments_manager and data.ailments_manager.ailments then
            local foundActionableAilments = false
            local currentPetID = petFarmPetID or PetID
            -- Get the unique ID of the selected pet
            local selectedPetUniqueID = nil
            if currentPetID then
                local playerData = require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
                if playerData and playerData.inventory and playerData.inventory.pets and playerData.inventory.pets[currentPetID] then
                    selectedPetUniqueID = playerData.inventory.pets[currentPetID].unique
                end
            end
            if not selectedPetUniqueID then
                debugPrint("No selected pet or pet not found in inventory")
                task.wait(SCAN_INTERVAL)
                continue
            end
            -- Only handle ailments for the selected pet
            for ailmentId, ailmentData in pairs(data.ailments_manager.ailments) do
                if ailmentId == selectedPetUniqueID then
                    foundActionableAilments = true
                    for ailmentType, furnitureName in pairs(AILMENT_TASKS) do
                        if ailmentData[ailmentType] and type(ailmentData[ailmentType]) == "table" then
                            -- Check cooldown
                            if not lastTaskTime[ailmentType] or (currentTime - lastTaskTime[ailmentType]) >= TASK_COOLDOWN then
                                if ailmentType == "play" then
                                    debugPrint("PLAY AILMENT DETECTED! Using squeaky_bone_default")
                                    local success = handlePlayAilment()
                                    if success then lastTaskTime[ailmentType] = currentTime end
                                elseif ailmentType == "walk" then
                                    debugPrint("WALK AILMENT DETECTED! Starting walk sequence")
                                    local success = handleWalkAilment()
                                    if success then lastTaskTime[ailmentType] = currentTime end
                                elseif ailmentType == "ride" then
                                    debugPrint("RIDE AILMENT DETECTED! Starting ride sequence")
                                    local success = handleRideAilment()
                                    if success then lastTaskTime[ailmentType] = currentTime end
                                elseif ailmentType == "sick" then
                                    debugPrint("SICK AILMENT DETECTED! Using healing apple")
                                    local success = handleSickAilment()
                                    if success then lastTaskTime[ailmentType] = currentTime end
                                elseif ailmentType == "mystery" then
                                    debugPrint("MYSTERY AILMENT DETECTED! Starting resolution...")
                                    local success = resolveMysteryAilment(ailmentId)
                                    if success then lastTaskTime[ailmentType] = currentTime end
                                elseif ailmentType == "pet_me" then
                                    debugPrint("PET ME AILMENT DETECTED! Handling...")
                                    local success = handlePetMeAilment(currentPetID)
                                    if success then lastTaskTime[ailmentType] = currentTime end
                                else
                                    debugPrint(string.upper(ailmentType) .. " AILMENT DETECTED! Using " .. furnitureName)
                                    local success = useFurnitureWithPet(furnitureName)
                                    if success then lastTaskTime[ailmentType] = currentTime end
                                end
                                break -- Handle one ailment at a time
                            else
                                debugPrint(ailmentType .. " task on cooldown (" .. (TASK_COOLDOWN - (currentTime - lastTaskTime[ailmentType])) .. "s remaining)")
                            end
                        end
                    end
                    if foundActionableAilments then break end
                end
            end
            -- Only show "no ailments" message once every minute
            if not foundActionableAilments and currentTime - lastAilmentScanTime >= 60 then
                debugPrint("No actionable ailments detected for selected pet")
                lastAilmentScanTime = currentTime
            end
        else
            if currentTime - lastAilmentScanTime >= 60 then
                debugPrint("Error reading ailments data or no ailments found")
                lastAilmentScanTime = currentTime
            end
        end
        task.wait(SCAN_INTERVAL)
    end
end

-- Start ailment-only PetFarm (UPDATED FUNCTION)
local function startAilmentOnlyPetFarm()
    debugPrint("Starting AILMENT-ONLY PetFarm system...")
    debugPrint("Features: Ailment Monitoring + Throw Toys for Play Ailment + Walk Handler + Ride Handler + Sick Handler + Mystery Handler + Auto Pet Re-equip")
    -- Ensure pet is equipped and present
    local currentCyclePetID = PetID or lastValidPetID or petFarmPetID
    if not currentCyclePetID then
        debugPrint("No pet selected for PetFarm")
        PetFarmMode = false
        return
    end
    local char = ensureCharacterSpawned()
    if not char then
        debugPrint("Cannot start PetFarm: No valid character")
        PetFarmMode = false
        return
    end
    -- Ensure pet is equipped with verification
    debugPrint("Ensuring pet is equipped and present...")
    local ensured = ensurePetEquipped(currentCyclePetID, 18)
    if not ensured then
        debugPrint("Failed to ensure pet is equipped/present")
        PetFarmMode = false
        return
    end
    petFarmPetID = currentCyclePetID
    lastValidPetID = currentCyclePetID
    -- Check and buy missing furniture once at start
    checkAndBuyMissingFurniture()
    task.wait(3)
    -- Lock door for safety
    local args = {true}
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/SetDoorLocked"):InvokeServer(unpack(args))
    end)
    debugPrint("Door locked, starting ailment monitoring...")
    -- Start the ailment monitoring loop
    monitorAndHandleAilments()
    -- Cleanup when stopped
    safelyUnequipToy()
    safelyUnequipStroller()
    safelyUnequipFood(currentFoodID)
    if petFarmPetID then
        pcall(function()
            ReplicatedStorage.API["ToolAPI/Unequip"]:InvokeServer(petFarmPetID)
        end)
        petFarmPetID = nil
    end
    debugPrint("Ailment-only PetFarm stopped")
end

-- Toggle PetFarm mode (UPDATED FUNCTION)
local function togglePetFarmMode()
    if PetFarmMode and petFarmCoroutine then
        debugPrint("PetFarm is already running, stopping first...")
        PetFarmMode = false
        task.wait(2)
    end
    PetFarmMode = not PetFarmMode
    if PetFarmMode then
        if not PetID and lastValidPetID then
            PetID = lastValidPetID
            debugPrint("Restored PetID from lastValidPetID: " .. tostring(PetID))
        end
        if not PetID then
            debugPrint("Please select a pet first!")
            PetFarmMode = false
            return
        end
        debugPrint("AILMENT-ONLY PetFarm: ENABLED with selected pet")
        lastValidPetID = PetID
        if not isPlayerAtHome() then
            debugPrint("Player not at home when enabling PetFarm. Waiting 2 seconds and performing a single respawn.")
            task.wait(2)
            pcall(function()
                ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/Spawn"):InvokeServer()
            end)
            task.wait(5)
        else
            debugPrint("Player is at home, no respawn required.")
        end
        local ensured = ensurePetEquipped(PetID, 18)
        if not ensured then
            debugPrint("Could not ensure selected pet is equipped/present. Starting PetFarm anyway may fail. Aborting start to be safe.")
            PetFarmMode = false
            return
        end
        petFarmCoroutine = coroutine.wrap(startAilmentOnlyPetFarm)()
    else
        debugPrint("AILMENT-ONLY PetFarm: DISABLED")
        petFarmCoroutine = nil
        safelyUnequipToy()
        safelyUnequipStroller()
        safelyUnequipFood(currentFoodID)
        if petFarmPetID then
            pcall(function()
                ReplicatedStorage.API["ToolAPI/Unequip"]:InvokeServer(petFarmPetID)
            end)
            petFarmPetID = nil
        end
    end
end

-- ==================================================================
-- UPDATED UI CREATION WITH AUTO ACCEPT FEATURE
-- ==================================================================

-- Updated createEnhancedCompactUI function with Auto Accept button
local function createEnhancedCompactUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PetFarmUI"
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    -- Increased frame height to accommodate the new button
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 180, 0, 220) -- Increased from 200 to 220
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 0.1
    frame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    -- Session Tracking Label
    local sessionLabel = Instance.new("TextLabel")
    sessionLabel.Size = UDim2.new(1, 0, 0, 20)
    sessionLabel.Position = UDim2.new(0, 5, 0, 0)
    sessionLabel.BackgroundTransparency = 1
    sessionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    sessionLabel.Text = "💵 0 +0 | 🧪 0 +0 | ♻️ 0 | 🥚 0"
    sessionLabel.Font = Enum.Font.SourceSans
    sessionLabel.TextSize = 11
    sessionLabel.TextXAlignment = Enum.TextXAlignment.Left
    sessionLabel.Parent = frame
    sessionLabel.RichText = true

    -- Developer Console Button
    local devConsoleButton = Instance.new("TextButton")
    devConsoleButton.Size = UDim2.new(0, 20, 0, 20)
    devConsoleButton.Position = UDim2.new(1, -20, 0, 0)
    devConsoleButton.BackgroundTransparency = 1
    devConsoleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    devConsoleButton.Text = "⚠️"
    devConsoleButton.Font = Enum.Font.SourceSansBold
    devConsoleButton.TextSize = 14
    devConsoleButton.Parent = frame
    devConsoleButton.MouseButton1Click:Connect(function()
        game:GetService("StarterGui"):SetCore("DevConsoleVisible", true)
    end)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 20)
    title.Position = UDim2.new(0, 0, 0, 20)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "🐾 Cocoon PetFarm"
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 14
    title.Parent = frame

    -- Player Name Input for Trading
    local playerNameBox = Instance.new("TextBox")
    playerNameBox.Size = UDim2.new(0, 160, 0, 20)
    playerNameBox.Position = UDim2.new(0, 10, 0, 45)
    playerNameBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    playerNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    playerNameBox.PlaceholderText = "Enter player name"
    playerNameBox.Text = ""
    playerNameBox.Font = Enum.Font.SourceSans
    playerNameBox.TextSize = 11
    playerNameBox.Parent = frame
    
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = playerNameBox

    -- Trade Buttons Row
    local tradeButton = Instance.new("TextButton")
    tradeButton.Size = UDim2.new(0, 78, 0, 20)
    tradeButton.Position = UDim2.new(0, 10, 0, 70)
    tradeButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    tradeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    tradeButton.Text = "Send Trade"
    tradeButton.Font = Enum.Font.SourceSansBold
    tradeButton.TextSize = 10
    tradeButton.Parent = frame
    
    local tradeButtonCorner = Instance.new("UICorner")
    tradeButtonCorner.CornerRadius = UDim.new(0, 4)
    tradeButtonCorner.Parent = tradeButton

    local addPetsButton = Instance.new("TextButton")
    addPetsButton.Size = UDim2.new(0, 78, 0, 20)
    addPetsButton.Position = UDim2.new(0, 92, 0, 70)
    addPetsButton.BackgroundColor3 = Color3.fromRGB(170, 0, 170)
    addPetsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    addPetsButton.Text = "Add All Pets"
    addPetsButton.Font = Enum.Font.SourceSansBold
    addPetsButton.TextSize = 10
    addPetsButton.Parent = frame
    
    local addPetsCorner = Instance.new("UICorner")
    addPetsCorner.CornerRadius = UDim.new(0, 4)
    addPetsCorner.Parent = addPetsButton

    -- Auto Features Row 1
    local autoTradeButton = Instance.new("TextButton")
    autoTradeButton.Size = UDim2.new(0, 78, 0, 20)
    autoTradeButton.Position = UDim2.new(0, 10, 0, 95)
    autoTradeButton.BackgroundColor3 = Color3.fromRGB(215, 120, 0)
    autoTradeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoTradeButton.Text = "Auto Trade [OFF]"
    autoTradeButton.Font = Enum.Font.SourceSansBold
    autoTradeButton.TextSize = 10
    autoTradeButton.Parent = frame
    
    local autoTradeCorner = Instance.new("UICorner")
    autoTradeCorner.CornerRadius = UDim.new(0, 4)
    autoTradeCorner.Parent = autoTradeButton

    local autoPotionButton = Instance.new("TextButton")
    autoPotionButton.Size = UDim2.new(0, 78, 0, 20)
    autoPotionButton.Position = UDim2.new(0, 92, 0, 95)
    autoPotionButton.BackgroundColor3 = Color3.fromRGB(0, 170, 170)
    autoPotionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoPotionButton.Text = "Auto Potion [OFF]"
    autoPotionButton.Font = Enum.Font.SourceSansBold
    autoPotionButton.TextSize = 10
    autoPotionButton.Parent = frame
    
    local autoPotionCorner = Instance.new("UICorner")
    autoPotionCorner.CornerRadius = UDim.new(0, 4)
    autoPotionCorner.Parent = autoPotionButton

    -- Auto Features Row 2 (NEW ROW)
    local autoAcceptButton = Instance.new("TextButton")
    autoAcceptButton.Size = UDim2.new(0, 78, 0, 20)
    autoAcceptButton.Position = UDim2.new(0, 10, 0, 120)
    autoAcceptButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
    autoAcceptButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoAcceptButton.Text = "Auto Accept [OFF]"
    autoAcceptButton.Font = Enum.Font.SourceSansBold
    autoAcceptButton.TextSize = 10
    autoAcceptButton.Parent = frame
    
    local autoAcceptCorner = Instance.new("UICorner")
    autoAcceptCorner.CornerRadius = UDim.new(0, 4)
    autoAcceptCorner.Parent = autoAcceptButton

    local autoPetPenButton = Instance.new("TextButton")
    autoPetPenButton.Size = UDim2.new(0, 78, 0, 20)
    autoPetPenButton.Position = UDim2.new(0, 92, 0, 120)
    autoPetPenButton.BackgroundColor3 = Color3.fromRGB(170, 170, 0)
    autoPetPenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoPetPenButton.Text = "Auto PetPen [OFF]"
    autoPetPenButton.Font = Enum.Font.SourceSansBold
    autoPetPenButton.TextSize = 10
    autoPetPenButton.Parent = frame
    
    local autoPetPenCorner = Instance.new("UICorner")
    autoPetPenCorner.CornerRadius = UDim.new(0, 4)
    autoPetPenCorner.Parent = autoPetPenButton

    -- PetFarm Button (moved to new row)
    local petFarmButton = Instance.new("TextButton")
    petFarmButton.Size = UDim2.new(0, 160, 0, 20)
    petFarmButton.Position = UDim2.new(0, 10, 0, 145)
    petFarmButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    petFarmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    petFarmButton.Text = "START PETFARM"
    petFarmButton.Font = Enum.Font.SourceSansBold
    petFarmButton.TextSize = 10
    petFarmButton.Parent = frame
    
    local petFarmCorner = Instance.new("UICorner")
    petFarmCorner.CornerRadius = UDim.new(0, 4)
    petFarmCorner.Parent = petFarmButton

    return {
        frame = frame,
        sessionLabel = sessionLabel,
        playerNameBox = playerNameBox,
        tradeButton = tradeButton,
        addPetsButton = addPetsButton,
        autoTradeButton = autoTradeButton,
        autoPotionButton = autoPotionButton,
        autoAcceptButton = autoAcceptButton, -- NEW
        autoPetPenButton = autoPetPenButton,
        petFarmButton = petFarmButton
    }
end

-- Updated updatePetsDropdown function with proper error handling
local function updatePetsDropdown(dropdownFrame, dropdownButton, dropdownListFrame)
    local List = {}
    local currentSelection = dropdownButton.Text
    local wasSelected = false
    local previousPetsShow = PetsShow
    PetsShow = {}
    
    local success, errorMsg = pcall(function()
        local clientData = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = clientData.get_data()[player.Name]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for i, v in pairs(playerData.inventory.pets) do
                -- Add safety checks for pet data
                if v and v.id and v.properties then
                    local neonStatus = v.properties.neon and "Neon" or ""
                    local petAge = v.properties.age or 0
                    local key = tostring(v.id) .. " - " .. tostring(petAge) .. " years old (" .. neonStatus .. ")"
                    PetsShow[key] = v
                    table.insert(List, key)
                    if key == currentSelection then
                        wasSelected = true
                    end
                else
                    debugPrint("Skipping invalid pet data: " .. tostring(v))
                end
            end
            table.sort(List)
        end
    end)
    
    if not success then
        debugPrint("Error updating pets dropdown: " .. tostring(errorMsg))
    end
    
    -- Clear existing dropdown options
    for _, child in ipairs(dropdownListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    if wasSelected and currentSelection ~= "Select a Pet" then
        dropdownButton.Text = currentSelection
        if PetsShow[currentSelection] then
            PetID = PetsShow[currentSelection].unique
            petFarmPetID = PetID
        end
    else
        dropdownButton.Text = #List > 0 and "Select a Pet (" .. #List .. ")" or "No Pets Found"
        if PetID and not wasSelected and not PetFarmMode then
            local petStillExists = false
            for _, petKey in ipairs(List) do
                if PetsShow[petKey] and PetsShow[petKey].unique == PetID then
                    petStillExists = true
                    break
                end
            end
            if not petStillExists then
                pcall(function()
                    ReplicatedStorage.API["ToolAPI/Unequip"]:InvokeServer(PetID)
                end)
                PetID = nil
                Pet = nil
                debugPrint("Previous pet selection no longer available, unequipped")
            else
                debugPrint("Pet still exists in inventory, preserving selection despite UI change")
            end
        elseif PetFarmMode and PetID and not wasSelected then
            debugPrint("PetFarm active - preserving current pet selection")
            for petKey, petData in pairs(PetsShow) do
                if petData and petData.unique == PetID then
                    dropdownButton.Text = petKey
                    wasSelected = true
                    debugPrint("Updated dropdown to match current PetFarm pet: " .. petKey)
                    break
                end
            end
        end
    end
    
    -- Create new dropdown options with safety checks
    for i, petKey in ipairs(List) do
        local optionButton = Instance.new("TextButton")
        optionButton.Size = UDim2.new(1, 0, 0, 15)
        optionButton.Position = UDim2.new(0, 0, 0, (i-1)*15)
        optionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        optionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        optionButton.Text = petKey
        optionButton.Font = Enum.Font.SourceSans
        optionButton.TextSize = 10
        optionButton.Parent = dropdownListFrame
        
        optionButton.MouseButton1Click:Connect(function()
            dropdownButton.Text = petKey
            currentSelectedPetKey = petKey
            dropdownListFrame.Visible = false
            
            -- Safety check for pet data
            if PetsShow[petKey] and PetsShow[petKey].unique then
                if PetID and PetID ~= PetsShow[petKey].unique then
                    pcall(function()
                        ReplicatedStorage.API["ToolAPI/Unequip"]:InvokeServer(PetID)
                    end)
                end
                PetID = PetsShow[petKey].unique
                lastValidPetID = PetID
                
                -- Safe equip with error handling
                local equipSuccess, equipError = pcall(function()
                    Pet = ReplicatedStorage.API["ToolAPI/Equip"]:InvokeServer(PetID)
                end)
                
                if not equipSuccess then
                    debugPrint("Failed to equip pet: " .. tostring(equipError))
                end
                
                if PetFarmMode and petFarmPetID ~= PetID then
                    petFarmPetID = PetID
                    debugPrint("Updated PetFarm pet to current selection")
                end
                debugPrint("Selected pet: " .. petKey)
            else
                debugPrint("Error: Invalid pet data for selection: " .. petKey)
            end
        end)
    end
    
    dropdownListFrame.CanvasSize = UDim2.new(0, 0, 0, #List * 15)
end

-- Create pets dropdown
local function createPetsDropdown(parentFrame, position)
    local dropdownFrame = Instance.new("Frame")
    dropdownFrame.Size = UDim2.new(0, 160, 0, 35)
    dropdownFrame.Position = position
    dropdownFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    dropdownFrame.BorderSizePixel = 0
    dropdownFrame.BackgroundTransparency = 0.1
    dropdownFrame.Parent = parentFrame
    local dropdownCorner = Instance.new("UICorner")
    dropdownCorner.CornerRadius = UDim.new(0, 4)
    dropdownCorner.Parent = dropdownFrame
    local dropdownTitle = Instance.new("TextLabel")
    dropdownTitle.Size = UDim2.new(1, 0, 0, 15)
    dropdownTitle.Position = UDim2.new(0, 0, 0, 0)
    dropdownTitle.BackgroundTransparency = 1
    dropdownTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdownTitle.Text = "Pets List"
    dropdownTitle.Font = Enum.Font.SourceSansBold
    dropdownTitle.TextSize = 11
    dropdownTitle.TextXAlignment = Enum.TextXAlignment.Left
    dropdownTitle.Parent = dropdownFrame
    local dropdownButton = Instance.new("TextButton")
    dropdownButton.Size = UDim2.new(1, 0, 0, 20)
    dropdownButton.Position = UDim2.new(0, 0, 0, 15)
    dropdownButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    dropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdownButton.Text = "Select a Pet"
    dropdownButton.Font = Enum.Font.SourceSans
    dropdownButton.TextSize = 10
    dropdownButton.Parent = dropdownFrame
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 4)
    buttonCorner.Parent = dropdownButton
    local dropdownListFrame = Instance.new("ScrollingFrame")
    dropdownListFrame.Size = UDim2.new(1, 0, 0, 200)
    dropdownListFrame.Position = UDim2.new(0, 0, 1, 0)
    dropdownListFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    dropdownListFrame.BorderSizePixel = 0
    dropdownListFrame.Visible = false
    dropdownListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    dropdownListFrame.ScrollBarThickness = 3
    dropdownListFrame.Parent = dropdownFrame
    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 4)
    listCorner.Parent = dropdownListFrame
    local dropdownToggle = false
    dropdownButton.MouseButton1Click:Connect(function()
        dropdownToggle = not dropdownToggle
        dropdownListFrame.Visible = dropdownToggle
        if dropdownToggle then
            updatePetsDropdown(dropdownFrame, dropdownButton, dropdownListFrame)
        end
    end)
    return dropdownFrame, dropdownButton, dropdownListFrame
end

-- ==================================================================
-- INITIALIZATION AND MAIN LOOP
-- ==================================================================

-- Initialize enhanced UI
local ui = createEnhancedCompactUI()

-- Add Pets Dropdown to UI (updated position)
local petsDropdownFrame, petsDropdownButton, petsDropdownListFrame = createPetsDropdown(
    ui.frame,
    UDim2.new(0, 10, 0, 170) -- Updated from 145 to 170
)

-- Function to update session display
local function updateSessionDisplay()
    local currentMoney, currentPotions = updateSessionEarnings()
    local recyclingPoints, crystalEggs = getRecyclingAndEggData()
   
    ui.sessionLabel.Text = string.format(
        "💵 %d +%d | 🧪 %d +%d | ♻️ %d | 🥚 %d",
        currentMoney, sessionBucksEarned,
        currentPotions, sessionPotionsEarned,
        recyclingPoints, crystalEggs
    )
end

-- Connect Trade button
ui.tradeButton.MouseButton1Click:Connect(function()
    sendTradeRequest(ui.playerNameBox.Text)
end)

-- Connect Enter key on textbox
ui.playerNameBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        sendTradeRequest(ui.playerNameBox.Text)
    end
end)

-- Connect Add All Pets button
ui.addPetsButton.MouseButton1Click:Connect(addAllPetsToTrade)

-- Connect Auto Trade button
ui.autoTradeButton.MouseButton1Click:Connect(function()
    toggleContinuousMode()
    ui.autoTradeButton.Text = ContinuousMode and "Auto Trade [ON]" or "Auto Trade [OFF]"
    ui.autoTradeButton.BackgroundColor3 = ContinuousMode and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(215, 120, 0)
end)

-- Connect Auto Potion button
ui.autoPotionButton.MouseButton1Click:Connect(function()
    toggleAutoPotionMode()
    ui.autoPotionButton.Text = AutoPotionMode and "Auto Potion [ON]" or "Auto Potion [OFF]"
    ui.autoPotionButton.BackgroundColor3 = AutoPotionMode and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(0, 170, 170)
end)

-- Connect Auto Accept button
ui.autoAcceptButton.MouseButton1Click:Connect(function()
    toggleAutoAcceptMode()
    ui.autoAcceptButton.Text = AutoAcceptMode and "Auto Accept [ON]" or "Auto Accept [OFF]"
    ui.autoAcceptButton.BackgroundColor3 = AutoAcceptMode and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
end)

-- Connect PetFarm button
ui.petFarmButton.MouseButton1Click:Connect(function()
    togglePetFarmMode()
    ui.petFarmButton.Text = PetFarmMode and "🛑 STOP PETFARM" or "🚀 START PETFARM"
    ui.petFarmButton.BackgroundColor3 = PetFarmMode and Color3.fromRGB(170, 0, 0) or Color3.fromRGB(0, 170, 0)
end)

-- Connect Auto PetPen button
ui.autoPetPenButton.MouseButton1Click:Connect(function()
    toggleAutoPetPenMode()
    ui.autoPetPenButton.Text = AutoPetPenMode and "Auto PetPen [ON]" or "Auto PetPen [OFF]"
    ui.autoPetPenButton.BackgroundColor3 = AutoPetPenMode and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 170, 0)
end)

-- Update pets dropdown periodically
coroutine.wrap(function()
    while true do
        if not petsDropdownListFrame.Visible then
            updatePetsDropdown(petsDropdownFrame, petsDropdownButton, petsDropdownListFrame)
        end
        task.wait(10)
    end
end)()

-- Main loop to update session display
local function mainLoop()
    while true do
        updateSessionDisplay()
        task.wait(1)
    end
end

-- Initialize session tracking
lastMoneyAmount, lastPotionAmount = getCurrentMoneyAndPotions()

-- Debug the recycler data structure on startup
task.wait(2) -- Wait for data to load
debugInspectRecyclerData()

-- Start the main loop
coroutine.wrap(mainLoop)()

debugPrint("ENHANCED PetFarm System Loaded Successfully!")
debugPrint("Features: Ailment Monitoring + Throw Toys + Walk Handler + Ride Handler + Sick Handler + Mystery Handler + Pet Me Handler + Auto Pet Re-equip")
debugPrint("NEW: Auto Trading System - Send trades, add all pets, auto accept")
debugPrint("NEW: Auto Potion System - Uses pet_age_potion only on selected pet")
debugPrint("NEW: Auto Accept System - Automatically accepts and completes trades from all players")
debugPrint("UPDATED: Smart Neon Fusion - Fuses when 4 pets of same type reach age 6")
debugPrint("UPDATED: Auto PetPen Management with accurate slot tracking, age 6 removal, and priority-based pet addition")
