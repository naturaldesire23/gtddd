-- Unified Angeli UI Library v9.0
local UserInputService = cloneref and cloneref(game:GetService('UserInputService')) or game:GetService('UserInputService')
local TweenService = cloneref and cloneref(game:GetService('TweenService')) or game:GetService('TweenService')
local HttpService = cloneref and cloneref(game:GetService('HttpService')) or game:GetService('HttpService')
local TextService = cloneref and cloneref(game:GetService('TextService')) or game:GetService('TextService')
local RunService = cloneref and cloneref(game:GetService('RunService')) or game:GetService('RunService')
local Players = cloneref and cloneref(game:GetService('Players')) or game:GetService('Players')
local CoreGui = cloneref and cloneref(game:GetService('CoreGui')) or game:GetService('CoreGui')
local Debris = cloneref and cloneref(game:GetService('Debris')) or game:GetService('Debris')
local GuiService = cloneref and cloneref(game:GetService('GuiService')) or game:GetService('GuiService')
local Lighting = cloneref and cloneref(game:GetService('Lighting')) or game:GetService('Lighting')
local Workspace = cloneref and cloneref(game:GetService('Workspace')) or game:GetService('Workspace')

local mouse = Players.LocalPlayer:GetMouse()
local LocalPlayer = Players.LocalPlayer

local old_Fallen = CoreGui:FindFirstChild('Fallen')
if old_Fallen then
    Debris:AddItem(old_Fallen, 0)
end

pcall(function()
    if getgenv()._Fallen_Cleanup then
        getgenv()._Fallen_Cleanup()
        getgenv()._Fallen_Cleanup = nil
    end
end)

if not isfolder("Fallen") then
    makefolder("Fallen")
end

local function convertStringToTable(inputString)
    local result = {}
    for value in string.gmatch(inputString, "([^,]+)") do
        local trimmedValue = value:match("^%s*(.-)%s*$")
        table.insert(result, trimmedValue)
    end
    return result
end

local function convertTableToString(inputTable)
    return table.concat(inputTable, ", ")
end

local Connections = setmetatable({
    disconnect = function(self, connection)
        if not self[connection] then return end
        self[connection]:Disconnect()
        self[connection] = nil
    end,
    disconnect_all = function(self)
        for _, value in self do
            if typeof(value) == 'function' then continue end
            value:Disconnect()
        end
    end
}, Connections)

local Config = setmetatable({
    save = function(self, file_name, config)
        local success, result = pcall(function()
            local flags = HttpService:JSONEncode(config)
            writefile('Fallen/'..file_name..'.json', flags)
        end)
        if not success then warn('failed to save config', result) end
    end,
    load = function(self, file_name, config)
        local success, result = pcall(function()
            if not isfile('Fallen/'..file_name..'.json') then
                self:save(file_name, config)
                return
            end
            local flags = readfile('Fallen/'..file_name..'.json')
            if not flags then
                self:save(file_name, config)
                return
            end
            return HttpService:JSONDecode(flags)
        end)
        if not success then warn('failed to load config', result) end
        if not result then
            result = { _flags = {}, _keybinds = {} }
        end
        return result
    end
}, Config)

local DefaultTheme = {
    Background = Color3.fromRGB(0, 0, 0),
    Group = Color3.fromRGB(20, 20, 20),
    GroupStroke = Color3.fromRGB(45, 45, 45),
    Control = Color3.fromRGB(30, 30, 30),
    ControlHover = Color3.fromRGB(40, 40, 40),
    Divider = Color3.fromRGB(35, 35, 35),
    Text = Color3.fromRGB(238, 238, 242),
    TextDim = Color3.fromRGB(142, 142, 151),
    TextSoft = Color3.fromRGB(195, 195, 202),
    Accent = Color3.fromRGB(224, 224, 224),
    Gradient = ColorSequence.new{
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(92, 92, 92)),
        ColorSequenceKeypoint.new(0.34, Color3.fromRGB(18, 18, 18)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 0, 0))
    },
    TabGradient = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(155, 155, 155)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(58, 58, 58))
    }
}

local Theme = {}
for k, v in pairs(DefaultTheme) do
    Theme[k] = typeof(v) == "Color3" and Color3.new(v.R, v.G, v.B) or v
end

local Library = {
    _config = Config:load(game.GameId, { _flags = {}, _keybinds = {} }),
    _choosing_keybind = false,
    _device = nil,
    _ui_open = true,
    _ui_scale = 1,
    _ui = nil,
    _dragging = false,
    _drag_start = nil,
    _container_position = nil,
    _flag_registry = {},
    _elements = {},
    _notif_side = "Right",
    _notif_opacity = 0.0,
    _container_gradient = nil,
    _side_gradient = nil,
    _ui_stroke = nil
}
Library.__index = Library
Library.Connections = Connections

function Library.new()
    local self = setmetatable({ _tab = 0 }, Library)
    self:create_ui()
    self:build_interface_tab()
    return self
end

local NotificationHost = Instance.new("ScreenGui")
NotificationHost.Name = "FallenNotifications"
NotificationHost.ResetOnSpawn = false
NotificationHost.IgnoreGuiInset = true
NotificationHost.DisplayOrder = 101
NotificationHost.Parent = CoreGui

local NotificationContainer = Instance.new("Frame")
NotificationContainer.Name = "NotificationContainer"
NotificationContainer.Size = UDim2.new(0, 300, 0, 0)
NotificationContainer.BackgroundTransparency = 1
NotificationContainer.ClipsDescendants = false
NotificationContainer.Parent = NotificationHost
NotificationContainer.AutomaticSize = Enum.AutomaticSize.Y

local UIListLayout_Notif = Instance.new("UIListLayout")
UIListLayout_Notif.FillDirection = Enum.FillDirection.Vertical
UIListLayout_Notif.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout_Notif.Padding = UDim.new(0, 8)
UIListLayout_Notif.Parent = NotificationContainer

local function UpdateNotificationPosition()
    if Library._notif_side == "Left" then
        NotificationContainer.AnchorPoint = Vector2.new(0, 0)
        NotificationContainer.Position = UDim2.new(0, 22, 0, 22)
        UIListLayout_Notif.VerticalAlignment = Enum.VerticalAlignment.Top
    else
        NotificationContainer.AnchorPoint = Vector2.new(0, 1)
        NotificationContainer.Position = UDim2.new(0, 22, 1, -22)
        UIListLayout_Notif.VerticalAlignment = Enum.VerticalAlignment.Bottom
    end
end
UpdateNotificationPosition()

function Library.SendNotification(settings)
    local Notification = Instance.new("Frame")
    Notification.Size = UDim2.new(1, 0, 0, 62)
    Notification.BackgroundTransparency = 1
    Notification.BorderSizePixel = 0
    Notification.Name = "Notification"
    Notification.Parent = NotificationContainer

    local InnerFrame = Instance.new("Frame")
    InnerFrame.Size = UDim2.new(1, 0, 1, 0)
    InnerFrame.Position = UDim2.new(Library._notif_side == "Left" and 1 or -1, -320, 0, 0)
    InnerFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    InnerFrame.BackgroundTransparency = Library._notif_opacity
    InnerFrame.BorderSizePixel = 0
    InnerFrame.Name = "InnerFrame"
    InnerFrame.ZIndex = 1
    InnerFrame.Parent = Notification

    local InnerGradient = Instance.new("UIGradient")
    InnerGradient.Color = Theme.Gradient
    InnerGradient.Rotation = 90
    InnerGradient.Parent = InnerFrame

    local InnerUICorner = Instance.new("UICorner")
    InnerUICorner.CornerRadius = UDim.new(0, 8)
    InnerUICorner.Parent = InnerFrame

    local InnerStroke = Instance.new("UIStroke")
    InnerStroke.Color = Color3.fromRGB(255, 255, 255)
    InnerStroke.Transparency = 0.72
    InnerStroke.Thickness = 1
    InnerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    InnerStroke.Parent = InnerFrame

    local Title = Instance.new("TextLabel")
    Title.Text = settings.title or "Notification"
    Title.TextColor3 = Theme.Text
    Title.FontFace = Font.new('rbxasset://fonts/families/SFPro.json', Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    Title.TextSize = 16
    Title.Size = UDim2.new(1, -28, 0, 15)
    Title.Position = UDim2.new(0, 14, 0, 12)
    Title.BackgroundTransparency = 1
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextYAlignment = Enum.TextYAlignment.Center
    Title.TextTruncate = Enum.TextTruncate.AtEnd
    Title.ZIndex = 2
    Title.Parent = InnerFrame

    local Body = Instance.new("TextLabel")
    Body.Text = settings.text or "Notification message"
    Body.TextColor3 = Theme.TextDim
    Body.FontFace = Font.new('rbxasset://fonts/families/SFPro.json', Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    Body.TextSize = 14
    Body.Size = UDim2.new(1, -28, 0, 14)
    Body.Position = UDim2.new(0, 14, 0, 33)
    Body.BackgroundTransparency = 1
    Body.TextXAlignment = Enum.TextXAlignment.Left
    Body.TextYAlignment = Enum.TextYAlignment.Center
    Body.TextTruncate = Enum.TextTruncate.AtEnd
    Body.ZIndex = 2
    Body.Parent = InnerFrame

    task.spawn(function()
        local tweenIn = TweenService:Create(InnerFrame, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0)
        })
        tweenIn:Play()

        task.wait(settings.duration or 5)

        local tweenOut = TweenService:Create(InnerFrame, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
            Position = UDim2.new(Library._notif_side == "Left" and 1 or -1, -320, 0, 0)
        })
        tweenOut:Play()
        tweenOut.Completed:Wait()
        Notification:Destroy()
    end)
end

function Library:get_screen_scale()
    local viewport_size_x = workspace.CurrentCamera.ViewportSize.X
    self._ui_scale = viewport_size_x / 1400
end

function Library:get_device()
    local device = 'Unknown'
    if not UserInputService.TouchEnabled and UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
        device = 'PC'
    elseif UserInputService.TouchEnabled then
        device = 'Mobile'
    elseif UserInputService.GamepadEnabled then
        device = 'Console'
    end
    self._device = device
end

function Library:removed(action)
    self._ui.AncestryChanged:Once(action)
end

function Library:flag_type(flag, flag_type)
    if Library._config._flags[flag] == nil then return end
    return typeof(Library._config._flags[flag]) == flag_type
end

function Library:remove_table_value(__table, table_value)
    for index, value in __table do
        if value ~= table_value then continue end
        table.remove(__table, index)
    end
end

function Library:hexToRGB(hex)
    hex = hex:gsub("#","")
    return Color3.fromRGB(tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6)))
end

function Library:rgbToHex(color)
    return string.format("#%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
end

function Library:create_ui()
    local old_Fallen = CoreGui:FindFirstChild('Fallen')
    if old_Fallen then
        Debris:AddItem(old_Fallen, 0)
    end

    local Fallen = Instance.new('ScreenGui')
    Fallen.ResetOnSpawn = false
    Fallen.Name = 'Fallen'
    Fallen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Fallen.Parent = CoreGui

    local Container = Instance.new('Frame')
    Container.ClipsDescendants = true
    Container.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Container.AnchorPoint = Vector2.new(0.5, 0.5)
    Container.Name = 'Container'
    Container.BackgroundTransparency = 0
    Container.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Container.Position = UDim2.new(0.5, 0, 0.5, 0)
    Container.Size = UDim2.new(0, 0, 0, 0)
    Container.Active = true
    Container.BorderSizePixel = 0
    Container.Parent = Fallen

    local ShadowHolder = Instance.new('Frame')
    ShadowHolder.Name = 'ShadowHolder'
    ShadowHolder.AnchorPoint = Container.AnchorPoint
    ShadowHolder.Position = Container.Position
    ShadowHolder.Size = Container.Size
    ShadowHolder.BackgroundTransparency = 1
    ShadowHolder.BorderSizePixel = 0
    ShadowHolder.ZIndex = 0
    ShadowHolder.Parent = Fallen
    ShadowHolder.Visible = false

    local ShadowOuter = Instance.new('ImageLabel')
    ShadowOuter.Name = 'SoftShadowOuter'
    ShadowOuter.AnchorPoint = Vector2.new(0.5, 0.5)
    ShadowOuter.Position = UDim2.new(0.5, 0, 0.5, 2)
    ShadowOuter.Size = UDim2.new(1, 58, 1, 58)
    ShadowOuter.BackgroundTransparency = 1
    ShadowOuter.BorderSizePixel = 0
    ShadowOuter.Image = 'rbxassetid://6014261993'
    ShadowOuter.ImageColor3 = Color3.fromRGB(0, 0, 0)
    ShadowOuter.ImageTransparency = 0.43
    ShadowOuter.ScaleType = Enum.ScaleType.Slice
    ShadowOuter.SliceCenter = Rect.new(49, 49, 450, 450)
    ShadowOuter.ZIndex = 0
    ShadowOuter.Parent = ShadowHolder

    local ShadowInner = Instance.new('ImageLabel')
    ShadowInner.Name = 'SoftShadowInner'
    ShadowInner.AnchorPoint = Vector2.new(0.5, 0.5)
    ShadowInner.Position = UDim2.new(0.5, 0, 0.5, 1)
    ShadowInner.Size = UDim2.new(1, 32, 1, 32)
    ShadowInner.BackgroundTransparency = 1
    ShadowInner.BorderSizePixel = 0
    ShadowInner.Image = 'rbxassetid://6014261993'
    ShadowInner.ImageColor3 = Color3.fromRGB(0, 0, 0)
    ShadowInner.ImageTransparency = 0.30
    ShadowInner.ScaleType = Enum.ScaleType.Slice
    ShadowInner.SliceCenter = Rect.new(49, 49, 450, 450)
    ShadowInner.ZIndex = 0
    ShadowInner.Parent = ShadowHolder

    Container:GetPropertyChangedSignal('Position'):Connect(function()
        ShadowHolder.Position = Container.Position
    end)

    Container:GetPropertyChangedSignal('Size'):Connect(function()
        ShadowHolder.Size = Container.Size
    end)

    local ContainerGradient = Instance.new("UIGradient")
    ContainerGradient.Color = Theme.Gradient
    ContainerGradient.Rotation = 90
    ContainerGradient.Parent = Container
    self._container_gradient = ContainerGradient

    local Background = Instance.new('ImageLabel')
    Background.Name = 'Background'
    Background.Size = UDim2.new(1, 0, 1, 0)
    Background.Position = UDim2.new(0, 0, 0, 0)
    Background.BackgroundTransparency = 1
    Background.BorderSizePixel = 0
    Background.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Background.Image = ''
    Background.ImageTransparency = 0.5
    Background.ScaleType = Enum.ScaleType.Crop
    Background.Visible = false
    Background.ZIndex = 0
    Background.Parent = Container

    local UICorner_bg = Instance.new('UICorner')
    UICorner_bg.CornerRadius = UDim.new(0, 10)
    UICorner_bg.Parent = Background

    local Texture = Instance.new('ImageLabel')
    Texture.Name = 'Texture'
    Texture.Size = UDim2.new(1, 0, 1, 0)
    Texture.Position = UDim2.new(0, 0, 0, 0)
    Texture.BackgroundTransparency = 1
    Texture.BorderSizePixel = 0
    Texture.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Texture.Image = 'rbxassetid://9968344227'
    Texture.ImageColor3 = Color3.fromRGB(0, 0, 0)
    Texture.ImageTransparency = 0.88
    Texture.ScaleType = Enum.ScaleType.Tile
    Texture.TileSize = UDim2.new(0, 128, 0, 128)
    Texture.ZIndex = 0
    Texture.Parent = Container

    local SideBar = Instance.new("Frame")
    SideBar.Name = "GradientSide"
    SideBar.Parent = Container
    SideBar.Size = UDim2.new(0, 10, 1, 0)
    SideBar.Position = UDim2.new(0, 0, 0, 0)
    SideBar.BackgroundTransparency = 1

    local SideGradient = Instance.new("UIGradient")
    SideGradient.Color = Theme.Gradient
    SideGradient.Rotation = 90
    SideGradient.Parent = SideBar
    self._side_gradient = SideGradient

    local UICorner = Instance.new('UICorner')
    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = Container

    local UIStroke = Instance.new('UIStroke')
    UIStroke.Color = Theme.GroupStroke
    UIStroke.Transparency = 0.58
    UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    UIStroke.Parent = Container
    self._ui_stroke = UIStroke

    local Handler = Instance.new('Frame')
    Handler.BackgroundTransparency = 1
    Handler.Name = 'Handler'
    Handler.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Handler.Size = UDim2.new(0, 752, 0, 479)
    Handler.BorderSizePixel = 0
    Handler.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Handler.Parent = Container

    local Tabs = Instance.new('ScrollingFrame')
    Tabs.ScrollBarImageTransparency = 1
    Tabs.ScrollBarThickness = 0
    Tabs.Name = 'Tabs'
    Tabs.Size = UDim2.new(0, 129, 0, 401)
    Tabs.Selectable = false
    Tabs.AutomaticCanvasSize = Enum.AutomaticSize.XY
    Tabs.BackgroundTransparency = 1
    Tabs.Position = UDim2.new(0, 18, 0, 67)
    Tabs.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Tabs.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Tabs.BorderSizePixel = 0
    Tabs.CanvasSize = UDim2.new(0, 0, 0.5, 0)
    Tabs.Parent = Handler

    local UIListLayout_Tabs = Instance.new('UIListLayout')
    UIListLayout_Tabs.Padding = UDim.new(0, 4)
    UIListLayout_Tabs.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout_Tabs.Parent = Tabs

    local ClientName = Instance.new('TextLabel')
    ClientName.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
    ClientName.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
    ClientName.TextStrokeTransparency = 1
    ClientName.TextColor3 = Theme.Text
    ClientName.TextTransparency = 0
    ClientName.Text = 'Angeli'
    ClientName.Name = 'ClientName'
    ClientName.Size = UDim2.new(0, 110, 0, 19)
    ClientName.AnchorPoint = Vector2.new(0, 0.5)
    ClientName.Position = UDim2.new(0, 43, 0, 26)
    ClientName.BackgroundTransparency = 1
    ClientName.TextXAlignment = Enum.TextXAlignment.Left
    ClientName.BorderSizePixel = 0
    ClientName.BorderColor3 = Color3.fromRGB(0, 0, 0)
    ClientName.TextSize = 16
    ClientName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ClientName.Parent = Handler
    table.insert(Library._elements, {obj = ClientName, prop = "TextColor3", tKey = "Text"})

    local Logo = Instance.new('ImageLabel')
    Logo.Name = 'Logo'
    Logo.Size = UDim2.new(0, 26, 0, 26)
    Logo.AnchorPoint = Vector2.new(0, 0.5)
    Logo.Position = UDim2.new(0, 14, 0, 26)
    Logo.BackgroundTransparency = 1
    Logo.BorderSizePixel = 0
    Logo.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Logo.Image = 'rbxassetid://119051552929078'
    Logo.ImageColor3 = Color3.fromRGB(255, 255, 255)
    Logo.ImageTransparency = 0
    Logo.ScaleType = Enum.ScaleType.Fit
    Logo.Parent = Handler

    local Pin = Instance.new('Frame')
    Pin.Name = 'Pin'
    Pin.Position = UDim2.new(0, 18, 0, 79)
    Pin.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Pin.Size = UDim2.new(0, 2, 0, 16)
    Pin.BorderSizePixel = 0
    Pin.BackgroundColor3 = Theme.Accent
    Pin.Parent = Handler
    table.insert(Library._elements, {obj = Pin, prop = "BackgroundColor3", tKey = "Accent"})

    local UICorner2 = Instance.new('UICorner')
    UICorner2.CornerRadius = UDim.new(1, 0)
    UICorner2.Parent = Pin

    local Divider = Instance.new('Frame')
    Divider.Name = 'Divider'
    Divider.BackgroundTransparency = 0.65
    Divider.Position = UDim2.new(0, 164, 0, 75)
    Divider.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Divider.Size = UDim2.new(0, 1, 0, 330)
    Divider.BorderSizePixel = 0
    Divider.BackgroundColor3 = Theme.Divider
    Divider.Parent = Handler
    table.insert(Library._elements, {obj = Divider, prop = "BackgroundColor3", tKey = "Divider"})

    local Sections = Instance.new('Folder')
    Sections.Name = 'Sections'
    Sections.Parent = Handler

    local Minimize = Instance.new('TextButton')
    Minimize.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
    Minimize.TextColor3 = Color3.fromRGB(0, 0, 0)
    Minimize.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Minimize.Text = ''
    Minimize.AutoButtonColor = false
    Minimize.Name = 'Minimize'
    Minimize.BackgroundTransparency = 1
    Minimize.Position = UDim2.new(0.020057305693626404, 0, 0.02922755666077137, 0)
    Minimize.Size = UDim2.new(0, 24, 0, 24)
    Minimize.BorderSizePixel = 0
    Minimize.TextSize = 14
    Minimize.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Minimize.Parent = Handler

    local Search = Instance.new('ImageButton')
    Search.Name = 'Search'
    Search.AutoButtonColor = false
    Search.BackgroundTransparency = 1
    Search.BorderSizePixel = 0
    Search.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Search.Image = 'rbxassetid://102373102520464'
    Search.ImageColor3 = Color3.fromRGB(188, 188, 188)
    Search.ImageTransparency = 0
    Search.ScaleType = Enum.ScaleType.Fit
    Search.AnchorPoint = Vector2.new(1, 0.5)
    Search.Position = UDim2.new(0, 734, 0, 26)
    Search.Size = UDim2.new(0, 22, 0, 22)
    Search.Parent = Handler

    local UIScale = Instance.new('UIScale')
    UIScale.Parent = Container

    local ShadowScale
    if UserInputService.TouchEnabled then
        ShadowScale = Instance.new('UIScale')
        ShadowScale.Scale = UIScale.Scale
        ShadowScale.Parent = ShadowHolder
    end

    self._ui = Fallen
    self._container = Container
    self._background = Background

    local function on_drag(input, process)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self._dragging = true
            self._drag_start = input.Position
            self._container_position = Container.Position

            Connections['container_input_ended'] = input.Changed:Connect(function()
                if input.UserInputState ~= Enum.UserInputState.End then return end
                Connections:disconnect('container_input_ended')
                self._dragging = false
            end)
        end
    end

    local function update_drag(input)
        local delta = input.Position - self._drag_start
        local position = UDim2.new(self._container_position.X.Scale, self._container_position.X.Offset + delta.X, self._container_position.Y.Scale, self._container_position.Y.Offset + delta.Y)
        TweenService:Create(Container, TweenInfo.new(0.2), { Position = position }):Play()
    end

    local function drag(input, process)
        if not self._dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            update_drag(input)
        end
    end

    Connections['container_input_began'] = Container.InputBegan:Connect(on_drag)
    Connections['input_changed'] = UserInputService.InputChanged:Connect(drag)

    self:removed(function()
        self._ui = nil
        Connections:disconnect_all()
    end)

    function self:change_visiblity(state)
        Library._ui_open = state
        ShadowHolder.Visible = state
        if state then
            ContainerGradient.Enabled = true
            ContainerGradient.Color = Theme.Gradient
            ContainerGradient.Rotation = 90
            Container.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Logo.Position = UDim2.new(0, 14, 0, 26)
            ClientName.Position = UDim2.new(0, 43, 0, 26)

            TweenService:Create(Container, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = UDim2.fromOffset(752, 479)
            }):Play()
        else
            ContainerGradient.Enabled = true
            ContainerGradient.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(72, 72, 72)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 0, 0))
            }
            ContainerGradient.Rotation = 90
            Container.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Logo.Position = UDim2.new(0, 10, 0, 26)
            ClientName.Position = UDim2.new(0, 39, 0, 26)

            TweenService:Create(Container, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = UDim2.fromOffset(104.5, 52)
            }):Play()
        end
    end

    function self:set_gui_visibility(state)
        if not self._ui then return end
        if state then
            self._ui.Enabled = true
            Container.Size = UDim2.fromOffset(0, 0)
            TweenService:Create(Container, TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                Size = UDim2.fromOffset(752, 479)
            }):Play()
        else
            local t = TweenService:Create(Container, TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {
                Size = UDim2.fromOffset(0, 0)
            })
            t:Play()
            t.Completed:Once(function()
                self._ui.Enabled = false
            end)
        end
    end

    function self:load()
        self:get_device()

        if self._device == 'Mobile' or self._device == 'Unknown' then
            self:get_screen_scale()
            UIScale.Scale = self._ui_scale
            if ShadowScale then
                ShadowScale.Scale = self._ui_scale
            end

            Connections['ui_scale'] = workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
                self:get_screen_scale()
                UIScale.Scale = self._ui_scale
                if ShadowScale then
                    ShadowScale.Scale = self._ui_scale
                end
            end)
        end

        ShadowHolder.Visible = true

        TweenService:Create(Container, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(752, 479)
        }):Play()
    end

    function self:update_tabs(tab)
        for index, object in Tabs:GetChildren() do
            if object.Name ~= 'Tab' then continue end

            if object == tab then
                if object.BackgroundTransparency ~= 0.5 then
                    local offset = object.LayoutOrder * 42

                    TweenService:Create(Pin, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Position = UDim2.new(0, 18, 0, 79 + offset)
                    }):Play()

                    TweenService:Create(object, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundTransparency = 0.5
                    }):Play()

                    TweenService:Create(object.TextLabel, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        TextTransparency = 0,
                        TextColor3 = Theme.Text
                    }):Play()

                    TweenService:Create(object.TextLabel.UIGradient, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Offset = Vector2.new(1, 0)
                    }):Play()

                    TweenService:Create(object.Icon, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        ImageColor3 = object.Icon:GetAttribute('ActiveColor') or Theme.Text
                    }):Play()
                end

                continue
            end

            if object.BackgroundTransparency ~= 1 then
                TweenService:Create(object, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    BackgroundTransparency = 1
                }):Play()

                TweenService:Create(object.TextLabel, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    TextTransparency = 0,
                    TextColor3 = Theme.TextDim
                }):Play()

                TweenService:Create(object.TextLabel.UIGradient, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    Offset = Vector2.new(0, 0)
                }):Play()

                TweenService:Create(object.Icon, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    ImageColor3 = object.Icon:GetAttribute('IdleColor') or Theme.TextDim
                }):Play()
            end
        end
    end

    function self:update_sections(left_section, right_section)
        for _, object in Sections:GetChildren() do
            if object == left_section or object == right_section then
                object.Visible = true
                continue
            end
            object.Visible = false
        end
    end

    function self:create_tab(title, icon, icon_size, idle_color, active_color)
        local TabManager = {}

        local font_params = Instance.new('GetTextBoundsParams')
        font_params.Text = title
        font_params.Font = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
        font_params.Size = 13
        font_params.Width = 10000

        local font_size = TextService:GetTextBoundsAsync(font_params)
        local first_tab = not Tabs:FindFirstChild('Tab')

        local Tab = Instance.new('TextButton')
        Tab.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
        Tab.TextColor3 = Color3.fromRGB(0, 0, 0)
        Tab.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Tab.Text = ''
        Tab.AutoButtonColor = false
        Tab.BackgroundTransparency = 1
        Tab.Name = 'Tab'
        Tab.Size = UDim2.new(0, 129, 0, 38)
        Tab.BorderSizePixel = 0
        Tab.TextSize = 14
        Tab.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        Tab.Parent = Tabs
        Tab.LayoutOrder = self._tab

        local UICorner = Instance.new('UICorner')
        UICorner.CornerRadius = UDim.new(0, 5)
        UICorner.Parent = Tab

        local TextLabel = Instance.new('TextLabel')
        TextLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
        TextLabel.TextColor3 = Theme.TextDim
        TextLabel.TextTransparency = 0
        TextLabel.Text = title
        TextLabel.Size = UDim2.new(0, font_size.X, 0, 16)
        TextLabel.AnchorPoint = Vector2.new(0, 0.5)
        TextLabel.Position = UDim2.new(0, 37, 0.5, 0)
        TextLabel.BackgroundTransparency = 1
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.BorderSizePixel = 0
        TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
        TextLabel.TextSize = 13
        TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel.Parent = Tab

        local UIGradient = Instance.new('UIGradient')
        UIGradient.Color = Theme.TabGradient
        UIGradient.Parent = TextLabel

        local Icon = Instance.new('ImageLabel')
        Icon.Name = 'Icon'
        Icon.Size = UDim2.new(0, icon_size or 16, 0, icon_size or 16)
        Icon.AnchorPoint = Vector2.new(0.5, 0.5)
        Icon.Position = UDim2.new(0, 19, 0.5, 0)
        Icon.BackgroundTransparency = 1
        Icon.BorderSizePixel = 0
        Icon.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Icon.Image = icon or ''
        Icon.ImageColor3 = idle_color or Theme.TextDim
        Icon:SetAttribute('IdleColor', idle_color or Theme.TextDim)
        Icon:SetAttribute('ActiveColor', active_color or Theme.Text)
        Icon.ImageTransparency = 0
        Icon.ScaleType = Enum.ScaleType.Fit
        Icon.Parent = Tab

        local LeftSection = Instance.new('ScrollingFrame')
        LeftSection.Name = 'LeftSection'
        LeftSection.AutomaticCanvasSize = Enum.AutomaticSize.XY
        LeftSection.ScrollBarThickness = 0
        LeftSection.ScrollBarImageTransparency = 1
        LeftSection.Size = UDim2.new(0, 243, 0, 395)
        LeftSection.Selectable = false
        LeftSection.AnchorPoint = Vector2.new(0, 0)
        LeftSection.BackgroundTransparency = 1
        LeftSection.Position = UDim2.new(0, 203, 0, 67)
        LeftSection.BorderColor3 = Color3.fromRGB(0, 0, 0)
        LeftSection.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        LeftSection.BorderSizePixel = 0
        LeftSection.CanvasSize = UDim2.new(0, 0, 0.5, 0)
        LeftSection.Visible = false
        LeftSection.Parent = Sections

        local UIListLayout_L = Instance.new('UIListLayout')
        UIListLayout_L.Padding = UDim.new(0, 11)
        UIListLayout_L.HorizontalAlignment = Enum.HorizontalAlignment.Center
        UIListLayout_L.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout_L.Parent = LeftSection
        local UIPadding_L = Instance.new('UIPadding')
        UIPadding_L.PaddingTop = UDim.new(0, 1)
        UIPadding_L.Parent = LeftSection

        local RightSection = Instance.new('ScrollingFrame')
        RightSection.Name = 'RightSection'
        RightSection.AutomaticCanvasSize = Enum.AutomaticSize.XY
        RightSection.ScrollBarThickness = 0
        RightSection.Size = UDim2.new(0, 243, 0, 395)
        RightSection.Selectable = false
        RightSection.AnchorPoint = Vector2.new(0, 0)
        RightSection.ScrollBarImageTransparency = 1
        RightSection.BackgroundTransparency = 1
        RightSection.Position = UDim2.new(0, 474, 0, 67)
        RightSection.BorderColor3 = Color3.fromRGB(0, 0, 0)
        RightSection.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        RightSection.BorderSizePixel = 0
        RightSection.CanvasSize = UDim2.new(0, 0, 0.5, 0)
        RightSection.Visible = false
        RightSection.Parent = Sections

        local UIListLayout_R = Instance.new('UIListLayout')
        UIListLayout_R.Padding = UDim.new(0, 11)
        UIListLayout_R.HorizontalAlignment = Enum.HorizontalAlignment.Center
        UIListLayout_R.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout_R.Parent = RightSection

        local UIPadding_R = Instance.new('UIPadding')
        UIPadding_R.PaddingTop = UDim.new(0, 1)
        UIPadding_R.Parent = RightSection

        self._tab += 1

        if first_tab then
            self:update_tabs(Tab, LeftSection, RightSection)
            self:update_sections(LeftSection, RightSection)
        end

        Tab.MouseButton1Click:Connect(function()
            self:update_tabs(Tab, LeftSection, RightSection)
            self:update_sections(LeftSection, RightSection)
        end)

        function TabManager:create_module(settings)
            local LayoutOrderModule = 0;
            local ModuleManager = {
                _state = false,
                _size = 0,
                _multiplier = 0
            }

            if settings.section == 'right' then
                settings.section = RightSection
            else
                settings.section = LeftSection
            end

            local Module = Instance.new('Frame')
            Module.ClipsDescendants = true
            Module.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Module.BackgroundTransparency = 0
            Module.Position = UDim2.new(0.004115226212888956, 0, 0, 0)
            Module.Name = 'Module'
            Module.Size = UDim2.new(0, 241, 0, 93)
            Module.BorderSizePixel = 0
            Module.BackgroundColor3 = Theme.Group
            Module.Parent = settings.section
            table.insert(Library._elements, {obj = Module, prop = "BackgroundColor3", tKey = "Group"})

            local UIListLayout_Mod = Instance.new('UIListLayout')
            UIListLayout_Mod.Padding = UDim.new(0, 2)
            UIListLayout_Mod.SortOrder = Enum.SortOrder.LayoutOrder
            UIListLayout_Mod.Parent = Module

            local UICorner = Instance.new('UICorner')
            UICorner.CornerRadius = UDim.new(0, 9)
            UICorner.Parent = Module

            local UIStroke = Instance.new('UIStroke')
            UIStroke.Color = Theme.GroupStroke
            UIStroke.Transparency = 0.72
            UIStroke.Thickness = 1
            UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            UIStroke.Parent = Module
            table.insert(Library._elements, {obj = UIStroke, prop = "Color", tKey = "GroupStroke"})

            local ModuleScrollTrack = Instance.new('Frame')
            ModuleScrollTrack.Name = 'ModuleScrollTrack'
            ModuleScrollTrack.AnchorPoint = Vector2.new(1, 0)
            ModuleScrollTrack.Position = UDim2.new(1, 9, 0, 4)
            ModuleScrollTrack.Size = UDim2.new(0, 4, 0, 140)
            ModuleScrollTrack.BackgroundColor3 = Theme.Control
            ModuleScrollTrack.BackgroundTransparency = 0.55
            ModuleScrollTrack.BorderSizePixel = 0
            ModuleScrollTrack.ZIndex = 20
            ModuleScrollTrack.Visible = false
            ModuleScrollTrack.Parent = Handler
            table.insert(Library._elements, {obj = ModuleScrollTrack, prop = "BackgroundColor3", tKey = "Control"})

            local ModuleScrollTrackCorner = Instance.new('UICorner')
            ModuleScrollTrackCorner.CornerRadius = UDim.new(1, 0)
            ModuleScrollTrackCorner.Parent = ModuleScrollTrack

            local ModuleScrollThumb = Instance.new('Frame')
            ModuleScrollThumb.Name = 'Thumb'
            ModuleScrollThumb.AnchorPoint = Vector2.new(0.5, 0)
            ModuleScrollThumb.Position = UDim2.new(0.5, 0, 0, 0)
            ModuleScrollThumb.Size = UDim2.new(1, 0, 0, 88)
            ModuleScrollThumb.BackgroundColor3 = Theme.Accent
            ModuleScrollThumb.BackgroundTransparency = 0.08
            ModuleScrollThumb.BorderSizePixel = 0
            ModuleScrollThumb.ZIndex = 21
            ModuleScrollThumb.Parent = ModuleScrollTrack
            table.insert(Library._elements, {obj = ModuleScrollThumb, prop = "BackgroundColor3", tKey = "Accent"})

            local ModuleScrollThumbCorner = Instance.new('UICorner')
            ModuleScrollThumbCorner.CornerRadius = UDim.new(1, 0)
            ModuleScrollThumbCorner.Parent = ModuleScrollThumb

            local function UpdateModuleScrollIndicator()
                local moduleX
                local moduleY
                local sectionTop
                local viewportHeight
                local moduleWidth
                local moduleHeight
                local scale = UIScale.Scale

                if UserInputService.TouchEnabled then
                    moduleX = (Module.AbsolutePosition.X - Handler.AbsolutePosition.X) / scale
                    moduleY = (Module.AbsolutePosition.Y - Handler.AbsolutePosition.Y) / scale
                    sectionTop = (settings.section.AbsolutePosition.Y - Handler.AbsolutePosition.Y) / scale
                    viewportHeight = settings.section.AbsoluteWindowSize.Y / scale
                    moduleWidth = Module.AbsoluteSize.X / scale
                    moduleHeight = Module.AbsoluteSize.Y / scale
                else
                    moduleX = Module.AbsolutePosition.X - Handler.AbsolutePosition.X
                    moduleY = Module.AbsolutePosition.Y - Handler.AbsolutePosition.Y
                    sectionTop = settings.section.AbsolutePosition.Y - Handler.AbsolutePosition.Y
                    viewportHeight = settings.section.AbsoluteWindowSize.Y
                    moduleWidth = Module.AbsoluteSize.X
                    moduleHeight = Module.AbsoluteSize.Y
                end

                local moduleTop = math.max(moduleY + 4, sectionTop + 4)
                local moduleBottom = math.min(moduleY + moduleHeight - 4, sectionTop + viewportHeight - 4)
                local trackHeight = math.max(moduleBottom - moduleTop, 1)
                ModuleScrollTrack.Position = UDim2.fromOffset(moduleX + moduleWidth + 10, moduleTop)
                ModuleScrollTrack.Size = UDim2.new(0, 4, 0, trackHeight)

                local section = settings.section
                local viewportHeight = UserInputService.TouchEnabled and section.AbsoluteWindowSize.Y / scale or section.AbsoluteWindowSize.Y
                local canvasHeight = UserInputService.TouchEnabled and section.AbsoluteCanvasSize.Y / scale or section.AbsoluteCanvasSize.Y
                local scrollable = canvasHeight > viewportHeight + 1
                ModuleScrollTrack.Visible = ModuleManager._state and section.Visible and Library._ui_open

                if not scrollable then
                    ModuleScrollThumb.Size = UDim2.new(1, 0, 0, math.clamp(ModuleScrollTrack.AbsoluteSize.Y * 0.52, 80, 112))
                    ModuleScrollThumb.Position = UDim2.new(0.5, 0, 0, 0)
                    return
                end

                local trackHeight = math.max(ModuleScrollTrack.AbsoluteSize.Y, 1)
                local thumbMin = math.min(80, trackHeight)
                local thumbMax = math.min(math.max(thumbMin, 112), trackHeight)
                local thumbHeight = math.clamp(trackHeight * (viewportHeight / canvasHeight), thumbMin, thumbMax)
                local maxCanvasPosition = math.max(canvasHeight - viewportHeight, 1)
                local maxThumbPosition = math.max(trackHeight - thumbHeight, 0)
                local thumbPosition = maxThumbPosition * math.clamp(section.CanvasPosition.Y / maxCanvasPosition, 0, 1)

                ModuleScrollThumb.Size = UDim2.new(1, 0, 0, thumbHeight)
                ModuleScrollThumb.Position = UDim2.new(0.5, 0, 0, thumbPosition)
            end

            settings.section:GetPropertyChangedSignal('CanvasPosition'):Connect(UpdateModuleScrollIndicator)
            settings.section:GetPropertyChangedSignal('AbsoluteCanvasSize'):Connect(UpdateModuleScrollIndicator)
            settings.section:GetPropertyChangedSignal('AbsoluteWindowSize'):Connect(UpdateModuleScrollIndicator)
            settings.section:GetPropertyChangedSignal('Visible'):Connect(UpdateModuleScrollIndicator)
            Module:GetPropertyChangedSignal('AbsoluteSize'):Connect(UpdateModuleScrollIndicator)
            Module:GetPropertyChangedSignal('AbsolutePosition'):Connect(UpdateModuleScrollIndicator)

            local Header = Instance.new('TextButton')
            Header.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
            Header.TextColor3 = Color3.fromRGB(0, 0, 0)
            Header.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Header.Text = ''
            Header.AutoButtonColor = false
            Header.BackgroundTransparency = 1
            Header.Name = 'Header'
            Header.Size = UDim2.new(0, 241, 0, 93)
            Header.BorderSizePixel = 0
            Header.TextSize = 14
            Header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Header.Parent = Module

            local ModuleName = Instance.new('TextLabel')
            ModuleName.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
            ModuleName.TextColor3 = Theme.Text
            ModuleName.TextTransparency = 0
            if not settings.rich then
                ModuleName.Text = settings.title or "Module"
            else
                ModuleName.RichText = true
                ModuleName.Text = settings.richtext or "<font color='rgb(255,255,255)'>Angeli</font> user"
            end
            ModuleName.Name = 'ModuleName'
            ModuleName.Size = UDim2.new(0, 205, 0, 13)
            ModuleName.AnchorPoint = Vector2.new(0, 0.5)
            ModuleName.Position = UDim2.new(0, 14, 0, 22)
            ModuleName.BackgroundTransparency = 1
            ModuleName.TextXAlignment = Enum.TextXAlignment.Left
            ModuleName.BorderSizePixel = 0
            ModuleName.TextSize = 13
            ModuleName.Parent = Header
            table.insert(Library._elements, {obj = ModuleName, prop = "TextColor3", tKey = "Text"})

            local LockIcon = Instance.new('ImageLabel')
            LockIcon.Name = 'LockIcon'
            LockIcon.Image = 'rbxassetid://132906779122559'
            LockIcon.ImageColor3 = Theme.TextDim
            LockIcon.ImageTransparency = 0.14
            LockIcon.ScaleType = Enum.ScaleType.Fit
            LockIcon.AnchorPoint = Vector2.new(1, 0)
            LockIcon.Position = UDim2.new(1, -12, 0, 8.5)
            LockIcon.Size = UDim2.fromOffset(23, 23)
            LockIcon.BackgroundTransparency = 1
            LockIcon.BorderSizePixel = 0
            LockIcon.Parent = Header
            table.insert(Library._elements, {obj = LockIcon, prop = "ImageColor3", tKey = "TextDim"})

            local Description = Instance.new('TextLabel')
            Description.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
            Description.TextColor3 = Theme.TextDim
            Description.TextTransparency = 0
            Description.Text = settings.description or ''
            Description.Name = 'Description'
            Description.Size = UDim2.new(0, 205, 0, 13)
            Description.AnchorPoint = Vector2.new(0, 0.5)
            Description.Position = UDim2.new(0, 14, 0, 40)
            Description.BackgroundTransparency = 1
            Description.TextXAlignment = Enum.TextXAlignment.Left
            Description.BorderSizePixel = 0
            Description.TextSize = 10
            Description.Parent = Header
            table.insert(Library._elements, {obj = Description, prop = "TextColor3", tKey = "TextDim"})

            local Toggle = Instance.new('Frame')
            Toggle.Name = 'Toggle'
            Toggle.BackgroundTransparency = 0
            Toggle.Position = UDim2.new(0, 229, 0, 76)
            Toggle.AnchorPoint = Vector2.new(1, 0.5)
            Toggle.Size = UDim2.new(0, 30, 0, 16)
            Toggle.BorderSizePixel = 0
            Toggle.BackgroundColor3 = Theme.Control
            Toggle.Parent = Header
            table.insert(Library._elements, {obj = Toggle, prop = "BackgroundColor3", tKey = "Control", stateKey = false})

            local ToggleCorner = Instance.new('UICorner')
            ToggleCorner.CornerRadius = UDim.new(1, 0)
            ToggleCorner.Parent = Toggle

            local Circle = Instance.new('Frame')
            Circle.AnchorPoint = Vector2.new(0, 0.5)
            Circle.BackgroundTransparency = 0
            Circle.Position = UDim2.new(0, 2, 0.5, 0)
            Circle.Name = 'Circle'
            Circle.Size = UDim2.new(0, 12, 0, 12)
            Circle.BorderSizePixel = 0
            Circle.BackgroundColor3 = Theme.TextDim
            Circle.Parent = Toggle
            table.insert(Library._elements, {obj = Circle, prop = "BackgroundColor3", tKey = "TextDim", stateKey = false})

            local CircleCorner = Instance.new('UICorner')
            CircleCorner.CornerRadius = UDim.new(1, 0)
            CircleCorner.Parent = Circle

            local Keybind = Instance.new('TextButton')
            Keybind.Name = 'Keybind'
            Keybind.AutoButtonColor = false
            Keybind.Text = ''
            Keybind.BackgroundTransparency = 0
            Keybind.Position = UDim2.new(0, 14, 0, 67)
            Keybind.Size = UDim2.new(0, 38, 0, 16)
            Keybind.BorderSizePixel = 0
            Keybind.BackgroundColor3 = Theme.Control
            Keybind.Parent = Header
            table.insert(Library._elements, {obj = Keybind, prop = "BackgroundColor3", tKey = "Control"})

            local Icon = Instance.new('ImageLabel')
            Icon.Name = 'Icon'
            Icon.Image = settings.icon or 'rbxassetid://79095934438045'
            Icon.ImageColor3 = Theme.TextSoft
            Icon.ImageTransparency = 0
            Icon.ScaleType = Enum.ScaleType.Fit
            Icon.AnchorPoint = Vector2.new(0, 0.5)
            Icon.Position = UDim2.new(0, 13, 0, 75)
            Icon.Size = UDim2.fromOffset(17, 17)
            Icon.BackgroundTransparency = 1
            Icon.BorderSizePixel = 0
            Icon.Parent = Header
            table.insert(Library._elements, {obj = Icon, prop = "ImageColor3", tKey = "TextSoft"})

            Keybind.Position = UDim2.new(0, 34, 0, 67)

            local KeybindCorner = Instance.new('UICorner')
            KeybindCorner.CornerRadius = UDim.new(0, 2)
            KeybindCorner.Parent = Keybind

            local KeybindStroke = Instance.new('UIStroke')
            KeybindStroke.Color = Theme.GroupStroke
            KeybindStroke.Transparency = 0.68
            KeybindStroke.Thickness = 1
            KeybindStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            KeybindStroke.Parent = Keybind
            table.insert(Library._elements, {obj = KeybindStroke, prop = "Color", tKey = "GroupStroke"})

            local TextLabel = Instance.new('TextLabel')
            TextLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
            TextLabel.TextColor3 = Theme.TextSoft
            TextLabel.Text = 'None'
            TextLabel.Size = UDim2.new(1, -10, 1, 0)
            TextLabel.Position = UDim2.new(0, 5, 0, 0)
            TextLabel.BackgroundTransparency = 1
            TextLabel.TextXAlignment = Enum.TextXAlignment.Center
            TextLabel.TextYAlignment = Enum.TextYAlignment.Center
            TextLabel.BorderSizePixel = 0
            TextLabel.TextSize = 10
            TextLabel.Parent = Keybind
            table.insert(Library._elements, {obj = TextLabel, prop = "TextColor3", tKey = "TextSoft"})

            local Divider = Instance.new('Frame')
            Divider.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Divider.AnchorPoint = Vector2.new(0.5, 0)
            Divider.BackgroundTransparency = 0.72
            Divider.Position = UDim2.new(0.5, 0, 0.6200000047683716, 0)
            Divider.Name = 'Divider'
            Divider.Size = UDim2.new(0, 241, 0, 1)
            Divider.BorderSizePixel = 0
            Divider.BackgroundColor3 = Theme.Divider
            Divider.Parent = Header
            table.insert(Library._elements, {obj = Divider, prop = "BackgroundColor3", tKey = "Divider"})

            local Divider2 = Instance.new('Frame')
            Divider2.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Divider2.AnchorPoint = Vector2.new(0.5, 0)
            Divider2.BackgroundTransparency = 0.72
            Divider2.Position = UDim2.new(0.5, 0, 1, 0)
            Divider2.Name = 'Divider'
            Divider2.Size = UDim2.new(0, 241, 0, 1)
            Divider2.BorderSizePixel = 0
            Divider2.BackgroundColor3 = Theme.Divider
            Divider2.Parent = Header
            table.insert(Library._elements, {obj = Divider2, prop = "BackgroundColor3", tKey = "Divider"})

            local Options = Instance.new('Frame')
            Options.Name = 'Options'
            Options.BackgroundTransparency = 1
            Options.Position = UDim2.new(0, 0, 1, 2)
            Options.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Options.Size = UDim2.new(0, 241, 0, 8)
            Options.BorderSizePixel = 0
            Options.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Options.Parent = Module

            local UIPadding = Instance.new('UIPadding')
            UIPadding.PaddingTop = UDim.new(0, 8)
            UIPadding.Parent = Options

            local UIListLayout_Opts = Instance.new('UIListLayout')
            UIListLayout_Opts.Padding = UDim.new(0, 7)
            UIListLayout_Opts.HorizontalAlignment = Enum.HorizontalAlignment.Center
            UIListLayout_Opts.SortOrder = Enum.SortOrder.LayoutOrder
            UIListLayout_Opts.Parent = Options

            function ModuleManager:change_state(state)
                self._state = state
                ModuleScrollTrack.Visible = self._state and settings.section.Visible
                task.defer(UpdateModuleScrollIndicator)
                task.delay(0.3, UpdateModuleScrollIndicator)

                if self._state then
                    TweenService:Create(Module, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Size = UDim2.fromOffset(241, 93 + self._size + self._multiplier)
                    }):Play()

                    TweenService:Create(Toggle, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = Theme.Accent
                    }):Play()

                    TweenService:Create(Circle, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = Theme.Group,
                        Position = UDim2.new(1, -14, 0.5, 0)
                    }):Play()
                else
                    TweenService:Create(Module, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Size = UDim2.fromOffset(241, 93)
                    }):Play()

                    TweenService:Create(Toggle, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = Theme.Control
                    }):Play()

                    TweenService:Create(Circle, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = Theme.TextDim,
                        Position = UDim2.new(0, 2, 0.5, 0)
                    }):Play()
                end

                Library._config._flags[settings.flag] = self._state
                settings.callback(self._state)
                Config:save(game.GameId, Library._config)
            end

            function ModuleManager:connect_keybind()
                if not Library._config._keybinds[settings.flag] then return end
                Connections[settings.flag..'_keybind'] = UserInputService.InputBegan:Connect(function(input, process)
                    if process then return end
                    if tostring(input.KeyCode) ~= Library._config._keybinds[settings.flag] then return end
                    self:change_state(not self._state)
                end)
            end

            function ModuleManager:scale_keybind(empty)
                if Library._config._keybinds[settings.flag] and not empty then
                    local keybind_string = string.gsub(tostring(Library._config._keybinds[settings.flag]), 'Enum.KeyCode.', '')

                    local font_params = Instance.new('GetTextBoundsParams')
                    font_params.Text = keybind_string
                    font_params.Font = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold)
                    font_params.Size = 10
                    font_params.Width = 10000

                    local font_size = TextService:GetTextBoundsAsync(font_params)

                    Keybind.Size = UDim2.fromOffset(math.max(38, font_size.X + 12), 16)
                    TextLabel.Size = UDim2.new(1, -10, 1, 0)
                else
                    Keybind.Size = UDim2.fromOffset(38, 16)
                    TextLabel.Size = UDim2.new(1, -10, 1, 0)
                end
            end

            if Library._config._flags[settings.flag] == nil then
                Library._config._flags[settings.flag] = false
            end

            if Library:flag_type(settings.flag, 'boolean') then
                ModuleManager._state = Library._config._flags[settings.flag]
                settings.callback(ModuleManager._state)

                if ModuleManager._state then
                    Toggle.BackgroundColor3 = Theme.Accent
                    Circle.BackgroundColor3 = Theme.Group
                    Circle.Position = UDim2.new(1, -14, 0.5, 0)
                else
                    Toggle.BackgroundColor3 = Theme.Control
                    Circle.BackgroundColor3 = Theme.TextDim
                    Circle.Position = UDim2.new(0, 2, 0.5, 0)
                end
            end

            task.defer(UpdateModuleScrollIndicator)

            if Library._config._keybinds[settings.flag] then
                local keybind_string = string.gsub(tostring(Library._config._keybinds[settings.flag]), 'Enum.KeyCode.', '')
                TextLabel.Text = keybind_string

                ModuleManager:connect_keybind()
                ModuleManager:scale_keybind()
            end

            Connections[settings.flag..'_input_began'] = Keybind.MouseButton1Click:Connect(function()
                if Library._choosing_keybind then return end

                Library._choosing_keybind = true
                TextLabel.Text = '...'
                Keybind.BackgroundColor3 = Theme.ControlHover

                local function cancel_choose()
                    Library._choosing_keybind = false
                    Keybind.BackgroundColor3 = Theme.Control
                    if Library._config._keybinds[settings.flag] then
                        TextLabel.Text = string.gsub(tostring(Library._config._keybinds[settings.flag]), 'Enum.KeyCode.', '')
                    else
                        TextLabel.Text = 'None'
                    end
                    if Connections['keybind_choose_start'] then
                        Connections['keybind_choose_start']:Disconnect()
                        Connections['keybind_choose_start'] = nil
                    end
                end

                Connections['keybind_choose_start'] = UserInputService.InputBegan:Connect(function(input, process)
                    if process then return end
                    
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        local mousePos = UserInputService:GetMouseLocation()
                        local framePos = Keybind.AbsolutePosition
                        local frameSize = Keybind.AbsoluteSize
                        if mousePos.X < framePos.X or mousePos.X > framePos.X + frameSize.X or mousePos.Y < framePos.Y or mousePos.Y > framePos.Y + frameSize.Y then
                            cancel_choose()
                            return
                        end
                    end
                    
                    if input.KeyCode == Enum.KeyCode.Unknown then return end

                    if input.KeyCode == Enum.KeyCode.Backspace then
                        ModuleManager:scale_keybind(true)
                        Library._config._keybinds[settings.flag] = nil
                        TextLabel.Text = 'None'
                        cancel_choose()
                        Config:save(game.GameId, Library._config)
                        return
                    end

                    Library._config._keybinds[settings.flag] = tostring(input.KeyCode)

                    if Connections[settings.flag..'_keybind'] then
                        Connections[settings.flag..'_keybind']:Disconnect()
                        Connections[settings.flag..'_keybind'] = nil
                    end

                    ModuleManager:connect_keybind()
                    ModuleManager:scale_keybind()

                    local keybind_string = string.gsub(tostring(Library._config._keybinds[settings.flag]), 'Enum.KeyCode.', '')
                    TextLabel.Text = keybind_string
                    
                    cancel_choose()
                    Config:save(game.GameId, Library._config)
                end)
            end)

            Header.MouseButton1Click:Connect(function()
                ModuleManager:change_state(not ModuleManager._state)
            end)

            function ModuleManager:create_checkbox(settings)
                LayoutOrderModule = LayoutOrderModule + 1
                local CheckboxManager = { _state = false }

                if self._size == 0 then self._size = 11 end
                self._size += 28

                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size)
                end
                Options.Size = UDim2.fromOffset(241, self._size)

                local Row = Instance.new("TextButton")
                Row.Name = "ToggleRow"
                Row.Size = UDim2.new(0, 207, 0, 22)
                Row.BackgroundTransparency = 1
                Row.BorderSizePixel = 0
                Row.Text = ""
                Row.AutoButtonColor = false
                Row.Parent = Options
                Row.LayoutOrder = LayoutOrderModule

                local TitleLabel = Instance.new("TextLabel")
                TitleLabel.Name = "TitleLabel"
                TitleLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                TitleLabel.TextSize = 12
                TitleLabel.TextColor3 = Theme.Text
                TitleLabel.Text = settings.title or "Toggle"
                TitleLabel.Size = UDim2.new(1, -64, 1, 0)
                TitleLabel.Position = UDim2.new(0, 0, 0, 0)
                TitleLabel.BackgroundTransparency = 1
                TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
                TitleLabel.TextYAlignment = Enum.TextYAlignment.Center
                TitleLabel.Parent = Row
                table.insert(Library._elements, {obj = TitleLabel, prop = "TextColor3", tKey = "Text"})

                local KeybindBox = Instance.new("TextButton")
                KeybindBox.Name = "KeybindBox"
                KeybindBox.Size = UDim2.fromOffset(16, 16)
                KeybindBox.Position = UDim2.new(1, -38, 0.5, 0)
                KeybindBox.AnchorPoint = Vector2.new(1, 0.5)
                KeybindBox.BackgroundColor3 = Theme.Control
                KeybindBox.BorderSizePixel = 0
                KeybindBox.AutoButtonColor = false
                KeybindBox.Text = ""
                KeybindBox.Parent = Row
                table.insert(Library._elements, {obj = KeybindBox, prop = "BackgroundColor3", tKey = "Control"})

                local KeybindCorner = Instance.new("UICorner")
                KeybindCorner.CornerRadius = UDim.new(0, 2)
                KeybindCorner.Parent = KeybindBox

                local KeybindStroke = Instance.new("UIStroke")
                KeybindStroke.Color = Theme.GroupStroke
                KeybindStroke.Transparency = 0.72
                KeybindStroke.Thickness = 1
                KeybindStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                KeybindStroke.Parent = KeybindBox
                table.insert(Library._elements, {obj = KeybindStroke, prop = "Color", tKey = "GroupStroke"})

                local KeybindLabel = Instance.new("TextLabel")
                KeybindLabel.Name = "KeybindLabel"
                KeybindLabel.Size = UDim2.new(1, -4, 1, 0)
                KeybindLabel.Position = UDim2.new(0, 2, 0, 0)
                KeybindLabel.BackgroundTransparency = 1
                KeybindLabel.TextColor3 = Theme.TextSoft
                KeybindLabel.TextSize = 9
                KeybindLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                KeybindLabel.Text = Library._config._keybinds[settings.flag]
                    and string.gsub(tostring(Library._config._keybinds[settings.flag]), "Enum.KeyCode.", "")
                    or "..."
                KeybindLabel.Parent = KeybindBox
                table.insert(Library._elements, {obj = KeybindLabel, prop = "TextColor3", tKey = "TextSoft"})

                local Toggle = Instance.new("Frame")
                Toggle.Name = "Toggle"
                Toggle.Size = UDim2.fromOffset(31, 17)
                Toggle.Position = UDim2.new(1, 0, 0.5, 0)
                Toggle.AnchorPoint = Vector2.new(1, 0.5)
                Toggle.BackgroundColor3 = Theme.Control
                Toggle.BorderSizePixel = 0
                Toggle.Parent = Row
                table.insert(Library._elements, {obj = Toggle, prop = "BackgroundColor3", tKey = "Control", stateKey = false})

                local ToggleStroke = Instance.new("UIStroke")
                ToggleStroke.Color = Theme.GroupStroke
                ToggleStroke.Transparency = 0.62
                ToggleStroke.Thickness = 1
                ToggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                ToggleStroke.Parent = Toggle
                table.insert(Library._elements, {obj = ToggleStroke, prop = "Color", tKey = "GroupStroke"})

                local ToggleCorner = Instance.new("UICorner")
                ToggleCorner.CornerRadius = UDim.new(1, 0)
                ToggleCorner.Parent = Toggle

                local Knob = Instance.new("Frame")
                Knob.Name = "Knob"
                Knob.Size = UDim2.fromOffset(13, 13)
                Knob.Position = UDim2.new(0, 2, 0.5, 0)
                Knob.AnchorPoint = Vector2.new(0, 0.5)
                Knob.BackgroundColor3 = Theme.TextDim
                Knob.BorderSizePixel = 0
                Knob.Parent = Toggle
                table.insert(Library._elements, {obj = Knob, prop = "BackgroundColor3", tKey = "TextDim", stateKey = false})

                local KnobCorner = Instance.new("UICorner")
                KnobCorner.CornerRadius = UDim.new(1, 0)
                KnobCorner.Parent = Knob

                function CheckboxManager:change_state(state)
                    self._state = state
                    TweenService:Create(Toggle, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = state and Theme.Accent or Theme.Control
                    }):Play()
                    TweenService:Create(Knob, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        BackgroundColor3 = state and Theme.Group or Theme.TextDim,
                        Position = state and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
                    }):Play()
                    Library._config._flags[settings.flag] = self._state
                    settings.callback(self._state)
                    Config:save(game.GameId, Library._config)
                end

                if Library._config._flags[settings.flag] == nil then
                    Library._config._flags[settings.flag] = false
                end

                if Library:flag_type(settings.flag, "boolean") then
                    CheckboxManager._state = Library._config._flags[settings.flag]
                    if CheckboxManager._state then
                        Toggle.BackgroundColor3 = Theme.Accent
                        Knob.BackgroundColor3 = Theme.Group
                        Knob.Position = UDim2.new(1, -15, 0.5, 0)
                    else
                        Toggle.BackgroundColor3 = Theme.Control
                        Knob.BackgroundColor3 = Theme.TextDim
                        Knob.Position = UDim2.new(0, 2, 0.5, 0)
                    end
                    settings.callback(CheckboxManager._state)
                end

                KeybindBox.MouseButton1Click:Connect(function()
                    if Library._choosing_keybind then return end
                    Library._choosing_keybind = true
                    KeybindLabel.Text = "..."

                    local function cancel_choose()
                        Library._choosing_keybind = false
                        if Library._config._keybinds[settings.flag] then
                            KeybindLabel.Text = string.gsub(tostring(Library._config._keybinds[settings.flag]), "Enum.KeyCode.", "")
                        else
                            KeybindLabel.Text = "..."
                        end
                        if Connections['checkbox_keybind_choose'] then
                            Connections['checkbox_keybind_choose']:Disconnect()
                            Connections['checkbox_keybind_choose'] = nil
                        end
                    end

                    Connections['checkbox_keybind_choose'] = UserInputService.InputBegan:Connect(function(input, processed)
                        if processed then return end
                        
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            local mousePos = UserInputService:GetMouseLocation()
                            local framePos = KeybindBox.AbsolutePosition
                            local frameSize = KeybindBox.AbsoluteSize
                            if mousePos.X < framePos.X or mousePos.X > framePos.X + frameSize.X or mousePos.Y < framePos.Y or mousePos.Y > framePos.Y + frameSize.Y then
                                cancel_choose()
                                return
                            end
                        end
                        
                        if input.UserInputType ~= Enum.UserInputType.Keyboard and input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
                        if input.KeyCode == Enum.KeyCode.Unknown then return end
                        
                        if input.KeyCode == Enum.KeyCode.Backspace then
                            Library._config._keybinds[settings.flag] = nil
                            KeybindLabel.Text = "..."
                        else
                            Library._config._keybinds[settings.flag] = tostring(input.KeyCode)
                            KeybindLabel.Text = string.gsub(tostring(input.KeyCode), "Enum.KeyCode.", "")
                        end
                        cancel_choose()
                    end)
                end)

                KeybindBox.MouseButton1Click:Connect(function()
                    task.defer(function()
                        Row.Active = false
                        task.wait()
                        Row.Active = true
                    end)
                end)

                Row.MouseButton1Click:Connect(function()
                    CheckboxManager:change_state(not CheckboxManager._state)
                end)

                Connections[settings.flag .. "_row_keybind"] = UserInputService.InputBegan:Connect(function(input, processed)
                    if processed or Library._choosing_keybind then return end
                    local stored = Library._config._keybinds[settings.flag]
                    if stored and tostring(input.KeyCode) == stored then
                        CheckboxManager:change_state(not CheckboxManager._state)
                    end
                end)

                Library._flag_registry[settings.flag] = function(state)
                    CheckboxManager:change_state(state)
                end

                return CheckboxManager
            end

            function ModuleManager:create_keybind_row(settings)
                LayoutOrderModule = LayoutOrderModule + 1

                if self._size == 0 then self._size = 11 end
                self._size += 28

                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size)
                end
                Options.Size = UDim2.fromOffset(241, self._size)

                local Row = Instance.new('Frame')
                Row.Name = 'KeybindRow'
                Row.Size = UDim2.new(0, 207, 0, 22)
                Row.BackgroundTransparency = 1
                Row.BorderSizePixel = 0
                Row.LayoutOrder = LayoutOrderModule
                Row.Parent = Options

                local TitleLabel = Instance.new('TextLabel')
                TitleLabel.Name = 'TitleLabel'
                TitleLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                TitleLabel.TextSize = 12
                TitleLabel.TextColor3 = Theme.Text
                TitleLabel.Text = settings.title or 'Keybind'
                TitleLabel.Size = UDim2.new(1, -46, 1, 0)
                TitleLabel.Position = UDim2.new(0, 0, 0, 0)
                TitleLabel.BackgroundTransparency = 1
                TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
                TitleLabel.TextYAlignment = Enum.TextYAlignment.Center
                TitleLabel.Parent = Row
                table.insert(Library._elements, {obj = TitleLabel, prop = "TextColor3", tKey = "Text"})

                local KeybindBox = Instance.new('TextButton')
                KeybindBox.Name = 'KeybindBox'
                KeybindBox.Size = UDim2.fromOffset(38, 16)
                KeybindBox.AnchorPoint = Vector2.new(1, 0.5)
                KeybindBox.Position = UDim2.new(1, 0, 0.5, 0)
                KeybindBox.BackgroundColor3 = Theme.Control
                KeybindBox.BorderSizePixel = 0
                KeybindBox.AutoButtonColor = false
                KeybindBox.Text = ''
                KeybindBox.Parent = Row
                table.insert(Library._elements, {obj = KeybindBox, prop = "BackgroundColor3", tKey = "Control"})

                local KeybindCorner = Instance.new('UICorner')
                KeybindCorner.CornerRadius = UDim.new(0, 2)
                KeybindCorner.Parent = KeybindBox

                local KeybindStroke = Instance.new('UIStroke')
                KeybindStroke.Color = Theme.GroupStroke
                KeybindStroke.Transparency = 0.72
                KeybindStroke.Thickness = 1
                KeybindStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                KeybindStroke.Parent = KeybindBox
                table.insert(Library._elements, {obj = KeybindStroke, prop = "Color", tKey = "GroupStroke"})

                local KeybindLabel = Instance.new('TextLabel')
                KeybindLabel.Name = 'KeybindLabel'
                KeybindLabel.Size = UDim2.new(1, -4, 1, 0)
                KeybindLabel.Position = UDim2.new(0, 2, 0, 0)
                KeybindLabel.BackgroundTransparency = 1
                KeybindLabel.TextColor3 = Theme.TextSoft
                KeybindLabel.TextSize = 9
                KeybindLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                KeybindLabel.Text = Library._config._keybinds[settings.flag]
                    and string.gsub(tostring(Library._config._keybinds[settings.flag]), 'Enum.KeyCode.', '')
                    or '...'
                KeybindLabel.Parent = KeybindBox
                table.insert(Library._elements, {obj = KeybindLabel, prop = "TextColor3", tKey = "TextSoft"})

                local function resize_keybind_row()
                    local txt = KeybindLabel.Text
                    if txt == '...' then
                        KeybindBox.Size = UDim2.fromOffset(38, 16)
                        return
                    end
                    local fp = Instance.new('GetTextBoundsParams')
                    fp.Text = txt
                    fp.Font = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold)
                    fp.Size = 9
                    fp.Width = 10000
                    local fs = TextService:GetTextBoundsAsync(fp)
                    KeybindBox.Size = UDim2.fromOffset(math.max(38, fs.X + 12), 16)
                end

                resize_keybind_row()

                KeybindBox.MouseButton1Click:Connect(function()
                    if Library._choosing_keybind then return end
                    Library._choosing_keybind = true
                    KeybindLabel.Text = '...'
                    KeybindBox.Size = UDim2.fromOffset(38, 16)
                    KeybindBox.BackgroundColor3 = Theme.ControlHover

                    local function cancel_choose()
                        Library._choosing_keybind = false
                        KeybindBox.BackgroundColor3 = Theme.Control
                        if Library._config._keybinds[settings.flag] then
                            KeybindLabel.Text = string.gsub(tostring(Library._config._keybinds[settings.flag]), 'Enum.KeyCode.', '')
                        else
                            KeybindLabel.Text = '...'
                        end
                        resize_keybind_row()
                        if Connections['keybind_row_choose'] then
                            Connections['keybind_row_choose']:Disconnect()
                            Connections['keybind_row_choose'] = nil
                        end
                    end

                    Connections['keybind_row_choose'] = UserInputService.InputBegan:Connect(function(input, process)
                        if process then return end
                        
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            local mousePos = UserInputService:GetMouseLocation()
                            local framePos = KeybindBox.AbsolutePosition
                            local frameSize = KeybindBox.AbsoluteSize
                            if mousePos.X < framePos.X or mousePos.X > framePos.X + frameSize.X or mousePos.Y < framePos.Y or mousePos.Y > framePos.Y + frameSize.Y then
                                cancel_choose()
                                return
                            end
                        end

                        if input.KeyCode == Enum.KeyCode.Unknown then return end

                        if input.KeyCode == Enum.KeyCode.Backspace then
                            Library._config._keybinds[settings.flag] = nil
                            KeybindLabel.Text = '...'
                        else
                            Library._config._keybinds[settings.flag] = tostring(input.KeyCode)
                            KeybindLabel.Text = string.gsub(tostring(input.KeyCode), 'Enum.KeyCode.', '')
                        end

                        cancel_choose()
                    end)
                end)
            end

            function ModuleManager:create_slider(settings)
                LayoutOrderModule = LayoutOrderModule + 1

                local SliderManager = {}

                if self._size == 0 then self._size = 11 end
                self._size += 40

                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size)
                end
                Options.Size = UDim2.fromOffset(241, self._size)

                local Slider = Instance.new('TextButton')
                Slider.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                Slider.TextSize = 14
                Slider.TextColor3 = Color3.fromRGB(0, 0, 0)
                Slider.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Slider.Text = ''
                Slider.AutoButtonColor = false
                Slider.BackgroundTransparency = 1
                Slider.Name = 'Slider'
                Slider.Size = UDim2.new(0, 207, 0, 33)
                Slider.BorderSizePixel = 0
                Slider.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Slider.Parent = Options
                Slider.LayoutOrder = LayoutOrderModule

                local TextLabel = Instance.new('TextLabel')
                TextLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                TextLabel.TextSize = 12
                TextLabel.TextColor3 = Theme.Text
                TextLabel.TextTransparency = 0
                TextLabel.Text = settings.title
                TextLabel.Size = UDim2.new(0, 160, 0, 14)
                TextLabel.Position = UDim2.new(0, 0, 0, 0)
                TextLabel.BackgroundTransparency = 1
                TextLabel.TextXAlignment = Enum.TextXAlignment.Left
                TextLabel.BorderSizePixel = 0
                TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.Parent = Slider
                table.insert(Library._elements, {obj = TextLabel, prop = "TextColor3", tKey = "Text"})

                local Drag = Instance.new('Frame')
                Drag.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Drag.AnchorPoint = Vector2.new(0.5, 1)
                Drag.BackgroundTransparency = 0
                Drag.Position = UDim2.new(0.5, 0, 0.94, 0)
                Drag.Name = 'Drag'
                Drag.Size = UDim2.new(0, 207, 0, 6)
                Drag.BorderSizePixel = 0
                Drag.BackgroundColor3 = Theme.Group
                Drag.Parent = Slider
                table.insert(Library._elements, {obj = Drag, prop = "BackgroundColor3", tKey = "Group"})

                local UICorner = Instance.new('UICorner')
                UICorner.CornerRadius = UDim.new(1, 0)
                UICorner.Parent = Drag

                local Fill = Instance.new('Frame')
                Fill.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Fill.AnchorPoint = Vector2.new(0, 0.5)
                Fill.BackgroundTransparency = 0
                Fill.Position = UDim2.new(0, 0, 0.5, 0)
                Fill.Name = 'Fill'
                Fill.Size = UDim2.new(0, 103, 0, 6)
                Fill.BorderSizePixel = 0
                Fill.BackgroundColor3 = Theme.Accent
                Fill.Parent = Drag
                table.insert(Library._elements, {obj = Fill, prop = "BackgroundColor3", tKey = "Accent"})

                local UICorner = Instance.new('UICorner')
                UICorner.CornerRadius = UDim.new(0, 3)
                UICorner.Parent = Fill

                local Circle = Instance.new('Frame')
                Circle.AnchorPoint = Vector2.new(1, 0.5)
                Circle.Name = 'Circle'
                Circle.Position = UDim2.new(1, 0, 0.5, 0)
                Circle.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Circle.Size = UDim2.new(0, 10, 0, 10)
                Circle.BorderSizePixel = 0
                Circle.BackgroundColor3 = Theme.Accent
                Circle.Parent = Fill
                table.insert(Library._elements, {obj = Circle, prop = "BackgroundColor3", tKey = "Accent"})

                local UICorner = Instance.new('UICorner')
                UICorner.CornerRadius = UDim.new(1, 0)
                UICorner.Parent = Circle

                local CircleStroke = Instance.new('UIStroke')
                CircleStroke.Color = Theme.Group
                CircleStroke.Transparency = 0.58
                CircleStroke.Thickness = 1
                CircleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                CircleStroke.Parent = Circle
                table.insert(Library._elements, {obj = CircleStroke, prop = "Color", tKey = "Group"})

                local Value = Instance.new('TextLabel')
                Value.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                Value.TextColor3 = Theme.TextSoft
                Value.TextTransparency = 0.20000000298023224
                Value.Text = '50'
                Value.Name = 'Value'
                Value.Size = UDim2.new(0, 42, 0, 13)
                Value.AnchorPoint = Vector2.new(1, 0)
                Value.Position = UDim2.new(1, 0, 0, 0)
                Value.BackgroundTransparency = 1
                Value.TextXAlignment = Enum.TextXAlignment.Right
                Value.BorderSizePixel = 0
                Value.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Value.TextSize = 10
                Value.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Value.Parent = Slider
                table.insert(Library._elements, {obj = Value, prop = "TextColor3", tKey = "TextSoft"})

                function SliderManager:set_percentage(percentage)
                    local rounded_number = 0
                    if settings.round_number then
                        rounded_number = math.floor(percentage)
                    else
                        rounded_number = math.floor(percentage * 10) / 10
                    end

                    percentage = (percentage - settings.minimum_value) / (settings.maximum_value - settings.minimum_value)

                    local slider_size = math.clamp(percentage, 0.02, 1) * Drag.Size.X.Offset
                    local number_threshold = math.clamp(rounded_number, settings.minimum_value, settings.maximum_value)

                    Library._config._flags[settings.flag] = number_threshold
                    Value.Text = number_threshold

                    TweenService:Create(Fill, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Size = UDim2.fromOffset(slider_size, Drag.Size.Y.Offset)
                    }):Play()

                    settings.callback(number_threshold)
                    Config:save(game.GameId, Library._config)
                end

                function SliderManager:update()
                    local mouse_position = (mouse.X - Drag.AbsolutePosition.X) / Drag.Size.X.Offset
                    local percentage = settings.minimum_value + (settings.maximum_value - settings.minimum_value) * mouse_position
                    self:set_percentage(percentage)
                end

                function SliderManager:input()
                    SliderManager:update()
                    Connections['slider_drag_'..settings.flag] = mouse.Move:Connect(function()
                        SliderManager:update()
                    end)
                    Connections['slider_input_'..settings.flag] = UserInputService.InputEnded:Connect(function(input, process)
                        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
                        Connections:disconnect('slider_drag_'..settings.flag)
                        Connections:disconnect('slider_input_'..settings.flag)
                    end)
                end

                if Library:flag_type(settings.flag, 'number') then
                    if not settings.ignoresaved then
                        SliderManager:set_percentage(Library._config._flags[settings.flag])
                    else
                        SliderManager:set_percentage(settings.value)
                    end
                else
                    SliderManager:set_percentage(settings.value)
                end

                Slider.MouseButton1Down:Connect(function()
                    SliderManager:input()
                end)

                Library._flag_registry[settings.flag] = function(value)
                    SliderManager:set_percentage(value)
                end

                return SliderManager
            end

            function ModuleManager:create_button(settings)
                LayoutOrderModule = LayoutOrderModule + 1

                if self._size == 0 then self._size = 11 end
                self._size += 29

                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size + self._multiplier)
                end
                Options.Size = UDim2.fromOffset(241, self._size + self._multiplier)

                local Holder = Instance.new('Frame')
                Holder.Name = 'ButtonHolder'
                Holder.Size = UDim2.fromOffset(207, 23)
                Holder.BackgroundTransparency = 1
                Holder.BorderSizePixel = 0
                Holder.LayoutOrder = LayoutOrderModule
                Holder.Parent = Options

                local Btn = Instance.new('TextButton')
                Btn.Name = 'Button'
                Btn.AnchorPoint = Vector2.new(0, 1)
                Btn.Position = UDim2.new(0, 0, 1, 0)
                Btn.Size = UDim2.fromOffset(207, 22)
                Btn.BackgroundColor3 = Theme.Control
                Btn.BorderSizePixel = 0
                Btn.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                Btn.TextColor3 = Theme.Text
                Btn.TextSize = 12
                Btn.AutoButtonColor = false
                Btn.Text = settings.title
                Btn.Parent = Holder
                table.insert(Library._elements, {obj = Btn, prop = "BackgroundColor3", tKey = "Control"})
                table.insert(Library._elements, {obj = Btn, prop = "TextColor3", tKey = "Text"})

                local BtnCorner = Instance.new('UICorner')
                BtnCorner.CornerRadius = UDim.new(0, 4)
                BtnCorner.Parent = Btn

                local BtnStroke = Instance.new('UIStroke')
                BtnStroke.Color = Theme.GroupStroke
                BtnStroke.Transparency = 0.72
                BtnStroke.Thickness = 1
                BtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                BtnStroke.Parent = Btn
                table.insert(Library._elements, {obj = BtnStroke, prop = "Color", tKey = "GroupStroke"})

                Btn.MouseButton1Click:Connect(settings.callback)
            end

            function ModuleManager:create_input(settings)
                LayoutOrderModule = LayoutOrderModule + 1

                if self._size == 0 then self._size = 11 end
                self._size += 29

                if ModuleManager._state then
                    Module.Size = UDim2.fromOffset(241, 93 + self._size + self._multiplier)
                end
                Options.Size = UDim2.fromOffset(241, self._size + self._multiplier)

                local Holder = Instance.new('Frame')
                Holder.Name = 'TextboxHolder'
                Holder.Size = UDim2.fromOffset(207, 23)
                Holder.BackgroundTransparency = 1
                Holder.BorderSizePixel = 0
                Holder.LayoutOrder = LayoutOrderModule
                Holder.Parent = Options

                local Box = Instance.new('TextBox')
                Box.Name = 'TextBox'
                Box.AnchorPoint = Vector2.new(0, 1)
                Box.Position = UDim2.new(0, 0, 1, 0)
                Box.Size = UDim2.fromOffset(207, 22)
                Box.BackgroundColor3 = Theme.Control
                Box.BorderSizePixel = 0
                Box.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                Box.TextColor3 = Theme.Text
                Box.TextSize = 12
                Box.PlaceholderText = settings.placeholder or ''
                Box.PlaceholderColor3 = Theme.TextDim
                Box.Text = settings.value or ''
                Box.ClearTextOnFocus = false
                Box.Parent = Holder
                table.insert(Library._elements, {obj = Box, prop = "BackgroundColor3", tKey = "Control"})
                table.insert(Library._elements, {obj = Box, prop = "TextColor3", tKey = "Text"})
                table.insert(Library._elements, {obj = Box, prop = "PlaceholderColor3", tKey = "TextDim"})

                local BoxCorner = Instance.new('UICorner')
                BoxCorner.CornerRadius = UDim.new(0, 4)
                BoxCorner.Parent = Box

                local BoxStroke = Instance.new('UIStroke')
                BoxStroke.Color = Theme.GroupStroke
                BoxStroke.Transparency = 0.72
                BoxStroke.Thickness = 1
                BoxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                BoxStroke.Parent = Box
                table.insert(Library._elements, {obj = BoxStroke, prop = "Color", tKey = "GroupStroke"})

                Box.FocusLost:Connect(function()
                    settings.callback(Box.Text)
                end)

                return Box
            end

            function ModuleManager:create_dropdown(settings)
                if not settings.Order then
                    LayoutOrderModule = LayoutOrderModule + 1
                end

                local DropdownManager = {
                    _state = false,
                    _size = 0
                }

                if not settings.Order then
                    if self._size == 0 then self._size = 11 end
                    self._size += 53
                end

                if not settings.Order then
                    if ModuleManager._state then
                        Module.Size = UDim2.fromOffset(241, 93 + self._size)
                    end
                    Options.Size = UDim2.fromOffset(241, self._size)
                end

                local Dropdown = Instance.new('TextButton')
                Dropdown.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                Dropdown.TextColor3 = Color3.fromRGB(0, 0, 0)
                Dropdown.BorderColor3 = Color3.fromRGB(0, 0,0)
                Dropdown.Text = ''
                Dropdown.AutoButtonColor = false
                Dropdown.BackgroundTransparency = 1
                Dropdown.Name = 'Dropdown'
                Dropdown.Size = UDim2.new(0, 210, 0, 45)
                Dropdown.BorderSizePixel = 0
                Dropdown.TextSize = 14
                Dropdown.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Dropdown.Parent = Options

                if not settings.Order then
                    Dropdown.LayoutOrder = LayoutOrderModule
                else
                    Dropdown.LayoutOrder = settings.OrderValue
                end

                if not Library._config._flags[settings.flag] then
                    Library._config._flags[settings.flag] = {}
                end

                local TextLabel = Instance.new('TextLabel')
                TextLabel.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                TextLabel.TextSize = 11
                TextLabel.TextColor3 = Theme.Text
                TextLabel.TextTransparency = 0.20000000298023224
                TextLabel.Text = settings.title
                TextLabel.Size = UDim2.new(0, 207, 0, 13)
                TextLabel.BackgroundTransparency = 1
                TextLabel.TextXAlignment = Enum.TextXAlignment.Left
                TextLabel.BorderSizePixel = 0
                TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.Parent = Dropdown
                table.insert(Library._elements, {obj = TextLabel, prop = "TextColor3", tKey = "Text"})

                local Box = Instance.new('Frame')
                Box.ClipsDescendants = true
                Box.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Box.AnchorPoint = Vector2.new(0.5, 0)
                Box.BackgroundTransparency = 0
                Box.Position = UDim2.new(0.5, 0, 1.3, 0)
                Box.Name = 'Box'
                Box.Size = UDim2.new(0, 210, 0, 28)
                Box.BorderSizePixel = 0
                Box.BackgroundColor3 = Theme.Control
                Box.Parent = TextLabel
                table.insert(Library._elements, {obj = Box, prop = "BackgroundColor3", tKey = "Control"})

                local UICorner = Instance.new('UICorner')
                UICorner.CornerRadius = UDim.new(0, 5)
                UICorner.Parent = Box

                local BoxStroke = Instance.new('UIStroke')
                BoxStroke.Color = Theme.GroupStroke
                BoxStroke.Transparency = 0.48
                BoxStroke.Thickness = 1
                BoxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                BoxStroke.Parent = Box
                table.insert(Library._elements, {obj = BoxStroke, prop = "Color", tKey = "GroupStroke"})

                local Header = Instance.new('Frame')
                Header.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Header.AnchorPoint = Vector2.new(0.5, 0)
                Header.BackgroundTransparency = 1
                Header.Position = UDim2.new(0.5, 0, 0, 0)
                Header.Name = 'Header'
                Header.Size = UDim2.new(0, 210, 0, 28)
                Header.BorderSizePixel = 0
                Header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Header.Parent = Box

                local CurrentOption = Instance.new('TextLabel')
                CurrentOption.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                CurrentOption.TextColor3 = Theme.Text
                CurrentOption.TextTransparency = 0
                CurrentOption.Name = 'CurrentOption'
                CurrentOption.Size = UDim2.new(0, 164, 0, 16)
                CurrentOption.AnchorPoint = Vector2.new(0, 0.5)
                CurrentOption.Position = UDim2.new(0, 10, 0.5, 0)
                CurrentOption.BackgroundTransparency = 1
                CurrentOption.TextXAlignment = Enum.TextXAlignment.Left
                CurrentOption.BorderSizePixel = 0
                CurrentOption.BorderColor3 = Color3.fromRGB(0, 0, 0)
                CurrentOption.TextSize = 11
                CurrentOption.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                CurrentOption.Parent = Header
                table.insert(Library._elements, {obj = CurrentOption, prop = "TextColor3", tKey = "Text"})
                
                local UIGradient = Instance.new('UIGradient')
                UIGradient.Transparency = NumberSequence.new{
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(0.704, 0),
                    NumberSequenceKeypoint.new(0.872, 0.36250001192092896),
                    NumberSequenceKeypoint.new(1, 1)
                }
                UIGradient.Parent = CurrentOption

                local Arrow = Instance.new('ImageLabel')
                Arrow.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Arrow.AnchorPoint = Vector2.new(0, 0.5)
                Arrow.Image = 'rbxassetid://84232453189324'
                Arrow.ImageColor3 = Theme.TextDim
                Arrow.BackgroundTransparency = 1
                Arrow.Position = UDim2.new(1, -16, 0.5, 0)
                Arrow.Name = 'Arrow'
                Arrow.Size = UDim2.new(0, 9, 0, 9)
                Arrow.BorderSizePixel = 0
                Arrow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Arrow.Parent = Header
                table.insert(Library._elements, {obj = Arrow, prop = "ImageColor3", tKey = "TextDim"})

                local Options = Instance.new('ScrollingFrame')
                Options.ScrollBarImageColor3 = Color3.fromRGB(0, 0, 0)
                Options.Active = true
                Options.ScrollBarImageTransparency = 1
                Options.AutomaticCanvasSize = Enum.AutomaticSize.XY
                Options.ScrollBarThickness = 0
                Options.Name = 'Options'
                Options.Size = UDim2.new(0, 207, 0, 0)
                Options.BackgroundTransparency = 1
                Options.Position = UDim2.new(0, 0, 1, 0)
                Options.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Options.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Options.BorderSizePixel = 0
                Options.CanvasSize = UDim2.new(0, 0, 0.5, 0)
                Options.Parent = Box

                local UIListLayout = Instance.new('UIListLayout')
                UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
                UIListLayout.Parent = Options

                local UIPadding = Instance.new('UIPadding')
                UIPadding.PaddingTop = UDim.new(0, 4)
                UIPadding.PaddingLeft = UDim.new(0, 11)
                UIPadding.Parent = Options

                local UIListLayout2 = Instance.new('UIListLayout')
                UIListLayout2.SortOrder = Enum.SortOrder.LayoutOrder
                UIListLayout2.Parent = Box

                function DropdownManager:update(option)
                    if settings.multi_dropdown then
                        if not Library._config._flags[settings.flag] then
                            Library._config._flags[settings.flag] = {}
                        end

                        local CurrentTargetValue = nil

                        if #Library._config._flags[settings.flag] > 0 then
                            CurrentTargetValue = convertTableToString(Library._config._flags[settings.flag])
                        end

                        local selected = {}

                        if CurrentTargetValue then
                            for value in string.gmatch(CurrentTargetValue, "([^,]+)") do
                                local trimmedValue = value:match("^%s*(.-)%s*$")
                                if trimmedValue ~= "Label" then
                                    table.insert(selected, trimmedValue)
                                end
                            end
                        else
                            for value in string.gmatch(CurrentOption.Text, "([^,]+)") do
                                local trimmedValue = value:match("^%s*(.-)%s*$")
                                if trimmedValue ~= "Label" then
                                    table.insert(selected, trimmedValue)
                                end
                            end
                        end

                        local CurrentTextGet = convertStringToTable(CurrentOption.Text)

                        local optionSkibidi = "nil"
                        if typeof(option) ~= 'string' then
                            optionSkibidi = option.Name
                        else
                            optionSkibidi = option
                        end

                        for i, v in pairs(CurrentTextGet) do
                            if v == optionSkibidi then
                                table.remove(CurrentTextGet, i)
                                break
                            end
                        end

                        CurrentOption.Text = table.concat(selected, ", ")
                        local OptionsChild = {}

                        for _, object in Options:GetChildren() do
                            if object.Name == "Option" then
                                table.insert(OptionsChild, object.Text)
                                if table.find(selected, object.Text) then
                                    object.TextTransparency = 0.2
                                else
                                    object.TextTransparency = 0.6
                                end
                            end
                        end

                        CurrentTargetValue = convertStringToTable(CurrentOption.Text)

                        for _, v in CurrentTargetValue do
                            if not table.find(OptionsChild, v) and table.find(selected, v) then
                                table.remove(selected, _)
                            end
                        end

                        CurrentOption.Text = table.concat(selected, ", ")

                        Library._config._flags[settings.flag] = convertStringToTable(CurrentOption.Text)
                    else
                        CurrentOption.Text = (typeof(option) == "string" and option) or (option and option.Name) or ''
                        for _, object in Options:GetChildren() do
                            if object.Name == "Option" then
                                if object.Text == CurrentOption.Text then
                                    object.TextTransparency = 0.2
                                else
                                    object.TextTransparency = 0.6
                                end
                            end
                        end
                        Library._config._flags[settings.flag] = option
                    end

                    settings.callback(option)
                    Config:save(game.GameId, Library._config)
                end

                function DropdownManager:unfold_settings()
                    self._state = not self._state
                    local extra = self._state and self._size or 0

                    if self._state then
                        ModuleManager._multiplier += self._size
                    else
                        ModuleManager._multiplier -= self._size
                    end

                    TweenService:Create(Module, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Size = UDim2.fromOffset(241, 93 + ModuleManager._size + ModuleManager._multiplier)
                    }):Play()

                    TweenService:Create(Module.Options, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Size = UDim2.fromOffset(241, ModuleManager._size + ModuleManager._multiplier)
                    }):Play()

                    TweenService:Create(Dropdown, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Size = UDim2.fromOffset(210, 45 + extra)
                    }):Play()

                    TweenService:Create(Box, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Size = UDim2.fromOffset(210, 28 + extra)
                    }):Play()

                    TweenService:Create(Arrow, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                        Rotation = self._state and 180 or 0
                    }):Play()
                end

                function DropdownManager:refresh(new_options)
                    local old_size = self._size
                    for _, child in ipairs(Options:GetChildren()) do
                        if child.Name == 'Option' then child:Destroy() end
                    end
                    self._size = 8
                    for index, value in new_options do
                        local Option = Instance.new('TextButton')
                        Option.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                        Option.Active = false
                        Option.TextTransparency = 0.32
                        Option.AnchorPoint = Vector2.new(0, 0.5)
                        Option.TextSize = 11
                        Option.Size = UDim2.new(0, 184, 0, 19)
                        Option.TextColor3 = Theme.Text
                        Option.BorderColor3 = Color3.fromRGB(0, 0, 0)
                        Option.Text = (typeof(value) == 'string' and value) or value.Name
                        Option.AutoButtonColor = false
                        Option.Name = 'Option'
                        Option.BackgroundTransparency = 1
                        Option.TextXAlignment = Enum.TextXAlignment.Left
                        Option.Selectable = false
                        Option.Position = UDim2.new(0.04999988153576851, 0, 0.34210526943206787, 0)
                        Option.BorderSizePixel = 0
                        Option.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                        Option.Parent = Options
                        table.insert(Library._elements, {obj = Option, prop = "TextColor3", tKey = "Text"})
                        
                        local UIGradient = Instance.new('UIGradient')
                        UIGradient.Transparency = NumberSequence.new{
                            NumberSequenceKeypoint.new(0, 0),
                            NumberSequenceKeypoint.new(0.704, 0),
                            NumberSequenceKeypoint.new(0.872, 0.36250001192092896),
                            NumberSequenceKeypoint.new(1, 1)
                        }
                        UIGradient.Parent = Option
                        Option.MouseButton1Click:Connect(function()
                            DropdownManager:update(value)
                        end)
                        if settings.maximum_options and index > settings.maximum_options then continue end
                        self._size += 19
                        Options.Size = UDim2.fromOffset(210, self._size)
                    end
                    if self._state then
                        local diff = self._size - old_size
                        ModuleManager._multiplier += diff
                        Module.Size = UDim2.fromOffset(241, 93 + ModuleManager._size + ModuleManager._multiplier)
                        Module.Options.Size = UDim2.fromOffset(241, ModuleManager._size + ModuleManager._multiplier)
                        Dropdown.Size = UDim2.fromOffset(210, 45 + self._size)
                        Box.Size = UDim2.fromOffset(210, 28 + self._size)
                    end
                end

                if #settings.options > 0 then
                    DropdownManager._size = 8
                    for index, value in settings.options do
                        local Option = Instance.new('TextButton')
                        Option.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
                        Option.Active = false
                        Option.TextTransparency = 0.32
                        Option.AnchorPoint = Vector2.new(0, 0.5)
                        Option.TextSize = 11
                        Option.Size = UDim2.new(0, 184, 0, 19)
                        Option.TextColor3 = Theme.Text
                        Option.BorderColor3 = Color3.fromRGB(0, 0, 0)
                        Option.Text = (typeof(value) == "string" and value) or value.Name
                        Option.AutoButtonColor = false
                        Option.Name = 'Option'
                        Option.BackgroundTransparency = 1
                        Option.TextXAlignment = Enum.TextXAlignment.Left
                        Option.Selectable = false
                        Option.Position = UDim2.new(0.04999988153576851, 0, 0.34210526943206787, 0)
                        Option.BorderSizePixel = 0
                        Option.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                        Option.Parent = Options
                        table.insert(Library._elements, {obj = Option, prop = "TextColor3", tKey = "Text"})

                        local UIGradient = Instance.new('UIGradient')
                        UIGradient.Transparency = NumberSequence.new{
                            NumberSequenceKeypoint.new(0, 0),
                            NumberSequenceKeypoint.new(0.704, 0),
                            NumberSequenceKeypoint.new(0.872, 0.36250001192092896),
                            NumberSequenceKeypoint.new(1, 1)
                        }
                        UIGradient.Parent = Option

                        Option.MouseButton1Click:Connect(function()
                            if not Library._config._flags[settings.flag] then
                                Library._config._flags[settings.flag] = {}
                            end

                            if settings.multi_dropdown then
                                if table.find(Library._config._flags[settings.flag], value) then
                                    Library:remove_table_value(Library._config._flags[settings.flag], value)
                                else
                                    table.insert(Library._config._flags[settings.flag], value)
                                end
                            end

                            DropdownManager:update(value)
                        end)

                        if settings.maximum_options and index > settings.maximum_options then continue end
                        DropdownManager._size += 19
                        Options.Size = UDim2.fromOffset(210, DropdownManager._size)
                    end
                end

                if Library:flag_type(settings.flag, 'string') then
                    DropdownManager:update(Library._config._flags[settings.flag])
                elseif settings.options[1] then
                    DropdownManager:update(settings.options[1])
                end

                Dropdown.MouseButton1Click:Connect(function()
                    DropdownManager:unfold_settings()
                end)

                return DropdownManager
            end

            Library._flag_registry[settings.flag] = function(state)
                ModuleManager:change_state(state)
            end

            return ModuleManager
        end

        return TabManager
    end

    function self:SetColor(key, color)
        Theme[key] = color
        for _, element in ipairs(Library._elements) do
            if element.tKey == key then
                if element.stateKey ~= nil then
                else
                    element.obj[element.prop] = color
                end
            end
        end
        if key == "Gradient" then
            self._container_gradient.Color = color
            self._side_gradient.Color = color
        elseif key == "GroupStroke" then
            self._ui_stroke.Color = color
        end
        self:SaveConfig()
    end

    function self:GetColor(key)
        return Theme[key]
    end

    function self:SetBackground(image, transparency)
        if image and image ~= "" then
            self._background.Image = image
            self._background.Visible = true
        else
            self._background.Visible = false
        end
        if transparency ~= nil then
            self._background.ImageTransparency = transparency
        end
        self:SaveConfig()
    end

    function self:SaveConfig()
        pcall(function()
            if writefile then
                local ConfigData = { Theme = {} }
                for k, v in pairs(Theme) do
                    if typeof(v) == "Color3" then
                        ConfigData.Theme[k] = self:rgbToHex(v)
                    end
                end
                local json = HttpService:JSONEncode(ConfigData)
                writefile("Fallen/UI_Config.json", json)
            end
        end)
    end

    function self:LoadConfig()
        pcall(function()
            if isfile then
                local saved = readfile("Fallen/UI_Config.json")
                if saved then
                    local data = HttpService:JSONDecode(saved)
                    if data.Theme then
                        for k, v in pairs(data.Theme) do
                            if DefaultTheme[k] then
                                self:SetColor(k, self:hexToRGB(v))
                            end
                        end
                    end
                end
            end
        end)
    end
    
    self:LoadConfig()

    Connections['library_visiblity'] = UserInputService.InputBegan:Connect(function(input, process)
        local custom = Library._config._keybinds['Minimize_Keybind']
        if custom then
            if tostring(input.KeyCode) ~= custom then return end
        else
            if input.KeyCode ~= Enum.KeyCode.RightControl then return end
        end

        self._ui_open = not self._ui_open
        if Library._config._flags['UI_Gui_Visible'] then
            self:set_gui_visibility(self._ui_open)
            return
        end
        self:change_visiblity(self._ui_open)
    end)

    self._ui.Container.Handler.Minimize.MouseButton1Click:Connect(function()
        self._ui_open = not self._ui_open
        if Library._config._flags['UI_Gui_Visible'] then
            self:set_gui_visibility(self._ui_open)
            return
        end
        self:change_visiblity(self._ui_open)
    end)

    return self
end

function Library:build_interface_tab()
    local InterfaceTab = self:create_tab('Interface', 'rbxassetid://94381583400007', 16, Color3.fromRGB(100, 100, 100), Color3.fromRGB(190, 190, 190))

    local Container = self._ui.Container
    local Handler = Container.Handler

    local Custom_Asset = getcustomasset or getsynasset
    local Background_Folder = 'Fallen/Backgrounds'

    if Custom_Asset and not isfolder(Background_Folder) then
        makefolder(Background_Folder)
    end

    local function resolve_background(source)
        if source == '' then return '' end
        if source:match('^%d+$')        then return 'rbxassetid://'..source end
        if source:match('^rbx%a+://')   then return source end
        if not Custom_Asset             then return '' end
        if not source:match('^https?://') then
            return (isfile(source) and Custom_Asset(source)) or ''
        end

        local extension = source:match('%.(%a%a%a%a?)[%?#]')
                   or source:match('%.(%a%a%a%a?)$')
                   or 'png'
        local path = Background_Folder..'/'..source:gsub('%W', ''):sub(-48)..'.'..extension

        if not isfile(path) then
            local success, body = pcall(game.HttpGet, game, source, true)
            if not success then return '' end
            writefile(path, body)
        end
        return Custom_Asset(path)
    end

    local function set_background_image(source)
        local Background_Image = self._background
        local resolved = resolve_background(source)
        Background_Image.Image     = resolved
        Background_Image.Size      = UDim2.new(1, 0, 1, 0)
        Background_Image.Position  = UDim2.new(0, 0, 0, 0)
        Background_Image.ScaleType = Enum.ScaleType.Crop
    end

    local Transparent_Targets = { Module = true, Box = true, Keybind = true, Reset = true, AssetId = true }

    local function set_module_transparency(value)
        for _, object in self._ui:GetDescendants() do
            if Transparent_Targets[object.Name] then
                object.BackgroundTransparency = value
            end
        end
    end

    local Background_Presets = {
        ['Preset 1']  = 'https://i.pinimg.com/736x/bd/12/a5/bd12a561f083960f6c1382c54f4df234.jpg',
        ['Preset 2']  = 'https://i.pinimg.com/736x/53/bd/84/53bd848d7ca43b57612117292d7ff979.jpg',
        ['Preset 3']  = 'https://i.pinimg.com/736x/db/26/c7/db26c713d48342bd15c0ee8f623e19c6.jpg',
        ['Preset 4']  = 'https://i.pinimg.com/736x/dc/ad/10/dcad1026de88c854a17c6f4dd0b620c8.jpg',
        ['Preset 5']  = 'https://i.pinimg.com/736x/fe/88/90/fe88905bf7387c8827ffaf4a5aae7068.jpg',
        ['Preset 6']  = 'https://i.pinimg.com/736x/6a/82/5e/6a825e0e447466bad8295e9dc9b87486.jpg',
        ['Preset 7']  = 'https://i.pinimg.com/originals/10/ff/4f/10ff4f98a494e390e07b1a0e9eefa4be.gif',
        ['Preset 8']  = 'https://i.pinimg.com/736x/d8/87/49/d887496ab4b2dc63c0526b055ec34f60.jpg',
        ['Preset 9']  = 'https://i.pinimg.com/736x/b6/18/fc/b618fc66a0fd9442ddeb338ab5d283c7.jpg',
        ['Preset 10'] = 'https://i.pinimg.com/736x/f9/03/bc/f903bc265438bccc74579c6be2b9de0f.jpg',
        ['Preset 11'] = 'https://i.pinimg.com/1200x/ac/31/e3/ac31e3d45b625de96efe6712d4f3a3c2.jpg',
    }

    local Preset_Options = {
        'None',
        'Preset 1','Preset 2','Preset 3','Preset 4','Preset 5','Preset 6',
        'Preset 7','Preset 8','Preset 9','Preset 10','Preset 11',
    }

    local function find_module_frame(title)
        for _, object in self._ui:GetDescendants() do
            if object.Name == 'Module' then
                local header      = object:FindFirstChild('Header')
                local module_name = header and header:FindFirstChild('ModuleName')
                if module_name and module_name.Text == title then
                    return object
                end
            end
        end
    end

    local function build_reset_button(parent, layout_order, on_click)
        local Reset_Holder = Instance.new('Frame')
        Reset_Holder.Name                = 'ResetHolder'
        Reset_Holder.Size                = UDim2.fromOffset(207, 23)
        Reset_Holder.BackgroundTransparency = 1
        Reset_Holder.BorderSizePixel     = 0
        Reset_Holder.LayoutOrder         = layout_order
        Reset_Holder.Parent              = parent

        local Reset = Instance.new('TextButton')
        Reset.Name             = 'Reset'
        Reset.AnchorPoint      = Vector2.new(0, 1)
        Reset.Position         = UDim2.new(0, 0, 1, 0)
        Reset.Size             = UDim2.fromOffset(207, 22)
        Reset.BackgroundColor3 = Theme.Control
        Reset.BorderSizePixel  = 0
        Reset.FontFace         = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
        Reset.TextColor3       = Theme.Text
        Reset.TextSize         = 12
        Reset.AutoButtonColor  = false
        Reset.Text             = 'Reset'
        Reset.Parent           = Reset_Holder
        table.insert(self._elements, {obj = Reset, prop = "BackgroundColor3", tKey = "Control"})
        table.insert(self._elements, {obj = Reset, prop = "TextColor3", tKey = "Text"})

        local ResetCorner = Instance.new('UICorner')
        ResetCorner.CornerRadius = UDim.new(0, 4)
        ResetCorner.Parent       = Reset

        local ResetStroke = Instance.new('UIStroke')
        ResetStroke.Color            = Theme.GroupStroke
        ResetStroke.Transparency     = 0.72
        ResetStroke.Thickness        = 1
        ResetStroke.ApplyStrokeMode  = Enum.ApplyStrokeMode.Border
        ResetStroke.Parent           = Reset
        table.insert(self._elements, {obj = ResetStroke, prop = "Color", tKey = "GroupStroke"})

        Reset.MouseButton1Click:Connect(on_click)
    end

    local color_module = InterfaceTab:create_module({
        title       = 'Appearance',
        flag        = 'Gui_Colors',
        description = 'Customize UI Colors',
        section     = 'left',
        callback    = function(state) 
            if state then
                for k, v in pairs(Theme) do
                    self:SetColor(k, v)
                end
            end
        end,
    })

    local Color_Module_Frame = find_module_frame('Appearance')
    local Color_Targets = { 'Background', 'Group', 'Control', 'Accent', 'Text', 'TextDim' }
    local Color_Swatches = {}
    local Selected_Color_Target = 'Background'
    local Pointer_Offset = Vector2.zero
    local Current_Hue = 0
    local Current_Saturation = 0
    local Current_Value = 1

    if Color_Module_Frame then
        local Options = Color_Module_Frame.Options

        local Popup = Instance.new('Frame')
        Popup.Name            = 'ColorPopup'
        Popup.Position        = UDim2.fromOffset(8, 8)
        Popup.Size            = UDim2.fromOffset(214, 144)
        Popup.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
        Popup.BorderSizePixel = 0
        Popup.Visible         = false
        Popup.ZIndex          = 30
        Popup.Parent          = Handler

        local PopupCorner = Instance.new('UICorner')
        PopupCorner.CornerRadius = UDim.new(0, 9)
        PopupCorner.Parent       = Popup

        local PopupStroke = Instance.new('UIStroke')
        PopupStroke.Color           = Theme.GroupStroke
        PopupStroke.Transparency    = 0.72
        PopupStroke.Thickness       = 1
        PopupStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        PopupStroke.Parent          = Popup

        local Field = Instance.new('TextButton')
        Field.Name             = 'Field'
        Field.Position         = UDim2.fromOffset(10, 10)
        Field.Size             = UDim2.fromOffset(194, 100)
        Field.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        Field.BorderSizePixel  = 0
        Field.ClipsDescendants = true
        Field.AutoButtonColor  = false
        Field.Text             = ''
        Field.ZIndex           = 31
        Field.Parent           = Popup

        local FieldCorner = Instance.new('UICorner')
        FieldCorner.CornerRadius = UDim.new(0, 5)
        FieldCorner.Parent       = Field

        local Saturation = Instance.new('Frame')
        Saturation.Name             = 'Saturation'
        Saturation.Size             = UDim2.new(1, 0, 1, 0)
        Saturation.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Saturation.BorderSizePixel  = 0
        Saturation.ZIndex           = 32
        Saturation.Parent           = Field

        local SaturationGradient = Instance.new('UIGradient')
        SaturationGradient.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }
        SaturationGradient.Parent = Saturation

        local Brightness = Instance.new('Frame')
        Brightness.Name             = 'Brightness'
        Brightness.Size             = UDim2.new(1, 0, 1, 0)
        Brightness.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        Brightness.BorderSizePixel  = 0
        Brightness.ZIndex           = 33
        Brightness.Parent           = Field

        local BrightnessGradient = Instance.new('UIGradient')
        BrightnessGradient.Rotation    = 90
        BrightnessGradient.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }
        BrightnessGradient.Parent = Brightness

        local Cursor = Instance.new('Frame')
        Cursor.Name                 = 'Cursor'
        Cursor.AnchorPoint          = Vector2.new(0.5, 0.5)
        Cursor.Position             = UDim2.new(0, 0, 0, 0)
        Cursor.Size                 = UDim2.fromOffset(11, 11)
        Cursor.BackgroundTransparency = 1
        Cursor.BorderSizePixel      = 0
        Cursor.ZIndex               = 34
        Cursor.Parent               = Field

        local CursorCorner = Instance.new('UICorner')
        CursorCorner.CornerRadius = UDim.new(1, 0)
        CursorCorner.Parent       = Cursor

        local CursorStroke = Instance.new('UIStroke')
        CursorStroke.Color           = Color3.fromRGB(255, 255, 255)
        CursorStroke.Transparency    = 0
        CursorStroke.Thickness       = 2
        CursorStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        CursorStroke.Parent          = Cursor

        local Hue = Instance.new('TextButton')
        Hue.Name             = 'Hue'
        Hue.Position         = UDim2.fromOffset(10, 120)
        Hue.Size             = UDim2.fromOffset(194, 12)
        Hue.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Hue.BorderSizePixel  = 0
        Hue.AutoButtonColor  = false
        Hue.Text             = ''
        Hue.ZIndex           = 31
        Hue.Parent           = Popup

        local HueCorner = Instance.new('UICorner')
        HueCorner.CornerRadius = UDim.new(1, 0)
        HueCorner.Parent       = Hue

        local HueGradient = Instance.new('UIGradient')
        HueGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0,   0  )),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0  )),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,   255, 0  )),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0,   255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,   0,   255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0,   255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0,   0  )),
        }
        HueGradient.Parent = Hue

        local Hue_Knob = Instance.new('Frame')
        Hue_Knob.Name             = 'Knob'
        Hue_Knob.AnchorPoint      = Vector2.new(0.5, 0.5)
        Hue_Knob.Position         = UDim2.new(0, 0, 0.5, 0)
        Hue_Knob.Size             = UDim2.fromOffset(5, 16)
        Hue_Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Hue_Knob.BorderSizePixel  = 0
        Hue_Knob.ZIndex           = 32
        Hue_Knob.Parent           = Hue

        local Hue_Knob_Corner = Instance.new('UICorner')
        Hue_Knob_Corner.CornerRadius = UDim.new(1, 0)
        Hue_Knob_Corner.Parent       = Hue_Knob

        local Hue_Knob_Stroke = Instance.new('UIStroke')
        Hue_Knob_Stroke.Color           = Color3.fromRGB(20, 20, 24)
        Hue_Knob_Stroke.Transparency    = 0.42
        Hue_Knob_Stroke.Thickness       = 1
        Hue_Knob_Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        Hue_Knob_Stroke.Parent          = Hue_Knob

        local function set_color(hue, saturation, brightness)
            Current_Hue        = hue
            Current_Saturation = saturation
            Current_Value      = brightness

            local color    = Color3.fromHSV(hue, saturation, brightness)

            Field.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
            Cursor.Position        = UDim2.new(saturation, 0, 1 - brightness, 0)
            Hue_Knob.Position      = UDim2.new(hue, 0, 0.5, 0)
            Color_Swatches[Selected_Color_Target].BackgroundColor3 = color

            self:SetColor(Selected_Color_Target, color)
        end

        local function calibrate_pointer(frame)
            local inset    = GuiService:GetGuiInset()
            local location = UserInputService:GetMouseLocation()
            local top_left     = frame.AbsolutePosition
            local bottom_right = top_left + frame.AbsoluteSize

            for _, offset in { Vector2.zero, inset, -inset } do
                local point = location + offset
                if point.X >= top_left.X and point.X <= bottom_right.X
                   and point.Y >= top_left.Y and point.Y <= bottom_right.Y then
                    Pointer_Offset = offset
                    return
                end
            end
        end

        local function update_field()
            local location  = UserInputService:GetMouseLocation() + Pointer_Offset
            local saturation = math.clamp((location.X - Field.AbsolutePosition.X) / Field.AbsoluteSize.X, 0, 1)
            local brightness = math.clamp((location.Y - Field.AbsolutePosition.Y) / Field.AbsoluteSize.Y, 0, 1)
            set_color(Current_Hue, saturation, 1 - brightness)
        end

        local function update_hue()
            local location = UserInputService:GetMouseLocation() + Pointer_Offset
            local hue = math.clamp((location.X - Hue.AbsolutePosition.X) / Hue.AbsoluteSize.X, 0, 1)
            set_color(hue, Current_Saturation, Current_Value)
        end

        local function begin_drag(key, frame, update)
            calibrate_pointer(frame)
            update()

            self.Connections[key..'_move'] = UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseMovement
                   and input.UserInputType ~= Enum.UserInputType.Touch then return end
                update()
            end)

            self.Connections[key..'_ended'] = UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                   and input.UserInputType ~= Enum.UserInputType.Touch then return end
                self.Connections:disconnect(key..'_move')
                self.Connections:disconnect(key..'_ended')
            end)
        end

        local function close_popup()
            Popup.Visible = false
            for _, swatch in Color_Swatches do
                swatch.UIStroke.Transparency = 0.72
            end
        end

        local function open_popup(target, swatch)
            if Popup.Visible and Selected_Color_Target == target then
                close_popup()
                return
            end

            Selected_Color_Target = target

            for name, object in Color_Swatches do
                object.UIStroke.Transparency = name == target and 0 or 0.72
            end

            local scale      = Handler.AbsoluteSize.X / 752
            local relative_x = (swatch.AbsolutePosition.X - Handler.AbsolutePosition.X) / scale
            local relative_y = (swatch.AbsolutePosition.Y - Handler.AbsolutePosition.Y) / scale

            Popup.Position = UDim2.fromOffset(
                math.clamp(relative_x - 224, 8, 530),
                math.clamp(relative_y - 62,  8, 327)
            )
            Popup.Visible = true

            local hue, sat, bright = Color3.toHSV(Theme[target])
            set_color(hue, sat, bright)
        end

        local function build_color_row(index, target)
            local Row = Instance.new('TextButton')
            Row.Name                 = 'ColorRow'
            Row.Size                 = UDim2.fromOffset(207, 22)
            Row.BackgroundTransparency = 1
            Row.BorderSizePixel      = 0
            Row.AutoButtonColor      = false
            Row.Text                 = ''
            Row.LayoutOrder          = index
            Row.Parent               = Options

            local TitleLabel = Instance.new('TextLabel')
            TitleLabel.Name            = 'TitleLabel'
            TitleLabel.Size            = UDim2.new(1, -50, 1, 0)
            TitleLabel.Position        = UDim2.new(0, 0, 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.FontFace        = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
            TitleLabel.TextColor3      = Theme.Text
            TitleLabel.TextSize        = 12
            TitleLabel.Text            = target
            TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
            TitleLabel.TextYAlignment  = Enum.TextYAlignment.Center
            TitleLabel.Parent          = Row
            table.insert(self._elements, {obj = TitleLabel, prop = "TextColor3", tKey = "Text"})

            local Swatch = Instance.new('TextButton')
            Swatch.Name             = 'Swatch'
            Swatch.AnchorPoint      = Vector2.new(1, 0.5)
            Swatch.Position         = UDim2.new(1, 0, 0.5, 0)
            Swatch.Size             = UDim2.fromOffset(34, 16)
            Swatch.BackgroundColor3 = Theme[target]
            Swatch.BorderSizePixel  = 0
            Swatch.AutoButtonColor  = false
            Swatch.Text             = ''
            Swatch.Parent           = Row

            local SwatchCorner = Instance.new('UICorner')
            SwatchCorner.CornerRadius = UDim.new(0, 4)
            SwatchCorner.Parent       = Swatch

            local SwatchStroke = Instance.new('UIStroke')
            SwatchStroke.Color           = Theme.GroupStroke
            SwatchStroke.Transparency    = 0.72
            SwatchStroke.Thickness       = 1
            SwatchStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            SwatchStroke.Parent          = Swatch
            table.insert(self._elements, {obj = SwatchStroke, prop = "Color", tKey = "GroupStroke"})

            Swatch.MouseButton1Click:Connect(function() open_popup(target, Swatch) end)
            Row.MouseButton1Click:Connect(function()    open_popup(target, Swatch) end)

            Color_Swatches[target] = Swatch
        end

        for index, target in Color_Targets do
            build_color_row(index, target)
        end

        build_reset_button(Options, #Color_Targets + 3, function()
            close_popup()
            for target, color in pairs(DefaultTheme) do
                if typeof(color) == "Color3" then
                    self:SetColor(target, color)
                    Color_Swatches[target].BackgroundColor3 = color
                end
            end
        end)

        Field.MouseButton1Down:Connect(function()
            begin_drag('gui_color_field', Field, update_field)
        end)

        Hue.MouseButton1Down:Connect(function()
            begin_drag('gui_color_hue', Hue, update_hue)
        end)

        self.Connections['gui_color_section'] = Color_Module_Frame.Parent:GetPropertyChangedSignal('Visible'):Connect(function()
            if Color_Module_Frame.Parent.Visible then return end
            close_popup()
        end)

        self.Connections['gui_color_visiblity'] = Color_Module_Frame:GetPropertyChangedSignal('Size'):Connect(function()
            if Color_Module_Frame.AbsoluteSize.Y > 100 then return end
            close_popup()
        end)
        
        color_module._size = 282
        Options.Size = UDim2.fromOffset(241, color_module._size)
        if color_module._state then
            color_module:change_state(true)
        end
    end

    local image_module = InterfaceTab:create_module({
        title       = 'Background',
        flag        = 'Background_Image',
        description = 'Pick the Image Background',
        section     = 'right',
        callback    = function(state)
            if not self._background then return end
            self._background.Visible = state
            if state then
                set_module_transparency((self._config._flags['Background_Module_Transparency'] or 0) / 100)
                return
            end
            set_module_transparency(0)
        end,
    })

    local Saved_Background_Id = self._config._flags['Background_Image_Id']
    local Background_Image_Id = (typeof(Saved_Background_Id) == 'string' and Saved_Background_Id) or ''
    local Asset_Input

    local preset_dropdown = image_module:create_dropdown({
        title           = 'Preset',
        flag            = 'Background_Preset',
        options         = Preset_Options,
        multi_dropdown  = false,
        maximum_options = 4,
        callback        = function(value)
            local name   = (typeof(value) == 'string' and value) or (typeof(value) == 'table' and value.Name)
            local source = (name and Background_Presets[name]) or ''
            Background_Image_Id = source
            set_background_image(source)
            if Asset_Input then Asset_Input.Text = source end
            self._config._flags['Background_Image_Id'] = source
        end,
    })

    local transparency_slider = image_module:create_slider({
        title         = 'Transparency',
        flag          = 'Background_Image_Transparency',
        minimum_value = 0,
        maximum_value = 100,
        value         = 50,
        round_number  = true,
        callback      = function(value)
            if not self._background then return end
            self._background.ImageTransparency = value / 100
        end,
    })

    local module_transparency_slider = image_module:create_slider({
        title         = 'Module Transparency',
        flag          = 'Background_Module_Transparency',
        minimum_value = 0,
        maximum_value = 100,
        value         = 0,
        round_number  = true,
        callback      = function(value)
            set_module_transparency(value / 100)
        end,
    })

    local Image_Module_Frame = find_module_frame('Background')

    if Image_Module_Frame then
        local Options = Image_Module_Frame.Options

        local Row = Instance.new('Frame')
        Row.Name                 = 'AssetRow'
        Row.Size                 = UDim2.fromOffset(207, 24)
        Row.BackgroundTransparency = 1
        Row.BorderSizePixel      = 0
        Row.LayoutOrder          = 0
        Row.Parent               = Options

        local Input = Instance.new('TextBox')
        Input.Name                 = 'AssetId'
        Input.AnchorPoint          = Vector2.new(0, 0.5)
        Input.Position             = UDim2.new(0, 0, 0.5, 0)
        Input.Size                 = UDim2.fromOffset(207, 22)
        Input.BackgroundColor3     = Theme.Control
        Input.BorderSizePixel      = 0
        Input.FontFace             = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
        Input.TextColor3           = Theme.Text
        Input.PlaceholderColor3    = Theme.TextDim
        Input.PlaceholderText      = 'Asset ID or Image Link'
        Input.TextSize             = 12
        Input.ClearTextOnFocus     = false
        Input.ClipsDescendants     = true
        Input.Text                 = Background_Image_Id
        Input.Parent               = Row
        table.insert(self._elements, {obj = Input, prop = "BackgroundColor3", tKey = "Control"})
        table.insert(self._elements, {obj = Input, prop = "TextColor3", tKey = "Text"})
        table.insert(self._elements, {obj = Input, prop = "PlaceholderColor3", tKey = "TextDim"})

        Asset_Input = Input

        local InputCorner = Instance.new('UICorner')
        InputCorner.CornerRadius = UDim.new(0, 4)
        InputCorner.Parent       = Input

        local InputStroke = Instance.new('UIStroke')
        InputStroke.Color           = Theme.GroupStroke
        InputStroke.Transparency    = 0.72
        InputStroke.Thickness       = 1
        InputStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        InputStroke.Parent          = Input
        table.insert(self._elements, {obj = InputStroke, prop = "Color", tKey = "GroupStroke"})

        Input.FocusLost:Connect(function()
            local source = Input.Text:match('^%s*(.-)%s*$')
            Input.Text          = source
            Background_Image_Id = source
            set_background_image(source)
            self._config._flags['Background_Image_Id'] = source
        end)

        build_reset_button(Options, 4, function()
            Input.Text          = ''
            Background_Image_Id = ''
            set_background_image('')
            preset_dropdown:update('None')
            transparency_slider:set_percentage(50)
            module_transparency_slider:set_percentage(0)
            self._config._flags['Background_Image_Id'] = ''
        end)

        image_module._size += 62
        Options.Size = UDim2.fromOffset(241, image_module._size)

        if image_module._state then
            image_module:change_state(true)
        end
    end

    set_background_image(Background_Image_Id)
    set_module_transparency((self._config._flags['Background_Module_Transparency'] or 0) / 100)

    local settings_module = InterfaceTab:create_module({
        title       = 'Settings',
        flag        = 'UI_Settings',
        description = 'UI Behavior and Overlay',
        section     = 'left',
        callback    = function(state) end,
    })

    settings_module:create_checkbox({
        title    = 'Hide on Minimized',
        flag     = 'UI_Gui_Visible',
        callback = function(state) end,
    })

    local function FpsBooster(state)
        if state then
            pcall(function()
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 1e9
                Lighting.Brightness = 1
                Lighting.Ambient = Color3.fromRGB(140,140,140)
                Lighting.OutdoorAmbient = Color3.fromRGB(140,140,140)
                Lighting.EnvironmentDiffuseScale = 0
                Lighting.EnvironmentSpecularScale = 0
            end)

            for _,v in ipairs(Lighting:GetChildren()) do
                if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("Sky") then
                    v:Destroy()
                end
            end

            for _,obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    obj.CastShadow = false
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    obj:Destroy()
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Explosion") or obj:IsA("Smoke") or obj:IsA("Fire") then
                    obj:Destroy()
                end
            end

            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        else
            pcall(function()
                Lighting.GlobalShadows = true
                Lighting.FogEnd = 100000
                Lighting.Brightness = 2
                Lighting.Ambient = Color3.fromRGB(128, 128, 128)
                Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
                Lighting.EnvironmentDiffuseScale = 1
                Lighting.EnvironmentSpecularScale = 1
            end)
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        end
    end

    settings_module:create_checkbox({
        title    = 'FPS Booster',
        flag     = 'UI_FPS_Booster',
        callback = function(state) 
            FpsBooster(state)
        end,
    })

    local FpsGui = Instance.new("ScreenGui")
    FpsGui.Name = "FpsDisplay"
    FpsGui.ResetOnSpawn = false
    FpsGui.Parent = CoreGui

    local FpsFrame = Instance.new("TextLabel")
    FpsFrame.Size = UDim2.new(0, 200, 0, 50)
    FpsFrame.Position = UDim2.new(0.5, -100, 0, 20)
    FpsFrame.BackgroundTransparency = 1
    FpsFrame.TextScaled = true
    FpsFrame.Font = Enum.Font.Arcade
    FpsFrame.TextColor3 = Color3.new(1, 1, 1)
    FpsFrame.Parent = FpsGui
    FpsFrame.Active = true
    FpsFrame.Draggable = true
    FpsGui.Enabled = false

    local lastTime = tick()
    local frameCount = 0

    RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local currentTime = tick()
        if (currentTime - lastTime) >= 1 then
            local fps = frameCount
            frameCount = 0
            lastTime = currentTime

            FpsFrame.Text = string.format("FPS: %d", fps)
        end
    end)

    settings_module:create_checkbox({
        title    = 'Show FPS (Text)',
        flag     = 'UI_Show_Fps_Text',
        callback = function(state)
            FpsGui.Enabled = state
            if state then
                PingGraphGui.Enabled = false
                self._flag_registry['UI_Show_Ping_Graph'](false)
            end
        end,
    })

    local PingGraphGui = Instance.new("ScreenGui")
    PingGraphGui.Name = "PingGraph"
    PingGraphGui.ResetOnSpawn = false
    PingGraphGui.IgnoreGuiInset = true
    PingGraphGui.Parent = CoreGui
    PingGraphGui.Enabled = false

    local GRAPH_WIDTH = 200
    local GRAPH_HEIGHT = 35
    local MAX_POINTS = 60
    local UPDATE_INTERVAL = 0.2
    local SMOOTH_SAMPLES = 3

    local PingContainer = Instance.new("Frame")
    PingContainer.Size = UDim2.new(0, GRAPH_WIDTH + 12, 0, GRAPH_HEIGHT + 34)
    PingContainer.Position = UDim2.new(0, 15, 0, 15)
    PingContainer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    PingContainer.BackgroundTransparency = 0.15
    PingContainer.BorderSizePixel = 0
    PingContainer.Active = true
    PingContainer.Draggable = true
    PingContainer.ClipsDescendants = true
    PingContainer.Parent = PingGraphGui

    local PingCorner = Instance.new("UICorner")
    PingCorner.CornerRadius = UDim.new(0, 6)
    PingCorner.Parent = PingContainer

    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 20)
    TopBar.Position = UDim2.new(0, 0, 0, 0)
    TopBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    TopBar.BackgroundTransparency = 0.1
    TopBar.BorderSizePixel = 0
    TopBar.Parent = PingContainer

    local TopBarCorner = Instance.new("UICorner")
    TopBarCorner.CornerRadius = UDim.new(0, 6)
    TopBarCorner.Parent = TopBar

    local PingTitle = Instance.new("TextLabel")
    PingTitle.Size = UDim2.new(1, 0, 0, 20)
    PingTitle.Position = UDim2.new(0, 0, 0, 0)
    PingTitle.BackgroundTransparency = 1
    PingTitle.FontFace = Font.new("rbxasset://fonts/families/SFPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    PingTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    PingTitle.TextSize = 10
    PingTitle.TextXAlignment = Enum.TextXAlignment.Center
    PingTitle.TextYAlignment = Enum.TextYAlignment.Center
    PingTitle.Text = "PING: --  |  AVG: --  |  MAX: --"
    PingTitle.TextStrokeTransparency = 0.4
    PingTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    PingTitle.Parent = PingContainer

    local Canvas = Instance.new("Frame")
    Canvas.Size = UDim2.new(0, GRAPH_WIDTH, 0, GRAPH_HEIGHT)
    Canvas.Position = UDim2.new(0, 4, 0, 22)
    Canvas.BackgroundTransparency = 1
    Canvas.BorderSizePixel = 0
    Canvas.ClipsDescendants = true
    Canvas.Parent = PingContainer

    for i = 0, 2 do
        local line = Instance.new("Frame")
        line.Size = UDim2.new(1, 0, 0, 0.5)
        line.Position = UDim2.new(0, 0, 0, i * (GRAPH_HEIGHT / 2))
        line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        line.BackgroundTransparency = 0.95
        line.BorderSizePixel = 0
        line.Parent = Canvas
    end

    local GraphLines = {}
    for i = 1, MAX_POINTS - 1 do
        local line = Instance.new("Frame")
        line.Size = UDim2.new(0, 4, 0, 2)
        line.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
        line.BorderSizePixel = 0
        line.Visible = false
        line.Parent = Canvas
        table.insert(GraphLines, line)
    end

    local Stats = { min = math.huge, max = 0, sum = 0, count = 0, avg = 0, current = 0 }
    local pingBuffer = {}
    local lastUpdate = 0
    local maxPingScale = 80
    local PingHistory = {}
    local RawPingCache = 0
    local PingCacheTime = 0

    local function GetRawPing()
        local now = tick()
        if now - PingCacheTime < 0.05 then
            return RawPingCache
        end
        local ok, val = pcall(function()
            return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and type(val) == "number" and val > 0 then
            RawPingCache = val
            PingCacheTime = now
            return val
        end
        return RawPingCache
    end

    local function GetSmoothPing()
        local raw = GetRawPing()
        table.insert(PingHistory, raw)
        if #PingHistory > SMOOTH_SAMPLES then
            table.remove(PingHistory, 1)
        end
        local sum = 0
        for _, v in ipairs(PingHistory) do
            sum = sum + v
        end
        return #PingHistory > 0 and sum / #PingHistory or raw
    end

    task.spawn(function()
        while true do
            GetSmoothPing()
            task.wait(1)
        end
    end)

    local function UpdateGraph()
        local currentPing = GetSmoothPing()
        Stats.current = currentPing
        
        if currentPing > 0 then
            if currentPing < Stats.min then Stats.min = currentPing end
            if currentPing > Stats.max then Stats.max = currentPing end
            Stats.sum = Stats.sum + currentPing
            Stats.count = Stats.count + 1
            Stats.avg = Stats.count > 0 and Stats.sum / Stats.count or 0
        end
        
        PingTitle.Text = string.format("PING: %d  |  AVG: %.0f  |  MAX: %.0f", math.round(currentPing), Stats.avg, Stats.max)
        
        table.insert(pingBuffer, currentPing)
        if #pingBuffer > MAX_POINTS then
            table.remove(pingBuffer, 1)
        end
        
        local localMax = 20
        for _, v in ipairs(pingBuffer) do
            if v > localMax then localMax = v end
        end
        localMax = localMax * 1.15
        localMax = math.max(localMax, 30)
        maxPingScale = maxPingScale + (localMax - maxPingScale) * 0.1
        maxPingScale = math.max(maxPingScale, 25)
        
        local count = #pingBuffer
        
        for i = 1, MAX_POINTS - 1 do
            local line = GraphLines[i]
            if i < count then
                local ping1 = pingBuffer[i] or 0
                local ping2 = pingBuffer[i + 1] or 0
                local norm1 = math.clamp(ping1 / maxPingScale, 0, 1)
                local norm2 = math.clamp(ping2 / maxPingScale, 0, 1)
                local x1 = (i - 1) * (GRAPH_WIDTH / MAX_POINTS)
                local x2 = i * (GRAPH_WIDTH / MAX_POINTS)
                local y1 = GRAPH_HEIGHT - (norm1 * (GRAPH_HEIGHT - 2)) - 1
                local y2 = GRAPH_HEIGHT - (norm2 * (GRAPH_HEIGHT - 2)) - 1
                local angle = math.atan2(y2 - y1, x2 - x1)
                local length = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
                local avgPing = (ping1 + ping2) / 2
                local color
                if avgPing < 40 then
                    color = Color3.fromRGB(0, 255, 80)
                elseif avgPing < 70 then
                    color = Color3.fromRGB(255, 255, 0)
                elseif avgPing < 120 then
                    color = Color3.fromRGB(255, 180, 0)
                else
                    color = Color3.fromRGB(255, 60, 60)
                end
                line.Size = UDim2.new(0, length, 0, 2)
                line.Position = UDim2.new(0, x1, 0, y1 - 1)
                line.Rotation = math.deg(angle)
                line.BackgroundColor3 = color
                line.Visible = true
            else
                line.Visible = false
            end
        end
    end

    RunService.RenderStepped:Connect(function(delta)
        if not PingGraphGui.Enabled then return end
        lastUpdate = lastUpdate + delta
        if lastUpdate >= UPDATE_INTERVAL then
            lastUpdate = 0
            UpdateGraph()
        end
    end)

    settings_module:create_checkbox({
        title    = 'Show Ping (Graph)',
        flag     = 'UI_Show_Ping_Graph',
        callback = function(state)
            PingGraphGui.Enabled = state
            if state then
                FpsGui.Enabled = false
                self._flag_registry['UI_Show_Fps_Text'](false)
            end
        end,
    })

    local notif_module = InterfaceTab:create_module({
        title       = 'Notifications',
        flag        = 'UI_Notifications',
        description = 'Configure notification behavior',
        section     = 'right',
        callback    = function(state) end,
    })

    notif_module:create_dropdown({
        title           = 'Side',
        flag            = 'UI_Notif_Side',
        options         = { 'Left', 'Right' },
        multi_dropdown  = false,
        maximum_options = 2,
        callback        = function(value)
            local side = (typeof(value) == "string" and value) or value.Name
            Library._notif_side = side
            UpdateNotificationPosition()
        end,
    })

    notif_module:create_slider({
        title         = 'Opacity',
        flag          = 'UI_Notif_Opacity',
        minimum_value = 0,
        maximum_value = 100,
        value         = 0,
        round_number  = true,
        callback      = function(value)
            Library._notif_opacity = value / 100
        end,
    })
end

return Library
