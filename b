-- Baby Farm Script
-- Place this as a LocalScript in StarterPlayerScripts or similar
-- This script monitors and handles baby ailments using furniture logic from the main PetFarm

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Player
local player = Players.LocalPlayer

-- Debug settings
local DEBUG_MODE = true

-- Baby Farm variables
local BabyFarmMode = false
local babyFarmCoroutine = nil

-- Ailment to Furniture Mapping (simplified for babies, only basic furniture and special for hungry/thirsty/sick)
local BABY_AILMENT_TASKS = {
    sleepy = "BasicBed",
    hungry = "teachers_apple",
    thirsty = "water",
    dirty = "CheapPetBathtub",
    bored = "Piano",
    sick = "healing_apple"
}

-- Task cooldowns to prevent spam
local lastTaskTime = {}
local TASK_COOLDOWN = 30 -- seconds

-- Debug function
local function debugPrint(message)
    if not DEBUG_MODE then return end
    local hours = os.date("%H")
    local minutes = os.date("%M")
    local seconds = os.date("%S")
    local timestamp = string.format("[%s:%s:%s]", hours, minutes, seconds)
    print(timestamp .. " [BabyFarm] " .. message)
end

-- Function to safely get player data (from provided snippet)
local function getPlayerData()
    local clientModules = ReplicatedStorage:WaitForChild("ClientModules", 10)
    if not clientModules then return nil end

    local coreModule = clientModules:WaitForChild("Core", 5)
    if not coreModule then return nil end

    local clientDataModule = coreModule:WaitForChild("ClientData", 5)
    if not clientDataModule then return nil end

    local clientData
    local success, err = pcall(function()
        clientData = require(clientDataModule)
    end)
    if not success or not clientData then return nil end

    local playerData
    success, err = pcall(function()
        playerData = clientData.get_data()[player.Name]
    end)
    if not success or not playerData then return nil end

    return playerData
end

-- Enhanced helper to extract ailment key from potentially table-structured ailment
local function extractAilmentKey(ailment)
    if type(ailment) == "table" then
        -- Try common fields first
        local candidates = {"type", "name", "ailment", "id", "key", "kind"}
        for _, field in ipairs(candidates) do
            local val = ailment[field]
            if type(val) == "string" then
                local lowerVal = val:lower()
                if BABY_AILMENT_TASKS[lowerVal] then
                    debugPrint("Extracted ailment '" .. lowerVal .. "' from field '" .. field .. "'")
                    return lowerVal
                end
            end
        end
        -- If no direct match, search all string values for known ailments
        for k, v in pairs(ailment) do
            if type(v) == "string" then
                local lowerV = v:lower()
                if BABY_AILMENT_TASKS[lowerV] then
                    debugPrint("Found matching ailment string '" .. lowerV .. "' in table key '" .. tostring(k) .. "'")
                    return lowerV
                end
            elseif type(v) == "table" then
                -- Recurse into sub-tables if needed
                local subKey = extractAilmentKey(v)
                if subKey ~= "unknown" then
                    return subKey
                end
            end
        end
        -- If still unknown, debug the structure
        debugPrint("Unknown ailment table structure for debugging:")
        for k, v in pairs(ailment) do
            debugPrint("  Key: " .. tostring(k) .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")")
        end
        return "unknown"
    else
        local str = tostring(ailment):lower()
        if BABY_AILMENT_TASKS[str] then
            return str
        end
        return str
    end
end

-- Function to print available baby ailments in compact form (updated to use extraction)
local function printAvailableBabyAilmentsCompact()
    debugPrint("🔍 BABY AILMENTS (COMPACT)")
    debugPrint("=========================")

    local playerData = getPlayerData()
    if not playerData or not playerData.ailments_manager or not playerData.ailments_manager.baby_ailments then
        debugPrint("No baby ailments found.")
        return
    end

    local babyAilments = playerData.ailments_manager.baby_ailments
    local count = 0
    local actionableCount = 0

    debugPrint(string.format("%-5s %-36s %-15s %-10s", "No.", "Pet Unique ID", "Ailment", "Actionable"))
    debugPrint(string.rep("-", 70))

    for petUniqueID, ailment in pairs(babyAilments) do
        local ailmentKey = extractAilmentKey(ailment)
        local isActionable = BABY_AILMENT_TASKS[ailmentKey] and ailmentKey ~= "unknown"
        if isActionable then actionableCount = actionableCount + 1 end
        count = count + 1
        local status = isActionable and "YES" or "NO"
        debugPrint(string.format("%-5d %-36s %-15s %-10s", count, petUniqueID:sub(1, 36), ailmentKey, status))
    end

    debugPrint(string.rep("-", 70))
    debugPrint(string.format("Total baby ailments: %d (Actionable: %d)", count, actionableCount))
end

-- Extracted/Adapted from w1: Character validation
local function getValidCharacter()
    local currentChar = player.Character
    if currentChar and currentChar.Parent and currentChar:FindFirstChild("HumanoidRootPart") then
        return currentChar
    end
    debugPrint("Character not found or invalid, waiting for CharacterAdded...")
    local character = player.CharacterAdded:Wait()
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

-- Extracted/Adapted from w1: Ensure character is spawned and valid
local function ensureCharacterSpawned()
    local char = getValidCharacter()
    if not char then
        debugPrint("Respawning character...")
        pcall(function()
            ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/Spawn"):InvokeServer()
        end)
        task.wait(5)
        char = getValidCharacter()
    end
    return char
end

-- Extracted/Adapted from w1: Check if player is at home
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

-- Dynamic function to find player's home folder
local function findHomeFolder()
    local hi = Workspace:FindFirstChild("HouseInteriors")
    if not hi then
        debugPrint("HouseInteriors folder not found")
        return nil
    end
    for _, folder in ipairs(hi:GetChildren()) do
        if string.find(folder.Name, player.Name) then
            debugPrint("Found home folder: " .. folder.Name)
            return folder
        end
    end
    debugPrint("No home folder found containing player name")
    return nil
end

-- Extracted/Adapted from w1: Find player's pet in workspace (for specific unique ID)
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

-- Extracted/Adapted from w1: Ensure pet is equipped (simplified for baby, assumes equip_manager not needed for temp equip)
local function ensurePetEquipped(petUniqueID, timeout)
    timeout = timeout or 15
    if not petUniqueID then
        debugPrint("ensurePetEquipped: no petUniqueID provided")
        return false
    end
    debugPrint("Equipping baby pet temporarily: " .. tostring(petUniqueID))
    local success, result = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(petUniqueID, {use_sound_delay = true, equip_as_last = false})
    end)
    if not success then
        debugPrint("Failed to equip baby pet: " .. tostring(result))
        return false
    end
    -- Wait and verify in workspace
    local startTime = os.time()
    while os.time() - startTime < timeout do
        local petModel = findPetModel(petUniqueID)
        if petModel then
            debugPrint("Baby pet successfully equipped and present")
            return petModel
        end
        task.wait(0.5)
    end
    debugPrint("Baby pet did not fully equip within timeout")
    return false
end

-- Extracted/Adapted from w1: Find furniture and activate (core of useFurnitureWithPet) - updated to use localPlayer.Character and dynamic home
local function activateFurniture(furnitureName)
    local homeFolder = findHomeFolder()
    if not homeFolder then
        debugPrint("Home folder not found")
        return false
    end
    local furnitureFolder = homeFolder:FindFirstChild("Furniture")
    if not furnitureFolder then
        debugPrint("Furniture folder not found")
        return false
    end
    local furniture = furnitureFolder:FindFirstChild(furnitureName)
    if not furniture then
        debugPrint("Furniture not found: " .. furnitureName)
        return false
    end
    local playerChar = player.Character
    if not playerChar then
        debugPrint("Local player character not found")
        return false
    end
    debugPrint("Activating furniture: " .. furnitureName .. " using localPlayer character in home: " .. homeFolder.Name)
    local args = {
        playerChar,
        {
            furniture = furniture
        }
    }
    local success, err = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/ReplicateActivePerformances"):FireServer(unpack(args))
    end)
    if success then
        debugPrint("Successfully activated furniture: " .. furnitureName .. " on localPlayer")
        return true
    else
        debugPrint("Failed to activate furniture: " .. tostring(err))
        return false
    end
end

-- Adapted from w1: Use furniture with localPlayer (no pet equip for baby furniture)
local function useFurnitureWithLocalPlayer(furnitureName)
    debugPrint("Using furniture for baby: " .. furnitureName .. " on localPlayer")
    local success = activateFurniture(furnitureName)
    if success then
        task.wait(20)  -- Wait for ailment cure
        return true
    else
        debugPrint("Failed to activate furniture with localPlayer")
        return false
    end
end

-- Buy teachers_apple
local function buyTeachersApple()
    debugPrint("Buying teachers_apple from shop...")
    local args = {
        "food",
        "teachers_apple",
        {
            buy_count = 1
        }
    }
    local success, result = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/BuyItem"):InvokeServer(unpack(args))
    end)
    if success then
        debugPrint("Successfully purchased teachers_apple")
        return true
    else
        debugPrint("Failed to buy teachers_apple: " .. tostring(result))
        return false
    end
end

-- Find teachers_apple in inventory
local function findTeachersApple()
    debugPrint("Scanning inventory for teachers_apple...")
    local teachersAppleID = nil
    local success, errorMsg = pcall(function()
        local clientData = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = clientData.get_data()[player.Name]
        if playerData and playerData.inventory and playerData.inventory.food then
            for foodId, foodData in pairs(playerData.inventory.food) do
                if foodData.id and string.lower(foodData.id) == "teachers_apple" then
                    teachersAppleID = foodId
                    debugPrint("Found teachers_apple with ID: " .. foodId)
                    break
                end
            end
        end
    end)
    if not success then
        debugPrint("Error scanning inventory for teachers_apple: " .. tostring(errorMsg))
    end
    return teachersAppleID
end

-- Use teachers_apple on localPlayer (no pet equip needed for baby ailments)
local function useTeachersApple(foodID)
    if not foodID then
        debugPrint("Cannot use teachers_apple: Missing foodID")
        return false
    end
    debugPrint("Using teachers_apple " .. foodID .. " on localPlayer for baby ailment")
    
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
        debugPrint("Failed to equip teachers_apple: " .. tostring(equipResult))
        return false
    end
    debugPrint("Successfully equipped teachers_apple")
    task.wait(2)
    
    local startArgs = {
        foodID,
        "START"
    }
    local endArgs = {
        foodID,
        "END"
    }
    
    -- START
    local startSuccess, startResult = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(startArgs))
    end)
    if not startSuccess then
        debugPrint("Failed to start using teachers_apple: " .. tostring(startResult))
        pcall(function()
            ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Unequip"):InvokeServer(foodID)
        end)
        return false
    end
    task.wait(2)
    
    -- END (first)
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(endArgs))
    end)
    task.wait(2)
    
    -- START END (second)
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(startArgs))
    end)
    task.wait(2)
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(endArgs))
    end)
    task.wait(2)
    
    -- START (third)
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(startArgs))
    end)
    task.wait(2)
    
    -- Unequip food
    local unequipArgs = { foodID }
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Unequip"):InvokeServer(unpack(unequipArgs))
    end)
    
    -- Final END
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(endArgs))
    end)
    task.wait(2)
    
    debugPrint("Successfully used teachers_apple on localPlayer")
    return true
end

-- Handle hungry ailment for baby (use on localPlayer)
local function handleHungryAilment()
    debugPrint("HUNGRY AILMENT DETECTED FOR BABY! Starting feeding process on localPlayer...")
    local teachersAppleID = findTeachersApple()
    if not teachersAppleID then
        debugPrint("No teachers_apple found in inventory, purchasing one...")
        local purchaseSuccess = buyTeachersApple()
        if not purchaseSuccess then
            debugPrint("Failed to purchase teachers_apple")
            return false
        end
        task.wait(2)
        teachersAppleID = findTeachersApple()
        if not teachersAppleID then
            debugPrint("Failed to find teachers_apple after purchase")
            return false
        end
    end
    local useSuccess = useTeachersApple(teachersAppleID)
    if useSuccess then
        debugPrint("Successfully handled hungry ailment with teachers_apple on localPlayer")
        return true
    else
        debugPrint("Failed to use teachers_apple on localPlayer")
        return false
    end
end

-- Buy water
local function buyWater()
    debugPrint("Buying water from shop...")
    local args = {
        "food",
        "water",
        {
            buy_count = 1
        }
    }
    local success, result = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/BuyItem"):InvokeServer(unpack(args))
    end)
    if success then
        debugPrint("Successfully purchased water")
        return true
    else
        debugPrint("Failed to buy water: " .. tostring(result))
        return false
    end
end

-- Find water in inventory
local function findWater()
    debugPrint("Scanning inventory for water...")
    local waterID = nil
    local success, errorMsg = pcall(function()
        local clientData = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = clientData.get_data()[player.Name]
        if playerData and playerData.inventory and playerData.inventory.food then
            for foodId, foodData in pairs(playerData.inventory.food) do
                if foodData.id and string.lower(foodData.id) == "water" then
                    waterID = foodId
                    debugPrint("Found water with ID: " .. foodId)
                    break
                end
            end
        end
    end)
    if not success then
        debugPrint("Error scanning inventory for water: " .. tostring(errorMsg))
    end
    return waterID
end

-- Use water on localPlayer (no pet equip needed for baby ailments)
local function useWater(foodID)
    if not foodID then
        debugPrint("Cannot use water: Missing foodID")
        return false
    end
    debugPrint("Using water " .. foodID .. " on localPlayer for baby ailment")
    
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
        debugPrint("Failed to equip water: " .. tostring(equipResult))
        return false
    end
    debugPrint("Successfully equipped water")
    task.wait(3)
    
    local startArgs = {
        foodID,
        "START"
    }
    local endArgs = {
        foodID,
        "END"
    }
    
    -- Perform multiple START/END cycles as per provided code (9 full cycles)
    for i = 1, 9 do
        pcall(function()
            ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(startArgs))
        end)
        task.wait(2)
        pcall(function()
            ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(endArgs))
        end)
        task.wait(2)
    end
    
    -- Unequip food
    local unequipArgs = { foodID }
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Unequip"):InvokeServer(unpack(unequipArgs))
    end)
    
    -- Final END
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(endArgs))
    end)
    task.wait(2)
    
    debugPrint("Successfully used water on localPlayer")
    return true
end

-- Handle thirsty ailment for baby (use on localPlayer)
local function handleThirstyAilment()
    debugPrint("THIRSTY AILMENT DETECTED FOR BABY! Starting watering process on localPlayer...")
    local waterID = findWater()
    if not waterID then
        debugPrint("No water found in inventory, purchasing one...")
        local purchaseSuccess = buyWater()
        if not purchaseSuccess then
            debugPrint("Failed to purchase water")
            return false
        end
        task.wait(3)
        waterID = findWater()
        if not waterID then
            debugPrint("Failed to find water after purchase")
            return false
        end
    end
    local useSuccess = useWater(waterID)
    if useSuccess then
        debugPrint("Successfully handled thirsty ailment with water on localPlayer")
        return true
    else
        debugPrint("Failed to use water on localPlayer")
        return false
    end
end

-- Buy healing_apple
local function buyHealingApple()
    debugPrint("Buying healing_apple from shop...")
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
        debugPrint("Successfully purchased healing_apple")
        return true
    else
        debugPrint("Failed to buy healing_apple: " .. tostring(result))
        return false
    end
end

-- Find healing_apple in inventory
local function findHealingApple()
    debugPrint("Scanning inventory for healing_apple...")
    local healingAppleID = nil
    local success, errorMsg = pcall(function()
        local clientData = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = clientData.get_data()[player.Name]
        if playerData and playerData.inventory and playerData.inventory.food then
            for foodId, foodData in pairs(playerData.inventory.food) do
                if foodData.id and string.lower(foodData.id) == "healing_apple" then
                    healingAppleID = foodId
                    debugPrint("Found healing_apple with ID: " .. foodId)
                    break
                end
            end
        end
    end)
    if not success then
        debugPrint("Error scanning inventory for healing_apple: " .. tostring(errorMsg))
    end
    return healingAppleID
end

-- Use healing_apple on localPlayer (no pet equip needed for baby ailments)
local function useHealingApple(foodID)
    if not foodID then
        debugPrint("Cannot use healing_apple: Missing foodID")
        return false
    end
    debugPrint("Using healing_apple " .. foodID .. " on localPlayer for baby ailment")
    
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
        debugPrint("Failed to equip healing_apple: " .. tostring(equipResult))
        return false
    end
    debugPrint("Successfully equipped healing_apple")
    task.wait(2)
    
    local startArgs = {
        foodID,
        "START"
    }
    local endArgs = {
        foodID,
        "END"
    }
    
    -- First START/END
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(startArgs))
    end)
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(endArgs))
    end)
    task.wait(2)
    
    -- Second START/END
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(startArgs))
    end)
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(endArgs))
    end)
    task.wait(2)
    
    -- Third START
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(startArgs))
    end)
    task.wait(2)
    
    -- Unequip food
    local unequipArgs = { foodID }
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Unequip"):InvokeServer(unpack(unequipArgs))
    end)
    
    -- Final END
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(endArgs))
    end)
    task.wait(2)
    
    debugPrint("Successfully used healing_apple on localPlayer")
    return true
end

-- Handle sick ailment for baby (use on localPlayer)
local function handleSickAilment()
    debugPrint("SICK AILMENT DETECTED FOR BABY! Starting healing process on localPlayer...")
    local healingAppleID = findHealingApple()
    if not healingAppleID then
        debugPrint("No healing_apple found in inventory, purchasing one...")
        local purchaseSuccess = buyHealingApple()
        if not purchaseSuccess then
            debugPrint("Failed to purchase healing_apple")
            return false
        end
        task.wait(2)
        healingAppleID = findHealingApple()
        if not healingAppleID then
            debugPrint("Failed to find healing_apple after purchase")
            return false
        end
    end
    local useSuccess = useHealingApple(healingAppleID)
    if useSuccess then
        debugPrint("Successfully handled sick ailment with healing_apple on localPlayer")
        return true
    else
        debugPrint("Failed to use healing_apple on localPlayer")
        return false
    end
end

-- Adapted from w1: Check and buy missing furniture (baby version, same logic) - updated with dynamic home
local function checkAndBuyMissingFurniture()
    local homeFolder = findHomeFolder()
    if not homeFolder then
        debugPrint("Cannot check furniture: Home folder not found, buying all required furniture")
        -- Buy all if no home
        for ailment, furnitureName in pairs(BABY_AILMENT_TASKS) do
            if furnitureName ~= "teachers_apple" and furnitureName ~= "water" and furnitureName ~= "healing_apple" then
                debugPrint("Buying required furniture: " .. furnitureName)
                local args = {
                    "furniture",
                    furnitureName,
                    {
                        buy_count = 1
                    }
                }
                local success, result = pcall(function()
                    return ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/BuyItem"):InvokeServer(unpack(args))
                end)
                if success then
                    debugPrint("Successfully purchased: " .. furnitureName)
                else
                    debugPrint("Failed to buy " .. furnitureName .. ": " .. tostring(result))
                end
                task.wait(2)
            end
        end
        return
    end
    local furnitureFolder = homeFolder:FindFirstChild("Furniture")
    if not furnitureFolder then
        debugPrint("Furniture folder not found, buying all required furniture")
        -- Buy all if no furniture folder
        for ailment, furnitureName in pairs(BABY_AILMENT_TASKS) do
            if furnitureName ~= "teachers_apple" and furnitureName ~= "water" and furnitureName ~= "healing_apple" then
                debugPrint("Buying required furniture: " .. furnitureName)
                local args = {
                    "furniture",
                    furnitureName,
                    {
                        buy_count = 1
                    }
                }
                local success, result = pcall(function()
                    return ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/BuyItem"):InvokeServer(unpack(args))
                end)
                if success then
                    debugPrint("Successfully purchased: " .. furnitureName)
                else
                    debugPrint("Failed to buy " .. furnitureName .. ": " .. tostring(result))
                end
                task.wait(2)
            end
        end
        return
    end
    local furnitureToBuy = {}
    for ailment, furnitureName in pairs(BABY_AILMENT_TASKS) do
        if furnitureName ~= "teachers_apple" and furnitureName ~= "water" and furnitureName ~= "healing_apple" then
            furnitureToBuy[furnitureName] = true
        end
    end
    for furnitureName, _ in pairs(furnitureToBuy) do
        if not furnitureFolder:FindFirstChild(furnitureName) then
            debugPrint("Missing furniture: " .. furnitureName .. ", buying...")
            local args = {
                "furniture",
                furnitureName,
                {
                    buy_count = 1
                }
            }
            local success, result = pcall(function()
                return ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/BuyItem"):InvokeServer(unpack(args))
            end)
            if success then
                debugPrint("Successfully purchased: " .. furnitureName)
                task.wait(2)
            else
                debugPrint("Failed to buy " .. furnitureName .. ": " .. tostring(result))
            end
        end
    end
end

-- Main monitoring loop for baby ailments
local function monitorAndHandleBabyAilments()
    debugPrint("Starting baby ailment monitoring...")
    local lastScanTime = 0
    local SCAN_INTERVAL = 10 -- seconds
    local currentTime = os.time()
    while BabyFarmMode do
        currentTime = os.time()
        local playerData = getPlayerData()
        if playerData and playerData.ailments_manager and playerData.ailments_manager.baby_ailments then
            local foundActionable = false
            for petUniqueID, ailmentType in pairs(playerData.ailments_manager.baby_ailments) do
                local ailmentKey = extractAilmentKey(ailmentType)
                local furnitureName = BABY_AILMENT_TASKS[ailmentKey]
                if furnitureName then
                    foundActionable = true
                    -- Check cooldown
                    if not lastTaskTime[ailmentKey] or (currentTime - lastTaskTime[ailmentKey]) >= TASK_COOLDOWN then
                        if ailmentKey == "hungry" then
                            debugPrint("Baby hungry ailment detected for pet: " .. petUniqueID .. " → Using teachers_apple on localPlayer")
                            local success = handleHungryAilment()
                            if success then
                                lastTaskTime[ailmentKey] = currentTime
                            end
                        elseif ailmentKey == "thirsty" then
                            debugPrint("Baby thirsty ailment detected for pet: " .. petUniqueID .. " → Using water on localPlayer")
                            local success = handleThirstyAilment()
                            if success then
                                lastTaskTime[ailmentKey] = currentTime
                            end
                        elseif ailmentKey == "sick" then
                            debugPrint("Baby sick ailment detected for pet: " .. petUniqueID .. " → Using healing_apple on localPlayer")
                            local success = handleSickAilment()
                            if success then
                                lastTaskTime[ailmentKey] = currentTime
                            end
                        else
                            debugPrint("Baby " .. ailmentKey .. " ailment detected for pet: " .. petUniqueID .. " → Using " .. furnitureName .. " on localPlayer")
                            local success = useFurnitureWithLocalPlayer(furnitureName)
                            if success then
                                lastTaskTime[ailmentKey] = currentTime
                            end
                        end
                        break -- Handle one at a time
                    else
                        debugPrint(ailmentKey .. " on cooldown (" .. (TASK_COOLDOWN - (currentTime - lastTaskTime[ailmentKey])) .. "s remaining)")
                    end
                end
            end
            if not foundActionable and currentTime - lastScanTime >= 60 then
                debugPrint("No actionable baby ailments detected")
                lastScanTime = currentTime
            end
        else
            if currentTime - lastScanTime >= 60 then
                debugPrint("No baby ailments data found")
                lastScanTime = currentTime
            end
        end
        task.wait(SCAN_INTERVAL)
    end
end

-- Toggle Baby Farm mode
local function toggleBabyFarmMode()
    BabyFarmMode = not BabyFarmMode
    if BabyFarmMode then
        debugPrint("Baby Farm: ENABLED")
        local char = ensureCharacterSpawned()
        if not char then
            debugPrint("Cannot start Baby Farm: No valid character")
            BabyFarmMode = false
            return
        end
        if not isPlayerAtHome() then
            debugPrint("Player not at home, respawning...")
            pcall(function()
                ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/Spawn"):InvokeServer()
            end)
            task.wait(10)  -- Wait longer for home to load
        end
        checkAndBuyMissingFurniture()
        task.wait(3)
        babyFarmCoroutine = coroutine.wrap(monitorAndHandleBabyAilments)()
    else
        debugPrint("Baby Farm: DISABLED")
        babyFarmCoroutine = nil
    end
end

-- Simple UI for toggle (optional, compact)
local function createSimpleUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BabyFarmUI"
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 120, 0, 40)
    frame.Position = UDim2.new(0, 10, 0, 250)  -- Below main UI
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 20)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "👶 Baby Farm"
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 12
    title.Parent = frame

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(1, 0, 0, 20)
    toggleButton.Position = UDim2.new(0, 0, 1, 0)
    toggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Text = "🚀 START BABY FARM"
    toggleButton.Font = Enum.Font.SourceSansBold
    toggleButton.TextSize = 10
    toggleButton.Parent = frame

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 4)
    buttonCorner.Parent = toggleButton

    toggleButton.MouseButton1Click:Connect(function()
        toggleBabyFarmMode()
        toggleButton.Text = BabyFarmMode and "🛑 STOP BABY FARM" or "🚀 START BABY FARM"
        toggleButton.BackgroundColor3 = BabyFarmMode and Color3.fromRGB(170, 0, 0) or Color3.fromRGB(0, 170, 0)
    end)

    -- Initial scan
    task.wait(2)
    printAvailableBabyAilmentsCompact()
end

-- Initialize
createSimpleUI()
debugPrint("Baby Farm Script Loaded! Toggle via UI button.")
debugPrint("Scans baby_ailments and uses furniture to cure (basic ailments only).")
debugPrint("All ailments now handled on localPlayer without pet equip (furniture uses player.Character).")
debugPrint("UPDATED: Dynamic home folder search to fix 'Home folder not found' error.")
debugPrint("UPDATED: Longer wait after spawn for home to load.")
debugPrint("UPDATED: Buy all furniture if home/furniture folder not found.")
debugPrint("UPDATED: Added 'kind' to ailment extraction fields.")
