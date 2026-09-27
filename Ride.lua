--======================================================
-- Egg Stealer ScriptHub
-- Unified Live Eggs UI
--======================================================

repeat task.wait() until game:IsLoaded()

--======================================================
-- Services
--======================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer


--======================================================
-- Config
--======================================================

local Config = {
    Eggs = {
        "Blackhole Egg",
        "Cherub Egg",
        "Solaris Egg",
        "Volcanic Egg",
    },

    TweenSpeed = 1500,
    MaxTweenTime = 20,
    HoldETime = 0.50,

    AutoEgg = false,
    AntiAFK = true,

    SpeedHack = false,
    SpeedValue = 16,

    AutoBuy = {
        Lucky = false,
        Gear = false,
        Food = false,

        GearSelected = {
            "Eternal Radar",
        },

        FoodSelected = {
            "Dragonfruit",
        },

        CheckDelay = 2,
        BuyDelay = 0.15,

        -- Upgrades Remote:
        -- ReplicatedStorage.Remotes.Game.Plot.Upgrades
        LuckyArgument = "Lucky",
    },
}

local ConfigPath = "EggStealer/dashboard.json"
local function MergeConfig(target, saved)
    for key, value in pairs(saved) do
        if target[key] ~= nil and type(value) == type(target[key]) then
            if type(value) == "table" and key == "AutoBuy" then
                MergeConfig(target[key], value)
            else
                target[key] = value
            end
        end
    end
end
if type(readfile) == "function" and type(isfile) == "function" and isfile(ConfigPath) then
    pcall(function()
        MergeConfig(Config, HttpService:JSONDecode(readfile(ConfigPath)))
    end)
end

--======================================================
-- Anti AFK
--======================================================

local runtimeEnv = (getgenv and getgenv()) or _G
if runtimeEnv.HeavyEggAntiAFKConnection then
    runtimeEnv.HeavyEggAntiAFKConnection:Disconnect()
end
local function KeepActive()
    if not Config.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
    print("[EggHub] Anti AFK ทำงานแล้ว")
end
runtimeEnv.HeavyEggAntiAFKConnection = LocalPlayer.Idled:Connect(KeepActive)
local antiAfkRun = {}
runtimeEnv.HeavyEggAntiAFKRun = antiAfkRun
task.spawn(function()
    while runtimeEnv.HeavyEggAntiAFKRun == antiAfkRun do
        KeepActive() -- first action happens immediately when the script runs
        task.wait(60)
    end
end)

--======================================================
-- Lists
-- เพิ่ม/ลบชื่อได้จากรายการเหล่านี้
--======================================================

local EggList = {
        "Blackhole Egg",
        "Cherub Egg",
        "Solaris Egg",
        "Volcanic Egg",
}

-- ใส่รหัสรูปที่คัดลอกจากเกมได้ที่นี่ (ปล่อยว่างเพื่อแสดงสัญลักษณ์ไข่)
local EggImages = {
    ["Blackhole Egg"] = "", -- Render the actual egg model below.
    ["Cherub Egg"] = "",
    ["Solaris Egg"] = "",
    ["Volcanic Egg"] = "",
}

local GearList = {
    "Eternal Radar",
    "Angelic Radar",
    "Magic Radar",
    "Royal Radar",
    "Jewel Radar",
}

local FoodList = {
    "Dragonfruit",
    "Magic Apple",
    "Meat",
    "Bone",
    "Grass",
}

--======================================================
-- State
--======================================================

local CurrentTween = nil
local Busy = false
local CollectedEggs = {}
local EggHistory = {}
local function AddEggHistory(action, eggName)
    table.insert(EggHistory, 1, {time = os.date("%H:%M:%S"), action = action, name = eggName})
    if #EggHistory > 100 then table.remove(EggHistory) end
end
local CurrentEggTarget = nil
local LastCollectedEgg = nil
local LastCollectedTime = 0
local VolcanicRetryAfter = 0

--======================================================
-- Helpers
--======================================================

local function GetCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function GetHumanoidRootPart()
    local Character = GetCharacter()
    return Character:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local Character = GetCharacter()
    return Character:FindFirstChildOfClass("Humanoid")
end

local function GetEggFolder()
    return workspace:FindFirstChild("RenderedEggs")
end

local function BuildSelectedSet(List)
    local Set = {}

    for _, Name in ipairs(List or {}) do
        Set[Name] = true
    end

    return Set
end

local function BuildDropdownDefault(List)
    local Result = {}

    for _, Name in ipairs(List or {}) do
        Result[Name] = true
    end

    return Result
end

--======================================================
-- Object Position
--======================================================

local function GetObjectPosition(Object)
    if not Object then
        return nil
    end

    if Object:IsA("BasePart") then
        return Object.Position
    end

    if Object:IsA("Model") then
        if Object.PrimaryPart then
            return Object.PrimaryPart.Position
        end

        local Part = Object:FindFirstChildWhichIsA("BasePart", true)

        if Part then
            return Part.Position
        end
    end

    return nil
end

--======================================================
-- Find selected Egg
--======================================================

local function FindEnabledEgg()
    local Folder = GetEggFolder()

    if not Folder then
        return nil, nil
    end

    local Selected = BuildSelectedSet(Config.Eggs)
    local BestEgg = nil
    local BestPosition = nil
    local BestDistance = math.huge
    local HRP = GetHumanoidRootPart()

    for _, Egg in ipairs(Folder:GetChildren()) do
        if Selected[Egg.Name]
            and (Egg.Name ~= "Volcanic Egg" or tick() >= VolcanicRetryAfter) then
            -- อย่าเลือกเป้าหมายเดิมซ้ำทันที ขณะรอเซิร์ฟเวอร์อัปเดต
            if Egg ~= CurrentEggTarget then
                local Position = GetObjectPosition(Egg)

                if Position then
                    local Distance = HRP and (HRP.Position - Position).Magnitude or 0

                    if Distance < BestDistance then
                        BestDistance = Distance
                        BestEgg = Egg
                        BestPosition = Position
                    end
                end
            end
        end
    end

    return BestEgg, BestPosition
end

local function WaitForEggUpdate(Egg, Timeout)
    if not Egg then
        return true
    end

    local Start = tick()
    Timeout = Timeout or 3

    while tick() - Start < Timeout do
        -- ไข่ถูกลบออกจาก RenderedEggs
        if not Egg.Parent then
            return true
        end

        -- ไข่ถูกย้ายออกจากโฟลเดอร์เดิม
        if Egg.Parent ~= GetEggFolder() then
            return true
        end

        task.wait(0.10)
    end

    return false
end

--======================================================
-- Home
--======================================================

-- ใช้ workspace.Plots:GetChildren()[6].Data.Owner เป็นรูปแบบอ้างอิง
-- แต่ไม่ล็อก Plot[6] ถาวร: ถ้า index เปลี่ยนหลังรีเกม
-- จะค้น Plot ทุกตัวที่ Data.Owner เป็น LocalPlayer

local function GetOwnerValue(Data)
    if not Data then
        return nil
    end

    local Owner = Data:FindFirstChild("Owner")
    if not Owner then
        return nil
    end

    if Owner:IsA("ObjectValue") then
        return Owner.Value
    end

    if Owner:IsA("StringValue")
        or Owner:IsA("IntValue")
        or Owner:IsA("NumberValue") then
        return Owner.Value
    end

    return nil
end

local function IsMyOwner(Value)
    if Value == nil then
        return false
    end

    if Value == LocalPlayer then
        return true
    end

    if typeof(Value) == "Instance" and Value:IsA("Player") then
        return Value == LocalPlayer
    end

    local V = tostring(Value)

    return V == tostring(LocalPlayer.UserId)
        or V == LocalPlayer.Name
end

local function PlotBelongsToMe(Plot)
    if not Plot then
        return false
    end

    local Data = Plot:FindFirstChild("Data")
    if not Data then
        return false
    end

    return IsMyOwner(GetOwnerValue(Data))
end

local function FindMyPlot()
    local Plots = workspace:FindFirstChild("Plots")

    if not Plots then
        warn("[EggHub] ไม่พบ workspace.Plots")
        return nil
    end

    local PlotList = Plots:GetChildren()

    -- ตรวจ Plot[6] ก่อน ตาม path ที่ผู้ใช้ให้มา
    local Plot6 = PlotList[6]

    if Plot6 and PlotBelongsToMe(Plot6) then
        print(
            "[EggHub] My Plot:",
            Plot6:GetFullName(),
            "(matched Plot[6].Data.Owner)"
        )
        return Plot6
    end

    -- ถ้า Plot[6] ไม่ใช่ของเรา ให้ค้นทุก Plot
    for Index, Plot in ipairs(PlotList) do
        if PlotBelongsToMe(Plot) then
            print(
                "[EggHub] My Plot:",
                Plot:GetFullName(),
                "| Index:",
                Index
            )
            return Plot
        end
    end

    return nil
end

local function GetHomePosition()
    local MyPlot = FindMyPlot()

    if not MyPlot then
        warn("[EggHub] ยังหา Plot ของตัวเองไม่พบ")
        return nil
    end

    local Baseplate = MyPlot:FindFirstChild("Baseplate", true)

    if not Baseplate then
        warn(
            "[EggHub] ไม่พบ Baseplate ใน My Plot:",
            MyPlot:GetFullName()
        )
        return nil
    end

    return GetObjectPosition(Baseplate)
end

--======================================================
-- Tween
--======================================================

local function StopTween()
    if CurrentTween then
        pcall(function()
            CurrentTween:Cancel()
        end)

        CurrentTween = nil
    end
end

local function TweenTo(TargetPosition, ForceMaxTime)

    local HRP = GetHumanoidRootPart()

    if not HRP or not TargetPosition then
        return false
    end

    StopTween()

    local Distance = (HRP.Position - TargetPosition).Magnitude

    -- เดินทางไปหาไข่ให้เร็วที่สุด
    -- กลับบ้านจะใช้เวลาสูงสุดไม่เกิน Config.MaxTweenTime
    local Speed = math.max(Config.TweenSpeed, 1)

    local Duration

    if ForceMaxTime then
        -- ให้ระยะทางทั้งหมดจบภายใน <= 20 วินาที
        Duration = math.min(
            Distance / Speed,
            Config.MaxTweenTime
        )

        -- ถ้าระยะไกลมาก ให้เร่งความเร็วเพิ่มอัตโนมัติ
        if Distance > 0 and Duration >= Config.MaxTweenTime then
            Duration = Config.MaxTweenTime
        end

    else
        -- ไปหาไข่เร็วที่สุดที่ตั้งไว้
        Duration = math.max(
            Distance / Speed,
            0.01
        )
    end

    CurrentTween = TweenService:Create(
        HRP,
        TweenInfo.new(
            Duration,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.Out
        ),
        {
            CFrame = CFrame.new(
                TargetPosition + Vector3.new(0, 3, 0)
            )
        }
    )

    local Finished = false

    CurrentTween.Completed:Connect(function()
        Finished = true
    end)

    CurrentTween:Play()

    local StartTime = tick()
    local TimeLimit = ForceMaxTime
        and (Config.MaxTweenTime + 0.5)
        or math.max(Duration + 0.5, 2)

    while not Finished do

        if tick() - StartTime >= TimeLimit then

            StopTween()

            break
        end

        task.wait()
    end

    CurrentTween = nil

    -- ถ้าปิด Auto Egg ระหว่าง Tween ให้ถือว่าเป็นการยกเลิก
    if not Config.AutoEgg and not ForceMaxTime then
        return false
    end

    return true
end

local function GetEggTopPosition(egg)
    if egg:IsA("BasePart") then
        return egg.Position + Vector3.new(0, egg.Size.Y / 2, 0)
    end
    if egg:IsA("Model") then
        local ok, box, size = pcall(function() return egg:GetBoundingBox() end)
        if ok then return box.Position + Vector3.new(0, size.Y / 2, 0) end
    end
    return GetObjectPosition(egg)
end

local function TweenToVolcanicEgg(egg, testRoute)
    if not Config.AutoEgg or (not testRoute and (not egg or egg.Name ~= "Volcanic Egg")) then return false end
    local folder = GetEggFolder()
    if not testRoute and (not folder or egg.Parent ~= folder) then
        warn("[Volcanic] ยังไม่มีไข่จริงใน RenderedEggs")
        return false
    end
    -- เส้นทาง HRP ที่บันทึกจากการเดินจริง: รักษาลำดับช่วงลงช่องทั้งสองจุด
    local route = {
        Vector3.new(-4968.151, 41275.250, -3649.905), -- 1
        Vector3.new(-4970.450, 41275.250, -3645.799), -- 2
        Vector3.new(-4972.460, 41275.250, -3642.246), -- 3
        Vector3.new(-4974.511, 41275.152, -3638.621), -- 4
        Vector3.new(-4976.526, 41275.152, -3635.071), -- 5
        Vector3.new(-4978.552, 41275.152, -3631.433), -- 6
        Vector3.new(-4980.554, 41275.078, -3627.876), -- 7
        Vector3.new(-4982.564, 41275.078, -3624.323), -- 8
        Vector3.new(-4984.615, 41275.078, -3620.698), -- 9
        Vector3.new(-4986.627, 41275.090, -3617.146), -- 10
        Vector3.new(-4988.723, 41274.164, -3613.619), -- 11
        Vector3.new(-4990.789, 41273.082, -3610.157), -- 12
        Vector3.new(-4992.913, 41272.707, -3606.592), -- 13
        Vector3.new(-4994.995, 41272.340, -3603.099), -- 14
        Vector3.new(-4997.119, 41271.965, -3599.535), -- 15
        Vector3.new(-4999.200, 41271.598, -3596.042), -- 16
        Vector3.new(-5001.297, 41271.230, -3592.560), -- 17
        Vector3.new(-5003.465, 41270.871, -3589.023), -- 18
        Vector3.new(-5005.565, 41270.629, -3585.434), -- 19
        Vector3.new(-5007.661, 41270.398, -3581.937), -- 20
        Vector3.new(-5009.833, 41270.250, -3578.386), -- 21
        Vector3.new(-5011.712, 41268.379, -3575.298), -- 22
        Vector3.new(-5012.621, 41264.441, -3573.809), -- 23
        Vector3.new(-5014.702, 41263.148, -3570.399), -- 24
        Vector3.new(-5016.796, 41262.305, -3566.996), -- 25
        Vector3.new(-5018.799, 41261.418, -3563.445), -- 26
        Vector3.new(-5020.786, 41260.559, -3559.980), -- 27
        Vector3.new(-5022.855, 41259.699, -3556.472), -- 28
        Vector3.new(-5024.885, 41258.848, -3553.036), -- 29
        Vector3.new(-5026.372, 41257.938, -3549.357), -- 30
        Vector3.new(-5026.723, 41254.859, -3545.287), -- 31
        Vector3.new(-5024.884, 41254.031, -3541.369), -- 32
        Vector3.new(-5023.702, 41254.039, -3537.375), -- 33
        Vector3.new(-5023.093, 41254.047, -3533.277), -- 34
        Vector3.new(-5025.312, 41254.070, -3530.025), -- 35
        Vector3.new(-5028.730, 41254.078, -3527.640), -- 36
        Vector3.new(-5032.073, 41254.246, -3525.317), -- 37
        Vector3.new(-5035.530, 41254.656, -3523.027), -- 38
        Vector3.new(-5038.651, 41254.867, -3520.530), -- 39
        Vector3.new(-5042.248, 41254.914, -3518.424), -- 40
        Vector3.new(-5046.249, 41254.875, -3518.303), -- 41
        Vector3.new(-5050.482, 41254.613, -3518.144), -- 42
        Vector3.new(-5054.537, 41254.195, -3518.020), -- 43
        Vector3.new(-5058.712, 41254.195, -3517.879), -- 44
        Vector3.new(-5062.758, 41254.199, -3518.403), -- 45
        Vector3.new(-5066.890, 41254.215, -3518.865), -- 46
        Vector3.new(-5070.967, 41254.227, -3518.869), -- 47
        Vector3.new(-5075.034, 41254.062, -3518.680), -- 48
        Vector3.new(-5079.005, 41253.906, -3517.877), -- 49
        Vector3.new(-5081.813, 41253.977, -3514.935), -- 50
        Vector3.new(-5085.366, 41254.043, -3512.978), -- 51
        Vector3.new(-5089.472, 41253.965, -3513.580), -- 52
        Vector3.new(-5092.004, 41252.043, -3514.030), -- 53
        Vector3.new(-5092.533, 41249.578, -3514.017), -- 54
        Vector3.new(-5093.160, 41247.172, -3513.928), -- 55
        Vector3.new(-5093.762, 41245.289, -3513.842), -- 56
        Vector3.new(-5094.380, 41243.434, -3513.757), -- 57
        Vector3.new(-5095.349, 41240.414, -3513.621), -- 58
        Vector3.new(-5096.259, 41236.609, -3513.493), -- 59
        Vector3.new(-5096.438, 41234.105, -3513.468), -- 60
        Vector3.new(-5096.692, 41231.176, -3513.430), -- 61
        Vector3.new(-5096.933, 41228.480, -3513.394), -- 62
        Vector3.new(-5097.817, 41223.281, -3513.298), -- 63
        Vector3.new(-5099.739, 41215.207, -3513.167), -- 64
        Vector3.new(-5101.731, 41204.906, -3513.079), -- 65
        Vector3.new(-5103.806, 41191.520, -3512.983), -- 66
        Vector3.new(-5105.964, 41174.715, -3512.881), -- 67
        Vector3.new(-5108.123, 41156.148, -3512.781), -- 68
        Vector3.new(-5111.124, 41156.559, -3515.040), -- 69
        Vector3.new(-5112.260, 41156.559, -3519.049), -- 70
        Vector3.new(-5113.548, 41156.566, -3522.835), -- 71
        Vector3.new(-5115.180, 41156.570, -3526.752), -- 72
        Vector3.new(-5117.370, 41156.574, -3530.392), -- 73
        Vector3.new(-5119.544, 41156.590, -3533.747), -- 74
        Vector3.new(-5121.774, 41156.570, -3537.271), -- 75
        Vector3.new(-5124.026, 41156.570, -3540.778), -- 76
        Vector3.new(-5126.451, 41156.570, -3544.062), -- 77
        Vector3.new(-5126.744, 41156.578, -3547.964), -- 78
        Vector3.new(-5129.415, 41156.141, -3550.698), -- 79
        Vector3.new(-5130.028, 41153.727, -3551.308), -- 80
        Vector3.new(-5130.181, 41152.109, -3551.763), -- 81
        Vector3.new(-5130.974, 41149.688, -3552.559), -- 82
        Vector3.new(-5133.774, 41148.273, -3555.370), -- 83
        Vector3.new(-5136.724, 41147.801, -3558.280), -- 84
        Vector3.new(-5139.958, 41147.262, -3560.840), -- 85
        Vector3.new(-5143.391, 41146.719, -3562.979), -- 86
        Vector3.new(-5145.505, 41146.367, -3566.060), -- 87
        Vector3.new(-5149.218, 41145.758, -3567.842), -- 88
        Vector3.new(-5151.958, 41145.316, -3570.627), -- 89
        Vector3.new(-5155.933, 41144.715, -3571.313), -- 90
        Vector3.new(-5159.954, 41144.070, -3571.635), -- 91
        Vector3.new(-5164.081, 41142.535, -3571.608), -- 92
        Vector3.new(-5167.520, 41142.031, -3573.661), -- 93
        Vector3.new(-5171.600, 41142.031, -3574.424), -- 94
        Vector3.new(-5175.743, 41142.031, -3574.245), -- 95
        Vector3.new(-5179.610, 41142.031, -3573.226), -- 96
        Vector3.new(-5183.545, 41142.031, -3573.542), -- 97
        Vector3.new(-5187.533, 41142.031, -3573.288), -- 98
        Vector3.new(-5191.625, 41142.031, -3573.270), -- 99
        Vector3.new(-5195.504, 41142.031, -3572.608), -- 100
        Vector3.new(-5199.618, 41142.031, -3572.339), -- 101
        Vector3.new(-5203.686, 41142.031, -3572.525), -- 102
        Vector3.new(-5207.377, 41142.031, -3573.419), -- 103
        Vector3.new(-5211.162, 41142.031, -3575.131), -- 104
        Vector3.new(-5215.086, 41141.863, -3576.306), -- 105
        Vector3.new(-5217.569, 41138.730, -3576.972), -- 106
        Vector3.new(-5221.624, 41138.816, -3577.922), -- 107
        Vector3.new(-5225.701, 41138.852, -3578.769), -- 108
        Vector3.new(-5229.696, 41138.891, -3579.559), -- 109
        Vector3.new(-5233.716, 41138.934, -3580.252), -- 110
        Vector3.new(-5237.865, 41138.973, -3580.624), -- 111
        Vector3.new(-5241.923, 41138.664, -3580.799), -- 112
        Vector3.new(-5246.098, 41138.762, -3580.726), -- 113
        Vector3.new(-5250.165, 41138.918, -3580.572), -- 114
        Vector3.new(-5254.310, 41138.984, -3580.173), -- 115
        Vector3.new(-5258.317, 41138.977, -3579.473), -- 116
        Vector3.new(-5259.635, 41137.273, -3579.242), -- 117
        Vector3.new(-5259.878, 41133.090, -3579.200), -- 118
        Vector3.new(-5259.878, 41126.066, -3579.200), -- 119
        Vector3.new(-5259.878, 41116.332, -3579.200), -- 120
        Vector3.new(-5259.878, 41103.887, -3579.200), -- 121
        Vector3.new(-5259.878, 41089.391, -3579.200), -- 122
        Vector3.new(-5259.878, 41070.859, -3579.200), -- 123
        Vector3.new(-5259.878, 41050.273, -3579.200), -- 124
        Vector3.new(-5259.878, 41042.176, -3579.200), -- 125
        Vector3.new(-5261.732, 41042.305, -3583.219), -- 126
        Vector3.new(-5263.150, 41042.223, -3587.043), -- 127
        Vector3.new(-5264.553, 41042.125, -3590.965), -- 128
        Vector3.new(-5265.879, 41042.039, -3594.824), -- 129
        Vector3.new(-5266.230, 41041.969, -3598.966), -- 130
        Vector3.new(-5266.366, 41041.906, -3603.045), -- 131
        Vector3.new(-5266.496, 41041.828, -3607.125), -- 132
        Vector3.new(-5266.447, 41041.762, -3611.287), -- 133
        Vector3.new(-5265.967, 41041.703, -3615.335), -- 134
        Vector3.new(-5264.376, 41041.672, -3619.180), -- 135
        Vector3.new(-5262.572, 41041.656, -3623.028), -- 136
        Vector3.new(-5260.235, 41041.586, -3626.463), -- 137
        Vector3.new(-5256.889, 41041.500, -3628.777), -- 138
        Vector3.new(-5253.414, 41039.535, -3630.795), -- 139
        Vector3.new(-5251.572, 41035.000, -3631.754), -- 140
        Vector3.new(-5249.712, 41028.473, -3632.690), -- 141
        Vector3.new(-5246.008, 41028.730, -3634.390), -- 142
        Vector3.new(-5241.958, 41028.703, -3635.361), -- 143
        Vector3.new(-5237.963, 41028.688, -3636.244), -- 144
        Vector3.new(-5233.910, 41028.672, -3636.705), -- 145
        Vector3.new(-5229.760, 41028.664, -3637.035), -- 146
        Vector3.new(-5225.604, 41028.664, -3637.304), -- 147
        Vector3.new(-5221.430, 41028.684, -3637.377), -- 148
        Vector3.new(-5217.286, 41028.488, -3637.463), -- 149
        Vector3.new(-5215.291, 41026.355, -3637.500), -- 150
        Vector3.new(-5211.137, 41026.547, -3637.585), -- 151
        Vector3.new(-5206.975, 41026.730, -3637.644), -- 152
        Vector3.new(-5202.811, 41026.891, -3637.562), -- 153
        Vector3.new(-5198.578, 41027.047, -3637.362), -- 154
        Vector3.new(-5194.451, 41027.172, -3636.774), -- 155
        Vector3.new(-5190.506, 41027.270, -3635.808), -- 156
        Vector3.new(-5186.803, 41027.277, -3633.719), -- 157
        Vector3.new(-5183.346, 41027.277, -3631.255), -- 158
        Vector3.new(-5180.220, 41027.238, -3628.378), -- 159
        Vector3.new(-5177.046, 41027.160, -3625.433), -- 160
        Vector3.new(-5173.971, 41027.113, -3622.613), -- 161
        Vector3.new(-5170.706, 41026.945, -3619.643), -- 162
        Vector3.new(-5167.911, 41026.328, -3616.630), -- 163
        Vector3.new(-5165.118, 41025.910, -3613.483), -- 164
        Vector3.new(-5162.300, 41025.879, -3610.195), -- 165
        Vector3.new(-5159.692, 41025.855, -3606.747), -- 166
        Vector3.new(-5157.404, 41025.824, -3603.067), -- 167
        Vector3.new(-5155.044, 41025.793, -3599.528), -- 168
        Vector3.new(-5152.644, 41025.762, -3595.917), -- 169
        Vector3.new(-5150.491, 41025.738, -3592.155), -- 170
        Vector3.new(-5148.557, 41026.199, -3588.472), -- 171
        Vector3.new(-5146.720, 41026.191, -3584.728), -- 172
        Vector3.new(-5144.988, 41026.156, -3580.939), -- 173
        Vector3.new(-5143.455, 41026.125, -3577.065), -- 174
        Vector3.new(-5141.881, 41026.094, -3573.028), -- 175
        Vector3.new(-5140.307, 41026.062, -3568.990), -- 176
        Vector3.new(-5138.793, 41026.039, -3565.109), -- 177
        Vector3.new(-5137.279, 41026.039, -3561.227), -- 178
        Vector3.new(-5135.525, 41026.016, -3557.261), -- 179
        Vector3.new(-5133.722, 41025.992, -3553.313), -- 180
        Vector3.new(-5131.968, 41025.969, -3549.529), -- 181
        Vector3.new(-5130.171, 41025.938, -3545.770), -- 182
        Vector3.new(-5128.244, 41025.906, -3541.988), -- 183
        Vector3.new(-5125.911, 41025.875, -3538.438), -- 184
        Vector3.new(-5123.274, 41025.824, -3534.786), -- 185
        Vector3.new(-5120.784, 41025.801, -3531.337), -- 186
        Vector3.new(-5118.294, 41025.762, -3527.888), -- 187
        Vector3.new(-5115.853, 41025.730, -3524.509), -- 188
        Vector3.new(-5113.331, 41025.793, -3521.090), -- 189
        Vector3.new(-5110.550, 41025.906, -3518.104), -- 190
        Vector3.new(-5107.393, 41026.012, -3515.134), -- 191
        Vector3.new(-5104.402, 41026.125, -3512.346), -- 192
        Vector3.new(-5101.289, 41026.230, -3509.445), -- 193
        Vector3.new(-5098.115, 41026.352, -3506.487), -- 194
        Vector3.new(-5094.941, 41026.461, -3503.529), -- 195
        Vector3.new(-5091.890, 41026.570, -3500.685), -- 196
        Vector3.new(-5088.716, 41026.676, -3497.727), -- 197
        Vector3.new(-5085.603, 41026.785, -3494.826), -- 198
        Vector3.new(-5082.515, 41027.113, -3491.949), -- 199
        Vector3.new(-5079.417, 41028.027, -3489.067), -- 200
        Vector3.new(-5076.499, 41028.887, -3486.352), -- 201
        Vector3.new(-5073.454, 41029.785, -3483.653), -- 202
        Vector3.new(-5070.232, 41030.703, -3481.184), -- 203
        Vector3.new(-5068.402, 41031.453, -3477.626), -- 204
        Vector3.new(-5067.650, 41031.906, -3473.642), -- 205
        Vector3.new(-5066.878, 41032.387, -3469.496), -- 206
        Vector3.new(-5066.506, 41036.340, -3467.540), -- 207
        Vector3.new(-5066.054, 41041.848, -3465.420), -- 208
        Vector3.new(-5065.575, 41044.379, -3463.393), -- 209
        Vector3.new(-5063.868, 41041.293, -3459.636), -- 210
        Vector3.new(-5062.424, 41039.508, -3458.024), -- 211
        Vector3.new(-5059.198, 41039.410, -3455.421), -- 212
        Vector3.new(-5055.600, 41039.676, -3453.340), -- 213
        Vector3.new(-5051.865, 41039.945, -3451.335), -- 214
        Vector3.new(-5048.125, 41040.336, -3449.359), -- 215
        Vector3.new(-5044.439, 41040.594, -3447.435), -- 216
        Vector3.new(-5040.604, 41040.766, -3445.444), -- 217
        Vector3.new(-5036.824, 41041.039, -3443.355), -- 218
        Vector3.new(-5033.588, 41041.297, -3440.750), -- 219
        Vector3.new(-5030.523, 41041.539, -3437.815), -- 220
        Vector3.new(-5027.414, 41041.793, -3434.806), -- 221
        Vector3.new(-5024.475, 41042.199, -3431.760), -- 222
        Vector3.new(-5021.399, 41042.496, -3428.735), -- 223
        Vector3.new(-5018.225, 41042.887, -3426.106), -- 224
        Vector3.new(-5014.942, 41040.723, -3424.160), -- 225
        Vector3.new(-5011.175, 41040.723, -3422.194), -- 226
        Vector3.new(-5007.755, 41040.723, -3420.274), -- 227
        Vector3.new(-5003.583, 41040.723, -3420.247), -- 228
        Vector3.new(-4999.451, 41040.727, -3419.729), -- 229
        Vector3.new(-4995.325, 41040.730, -3419.156), -- 230
        Vector3.new(-4991.111, 41040.746, -3418.610), -- 231
        Vector3.new(-4986.960, 41040.746, -3418.186), -- 232
        Vector3.new(-4982.727, 41040.750, -3417.929), -- 233
        Vector3.new(-4978.481, 41040.758, -3417.779), -- 234
        Vector3.new(-4974.155, 41040.691, -3417.924), -- 235
        Vector3.new(-4970.087, 41040.691, -3418.206), -- 236
        Vector3.new(-4965.854, 41040.691, -3418.579), -- 237
        Vector3.new(-4961.621, 41040.691, -3418.968), -- 238
        Vector3.new(-4957.557, 41040.715, -3419.438), -- 239
        Vector3.new(-4953.406, 41040.730, -3419.850), -- 240
        Vector3.new(-4949.329, 41040.641, -3420.214), -- 241
        Vector3.new(-4947.863, 41038.723, -3420.337), -- 242
        Vector3.new(-4945.976, 41034.066, -3420.499), -- 243
        Vector3.new(-4944.005, 41027.047, -3420.667), -- 244
        Vector3.new(-4940.100, 41025.953, -3421.018), -- 245
        Vector3.new(-4936.298, 41024.516, -3421.921), -- 246
        Vector3.new(-4932.623, 41023.078, -3422.998), -- 247
        Vector3.new(-4928.962, 41021.641, -3424.087), -- 248
        Vector3.new(-4925.227, 41020.195, -3425.198), -- 249
        Vector3.new(-4921.565, 41018.785, -3426.289), -- 250
        Vector3.new(-4917.912, 41017.348, -3427.676), -- 251
        Vector3.new(-4914.443, 41015.926, -3429.306), -- 252
        Vector3.new(-4910.903, 41014.480, -3430.957), -- 253
        Vector3.new(-4907.492, 41013.004, -3432.700), -- 254
        Vector3.new(-4904.275, 41011.605, -3434.945), -- 255
        Vector3.new(-4901.272, 41010.457, -3437.347), -- 256
        Vector3.new(-4898.568, 41005.816, -3440.123), -- 257
        Vector3.new(-4897.507, 40999.523, -3441.915), -- 258
        Vector3.new(-4896.595, 40992.652, -3443.711), -- 259
        Vector3.new(-4895.060, 40991.520, -3447.221), -- 260
        Vector3.new(-4894.215, 40990.113, -3451.048), -- 261
        Vector3.new(-4893.740, 40988.828, -3454.896), -- 262
        Vector3.new(-4893.300, 40987.539, -3458.830), -- 263
        Vector3.new(-4893.563, 40986.383, -3462.740), -- 264
        Vector3.new(-4893.979, 40985.258, -3466.719), -- 265
        Vector3.new(-4894.404, 40984.105, -3470.620), -- 266
        Vector3.new(-4894.858, 40982.957, -3474.608), -- 267
        Vector3.new(-4895.326, 40981.855, -3478.508), -- 268
        Vector3.new(-4895.943, 40980.789, -3482.397), -- 269
        Vector3.new(-4896.625, 40979.707, -3486.359), -- 270
        Vector3.new(-4897.460, 40978.562, -3489.787), -- 271
        Vector3.new(-4897.489, 40975.820, -3489.874), -- 272
        Vector3.new(-4897.854, 40971.793, -3490.903), -- 273
        Vector3.new(-4899.261, 40971.660, -3494.809), -- 274
        Vector3.new(-4900.696, 40971.273, -3498.705), -- 275
        Vector3.new(-4902.725, 40971.023, -3502.224), -- 276
        Vector3.new(-4905.189, 40970.789, -3505.582), -- 277
        Vector3.new(-4907.332, 40970.535, -3509.137), -- 278
        Vector3.new(-4909.236, 40970.246, -3512.823), -- 279
        Vector3.new(-4911.090, 40969.957, -3516.445), -- 280
        Vector3.new(-4912.915, 40969.660, -3520.081), -- 281
        Vector3.new(-4914.770, 40969.367, -3523.792), -- 282
        Vector3.new(-4916.588, 40969.035, -3527.428), -- 283
        Vector3.new(-4918.407, 40968.746, -3531.065), -- 284
        Vector3.new(-4920.338, 40968.461, -3534.744), -- 285
        Vector3.new(-4922.522, 40968.207, -3538.281), -- 286
        Vector3.new(-4924.806, 40967.961, -3541.657), -- 287
        Vector3.new(-4927.276, 40967.688, -3545.000), -- 288
        Vector3.new(-4929.304, 40964.988, -3547.643), -- 289
        Vector3.new(-4930.474, 40962.590, -3549.120), -- 290
        Vector3.new(-4932.818, 40960.562, -3552.006), -- 291
        Vector3.new(-4935.324, 40958.922, -3555.022), -- 292
        Vector3.new(-4937.932, 40958.363, -3558.107), -- 293
        Vector3.new(-4940.617, 40957.988, -3561.281), -- 294
        Vector3.new(-4943.249, 40957.621, -3564.392), -- 295
        Vector3.new(-4945.914, 40957.262, -3567.467), -- 296
        Vector3.new(-4948.750, 40956.891, -3570.498), -- 297
        Vector3.new(-4951.675, 40956.547, -3573.327), -- 298
        Vector3.new(-4954.681, 40956.191, -3576.188), -- 299
        Vector3.new(-4957.258, 40955.789, -3579.329), -- 300
        Vector3.new(-4959.440, 40953.453, -3582.521), -- 301
        Vector3.new(-4961.187, 40951.066, -3585.387), -- 302
        Vector3.new(-4963.139, 40949.324, -3588.483), -- 303
        Vector3.new(-4964.429, 40946.203, -3590.428), -- 304
        Vector3.new(-4964.821, 40944.270, -3590.980), -- 305
        Vector3.new(-4965.723, 40941.594, -3592.204), -- 306
        Vector3.new(-4967.948, 40939.855, -3595.205), -- 307
        Vector3.new(-4970.335, 40938.195, -3598.186), -- 308
        Vector3.new(-4972.790, 40936.578, -3601.019), -- 309
        Vector3.new(-4975.243, 40934.922, -3603.948), -- 310
        Vector3.new(-4977.567, 40933.297, -3606.885), -- 311
        Vector3.new(-4979.888, 40931.641, -3609.828), -- 312
        Vector3.new(-4982.304, 40929.957, -3612.881), -- 313
        Vector3.new(-4984.759, 40928.406, -3615.864), -- 314
        Vector3.new(-4987.355, 40927.965, -3618.982), -- 315
        Vector3.new(-4990.131, 40927.488, -3622.049), -- 316
        Vector3.new(-4992.928, 40927.062, -3624.988), -- 317
        Vector3.new(-4995.785, 40926.688, -3627.991), -- 318
        Vector3.new(-4998.628, 40926.375, -3630.895), -- 319
        Vector3.new(-5001.643, 40926.070, -3633.624), -- 320
        Vector3.new(-5004.658, 40925.773, -3636.351), -- 321
        Vector3.new(-5007.672, 40925.449, -3639.079), -- 322
        Vector3.new(-5010.749, 40925.121, -3641.862), -- 323
        Vector3.new(-5013.640, 40924.801, -3644.478), -- 324
        Vector3.new(-5016.716, 40924.367, -3647.261), -- 325
        Vector3.new(-5019.743, 40919.008, -3649.995), -- 326
        Vector3.new(-5021.293, 40915.156, -3651.387), -- 327
        Vector3.new(-5024.359, 40915.281, -3654.085), -- 328
        Vector3.new(-5027.663, 40915.273, -3656.619), -- 329
        Vector3.new(-5031.143, 40915.203, -3658.748), -- 330
        Vector3.new(-5035.082, 40915.137, -3660.094), -- 331
        Vector3.new(-5038.981, 40915.074, -3661.294), -- 332
        Vector3.new(-5042.961, 40915.113, -3662.510), -- 333
        Vector3.new(-5046.886, 40915.344, -3663.602), -- 334
        Vector3.new(-5050.833, 40915.332, -3664.630), -- 335
        Vector3.new(-5054.862, 40915.320, -3665.693), -- 336
        Vector3.new(-5058.876, 40915.312, -3666.794), -- 337
        Vector3.new(-5062.800, 40915.301, -3667.883), -- 338
        Vector3.new(-5066.908, 40915.289, -3668.990), -- 339
        Vector3.new(-5070.855, 40915.277, -3670.029), -- 340
        Vector3.new(-5074.901, 40915.266, -3671.047), -- 341
        Vector3.new(-5078.954, 40915.250, -3672.060), -- 342
        Vector3.new(-5082.925, 40915.238, -3673.053), -- 343
        Vector3.new(-5086.897, 40915.227, -3674.046), -- 344
        Vector3.new(-5090.950, 40915.207, -3675.059), -- 345
        Vector3.new(-5094.929, 40915.188, -3675.983), -- 346
        Vector3.new(-5099.035, 40915.117, -3676.700), -- 347
        Vector3.new(-5103.078, 40915.066, -3677.304), -- 348
        Vector3.new(-5106.707, 40913.719, -3677.694), -- 349
        Vector3.new(-5108.601, 40911.848, -3677.841), -- 350
        Vector3.new(-5112.769, 40911.902, -3677.997), -- 351
        Vector3.new(-5116.943, 40911.902, -3677.973), -- 352
        Vector3.new(-5121.028, 40911.840, -3677.865), -- 353
        Vector3.new(-5125.213, 40911.836, -3677.708), -- 354
        Vector3.new(-5127.361, 40908.199, -3677.651), -- 355
        Vector3.new(-5131.512, 40908.000, -3677.551), -- 356
        Vector3.new(-5135.570, 40907.500, -3677.445), -- 357
        Vector3.new(-5139.685, 40906.445, -3677.433), -- 358
        Vector3.new(-5143.728, 40905.926, -3677.390), -- 359
        Vector3.new(-5147.854, 40905.418, -3677.257), -- 360
        Vector3.new(-5151.876, 40904.922, -3676.783), -- 361
        Vector3.new(-5156.035, 40904.422, -3675.999), -- 362
        Vector3.new(-5159.949, 40903.938, -3675.261), -- 363
        Vector3.new(-5164.013, 40903.449, -3674.482), -- 364
        Vector3.new(-5167.984, 40902.953, -3673.704), -- 365
        Vector3.new(-5172.037, 40902.457, -3672.844), -- 366
        Vector3.new(-5175.995, 40901.980, -3671.956), -- 367
        Vector3.new(-5179.928, 40901.512, -3670.992), -- 368
        Vector3.new(-5183.878, 40901.043, -3669.771), -- 369
        Vector3.new(-5187.707, 40900.582, -3668.456), -- 370
        Vector3.new(-5191.535, 40900.121, -3667.140), -- 371
        Vector3.new(-5195.285, 40899.668, -3665.851), -- 372
        Vector3.new(-5199.136, 40899.426, -3664.529), -- 373
        Vector3.new(-5202.923, 40898.961, -3663.074), -- 374
        Vector3.new(-5206.466, 40898.422, -3660.959), -- 375
        Vector3.new(-5209.921, 40898.035, -3658.815), -- 376
        Vector3.new(-5213.418, 40898.004, -3656.564), -- 377
        Vector3.new(-5216.776, 40898.352, -3654.265), -- 378
        Vector3.new(-5220.123, 40898.707, -3651.810), -- 379
        Vector3.new(-5223.357, 40899.059, -3649.340), -- 380
        Vector3.new(-5226.525, 40899.414, -3646.788), -- 381
        Vector3.new(-5229.685, 40899.777, -3644.094), -- 382
        Vector3.new(-5232.814, 40900.148, -3641.365), -- 383
        Vector3.new(-5235.853, 40900.508, -3638.658), -- 384
        Vector3.new(-5238.892, 40900.867, -3635.943), -- 385
        Vector3.new(-5241.992, 40901.066, -3633.172), -- 386
        Vector3.new(-5245.020, 40900.660, -3630.467), -- 387
        Vector3.new(-5248.172, 40900.332, -3627.922), -- 388
        Vector3.new(-5251.794, 40900.332, -3625.867), -- 389
        Vector3.new(-5255.154, 40898.672, -3624.127), -- 390
        Vector3.new(-5258.708, 40897.465, -3622.225), -- 391
        Vector3.new(-5261.999, 40895.594, -3620.363), -- 392
        Vector3.new(-5265.519, 40895.605, -3618.298), -- 393
        Vector3.new(-5269.106, 40895.605, -3616.167), -- 394
        Vector3.new(-5272.588, 40895.605, -3614.039), -- 395
        Vector3.new(-5276.051, 40895.605, -3611.871), -- 396
        Vector3.new(-5279.567, 40895.605, -3609.631), -- 397
        Vector3.new(-5282.990, 40895.605, -3607.418), -- 398
        Vector3.new(-5286.481, 40895.605, -3605.149), -- 399
        Vector3.new(-5289.973, 40895.605, -3602.878), -- 400
        Vector3.new(-5293.391, 40895.605, -3600.647), -- 401
        Vector3.new(-5296.664, 40895.605, -3598.207), -- 402
        Vector3.new(-5299.917, 40895.605, -3595.743), -- 403
        Vector3.new(-5303.300, 40895.652, -3593.312), -- 404
        Vector3.new(-5305.001, 40898.676, -3592.122), -- 405
        Vector3.new(-5306.642, 40904.277, -3590.974), -- 406
        Vector3.new(-5308.304, 40907.383, -3589.863), -- 407
        Vector3.new(-5311.927, 40905.680, -3587.640), -- 408
        Vector3.new(-5313.678, 40901.332, -3586.670), -- 409
        Vector3.new(-5317.340, 40900.781, -3584.680), -- 410
        Vector3.new(-5319.095, 40905.672, -3583.719), -- 411
        Vector3.new(-5320.885, 40910.586, -3582.654), -- 412
        Vector3.new(-5322.610, 40912.789, -3581.486), -- 413
        Vector3.new(-5325.901, 40912.625, -3578.995), -- 414
        Vector3.new(-5327.920, 40912.781, -3575.719), -- 415
        Vector3.new(-5327.208, 40912.781, -3571.618), -- 416
        Vector3.new(-5323.312, 40912.781, -3570.493), -- 417
    }
    local spawnFolder = workspace:FindFirstChild("EggSpawns")
    local eggSpawn = spawnFolder and spawnFolder:FindFirstChild("Volcanic")
    if not eggSpawn then
        warn("[Volcanic Test] ไม่พบ EggSpawns.Volcanic")
        return false
    end
    
    local root = GetHumanoidRootPart()
    if not root then return false end
    local previousSpeed = Config.TweenSpeed
    Config.TweenSpeed = 1500 -- เดินทางไปยังจุดเริ่มของเส้นทาง
    local function finish(ok)
        Config.TweenSpeed = previousSpeed
        return ok
    end
    local function moveTo(target, label, precise)
        local tolerance = precise and 2.5 or 10
        local function reached(position)
            if precise then
                -- HRP ขณะเดินอาจสูง/ต่ำกว่าจุดที่บันทึกจากแรงโน้มถ่วงราว 3 studs
                local delta = target - position
                return Vector3.new(delta.X, 0, delta.Z).Magnitude <= 3
                    and math.abs(delta.Y) <= 6
            end
            return (target - position).Magnitude <= tolerance
        end
        local previousDistance = math.huge
        for attempt = 1, 3 do
            if not Config.AutoEgg or (not testRoute and egg.Parent ~= folder) then return false end
            local now = GetHumanoidRootPart()
            if not now then return false end
            local distance = (target - now.Position).Magnitude
            if reached(now.Position) then return true end
            if attempt > 1 and distance >= previousDistance - 3 then
                warn("[Volcanic] จุด", label, "ไม่คืบหน้า หยุดลองซ้ำ:", now.Position)
                return false
            end
            previousDistance = distance
            -- TweenTo adds 3 studs to its input. Pass the HRP destination minus 3.
            if not TweenTo(target - Vector3.new(0, 3, 0)) then return false end
            now = GetHumanoidRootPart()
            if not now then return false end
            if reached(now.Position) or (not precise and (now.Position - target).Magnitude <= 15) then
                return Config.AutoEgg
            end
            warn("[Volcanic] เกมดึงตัวกลับระหว่างทางที่จุด", label,
                "| ลอง:", attempt, "| ตำแหน่ง:", now.Position)
            task.wait(0.35)
        end
        warn("[Volcanic] ไปไม่ถึงจุดหลังลอง 3 ครั้ง:", label)
        return false
    end
    for index, position in ipairs(route) do
        if index == 1 or index % 25 == 0 or index == #route then
            print("[Volcanic] จุดทางเดิน", index, "/", #route, "| เป้าหมาย:", position)
        end
        if not moveTo(position, "จุดเดิน " .. index, true) then return finish(false) end
        if index == 1 then
            Config.TweenSpeed = 350 -- เดินตามจุดที่บันทึกไว้หลังถึงจุดเริ่ม
        end
    end
    -- จุดสุดท้ายในไฟล์บันทึกอาจอยู่ห่างจุดเกิดไข่: เดินไปยัง Part หลังผ่านเส้นทาง
    if not moveTo(GetObjectPosition(eggSpawn) + Vector3.new(0, 2.5, 0), "EggSpawns.Volcanic") then
        return finish(false)
    end
    if testRoute then
        print("[Volcanic Test] ถึงจุดไข่เกิดแล้ว (ไม่ได้กด E)")
        return finish(true)
    end

    -- หลังเข้าทางประตูแล้ว จึงไปยังไข่จริงที่ RenderedEggs
    local top = GetEggTopPosition(egg)
    if not top or not moveTo(top + Vector3.new(0, 2.5, 0), "RenderedEggs.Volcanic Egg") then
        return finish(false)
    end
    local destination = top + Vector3.new(0, 2.5, 0)
    root = GetHumanoidRootPart()
    if not root or (root.Position - destination).Magnitude > 12 then return finish(false) end
    task.wait(0.4)
    root = GetHumanoidRootPart()
    top = GetEggTopPosition(egg)
    -- ตำแหน่งโมเดลไข่และตำแหน่ง prompt อาจไม่อยู่จุดเดียวกัน
    -- ให้ขั้นตอนกด E ลองต่อเมื่ออยู่ใกล้ไข่ แทนการยกเลิกจากคลาดเคลื่อนเล็กน้อย
    return finish(root ~= nil and top ~= nil and egg.Parent == folder
        and (root.Position - (top + Vector3.new(0, 2.5, 0))).Magnitude <= 12)
end

--======================================================
-- Hold E
--======================================================

local function ReleaseE()
    pcall(function()
        VirtualInputManager:SendKeyEvent(
            false,
            Enum.KeyCode.E,
            false,
            game
        )
    end)
end

local function HoldE()
    pcall(function()
        if not Config.AutoEgg then
            return
        end

        VirtualInputManager:SendKeyEvent(
            true,
            Enum.KeyCode.E,
            false,
            game
        )

        task.wait(Config.HoldETime)

        ReleaseE()
    end)
end

--======================================================
-- Collect Egg
--======================================================

local function IsEggStillPresent(Egg)
    local Folder = GetEggFolder()

    if not Egg or not Folder then
        return false
    end

    return Egg.Parent == Folder
end


local function FindSameEgg(EggName)
    local Folder = GetEggFolder()

    if not Folder then
        return nil, nil
    end

    local Selected = BuildSelectedSet(Config.Eggs)

    if not Selected[EggName] then
        return nil, nil
    end

    local HRP = GetHumanoidRootPart()
    local BestEgg = nil
    local BestPosition = nil
    local BestDistance = math.huge

    for _, Egg in ipairs(Folder:GetChildren()) do
        if Egg.Name == EggName then

            local Position = GetObjectPosition(Egg)

            if Position then

                local Distance =
                    HRP and (HRP.Position - Position).Magnitude or 0

                if Distance < BestDistance then
                    BestDistance = Distance
                    BestEgg = Egg
                    BestPosition = Position
                end

            end
        end
    end

    return BestEgg, BestPosition
end


-- เก็บไข่จนสำเร็จ
-- จะไม่กลับบ้านจนกว่าจะยืนยันว่าไข่หาย/ถูกย้ายออกจาก RenderedEggs
local function CollectEggUntilSuccess(Egg, EggPosition)
    if not Egg or not EggPosition then
        return false
    end

    local EggName = Egg.Name
    local MaxAttempts = 12
    local Attempt = 0

    CurrentEggTarget = Egg

    while Config.AutoEgg and Attempt < MaxAttempts do
        Attempt += 1

        -- ถ้าตัวละครถูก Reset / ตาย ให้รอ Character ใหม่ก่อน
        local Character = LocalPlayer.Character
        local HumanoidObj = Character and Character:FindFirstChildOfClass("Humanoid")

        if not Character
            or not HumanoidObj
            or HumanoidObj.Health <= 0
        then
            print("[EggHub] ตัวละครหลุด/ล้ม กำลังรอตัวละครใหม่...")

            repeat
                task.wait(0.25)
                Character = LocalPlayer.Character
                HumanoidObj = Character and Character:FindFirstChildOfClass("Humanoid")
            until not Config.AutoEgg
                or (
                    Character
                    and HumanoidObj
                    and HumanoidObj.Health > 0
                    and GetHumanoidRootPart()
                )

            if not Config.AutoEgg then
                break
            end
        end

        -- ถ้า Instance เดิมหายไป ให้หาไข่ชื่อเดิมใหม่
        if not IsEggStillPresent(Egg) then
            local NewEgg, NewPosition = FindSameEgg(EggName)

            if NewEgg and NewPosition then
                Egg = NewEgg
                EggPosition = NewPosition
                CurrentEggTarget = Egg

                print(
                    "[EggHub] พบไข่เดิมใหม่:",
                    EggName
                )
            else
                print(
                    "[EggHub] ไม่พบไข่เดิมชั่วคราว:",
                    EggName
                )

                task.wait(0.5)
                continue
            end
        else
            -- อัปเดตตำแหน่งเผื่อไข่ขยับ
            local NewPosition = GetObjectPosition(Egg)
            if NewPosition then
                EggPosition = NewPosition
            end
        end

        print(
            "[EggHub] พยายามเก็บ:",
            EggName,
            "| ครั้งที่:",
            Attempt
        )

        local Moved
        if EggName == "Volcanic Egg" then
            Moved = TweenToVolcanicEgg(Egg)
        else
            Moved = TweenTo(EggPosition)
        end

        -- ปิด Auto Egg ระหว่าง Tween = หยุดทันที ไม่กด E ต่อ
        if not Config.AutoEgg then
            StopTween()
            ReleaseE()
            CurrentEggTarget = nil
            return false
        end

        if Moved then
            task.wait(0.15)

            if not Config.AutoEgg then
                StopTween()
                ReleaseE()
                CurrentEggTarget = nil
                return false
            end

            -- ถ้าไข่หายระหว่าง Tween ถือว่าเก็บสำเร็จจากการอัปเดตของเกม
            if not IsEggStillPresent(Egg) then
                print(
                    "[EggHub] ไข่หายระหว่างการเดินทาง:",
                    EggName
                )
            else
                -- ตรวจอีกครั้งก่อนกด E
                if not Config.AutoEgg then
                    StopTween()
                    ReleaseE()
                    CurrentEggTarget = nil
                    return false
                end

                HoldE()

                if not Config.AutoEgg then
                    ReleaseE()
                    CurrentEggTarget = nil
                    return false
                end

                -- ให้ ProximityPrompt/ระบบเก็บของประมวลผล
                task.wait(0.15)

                if not Config.AutoEgg then
                    ReleaseE()
                    CurrentEggTarget = nil
                    return false
                end

                -- รอผลจริงก่อนนับว่าเก็บสำเร็จ
                local Updated = WaitForEggUpdate(Egg, 1.5)

                if Updated or not IsEggStillPresent(Egg) then
                    print(
                        "[EggHub] เก็บสำเร็จ:",
                        EggName
                    )

                    CollectedEggs[EggName] =
                        (CollectedEggs[EggName] or 0) + 1
                    AddEggHistory("Collected", EggName)

                    LastCollectedEgg = Egg
                    LastCollectedTime = tick()

                    print(
                        "[EggHub] จำนวน:",
                        CollectedEggs[EggName]
                    )

                    CurrentEggTarget = nil

                    return true
                end

                print(
                    "[EggHub] ยังเก็บไม่สำเร็จ กำลังลองใหม่:",
                    EggName
                )
            end
        else
            print(
                "[EggHub] Tween ไม่สำเร็จ กำลังลองใหม่:",
                EggName
            )
            if EggName == "Volcanic Egg" then
                -- เกมอาจปฏิเสธการเข้า Lair หากไม่ได้ผ่านประตู
                -- พักสั้น ๆ ก่อนลองใหม่ ไม่ตัดการเก็บไข่ทิ้งตั้งแต่ครั้งแรก
                task.wait(1)
            end
        end

        -- ถ้าเดินทางล้ม/หลุด ให้รอสั้น ๆ แล้วกลับไปหาไข่เดิม
        task.wait(0.35)

        -- หาไข่ชื่อเดิมอีกครั้งเพื่อให้รองรับ RenderedEggs refresh
        local RetryEgg, RetryPosition = FindSameEgg(EggName)

        if RetryEgg and RetryPosition then
            Egg = RetryEgg
            EggPosition = RetryPosition
            CurrentEggTarget = Egg
        end
    end

    print(
        "[EggHub] เก็บไม่สำเร็จภายในจำนวนครั้งที่กำหนด:",
        EggName
    )

    return false
end

--======================================================
-- Return Home
--======================================================

local function ReturnHome()
    local HomePosition = GetHomePosition()

    if not HomePosition then
        warn(
            "[EggHub] ไม่พบ Baseplate ใน Plot ของตัวเอง"
        )

        return false
    end

    print("[EggHub] กำลังกลับบ้าน...")

    return TweenTo(HomePosition, true)
end

--======================================================
-- Auto Egg Loop
--======================================================

task.spawn(function()

    while task.wait(0.25) do

        if Config.AutoEgg and not Busy then

            Busy = true

            -- ถ้า target เก่าถูกลบแล้ว ให้เคลียร์
            if CurrentEggTarget
                and not CurrentEggTarget.Parent then

                CurrentEggTarget = nil
            end

            local Egg, EggPosition = FindEnabledEgg()

            if Egg and EggPosition then

                CurrentEggTarget = Egg

                print(
                    "[EggHub] พบไข่:",
                    Egg.Name
                )

                -- สำคัญ:
                -- จะไม่กลับบ้านจนกว่า CollectEggUntilSuccess() จะยืนยันว่าเก็บสำเร็จ
                local Success =
                    CollectEggUntilSuccess(
                        Egg,
                        EggPosition
                    )

                if Success then

                    -- ถ้าปิดระหว่างทาง ห้ามทำงานต่อ/ห้ามกลับบ้าน
                    if not Config.AutoEgg then
                        StopTween()
                        ReleaseE()
                        CurrentEggTarget = nil
                        Busy = false
                        continue
                    end

                    task.wait(0.20)

                    if not Config.AutoEgg then
                        StopTween()
                        ReleaseE()
                        CurrentEggTarget = nil
                        Busy = false
                        continue
                    end

                    -- กลับบ้านหลังจากเก็บสำเร็จเท่านั้น
                    ReturnHome()

                    -- รอให้ RenderedEggs รีเฟรช
                    task.wait(0.50)

                    if CurrentEggTarget
                        and not CurrentEggTarget.Parent then

                        CurrentEggTarget = nil
                    end

                else

                    -- ถ้าเก็บไม่สำเร็จ ห้ามกลับบ้านเอง
                    -- ให้รอแล้ววนกลับไปหาเป้าหมายเดิม
                    print(
                        "[EggHub] ยังเก็บไม่สำเร็จ:",
                        Egg.Name,
                        "| จะลองใหม่"
                    )

                    task.wait(0.50)
                end

            else

                -- ไม่มีเป้าหมายใหม่ รอ RenderedEggs อัปเดต
                task.wait(0.50)
            end

            Busy = false
        end
    end

end)

--======================================================
-- AutoBuy remotes
--======================================================

local AutobuyRemote = nil
local UpgradesRemote = nil

pcall(function()
    AutobuyRemote =
        ReplicatedStorage
        :WaitForChild("Remotes")
        :WaitForChild("Game")
        :WaitForChild("Autobuy")
end)

pcall(function()
    UpgradesRemote =
        ReplicatedStorage
        :WaitForChild("Remotes")
        :WaitForChild("Game")
        :WaitForChild("Plot")
        :WaitForChild("Upgrades")
end)

--======================================================
-- Gear / Food
--======================================================

local function BuyItem(Category, ItemName)
    if not AutobuyRemote then
        return false
    end

    local Success = false

    pcall(function()
        if AutobuyRemote:IsA("RemoteEvent") then
            AutobuyRemote:FireServer(Category, ItemName)
            Success = true
        elseif AutobuyRemote:IsA("RemoteFunction") then
            AutobuyRemote:InvokeServer(Category, ItemName)
            Success = true
        end
    end)

    return Success
end

--======================================================
-- AutoBuy Gear
--======================================================

task.spawn(function()
    while task.wait(Config.AutoBuy.CheckDelay) do
        if Config.AutoBuy.Gear then
            local Selected = BuildSelectedSet(Config.AutoBuy.GearSelected)

            for _, ItemName in ipairs(GearList) do
                if not Config.AutoBuy.Gear then
                    break
                end

                if Selected[ItemName] then
                    local KeepBuying = true

                    while Config.AutoBuy.Gear and KeepBuying do
                        KeepBuying = false

                        if BuyItem("Gear", ItemName) then
                            KeepBuying = true

                            print(
                                "[AutoBuy][Gear] ซื้อ:",
                                ItemName
                            )

                            task.wait(Config.AutoBuy.BuyDelay)
                        end
                    end

                    print(
                        "[AutoBuy][Gear] ตรวจใหม่:",
                        ItemName
                    )
                end
            end
        end
    end
end)

--======================================================
-- AutoBuy Food
--======================================================

task.spawn(function()
    while task.wait(Config.AutoBuy.CheckDelay) do
        if Config.AutoBuy.Food then
            local Selected = BuildSelectedSet(Config.AutoBuy.FoodSelected)

            for _, ItemName in ipairs(FoodList) do
                if not Config.AutoBuy.Food then
                    break
                end

                if Selected[ItemName] then
                    local KeepBuying = true

                    while Config.AutoBuy.Food and KeepBuying do
                        KeepBuying = false

                        if BuyItem("Food", ItemName) then
                            KeepBuying = true

                            print(
                                "[AutoBuy][Food] ซื้อ:",
                                ItemName
                            )

                            task.wait(Config.AutoBuy.BuyDelay)
                        end
                    end

                    print(
                        "[AutoBuy][Food] ตรวจใหม่:",
                        ItemName
                    )
                end
            end
        end
    end
end)

--======================================================
-- AutoBuy Lucky / UpLuck
-- Remote:
-- ReplicatedStorage.Remotes.Game.Plot.Upgrades
--======================================================

local function UpLuck()
    if not UpgradesRemote then
        warn("[AutoBuy][Lucky] ไม่พบ Upgrades Remote")
        return false
    end

    local Success = false

    pcall(function()
        if UpgradesRemote:IsA("RemoteEvent") then
            UpgradesRemote:FireServer(Config.AutoBuy.LuckyArgument)
            Success = true
        elseif UpgradesRemote:IsA("RemoteFunction") then
            UpgradesRemote:InvokeServer(Config.AutoBuy.LuckyArgument)
            Success = true
        end
    end)

    if Success then
        print("[AutoBuy][Lucky] ส่งคำสั่ง UpLuck:", Config.AutoBuy.LuckyArgument)
    end

    return Success
end

--======================================================
-- AutoBuy Lucky Loop
--======================================================
-- แก้ปัญหา Toggle เปิดหลัง Script เริ่มแล้วไม่ทำงาน:
-- เดิม while Config.AutoBuy.Lucky จะถูกตรวจแค่ตอนสร้าง thread
-- ถ้าตอนนั้นเป็น false loop จะไม่เริ่มเลย
-- และเพิ่มเงื่อนไขเงินขั้นต่ำ 20M จาก SavedData.Cash

local LuckyMinCash = 20000000

local function GetCash()
    local SavedData = LocalPlayer:FindFirstChild("SavedData")
    local Cash = SavedData and SavedData:FindFirstChild("Cash")

    if Cash then
        return tonumber(Cash.Value) or 0
    end

    return 0
end

local function CanUpgradeLucky()
    local Cash = GetCash()

    if Cash >= LuckyMinCash then
        return true
    end

    return false
end

task.spawn(function()
    while task.wait(0.05) do
        if Config.AutoBuy.Lucky then
            if CanUpgradeLucky() then
                UpLuck()
            else
                -- เงินต่ำกว่า 20M: หยุดอัปทันที
                Config.AutoBuy.Lucky = false

                print(
                    "[AutoBuy][Lucky] หยุดอัป: เงินต่ำกว่า 20M | Cash:",
                    GetCash()
                )

                print("[EggHub] AutoBuy Lucky หยุดแล้ว: เงินต่ำกว่า 20M")
            end
        end
    end
end)

--======================================================
-- SpeedHack
--======================================================

local function UpdateSpeed()
    local HumanoidObj = GetHumanoid()

    if not HumanoidObj then
        return
    end

    if Config.SpeedHack then
        HumanoidObj.WalkSpeed = Config.SpeedValue
    else
        HumanoidObj.WalkSpeed = 16
    end
end

LocalPlayer.CharacterAdded:Connect(function(CharacterObj)
    local HumanoidObj = CharacterObj:WaitForChild("Humanoid")

    task.wait(0.5)

    if Config.SpeedHack then
        HumanoidObj.WalkSpeed = Config.SpeedValue
    else
        HumanoidObj.WalkSpeed = 16
    end
end)

task.spawn(function()
    while task.wait(0.25) do
        if Config.SpeedHack then
            UpdateSpeed()
        end
    end
end)

--======================================================
-- Unified Live Eggs Dashboard
--======================================================
do
    local CoreGui = game:GetService("CoreGui")
    local old = CoreGui:FindFirstChild("EggStealerUnified")
    if old then old:Destroy() end
    local ui = Instance.new("ScreenGui")
    ui.Name = "EggStealerUnified"
    ui.ResetOnSpawn = false
    ui.IgnoreGuiInset = true
    ui.Parent = CoreGui
    local bg = Color3.fromRGB(23, 25, 29)
    local card = Color3.fromRGB(35, 38, 43)
    local textColor = Color3.fromRGB(236, 239, 244)
    local gold = Color3.fromRGB(247, 210, 101)
    local function make(class, parent, props)
        local item = Instance.new(class)
        for key, value in pairs(props) do item[key] = value end
        item.Parent = parent
        return item
    end
    local function rounded(item, pixels)
        make("UICorner", item, {CornerRadius = UDim.new(0, pixels or 7)})
        return item
    end
    local function label(parent, value, position, size, color, fontSize)
        return make("TextLabel", parent, {BackgroundTransparency = 1, Text = value,
            TextColor3 = color or textColor, Font = Enum.Font.GothamBold, TextSize = fontSize or 13,
            TextXAlignment = Enum.TextXAlignment.Left, Position = position, Size = size})
    end
    local function button(parent, value, position, size, callback)
        local item = rounded(make("TextButton", parent, {Text = value, TextColor3 = textColor,
            TextSize = 12, Font = Enum.Font.GothamBold, BackgroundColor3 = Color3.fromRGB(50, 54, 60),
            Position = position, Size = size}), 6)
        item.MouseButton1Click:Connect(callback)
        return item
    end
    local function input(parent, value, position, size, placeholder, callback)
        local item = rounded(make("TextBox", parent, {Text = tostring(value), PlaceholderText = placeholder or "",
            TextColor3 = textColor, PlaceholderColor3 = Color3.fromRGB(145, 150, 157),
            Font = Enum.Font.Gotham, TextSize = 13, BackgroundColor3 = card,
            Position = position, Size = size, ClearTextOnFocus = false}), 6)
        item.FocusLost:Connect(function() callback(item.Text) end)
        return item
    end
    local root = rounded(make("Frame", ui, {Name = "Window", BackgroundColor3 = bg,
        Position = UDim2.new(0.5, -320, 0.5, -235), Size = UDim2.fromOffset(640, 470)}), 12)
    make("UIStroke", root, {Color = Color3.fromRGB(66, 70, 77), Thickness = 1})
    local bar = make("Frame", root, {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46)})
    label(bar, "Ride A Egg Script Priavte แจก พ่อมึงตาย", UDim2.fromOffset(15, 8), UDim2.new(1, -65, 0, 28), gold, 16)
    local mini = rounded(make("Frame", ui, {Name = "OpenButton", Size = UDim2.fromOffset(45, 45),
        Position = UDim2.new(0, 20, 0.5, -22), BackgroundColor3 = bg, Visible = false}), 10)
    local rootScale = make("UIScale", root, {Scale = 1})
    local miniScale = make("UIScale", mini, {Scale = 1})
    local isCollapsed = false
    local rootAnimation, miniAnimation
    local function setCollapsed(target)
        if target == isCollapsed then return end
        isCollapsed = target
        if rootAnimation then rootAnimation:Cancel() end
        if miniAnimation then miniAnimation:Cancel() end
        if target then
            mini.Visible = true
            miniScale.Scale = 0.65
            miniAnimation = TweenService:Create(miniScale, TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
            miniAnimation:Play()
            rootAnimation = TweenService:Create(rootScale, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.65})
            local thisAnimation = rootAnimation
            thisAnimation.Completed:Connect(function(state)
                if state == Enum.PlaybackState.Completed and rootAnimation == thisAnimation then
                    root.Visible = false
                end
            end)
            rootAnimation:Play()
        else
            root.Visible = true
            rootScale.Scale = 0.65
            rootAnimation = TweenService:Create(rootScale, TweenInfo.new(0.23, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
            rootAnimation:Play()
            miniAnimation = TweenService:Create(miniScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.65})
            local thisAnimation = miniAnimation
            thisAnimation.Completed:Connect(function(state)
                if state == Enum.PlaybackState.Completed and miniAnimation == thisAnimation then
                    mini.Visible = false
                    miniScale.Scale = 1
                end
            end)
            miniAnimation:Play()
        end
    end
    local avatarButton = rounded(make("ImageButton", mini, {
        Name = "PlayerAvatar", BackgroundColor3 = card, Image = "",
        Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(41, 41),
        ScaleType = Enum.ScaleType.Crop
    }), 8)
    local avatarFallback = make("TextLabel", avatarButton, {
        BackgroundTransparency = 1, Text = "👤", TextSize = 22,
        Size = UDim2.fromScale(1, 1), TextColor3 = textColor
    })
    avatarButton.MouseButton1Click:Connect(function() setCollapsed(false) end)
    task.spawn(function()
        local ok, thumbnail = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        end)
        if ok and thumbnail and ui.Parent then
            avatarButton.Image = thumbnail
            avatarFallback.Visible = false
        end
    end)
    button(bar, "—", UDim2.new(1, -37, 0, 9), UDim2.fromOffset(26, 26), function()
        setCollapsed(true)
    end)
    local ctrlConnection = UserInputService.InputBegan:Connect(function(event)
        if event.KeyCode == Enum.KeyCode.LeftControl or event.KeyCode == Enum.KeyCode.RightControl then
            setCollapsed(not isCollapsed)
        end
    end)
    ui.Destroying:Connect(function() ctrlConnection:Disconnect() end)
    local dragging, dragStart, startPos
    bar.InputBegan:Connect(function(event)
        if event.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, dragStart, startPos = true, event.Position, root.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(event)
        if event.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(event)
        if dragging and event.UserInputType == Enum.UserInputType.MouseMovement then
            local d = event.Position - dragStart
            root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    local side = rounded(make("Frame", root, {Position = UDim2.fromOffset(9, 48),
        Size = UDim2.fromOffset(126, 410), BackgroundColor3 = Color3.fromRGB(27, 29, 33)}), 8)
    local body = make("Frame", root, {Position = UDim2.fromOffset(145, 48),
        Size = UDim2.fromOffset(484, 410), BackgroundTransparency = 1})
    local tabs, pages = {}, {}
    local active = "Live"
    for i, name in ipairs({"Egg Stealer", "Live", "Upgrade", "Log History", "Config"}) do
        local page = make("Frame", body, {BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1), Visible = name == active})
        pages[name] = page
        local tab = button(side, name, UDim2.fromOffset(7, 12 + (i - 1) * 43),
            UDim2.fromOffset(112, 35), function()
                active = name
                for key, section in pairs(pages) do section.Visible = key == name end
                for key, item in pairs(tabs) do
                    item.BackgroundColor3 = key == name and Color3.fromRGB(57, 69, 63) or card
                end
            end)
        tab.BackgroundColor3 = name == active and Color3.fromRGB(57, 69, 63) or card
        tabs[name] = tab
    end
    local function line(page, y, title, value, callback)
        label(page, title, UDim2.fromOffset(5, y), UDim2.fromOffset(205, 28))
        return input(page, value, UDim2.fromOffset(221, y), UDim2.fromOffset(220, 29), "", callback)
    end
    local function toggle(page, y, title, getter, setter)
        label(page, title, UDim2.fromOffset(5, y), UDim2.fromOffset(255, 29))
        local btn
        local function draw()
            btn.Text = getter() and "ON" or "OFF"
            btn.BackgroundColor3 = getter() and Color3.fromRGB(52, 114, 79) or Color3.fromRGB(78, 62, 64)
        end
        btn = button(page, "", UDim2.fromOffset(338, y), UDim2.fromOffset(102, 29), function()
            setter(not getter())
            draw()
        end)
        draw()
        return draw
    end
    local function scroll(page, pos, size)
        local frame = make("ScrollingFrame", page, {BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 4, Position = pos, Size = size,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y})
        make("UIListLayout", frame, {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder})
        return frame
    end
    local eggPage = pages.Live
    label(eggPage, "Live Eggs Realtime", UDim2.fromOffset(5, 0), UDim2.fromOffset(280, 25), gold)
    local totalLabel = label(eggPage, "Total Live: 0", UDim2.fromOffset(330, 0), UDim2.fromOffset(145, 25))
    local search = input(eggPage, "", UDim2.fromOffset(5, 32), UDim2.fromOffset(190, 30), "Search egg...", function() end)
    local eggRows = scroll(eggPage, UDim2.fromOffset(5, 70), UDim2.fromOffset(470, 332))
    local known = {}
    for _, name in ipairs(EggList) do known[name] = true end
    local function rememberEgg(name)
        if not known[name] then known[name] = true; table.insert(EggList, name) end
    end
    local function setAutoEgg(enabled)
        Config.AutoEgg = enabled
        if not enabled then StopTween(); ReleaseE(); CurrentEggTarget = nil end
    end
    local function selected(name)
        local set = BuildSelectedSet(Config.Eggs)
        return set[name] == true
    end
    local function selectionColor(name)
        return selected(name) and Color3.fromRGB(43, 138, 83) or Color3.fromRGB(168, 59, 66)
    end
    local function selectEgg(name, on)
        rememberEgg(name)
        local set = BuildSelectedSet(Config.Eggs)
        set[name] = on or nil
        Config.Eggs = {}
        for _, entry in ipairs(EggList) do
            if set[entry] then table.insert(Config.Eggs, entry) end
        end
    end
    button(eggPage, "Farm All", UDim2.fromOffset(204, 32), UDim2.fromOffset(85, 30), function()
        Config.Eggs = table.clone(EggList)
        setAutoEgg(true)
    end)
    button(eggPage, "Stop Farm", UDim2.fromOffset(297, 32), UDim2.fromOffset(91, 30), function()
        setAutoEgg(false)
    end)
    button(eggPage, "Home", UDim2.fromOffset(396, 32), UDim2.fromOffset(78, 30), function()
        if Busy then return end
        task.spawn(function() Busy = true; ReturnHome(); Busy = false end)
    end)
    local lastSignature = ""
    local eggModels = {}
    local nextTemplateCheck = 0
    local function cacheEggModel(name, source)
        if eggModels[name] or not source
            or not (source:IsA("Model") or source:IsA("BasePart")) then return false end
        local ok, copy = pcall(function() return source:Clone() end)
        if not ok or not copy then return false end
        copy.Parent = nil
        eggModels[name] = copy
        return true
    end
    local function findEggTemplates()
        if tick() < nextTemplateCheck then return end
        nextTemplateCheck = tick() + 10
        local wanted = {}
        for _, name in ipairs(EggList) do
            if not eggModels[name] then wanted[name] = true end
        end
        if not next(wanted) then return end
        for _, object in ipairs(ReplicatedStorage:GetDescendants()) do
            if wanted[object.Name] and (object:IsA("Model") or object:IsA("BasePart"))
                and cacheEggModel(object.Name, object) then
                wanted[object.Name] = nil
                if not next(wanted) then break end
            end
        end
    end
    findEggTemplates()
    local function renderEggModel(row, source)
        if not source or not (source:IsA("Model") or source:IsA("BasePart")) then return false end
        local ok, clone = pcall(function() return source:Clone() end)
        if not ok or not clone then return false end
        local viewport = make("ViewportFrame", row, {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(1, 1),
            Size = UDim2.fromOffset(41, 41), Ambient = Color3.fromRGB(210, 210, 230),
            LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -1)
        })
        local world = make("WorldModel", viewport, {})
        for _, item in ipairs(clone:GetDescendants()) do
            if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("Highlight")
                or item:IsA("ProximityPrompt") then item:Destroy() end
        end
        clone.Parent = world
        -- Use only visible pieces for camera framing. Invisible handles and
        -- large outline parts otherwise make the egg appear as a tiny dot.
        local minimum, maximum
        local function includePart(part)
            if not part:IsA("BasePart") or part.Transparency >= 0.95
                or part.Name == "EggOutline" or part:FindFirstAncestor("EggOutline") then return end
            local extent = part.Size * 0.5
            local low, high = part.Position - extent, part.Position + extent
            minimum = minimum and Vector3.new(math.min(minimum.X, low.X), math.min(minimum.Y, low.Y), math.min(minimum.Z, low.Z)) or low
            maximum = maximum and Vector3.new(math.max(maximum.X, high.X), math.max(maximum.Y, high.Y), math.max(maximum.Z, high.Z)) or high
        end
        includePart(clone)
        for _, part in ipairs(clone:GetDescendants()) do includePart(part) end
        local bounds, size
        if minimum then
            bounds, size = CFrame.new((minimum + maximum) * 0.5), maximum - minimum
        elseif clone:IsA("Model") then bounds, size = clone:GetBoundingBox()
        else bounds, size = clone.CFrame, clone.Size end
        local distance = math.max(size.X, size.Y, size.Z, 0.5) * 1.3
        local camera = make("Camera", viewport, {
            FieldOfView = 45,
            CFrame = CFrame.lookAt(bounds.Position + Vector3.new(distance * 0.55, distance * 0.35, distance), bounds.Position)
        })
        viewport.CurrentCamera = camera
        return true
    end
    local function updateEggs()
        local grouped, amount = {}, 0
        local folder = GetEggFolder()
        if folder then
            for _, egg in ipairs(folder:GetChildren()) do
                if GetObjectPosition(egg) then
                    grouped[egg.Name] = grouped[egg.Name] or {}
                    table.insert(grouped[egg.Name], egg)
                    amount += 1
                end
            end
        end
        totalLabel.Text = "Total Live: " .. amount
        for name in pairs(grouped) do rememberEgg(name) end
        for name, instances in pairs(grouped) do cacheEggModel(name, instances[1]) end
        findEggTemplates()
        local names = table.clone(EggList)
        local signature = search.Text .. "|" .. tostring(Config.AutoEgg)
        for _, name in ipairs(names) do
            local instances = grouped[name] or {}
            signature ..= name .. ":" .. #instances .. ":" .. tostring(selected(name))
                .. ":" .. tostring(eggModels[name]) .. ";"
            for _, egg in ipairs(instances) do
                signature ..= tostring(egg) .. tostring(GetObjectPosition(egg))
            end
        end
        if signature == lastSignature then return end
        lastSignature = signature
        for _, child in ipairs(eggRows:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
        for _, name in ipairs(names) do
            if string.find(string.lower(name), string.lower(search.Text), 1, true) then
                local eggs = grouped[name] or {}
                local row = rounded(make("Frame", eggRows, {Size = UDim2.new(1, -5, 0, 43),
                    BackgroundColor3 = card}), 7)
                local usedModel = renderEggModel(row, eggModels[name] or eggs[1])
                local id = not usedModel and EggImages[name] or nil
                if not usedModel and name ~= "Blackhole Egg" and (not id or id == "") and eggs[1] then
                    if eggs[1]:IsA("MeshPart") then id = eggs[1].TextureID
                    elseif eggs[1]:IsA("Decal") or eggs[1]:IsA("Texture") then id = eggs[1].Texture end
                end
                if not usedModel and name ~= "Blackhole Egg" and (not id or id == "") and eggs[1] then
                    for _, source in ipairs(eggs[1]:GetDescendants()) do
                        if source:IsA("ImageLabel") or source:IsA("ImageButton") then id = source.Image
                        elseif source:IsA("Decal") or source:IsA("Texture") then id = source.Texture
                        elseif source:IsA("MeshPart") then id = source.TextureID
                        elseif source:IsA("SpecialMesh") then id = source.TextureId end
                        if id and id ~= "" then break end
                    end
                end
                if usedModel then
                    -- The actual 3D egg is already visible in the ViewportFrame.
                elseif id and id ~= "" then
                    make("ImageLabel", row, {Image = tostring(id):match("^%d+$") and ("rbxassetid://" .. id) or id,
                        BackgroundTransparency = 1, Position = UDim2.fromOffset(5, 6), Size = UDim2.fromOffset(30, 30)})
                else label(row, "🥚", UDim2.fromOffset(5, 8), UDim2.fromOffset(34, 25)) end
                label(row, name, UDim2.fromOffset(42, 4), UDim2.fromOffset(177, 20), textColor, 12)
                label(row, "Live: " .. #eggs, UDim2.fromOffset(42, 24), UDim2.fromOffset(100, 15),
                    #eggs > 0 and Color3.fromRGB(97, 218, 139) or Color3.fromRGB(145, 148, 152), 11)
                if known[name] then
                    local selectButton = button(row, selected(name) and "✓" or "+", UDim2.fromOffset(238, 7), UDim2.fromOffset(30, 29), function()
                        selectEgg(name, not selected(name)); lastSignature = ""; updateEggs()
                    end)
                    selectButton.BackgroundColor3 = selectionColor(name)
                end
                button(row, "TP", UDim2.fromOffset(276, 7), UDim2.fromOffset(43, 29), function()
                    if Busy or #eggs == 0 then return end
                    task.spawn(function()
                        Busy = true
                        local wasOn = Config.AutoEgg
                        Config.AutoEgg = true
                        local target = GetObjectPosition(eggs[1])
                        if name == "Volcanic Egg" then
                            TweenToVolcanicEgg(eggs[1])
                        elseif target then
                            TweenTo(target)
                        end
                        Config.AutoEgg = wasOn
                        Busy = false
                    end)
                end)
                button(row, "Farm", UDim2.fromOffset(325, 7), UDim2.fromOffset(60, 29), function()
                    if #eggs > 0 and known[name] then
                        Config.Eggs = {name}; setAutoEgg(true); lastSignature = ""
                    end
                end)
                button(row, "ESP", UDim2.fromOffset(392, 7), UDim2.fromOffset(59, 29), function()
                    for _, egg in ipairs(eggs) do
                        local oldHighlight = egg:FindFirstChild("EggHubHighlight")
                        if oldHighlight then oldHighlight:Destroy() else
                            make("Highlight", egg, {Name = "EggHubHighlight",
                                FillColor = gold, OutlineColor = Color3.new(1, 1, 1),
                                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop})
                        end
                    end
                end)
            end
        end
    end
    task.spawn(function()
        while ui.Parent do
            if root.Visible and active == "Live" then updateEggs() end
            task.wait(1)
        end
    end)
    local auto = pages["Egg Stealer"]
    label(auto, "Egg Stealer", UDim2.fromOffset(5, 0), UDim2.fromOffset(200, 25), gold)
    local syncFarm = toggle(auto, 35, "Auto Egg", function() return Config.AutoEgg end, setAutoEgg)
    label(auto, "Select Egg", UDim2.fromOffset(5, 75), UDim2.fromOffset(200, 25), gold)
    local eggChoices = scroll(auto, UDim2.fromOffset(5, 105), UDim2.fromOffset(460, 158))
    local choiceSignature = ""
    local function refreshEggChoices()
        local folder = GetEggFolder()
        if folder then for _, egg in ipairs(folder:GetChildren()) do
            if GetObjectPosition(egg) then rememberEgg(egg.Name) end
        end end
        local signature = table.concat(EggList, "|") .. ":" .. table.concat(Config.Eggs, "|")
        if signature == choiceSignature then return end
        choiceSignature = signature
        for _, child in ipairs(eggChoices:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
        for _, name in ipairs(EggList) do
            local row = rounded(make("Frame", eggChoices, {Size = UDim2.new(1, -8, 0, 30), BackgroundColor3 = card}), 6)
            label(row, name, UDim2.fromOffset(9, 2), UDim2.fromOffset(310, 26), textColor, 12)
            local selectButton = button(row, selected(name) and "✓" or "+", UDim2.new(1, -44, 0, 2), UDim2.fromOffset(36, 26), function()
                selectEgg(name, not selected(name)); choiceSignature = ""; refreshEggChoices()
            end)
            selectButton.BackgroundColor3 = selectionColor(name)
        end
    end
    task.spawn(function() while ui.Parent do
        if root.Visible and active == "Egg Stealer" then refreshEggChoices() end
        task.wait(1)
    end end)
    button(auto, "Collect Once", UDim2.fromOffset(5, 275), UDim2.fromOffset(138, 30), function()
        if Busy then return end
        task.spawn(function()
            Busy = true
            local previous = Config.AutoEgg
            Config.AutoEgg = true
            local egg, position = FindEnabledEgg()
            if egg and position and CollectEggUntilSuccess(egg, position) then ReturnHome() end
            Config.AutoEgg = previous
            Busy = false
        end)
    end)
    button(auto, "Test Volcanic Route", UDim2.fromOffset(150, 275), UDim2.fromOffset(170, 30), function()
        if Busy then return end
        task.spawn(function()
            Busy = true
            local previous = Config.AutoEgg
            Config.AutoEgg = true
            local ok = TweenToVolcanicEgg(nil, true)
            if ok then
                -- กลับบ้านได้แม้ไข่ยังไม่เกิด และไม่แตะ logic นับไข่
                ReturnHome()
            else
                warn("[Volcanic Test] ไปไม่ถึงจุดไข่เกิด ดูจุดล่าสุดใน Output")
            end
            Config.AutoEgg = previous
            Busy = false
        end)
    end)
    line(auto, 320, "Tween Speed", Config.TweenSpeed, function(v)
        Config.TweenSpeed = math.clamp(tonumber(v) or Config.TweenSpeed, 100, 100000)
    end)
    line(auto, 362, "Hold E Time (seconds)", Config.HoldETime, function(v)
        Config.HoldETime = math.clamp(tonumber(v) or Config.HoldETime, 0.1, 2)
    end)
    local upgrade = pages.Upgrade
    label(upgrade, "AutoBuy / Upgrade", UDim2.fromOffset(5, 0), UDim2.fromOffset(250, 25), gold)
    toggle(upgrade, 35, "Auto Lucky (minimum 20M Cash)",
        function() return Config.AutoBuy.Lucky end, function(v) Config.AutoBuy.Lucky = v end)
    toggle(upgrade, 75, "AutoBuy Gear", function() return Config.AutoBuy.Gear end,
        function(v) Config.AutoBuy.Gear = v end)
    toggle(upgrade, 115, "AutoBuy Food", function() return Config.AutoBuy.Food end,
        function(v) Config.AutoBuy.Food = v end)
    line(upgrade, 161, "Lucky Argument", Config.AutoBuy.LuckyArgument,
        function(v) Config.AutoBuy.LuckyArgument = v end)
    button(upgrade, "Test UpLuck", UDim2.fromOffset(5, 203), UDim2.fromOffset(125, 29), function() UpLuck() end)
    line(upgrade, 246, "Check Delay", Config.AutoBuy.CheckDelay, function(v)
        Config.AutoBuy.CheckDelay = math.clamp(tonumber(v) or Config.AutoBuy.CheckDelay, 1, 10)
    end)
    line(upgrade, 286, "Buy Delay", Config.AutoBuy.BuyDelay, function(v)
        Config.AutoBuy.BuyDelay = math.clamp(tonumber(v) or Config.AutoBuy.BuyDelay, 0.05, 1)
    end)
    local history = pages["Log History"]
    label(history, "Log History  •  This session", UDim2.fromOffset(5, 0), UDim2.fromOffset(360, 26), gold)
    local historyRows = scroll(history, UDim2.fromOffset(5, 45), UDim2.fromOffset(460, 300))
    local function refreshHistory()
        for _, child in ipairs(historyRows:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
        end
        if #EggHistory == 0 then
            local empty = label(historyRows, "No eggs collected yet", UDim2.fromOffset(7, 0), UDim2.new(1, -10, 0, 28))
            empty.LayoutOrder = 1
            return
        end
        for _, entry in ipairs(EggHistory) do
            local row = rounded(make("Frame", historyRows, {Size = UDim2.new(1, -8, 0, 34), BackgroundColor3 = card}), 6)
            label(row, entry.time .. "   " .. entry.action .. "   " .. entry.name,
                UDim2.fromOffset(9, 2), UDim2.new(1, -18, 0, 30), textColor, 12)
        end
    end
    button(history, "Refresh", UDim2.fromOffset(5, 354), UDim2.fromOffset(120, 30), refreshHistory)
    task.spawn(function() while ui.Parent do
        if root.Visible and active == "Log History" then refreshHistory() end
        task.wait(2)
    end end)
    local settings = pages.Config
    label(settings, "Config  •  Ctrl to fold UI", UDim2.fromOffset(5, 0), UDim2.fromOffset(235, 28), gold)
    local saveStatus = label(settings, "", UDim2.fromOffset(5, 180), UDim2.fromOffset(460, 22))
    button(settings, "Save Config", UDim2.fromOffset(260, 0), UDim2.fromOffset(102, 29), function()
        if type(writefile) ~= "function" then saveStatus.Text = "Save unavailable in this executor"; return end
        local ok = pcall(function()
            if type(makefolder) == "function"
                and (type(isfolder) ~= "function" or not isfolder("EggStealer")) then
                makefolder("EggStealer")
            end
            writefile(ConfigPath, HttpService:JSONEncode(Config))
        end)
        saveStatus.Text = ok and "Saved: " .. ConfigPath or "Save failed: check file access"
    end)
    toggle(settings, 36, "Speed Hack", function() return Config.SpeedHack end,
        function(v) Config.SpeedHack = v; UpdateSpeed() end)
    line(settings, 85, "WalkSpeed", Config.SpeedValue, function(v)
        Config.SpeedValue = math.clamp(tonumber(v) or Config.SpeedValue, 16, 300)
        if Config.SpeedHack then UpdateSpeed() end
    end)
    toggle(settings, 138, "Anti AFK", function() return Config.AntiAFK end,
        function(v) Config.AntiAFK = v end)
    label(settings, "Gear", UDim2.fromOffset(5, 209), UDim2.fromOffset(220, 22), gold)
    label(settings, "Food", UDim2.fromOffset(244, 209), UDim2.fromOffset(220, 22), gold)
    local gearChoices = scroll(settings, UDim2.fromOffset(5, 236), UDim2.fromOffset(225, 163))
    local foodChoices = scroll(settings, UDim2.fromOffset(244, 236), UDim2.fromOffset(225, 163))
    local function choices(parent, entries, field)
        for _, name in ipairs(entries) do
            local row = rounded(make("Frame", parent, {
                Size = UDim2.new(1, -5, 0, 32), BackgroundColor3 = card
            }), 6)
            label(row, name, UDim2.fromOffset(7, 3), UDim2.fromOffset(155, 26), textColor, 11)
            local chosen = BuildSelectedSet(Config.AutoBuy[field])
            local btn
            btn = button(row, chosen[name] and "✓" or "+",
                UDim2.new(1, -33, 0, 3), UDim2.fromOffset(29, 26), function()
                    local set = BuildSelectedSet(Config.AutoBuy[field])
                    set[name] = not set[name] or nil
                    Config.AutoBuy[field] = {}
                    for _, entry in ipairs(entries) do
                        if set[entry] then table.insert(Config.AutoBuy[field], entry) end
                    end
                    btn.Text = set[name] and "✓" or "+"
                end)
        end
    end
    choices(gearChoices, GearList, "GearSelected")
    choices(foodChoices, FoodList, "FoodSelected")
    task.spawn(function()
        while ui.Parent do
            syncFarm()
            task.wait(1)
        end
    end)
    task.spawn(function()
        for attempt = 1, 20 do
            if FindMyPlot() then break end
            task.wait(0.5)
        end
    end)
end
