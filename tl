local args = {
	"has_talked_to_trade_quest_npc",
	true
}
game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("SettingsAPI/SetBooleanFlag"):FireServer(unpack(args))

game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("AdoptAPI/MarkEnteredDoorTime"):FireServer()

local args = {
	"Interiors",
	"TradeLicenseZone"
}
game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("DownloadsAPI/Download"):InvokeServer(unpack(args))

local args = {
	"Interior",
	"TradeLicenseZone"
}
game:GetService("ReplicatedStorage"):WaitForChild("_package"):WaitForChild("playadopt.me"):WaitForChild("PerformanceLogger"):WaitForChild("logPlayerState"):FireServer(unpack(args))


game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("TradeAPI/BeginQuiz"):FireServer()
wait(15)

local args = {
	"safe"
}
game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("TradeAPI/AnswerQuizQuestion"):FireServer(unpack(args))
wait(15)

local args = {
	"safe"
}
game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("TradeAPI/AnswerQuizQuestion"):FireServer(unpack(args))
wait(15)

local args = {
	"not safe"
}
game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("TradeAPI/AnswerQuizQuestion"):FireServer(unpack(args))


game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("JournalAPI/CommitCollection"):FireServer()

local args = {
	"2_7735857bb1824329b0b2bc49d4497e93"
}
game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(unpack(args))

local args = {
	"SafetyHub",
	"TradeLicenseZone",
	{
		studs_ahead_of_door = 9,
		start_transparency = 1
	}
}
game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("AdoptAPI/SendPassiveDoorEnter"):FireServer(unpack(args))

game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("TradeAPI/EndQuiz"):FireServer()
wait(5)
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local localPlayer = Players.LocalPlayer
-- Wait for PlayerGui to load
repeat task.wait() until localPlayer:FindFirstChild("PlayerGui")
-- Find the dialog button
local button = localPlayer.PlayerGui:FindFirstChild("DialogApp")
    and localPlayer.PlayerGui.DialogApp:FindFirstChild("Dialog")
    and localPlayer.PlayerGui.DialogApp.Dialog:FindFirstChild("NormalDialog")
    and localPlayer.PlayerGui.DialogApp.Dialog.NormalDialog:FindFirstChild("Buttons")
    and localPlayer.PlayerGui.DialogApp.Dialog.NormalDialog.Buttons:FindFirstChild("ButtonTemplate")
if button then
    -- Check if button is visible, active, and clickable
    if button.Visible and button.Active and (button:IsA("GuiButton") or button:IsA("TextButton") or button:IsA("ImageButton")) then
        -- Simulate mouse click events
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
