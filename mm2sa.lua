--[[
  Angeli UI Library v5.0 - Full Rebuild
  Features:
    - Working Minimization (Smooth animation, collapses to header)
    - Built-in FPS & Ping Overlays
    - Custom Background Support (Image URL/ID, Transparency, Blur)
    - Dark/Light Theme Support (Applies instantly)
    - Per-Toggle Keybinds & UI Toggle Keybind
    - Modular Groupboxes & Tabs
]]

local AngeliUI = {}
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

-- ─── CONFIG STORAGE ───
local ConfigData = {
    BackgroundImage = "",
    BackgroundTransparency = 0,
    OverlayTransparency = 0.3,
    BlurAmount = 0,
    Theme = "dark",
    ShowFPS = false,
    ShowPing = false,
}

-- ─── THEMES ───
local Themes = {
    dark = {
        Background   = Color3.fromRGB(17, 17, 17),
        Group        = Color3.fromRGB(22, 22, 22),
        GroupStroke  = Color3.fromRGB(43, 43, 43),
        Control      = Color3.fromRGB(40, 40, 40),
        ControlHover = Color3.fromRGB(50, 50, 50),
        Divider      = Color3.fromRGB(32, 32, 32),
        Text         = Color3.fromRGB(229, 229, 232),
        TextDim      = Color3.fromRGB(158, 158, 164),
        TextSoft     = Color3.fromRGB(214, 214, 218),
        HeaderText   = Color3.fromRGB(140, 140, 146),
        TabSelected  = Color3.fromRGB(30, 30, 30),
        TabHover     = Color3.fromRGB(26, 26, 26),
        PillOff      = Color3.fromRGB(42, 42, 42),
        KnobOff      = Color3.fromRGB(216, 216, 216),
        PillOn       = Color3.fromRGB(236, 236, 236),
        KnobOn       = Color3.fromRGB(18, 18, 20),
        SliderTrack  = Color3.fromRGB(45, 45, 45),
        SliderFill   = Color3.fromRGB(255, 255, 255),
    },
    light = {
        Background   = Color3.fromRGB(240, 240, 245),
        Group        = Color3.fromRGB(255, 255, 255),
        GroupStroke  = Color3.fromRGB(200, 200, 205),
        Control      = Color3.fromRGB(235, 235, 240),
        ControlHover = Color3.fromRGB(220, 220, 225),
        Divider      = Color3.fromRGB(210, 210, 215),
        Text         = Color3.fromRGB(20, 20, 25),
        TextDim      = Color3.fromRGB(100, 100, 110),
        TextSoft     = Color3.fromRGB(50, 50, 55),
        HeaderText   = Color3.fromRGB(120, 120, 130),
        TabSelected  = Color3.fromRGB(230, 230, 235),
        TabHover     = Color3.fromRGB(220, 220, 225),
        PillOff      = Color3.fromRGB(200, 200, 205),
        KnobOff      = Color3.fromRGB(60, 60, 65),
        PillOn       = Color3.fromRGB(80, 80, 85),
        KnobOn       = Color3.fromRGB(240, 240, 245),
        SliderTrack  = Color3.fromRGB(200, 200, 205),
        SliderFill   = Color3.fromRGB(40, 40, 45),
    }
}

local Theme = Themes.dark

-- ─── HELPERS ───
local function New(className, props, children)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            inst[k] = v
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    if props and props.Parent ~= nil then
        inst.Parent = props.Parent
    end
    return inst
end

local function Tween(obj, info, props)
    TweenService:Create(obj, info or TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function Corner(parent, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function Stroke(parent, color, transparency)
    return New("UIStroke", {
        Color = color or Theme.GroupStroke,
        Transparency = transparency or 0,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function Pad(parent, top, bottom, left, right)
    return New("UIPadding", {
        PaddingTop    = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        PaddingLeft   = UDim.new(0, left or 0),
        PaddingRight  = UDim.new(0, right or 0),
        Parent = parent,
    })
end

local function round(num, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- ─── MAIN LIBRARY ───
function AngeliUI:CreateWindow(opts)
    opts = opts or {}
    local title = opts.Title or "Angeli UI"
    local size  = opts.Size or UDim2.fromOffset(660, 450)
    
    if opts.SaveConfig ~= false then
        pcall(function()
            local saved = readfile and readfile("AngeliUI_Config.json")
            if saved then
                local data = HttpService:JSONDecode(saved)
                for k, v in pairs(data) do
                    ConfigData[k] = v
                end
            end
        end)
    end
    
    local guiParent
    pcall(function()
        if gethui then guiParent = gethui() end
    end)
    if not guiParent then
        local ok, core = pcall(function() return game:GetService("CoreGui") end)
        if ok and core then
            local ok2 = pcall(function()
                local t = Instance.new("Folder") t.Parent = core t:Destroy()
            end)
            if ok2 then guiParent = core end
        end
    end
    if not guiParent then
        guiParent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    local old = guiParent:FindFirstChild("AngeliUI")
    if old then old:Destroy() end
    
    local Gui = New("ScreenGui", {
        Name = "AngeliUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = guiParent,
    })
    
    -- ─── BACKGROUND SYSTEM ───
    local BackgroundContainer = New("Frame", {
        Name = "BackgroundContainer",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Parent = Gui,
    })
    
    local BackgroundImage = New("ImageLabel", {
        Name = "BackgroundImage",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Image = ConfigData.BackgroundImage or "",
        ImageColor3 = Color3.new(1, 1, 1),
        ImageTransparency = ConfigData.BackgroundTransparency or 0,
        ScaleType = Enum.ScaleType.Crop,
        Visible = ConfigData.BackgroundImage and ConfigData.BackgroundImage ~= "",
        Parent = BackgroundContainer,
    })
    
    local BackgroundOverlay = New("Frame", {
        Name = "BackgroundOverlay",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = ConfigData.OverlayTransparency or 0.3,
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Visible = (ConfigData.OverlayTransparency or 0) > 0,
        Parent = BackgroundContainer,
    })
    
    local Blur = nil
    if ConfigData.BlurAmount and ConfigData.BlurAmount > 0 then
        Blur = New("BlurEffect", {
            Name = "Blur",
            Size = ConfigData.BlurAmount,
            Parent = BackgroundContainer,
        })
    end
    
    -- ─── MAIN UI ───
    local Main = New("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = size,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = Gui,
    })
    Corner(Main, 12)
    Stroke(Main, Theme.GroupStroke, 0.4)
    
    local Texture = New("ImageLabel", {
        Name = "Texture",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Image = "rbxassetid://9968344227",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 0.88,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.new(0, 128, 0, 128),
        ZIndex = 0,
        Parent = Main,
    })
    
    local uiScale = New("UIScale", { Scale = 0.96, Parent = Main })
    
    -- ─── HEADER ───
    local Header = New("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = Main,
    })
    
    local TitleLabel = New("TextLabel", {
        Name = "Title",
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -70, 1, 0),
        BackgroundTransparency = 1,
        Text = title,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = Header,
    })
    
    -- ─── HEADER BUTTONS ───
    local MinimizeBtn = New("TextButton", {
        Name = "Minimize",
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -56, 0.5, -12),
        BackgroundColor3 = Theme.Control,
        Text = "-",
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = Theme.Text,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = Header,
    })
    Corner(MinimizeBtn, 6)

    local CloseBtn = New("TextButton", {
        Name = "Close",
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -28, 0.5, -12),
        BackgroundColor3 = Color3.fromRGB(200, 50, 50),
        Text = "x",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = Header,
    })
    Corner(CloseBtn, 6)
    
    -- ─── DRAG LOGIC ───
    local dragConn
    do
        local dragging = false
        local dragStart, startPos
        local dragScaleX, dragScaleY = 0.5, 0.5
        local targetX, targetY, displayX, displayY
        local DRAG_SMOOTH = opts.DragSmooth or 14
        
        Header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = Main.Position
                dragScaleX, dragScaleY = startPos.X.Scale, startPos.Y.Scale
                targetX, targetY = startPos.X.Offset, startPos.Y.Offset
                displayX, displayY = targetX, targetY
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                targetX = startPos.X.Offset + delta.X
                targetY = startPos.Y.Offset + delta.Y
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        
        dragConn = RunService.RenderStepped:Connect(function(dt)
            if displayX == nil then return end
            local dx = targetX - displayX
            local dy = targetY - displayY
            if not dragging and math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then
                Main.Position = UDim2.new(dragScaleX, targetX, dragScaleY, targetY)
                displayX = nil
                return
            end
            local step = math.min(1, dt * DRAG_SMOOTH)
            displayX += dx * step
            displayY += dy * step
            Main.Position = UDim2.new(dragScaleX, displayX, dragScaleY, displayY)
        end)
    end
    
    -- ─── SIDEBAR ───
    local Sidebar = New("ScrollingFrame", {
        Name = "Sidebar",
        Position = UDim2.new(0, 0, 0, 47),
        Size = UDim2.new(0, 160, 1, -47),
        BackgroundTransparency = 1,
        ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = Main,
    })
    Pad(Sidebar, 10, 10, 10, 10)
    New("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Sidebar,
    })
    
    local SidebarFX = New("Frame", {
        Name = "SidebarFX",
        Position = UDim2.new(0, 0, 0, 47),
        Size = UDim2.new(0, 160, 1, -47),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = Main,
    })
    
    local Indicator = New("Frame", {
        Name = "TabIndicator",
        Size = UDim2.new(0, 3, 0, 16),
        Position = UDim2.new(0, 13, 0, 0),
        BackgroundColor3 = Theme.Text,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 5,
        Parent = SidebarFX,
    })
    Corner(Indicator, 2)
    
    -- ─── CONTENT ───
    local Content = New("Frame", {
        Name = "Content",
        Position = UDim2.new(0, 161, 0, 47),
        Size = UDim2.new(1, -161, 1, -47),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = Main,
    })
    Pad(Content, 12, 12, 12, 12)
    
    -- ─── NOTIFICATIONS ───
    local NotifyHolder = New("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -14, 1, -14),
        Size = UDim2.new(0, 250, 1, -28),
        BackgroundTransparency = 1,
        Parent = Gui,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Parent = NotifyHolder,
    })
    
    -- ─── OVERLAYS (FPS / PING) ───
    local OverlayHolder = New("Frame", {
        Name = "Overlays",
        Position = UDim2.new(0, 10, 0, 10),
        Size = UDim2.new(0, 100, 0, 30),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = Gui,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = OverlayHolder,
    })

    local FPSLabel = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = "FPS: 0",
        Font = Enum.Font.Code,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = false,
        Parent = OverlayHolder,
    })

    local PingLabel = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = "Ping: 0ms",
        Font = Enum.Font.Code,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = false,
        Parent = OverlayHolder,
    })

    local frames = 0
    local lastUpdate = tick()
    RunService.RenderStepped:Connect(function()
        frames += 1
        if tick() - lastUpdate >= 1 then
            FPSLabel.Text = "FPS: " .. frames
            frames = 0
            lastUpdate = tick()
        end
    end)

    task.spawn(function()
        while task.wait(1) do
            local pingVal = Stats:FindFirstChild("Network")
            if pingVal then
                local serverStats = pingVal:FindFirstChild("ServerStatsItem")
                if serverStats and serverStats:FindFirstChild("Value") then
                    PingLabel.Text = "Ping: " .. math.round(serverStats.Value) .. "ms"
                else
                    PingLabel.Text = "Ping: N/A"
                end
            else
                PingLabel.Text = "Ping: N/A"
            end
        end
    end)

    local function updateOverlays()
        FPSLabel.Visible = ConfigData.ShowFPS
        PingLabel.Visible = ConfigData.ShowPing
        OverlayHolder.Visible = ConfigData.ShowFPS or ConfigData.ShowPing
    end
    updateOverlays()
    
    -- ─── WINDOW API ───
    local Window = {}
    local sidebarOrder = 0
    local seenSections = {}
    local tabs = {}
    local keybinds = {}
    local rebinding = nil
    local currentTab = nil
    local uiVisible = false
    local isMinimized = false
    local indicatorConn = nil
    local smoothSliders = {}
    local SMOOTH_SPEED = 12
    
    local heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        local step = math.min(1, dt * SMOOTH_SPEED)
        for slider in pairs(smoothSliders) do
            local diff = slider.Target - slider.Display
            if math.abs(diff) < 0.0005 then
                slider.Display = slider.Target
                slider.Render()
                if not slider.Dragging then
                    smoothSliders[slider] = nil
                end
            else
                slider.Display = slider.Display + diff * step
                slider.Render()
            end
        end
    end)
    
    -- ─── VISIBILITY & MINIMIZE ───
    local function setVisible(visible, instant)
        uiVisible = visible
        if instant then
            Main.Visible = visible
            Main.BackgroundTransparency = visible and 0 or 1
            uiScale.Scale = visible and 1 or 0.96
            return
        end
        if visible then
            Main.Visible = true
            Tween(Main, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0 })
            Tween(uiScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
        else
            Tween(Main, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
            Tween(uiScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.96 })
            task.delay(0.24, function()
                if not uiVisible then Main.Visible = false end
            end)
        end
    end

    local function setMinimized(state)
        isMinimized = state
        if isMinimized then
            MinimizeBtn.Text = "+"
            Tween(Main, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0, 660, 0, 46) })
        else
            MinimizeBtn.Text = "-"
            Tween(Main, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = size })
        end
    end

    MinimizeBtn.MouseButton1Click:Connect(function()
        setMinimized(not isMinimized)
    end)

    CloseBtn.MouseButton1Click:Connect(function()
        setVisible(false)
    end)
    
    -- ─── NOTIFICATION ───
    function Window:Notify(n)
        n = n or {}
        local toast = New("Frame", {
            Size = UDim2.new(0, 250, 0, 0),
            Position = UDim2.new(0, 24, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.Group,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = NotifyHolder,
        })
        Corner(toast, 10)
        Stroke(toast, Theme.GroupStroke, 0.25)
        Pad(toast, 10, 12, 12, 12)
        New("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = toast })
        New("TextLabel", {
            LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 15),
            BackgroundTransparency = 1, Text = n.Title or "Angeli",
            Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = toast,
        })
        New("TextLabel", {
            LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, Text = n.Text or "",
            Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.TextDim,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, Parent = toast,
        })
        Tween(toast, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
        task.delay(n.Duration or 3, function()
            if toast and toast.Parent then
                Tween(toast, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1, Position = UDim2.new(0, 24, 0, 0) })
                task.delay(0.26, function()
                    if toast and toast.Parent then toast:Destroy() end
                end)
            end
        end)
    end
    
    -- ─── BACKGROUND CONTROLS ───
    function Window:SetBackground(image, transparency, scaleType)
        if image and image ~= "" then
            BackgroundImage.Image = image
            BackgroundImage.Visible = true
            ConfigData.BackgroundImage = image
        else
            BackgroundImage.Visible = false
            ConfigData.BackgroundImage = ""
        end
        if transparency ~= nil then
            BackgroundImage.ImageTransparency = transparency
            ConfigData.BackgroundTransparency = transparency
        end
        if scaleType then
            BackgroundImage.ScaleType = scaleType
        end
        self:SaveConfig()
    end
    
    function Window:SetOverlay(transparency, color)
        BackgroundOverlay.Visible = transparency > 0
        if transparency ~= nil then
            BackgroundOverlay.BackgroundTransparency = transparency
            ConfigData.OverlayTransparency = transparency
        end
        if color then
            BackgroundOverlay.BackgroundColor3 = color
        end
        self:SaveConfig()
    end
    
    function Window:SetBlur(amount)
        if amount and amount > 0 then
            if not Blur then
                Blur = New("BlurEffect", {
                    Name = "Blur",
                    Size = amount,
                    Parent = BackgroundContainer,
                })
            else
                Blur.Size = amount
            end
            ConfigData.BlurAmount = amount
        else
            if Blur then
                Blur:Destroy()
                Blur = nil
            end
            ConfigData.BlurAmount = 0
        end
        self:SaveConfig()
    end
    
    function Window:SetTheme(themeName)
        if themeName == "light" then
            Theme = Themes.light
        elseif themeName == "dark" then
            Theme = Themes.dark
        else
            return
        end
        ConfigData.Theme = themeName
        
        Main.BackgroundColor3 = Theme.Background
        Stroke(Main, Theme.GroupStroke, 0.4)
        TitleLabel.TextColor3 = Theme.Text
        MinimizeBtn.BackgroundColor3 = Theme.Control
        MinimizeBtn.TextColor3 = Theme.Text
        Indicator.BackgroundColor3 = Theme.Text
        
        for _, t in ipairs(tabs) do
            t.NameLabel.TextColor3 = (t == currentTab) and Theme.Text or Theme.TextDim
        end

        self:SaveConfig()
        self:Notify({ Title = "Theme", Text = "Switched to " .. themeName .. " theme." })
    end
    
    function Window:SaveConfig()
        pcall(function()
            if writefile then
                local json = HttpService:JSONEncode(ConfigData)
                writefile("AngeliUI_Config.json", json)
            end
        end)
    end
    
    -- ─── BUILDERS ───
    local function BuildToggle(parent, order, o)
        local state = o.Default == true
        local keyCode = nil
        if o.Keybind and Enum.KeyCode[o.Keybind] then
            keyCode = Enum.KeyCode[o.Keybind]
        end
        local row = New("Frame", {
            Name = "Toggle_" .. o.Name,
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            Parent = parent,
        })
        local click = New("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = row,
        })
        New("TextLabel", {
            Size = UDim2.new(1, -92, 1, 0),
            BackgroundTransparency = 1,
            Text = o.Name,
            Font = Enum.Font.Gotham,
            TextSize = 15,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = click,
        })
        local pill = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(30, 17),
            BackgroundColor3 = state and Theme.PillOn or Theme.PillOff,
            BorderSizePixel = 0,
            Parent = click,
        })
        Corner(pill, 9)
        local knob = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = state and UDim2.new(1, -8, 0.5, 0) or UDim2.new(0, 8, 0.5, 0),
            Size = UDim2.fromOffset(12, 12),
            BackgroundColor3 = state and Theme.KnobOn or Theme.KnobOff,
            BorderSizePixel = 0,
            Parent = pill,
        })
        Corner(knob, 6)
        local entry = { Keybind = nil }
        local function apply(fire)
            Tween(pill, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = state and Theme.PillOn or Theme.PillOff })
            Tween(knob, TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Position = state and UDim2.new(1, -8, 0.5, 0) or UDim2.new(0, 8, 0.5, 0),
                BackgroundColor3 = state and Theme.KnobOn or Theme.KnobOff,
            })
            if fire and o.Callback then
                task.spawn(o.Callback, state)
            end
        end
        function entry:Get() return state end
        function entry:Set(v, fire)
            state = v == true
            apply(fire ~= false)
        end
        click.MouseButton1Click:Connect(function()
            entry:Set(not state)
        end)
        local chip
        chip = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -40, 0.5, 0),
            Size = UDim2.new(0, 0, 0, 20),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = Theme.Control,
            Text = keyCode and keyCode.Name or "",
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = Theme.TextSoft,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Parent = row,
        })
        Corner(chip, 5)
        Pad(chip, 0, 0, 8, 8)
        chip.MouseButton1Click:Connect(function()
            if rebinding then return end
            rebinding = { Chip = chip, Entry = entry }
            chip.Text = "..."
            Tween(chip, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = Theme.TextSoft, TextColor3 = Theme.Background })
        end)
        entry.RefreshChip = function()
            chip.Text = entry.Keybind and entry.Keybind.Name or ""
        end
        entry.Bind = function(newKey)
            entry.Keybind = newKey
            keyCode = newKey
            entry.RefreshChip()
        end
        entry.Bind(keyCode)
        table.insert(keybinds, entry)
        return entry
    end
    
    local function BuildSlider(parent, order, o)
        local min = o.Min or 0
        local max = o.Max or 100
        local decimals = o.Decimals or 0
        local value = math.clamp(round(o.Default or min, decimals), min, max)
        local startAlpha = (value - min) / (max - min)
        local box = New("Frame", {
            Name = "Slider_" .. o.Name,
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 42),
            BackgroundTransparency = 1,
            Parent = parent,
        })
        New("TextLabel", {
            Size = UDim2.new(1, -40, 0, 15),
            BackgroundTransparency = 1,
            Text = o.Name,
            Font = Enum.Font.Gotham,
            TextSize = 15,
            TextColor3 = Theme.TextSoft,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = box,
        })
        local valueLabel = New("TextLabel", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0, 0, 0, 14),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            Text = tostring(value),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = box,
        })
        local hitbox = New("TextButton", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, -2),
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = box,
        })
        local track = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.new(1, 0, 0, 6),
            BackgroundColor3 = Theme.SliderTrack,
            BorderSizePixel = 0,
            Parent = hitbox,
        })
        Corner(track, 3)
        local fill = New("Frame", {
            Size = UDim2.new(startAlpha, 0, 1, 0),
            BackgroundColor3 = Theme.SliderFill,
            BorderSizePixel = 0,
            Parent = track,
        })
        Corner(fill, 3)
        local knob = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(startAlpha, 0, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            BackgroundColor3 = Theme.SliderFill,
            BorderSizePixel = 0,
            Parent = track,
        })
        Corner(knob, 8)
        local slider = {
            Display = startAlpha,
            Target = startAlpha,
            Dragging = false,
            Fire = false,
            LastValue = value,
        }
        function slider.Render()
            local a = slider.Display
            fill.Size = UDim2.new(a, 0, 1, 0)
            knob.Position = UDim2.new(a, 0, 0.5, 0)
            local newValue = round(min + (max - min) * a, decimals)
            if newValue ~= slider.LastValue then
                slider.LastValue = newValue
                value = newValue
                valueLabel.Text = tostring(newValue)
                if slider.Fire and o.Callback then
                    task.spawn(o.Callback, newValue)
                end
            end
        end
        local function knobSize(px)
            Tween(knob, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(px, px) })
        end
        local function setTargetFromX(x)
            local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local snapped = round(min + (max - min) * rel, decimals)
            slider.Target = (snapped - min) / (max - min)
            smoothSliders[slider] = true
        end
        local function startDrag(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                slider.Dragging = true
                slider.Fire = true
                knobSize(17)
                setTargetFromX(input.Position.X)
            end
        end
        hitbox.MouseButton1Down:Connect(function() end)
        hitbox.InputBegan:Connect(startDrag)
        knob.InputBegan:Connect(startDrag)
        track.InputBegan:Connect(startDrag)
        UserInputService.InputChanged:Connect(function(input)
            if slider.Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                setTargetFromX(input.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if slider.Dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                slider.Dragging = false
                knobSize(14)
            end
        end)
        hitbox.MouseEnter:Connect(function()
            if not slider.Dragging then knobSize(16) end
        end)
        hitbox.MouseLeave:Connect(function()
            if not slider.Dragging then knobSize(14) end
        end)
        return {
            Get = function() return value end,
            Set = function(_, v)
                local snapped = math.clamp(round(v, decimals), min, max)
                slider.Target = (snapped - min) / (max - min)
                slider.Fire = true
                smoothSliders[slider] = true
            end,
        }
    end
    
    local function BuildButton(parent, order, o)
        local btn = New("TextButton", {
            Name = "Button_" .. o.Name,
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = Theme.Control,
            Text = o.Name,
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.TextSoft,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Parent = parent,
        })
        Corner(btn, 7)
        btn.MouseEnter:Connect(function() Tween(btn, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = Theme.ControlHover }) end)
        btn.MouseLeave:Connect(function() Tween(btn, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = Theme.Control }) end)
        btn.MouseButton1Down:Connect(function() Tween(btn, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextColor3 = Theme.Text }) end)
        btn.MouseButton1Up:Connect(function() Tween(btn, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextColor3 = Theme.TextSoft }) end)
        btn.MouseButton1Click:Connect(function()
            if o.Callback then task.spawn(o.Callback) end
        end)
        return btn
    end
    
    local function BuildInput(parent, order, o)
        local box = New("Frame", {
            Name = "Input_" .. o.Name,
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundTransparency = 1,
            Parent = parent,
        })
        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Text = o.Name,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.TextSoft,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = box,
        })
        local input = New("TextBox", {
            Position = UDim2.new(0, 0, 0, 18),
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundColor3 = Theme.Control,
            BorderSizePixel = 0,
            Text = o.Default or "",
            PlaceholderText = o.Placeholder or "",
            PlaceholderColor3 = Theme.TextDim,
            TextColor3 = Theme.Text,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            Parent = box,
        })
        Corner(input, 5)
        Pad(input, 0, 0, 6, 6)
        
        input.FocusLost:Connect(function()
            if o.Callback then task.spawn(o.Callback, input.Text) end
        end)
        
        return {
            Get = function() return input.Text end,
            Set = function(_, v) input.Text = v end,
        }
    end
    
    local function CreateGroupbox(columnFrame, groupTitle)
        local group = New("Frame", {
            Name = "Group_" .. groupTitle,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.Group,
            BorderSizePixel = 0,
            Parent = columnFrame,
        })
        Corner(group, 11)
        Stroke(group, Theme.GroupStroke, 0.35)
        Pad(group, 13, 15, 14, 14)
        New("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = group,
        })
        New("TextLabel", {
            LayoutOrder = 0,
            Size = UDim2.new(1, 0, 0, 12),
            BackgroundTransparency = 1,
            Text = string.upper(groupTitle),
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = Theme.HeaderText,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = group,
        })
        local Group = {}
        local controlOrder = 0
        local function nextOrder()
            controlOrder += 1
            return controlOrder
        end
        function Group:AddToggle(o)    return BuildToggle(group, nextOrder(), o) end
        function Group:AddSlider(o)    return BuildSlider(group, nextOrder(), o) end
        function Group:AddButton(o)    return BuildButton(group, nextOrder(), o) end
        function Group:AddInput(o)     return BuildInput(group, nextOrder(), o) end
        return Group
    end
    
    -- ─── TAB INDICATOR ───
    local function moveIndicatorTo(tab, instant)
        if indicatorConn then
            indicatorConn:Disconnect()
            indicatorConn = nil
        end
        local btn = tab.Button
        local function place(inst)
            if not btn.Parent then return end
            local y = btn.AbsolutePosition.Y - Sidebar.AbsolutePosition.Y
                + (btn.AbsoluteSize.Y - 16) / 2
            Indicator.Visible = true
            if inst then
                Indicator.Position = UDim2.new(0, 13, 0, y)
            else
                Tween(Indicator, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0, 13, 0, y) })
            end
        end
        task.defer(place, instant)
        indicatorConn = btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            place(true)
        end)
    end
    
    -- ─── SELECT TAB ───
    local function selectTab(tab, instant)
        local previous = currentTab
        currentTab = tab
        for _, t in ipairs(tabs) do
            local selected = (t == tab)
            if selected then
                if t.Page ~= (previous and previous.Page) then
                    t.Page.Visible = true
                    t.Page.Position = UDim2.new(0, 0, 0, 12)
                    t.Page.BackgroundTransparency = 1
                    Tween(t.Page, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Position = UDim2.new(0, 0, 0, 0),
                        BackgroundTransparency = 0,
                    })
                else
                    t.Page.Visible = true
                end
                t.Scroller.CanvasPosition = Vector2.new(0, 0)
            else
                t.Page.Visible = false
            end
            Tween(t.Button, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = selected and 0 or 1,
            })
            t.NameLabel.TextColor3 = selected and Theme.Text or Theme.TextDim
        end
        moveIndicatorTo(tab, instant)
    end
    
    -- ─── ADD TAB ───
    function Window:AddTab(tabOpts)
        tabOpts = tabOpts or {}
        local sectionName = tabOpts.Section or "Main"
        if not seenSections[sectionName] then
            seenSections[sectionName] = true
            sidebarOrder += 1
            New("TextLabel", {
                LayoutOrder = sidebarOrder,
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1,
                Text = string.upper(sectionName),
                Font = Enum.Font.GothamBold,
                TextSize = 9,
                TextColor3 = Theme.HeaderText,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Bottom,
                Parent = Sidebar,
            })
        end
        sidebarOrder += 1
        local Tab = {}
        local button = New("TextButton", {
            LayoutOrder = sidebarOrder,
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            BackgroundColor3 = Theme.TabSelected,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Parent = Sidebar,
        })
        Corner(button, 8)
        local nameLabel = New("TextLabel", {
            Position = UDim2.new(0, 12, 0, 0),
            Size = UDim2.new(1, -12, 1, 0),
            BackgroundTransparency = 1,
            Text = tabOpts.Name or "Tab",
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = button,
        })
        button.MouseEnter:Connect(function()
            if currentTab ~= Tab then
                Tween(button, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.6 })
            end
        end)
        button.MouseLeave:Connect(function()
            if currentTab ~= Tab then
                Tween(button, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
            end
        end)
        local page = New("Frame", {
            Name = "Page_" .. (tabOpts.Name or "Tab"),
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Visible = false,
            BorderSizePixel = 0,
            Parent = Content,
        })
        local scroller = New("ScrollingFrame", {
            Name = "Scroller",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Color3.fromRGB(60, 60, 66),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollingDirection = Enum.ScrollingDirection.Y,
            BorderSizePixel = 0,
            Parent = page,
        })
        local holder = New("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Parent = scroller,
        })
        local leftCol = New("Frame", {
            Name = "Left",
            Size = UDim2.new(0.5, -6, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Parent = holder,
        })
        New("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = leftCol })
        local rightCol = New("Frame", {
            Name = "Right",
            Position = UDim2.new(0.5, 6, 0, 0),
            Size = UDim2.new(0.5, -6, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Parent = holder,
        })
        New("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rightCol })
        Tab.Page = page
        Tab.Scroller = scroller
        Tab.Button = button
        Tab.NameLabel = nameLabel
        table.insert(tabs, Tab)
        button.MouseButton1Click:Connect(function()
            if currentTab ~= Tab then
                selectTab(Tab)
            end
        end)
        function Tab:AddGroupbox(gOpts)
            gOpts = gOpts or {}
            local column = (gOpts.Column == "Right") and rightCol or leftCol
            return CreateGroupbox(column, gOpts.Title or "Group")
        end
        function Tab:Select()
            selectTab(Tab)
        end
        if #tabs == 1 then
            selectTab(Tab, true)
        end
        return Tab
    end
    
    -- ─── KEYBINDS ───
    local toggleKey = Enum.KeyCode.LeftControl
    if opts.ToggleKey and Enum.KeyCode[opts.ToggleKey] then
        toggleKey = Enum.KeyCode[opts.ToggleKey]
    end
    
    local inputConn
    inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if rebinding then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local pending = rebinding
                rebinding = nil
                Tween(pending.Chip, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundColor3 = Theme.Control,
                    TextColor3 = Theme.TextSoft,
                })
                if input.KeyCode == Enum.KeyCode.Escape then
                    pending.Entry.RefreshChip()
                elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
                    pending.Entry.Bind(nil)
                else
                    pending.Entry.Bind(input.KeyCode)
                end
            end
            return
        end
        if gameProcessed then return end
        if input.KeyCode == toggleKey then
            setVisible(not uiVisible)
            return
        end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            for _, entry in ipairs(keybinds) do
                if entry.Keybind and entry.Keybind == input.KeyCode then
                    entry:Set(not entry:Get())
                end
            end
        end
    end)
    
    -- ─── WINDOW API ───
    function Window:Toggle()
        setVisible(not uiVisible)
    end
    function Window:Show()
        setVisible(true)
    end
    function Window:Hide()
        setVisible(false)
    end
    function Window:Destroy()
        if heartbeatConn then heartbeatConn:Disconnect() end
        if inputConn then inputConn:Disconnect() end
        if indicatorConn then indicatorConn:Disconnect() end
        if dragConn then dragConn:Disconnect() end
        Gui:Destroy()
    end
    function Window:GetBackground()
        return BackgroundImage
    end
    function Window:GetGui()
        return Gui
    end
    function Window:ApplyTheme(themeName)
        self:SetTheme(themeName)
    end
    
    setVisible(true)
    return Window
end

-- ─── INTERFACE TAB BUILDER ───
function AngeliUI:AddInterfaceTab(window)
    local interfaceTab = window:AddTab({ Name = "Interface", Section = "Menu" })
    
    local bgGroup = interfaceTab:AddGroupbox({ Title = "Background", Column = "Left" })
    
    local bgInput = bgGroup:AddInput({
        Name = "Image URL/ID",
        Placeholder = "rbxassetid://123 or pinimg URL",
        Default = ConfigData.BackgroundImage or "",
        Callback = function(value)
            if value and value ~= "" then
                window:SetBackground(value)
                window:Notify({ Title = "Background", Text = "Background updated!" })
            end
        end
    })
    
    local presetGroup = interfaceTab:AddGroupbox({ Title = "Presets", Column = "Right" })
    presetGroup:AddButton({
        Name = "Dark Space",
        Callback = function()
            window:SetBackground("rbxassetid://123456789")
            bgInput:Set("rbxassetid://123456789")
            window:Notify({ Title = "Background", Text = "Switched to Dark Space" })
        end
    })
    presetGroup:AddButton({
        Name = "Nebula",
        Callback = function()
            window:SetBackground("rbxassetid://987654321")
            bgInput:Set("rbxassetid://987654321")
            window:Notify({ Title = "Background", Text = "Switched to Nebula" })
        end
    })
    presetGroup:AddButton({
        Name = "Clear",
        Callback = function()
            window:SetBackground("")
            bgInput:Set("")
            window:Notify({ Title = "Background", Text = "Background cleared" })
        end
    })
    
    local opacityGroup = interfaceTab:AddGroupbox({ Title = "Opacity & Effects", Column = "Left" })
    
    local bgTransparency = opacityGroup:AddSlider({
        Name = "Image Transparency",
        Min = 0, Max = 1, Default = ConfigData.BackgroundTransparency or 0, Decimals = 2,
        Callback = function(v)
            window:SetBackground(nil, v)
        end
    })
    
    local overlayTransparency = opacityGroup:AddSlider({
        Name = "Overlay Darken",
        Min = 0, Max = 1, Default = ConfigData.OverlayTransparency or 0.3, Decimals = 2,
        Callback = function(v)
            window:SetOverlay(v)
        end
    })
    
    local blurAmount = opacityGroup:AddSlider({
        Name = "Blur Amount",
        Min = 0, Max = 12, Default = ConfigData.BlurAmount or 0,
        Callback = function(v)
            window:SetBlur(v)
        end
    })
    
    local overlayGroup = interfaceTab:AddGroupbox({ Title = "Overlays", Column = "Right" })
    overlayGroup:AddToggle({
        Name = "Show FPS",
        Default = ConfigData.ShowFPS or false,
        Callback = function(val)
            ConfigData.ShowFPS = val
            updateOverlays()
            window:SaveConfig()
        end
    })
    overlayGroup:AddToggle({
        Name = "Show Ping",
        Default = ConfigData.ShowPing or false,
        Callback = function(val)
            ConfigData.ShowPing = val
            updateOverlays()
            window:SaveConfig()
        end
    })

    local themeGroup = interfaceTab:AddGroupbox({ Title = "Theme", Column = "Left" })
    
    themeGroup:AddButton({
        Name = "Dark Theme",
        Callback = function()
            window:SetTheme("dark")
        end
    })
    
    themeGroup:AddButton({
        Name = "Light Theme",
        Callback = function()
            window:SetTheme("light")
        end
    })
    
    local resetGroup = interfaceTab:AddGroupbox({ Title = "Reset", Column = "Right" })
    resetGroup:AddButton({
        Name = "Reset All Settings",
        Callback = function()
            ConfigData.BackgroundImage = ""
            ConfigData.BackgroundTransparency = 0
            ConfigData.OverlayTransparency = 0.3
            ConfigData.BlurAmount = 0
            ConfigData.ShowFPS = false
            ConfigData.ShowPing = false
            window:SetBackground("")
            window:SetOverlay(0.3)
            window:SetBlur(0)
            bgInput:Set("")
            bgTransparency:Set(0)
            overlayTransparency:Set(0.3)
            blurAmount:Set(0)
            updateOverlays()
            window:Notify({ Title = "Reset", Text = "All settings reset!" })
        end
    })
    
    return interfaceTab
end

return AngeliUI
