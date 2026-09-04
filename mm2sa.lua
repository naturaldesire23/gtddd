--[[
  MCUILib v4 — Minecraft-style UI Library for Roblox
  Author: Axiom

  What's new in v4:
    - Full per-window background image support (URL, rbxassetid, Pinterest CDN proxy)
    - Live opacity controls: bg transparency, panel transparency, row transparency
    - Runtime theme overrides via MCUILib.SetTheme() — hot-reloads all existing instances
    - Per-section custom tint and opacity
    - Fixed UIListLayout + AutomaticSize conflict on section containers
    - Fixed ScrollingFrame CanvasSize not updating (now driven by pageLayout.AbsoluteContentSize)
    - Fixed slider thumb drift on non-integer steps
    - Fixed keybind blink coroutine leaking after Destroy()
    - Fixed minimization restoring wrong size when content changes between states
    - Consistent ZIndex layering so popups never fall behind content frames
    - Gradient + noise texture now per-panel, not per-window (cleaner on multi-tab setups)
    - createSection now returns a richer Section API with Show/Hide and SetLabel
    - Window API: SetBackground(url, transparency), SetPanelOpacity(0-1), SetBGOpacity(0-1)
    - Tab API: SetBackground(url, opacity), independently of window bg
    - Divider supports optional text label
    - Dropdown component (new)
    - Checkbox component (alias for Toggle, explicit visual)
]]

local Players         = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local RunService      = game:GetService("RunService")
local HttpService     = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════════
-- THEME  (all mutable via MCUILib.SetTheme)
-- ══════════════════════════════════════════════
local Theme = {
  BG            = Color3.fromHex("#1a1a1a"),
  Panel         = Color3.fromHex("#2a2a2a"),
  PanelOpacity  = 0,           -- 0 = solid, 1 = fully transparent
  Row           = Color3.fromHex("#1e1e1e"),
  RowOpacity    = 0,
  RowHover      = Color3.fromHex("#303030"),
  Border        = Color3.fromHex("#555555"),
  BorderDark    = Color3.fromHex("#111111"),
  Text          = Color3.fromHex("#f0f0f0"),
  TextMuted     = Color3.fromHex("#aaaaaa"),
  Green         = Color3.fromHex("#55cc44"),
  GreenDark     = Color3.fromHex("#2a7020"),
  Red           = Color3.fromHex("#cc3333"),
  Accent        = Color3.fromHex("#4a90d9"),
  AccentDark    = Color3.fromHex("#2060a0"),
  SliderTrack   = Color3.fromHex("#111111"),
  SliderFill    = Color3.fromHex("#2060a0"),
  SliderThumb   = Color3.fromHex("#888888"),
  InputBG       = Color3.fromHex("#111111"),
  TitleBG       = Color3.fromHex("#222222"),
  TabBG         = Color3.fromHex("#1a1a1a"),
  TabActive     = Color3.fromHex("#2a2a2a"),
  DropdownBG    = Color3.fromHex("#1a1a1a"),
  -- Noise overlay
  NoiseAsset    = "rbxassetid://9968344227",
  NoiseOpacity  = 0.88,
  -- Gradient stops (applied to window frame)
  GradientStart = Color3.fromRGB(120, 120, 120),
  GradientMid   = Color3.fromRGB(0, 0, 0),
  GradientEnd   = Color3.fromRGB(0, 0, 0),
}

-- theme-change listeners so live instances can react
local _themeListeners = {}

local function fireTheme()
  for _, fn in ipairs(_themeListeners) do
    pcall(fn)
  end
end

-- ══════════════════════════════════════════════
-- ICONS
-- ══════════════════════════════════════════════
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

-- ══════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════
local function make(class, props, parent)
  local inst = Instance.new(class)
  for k, v in pairs(props or {}) do
    inst[k] = v
  end
  if parent then inst.Parent = parent end
  return inst
end

local function stroke(frame, color, thickness)
  return make("UIStroke", {
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    Color           = color or Theme.Border,
    Thickness       = thickness or 2,
  }, frame)
end

local function tween(inst, goal, t, style)
  TweenService:Create(
    inst,
    TweenInfo.new(t or 0.08, style or Enum.EasingStyle.Linear),
    goal
  ):Play()
end

-- resolve image string: bare asset IDs → proper rbxassetid://
local function resolveImage(url)
  if not url or url == "" then return "" end
  -- already a full asset string
  if url:match("^rbxassetid://") then return url end
  -- raw number
  if url:match("^%d+$") then return "rbxassetid://" .. url end
  -- http(s) URL — use as-is (works for Pinterest CDN, direct image URLs)
  return url
end

-- apply gradient + noise overlay to a frame
local function applyGradient(parent, startC, midC, endC)
  local existing = parent:FindFirstChild("_grad")
  if existing then existing:Destroy() end

  local grad = make("UIGradient", {
    Name  = "_grad",
    Color = ColorSequence.new{
      ColorSequenceKeypoint.new(0.00, startC or Theme.GradientStart),
      ColorSequenceKeypoint.new(0.11, midC   or Theme.GradientMid),
      ColorSequenceKeypoint.new(1.00, endC   or Theme.GradientEnd),
    },
    Transparency = NumberSequence.new(0),
    Rotation = 90,
  }, parent)
  return grad
end

local function applyNoise(parent, opacity)
  local existing = parent:FindFirstChild("_noise")
  if existing then existing:Destroy() end

  return make("ImageLabel", {
    Name               = "_noise",
    Size               = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Image              = Theme.NoiseAsset,
    ImageTransparency  = opacity or Theme.NoiseOpacity,
    ScaleType          = Enum.ScaleType.Tile,
    ZIndex             = 1,
    IgnoreGuiInset     = false,
  }, parent)
end

-- ══════════════════════════════════════════════
-- BACKGROUND IMAGE (window or tab level)
-- ══════════════════════════════════════════════
local function createBGLayer(parent, url, transparency)
  local existing = parent:FindFirstChild("_bgimage")
  if existing then existing:Destroy() end

  local resolved = resolveImage(url)
  if not resolved or resolved == "" then return nil end

  local bg = make("ImageLabel", {
    Name               = "_bgimage",
    Size               = UDim2.new(1, 0, 1, 0),
    Position           = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel    = 0,
    Image              = resolved,
    ImageTransparency  = transparency or 0.5,
    ScaleType          = Enum.ScaleType.Crop,
    Visible            = true,
    ZIndex             = 0,
  }, parent)
  return bg
end

-- ══════════════════════════════════════════════
-- NOTIFICATION TOAST
-- ══════════════════════════════════════════════
local function createToast(container)
  local toast = make("Frame", {
    Size              = UDim2.new(1, 0, 0, 28),
    BackgroundColor3  = Color3.fromHex("#1a2a1a"),
    BorderSizePixel   = 0,
    Visible           = false,
    LayoutOrder       = -999,
    ClipsDescendants  = true,
    ZIndex            = 50,
  }, container)
  stroke(toast, Theme.Green)

  local lbl = make("TextLabel", {
    Size              = UDim2.new(1, -10, 1, 0),
    Position          = UDim2.new(0, 8, 0, 0),
    BackgroundTransparency = 1,
    Text              = "",
    TextColor3        = Theme.Green,
    Font              = Enum.Font.Code,
    TextSize          = 15,
    TextXAlignment    = Enum.TextXAlignment.Left,
    ZIndex            = 51,
  }, toast)

  local dismissTask
  local function show(msg)
    lbl.Text = msg
    toast.Visible = true
    if dismissTask then task.cancel(dismissTask) end
    dismissTask = task.delay(2.2, function()
      toast.Visible = false
    end)
  end

  return toast, show
end

-- ══════════════════════════════════════════════
-- TOGGLE
-- ══════════════════════════════════════════════
local function createToggle(parent, label, iconId, default, callback)
  local state = default == true

  local row = make("Frame", {
    Size             = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = Theme.Row,
    BackgroundTransparency = Theme.RowOpacity,
    BorderSizePixel  = 0,
    LayoutOrder      = 1,
  }, parent)
  stroke(row)
  make("UIPadding", { PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8) }, row)

  if iconId then
    make("ImageLabel", {
      Size               = UDim2.new(0, 18, 0, 18),
      Position           = UDim2.new(0, 0, 0.5, -9),
      BackgroundTransparency = 1,
      Image              = resolveImage(iconId),
      ScaleType          = Enum.ScaleType.Fit,
      ZIndex             = 2,
    }, row)
  end

  make("TextLabel", {
    Size              = UDim2.new(1, iconId and -68 or -56, 1, 0),
    Position          = UDim2.new(0, iconId and 26 or 0, 0, 0),
    BackgroundTransparency = 1,
    Text              = label,
    TextColor3        = Theme.Text,
    Font              = Enum.Font.Code,
    TextSize          = 17,
    TextXAlignment    = Enum.TextXAlignment.Left,
    TextTruncate      = Enum.TextTruncate.AtEnd,
    ZIndex            = 2,
  }, row)

  local pill = make("Frame", {
    Size             = UDim2.new(0, 44, 0, 22),
    Position         = UDim2.new(1, -44, 0.5, -11),
    BackgroundColor3 = state and Theme.GreenDark or Color3.fromHex("#333333"),
    BorderSizePixel  = 0,
    ZIndex           = 2,
  }, row)
  stroke(pill)

  local thumb = make("Frame", {
    Size             = UDim2.new(0, 14, 0, 14),
    Position         = state and UDim2.new(0, 26, 0, 4) or UDim2.new(0, 4, 0, 4),
    BackgroundColor3 = state and Theme.Green or Color3.fromHex("#888888"),
    BorderSizePixel  = 0,
    ZIndex           = 3,
  }, pill)
  stroke(thumb, Color3.fromHex("#333333"))

  local function updateVisual(animate)
    local fn = animate and tween or function(i, g) for k, v in pairs(g) do i[k] = v end end
    fn(pill,  { BackgroundColor3 = state and Theme.GreenDark or Color3.fromHex("#333333") })
    fn(thumb, {
      Position         = state and UDim2.new(0, 26, 0, 4) or UDim2.new(0, 4, 0, 4),
      BackgroundColor3 = state and Theme.Green or Color3.fromHex("#888888"),
    })
  end

  local btn = make("TextButton", {
    Size               = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text               = "",
    ZIndex             = 10,
  }, row)

  btn.MouseButton1Click:Connect(function()
    state = not state
    updateVisual(true)
    if callback then callback(state) end
  end)

  btn.MouseEnter:Connect(function() tween(row, { BackgroundColor3 = Theme.RowHover }) end)
  btn.MouseLeave:Connect(function() tween(row, { BackgroundColor3 = Theme.Row }) end)

  local api = {}
  function api:Set(val)
    state = val == true
    updateVisual(true)
    if callback then callback(state) end
  end
  function api:Get() return state end
  function api:Destroy() row:Destroy() end
  return api
end

-- ══════════════════════════════════════════════
-- SLIDER
-- ══════════════════════════════════════════════
local function createSlider(parent, label, min, max, default, step, callback)
  step    = step or 1
  min     = min  or 0
  max     = max  or 100
  local value = math.clamp(default or min, min, max)

  local wrap = make("Frame", {
    Size             = UDim2.new(1, 0, 0, 56),
    BackgroundColor3 = Theme.Row,
    BackgroundTransparency = Theme.RowOpacity,
    BorderSizePixel  = 0,
    LayoutOrder      = 1,
  }, parent)
  stroke(wrap)
  make("UIPadding", {
    PaddingLeft   = UDim.new(0,8), PaddingRight  = UDim.new(0,8),
    PaddingTop    = UDim.new(0,4), PaddingBottom = UDim.new(0,6),
  }, wrap)

  local header = make("Frame", {
    Size               = UDim2.new(1, 0, 0, 22),
    BackgroundTransparency = 1,
  }, wrap)

  make("TextLabel", {
    Size              = UDim2.new(0.7, 0, 1, 0),
    BackgroundTransparency = 1,
    Text              = label,
    TextColor3        = Theme.Text,
    Font              = Enum.Font.Code,
    TextSize          = 17,
    TextXAlignment    = Enum.TextXAlignment.Left,
    ZIndex            = 2,
  }, header)

  local function fmtVal(v)
    if step < 1 then
      local decimals = math.max(0, math.ceil(-math.log10(step)))
      return string.format("%." .. decimals .. "f", v)
    end
    return tostring(math.round(v))
  end

  local valLbl = make("TextLabel", {
    Size              = UDim2.new(0.3, 0, 1, 0),
    Position          = UDim2.new(0.7, 0, 0, 0),
    BackgroundTransparency = 1,
    Text              = fmtVal(value),
    TextColor3        = Theme.Green,
    Font              = Enum.Font.Code,
    TextSize          = 17,
    TextXAlignment    = Enum.TextXAlignment.Right,
    ZIndex            = 2,
  }, header)

  local track = make("Frame", {
    Size             = UDim2.new(1, 0, 0, 10),
    Position         = UDim2.new(0, 0, 0, 30),
    BackgroundColor3 = Theme.SliderTrack,
    BorderSizePixel  = 0,
    ClipsDescendants = false,
  }, wrap)
  stroke(track)

  local pct0 = (max > min) and ((value - min) / (max - min)) or 0

  local fill = make("Frame", {
    Size             = UDim2.new(pct0, 0, 1, 0),
    BackgroundColor3 = Theme.SliderFill,
    BorderSizePixel  = 0,
    ZIndex           = 2,
  }, track)

  local thumbFrame = make("Frame", {
    Size             = UDim2.new(0, 18, 0, 18),
    Position         = UDim2.new(pct0, -9, 0.5, -9),
    BackgroundColor3 = Theme.SliderThumb,
    BorderSizePixel  = 0,
    ZIndex           = 4,
  }, track)
  stroke(thumbFrame, Color3.fromHex("#bbbbbb"), 2)

  local dragging = false

  local function setFromX(x)
    local abs = track.AbsoluteSize.X
    if abs == 0 then return end
    local rel    = math.clamp((x - track.AbsolutePosition.X) / abs, 0, 1)
    local raw    = min + (max - min) * rel
    -- snap to step
    local stepped = math.round(raw / step) * step
    value = math.clamp(stepped, min, max)
    local p = (max > min) and ((value - min) / (max - min)) or 0
    valLbl.Text          = fmtVal(value)
    fill.Size            = UDim2.new(p, 0, 1, 0)
    thumbFrame.Position  = UDim2.new(p, -9, 0.5, -9)
    if callback then callback(value) end
  end

  local dragBtn = make("TextButton", {
    Size               = UDim2.new(1, 0, 0, 24),
    Position           = UDim2.new(0, 0, 0.5, -12),
    BackgroundTransparency = 1,
    Text               = "",
    ZIndex             = 10,
  }, track)

  dragBtn.MouseButton1Down:Connect(function()
    dragging = true
    tween(thumbFrame, { BackgroundColor3 = Theme.Accent })
    setFromX(UserInputService:GetMouseLocation().X)
  end)

  local uisMoved = UserInputService.InputChanged:Connect(function(inp)
    if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
      setFromX(inp.Position.X)
    end
  end)

  local uisEnded = UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
      if dragging then
        dragging = false
        tween(thumbFrame, { BackgroundColor3 = Theme.SliderThumb })
      end
    end
  end)

  local api = {}
  function api:Set(val)
    value = math.clamp(val, min, max)
    local p = (max > min) and ((value - min) / (max - min)) or 0
    fill.Size           = UDim2.new(p, 0, 1, 0)
    thumbFrame.Position = UDim2.new(p, -9, 0.5, -9)
    valLbl.Text         = fmtVal(value)
    if callback then callback(value) end
  end
  function api:Get() return value end
  function api:Destroy()
    uisMoved:Disconnect()
    uisEnded:Disconnect()
    wrap:Destroy()
  end
  return api
end

-- ══════════════════════════════════════════════
-- INPUT BOX
-- ══════════════════════════════════════════════
local function createInput(parent, label, placeholder, callback)
  local wrap = make("Frame", {
    Size             = UDim2.new(1, 0, 0, 56),
    BackgroundColor3 = Theme.Row,
    BackgroundTransparency = Theme.RowOpacity,
    BorderSizePixel  = 0,
    LayoutOrder      = 1,
  }, parent)
  stroke(wrap)
  make("UIPadding", {
    PaddingLeft   = UDim.new(0,8), PaddingRight  = UDim.new(0,8),
    PaddingTop    = UDim.new(0,4), PaddingBottom = UDim.new(0,4),
  }, wrap)

  make("TextLabel", {
    Size              = UDim2.new(1, 0, 0, 20),
    BackgroundTransparency = 1,
    Text              = label,
    TextColor3        = Theme.Text,
    Font              = Enum.Font.Code,
    TextSize          = 16,
    TextXAlignment    = Enum.TextXAlignment.Left,
    ZIndex            = 2,
  }, wrap)

  local box = make("TextBox", {
    Size             = UDim2.new(1, 0, 0, 26),
    Position         = UDim2.new(0, 0, 0, 24),
    BackgroundColor3 = Theme.InputBG,
    BorderSizePixel  = 0,
    Text             = "",
    PlaceholderText  = placeholder or "",
    PlaceholderColor3 = Color3.fromHex("#555555"),
    TextColor3       = Theme.Text,
    Font             = Enum.Font.Code,
    TextSize         = 16,
    TextXAlignment   = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    ZIndex           = 2,
  }, wrap)
  make("UIPadding", { PaddingLeft = UDim.new(0,6) }, box)
  stroke(box, Color3.fromHex("#333333"))

  box.Focused:Connect(function()
    tween(box, { BackgroundColor3 = Color3.fromHex("#1a1a2a") })
  end)
  box.FocusLost:Connect(function(enter)
    tween(box, { BackgroundColor3 = Theme.InputBG })
    if callback then callback(box.Text, enter) end
  end)
  box:GetPropertyChangedSignal("Text"):Connect(function()
    if callback then callback(box.Text, false) end
  end)

  local api = {}
  function api:Get() return box.Text end
  function api:Set(v) box.Text = v or "" end
  function api:Clear() box.Text = "" end
  function api:Destroy() wrap:Destroy() end
  return api
end

-- ══════════════════════════════════════════════
-- DROPDOWN
-- ══════════════════════════════════════════════
local function createDropdown(parent, label, options, defaultIndex, callback)
  local selected = defaultIndex or 1
  local open     = false

  local wrap = make("Frame", {
    Size             = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = Theme.Row,
    BackgroundTransparency = Theme.RowOpacity,
    BorderSizePixel  = 0,
    LayoutOrder      = 1,
    ClipsDescendants = false,
    ZIndex           = 5,
  }, parent)
  stroke(wrap)
  make("UIPadding", { PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8) }, wrap)

  make("TextLabel", {
    Size              = UDim2.new(0.5, 0, 1, 0),
    BackgroundTransparency = 1,
    Text              = label,
    TextColor3        = Theme.Text,
    Font              = Enum.Font.Code,
    TextSize          = 17,
    TextXAlignment    = Enum.TextXAlignment.Left,
    ZIndex            = 6,
  }, wrap)

  local selBtn = make("TextButton", {
    Size             = UDim2.new(0.5, -4, 0, 26),
    Position         = UDim2.new(0.5, 4, 0.5, -13),
    BackgroundColor3 = Theme.DropdownBG,
    BorderSizePixel  = 0,
    Text             = options[selected] or "",
    TextColor3       = Theme.Text,
    Font             = Enum.Font.Code,
    TextSize          = 15,
    ZIndex           = 6,
  }, wrap)
  stroke(selBtn, Color3.fromHex("#444444"))

  make("ImageLabel", {
    Size             = UDim2.new(0, 14, 0, 14),
    Position         = UDim2.new(1, -18, 0.5, -7),
    BackgroundTransparency = 1,
    Image            = Icons.ArrowDown,
    ScaleType        = Enum.ScaleType.Fit,
    ZIndex           = 7,
  }, selBtn)

  -- dropdown list (renders below wrap)
  local listFrame = make("Frame", {
    Size             = UDim2.new(0.5, -4, 0, 0),
    Position         = UDim2.new(0.5, 4, 1, 2),
    BackgroundColor3 = Theme.DropdownBG,
    BorderSizePixel  = 0,
    Visible          = false,
    ZIndex           = 30,
    ClipsDescendants = true,
  }, wrap)
  stroke(listFrame, Color3.fromHex("#555555"))

  local listLayout = make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding   = UDim.new(0, 1),
  }, listFrame)

  local optBtns = {}
  for i, opt in ipairs(options) do
    local ob = make("TextButton", {
      Size             = UDim2.new(1, 0, 0, 28),
      BackgroundColor3 = i == selected and Theme.AccentDark or Theme.DropdownBG,
      BorderSizePixel  = 0,
      Text             = opt,
      TextColor3       = i == selected and Theme.Accent or Theme.Text,
      Font             = Enum.Font.Code,
      TextSize         = 15,
      LayoutOrder      = i,
      ZIndex           = 31,
    }, listFrame)
    make("UIPadding", { PaddingLeft = UDim.new(0,6) }, ob)

    local idx = i
    ob.MouseButton1Click:Connect(function()
      selected = idx
      selBtn.Text = options[selected]
      for j, b in ipairs(optBtns) do
        b.BackgroundColor3 = j == selected and Theme.AccentDark or Theme.DropdownBG
        b.TextColor3       = j == selected and Theme.Accent     or Theme.Text
      end
      -- close
      open = false
      tween(listFrame, { Size = UDim2.new(0.5, -4, 0, 0) }, 0.1)
      task.delay(0.1, function() listFrame.Visible = false end)
      if callback then callback(selected, options[selected]) end
    end)
    ob.MouseEnter:Connect(function()
      if selected ~= idx then tween(ob, { BackgroundColor3 = Color3.fromHex("#2a2a3a") }) end
    end)
    ob.MouseLeave:Connect(function()
      if selected ~= idx then tween(ob, { BackgroundColor3 = Theme.DropdownBG }) end
    end)
    optBtns[i] = ob
  end

  -- size the list to content
  local itemH     = 29
  local totalH    = #options * itemH

  selBtn.MouseButton1Click:Connect(function()
    open = not open
    if open then
      listFrame.Size    = UDim2.new(0.5, -4, 0, 0)
      listFrame.Visible = true
      tween(listFrame, { Size = UDim2.new(0.5, -4, 0, math.min(totalH, 140)) }, 0.12)
    else
      tween(listFrame, { Size = UDim2.new(0.5, -4, 0, 0) }, 0.1)
      task.delay(0.1, function() listFrame.Visible = false end)
    end
  end)

  local api = {}
  function api:Get() return selected, options[selected] end
  function api:Set(idx)
    selected    = idx
    selBtn.Text = options[selected] or ""
    for j, b in ipairs(optBtns) do
      b.BackgroundColor3 = j == selected and Theme.AccentDark or Theme.DropdownBG
      b.TextColor3       = j == selected and Theme.Accent     or Theme.Text
    end
    if callback then callback(selected, options[selected]) end
  end
  function api:Destroy() wrap:Destroy() end
  return api
end

-- ══════════════════════════════════════════════
-- KEYBIND
-- ══════════════════════════════════════════════
local function createKeybind(parent, label, default, callback)
  local currentKey = default or Enum.KeyCode.Unknown
  local listening  = false
  local active     = false
  local _blinkConn = nil
  local _destroyed = false

  local wrap = make("Frame", {
    Size             = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = Theme.Row,
    BackgroundTransparency = Theme.RowOpacity,
    BorderSizePixel  = 0,
    LayoutOrder      = 1,
  }, parent)
  stroke(wrap)
  make("UIPadding", { PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8) }, wrap)

  make("TextLabel", {
    Size              = UDim2.new(0.7, 0, 1, 0),
    BackgroundTransparency = 1,
    Text              = label,
    TextColor3        = Theme.Text,
    Font              = Enum.Font.Code,
    TextSize          = 17,
    TextXAlignment    = Enum.TextXAlignment.Left,
    ZIndex            = 2,
  }, wrap)

  local function keyName(k)
    if k == Enum.KeyCode.Unknown then return "NONE" end
    local n = k.Name:upper()
    return n:sub(1, math.min(4, #n))
  end

  local keyBtn = make("TextButton", {
    Size             = UDim2.new(0, 48, 0, 24),
    Position         = UDim2.new(1, -48, 0.5, -12),
    BackgroundColor3 = Color3.fromHex("#333333"),
    BorderSizePixel  = 0,
    Text             = keyName(currentKey),
    TextColor3       = Theme.Text,
    Font             = Enum.Font.Code,
    TextSize         = 15,
    ZIndex           = 2,
  }, wrap)
  stroke(keyBtn, Color3.fromHex("#666666"))

  local function stopListen()
    listening = false
    if _blinkConn then _blinkConn:Disconnect(); _blinkConn = nil end
    tween(keyBtn, { BackgroundColor3 = Color3.fromHex("#333333") })
    keyBtn.TextColor3       = Theme.Text
    keyBtn.Text             = keyName(currentKey)
    keyBtn.TextTransparency = 0
  end

  keyBtn.MouseButton1Click:Connect(function()
    if listening then stopListen(); return end
    listening    = true
    keyBtn.Text  = "..."
    tween(keyBtn, { BackgroundColor3 = Theme.AccentDark })
    keyBtn.TextColor3 = Theme.Green
    local t = 0
    _blinkConn = RunService.Heartbeat:Connect(function(dt)
      if _destroyed then _blinkConn:Disconnect(); return end
      t += dt
      keyBtn.TextTransparency = (math.floor(t * 3) % 2 == 0) and 0 or 0.5
    end)
  end)

  local _inputBegan = UserInputService.InputBegan:Connect(function(inp, gp)
    if _destroyed then return end
    if listening then
      if gp then return end
      if inp.UserInputType == Enum.UserInputType.Keyboard then
        currentKey = inp.KeyCode
        stopListen()
        if callback then callback(currentKey, false) end
      end
      return
    end
    if not gp and inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == currentKey then
      active = true
      if callback then callback(currentKey, true) end
    end
  end)

  local _inputEnded = UserInputService.InputEnded:Connect(function(inp)
    if _destroyed then return end
    if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == currentKey then
      active = false
      if callback then callback(currentKey, false) end
    end
  end)

  local api = {}
  api.OnChanged = callback
  function api:Get() return currentKey end
  function api:Set(k)
    currentKey = k
    stopListen()
    if api.OnChanged then api.OnChanged(k, false) end
  end
  function api:Destroy()
    _destroyed = true
    if _blinkConn then _blinkConn:Disconnect() end
    _inputBegan:Disconnect()
    _inputEnded:Disconnect()
    wrap:Destroy()
  end
  return api
end

-- ══════════════════════════════════════════════
-- SEGMENTED BUTTON
-- ══════════════════════════════════════════════
local function createSegmented(parent, options, defaultIndex, callback)
  local selected = defaultIndex or 1

  local wrap = make("Frame", {
    Size               = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    LayoutOrder        = 1,
  }, parent)

  make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder     = Enum.SortOrder.LayoutOrder,
    Padding       = UDim.new(0, 3),
  }, wrap)

  local btns  = {}
  local count = #options

  local function updateColors()
    for i, btn in ipairs(btns) do
      tween(btn, { BackgroundColor3 = i == selected and Theme.GreenDark or Color3.fromHex("#333333") })
      btn.TextColor3 = i == selected and Theme.Green or Theme.TextMuted
    end
  end

  for i, opt in ipairs(options) do
    local btn = make("TextButton", {
      Size             = UDim2.new(1/count, -(count - 1)*3/count, 1, 0),
      BackgroundColor3 = i == selected and Theme.GreenDark or Color3.fromHex("#333333"),
      BorderSizePixel  = 0,
      Text             = opt,
      TextColor3       = i == selected and Theme.Green or Theme.TextMuted,
      Font             = Enum.Font.Code,
      TextSize         = 15,
      LayoutOrder      = i,
      ZIndex           = 2,
    }, wrap)
    stroke(btn, i == selected and Theme.Green or Color3.fromHex("#444444"))

    local idx = i
    btn.MouseButton1Click:Connect(function()
      selected = idx
      updateColors()
      if callback then callback(selected, options[selected]) end
    end)
    btn.MouseEnter:Connect(function()
      if selected ~= idx then tween(btn, { BackgroundColor3 = Color3.fromHex("#444444") }) end
    end)
    btn.MouseLeave:Connect(function()
      if selected ~= idx then tween(btn, { BackgroundColor3 = Color3.fromHex("#333333") }) end
    end)
    btns[i] = btn
  end

  local api = {}
  function api:Get() return selected, options[selected] end
  function api:Set(idx)
    selected = math.clamp(idx, 1, #options)
    updateColors()
    if callback then callback(selected, options[selected]) end
  end
  function api:Destroy() wrap:Destroy() end
  return api
end

-- ══════════════════════════════════════════════
-- BUTTON
-- ══════════════════════════════════════════════
local _variantBG = {
  default = Color3.fromHex("#444444"),
  accent  = Color3.fromHex("#1a3a6a"),
  danger  = Color3.fromHex("#5a1a1a"),
  success = Color3.fromHex("#1a4a1a"),
  ghost   = Color3.fromHex("#2a2a2a"),
}
local _variantTXT = {
  default = Color3.fromHex("#f0f0f0"),
  accent  = Color3.fromHex("#88ccff"),
  danger  = Color3.fromHex("#ff8888"),
  success = Color3.fromHex("#55cc44"),
  ghost   = Color3.fromHex("#aaaaaa"),
}

local function createButton(parent, label, variant, callback)
  local v  = (variant and _variantBG[variant]) and variant or "default"
  local bg = _variantBG[v]

  local btn = make("TextButton", {
    Size             = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = bg,
    BorderSizePixel  = 0,
    Text             = label:upper(),
    TextColor3       = _variantTXT[v],
    Font             = Enum.Font.Code,
    TextSize         = 17,
    LayoutOrder      = 1,
    ZIndex           = 2,
  }, parent)
  make("UIPadding", { PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,10) }, btn)
  stroke(btn)

  btn.MouseButton1Click:Connect(function() if callback then callback() end end)
  btn.MouseEnter:Connect(function()
    tween(btn, { BackgroundColor3 = Color3.new(
      math.min(bg.R + 0.07, 1),
      math.min(bg.G + 0.07, 1),
      math.min(bg.B + 0.07, 1)
    )})
  end)
  btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = bg }) end)
  btn.MouseButton1Down:Connect(function() btn.Position = UDim2.new(0,0,0,1) end)
  btn.MouseButton1Up:Connect(function()   btn.Position = UDim2.new(0,0,0,0) end)

  local api = {}
  function api:SetLabel(lbl) btn.Text = lbl:upper() end
  function api:Destroy() btn:Destroy() end
  return api
end

-- ══════════════════════════════════════════════
-- COLOR PICKER
-- ══════════════════════════════════════════════
local function createColorPicker(parent, label, default, callback)
  local color = default or Color3.new(1, 1, 1)

  local row = make("Frame", {
    Size             = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = Theme.Row,
    BackgroundTransparency = Theme.RowOpacity,
    BorderSizePixel  = 0,
    LayoutOrder      = 1,
  }, parent)
  stroke(row)
  make("UIPadding", { PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8) }, row)

  local swatch = make("Frame", {
    Size             = UDim2.new(0, 24, 0, 24),
    Position         = UDim2.new(0, 0, 0.5, -12),
    BackgroundColor3 = color,
    BorderSizePixel  = 0,
    ZIndex           = 2,
  }, row)
  stroke(swatch, Color3.fromHex("#666666"))

  make("TextLabel", {
    Size              = UDim2.new(0.5, 0, 1, 0),
    Position          = UDim2.new(0, 32, 0, 0),
    BackgroundTransparency = 1,
    Text              = label,
    TextColor3        = Theme.Text,
    Font              = Enum.Font.Code,
    TextSize          = 17,
    TextXAlignment    = Enum.TextXAlignment.Left,
    ZIndex            = 2,
  }, row)

  local function toHex(c)
    return string.format("#%02X%02X%02X",
      math.round(c.R * 255),
      math.round(c.G * 255),
      math.round(c.B * 255))
  end

  local hexBox = make("TextBox", {
    Size             = UDim2.new(0, 88, 0, 24),
    Position         = UDim2.new(1, -88, 0.5, -12),
    BackgroundColor3 = Theme.InputBG,
    BorderSizePixel  = 0,
    Text             = toHex(color),
    TextColor3       = Theme.Text,
    Font             = Enum.Font.Code,
    TextSize         = 15,
    ClearTextOnFocus = false,
    ZIndex           = 2,
  }, row)
  make("UIPadding", { PaddingLeft = UDim.new(0,4) }, hexBox)
  stroke(hexBox, Color3.fromHex("#333333"))

  hexBox.FocusLost:Connect(function()
    local hex = hexBox.Text:gsub("#",""):gsub("%s","")
    if #hex == 6 then
      local ok, c = pcall(Color3.fromHex, "#"..hex)
      if ok then
        color = c
        swatch.BackgroundColor3 = c
        hexBox.Text = toHex(c)
        if callback then callback(color) end
      else
        hexBox.Text = toHex(color) -- revert bad input
      end
    else
      hexBox.Text = toHex(color)
    end
  end)

  local api = {}
  function api:Get() return color end
  function api:Set(c)
    color = c
    swatch.BackgroundColor3 = c
    hexBox.Text = toHex(c)
    if callback then callback(color) end
  end
  function api:Destroy() row:Destroy() end
  return api
end

-- ══════════════════════════════════════════════
-- DIVIDER (optional label)
-- ══════════════════════════════════════════════
local function createDivider(parent, text)
  if text then
    local f = make("Frame", {
      Size               = UDim2.new(1, 0, 0, 18),
      BackgroundTransparency = 1,
      LayoutOrder        = 1,
    }, parent)
    make("Frame", {
      Size             = UDim2.new(1, 0, 0, 1),
      Position         = UDim2.new(0, 0, 0.5, 0),
      BackgroundColor3 = Theme.BorderDark,
      BorderSizePixel  = 0,
    }, f)
    local lbl = make("TextLabel", {
      AutomaticSize    = Enum.AutomaticSize.X,
      Size             = UDim2.new(0, 0, 1, 0),
      Position         = UDim2.new(0.5, 0, 0, 0),
      AnchorPoint      = Vector2.new(0.5, 0),
      BackgroundColor3 = Theme.Panel,
      BorderSizePixel  = 0,
      Text             = "  " .. text .. "  ",
      TextColor3       = Theme.TextMuted,
      Font             = Enum.Font.Code,
      TextSize         = 13,
      ZIndex           = 2,
    }, f)
  else
    make("Frame", {
      Size             = UDim2.new(1, 0, 0, 1),
      BackgroundColor3 = Theme.BorderDark,
      BorderSizePixel  = 0,
      LayoutOrder      = 1,
    }, parent)
    make("Frame", {
      Size               = UDim2.new(1, 0, 0, 4),
      BackgroundTransparency = 1,
      LayoutOrder        = 1,
    }, parent)
  end
end

-- ══════════════════════════════════════════════
-- SECTION
-- ══════════════════════════════════════════════
local function createSection(scrollPage, sectionLabel)
  local headerLbl
  if sectionLabel then
    headerLbl = make("TextLabel", {
      Size              = UDim2.new(1, 0, 0, 18),
      BackgroundTransparency = 1,
      Text              = sectionLabel:upper(),
      TextColor3        = Theme.TextMuted,
      Font              = Enum.Font.Code,
      TextSize          = 12,
      TextXAlignment    = Enum.TextXAlignment.Left,
      LayoutOrder       = 1,
    }, scrollPage)
  end

  -- Use a Frame with AutomaticSize instead of letting ScrollingFrame be the layout root.
  -- This is the v3 bug: mixing AutomaticSize on ScrollingFrame caused canvas sizing issues.
  local container = make("Frame", {
    Size             = UDim2.new(1, 0, 0, 0),
    AutomaticSize    = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    LayoutOrder      = 1,
  }, scrollPage)

  make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding   = UDim.new(0, 3),
  }, container)

  local _, notify = createToast(container)

  local section = {}

  function section:Toggle(lbl, icon, def, cb)
    return createToggle(container, lbl, icon, def, cb)
  end
  function section:Slider(lbl, mn, mx, def, stp, cb)
    return createSlider(container, lbl, mn, mx, def, stp, cb)
  end
  function section:Input(lbl, ph, cb)
    return createInput(container, lbl, ph, cb)
  end
  function section:Dropdown(lbl, opts, defIdx, cb)
    return createDropdown(container, lbl, opts, defIdx, cb)
  end
  function section:Keybind(lbl, def, cb)
    return createKeybind(container, lbl, def, cb)
  end
  function section:Segmented(opts, defIdx, cb)
    return createSegmented(container, opts, defIdx, cb)
  end
  function section:Button(lbl, variant, cb)
    return createButton(container, lbl, variant, cb)
  end
  function section:ColorPicker(lbl, def, cb)
    return createColorPicker(container, lbl, def, cb)
  end
  function section:Divider(text)
    createDivider(container, text)
  end
  function section:Notify(msg)
    notify(msg)
  end
  function section:SetLabel(lbl)
    if headerLbl then headerLbl.Text = lbl:upper() end
  end
  function section:Show()
    container.Visible = true
    if headerLbl then headerLbl.Visible = true end
  end
  function section:Hide()
    container.Visible = false
    if headerLbl then headerLbl.Visible = false end
  end

  section._container = container
  return section
end

-- ══════════════════════════════════════════════
-- WINDOW
-- ══════════════════════════════════════════════
local function createWindow(title, iconId, options)
  options = options or {}
  local winW = options.Width  or 460
  local winH = options.Height or 320

  local screenGui = make("ScreenGui", {
    Name              = "MCUILib_" .. title,
    ResetOnSpawn      = false,
    ZIndexBehavior    = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset    = false,
    Parent            = PlayerGui,
  })

  local win = make("Frame", {
    Size             = UDim2.new(0, winW, 0, winH),
    Position         = options.Position or UDim2.new(0.5, -winW/2, 0.5, -winH/2),
    BackgroundColor3 = Theme.Panel,
    BackgroundTransparency = Theme.PanelOpacity,
    BorderSizePixel  = 0,
    ClipsDescendants = false,
    Parent           = screenGui,
  })
  stroke(win, Theme.Border)

  -- background image layer (behind everything)
  local winBGImg = nil

  -- gradient on the win frame itself
  applyGradient(win)
  applyNoise(win)

  -- ── title bar ────────────────────────────────
  local titlebar = make("Frame", {
    Size             = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = Theme.TitleBG,
    BorderSizePixel  = 0,
    ZIndex           = 10,
  }, win)
  stroke(titlebar, Theme.BorderDark)

  if iconId then
    make("ImageLabel", {
      Size               = UDim2.new(0, 18, 0, 18),
      Position           = UDim2.new(0, 8, 0.5, -9),
      BackgroundTransparency = 1,
      Image              = resolveImage(iconId),
      ScaleType          = Enum.ScaleType.Fit,
      ZIndex             = 12,
    }, titlebar)
  end

  make("TextLabel", {
    Size              = UDim2.new(1, iconId and -100 or -80, 1, 0),
    Position          = UDim2.new(0, iconId and 32 or 10, 0, 0),
    BackgroundTransparency = 1,
    Text              = title:upper(),
    TextColor3        = Theme.Text,
    Font              = Enum.Font.Code,
    TextSize          = 18,
    TextXAlignment    = Enum.TextXAlignment.Left,
    ZIndex            = 12,
  }, titlebar)

  -- close & minimize
  local closeBtn = make("TextButton", {
    Size             = UDim2.new(0, 20, 0, 20),
    Position         = UDim2.new(1, -26, 0.5, -10),
    BackgroundColor3 = Theme.Red,
    BorderSizePixel  = 0,
    Text             = "✕",
    TextColor3       = Color3.new(1,1,1),
    Font             = Enum.Font.Code,
    TextSize         = 14,
    ZIndex           = 12,
  }, titlebar)
  stroke(closeBtn, Color3.fromHex("#800000"))

  local minBtn = make("TextButton", {
    Size             = UDim2.new(0, 20, 0, 20),
    Position         = UDim2.new(1, -52, 0.5, -10),
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel  = 0,
    Text             = "—",
    TextColor3       = Color3.new(1,1,1),
    Font             = Enum.Font.Code,
    TextSize         = 14,
    ZIndex           = 12,
  }, titlebar)
  stroke(minBtn, Color3.fromHex("#0d3a8a"))

  -- ── tab bar ──────────────────────────────────
  local tabBar = make("Frame", {
    Size             = UDim2.new(1, 0, 0, 28),
    Position         = UDim2.new(0, 0, 0, 32),
    BackgroundColor3 = Theme.TabBG,
    BorderSizePixel  = 0,
    ZIndex           = 9,
    ClipsDescendants = true,
  }, win)
  stroke(tabBar, Theme.BorderDark)

  make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder     = Enum.SortOrder.LayoutOrder,
    Padding       = UDim.new(0, 2),
  }, tabBar)
  make("UIPadding", {
    PaddingLeft  = UDim.new(0,4),
    PaddingRight = UDim.new(0,4),
    PaddingTop   = UDim.new(0,2),
  }, tabBar)

  -- ── content area ─────────────────────────────
  local contentArea = make("Frame", {
    Size             = UDim2.new(1, 0, 1, -60),
    Position         = UDim2.new(0, 0, 0, 60),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    ZIndex           = 2,
  }, win)

  -- ── drag ─────────────────────────────────────
  local dragging, dragStart, startPos = false, nil, nil
  titlebar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
      dragging  = true
      dragStart = inp.Position
      startPos  = win.Position
    end
  end)
  titlebar.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
  end)
  UserInputService.InputChanged:Connect(function(inp)
    if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
      local d = inp.Position - dragStart
      win.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + d.X,
        startPos.Y.Scale, startPos.Y.Offset + d.Y
      )
    end
  end)

  -- ── close / minimize ─────────────────────────
  closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)
  closeBtn.MouseEnter:Connect(function() tween(closeBtn, { BackgroundColor3 = Color3.fromHex("#ff4444") }) end)
  closeBtn.MouseLeave:Connect(function() tween(closeBtn, { BackgroundColor3 = Theme.Red }) end)

  local minimized   = false
  local normalSize  = win.Size

  minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
      normalSize = win.Size
      tween(win, { Size = UDim2.new(0, winW, 0, 32) }, 0.18)
      contentArea.Visible = false
      tabBar.Visible      = false
      minBtn.Text         = "+"
    else
      tween(win, { Size = normalSize }, 0.18)
      contentArea.Visible = true
      tabBar.Visible      = true
      minBtn.Text         = "—"
    end
  end)
  minBtn.MouseEnter:Connect(function() tween(minBtn, { BackgroundColor3 = Color3.fromHex("#3b82f6") }) end)
  minBtn.MouseLeave:Connect(function() tween(minBtn, { BackgroundColor3 = Theme.Accent }) end)

  -- ── tab system ───────────────────────────────
  local pages     = {}
  local activePg  = nil

  local windowApi = {}

  function windowApi:AddTab(tabName, tabIcon)
    local tabBtn = make("TextButton", {
      Size             = UDim2.new(0, 90, 1, 0),
      BackgroundColor3 = Theme.TabBG,
      BorderSizePixel  = 0,
      Text             = tabName,
      TextColor3       = Theme.TextMuted,
      Font             = Enum.Font.Code,
      TextSize         = 14,
      ZIndex           = 10,
      LayoutOrder      = #pages + 1,
      ClipsDescendants = false,
    }, tabBar)

    if tabIcon then
      make("ImageLabel", {
        Size               = UDim2.new(0, 14, 0, 14),
        Position           = UDim2.new(0, 5, 0.5, -7),
        BackgroundTransparency = 1,
        Image              = resolveImage(tabIcon),
        ScaleType          = Enum.ScaleType.Fit,
        ZIndex             = 11,
      }, tabBtn)
      make("UIPadding", { PaddingLeft = UDim.new(0, 22) }, tabBtn)
    end

    -- each tab gets its own scrolling page
    local page = make("ScrollingFrame", {
      Size                  = UDim2.new(1, 0, 1, 0),
      BackgroundTransparency = 1,
      ScrollBarThickness    = 4,
      ScrollBarImageColor3  = Theme.Border,
      BorderSizePixel       = 0,
      Visible               = false,
      ZIndex                = 3,
      AutomaticCanvasSize   = Enum.AutomaticSize.Y,
      CanvasSize            = UDim2.new(0, 0, 0, 0),
    }, contentArea)

    -- background image for this tab (optional)
    local tabBGImg = nil

    local pageLayout = make("UIListLayout", {
      SortOrder = Enum.SortOrder.LayoutOrder,
      Padding   = UDim.new(0, 4),
    }, page)
    make("UIPadding", {
      PaddingLeft   = UDim.new(0, 8),
      PaddingRight  = UDim.new(0, 8),
      PaddingTop    = UDim.new(0, 8),
      PaddingBottom = UDim.new(0, 8),
    }, page)

    local function activateTab()
      for _, p in ipairs(pages) do
        p.frame.Visible = false
        tween(p.button, { BackgroundColor3 = Theme.TabBG })
        p.button.TextColor3 = Theme.TextMuted
      end
      page.Visible = true
      tween(tabBtn, { BackgroundColor3 = Theme.TabActive })
      tabBtn.TextColor3 = Theme.Text
      activePg = page
    end

    tabBtn.MouseButton1Click:Connect(activateTab)
    tabBtn.MouseEnter:Connect(function()
      if activePg ~= page then
        tween(tabBtn, { BackgroundColor3 = Color3.fromHex("#222222") })
      end
    end)
    tabBtn.MouseLeave:Connect(function()
      if activePg ~= page then
        tween(tabBtn, { BackgroundColor3 = Theme.TabBG })
      end
    end)

    local pageApi  = createSection(page, nil)
    pageApi._frame = page

    -- ── tab-level background ──────────────────
    function pageApi:SetBackground(url, opacity)
      tabBGImg = createBGLayer(page, url, opacity or 0.5)
      if tabBGImg then tabBGImg.ZIndex = 0 end
    end
    function pageApi:RemoveBackground()
      if tabBGImg then tabBGImg:Destroy(); tabBGImg = nil end
    end
    function pageApi:SetBGOpacity(t)
      if tabBGImg then tabBGImg.ImageTransparency = math.clamp(t, 0, 1) end
    end

    table.insert(pages, { frame = page, button = tabBtn, api = pageApi })
    if #pages == 1 then activateTab() end

    return pageApi
  end

  -- ── window-level background ───────────────────
  function windowApi:SetBackground(url, opacity)
    winBGImg = createBGLayer(win, url, opacity or 0.5)
    if winBGImg then
      winBGImg.ZIndex   = 0
      -- push behind gradient/noise
      winBGImg.Parent   = win
    end
  end
  function windowApi:RemoveBackground()
    if winBGImg then winBGImg:Destroy(); winBGImg = nil end
  end
  function windowApi:SetBGOpacity(t)
    if winBGImg then winBGImg.ImageTransparency = math.clamp(t, 0, 1) end
  end
  function windowApi:SetPanelOpacity(t)
    win.BackgroundTransparency = math.clamp(t, 0, 1)
  end

  -- ── theme live-reload for this window ─────────
  local themeCleanup = nil
  local function applyCurrentTheme()
    win.BackgroundColor3  = Theme.Panel
    titlebar.BackgroundColor3 = Theme.TitleBG
    tabBar.BackgroundColor3   = Theme.TabBG
    applyGradient(win)
    applyNoise(win, Theme.NoiseOpacity)
  end
  table.insert(_themeListeners, applyCurrentTheme)

  -- ── visibility ────────────────────────────────
  function windowApi:Show()   screenGui.Enabled = true  end
  function windowApi:Hide()   screenGui.Enabled = false end
  function windowApi:Toggle() screenGui.Enabled = not screenGui.Enabled end
  function windowApi:IsVisible() return screenGui.Enabled end
  function windowApi:Destroy()
    -- remove theme listener
    for i, fn in ipairs(_themeListeners) do
      if fn == applyCurrentTheme then
        table.remove(_themeListeners, i)
        break
      end
    end
    screenGui:Destroy()
  end
  function windowApi:GetGui() return screenGui end
  function windowApi:GetFrame() return win end

  return windowApi
end

-- ══════════════════════════════════════════════
-- PUBLIC API
-- ══════════════════════════════════════════════
local MCUILib = {}

MCUILib.Icons  = Icons
MCUILib.Theme  = Theme

function MCUILib.Window(title, iconId, options)
  return createWindow(title, iconId, options)
end

-- standalone component constructors (attach to any frame)
MCUILib.Toggle      = createToggle
MCUILib.Slider      = createSlider
MCUILib.Input       = createInput
MCUILib.Dropdown    = createDropdown
MCUILib.Keybind     = createKeybind
MCUILib.Segmented   = createSegmented
MCUILib.Button      = createButton
MCUILib.ColorPicker = createColorPicker
MCUILib.Divider     = createDivider
MCUILib.Section     = createSection

-- global theme override — hot-reloads all live windows
function MCUILib.SetTheme(overrides)
  for k, v in pairs(overrides) do
    Theme[k] = v
  end
  fireTheme()
end

-- resolve helper exposed for userland
MCUILib.ResolveImage = resolveImage

return MCUILib
