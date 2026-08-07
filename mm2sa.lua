-- MM2 Apex v2 — Full Rebuild + Avatar Mods
-- UI Library: Bxbx
-- Features: Combat, Visuals, Player, Teleport, Utilities, Misc, Settings

-- ==========================================
-- SERVICES
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- LOAD UI LIBRARY
-- ==========================================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/naturaldesire23/Bxbx/refs/heads/main/dkkd.lua"))()

local Window = Library:CreateWindow({
    Title = "MM2 Apex v2"
})

-- ==========================================
-- REMOTE REFERENCES (with validation)
-- ==========================================
local Remotes = {}

local function SafeGet(path)
    local current = game
    for _, part in ipairs(path) do
        current = current:FindFirstChild(part)
        if not current then return nil end
    end
    return current
end

local function InitRemotes()
    local remotePaths = {
        KnifeKill = {"ReplicatedStorage", "Remotes", "Gameplay", "KnifeKill"},
        GunKill = {"ReplicatedStorage", "Remotes", "Gameplay", "GunKill"},
        GiveWeapon = {"ReplicatedStorage", "Remotes", "Gameplay", "GiveWeapon"},
        KillEvent = {"ReplicatedStorage", "Remotes", "Gameplay", "KillEvent"},
        GetCoin = {"ReplicatedStorage", "Remotes", "Gameplay", "GetCoin"},
        CoinCollected = {"ReplicatedStorage", "Remotes", "Gameplay", "CoinCollected"},
        Equip = {"ReplicatedStorage", "Remotes", "Inventory", "Equip"},
        Unequip = {"ReplicatedStorage", "Remotes", "Inventory", "Unequip"},
        GunBeam = {"ReplicatedStorage", "WeaponEvents", "GunBeam"},
        GetPlayerData = {"ReplicatedStorage", "Remotes", "Extras", "GetPlayerData"},
        GetFullInventory = {"ReplicatedStorage", "Remotes", "Extras", "GetFullInventory"},
        Admin = {"ReplicatedStorage", "Remotes", "Extras", "Admin"},
        ChatMessage = {"ReplicatedStorage", "ChatMessage"},
        ServerMessage = {"ReplicatedStorage", "ServerMessage"},
    }
    for name, path in pairs(remotePaths) do
        Remotes[name] = SafeGet(path)
    end
end

InitRemotes()

-- ==========================================
-- GLOBAL STATE
-- ==========================================
getgenv().MM2_Apex = getgenv().MM2_Apex or {}

local State = {
    AutoKill = false,
    AutoKillRange = 30,
    KillMethod = "Knife",
    AutoGrab = false,
    AutoCoin = false,
    PlayerESP = false,
    WeaponESP = false,
    ESPColor = "Red",
    NoClip = false,
    WalkSpeed = 16,
    JumpPower = 50,
    InfJump = false,
    FlyEnabled = false,
    FlySpeed = 50,
    Aimlock = false,
    AimlockTarget = nil,
    GodMode = false,
    AntiAFK = false,
    Fullbright = false,
    RemoveFog = false,
    KillerESP = false,
    SheriffESP = false,
    InnocentESP = false,
    ShowRole = false,
    HitboxSize = 1,
    HitboxEnabled = false,
    AutoRejoin = false,
    ServerHop = false,
    Headless = false,
    Korblox = false,
    AvatarModsAllPlayers = false,
}

local ESPObjects = {}
local ESPConnections = {}
local NoClipConnections = {}
local HitboxObjects = {}
local FlyConnection = nil
local AimlockConnection = nil
local HeartbeatConnections = {}

-- ==========================================
-- COLOR MAPPING
-- ==========================================
local ESPColors = {
    Red = Color3.fromRGB(255, 0, 0),
    Green = Color3.fromRGB(0, 255, 0),
    Blue = Color3.fromRGB(0, 100, 255),
    Yellow = Color3.fromRGB(255, 255, 0),
    Purple = Color3.fromRGB(200, 0, 255),
    White = Color3.fromRGB(255, 255, 255),
    Cyan = Color3.fromRGB(0, 255, 255),
    Pink = Color3.fromRGB(255, 100, 200),
}

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================
local function GetCharacter()
    return LocalPlayer.Character
end

local function GetRootPart()
    local char = GetCharacter()
    if char then
        return char:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function GetHumanoid()
    local char = GetCharacter()
    if char then
        return char:FindFirstChild("Humanoid")
    end
    return nil
end

local function IsAlive(player)
    if not player then return false end
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false end
    return hum.Health > 0
end

local function GetDistance(part1, part2)
    if not part1 or not part2 then return math.huge end
    return (part1.Position - part2.Position).Magnitude
end

local function Notify(title, message, duration)
    pcall(function()
        Library:Notify(title, message, duration or 3)
    end)
end

-- ==========================================
-- TAB 1: COMBAT
-- ==========================================
local CombatTab = Window:CreateTab({
    Name = "Combat",
    Icon = "rbxassetid://122669828593160"
})

-- AUTO KILL
local AutoKillSection = CombatTab:CreateSection({ Name = "Auto Kill" })

AutoKillSection:CreateToggle({
    Name = "Enable Auto Kill",
    Default = false,
    Flag = "autokill_enabled",
    Callback = function(state)
        State.AutoKill = state
        Notify("Auto Kill", state and "Enabled" or "Disabled", 2)
    end
})

AutoKillSection:CreateSlider({
    Name = "Kill Range",
    Min = 5,
    Max = 200,
    Default = 30,
    Flag = "autokill_range",
    Callback = function(value)
        State.AutoKillRange = value
    end
})

AutoKillSection:CreateDropdown({
    Name = "Kill Method",
    Options = {"Knife", "Gun"},
    Default = "Knife",
    Flag = "kill_method",
    Callback = function(value)
        State.KillMethod = value
    end
})

-- AIMLOCK
local AimlockSection = CombatTab:CreateSection({ Name = "Aimlock" })

AimlockSection:CreateToggle({
    Name = "Enable Aimlock",
    Default = false,
    Flag = "aimlock_enabled",
    Callback = function(state)
        State.Aimlock = state
        if not state then
            State.AimlockTarget = nil
        end
        Notify("Aimlock", state and "Enabled" or "Disabled", 2)
    end
})

AimlockSection:CreateKeybind({
    Name = "Aimlock Key",
    Default = Enum.KeyCode.E,
    Callback = function()
        if not State.Aimlock then return end
        local rootPart = GetRootPart()
        if not rootPart then return end
        local nearest = nil
        local shortestDist = math.huge
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and IsAlive(player) then
                local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    local dist = GetDistance(rootPart, targetRoot)
                    if dist < shortestDist then
                        shortestDist = dist
                        nearest = player
                    end
                end
            end
        end
        State.AimlockTarget = nearest
        if nearest then
            Notify("Aimlock", "Locked: " .. nearest.Name, 2)
        end
    end
})

AimlockSection:CreateSlider({
    Name = "Aimlock Range",
    Min = 10,
    Max = 500,
    Default = 100,
    Flag = "aimlock_range",
    Callback = function(value)
        State.AimlockRange = value
    end
})

-- HITBOX
local HitboxSection = CombatTab:CreateSection({ Name = "Hitbox Expander" })

HitboxSection:CreateToggle({
    Name = "Enable Hitbox Expander",
    Default = false,
    Flag = "hitbox_enabled",
    Callback = function(state)
        State.HitboxEnabled = state
        if not state then
            ClearHitboxes()
        end
        Notify("Hitbox", state and "Enabled" or "Disabled", 2)
    end
})

HitboxSection:CreateSlider({
    Name = "Hitbox Size",
    Min = 1,
    Max = 20,
    Default = 5,
    Flag = "hitbox_size",
    Callback = function(value)
        State.HitboxSize = value
        if State.HitboxEnabled then
            UpdateHitboxes()
        end
    end
})

-- ==========================================
-- TAB 2: VISUALS
-- ==========================================
local VisualsTab = Window:CreateTab({
    Name = "Visuals",
    Icon = "rbxassetid://100050851789190"
})

-- ESP
local ESPSection = VisualsTab:CreateSection({ Name = "ESP Settings" })

ESPSection:CreateToggle({
    Name = "Player ESP",
    Default = false,
    Flag = "player_esp",
    Callback = function(state)
        State.PlayerESP = state
        if state then
            CreateESP()
        else
            ClearESP()
        end
    end
})

ESPSection:CreateToggle({
    Name = "Show Names",
    Default = true,
    Flag = "esp_names",
    Callback = function(value)
        State.ESPNames = value
        if State.PlayerESP then
            ClearESP()
            CreateESP()
        end
    end
})

ESPSection:CreateToggle({
    Name = "Show Distance",
    Default = true,
    Flag = "esp_distance",
    Callback = function(value)
        State.ESPDistance = value
        if State.PlayerESP then
            ClearESP()
            CreateESP()
        end
    end
})

ESPSection:CreateToggle({
    Name = "Show Health",
    Default = false,
    Flag = "esp_health",
    Callback = function(value)
        State.ESPHealth = value
        if State.PlayerESP then
            ClearESP()
            CreateESP()
        end
    end
})

ESPSection:CreateDropdown({
    Name = "ESP Color",
    Options = {"Red", "Green", "Blue", "Yellow", "Purple", "White", "Cyan", "Pink"},
    Default = "Red",
    Flag = "esp_color",
    Callback = function(value)
        State.ESPColor = value
        if State.PlayerESP then
            ClearESP()
            CreateESP()
        end
    end
})

ESPSection:CreateSlider({
    Name = "ESP Transparency",
    Min = 0,
    Max = 100,
    Default = 30,
    Flag = "esp_transparency",
    Callback = function(value)
        State.ESPTransparency = value / 100
        if State.PlayerESP then
            ClearESP()
            CreateESP()
        end
    end
})

ESPSection:CreateSlider({
    Name = "ESP Thickness",
    Min = 1,
    Max = 10,
    Default = 2,
    Flag = "esp_thickness",
    Callback = function(value)
        State.ESPThickness = value
        if State.PlayerESP then
            ClearESP()
            CreateESP()
        end
    end
})

-- WORLD VISUALS
local WorldSection = VisualsTab:CreateSection({ Name = "World" })

WorldSection:CreateToggle({
    Name = "Fullbright",
    Default = false,
    Flag = "fullbright",
    Callback = function(state)
        State.Fullbright = state
        if state then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 9e9
            Lighting.GlobalShadows = false
        else
            Lighting.Brightness = 1
            Lighting.ClockTime = 12
            Lighting.GlobalShadows = true
        end
    end
})

WorldSection:CreateToggle({
    Name = "Remove Fog",
    Default = false,
    Flag = "remove_fog",
    Callback = function(state)
        State.RemoveFog = state
        if state then
            Lighting.FogEnd = 9e9
            Lighting.FogStart = 9e9
        else
            Lighting.FogEnd = 100000
            Lighting.FogStart = 0
        end
    end
})

-- ==========================================
-- TAB 3: PLAYER MODS
-- ==========================================
local PlayerTab = Window:CreateTab({
    Name = "Player",
    Icon = "rbxassetid://16717281585"
})

local MovementSection = PlayerTab:CreateSection({ Name = "Movement" })

MovementSection:CreateSlider({
    Name = "Walk Speed",
    Min = 16,
    Max = 500,
    Default = 16,
    Flag = "walkspeed",
    Callback = function(value)
        State.WalkSpeed = value
        local hum = GetHumanoid()
        if hum then
            hum.WalkSpeed = value
        end
    end
})

MovementSection:CreateSlider({
    Name = "Jump Power",
    Min = 50,
    Max = 500,
    Default = 50,
    Flag = "jumppower",
    Callback = function(value)
        State.JumpPower = value
        local hum = GetHumanoid()
        if hum then
            hum.JumpPower = value
        end
    end
})

MovementSection:CreateToggle({
    Name = "Infinite Jump",
    Default = false,
    Flag = "inf_jump",
    Callback = function(state)
        State.InfJump = state
    end
})

MovementSection:CreateToggle({
    Name = "No Clip",
    Default = false,
    Flag = "noclip",
    Callback = function(state)
        State.NoClip = state
        if state then
            EnableNoClip()
        else
            DisableNoClip()
        end
    end
})

MovementSection:CreateToggle({
    Name = "Fly",
    Default = false,
    Flag = "fly_enabled",
    Callback = function(state)
        State.FlyEnabled = state
        if state then
            EnableFly()
        else
            DisableFly()
        end
    end
})

MovementSection:CreateSlider({
    Name = "Fly Speed",
    Min = 10,
    Max = 500,
    Default = 50,
    Flag = "fly_speed",
    Callback = function(value)
        State.FlySpeed = value
    end
})

local HealthSection = PlayerTab:CreateSection({ Name = "Health" })

HealthSection:CreateToggle({
    Name = "God Mode",
    Default = false,
    Flag = "god_mode",
    Callback = function(state)
        State.GodMode = state
        if state then
            local hum = GetHumanoid()
            if hum then
                hum.MaxHealth = math.huge
                hum.Health = math.huge
            end
        else
            local hum = GetHumanoid()
            if hum then
                hum.MaxHealth = 100
                hum.Health = 100
            end
        end
    end
})

HealthSection:CreateButton({
    Name = "Heal to Full",
    Callback = function()
        local hum = GetHumanoid()
        if hum then
            hum.Health = hum.MaxHealth
            Notify("Health", "Healed to full", 2)
        end
    end
})

-- ==========================================
-- TAB 4: TELEPORT
-- ==========================================
local TeleportTab = Window:CreateTab({
    Name = "Teleport",
    Icon = "rbxassetid://11049123456"
})

local TeleportSection = TeleportTab:CreateSection({ Name = "Player Teleport" })

TeleportSection:CreateButton({
    Name = "Teleport to Random Player",
    Callback = function()
        local players = Players:GetPlayers()
        local targets = {}
        for _, p in pairs(players) do
            if p ~= LocalPlayer and IsAlive(p) then
                table.insert(targets, p)
            end
        end
        if #targets > 0 then
            local target = targets[math.random(1, #targets)]
            local rootPart = GetRootPart()
            local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
            if rootPart and targetRoot then
                rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 5)
                Notify("Teleport", "Teleported to " .. target.Name, 2)
            end
        else
            Notify("Teleport", "No valid targets", 2)
        end
    end
})

TeleportSection:CreateButton({
    Name = "Teleport to Nearest Player",
    Callback = function()
        local rootPart = GetRootPart()
        if not rootPart then return end
        local nearest = nil
        local shortestDist = math.huge
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and IsAlive(player) then
                local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    local dist = GetDistance(rootPart, targetRoot)
                    if dist < shortestDist then
                        shortestDist = dist
                        nearest = player
                    end
                end
            end
        end
        if nearest then
            local targetRoot = nearest.Character:FindFirstChild("HumanoidRootPart")
            rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
            Notify("Teleport", "Teleported to " .. nearest.Name, 2)
        end
    end
})

local LocationSection = TeleportTab:CreateSection({ Name = "Saved Locations" })

local SavedLocations = {}
local LocationDropdown = nil

LocationSection:CreateButton({
    Name = "Save Current Position",
    Callback = function()
        local rootPart = GetRootPart()
        if rootPart then
            local posName = "Location_" .. tostring(#SavedLocations + 1)
            SavedLocations[posName] = rootPart.CFrame
            if LocationDropdown then
                LocationDropdown:Refresh(getLocationNames())
            end
            Notify("Teleport", "Saved: " .. posName, 2)
        end
    end
})

local function getLocationNames()
    local names = {}
    for name, _ in pairs(SavedLocations) do
        table.insert(names, name)
    end
    return names
end

LocationDropdown = LocationSection:CreateDropdown({
    Name = "Saved Positions",
    Options = {},
    Default = "",
    Flag = "saved_positions",
    Callback = function(value)
        local rootPart = GetRootPart()
        if rootPart and SavedLocations[value] then
            rootPart.CFrame = SavedLocations[value]
            Notify("Teleport", "Teleported to " .. value, 2)
        end
    end
})

LocationSection:CreateButton({
    Name = "Clear Saved Positions",
    Callback = function()
        SavedLocations = {}
        if LocationDropdown then
            LocationDropdown:Refresh({})
        end
        Notify("Teleport", "Cleared all saved positions", 2)
    end
})

-- ==========================================
-- TAB 5: UTILITIES
-- ==========================================
local UtilsTab = Window:CreateTab({
    Name = "Utilities",
    Icon = "rbxassetid://120959262762131"
})

local ServerSection = UtilsTab:CreateSection({ Name = "Server" })

ServerSection:CreateButton({
    Name = "Copy Job ID",
    Callback = function()
        if setclipboard then
            setclipboard(game.JobId)
            Notify("Copied", "Job ID copied to clipboard", 3)
        else
            Notify("Error", "Clipboard not available", 3)
        end
    end
})

ServerSection:CreateButton({
    Name = "Copy Game ID",
    Callback = function()
        if setclipboard then
            setclipboard(tostring(game.PlaceId))
            Notify("Copied", "Game ID copied to clipboard", 3)
        else
            Notify("Error", "Clipboard not available", 3)
        end
    end
})

ServerSection:CreateButton({
    Name = "Rejoin Server",
    Callback = function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
})

ServerSection:CreateToggle({
    Name = "Auto Rejoin on Disconnect",
    Default = false,
    Flag = "auto_rejoin",
    Callback = function(state)
        State.AutoRejoin = state
    end
})

ServerSection:CreateToggle({
    Name = "Anti-AFK",
    Default = false,
    Flag = "anti_afk",
    Callback = function(state)
        State.AntiAFK = state
        if state then
            LocalPlayer.Idled:Connect(function()
                game:GetService("VirtualUser"):CaptureController()
                game:GetService("VirtualUser"):ClickButton2(Vector2.new())
            end)
        end
    end
})

local DataSection = UtilsTab:CreateSection({ Name = "Data" })

DataSection:CreateButton({
    Name = "Get Full Inventory",
    Callback = function()
        if Remotes.GetFullInventory then
            local success, data = pcall(function()
                return Remotes.GetFullInventory:InvokeServer()
            end)
            if success then
                Notify("Inventory", "Check console (F9)", 3)
                print("=== INVENTORY DATA ===")
                print(HttpService:JSONEncode(data))
                print("======================")
            else
                Notify("Error", "Failed to get inventory", 3)
            end
        else
            Notify("Error", "Remote not found", 3)
        end
    end
})

DataSection:CreateButton({
    Name = "Get Player Data",
    Callback = function()
        if Remotes.GetPlayerData then
            local success, data = pcall(function()
                return Remotes.GetPlayerData:InvokeServer()
            end)
            if success then
                Notify("Player Data", "Check console (F9)", 3)
                print("=== PLAYER DATA ===")
                print(HttpService:JSONEncode(data))
                print("===================")
            else
                Notify("Error", "Failed to get player data", 3)
            end
        else
            Notify("Error", "Remote not found", 3)
        end
    end
})

DataSection:CreateButton({
    Name = "Server Hop",
    Callback = function()
        local HttpService = game:GetService("HttpService")
        local success, response = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        if success and response.data then
            for _, server in pairs(response.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                    break
                end
            end
        end
    end
})

-- ==========================================
-- TAB 6: MISC
-- ==========================================
local MiscTab = Window:CreateTab({
    Name = "Misc",
    Icon = "rbxassetid://16717281585"
})

-- Constants
local HEADLESS_MESH_ID = "rbxassetid://1095708"
local KORBLOX_MESH_ID = "rbxassetid://101851696"
local KORBLOX_COLOR = Color3.fromRGB(50, 50, 50)

local function ApplyHeadless(character)
    if not character then return end
    local head = character:FindFirstChild("Head")
    if not head then return end

    head.Transparency = 1
    head.CanCollide = false

    local face = head:FindFirstChild("face")
    if face then face:Destroy() end

    local existingMesh = head:FindFirstChild("HeadlessMesh")
    if not existingMesh then
        local mesh = Instance.new("SpecialMesh")
        mesh.Name = "HeadlessMesh"
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = HEADLESS_MESH_ID
        mesh.Scale = Vector3.new(0.001, 0.001, 0.001)
        mesh.Parent = head
    end

    head:GetPropertyChangedSignal("Transparency"):Connect(function()
        if head.Transparency ~= 1 then
            head.Transparency = 1
        end
    end)

    head.ChildAdded:Connect(function(child)
        if child.Name == "face" and child:IsA("Decal") then
            child:Destroy()
        end
    end)
end

local function ApplyKorblox(character)
    if not character then return end
    local rightLeg = character:FindFirstChild("Right Leg") or character:FindFirstChild("RightUpperLeg")
    if not rightLeg then return end

    rightLeg.Color = KORBLOX_COLOR

    local existingMesh = rightLeg:FindFirstChild("KorbloxMesh")
    if not existingMesh then
        for _, child in ipairs(rightLeg:GetChildren()) do
            if child:IsA("SpecialMesh") or child:IsA("CharacterMesh") then
                if child.Name ~= "KorbloxMesh" then
                    child:Destroy()
                end
            end
        end

        local korbloxMesh = Instance.new("SpecialMesh")
        korbloxMesh.Name = "KorbloxMesh"
        korbloxMesh.MeshType = Enum.MeshType.FileMesh
        korbloxMesh.MeshId = KORBLOX_MESH_ID
        korbloxMesh.Scale = Vector3.new(1, 1, 1)
        korbloxMesh.Parent = rightLeg
    end

    rightLeg:GetPropertyChangedSignal("Color"):Connect(function()
        if rightLeg.Color ~= KORBLOX_COLOR then
            rightLeg.Color = KORBLOX_COLOR
        end
    end)
end

local function ApplyAvatarMods(character)
    if not character then return end
    if State.Headless then
        ApplyHeadless(character)
    end
    if State.Korblox then
        ApplyKorblox(character)
    end
end

local AvatarSection = MiscTab:CreateSection({ Name = "Avatar Mods" })

AvatarSection:CreateToggle({
    Name = "Headless Head",
    Default = false,
    Flag = "headless_head",
    Callback = function(state)
        State.Headless = state
        ApplyAvatarMods(LocalPlayer.Character)
        if State.AvatarModsAllPlayers then
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then ApplyAvatarMods(p.Character) end
            end
        end
        Notify("Avatar Mods", "Headless " .. (state and "Enabled" or "Disabled"), 2)
    end
})

AvatarSection:CreateToggle({
    Name = "Korblox Leg",
    Default = false,
    Flag = "korblox_leg",
    Callback = function(state)
        State.Korblox = state
        ApplyAvatarMods(LocalPlayer.Character)
        if State.AvatarModsAllPlayers then
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then ApplyAvatarMods(p.Character) end
            end
        end
        Notify("Avatar Mods", "Korblox " .. (state and "Enabled" or "Disabled"), 2)
    end
})

AvatarSection:CreateToggle({
    Name = "Apply to All Players",
    Default = false,
    Flag = "avatar_all_players",
    Callback = function(state)
        State.AvatarModsAllPlayers = state
        for _, p in pairs(Players:GetPlayers()) do
            ApplyAvatarMods(p.Character)
        end
        Notify("Avatar Mods", "Global application " .. (state and "Enabled" or "Disabled"), 2)
    end
})

local MiscSection = MiscTab:CreateSection({ Name = "Miscellaneous" })

MiscSection:CreateButton({
    Name = "Toggle Fog",
    Callback = function()
        if Lighting.FogEnd > 1000 then
            Lighting.FogEnd = 100000
        else
            Lighting.FogEnd = 9e9
        end
    end
})

MiscSection:CreateButton({
    Name = "Set Day Time",
    Callback = function()
        Lighting.ClockTime = 14
    end
})

MiscSection:CreateButton({
    Name = "Set Night Time",
    Callback = function()
        Lighting.ClockTime = 0
    end
})

MiscSection:CreateButton({
    Name = "Force Respawn",
    Callback = function()
        local hum = GetHumanoid()
        if hum then
            hum.Health = 0
        end
    end
})

-- ==========================================
-- TAB 7: SETTINGS
-- ==========================================
local SettingsTab = Window:CreateTab({
    Name = "Settings",
    Icon = "rbxassetid://120959262762131"
})

local ConfigSection = SettingsTab:CreateSection({ Name = "Configuration" })

ConfigSection:CreateButton({
    Name = "Save Config",
    Callback = function()
        local config = {}
        for key, value in pairs(State) do
            config[key] = value
        end
        if writefile then
            writefile("MM2_Apex_Config.json", HttpService:JSONEncode(config))
            Notify("Config", "Saved successfully", 3)
        end
    end
})

ConfigSection:CreateButton({
    Name = "Load Config",
    Callback = function()
        if readfile then
            local success, content = pcall(function()
                return readfile("MM2_Apex_Config.json")
            end)
            if success and content then
                local config = HttpService:JSONDecode(content)
                for key, value in pairs(config) do
                    State[key] = value
                end
                Notify("Config", "Loaded successfully", 3)
            end
        end
    end
})

ConfigSection:CreateButton({
    Name = "Reset to Defaults",
    Callback = function()
        State.AutoKill = false
        State.AutoKillRange = 30
        State.KillMethod = "Knife"
        State.AutoGrab = false
        State.AutoCoin = false
        State.PlayerESP = false
        State.NoClip = false
        State.WalkSpeed = 16
        State.JumpPower = 50
        State.InfJump = false
        State.FlyEnabled = false
        State.GodMode = false
        State.HitboxEnabled = false
        State.Headless = false
        State.Korblox = false
        ClearESP()
        ClearHitboxes()
        DisableNoClip()
        DisableFly()
        Notify("Config", "Reset to defaults", 3)
    end
})

ConfigSection:CreateKeybind({
    Name = "Toggle UI",
    Default = Enum.KeyCode.RightControl,
    Callback = function()
        Window:Toggle()
    end
})

ConfigSection:CreateKeybind({
    Name = "Destroy Script",
    Default = Enum.KeyCode.Delete,
    Callback = function()
        ClearESP()
        ClearHitboxes()
        DisableNoClip()
        DisableFly()
        for _, conn in pairs(HeartbeatConnections) do
            pcall(function() conn:Disconnect() end)
        end
        Window:Destroy()
    end
})

-- ==========================================
-- SHOW UI
-- ==========================================
Window:Show()

-- ==========================================
-- COMBAT LOGIC
-- ==========================================
local function GetNearestTarget(maxRange)
    local nearest = nil
    local shortestDist = maxRange or math.huge
    local rootPart = GetRootPart()
    if not rootPart then return nil end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local dist = GetDistance(rootPart, targetRoot)
                if dist < shortestDist then
                    shortestDist = dist
                    nearest = player
                end
            end
        end
    end
    return nearest
end

table.insert(HeartbeatConnections, RunService.Heartbeat:Connect(function()
    if not State.AutoKill then return end
    local target = GetNearestTarget(State.AutoKillRange)
    if target then
        if State.KillMethod == "Knife" and Remotes.KnifeKill then
            pcall(function()
                Remotes.KnifeKill:Fire(target)
            end)
        elseif State.KillMethod == "Gun" and Remotes.GunKill then
            pcall(function()
                Remotes.GunKill:Fire(target)
            end)
        end
    end
end))

-- AIMLOCK LOGIC
table.insert(HeartbeatConnections, RunService.Heartbeat:Connect(function()
    if not State.Aimlock or not State.AimlockTarget then return end
    if not IsAlive(State.AimlockTarget) then
        State.AimlockTarget = nil
        return
    end
    local rootPart = GetRootPart()
    local targetRoot = State.AimlockTarget.Character:FindFirstChild("HumanoidRootPart")
    if rootPart and targetRoot then
        rootPart.CFrame = CFrame.new(rootPart.Position, targetRoot.Position)
    end
end))

-- AUTO GRAB LOGIC
table.insert(HeartbeatConnections, RunService.Heartbeat:Connect(function()
    if not State.AutoGrab then return end
    local rootPart = GetRootPart()
    if not rootPart then return end
    for _, tool in pairs(Workspace:GetDescendants()) do
        if tool:IsA("Tool") and tool:FindFirstChild("Handle") then
            local dist = GetDistance(rootPart, tool.Handle)
            if dist < 15 then
                if Remotes.GiveWeapon then
                    pcall(function()
                        Remotes.GiveWeapon:FireServer(tool)
                    end)
                end
                break
            end
        end
    end
end))

-- AUTO COIN LOGIC
table.insert(HeartbeatConnections, RunService.Heartbeat:Connect(function()
    if not State.AutoCoin then return end
    local rootPart = GetRootPart()
    if not rootPart then return end
    for _, coin in pairs(Workspace:GetDescendants()) do
        if coin:IsA("BasePart") and coin.Name:lower():find("coin") then
            local dist = GetDistance(rootPart, coin)
            if dist < 25 then
                if Remotes.GetCoin then
                    pcall(function()
                        Remotes.GetCoin:FireServer(coin)
                    end)
                end
                break
            end
        end
    end
end))

-- ==========================================
-- ESP SYSTEM
-- ==========================================
function GetESPColor()
    return ESPColors[State.ESPColor] or Color3.fromRGB(255, 0, 0)
end

function CreateESP()
    ClearESP()
    local color = GetESPColor()
    local transparency = State.ESPTransparency or 0.3

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char then
                local highlight = Instance.new("Highlight")
                highlight.Name = "ESP_Highlight"
                highlight.Parent = char
                highlight.FillColor = color
                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                highlight.FillTransparency = transparency
                highlight.OutlineTransparency = 0.5
                ESPObjects[player] = {highlight = highlight}

                local head = char:FindFirstChild("Head")
                if head then
                    local billboard = Instance.new("BillboardGui")
                    billboard.Name = "ESP_NameTag"
                    billboard.Parent = head
                    billboard.Size = UDim2.new(0, 150, 0, 50)
                    billboard.Adornee = head
                    billboard.StudsOffset = Vector3.new(0, 2, 0)
                    billboard.AlwaysOnTop = true

                    local nameFrame = Instance.new("Frame")
                    nameFrame.Parent = billboard
                    nameFrame.Size = UDim2.new(1, 0, 0, 20)
                    nameFrame.Position = UDim2.new(0, 0, 0, 0)
                    nameFrame.BackgroundTransparency = 1

                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Parent = nameFrame
                    nameLabel.Size = UDim2.new(1, 0, 1, 0)
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.Text = player.Name
                    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    nameLabel.TextScaled = true
                    nameLabel.Font = Enum.Font.GothamBold
                    nameLabel.TextStrokeTransparency = 0
                    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

                    ESPObjects[player].billboard = billboard
                    ESPObjects[player].nameLabel = nameLabel

                    if State.ESPDistance or State.ESPHealth then
                        local infoFrame = Instance.new("Frame")
                        infoFrame.Parent = billboard
                        infoFrame.Size = UDim2.new(1, 0, 0, 20)
                        infoFrame.Position = UDim2.new(0, 0, 0, 25)
                        infoFrame.BackgroundTransparency = 1

                        local infoLabel = Instance.new("TextLabel")
                        infoLabel.Parent = infoFrame
                        infoLabel.Size = UDim2.new(1, 0, 1, 0)
                        infoLabel.BackgroundTransparency = 1
                        infoLabel.TextColor3 = color
                        infoLabel.TextScaled = true
                        infoLabel.Font = Enum.Font.Gotham
                        infoLabel.TextStrokeTransparency = 0
                        infoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

                        ESPObjects[player].infoLabel = infoLabel
                    end
                end
            end
        end
    end
end

function ClearESP()
    for player, objects in pairs(ESPObjects) do
        if objects.highlight then
            pcall(function() objects.highlight:Destroy() end)
        end
        if objects.billboard then
            pcall(function() objects.billboard:Destroy() end)
        end
    end
    ESPObjects = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            for _, child in pairs(player.Character:GetChildren()) do
                if child.Name:find("ESP_") then
                    pcall(function() child:Destroy() end)
                end
            end
            local head = player.Character:FindFirstChild("Head")
            if head then
                for _, child in pairs(head:GetChildren()) do
                    if child.Name:find("ESP_") then
                        pcall(function() child:Destroy() end)
                    end
                end
            end
        end
    end
end

table.insert(HeartbeatConnections, RunService.Heartbeat:Connect(function()
    if not State.PlayerESP then return end
    local rootPart = GetRootPart()
    for player, objects in pairs(ESPObjects) do
        if player and player.Character and IsAlive(player) then
            if objects.infoLabel and rootPart then
                local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    local dist = GetDistance(rootPart, targetRoot)
                    local hum = player.Character:FindFirstChild("Humanoid")
                    local info = ""
                    if State.ESPDistance then
                        info = info .. string.format("[%dm]", math.floor(dist))
                    end
                    if State.ESPHealth and hum then
                        info = info .. string.format(" HP:%d", math.floor(hum.Health))
                    end
                    objects.infoLabel.Text = info
                end
            end
            if objects.highlight then
                objects.highlight.FillColor = GetESPColor()
            end
        end
    end
end))

-- ==========================================
-- HITBOX EXPANDER
-- ==========================================
function ClearHitboxes()
    for player, hitbox in pairs(HitboxObjects) do
        pcall(function() hitbox:Destroy() end)
    end
    HitboxObjects = {}
end

function UpdateHitboxes()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if humRoot then
                if not HitboxObjects[player] or not HitboxObjects[player]:FindFirstAncestor(player.Character) then
                    if HitboxObjects[player] then
                        pcall(function() HitboxObjects[player]:Destroy() end)
                    end
                    local hitbox = Instance.new("Part")
                    hitbox.Name = "Hitbox_Expanded"
                    hitbox.Size = Vector3.new(State.HitboxSize, State.HitboxSize, State.HitboxSize)
                    hitbox.CFrame = humRoot.CFrame
                    hitbox.Anchored = true
                    hitbox.CanCollide = false
                    hitbox.Transparency = 0.5
                    hitbox.Color = Color3.fromRGB(255, 0, 0)
                    hitbox.Material = Enum.Material.ForceField
                    hitbox.Parent = player.Character
                    HitboxObjects[player] = hitbox
                else
                    HitboxObjects[player].Size = Vector3.new(State.HitboxSize, State.HitboxSize, State.HitboxSize)
                end
            end
        end
    end
end

table.insert(HeartbeatConnections, RunService.Heartbeat:Connect(function()
    if not State.HitboxEnabled then return end
    UpdateHitboxes()
end))

-- ==========================================
-- NO CLIP
-- ==========================================
function EnableNoClip()
    DisableNoClip()
    local char = GetCharacter()
    if not char then return end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            local conn = part:GetPropertyChangedSignal("CanCollide"):Connect(function()
                part.CanCollide = false
            end)
            table.insert(NoClipConnections, conn)
            part.CanCollide = false
        end
    end
    table.insert(NoClipConnections, RunService.Stepped:Connect(function()
        local c = GetCharacter()
        if c then
            for _, part in pairs(c:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end))
end

function DisableNoClip()
    for _, conn in pairs(NoClipConnections) do
        pcall(function() conn:Disconnect() end)
    end
    NoClipConnections = {}
end

-- ==========================================
-- FLY SYSTEM
-- ==========================================
function EnableFly()
    DisableFly()
    local rootPart = GetRootPart()
    if not rootPart then return end
    local camera = Workspace.CurrentCamera
    FlyConnection = RunService.RenderStepped:Connect(function()
        local rootPart = GetRootPart()
        if not rootPart then return end
        local camera = Workspace.CurrentCamera
        local moveVector = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveVector = moveVector + camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveVector = moveVector - camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveVector = moveVector - camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveVector = moveVector + camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveVector = moveVector + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveVector = moveVector - Vector3.new(0, 1, 0)
        end
        rootPart.Velocity = moveVector * State.FlySpeed
    end)
end

function DisableFly()
    if FlyConnection then
        pcall(function() FlyConnection:Disconnect() end)
        FlyConnection = nil
    end
    local rootPart = GetRootPart()
    if rootPart then
        rootPart.Velocity = Vector3.new(0, 0, 0)
    end
end

-- ==========================================
-- INFINITE JUMP
-- ==========================================
UserInputService.JumpRequest:Connect(function()
    if State.InfJump then
        local hum = GetHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- ==========================================
-- RESPAWN HANDLER
-- ==========================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    local hum = GetHumanoid()
    if hum then
        hum.WalkSpeed = State.WalkSpeed
        hum.JumpPower = State.JumpPower
        if State.GodMode then
            hum.MaxHealth = math.huge
            hum.Health = math.huge
        end
    end
    if State.NoClip then
        EnableNoClip()
    end
    if State.PlayerESP then
        CreateESP()
    end
    if State.FlyEnabled then
        EnableFly()
    end
    if State.Headless or State.Korblox then
        ApplyAvatarMods(GetCharacter())
    end
end)

-- ==========================================
-- PLAYER JOIN/LEAVE HANDLERS
-- ==========================================
Players.PlayerAdded:Connect(function(player)
    if State.PlayerESP then
        player.CharacterAdded:Connect(function()
            task.wait(0.5)
            if State.PlayerESP then
                CreateESP()
            end
        end)
    end
    if State.AvatarModsAllPlayers then
        player.CharacterAdded:Connect(function()
            task.wait(0.5)
            ApplyAvatarMods(player.Character)
        end)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        if ESPObjects[player].highlight then
            pcall(function() ESPObjects[player].highlight:Destroy() end)
        end
        if ESPObjects[player].billboard then
            pcall(function() ESPObjects[player].billboard:Destroy() end)
        end
        ESPObjects[player] = nil
    end
    if HitboxObjects[player] then
        pcall(function() HitboxObjects[player]:Destroy() end)
        HitboxObjects[player] = nil
    end
    if State.AimlockTarget == player then
        State.AimlockTarget = nil
    end
end)

-- ==========================================
-- SERVER MESSAGE HANDLER
-- ==========================================
if Remotes.ServerMessage then
    pcall(function()
        Remotes.ServerMessage.OnClientEvent:Connect(function(message)
            Notify("Server", tostring(message), 4)
        end)
    end)
end

if Remotes.GunBeam then
    pcall(function()
        Remotes.GunBeam.OnClientEvent:Connect(function(origin, target)
            local part = Instance.new("Part")
            part.Material = Enum.Material.Neon
            part.Color = Color3.fromRGB(255, 255, 0)
            part.Anchored = true
            part.CanCollide = false
            part.Size = Vector3.new(0.2, 0.2, (origin - target).Magnitude)
            part.CFrame = CFrame.new(origin, target) * CFrame.new(0, 0, -part.Size.Z / 2)
            part.Parent = Workspace
            game:GetService("Debris"):AddItem(part, 0.5)
        end)
    end)
end

-- ==========================================
-- AUTO REJOIN
-- ==========================================
game:GetService("CoreGui").RobloxPromptGui.promptChildTriggered:Connect(function()
    if State.AutoRejoin then
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
end)

-- ==========================================
-- INITIALIZATION
-- ==========================================
Notify("MM2 Apex v2", "Loaded successfully", 5)
print("=== MM2 Apex v2 ===")
print("Remotes found:")
for name, remote in pairs(Remotes) do
    print("  " .. name .. ": " .. (remote and "FOUND" or "MISSING"))
end
print("==================")
