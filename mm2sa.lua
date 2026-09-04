--[[
  MCUILib — Light Theme + Collapsible Tabs
  Usage:
    local MC = loadstring(game:HttpGet("..."))()
    
    -- Switch to light theme
    MC.SetTheme({
      BG          = Color3.fromHex("#f5f5f5"),
      Panel       = Color3.fromHex("#ffffff"),
      Row         = Color3.fromHex("#f9f9f9"),
      RowHover    = Color3.fromHex("#f0f0f0"),
      Border      = Color3.fromHex("#c8c8c8"),
      BorderDark  = Color3.fromHex("#e8e8e8"),
      Text        = Color3.fromHex("#1a1a1a"),
      TextMuted   = Color3.fromHex("#666666"),
      Green       = Color3.fromHex("#3aa82b"),
      GreenDark   = Color3.fromHex("#d4f0d0"),
      Red         = Color3.fromHex("#d63030"),
      Accent      = Color3.fromHex("#2563eb"),
      AccentDark  = Color3.fromHex("#e8f0fe"),
      SliderTrack = Color3.fromHex("#e8e8e8"),
      SliderThumb = Color3.fromHex("#c8c8c8"),
      InputBG     = Color3.fromHex("#ffffff"),
      TitleBG     = Color3.fromHex("#f0f0f0"),
    })
    
    local win = MC.Window("Clicker", MC.Icons.Ban)
    
    -- Tab system
    local mainTab = win:Tab("Main")
    mainTab:Toggle("Auto Clicker", MC.Icons.Activity, true, function(v) print(v) end)
    mainTab:Slider("CPS", 1, 20, 12, 1, function(v) print(v) end)
    
    local visualsTab = win:Tab("Visuals")
    visualsTab:Toggle("ESP", MC.Icons.Eye, true, function(v) print(v) end)
    visualsTab:ColorPicker("Color", Color3.fromHex("#55CC44"), function(c) print(c) end)
    
    win:Show()
]]

-- Add this to the library (paste after the existing code)

-- ──────────────────────────────────────────────
-- TAB SYSTEM (Collapsible)
-- ──────────────────────────────────────────────
local function createTabSystem(windowBody)
    local tabBar = make("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
    }, windowBody)
    
    local layout = make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
    }, tabBar)
    
    local tabs = {}
    local activeTab = nil
    local contentContainer = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
    }, windowBody)
    
    make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
    }, contentContainer)
    
    local function switchTab(tabId)
        if activeTab == tabId then
            -- Toggle collapse
            local container = tabs[tabId].container
            container.Visible = not container.Visible
            return
        end
        
        for id, data in pairs(tabs) do
            data.container.Visible = (id == tabId)
            data.btn.BackgroundColor3 = (id == tabId) and Theme.GreenDark or Color3.fromHex("#f0f0f0")
            data.btn.TextColor3 = (id == tabId) and Theme.Green or Theme.Text
        end
        
        activeTab = tabId
    end
    
    local function createTab(label)
        local btn = make("TextButton", {
            Size = UDim2.new(0, 80, 1, 0),
            BackgroundColor3 = Color3.fromHex("#f0f0f0"),
            BorderSizePixel = 0,
            Text = label:upper(),
            TextColor3 = Theme.Text,
            Font = Enum.Font.Code,
            TextSize = 14,
        }, tabBar)
        make("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = Theme.Border,
            Thickness = 1,
        }, btn)
        
        local container = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = (#tabs == 0), -- first tab visible by default
            LayoutOrder = 1,
        }, contentContainer)
        
        make("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 3),
        }, container)
        
        local _, notify = createToast(container)
        
        local tab = {}
        tab.container = container
        tab.btn = btn
        
        function tab:Toggle(lbl, icon, default, cb)
            return createToggle(container, lbl, icon, default, cb)
        end
        
        function tab:Slider(lbl, mn, mx, def, stp, cb)
            return createSlider(container, lbl, mn, mx, def, stp, cb)
        end
        
        function tab:Input(lbl, placeholder, cb)
            return createInput(container, lbl, placeholder, cb)
        end
        
        function tab:Keybind(lbl, default, cb)
            return createKeybind(container, lbl, default, cb)
        end
        
        function tab:SegmentedButton(opts, defIdx, cb)
            return createSegmented(container, opts, defIdx, cb)
        end
        
        function tab:Button(lbl, variant, cb)
            return createButton(container, lbl, variant, cb)
        end
        
        function tab:ColorPicker(lbl, default, cb)
            return createColorPicker(container, lbl, default, cb)
        end
        
        function tab:Divider()
            createDivider(container)
        end
        
        function tab:Notify(msg)
            notify(msg)
        end
        
        btn.MouseButton1Click:Connect(function()
            switchTab(label)
        end)
        
        tabs[label] = { btn = btn, container = container }
        if #tabs == 1 then activeTab = label end
        
        return tab
    end
    
    return createTab
end

-- Patch window creation
local originalCreateWindow = createWindow
createWindow = function(title, iconId)
    local win = originalCreateWindow(title, iconId)
    
    -- Override Section method to use tabs instead
    local body = win._body or nil
    if body then
        -- Find body frame (hacky but works)
        for _, child in ipairs(win._screenGui:GetChildren()) do
            if child:IsA("Frame") and child.Name ~= "TitleBar" then
                body = child
                break
            end
        end
    end
    
    -- Rebuild with tabs
    local function createTabbedWindow(title, iconId)
        local screenGui = make("ScreenGui", {
            Name = "MCUILib_" .. title,
            ResetOnSpawn = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            Parent = PlayerGui,
        })
        
        local win = make("Frame", {
            Size = UDim2.new(0, 320, 0, 0),
            Position = UDim2.new(0.5, -160, 0.5, -200),
            BackgroundColor3 = Theme.Panel,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = screenGui,
        })
        mcBorder(win, Theme.Border, Theme.BorderDark)
        
        -- Titlebar
        local titlebar = make("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = Theme.TitleBG,
            BorderSizePixel = 0,
        }, win)
        mcBorder(titlebar, Theme.BorderDark)
        
        if iconId then
            make("ImageLabel", {
                Size = UDim2.new(0, 18, 0, 18),
                Position = UDim2.new(0, 8, 0.5, -9),
                BackgroundTransparency = 1,
                Image = iconId,
                ScaleType = Enum.ScaleType.Fit,
            }, titlebar)
        end
        
        make("TextLabel", {
            Size = UDim2.new(1, -(iconId and 72 or 52), 1, 0),
            Position = UDim2.new(0, iconId and 30 or 10, 0, 0),
            BackgroundTransparency = 1,
            Text = title:upper(),
            TextColor3 = Theme.Text,
            Font = Enum.Font.Code,
            TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, titlebar)
        
        local closeBtn = make("TextButton", {
            Size = UDim2.new(0, 20, 0, 20),
            Position = UDim2.new(1, -26, 0.5, -10),
            BackgroundColor3 = Theme.Red,
            BorderSizePixel = 0,
            Text = "✕",
            TextColor3 = Color3.new(1, 1, 1),
            Font = Enum.Font.Code,
            TextSize = 14,
        }, titlebar)
        mcBorder(closeBtn, Color3.fromHex("#800000"), Color3.fromHex("#400000"))
        
        -- Body with tab system
        local body = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.new(0, 0, 0, 32),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
        }, win)
        make("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 0),
        }, body)
        make("UIPadding", {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 6),
            PaddingBottom = UDim.new(0, 8),
        }, body)
        
        local createTab = createTabSystem(body)
        
        -- Dragging
        local dragging, dragStart, startPos = false, nil, nil
        titlebar.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = inp.Position
                startPos = win.Position
            end
        end)
        titlebar.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = inp.Position - dragStart
                win.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
        
        closeBtn.MouseButton1Click:Connect(function()
            screenGui.Enabled = false
        end)
        closeBtn.MouseEnter:Connect(function()
            tween(closeBtn, { BackgroundColor3 = Color3.fromHex("#ff4444") })
        end)
        closeBtn.MouseLeave:Connect(function()
            tween(closeBtn, { BackgroundColor3 = Theme.Red })
        end)
        
        local windowApi = {}
        windowApi.Tab = createTab
        windowApi.Show = function() screenGui.Enabled = true end
        windowApi.Hide = function() screenGui.Enabled = false end
        windowApi.Toggle = function() screenGui.Enabled = not screenGui.Enabled end
        windowApi.Destroy = function() screenGui:Destroy() end
        
        return windowApi
    end
    
    -- Override MCUILib.Window to use tabbed version
    MCUILib.Window = createTabbedWindow
    return createTabbedWindow(title, iconId)
end

-- Export
MCUILib.TabSystem = createTabSystem
return MCUILib
