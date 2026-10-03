-- =========================================
-- VIP EGG HUNTER - DELTA X (MAX POWER V12)
-- Tính năng mới: ESP hiển thị số KG của trứng
-- =========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local SafeGui = (gethui and gethui()) or game:GetService("CoreGui"):FindFirstChild("RobloxGui") or game:GetService("CoreGui")

-- =========================================
-- FILE HỆ THỐNG (LƯU TRỮ)
-- =========================================
local ConfigFile = "VIP_Egg_Config_V12.json"
local ServerFile = "VIP_Egg_Servers_V12.json"

local Settings = {
    ESP_Enabled = false,
    InfJump = false,
    FlySpeed = 5000, 
    AutoFarm = false,
    AutoHop = false,
    FarmAll = true,
    SelectedEggs = {"Volcanic Egg"}
}

local function SaveSettings()
    if writefile then
        pcall(function() writefile(ConfigFile, HttpService:JSONEncode(Settings)) end)
    end
end

local function LoadSettings()
    if readfile and isfile and isfile(ConfigFile) then
        pcall(function()
            local decoded = HttpService:JSONDecode(readfile(ConfigFile))
            for k, v in pairs(decoded) do Settings[k] = v end
        end)
    end
end
LoadSettings()

local function HopServer()
    local serversVisited = {}
    if readfile and isfile and isfile(ServerFile) then
        pcall(function() serversVisited = HttpService:JSONDecode(readfile(ServerFile)) end)
    end
    
    serversVisited[game.JobId] = true
    
    local count = 0
    for _ in pairs(serversVisited) do count = count + 1 end
    if count > 100 then serversVisited = { [game.JobId] = true } end
    
    if writefile then pcall(function() writefile(ServerFile, HttpService:JSONEncode(serversVisited)) end) end

    local apiUrl = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
    local response = nil
    pcall(function() response = game:HttpGet(apiUrl) end)
    
    if response then
        local data = HttpService:JSONDecode(response)
        if data and data.data then
            for _, server in ipairs(data.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId and not serversVisited[server.id] then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                    task.wait(5) 
                end
            end
        end
    end
end

-- =========================================
-- TỐI ƯU HÓA MOBILE (FPS BOOST)
-- =========================================
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

Lighting.GlobalShadows = false
Lighting.FogEnd = 9e9
for _, v in ipairs(Workspace:GetDescendants()) do
    if v:IsA("BasePart") and not v:IsA("MeshPart") then v.Material = Enum.Material.SmoothPlastic
    elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1 end
end

-- =========================================
-- BIẾN CẤU HÌNH & THỨ TỰ ƯU TIÊN
-- =========================================
local PriorityOrder = {
    "Volcanic Egg",
    "Cherub Egg",
    "Solaris Egg",
    "Blackhole Egg"
}

local TargetEggs = {
    ["Volcanic Egg"] = Color3.fromRGB(255, 69, 0),
    ["Cherub Egg"] = Color3.fromRGB(255, 215, 0),     
    ["Solaris Egg"] = Color3.fromRGB(255, 140, 0),    
    ["Blackhole Egg"] = Color3.fromRGB(138, 43, 226)
}

local ESP_Cache = {}
local CustomBasePos = nil

-- =========================================
-- HÀM LẤY SỐ KG CỦA TRỨNG
-- =========================================
local function GetEggWeight(egg)
    -- 1. Tìm trong các object Value (NumberValue, StringValue, IntValue)
    local weightVal = egg:FindFirstChild("Weight", true) or egg:FindFirstChild("Kg", true) or egg:FindFirstChild("kg", true)
    if weightVal and (weightVal:IsA("NumberValue") or weightVal:IsA("IntValue") or weightVal:IsA("StringValue")) then
        return tostring(weightVal.Value)
    end
    
    -- 2. Tìm trong Attributes của quả trứng
    local attr = egg:GetAttribute("Weight") or egg:GetAttribute("Kg") or egg:GetAttribute("kg")
    if attr then return tostring(attr) end
    
    -- 3. Quét trong các TextLabel (những UI có sẵn gắn trên quả trứng)
    for _, v in ipairs(egg:GetDescendants()) do
        if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
            local text = string.lower(v.Text)
            if string.find(text, "kg") then
                -- Trích xuất con số ra khỏi chuỗi (VD: "Trọng lượng: 12.5 kg" -> "12.5")
                local match = string.match(text, "(%d+%.?%d*)%s*kg")
                if match then return match end
            end
        end
    end
    
    return "?" -- Không tìm thấy kg
end

-- =========================================
-- AUTO-DETECT HỆ THỐNG
-- =========================================
local function AutoDetectBase()
    local baseFolders = {"Plots", "Ranches", "Bases", "Tycoons", "Housing"}
    for _, folderName in ipairs(baseFolders) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, plot in ipairs(folder:GetChildren()) do
                local ownerVal = plot:FindFirstChild("Owner", true) or plot:FindFirstChild("Player", true)
                if ownerVal and ((ownerVal:IsA("ObjectValue") and ownerVal.Value == LocalPlayer) or 
                   (ownerVal:IsA("StringValue") and (ownerVal.Value == LocalPlayer.Name or ownerVal.Value == tostring(LocalPlayer.UserId)))) then
                    local dest = plot:FindFirstChild("Floor", true) or plot:FindFirstChild("Baseplate", true) or plot:FindFirstChildWhichIsA("BasePart", true)
                    if dest then return dest.Position end
                end
            end
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj.Name == "Owner" or obj.Name == "Player") and ((obj:IsA("ObjectValue") and obj.Value == LocalPlayer) or 
           (obj:IsA("StringValue") and (string.find(string.lower(obj.Value), string.lower(LocalPlayer.Name)) or obj.Value == tostring(LocalPlayer.UserId)))) then
            local parent = obj.Parent
            local dest = parent:FindFirstChild("Floor", true) or parent:FindFirstChild("Base", true) or parent:FindFirstChildWhichIsA("BasePart", true)
            if dest then return dest.Position end
        end
    end
    return nil
end

local function GetHighestPointAbove(eggPos, targetObj)
    local rayOrigin = Vector3.new(eggPos.X, 3000, eggPos.Z)
    local rayDirection = Vector3.new(0, -4000, 0)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, targetObj}
    
    local result = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
    if result then return result.Position + Vector3.new(0, 30, 0) end
    return eggPos + Vector3.new(0, 500, 0) 
end

-- =========================================
-- TWEEN VÀ TƯƠNG TÁC
-- =========================================
local CurrentTween = nil
local function TweenToTarget(targetPos)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local distance = (hrp.Position - targetPos).Magnitude
    local timeToTravel = distance / Settings.FlySpeed
    if timeToTravel < 0.05 then timeToTravel = 0.05 end

    if CurrentTween then CurrentTween:Cancel() end
    CurrentTween = TweenService:Create(hrp, TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
    
    local nc = RunService.Stepped:Connect(function()
        for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
        if char:FindFirstChildOfClass("Humanoid") then char:FindFirstChildOfClass("Humanoid"):ChangeState(11) end
    end)

    CurrentTween:Play()
    CurrentTween.Completed:Wait()
    if nc then nc:Disconnect() end
end

local function AutoInteract(eggModel)
    local prompt = eggModel:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        prompt.HoldDuration = 0
        local endTime = tick() + 1.0
        while tick() < endTime do
            if fireproximityprompt then pcall(function() fireproximityprompt(prompt, 0) end)
            else prompt:InputHoldBegin(); task.wait(0.05); prompt:InputHoldEnd() end
            task.wait(0.05)
        end
    end
end

-- =========================================
-- RAYFIELD UI
-- =========================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
   Name = "🥚 VIP Egg Hunter [V12]",
   LoadingTitle = "Loading V12...",
   LoadingSubtitle = "Priority & ESP KG",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false
})

local TabAuto = Window:CreateTab("Auto Farm", 4483362458)
local TabUtil = Window:CreateTab("Tiện Ích", 4483362458)

TabAuto:CreateToggle({
    Name = "✅ Farm Tất Cả Trứng (Ưu tiên)",
    CurrentValue = Settings.FarmAll,
    Callback = function(v) Settings.FarmAll = v; SaveSettings() end,
})

TabAuto:CreateDropdown({
    Name = "🎯 Chọn Trứng Lẻ",
    Options = PriorityOrder,
    CurrentOption = Settings.SelectedEggs,
    MultipleOptions = true,
    Callback = function(opt) Settings.SelectedEggs = opt; SaveSettings() end,
})

TabAuto:CreateSlider({
    Name = "🚀 Tốc Độ Bay",
    Range = {500, 10000}, Increment = 500,
    CurrentValue = Settings.FlySpeed,
    Suffix = "Studs/s",
    Callback = function(v) Settings.FlySpeed = v; SaveSettings() end,
})

TabAuto:CreateToggle({
    Name = "🔄 AUTO HOP SERVER",
    CurrentValue = Settings.AutoHop,
    Callback = function(v) Settings.AutoHop = v; SaveSettings() end,
})

local FarmToggle
FarmToggle = TabAuto:CreateToggle({
    Name = "▶ BẮT ĐẦU AUTO FARM",
    CurrentValue = Settings.AutoFarm,
    Callback = function(v)
        Settings.AutoFarm = v; SaveSettings()
        if v then
            CustomBasePos = AutoDetectBase()
            if not CustomBasePos then
                Rayfield:Notify({Title = "THIẾU BASE", Content = "Chưa tìm thấy Base!", Duration = 3})
                task.delay(0.2, function() FarmToggle:Set(false) end)
                Settings.AutoFarm = false
            end
        end
    end,
})

TabUtil:CreateButton({
    Name = "🏠 Teleport Về Base",
    Callback = function()
        local bp = AutoDetectBase()
        if bp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(bp + Vector3.new(0, 5, 0))
        end
    end,
})

TabUtil:CreateToggle({
    Name = "✅ ESP Trứng (Hiện KG)",
    CurrentValue = Settings.ESP_Enabled,
    Callback = function(v) Settings.ESP_Enabled = v; SaveSettings() end,
})

TabUtil:CreateToggle({
    Name = "🚀 Infinity Jump",
    CurrentValue = Settings.InfJump,
    Callback = function(v) Settings.InfJump = v; SaveSettings() end,
})

-- =========================================
-- LOGIC CORE (THỨ TỰ ƯU TIÊN)
-- =========================================
UserInputService.JumpRequest:Connect(function()
    if Settings.InfJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

task.spawn(function()
    task.wait(3)
    if Settings.AutoFarm and not CustomBasePos then CustomBasePos = AutoDetectBase() end

    while task.wait(0.5) do 
        if Settings.AutoFarm and CustomBasePos then
            local targetObj = nil
            local targetName = ""
            
            -- Quét trứng dựa trên danh sách ưu tiên PriorityOrder
            for _, pEgg in ipairs(PriorityOrder) do
                local canFarmThis = Settings.FarmAll
                if not canFarmThis then
                    for _, s in ipairs(Settings.SelectedEggs) do 
                        if s == pEgg then canFarmThis = true; break end 
                    end
                end
                
                if canFarmThis then
                    for obj, data in pairs(ESP_Cache) do
                        if data.Name == pEgg and obj and obj.Parent then
                            targetObj = obj
                            targetName = pEgg
                            break
                        end
                    end
                end
                
                if targetObj then break end
            end

            if targetObj then
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local eggPos = targetObj:IsA("Model") and (targetObj.PrimaryPart and targetObj.PrimaryPart.Position or targetObj:GetPivot().Position) or targetObj:IsA("BasePart") and targetObj.Position
                    
                    if eggPos then
                        -- LẤY TRỨNG THÔNG MINH
                        if targetName == "Volcanic Egg" then
                            local skyPos = GetHighestPointAbove(eggPos, targetObj)
                            hrp.CFrame = CFrame.new(skyPos)
                            task.wait(0.4)
                            TweenToTarget(eggPos + Vector3.new(0, 3, 0))
                        else
                            hrp.CFrame = CFrame.new(eggPos + Vector3.new(0, 3, 0))
                        end

                        task.wait(0.3); AutoInteract(targetObj); task.wait(0.4) 
                        
                        -- VỀ BASE
                        local safeBase = CustomBasePos + Vector3.new(0, 5, 0)
                        TweenToTarget(safeBase)
                        for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then hum:ChangeState(Enum.HumanoidStateType.Freefall) end
                        
                        task.wait(1.5)

                        if Settings.AutoHop then
                            Rayfield:Notify({Title = "AUTO HOP", Content = string.format("Đã lấy %s! Nhảy server sau 2s...", targetName), Duration = 2})
                            task.wait(2)
                            HopServer()
                        end
                    end
                end
            elseif Settings.AutoHop then
                Rayfield:Notify({Title = "AUTO HOP", Content = "Không còn trứng yêu cầu. Nhảy server sau 3s...", Duration = 3})
                task.wait(3)
                HopServer()
            end
        end
    end
end)

-- =========================================
-- HỆ THỐNG ESP 
-- =========================================
local function IsValidWildEgg(object)
    local current = object.Parent
    while current and current ~= Workspace do
        local n = string.lower(current.Name)
        if string.find(n, "base") or string.find(n, "plot") or string.find(n, "ranch") or current:FindFirstChild("Humanoid") then return false end
        current = current.Parent
    end
    return true
end

function CheckAndAddESP(object)
    if not IsValidWildEgg(object) then return end
    for exactName, color in pairs(TargetEggs) do
        if string.find(string.lower(object.Name), string.lower(exactName)) and not ESP_Cache[object] then
            ESP_Cache[object] = { Name = exactName, WeightCache = nil }
            
            if Settings.ESP_Enabled then
                local billboard = Instance.new("BillboardGui")
                billboard.Adornee = object
                -- Kéo dài width ra để đủ chỗ hiển thị thêm kg
                billboard.Size = UDim2.new(0, 300, 0, 50) 
                billboard.StudsOffset = Vector3.new(0, 3, 0)
                billboard.AlwaysOnTop = true
                billboard.Parent = SafeGui

                local label = Instance.new("TextLabel", billboard)
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.TextColor3 = color
                label.TextStrokeTransparency = 0
                label.Font = Enum.Font.SourceSansBold
                label.TextSize = 16

                local highlight = Instance.new("Highlight")
                highlight.Adornee = object
                highlight.FillColor = color
                highlight.FillTransparency = 0.4
                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                highlight.Parent = SafeGui
                
                ESP_Cache[object].Billboard = billboard
                ESP_Cache[object].Label = label
                ESP_Cache[object].Highlight = highlight
            end
            break
        end
    end
end
Workspace.DescendantAdded:Connect(function(des) task.wait(0.1); CheckAndAddESP(des) end)
Workspace.DescendantRemoving:Connect(function(des)
    if ESP_Cache[des] then
        if ESP_Cache[des].Billboard then ESP_Cache[des].Billboard:Destroy() end
        if ESP_Cache[des].Highlight then ESP_Cache[des].Highlight:Destroy() end
        ESP_Cache[des] = nil
    end
end)
for _, des in ipairs(Workspace:GetDescendants()) do CheckAndAddESP(des) end

-- Cập nhật ESP mỗi frame
RunService.RenderStepped:Connect(function()
    if not Settings.ESP_Enabled then return end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    for object, data in pairs(ESP_Cache) do
        if data.Label and object.Parent then
            local ePos = object:IsA("Model") and (object.PrimaryPart and object.PrimaryPart.Position or object:GetPivot().Position) or object:IsA("BasePart") and object.Position
            if ePos then 
                -- Tối ưu: Lấy kg 1 lần rồi cache lại để tránh giật lag khi quét TextLabel liên tục
                if not data.WeightCache then data.WeightCache = GetEggWeight(object) end
                
                data.Label.Text = string.format("🥚 %s | %s kg [%d stud]", data.Name, data.WeightCache, math.floor((hrp.Position - ePos).Magnitude)) 
            end
        end
    end
end)
