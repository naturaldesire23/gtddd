--[[
  MCUILib — Minecraft-style UI Library for Roblox
  Author: Axiom
  
  Assets (ImageLabel/ImageButton ids):
    Activity:     137527339160230
    AlertTriangle:112102474509324
    Misc:          92373371786861
    Atom:         119051552929078
    Ban:          109685306480139
    Battery:      102599812606554
    Bug:           75649814233484
    Eye:          127234874352422
    ArrowUp:      104406213770080
    ArrowDown:    134161790366779

  Usage:
    local MC = require(path.to.MCUILib)
    local win = MC.Window("Combat", MC.Icons.Eye)
    local section = win:Section("⚔ FEATURES")
    section:Toggle("Kill Aura", MC.Icons.Activity, true, function(val) print(val) end)
    section:Slider("Range", 1, 6, 3.8, 0.1, function(val) print(val) end)
    section:Keybind("Toggle", Enum.KeyCode.F4, function(key) print(key) end)
    section:Input("Tag", "enter text...", function(txt) print(txt) end)
    section:SegmentedButton({"Single","Multi","Legit"}, 1, function(idx, lbl) print(lbl) end)
    section:Button("Save Config", "accent", function() print("saved") end)
    section:ColorPicker("ESP Color", Color3.fromHex("#55CC44"), function(c) print(c) end)
    win:Show()
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ──────────────────────────────────────────────
-- THEME
-- ──────────────────────────────────────────────
local Theme = {
  BG          = Color3.fromHex("#1a1a1a"),
  Panel       = Color3.fromHex("#2a2a2a"),
  Row         = Color3.fromHex("#1e1e1e"),
  RowHover    = Color3.fromHex("#303030"),
  Border      = Color3.fromHex("#555555"),
  BorderDark  = Color3.fromHex("#111111"),
  Text        = Color3.fromHex("#f0f0f0"),
  TextMuted   = Color3.fromHex("#aaaaaa"),
  Green       = Color3.fromHex("#55cc44"),
  GreenDark   = Color3.fromHex("#2a7020"),
  Red         = Color3.fromHex("#cc3333"),
  Accent      = Color3.fromHex("#4a90d9"),
  AccentDark  = Color3.fromHex("#2060a0"),
  SliderTrack = Color3.fromHex("#111111"),
  SliderThumb = Color3.fromHex("#888888"),
  InputBG     = Color3.fromHex("#111111"),
  TitleBG     = Color3.fromHex("#222222"),
}

-- ──────────────────────────────────────────────
-- ICON ASSET IDs  (use as ImageLabel.Image)
-- ──────────────────────────────────────────────
local Icons = {
  Activity      = "rbxassetid://137527339160230",
  AlertTriangle = "rbxassetid://112102474509324",
  Misc          = "rbxassetid://92373371786861",
  Atom          = "rbxassetid://119051552929078",
  Ban           = "rbxassetid://109685306480139",
  Battery       = "rbxassetid://102599812606554",
  Bug           = "rbxassetid://75649814233484",
  Eye           = "rbxassetid://127234874352422",
  ArrowUp       = "rbxassetid://104406213770080",
  ArrowDown     = "rbxassetid://134161790366779",
}

-- ──────────────────────────────────────────────
-- HELPERS
-- ──────────────────────────────────────────────
local function make(class, props, parent)
  local inst = Instance.new(class)
  for k, v in pairs(props or {}) do
    inst[k] = v
  end
  if parent then inst.Parent = parent end
  return inst
end

local function mcBorder(frame, light, dark)
  -- pixel-art 2px bevel border via UIStroke + shadow trick
  local stroke = make("UIStroke", {
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    Color = light or Theme.Border,
    Thickness = 2,
  }, frame)
  return stroke
end

local function tween(inst, goal, t)
  TweenService:Create(inst, TweenInfo.new(t or 0.08, Enum.EasingStyle.Linear), goal):Play()
end

-- ──────────────────────────────────────────────
-- NOTIFICATION TOAST
-- ──────────────────────────────────────────────
local function createToast(container)
  local toast = make("Frame", {
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = Color3.fromHex("#1a2a1a"),
    BorderSizePixel = 0,
    Visible = false,
    LayoutOrder = -999,
    ClipsDescendants = true,
  }, container)
  make("UIStroke", {
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    Color = Theme.Green,
    Thickness = 2,
  }, toast)
  local lbl = make("TextLabel", {
    Size = UDim2.new(1, -10, 1, 0),
    Position = UDim2.new(0, 8, 0, 0),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Theme.Green,
    Font = Enum.Font.Code,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
  }, toast)

  local dismissConn
  local function show(msg)
    lbl.Text = msg
    toast.Visible = true
    if dismissConn then dismissConn:Disconnect() end
    dismissConn = task.delay(2.2, function()
      toast.Visible = false
    end)
  end

  return toast, show
end

-- ──────────────────────────────────────────────
-- TOGGLE COMPONENT
-- ──────────────────────────────────────────────
local function createToggle(parent, label, iconId, default, callback)
  local state = default == true

  local row = make("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = Theme.Row,
    BorderSizePixel = 0,
    LayoutOrder = 1,
  }, parent)
  mcBorder(row)
  make("UIPadding", { PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8) }, row)

  -- icon
  if iconId then
    local ic = make("ImageLabel", {
      Size = UDim2.new(0, 18, 0, 18),
      Position = UDim2.new(0, 0, 0.5, -9),
      BackgroundTransparency = 1,
      Image = iconId,
      ScaleType = Enum.ScaleType.Fit,
    }, row)
  end

  local lblFrame = make("TextLabel", {
    Size = UDim2.new(1, -(iconId and 60 or 50), 1, 0),
    Position = UDim2.new(0, iconId and 26 or 0, 0, 0),
    BackgroundTransparency = 1,
    Text = label,
    TextColor3 = Theme.Text,
    Font = Enum.Font.Code,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
  }, row)

  -- toggle pill
  local pill = make("Frame", {
    Size = UDim2.new(0, 42, 0, 20),
    Position = UDim2.new(1, -42, 0.5, -10),
    BackgroundColor3 = state and Theme.GreenDark or Color3.fromHex("#333333"),
    BorderSizePixel = 0,
  }, row)
  mcBorder(pill)

  local thumb = make("Frame", {
    Size = UDim2.new(0, 12, 0, 12),
    Position = state and UDim2.new(0, 26, 0, 2) or UDim2.new(0, 2, 0, 2),
    BackgroundColor3 = state and Theme.Green or Color3.fromHex("#888888"),
    BorderSizePixel = 0,
  }, pill)
  mcBorder(thumb, Color3.fromHex("#333333"))

  local function updateVisual()
    tween(pill, { BackgroundColor3 = state and Theme.GreenDark or Color3.fromHex("#333333") })
    tween(thumb, {
      Position = state and UDim2.new(0, 26, 0, 2) or UDim2.new(0, 2, 0, 2),
      BackgroundColor3 = state and Theme.Green or Color3.fromHex("#888888"),
    })
  end

  local btn = make("TextButton", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "",
    ZIndex = 5,
  }, row)

  btn.MouseButton1Click:Connect(function()
    state = not state
    updateVisual()
    if callback then callback(state) end
  end)

  btn.MouseEnter:Connect(function()
    tween(row, { BackgroundColor3 = Theme.RowHover })
  end)
  btn.MouseLeave:Connect(function()
    tween(row, { BackgroundColor3 = Theme.Row })
  end)

  local api = {}
  function api:Set(val)
    state = val
    updateVisual()
  end
  function api:Get() return state end
  return api
end

-- ──────────────────────────────────────────────
-- SLIDER COMPONENT
-- ──────────────────────────────────────────────
local function createSlider(parent, label, min, max, default, step, callback)
  step = step or 1
  local value = default or min

  local wrap = make("Frame", {
    Size = UDim2.new(1, 0, 0, 52),
    BackgroundColor3 = Theme.Row,
    BorderSizePixel = 0,
    LayoutOrder = 1,
  }, parent)
  mcBorder(wrap)
  make("UIPadding", { PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8), PaddingTop = UDim.new(0,4), PaddingBottom = UDim.new(0,4) }, wrap)

  local header = make("Frame", {
    Size = UDim2.new(1, 0, 0, 22),
    BackgroundTransparency = 1,
  }, wrap)

  make("TextLabel", {
    Size = UDim2.new(0.7, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = label,
    TextColor3 = Theme.Text,
    Font = Enum.Font.Code,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
  }, header)

  local valLbl = make("TextLabel", {
    Size = UDim2.new(0.3, 0, 1, 0),
    Position = UDim2.new(0.7, 0, 0, 0),
    BackgroundTransparency = 1,
    Text = tostring(value),
    TextColor3 = Theme.Green,
    Font = Enum.Font.Code,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Right,
  }, header)

  -- track background
  local track = make("Frame", {
    Size = UDim2.new(1, 0, 0, 10),
    Position = UDim2.new(0, 0, 0, 28),
    BackgroundColor3 = Theme.SliderTrack,
    BorderSizePixel = 0,
  }, wrap)
  mcBorder(track)

  -- fill
  local fill = make("Frame", {
    Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
    BackgroundColor3 = Theme.AccentDark,
    BorderSizePixel = 0,
  }, track)

  -- thumb
  local thumbPos = (value - min) / (max - min)
  local thumbFrame = make("Frame", {
    Size = UDim2.new(0, 16, 0, 16),
    Position = UDim2.new(thumbPos, -8, 0.5, -8),
    BackgroundColor3 = Theme.SliderThumb,
    BorderSizePixel = 0,
    ZIndex = 3,
  }, track)
  mcBorder(thumbFrame, Color3.fromHex("#bbbbbb"), Color3.fromHex("#333333"))

  local dragging = false
  local dragBtn = make("TextButton", {
    Size = UDim2.new(1, 0, 0, 20),
    Position = UDim2.new(0, 0, 0.5, -10),
    BackgroundTransparency = 1,
    Text = "",
    ZIndex = 10,
  }, track)

  local function setFromX(x)
    local abs = track.AbsoluteSize.X
    local rel = math.clamp((x - track.AbsolutePosition.X) / abs, 0, 1)
    local raw = min + (max - min) * rel
    local stepped = math.round(raw / step) * step
    value = math.clamp(stepped, min, max)
    local display = (step < 1) and string.format("%.1f", value) or tostring(math.round(value))
    valLbl.Text = display
    local pct = (value - min) / (max - min)
    fill.Size = UDim2.new(pct, 0, 1, 0)
    thumbFrame.Position = UDim2.new(pct, -8, 0.5, -8)
    if callback then callback(value) end
  end

  dragBtn.MouseButton1Down:Connect(function()
    dragging = true
    tween(thumbFrame, { BackgroundColor3 = Theme.Accent })
  end)

  UserInputService.InputChanged:Connect(function(inp)
    if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
      setFromX(inp.Position.X)
    end
  end)

  UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
      dragging = false
      tween(thumbFrame, { BackgroundColor3 = Theme.SliderThumb })
    end
  end)

  dragBtn.MouseButton1Click:Connect(function()
    setFromX(UserInputService:GetMouseLocation().X)
  end)

  local api = {}
  function api:Set(val)
    value = math.clamp(val, min, max)
    local pct = (value - min) / (max - min)
    fill.Size = UDim2.new(pct, 0, 1, 0)
    thumbFrame.Position = UDim2.new(pct, -8, 0.5, -8)
    valLbl.Text = (step < 1) and string.format("%.1f", value) or tostring(math.round(value))
  end
  function api:Get() return value end
  return api
end

-- ──────────────────────────────────────────────
-- INPUT BOX COMPONENT
-- ──────────────────────────────────────────────
local function createInput(parent, label, placeholder, callback)
  local wrap = make("Frame", {
    Size = UDim2.new(1, 0, 0, 54),
    BackgroundColor3 = Theme.Row,
    BorderSizePixel = 0,
    LayoutOrder = 1,
  }, parent)
  mcBorder(wrap)
  make("UIPadding", { PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8), PaddingTop = UDim.new(0,4), PaddingBottom = UDim.new(0,4) }, wrap)

  make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1,
    Text = label,
    TextColor3 = Theme.Text,
    Font = Enum.Font.Code,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
  }, wrap)

  local box = make("TextBox", {
    Size = UDim2.new(1, 0, 0, 24),
    Position = UDim2.new(0, 0, 0, 22),
    BackgroundColor3 = Theme.InputBG,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = placeholder or "",
    PlaceholderColor3 = Color3.fromHex("#555555"),
    TextColor3 = Theme.Text,
    Font = Enum.Font.Code,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
  }, wrap)
  make("UIPadding", { PaddingLeft = UDim.new(0,6) }, box)
  mcBorder(box, Color3.fromHex("#333333"), Color3.fromHex("#666666"))

  box:GetPropertyChangedSignal("Text"):Connect(function()
    if callback then callback(box.Text) end
  end)

  box.Focused:Connect(function()
    tween(box, { BackgroundColor3 = Color3.fromHex("#1a1a2a") })
  end)
  box.FocusLost:Connect(function()
    tween(box, { BackgroundColor3 = Theme.InputBG })
    if callback then callback(box.Text) end
  end)

  local api = {}
  function api:Get() return box.Text end
  function api:Set(v) box.Text = v end
  return api
end

-- ──────────────────────────────────────────────
-- KEYBIND COMPONENT
-- ──────────────────────────────────────────────
local function createKeybind(parent, label, default, callback)
  local currentKey = default or Enum.KeyCode.Unknown
  local listening = false

  local wrap = make("Frame", {
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = Theme.Row,
    BorderSizePixel = 0,
    LayoutOrder = 1,
  }, parent)
  mcBorder(wrap)
  make("UIPadding", { PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8) }, wrap)

  make("TextLabel", {
    Size = UDim2.new(0.7, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = label,
    TextColor3 = Theme.Text,
    Font = Enum.Font.Code,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
  }, wrap)

  local keyName = currentKey == Enum.KeyCode.Unknown and "NONE" or currentKey.Name:upper():sub(1,4)
  local keyBtn = make("TextButton", {
    Size = UDim2.new(0, 46, 0, 22),
    Position = UDim2.new(1, -46, 0.5, -11),
    BackgroundColor3 = Color3.fromHex("#333333"),
    BorderSizePixel = 0,
    Text = keyName,
    TextColor3 = Theme.Text,
    Font = Enum.Font.Code,
    TextSize = 15,
  }, wrap)
  mcBorder(keyBtn, Color3.fromHex("#666666"), Color3.fromHex("#111111"))

  local blinkConn
  local function stopListen()
    listening = false
    if blinkConn then blinkConn:Disconnect(); blinkConn = nil end
    tween(keyBtn, { BackgroundColor3 = Color3.fromHex("#333333") })
    keyBtn.TextColor3 = Theme.Text
    keyBtn.Text = currentKey == Enum.KeyCode.Unknown and "NONE" or currentKey.Name:upper():sub(1,4)
  end

  keyBtn.MouseButton1Click:Connect(function()
    if listening then
      stopListen()
      return
    end
    listening = true
    keyBtn.Text = "..."
    tween(keyBtn, { BackgroundColor3 = Theme.AccentDark })
    keyBtn.TextColor3 = Theme.Green
    local t = 0
    blinkConn = RunService.Heartbeat:Connect(function(dt)
      t += dt
      keyBtn.TextTransparency = (math.floor(t * 3) % 2 == 0) and 0 or 0.5
    end)
  end)

  UserInputService.InputBegan:Connect(function(inp, gp)
    if not listening then return end
    if inp.UserInputType == Enum.UserInputType.Keyboard then
      currentKey = inp.KeyCode
      stopListen()
      if callback then callback(currentKey) end
    end
  end)

  local api = {}
  function api:Get() return currentKey end
  function api:Set(k) currentKey = k; stopListen() end
  return api
end

-- ──────────────────────────────────────────────
-- SEGMENTED BUTTON COMPONENT
-- ──────────────────────────────────────────────
local function createSegmented(parent, options, defaultIndex, callback)
  local selected = defaultIndex or 1

  local wrap = make("Frame", {
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundTransparency = 1,
    LayoutOrder = 1,
  }, parent)

  local layout = make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 3),
  }, wrap)

  local btns = {}

  local function updateColors()
    for i, btn in ipairs(btns) do
      if i == selected then
        tween(btn, { BackgroundColor3 = Theme.GreenDark })
        btn.TextColor3 = Theme.Green
      else
        tween(btn, { BackgroundColor3 = Color3.fromHex("#333333") })
        btn.TextColor3 = Theme.TextMuted
      end
    end
  end

  local count = #options
  for i, opt in ipairs(options) do
    local btn = make("TextButton", {
      Size = UDim2.new(1/count, -3, 1, 0),
      BackgroundColor3 = i == selected and Theme.GreenDark or Color3.fromHex("#333333"),
      BorderSizePixel = 0,
      Text = opt,
      TextColor3 = i == selected and Theme.Green or Theme.TextMuted,
      Font = Enum.Font.Code,
      TextSize = 15,
      LayoutOrder = i,
    }, wrap)
    mcBorder(btn, i == selected and Theme.Green or Color3.fromHex("#444444"), Color3.fromHex("#111111"))
    btns[i] = btn

    local idx = i
    btn.MouseButton1Click:Connect(function()
      selected = idx
      updateColors()
      if callback then callback(selected, options[selected]) end
    end)

    btn.MouseEnter:Connect(function()
      if selected ~= idx then
        tween(btn, { BackgroundColor3 = Color3.fromHex("#444444") })
        btn.TextColor3 = Theme.Text
      end
    end)
    btn.MouseLeave:Connect(function()
      if selected ~= idx then
        tween(btn, { BackgroundColor3 = Color3.fromHex("#333333") })
        btn.TextColor3 = Theme.TextMuted
      end
    end)
  end

  local api = {}
  function api:Get() return selected, options[selected] end
  function api:Set(idx)
    selected = idx
    updateColors()
  end
  return api
end

-- ──────────────────────────────────────────────
-- BUTTON COMPONENT
-- ──────────────────────────────────────────────
local function createButton(parent, label, variant, callback)
  local bgMap = {
    default = Color3.fromHex("#444444"),
    accent  = Color3.fromHex("#1a3a6a"),
    danger  = Color3.fromHex("#5a1a1a"),
    success = Color3.fromHex("#1a4a1a"),
  }
  local txtMap = {
    default = Theme.Text,
    accent  = Color3.fromHex("#88ccff"),
    danger  = Color3.fromHex("#ff8888"),
    success = Theme.Green,
  }
  local v = variant or "default"

  local btn = make("TextButton", {
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = bgMap[v] or bgMap.default,
    BorderSizePixel = 0,
    Text = label:upper(),
    TextColor3 = txtMap[v] or txtMap.default,
    Font = Enum.Font.Code,
    TextSize = 17,
    LayoutOrder = 1,
  }, parent)
  make("UIPadding", { PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,10) }, btn)
  mcBorder(btn)

  btn.MouseButton1Click:Connect(function()
    if callback then callback() end
  end)

  btn.MouseEnter:Connect(function()
    local c = bgMap[v] or bgMap.default
    tween(btn, { BackgroundColor3 = Color3.new(
      math.min(c.R + 0.06, 1),
      math.min(c.G + 0.06, 1),
      math.min(c.B + 0.06, 1)
    )})
  end)
  btn.MouseLeave:Connect(function()
    tween(btn, { BackgroundColor3 = bgMap[v] or bgMap.default })
  end)

  btn.MouseButton1Down:Connect(function()
    btn.Position = UDim2.new(0, 0, 0, 1)
  end)
  btn.MouseButton1Up:Connect(function()
    btn.Position = UDim2.new(0, 0, 0, 0)
  end)

  return btn
end

-- ──────────────────────────────────────────────
-- COLOR PICKER COMPONENT
-- ──────────────────────────────────────────────
local function createColorPicker(parent, label, default, callback)
  local color = default or Color3.new(1, 1, 1)

  local row = make("Frame", {
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = Theme.Row,
    BorderSizePixel = 0,
    LayoutOrder = 1,
  }, parent)
  mcBorder(row)
  make("UIPadding", { PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8) }, row)

  local swatch = make("Frame", {
    Size = UDim2.new(0, 22, 0, 22),
    Position = UDim2.new(0, 0, 0.5, -11),
    BackgroundColor3 = color,
    BorderSizePixel = 0,
  }, row)
  mcBorder(swatch, Color3.fromHex("#666666"), Color3.fromHex("#111111"))

  make("TextLabel", {
    Size = UDim2.new(0.6, 0, 1, 0),
    Position = UDim2.new(0, 30, 0, 0),
    BackgroundTransparency = 1,
    Text = label,
    TextColor3 = Theme.Text,
    Font = Enum.Font.Code,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
  }, row)

  local hexBox = make("TextBox", {
    Size = UDim2.new(0, 90, 0, 22),
    Position = UDim2.new(1, -90, 0.5, -11),
    BackgroundColor3 = Theme.InputBG,
    BorderSizePixel = 0,
    Text = string.format("#%02X%02X%02X",
      math.round(color.R * 255),
      math.round(color.G * 255),
      math.round(color.B * 255)
    ),
    TextColor3 = Theme.Text,
    Font = Enum.Font.Code,
    TextSize = 15,
    ClearTextOnFocus = false,
  }, row)
  make("UIPadding", { PaddingLeft = UDim.new(0,4) }, hexBox)
  mcBorder(hexBox, Color3.fromHex("#333333"), Color3.fromHex("#666666"))

  hexBox.FocusLost:Connect(function()
    local hex = hexBox.Text:gsub("#", "")
    if #hex == 6 then
      local ok, c = pcall(Color3.fromHex, "#" .. hex)
      if ok then
        color = c
        swatch.BackgroundColor3 = color
        if callback then callback(color) end
      end
    end
  end)

  local api = {}
  function api:Get() return color end
  function api:Set(c)
    color = c
    swatch.BackgroundColor3 = c
    hexBox.Text = string.format("#%02X%02X%02X",
      math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
  end
  return api
end

-- ──────────────────────────────────────────────
-- DIVIDER
-- ──────────────────────────────────────────────
local function createDivider(parent)
  make("Frame", {
    Size = UDim2.new(1, 0, 0, 6),
    BackgroundTransparency = 1,
    LayoutOrder = 1,
  }, parent)
  make("Frame", {
    Size = UDim2.new(1, 0, 0, 2),
    Position = UDim2.new(0, 0, 0, 2),
    BackgroundColor3 = Theme.BorderDark,
    BorderSizePixel = 0,
    LayoutOrder = 1,
  }, parent)
end

-- ──────────────────────────────────────────────
-- SECTION
-- ──────────────────────────────────────────────
local function createSection(windowBody, label)
  if label then
    make("TextLabel", {
      Size = UDim2.new(1, 0, 0, 18),
      BackgroundTransparency = 1,
      Text = label,
      TextColor3 = Theme.TextMuted,
      Font = Enum.Font.Code,
      TextSize = 13,
      TextXAlignment = Enum.TextXAlignment.Left,
      LayoutOrder = 1,
    }, windowBody)
  end

  local container = make("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = 1,
  }, windowBody)

  make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 3),
  }, container)

  local _, notify = createToast(container)

  local section = {}

  function section:Toggle(lbl, icon, default, cb)
    return createToggle(container, lbl, icon, default, cb)
  end

  function section:Slider(lbl, mn, mx, def, stp, cb)
    return createSlider(container, lbl, mn, mx, def, stp, cb)
  end

  function section:Input(lbl, placeholder, cb)
    return createInput(container, lbl, placeholder, cb)
  end

  function section:Keybind(lbl, default, cb)
    return createKeybind(container, lbl, default, cb)
  end

  function section:SegmentedButton(opts, defIdx, cb)
    return createSegmented(container, opts, defIdx, cb)
  end

  function section:Button(lbl, variant, cb)
    return createButton(container, lbl, variant, cb)
  end

  function section:ColorPicker(lbl, default, cb)
    return createColorPicker(container, lbl, default, cb)
  end

  function section:Divider()
    createDivider(container)
  end

  function section:Notify(msg)
    notify(msg)
  end

  return section
end

-- ──────────────────────────────────────────────
-- WINDOW
-- ──────────────────────────────────────────────
local function createWindow(title, iconId)
  local screenGui = make("ScreenGui", {
    Name = "MCUILib_" .. title,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = PlayerGui,
  })

  local win = make("Frame", {
    Size = UDim2.new(0, 300, 0, 0),
    Position = UDim2.new(0.5, -150, 0.5, -200),
    BackgroundColor3 = Theme.Panel,
    BorderSizePixel = 0,
    AutomaticSize = Enum.AutomaticSize.Y,
    Parent = screenGui,
  })
  mcBorder(win, Theme.Border, Theme.BorderDark)
  make("UICorner", { CornerRadius = UDim.new(0, 0) }, win)

  -- titlebar
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

  -- body
  local body = make("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    Position = UDim2.new(0, 0, 0, 32),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
  }, win)
  make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4),
  }, body)
  make("UIPadding", {
    PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
    PaddingTop = UDim.new(0, 8),
    PaddingBottom = UDim.new(0, 8),
  }, body)

  -- dragging
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

  function windowApi:Section(label)
    return createSection(body, label)
  end

  function windowApi:Divider()
    createDivider(body)
  end

  function windowApi:Show()
    screenGui.Enabled = true
  end

  function windowApi:Hide()
    screenGui.Enabled = false
  end

  function windowApi:Toggle()
    screenGui.Enabled = not screenGui.Enabled
  end

  function windowApi:SetTitle(t)
    -- find the title label and update
    for _, v in ipairs(titlebar:GetChildren()) do
      if v:IsA("TextLabel") then v.Text = t:upper() end
    end
  end

  function windowApi:Destroy()
    screenGui:Destroy()
  end

  return windowApi
end

-- ──────────────────────────────────────────────
-- PUBLIC API
-- ──────────────────────────────────────────────
local MCUILib = {}
MCUILib.Icons = Icons
MCUILib.Theme = Theme

function MCUILib.Window(title, iconId)
  return createWindow(title, iconId)
end

-- Standalone component creators (for embedding in custom frames)
MCUILib.Toggle       = createToggle
MCUILib.Slider       = createSlider
MCUILib.Input        = createInput
MCUILib.Keybind      = createKeybind
MCUILib.Segmented    = createSegmented
MCUILib.Button       = createButton
MCUILib.ColorPicker  = createColorPicker

-- Theme editor — call this to swap entire palette at runtime
function MCUILib.SetTheme(overrides)
  for k, v in pairs(overrides) do
    Theme[k] = v
  end
end

return MCUILib
