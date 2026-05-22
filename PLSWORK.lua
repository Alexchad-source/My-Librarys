--[[
    Alexchad UI Library - v3 (FRESH BUILD - if you see this, the file updated correctly)
    
    Changes from v1:
    - Close button now on the far right, Minimize to its left (standard window layout)
    - Dialog animations use Quart easing (no more bouncy)
    - All unload/close animations smoothed out
    - Tab switching is now a REEL: all tab contents are stacked vertically inside
      a clipping viewport. Switching tabs tweens the reel up/down so the next
      tab slides in while the previous slides out in one continuous motion.
    - Supports any number of tabs (the reel auto-resizes)
    - Tab list itself scrolls if it exceeds vertical space
    - Fixed content getting cut off / bleeding outside when minimized:
      the MainContainer clips properly and content fades out instantly when
      the window shrinks below the content's needed size.
    
    Credit: Alexchad (original). Improved version.
    
    >>> PART 1 OF 3 — paste this, then PART2, then PART3 into the same file <<<
]]

local AlexchadLibrary = {}

-- Services
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local CoreGui           = game:GetService("CoreGui")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")

local Player = Players.LocalPlayer
local Mouse  = Player:GetMouse()

-- ============================================================
-- GUI parent selection (executor safe)
-- ============================================================
local function GetGuiParent()
    local ok, res = pcall(function()
        if gethui then return gethui() end
        if syn and syn.protect_gui then return CoreGui end
        return CoreGui
    end)
    return ok and res or CoreGui
end
local GuiParent = GetGuiParent()

local function CleanupAllBlur()
    for _, fx in pairs(Lighting:GetChildren()) do
        if fx:IsA("BlurEffect") and fx.Name:find("Alexchad") then
            fx:Destroy()
        end
    end
end

-- ============================================================
-- Themes
-- ============================================================
local Themes = {
    Default = {
        Background=Color3.fromRGB(20,20,30), BackgroundTransparency=0.15,
        Container=Color3.fromRGB(30,30,45),  ContainerTransparency=0.25,
        Element=Color3.fromRGB(40,40,60),    ElementTransparency=0.3,
        ElementHover=Color3.fromRGB(50,50,75),
        Accent=Color3.fromRGB(100,120,255),  AccentDark=Color3.fromRGB(70,90,200),
        AccentGlow=Color3.fromRGB(130,150,255),
        Text=Color3.fromRGB(255,255,255), TextDark=Color3.fromRGB(180,180,200),
        TextMuted=Color3.fromRGB(120,120,150),
        Border=Color3.fromRGB(80,80,120), BorderTransparency=0.5,
        Success=Color3.fromRGB(80,220,120), Warning=Color3.fromRGB(255,180,60), Error=Color3.fromRGB(255,80,80),
        GradientStart=Color3.fromRGB(60,60,100), GradientEnd=Color3.fromRGB(30,30,50)
    },
    Dark = {
        Background=Color3.fromRGB(10,10,15), BackgroundTransparency=0.1,
        Container=Color3.fromRGB(18,18,25),  ContainerTransparency=0.2,
        Element=Color3.fromRGB(25,25,35),    ElementTransparency=0.25,
        ElementHover=Color3.fromRGB(35,35,50),
        Accent=Color3.fromRGB(130,100,255),  AccentDark=Color3.fromRGB(100,70,200),
        AccentGlow=Color3.fromRGB(160,130,255),
        Text=Color3.fromRGB(255,255,255), TextDark=Color3.fromRGB(160,160,180),
        TextMuted=Color3.fromRGB(100,100,130),
        Border=Color3.fromRGB(60,60,90), BorderTransparency=0.6,
        Success=Color3.fromRGB(80,220,120), Warning=Color3.fromRGB(255,180,60), Error=Color3.fromRGB(255,80,80),
        GradientStart=Color3.fromRGB(40,40,70), GradientEnd=Color3.fromRGB(15,15,25)
    },
    Light = {
        Background=Color3.fromRGB(240,240,250), BackgroundTransparency=0.1,
        Container=Color3.fromRGB(250,250,255), ContainerTransparency=0.15,
        Element=Color3.fromRGB(235,235,245),   ElementTransparency=0.2,
        ElementHover=Color3.fromRGB(225,225,240),
        Accent=Color3.fromRGB(80,100,220), AccentDark=Color3.fromRGB(60,80,180),
        AccentGlow=Color3.fromRGB(110,130,255),
        Text=Color3.fromRGB(30,30,50), TextDark=Color3.fromRGB(80,80,110),
        TextMuted=Color3.fromRGB(130,130,160),
        Border=Color3.fromRGB(200,200,220), BorderTransparency=0.3,
        Success=Color3.fromRGB(60,180,100), Warning=Color3.fromRGB(230,160,40), Error=Color3.fromRGB(220,60,60),
        GradientStart=Color3.fromRGB(255,255,255), GradientEnd=Color3.fromRGB(230,230,245)
    },
    Ocean = {
        Background=Color3.fromRGB(15,25,40), BackgroundTransparency=0.15,
        Container=Color3.fromRGB(20,35,55),  ContainerTransparency=0.25,
        Element=Color3.fromRGB(25,45,70),    ElementTransparency=0.3,
        ElementHover=Color3.fromRGB(35,55,85),
        Accent=Color3.fromRGB(60,180,220),   AccentDark=Color3.fromRGB(40,150,190),
        AccentGlow=Color3.fromRGB(90,210,250),
        Text=Color3.fromRGB(255,255,255), TextDark=Color3.fromRGB(170,200,220),
        TextMuted=Color3.fromRGB(120,150,180),
        Border=Color3.fromRGB(60,100,140), BorderTransparency=0.5,
        Success=Color3.fromRGB(80,220,150), Warning=Color3.fromRGB(255,190,80), Error=Color3.fromRGB(255,100,100),
        GradientStart=Color3.fromRGB(40,80,120), GradientEnd=Color3.fromRGB(20,40,60)
    },
    Midnight = {
        Background=Color3.fromRGB(8,8,15), BackgroundTransparency=0.1,
        Container=Color3.fromRGB(12,12,22), ContainerTransparency=0.2,
        Element=Color3.fromRGB(18,18,32),   ElementTransparency=0.25,
        ElementHover=Color3.fromRGB(28,28,45),
        Accent=Color3.fromRGB(180,80,255),  AccentDark=Color3.fromRGB(140,50,200),
        AccentGlow=Color3.fromRGB(210,120,255),
        Text=Color3.fromRGB(255,255,255), TextDark=Color3.fromRGB(180,170,200),
        TextMuted=Color3.fromRGB(120,110,150),
        Border=Color3.fromRGB(80,60,120), BorderTransparency=0.5,
        Success=Color3.fromRGB(100,255,150), Warning=Color3.fromRGB(255,200,80), Error=Color3.fromRGB(255,80,100),
        GradientStart=Color3.fromRGB(50,30,80), GradientEnd=Color3.fromRGB(15,10,25)
    },
    Emerald = {
        Background=Color3.fromRGB(15,25,20), BackgroundTransparency=0.15,
        Container=Color3.fromRGB(20,35,28),  ContainerTransparency=0.25,
        Element=Color3.fromRGB(25,45,35),    ElementTransparency=0.3,
        ElementHover=Color3.fromRGB(35,60,48),
        Accent=Color3.fromRGB(50,205,130),   AccentDark=Color3.fromRGB(35,170,100),
        AccentGlow=Color3.fromRGB(80,235,160),
        Text=Color3.fromRGB(255,255,255), TextDark=Color3.fromRGB(180,210,195),
        TextMuted=Color3.fromRGB(130,160,145),
        Border=Color3.fromRGB(60,120,90), BorderTransparency=0.5,
        Success=Color3.fromRGB(80,255,150), Warning=Color3.fromRGB(255,200,80), Error=Color3.fromRGB(255,100,100),
        GradientStart=Color3.fromRGB(40,100,70), GradientEnd=Color3.fromRGB(20,50,35)
    }
}

-- ============================================================
-- Utility
-- ============================================================
local Utility = {}

function Utility:Create(class, props, children)
    local inst = Instance.new(class)
    for k,v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    for _,c in pairs(children or {}) do c.Parent = inst end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

function Utility:Tween(inst, props, dur, style, dir)
    if not inst then return end
    local ti = TweenInfo.new(
        dur or 0.25,
        style or Enum.EasingStyle.Quart,
        dir   or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(inst, ti, props)
    t:Play()
    return t
end

function Utility:Ripple(btn, theme, cfg)
    if not cfg.RippleEnabled then return end
    local rip = Utility:Create("Frame", {
        Name="Ripple", Parent=btn,
        BackgroundColor3=theme.AccentGlow, BackgroundTransparency=0.6,
        BorderSizePixel=0,
        Position=UDim2.new(0, Mouse.X-btn.AbsolutePosition.X, 0, Mouse.Y-btn.AbsolutePosition.Y),
        Size=UDim2.new(0,0,0,0), AnchorPoint=Vector2.new(0.5,0.5),
        ZIndex=btn.ZIndex+5
    }, { Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)}) })
    local sz = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y)*2.5
    Utility:Tween(rip, {Size=UDim2.new(0,sz,0,sz), BackgroundTransparency=1}, cfg.RippleSpeed).Completed:Connect(function()
        rip:Destroy()
    end)
end

function Utility:MakeDraggable(frame, handle, cfg)
    local dragging, dragInput, dragStart, startPos
    handle = handle or frame
    handle.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=input.Position; startPos=frame.Position
            input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
            dragInput=input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input==dragInput and dragging then
            local d = input.Position - dragStart
            Utility:Tween(frame, {
                Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
            }, cfg.AnimationSpeed*0.5)
        end
    end)
end

-- ============================================================
-- Config Manager (executor file IO)
-- ============================================================
local ConfigManager = {}

function ConfigManager:GetSaveFolder(folder)
    local ok,res = pcall(function()
        if isfolder and writefile and readfile then
            if not isfolder(folder) then makefolder(folder) end
            return true
        end
        return false
    end)
    return ok and res
end

function ConfigManager:Save(folder, file, data)
    pcall(function()
        if writefile then writefile(folder.."/"..file..".json", HttpService:JSONEncode(data)) end
    end)
end

function ConfigManager:Load(folder, file)
    local ok,res = pcall(function()
        if readfile and isfile then
            local p = folder.."/"..file..".json"
            if isfile(p) then return HttpService:JSONDecode(readfile(p)) end
        end
    end)
    return ok and res or nil
end

-- ============================================================
-- KeySystem (Rayfield-style)
-- ============================================================
local KeySystem = {}

function KeySystem:Show(options, themes)
    local ks         = options.KeySystem or {}
    local title      = ks.Title    or "Key System"
    local subtitle   = ks.Subtitle or "Authentication Required"
    local note       = ks.Note     or "Enter your key below to access this script."
    local fileName   = ks.FileName or "AlexchadKey"
    local saveKey    = ks.SaveKey  ~= false
    local validKeys  = ks.Key
    local keyURL     = ks.KeyURL
    local actions    = ks.Actions or {}
    local themeName  = ks.Theme    or options.Theme or "Default"
    local theme      = themes[themeName] or themes.Default

    if type(validKeys) == "string" then validKeys = {validKeys} end

    if ks.GetKey and #actions == 0 then
        table.insert(actions, {Type="Link", Text="Get Key", URL=ks.GetKey})
    end

    local function readSavedKey()
        if not saveKey then return nil end
        local ok, k = pcall(function()
            if isfile and isfile("AlexchadKeys/"..fileName..".txt") then
                return readfile("AlexchadKeys/"..fileName..".txt")
            end
        end)
        return ok and k or nil
    end
    local function writeSavedKey(k)
        if not saveKey then return end
        pcall(function()
            if not isfolder("AlexchadKeys") then makefolder("AlexchadKeys") end
            writefile("AlexchadKeys/"..fileName..".txt", k)
        end)
    end

    local function fetchKeysFromURL()
        if not keyURL then return nil end
        local ok, body = pcall(function() return game:HttpGet(keyURL) end)
        if not ok or type(body) ~= "string" then return nil end
        local list = {}
        for line in body:gmatch("[^\r\n]+") do
            local trimmed = line:match("^%s*(.-)%s*$")
            if trimmed and #trimmed > 0 then
                table.insert(list, trimmed)
            end
        end
        return list
    end

    local function isValid(input)
        if not input or input == "" then return false end
        if validKeys then
            for _, k in ipairs(validKeys) do
                if input == k then return true end
            end
        end
        if keyURL then
            local list = fetchKeysFromURL()
            if list then
                for _, k in ipairs(list) do
                    if input == k then return true end
                end
            end
        end
        return false
    end

    local forceShow = ks.ForceShow == true
    if not forceShow then
        local saved = readSavedKey()
        if saved and isValid(saved) then
            return true
        end
    end

    local KeyGui = Instance.new("ScreenGui")
    KeyGui.Name = "AlexchadKeySystem"
    KeyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    KeyGui.ResetOnSpawn = false
    KeyGui.IgnoreGuiInset = true
    KeyGui.Parent = GuiParent

    local Bg = Instance.new("Frame")
    Bg.Name = "Bg"
    Bg.BackgroundColor3 = Color3.new(0,0,0)
    Bg.BackgroundTransparency = 0.4
    Bg.Size = UDim2.new(1,0,1,0)
    Bg.BorderSizePixel = 0
    Bg.Parent = KeyGui

    local blur
    pcall(function()
        blur = Instance.new("BlurEffect")
        blur.Name = "AlexchadKeyBlur"
        blur.Size = 0
        blur.Parent = Lighting
        TweenService:Create(blur, TweenInfo.new(0.3), {Size=15}):Play()
    end)

    local Card = Instance.new("Frame")
    Card.Name = "Card"
    Card.AnchorPoint = Vector2.new(0.5,0.5)
    Card.Position = UDim2.new(0.5,0,0.5,10)
    Card.Size = UDim2.new(0,0,0,0)
    Card.BackgroundColor3 = theme.Background
    Card.BackgroundTransparency = 1
    Card.ClipsDescendants = true
    Card.Parent = Bg
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,14); corner.Parent = Card
    local stroke = Instance.new("UIStroke"); stroke.Color = theme.Border; stroke.Transparency = 1; stroke.Thickness = 1.5; stroke.Parent = Card
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, theme.GradientStart),
        ColorSequenceKeypoint.new(1, theme.GradientEnd)
    })
    grad.Rotation = 135
    grad.Transparency = NumberSequence.new(0.3)
    grad.Parent = Card

    TweenService:Create(Card, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.new(0,400,0,260),
        Position = UDim2.new(0.5,0,0.5,0),
        BackgroundTransparency = theme.BackgroundTransparency
    }):Play()
    TweenService:Create(stroke, TweenInfo.new(0.4), {Transparency = theme.BorderTransparency}):Play()

    task.wait(0.15)

    local function mk(class, props, parent)
        local i = Instance.new(class)
        for k,v in pairs(props) do i[k] = v end
        i.Parent = parent
        return i
    end

    mk("TextLabel", {
        BackgroundTransparency=1, Position=UDim2.new(0,20,0,18), Size=UDim2.new(1,-40,0,22),
        Font=Enum.Font.GothamBold, Text=title, TextColor3=theme.Text, TextSize=18,
        TextXAlignment=Enum.TextXAlignment.Left
    }, Card)
    mk("TextLabel", {
        BackgroundTransparency=1, Position=UDim2.new(0,20,0,40), Size=UDim2.new(1,-40,0,16),
        Font=Enum.Font.Gotham, Text=subtitle, TextColor3=theme.Accent, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left
    }, Card)
    mk("TextLabel", {
        BackgroundTransparency=1, Position=UDim2.new(0,20,0,64), Size=UDim2.new(1,-40,0,40),
        Font=Enum.Font.Gotham, Text=note, TextColor3=theme.TextMuted, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top,
        TextWrapped=true
    }, Card)

    local InputBox = Instance.new("Frame")
    InputBox.Position = UDim2.new(0,20,0,114)
    InputBox.Size = UDim2.new(1,-40,0,38)
    InputBox.BackgroundColor3 = theme.Element
    InputBox.BackgroundTransparency = theme.ElementTransparency
    InputBox.Parent = Card
    local ibc = Instance.new("UICorner"); ibc.CornerRadius = UDim.new(0,8); ibc.Parent = InputBox
    local ibs = Instance.new("UIStroke"); ibs.Color = theme.Border; ibs.Transparency = theme.BorderTransparency; ibs.Thickness = 1; ibs.Name = "Stroke"; ibs.Parent = InputBox

    local TB = mk("TextBox",{
        BackgroundTransparency=1, Position=UDim2.new(0,12,0,0), Size=UDim2.new(1,-24,1,0),
        Font=Enum.Font.Gotham, PlaceholderText="Enter your key...",
        PlaceholderColor3=theme.TextMuted, Text="", TextColor3=theme.Text, TextSize=14,
        ClearTextOnFocus=false, ClipsDescendants=true,
        TextXAlignment=Enum.TextXAlignment.Left
    }, InputBox)

    TB.Focused:Connect(function()
        TweenService:Create(ibs, TweenInfo.new(0.2), {Color=theme.Accent, Transparency=0}):Play()
    end)
    TB.FocusLost:Connect(function()
        TweenService:Create(ibs, TweenInfo.new(0.2), {Color=theme.Border, Transparency=theme.BorderTransparency}):Play()
    end)

    local Status = mk("TextLabel",{
        BackgroundTransparency=1, Position=UDim2.new(0,20,0,158), Size=UDim2.new(1,-40,0,16),
        Font=Enum.Font.GothamSemibold, Text="", TextColor3=theme.Error, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left
    }, Card)

    local Row = Instance.new("Frame")
    Row.BackgroundTransparency = 1
    Row.Position = UDim2.new(0,20,1,-58)
    Row.Size = UDim2.new(1,-40,0,40)
    Row.Parent = Card
    local rowList = Instance.new("UIListLayout")
    rowList.FillDirection = Enum.FillDirection.Horizontal
    rowList.HorizontalAlignment = Enum.HorizontalAlignment.Left
    rowList.VerticalAlignment = Enum.VerticalAlignment.Center
    rowList.Padding = UDim.new(0,8)
    rowList.Parent = Row

    local function makeBtn(text, primary, parent)
        local b = Instance.new("TextButton")
        b.BackgroundColor3 = primary and theme.Accent or theme.Element
        b.BackgroundTransparency = primary and 0 or theme.ElementTransparency
        b.Size = UDim2.new(0,110,0,36)
        b.Font = Enum.Font.GothamBold
        b.Text = text
        b.TextColor3 = primary and theme.Text or theme.TextDark
        b.TextSize = 13
        b.AutoButtonColor = false
        b.Parent = parent
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,8); bc.Parent = b
        local bs = Instance.new("UIStroke"); bs.Color = primary and theme.Accent or theme.Border; bs.Transparency = primary and 0.3 or theme.BorderTransparency; bs.Thickness = 1; bs.Parent = b
        b.MouseEnter:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.15), {
                BackgroundColor3 = primary and theme.AccentDark or theme.ElementHover,
                BackgroundTransparency = primary and 0 or theme.ElementTransparency - 0.1,
                TextColor3 = theme.Text
            }):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.15), {
                BackgroundColor3 = primary and theme.Accent or theme.Element,
                BackgroundTransparency = primary and 0 or theme.ElementTransparency,
                TextColor3 = primary and theme.Text or theme.TextDark
            }):Play()
        end)
        return b
    end

    local validated = false

    for _, act in ipairs(actions) do
        local b = makeBtn(act.Text or "Get Key", false, Row)
        b.MouseButton1Click:Connect(function()
            local actType = act.Type or "Link"
            if actType == "Link" or actType == "URL" then
                pcall(function()
                    if setclipboard then setclipboard(act.URL or "") end
                end)
                Status.TextColor3 = theme.Success
                Status.Text = "Link copied to clipboard!"
            elseif actType == "Callback" and act.Callback then
                pcall(act.Callback)
            end
        end)
    end

    local spacer = Instance.new("Frame")
    spacer.BackgroundTransparency = 1
    spacer.Size = UDim2.new(1, -(#actions * 118) - 118, 0, 1)
    spacer.LayoutOrder = 50
    spacer.Parent = Row

    local CheckBtn = makeBtn("Check Key", true, Row)
    CheckBtn.LayoutOrder = 100

    local proceed = false

    CheckBtn.MouseButton1Click:Connect(function()
        local input = TB.Text:match("^%s*(.-)%s*$") or ""
        if input == "" then
            Status.TextColor3 = theme.Warning
            Status.Text = "Please enter a key."
            return
        end
        Status.TextColor3 = theme.TextMuted
        Status.Text = "Checking..."
        CheckBtn.Text = "..."

        task.spawn(function()
            local ok = isValid(input)
            if ok then
                writeSavedKey(input)
                Status.TextColor3 = theme.Success
                Status.Text = "Key valid! Loading..."
                validated = true
                task.wait(0.6)
                TweenService:Create(Card, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
                    Size = UDim2.new(0,0,0,0), BackgroundTransparency = 1
                }):Play()
                TweenService:Create(Bg, TweenInfo.new(0.3), {BackgroundTransparency=1}):Play()
                if blur then TweenService:Create(blur, TweenInfo.new(0.3), {Size=0}):Play() end
                task.wait(0.35)
                if blur then blur:Destroy() end
                KeyGui:Destroy()
                proceed = true
            else
                Status.TextColor3 = theme.Error
                Status.Text = "Invalid key. Please try again."
                CheckBtn.Text = "Check Key"
            end
        end)
    end)

    repeat task.wait(0.1) until proceed or not KeyGui.Parent

    if blur and blur.Parent then blur:Destroy() end
    return validated
end

-- >>> END OF PART 1 — continue with PART 2 below <<<
-- >>> PART 2 OF 3 — paste this directly after PART 1, before PART 3 <<<

function AlexchadLibrary:CreateWindow(options)
    options = options or {}

    -- Key System gate
    if options.KeySystem and options.KeySystem.Enabled then
        local ok = KeySystem:Show(options, Themes)
        if not ok then return nil end
    end

    CleanupAllBlur()
    if GuiParent:FindFirstChild("AlexchadUI") then
        GuiParent.AlexchadUI:Destroy()
    end

    local windowName    = options.Name           or "Alexchad"
    local windowSub     = options.Subtitle       or "Interface Suite"
    local windowVer     = options.Version        or "v3.0"
    local loadingTitle  = options.LoadingTitle   or "Alexchad Interface"
    local loadingSub    = options.LoadingSubtitle or "Loading..."
    local themeName     = options.Theme          or "Default"
    local configSaving  = options.ConfigurationSaving or {}
    local configEnabled = configSaving.Enabled  or false
    local configFolder  = configSaving.FolderName or "AlexchadConfig"
    local configFile    = configSaving.FileName   or "config"

    local Config = {
        AnimationSpeed       = options.AnimationSpeed       or 0.28,
        TabSwitchSpeed       = options.TabSwitchSpeed       or 0.4,
        RippleEnabled        = options.RippleEnabled ~= false,
        RippleSpeed          = options.RippleSpeed          or 0.4,
        CornerRadius         = options.CornerRadius         or 12,
        ElementCornerRadius  = options.ElementCornerRadius  or 10,
        BlurEnabled          = options.BlurEnabled ~= false
    }

    local WIN_W, WIN_H = 700, 480
    local MIN_H        = 85

    local Window = {
        Tabs = {}, CurrentTab = nil,
        Theme = Themes[themeName] or Themes.Default,
        ThemeName = themeName,
        Config = Config,
        Minimized = false,
        Elements = {},
        ConfigData = {},
        Connections = {},
        ElementRefs = {}
    }

    if configEnabled then
        ConfigManager:GetSaveFolder(configFolder)
        local saved = ConfigManager:Load(configFolder, configFile)
        if saved then
            Window.ConfigData = saved
            if saved.Theme and Themes[saved.Theme] then
                Window.Theme = Themes[saved.Theme]
                Window.ThemeName = saved.Theme
            end
        end
    end

    local theme = Window.Theme

    local ScreenGui = Utility:Create("ScreenGui", {
        Name="AlexchadUI", Parent=GuiParent,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn=false, IgnoreGuiInset=true
    })

    local Blur
    if Config.BlurEnabled then
        Blur = Utility:Create("BlurEffect",{Name="AlexchadBlur", Parent=Lighting, Size=0})
    end

    -- Loading screen
    local LoadingFrame = Utility:Create("Frame",{
        Name="LoadingFrame", Parent=ScreenGui,
        BackgroundColor3=theme.Background, BackgroundTransparency=theme.BackgroundTransparency,
        Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.new(0,320,0,160),
        AnchorPoint=Vector2.new(0.5,0.5)
    },{
        Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.CornerRadius+4)}),
        Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency,Thickness=1.5}),
        Utility:Create("UIGradient",{
            Color=ColorSequence.new({ColorSequenceKeypoint.new(0,theme.GradientStart),ColorSequenceKeypoint.new(1,theme.GradientEnd)}),
            Rotation=135,
            Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3),NumberSequenceKeypoint.new(0.5,0.5),NumberSequenceKeypoint.new(1,0.3)})
        })
    })

    local LT = Utility:Create("TextLabel",{Parent=LoadingFrame,BackgroundTransparency=1,Position=UDim2.new(0,0,0,35),Size=UDim2.new(1,0,0,30),Font=Enum.Font.GothamBold,Text=loadingTitle,TextColor3=theme.Text,TextSize=22,TextTransparency=1})
    local LS = Utility:Create("TextLabel",{Parent=LoadingFrame,BackgroundTransparency=1,Position=UDim2.new(0,0,0,65),Size=UDim2.new(1,0,0,20),Font=Enum.Font.Gotham,Text=loadingSub,TextColor3=theme.TextDark,TextSize=14,TextTransparency=1})
    local LBg = Utility:Create("Frame",{Parent=LoadingFrame,BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency,Position=UDim2.new(0.1,0,0,110),Size=UDim2.new(0.8,0,0,8)},{Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})
    local LFill = Utility:Create("Frame",{Parent=LBg,BackgroundColor3=theme.Accent,Size=UDim2.new(0,0,1,0)},{Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})

    if Blur then Utility:Tween(Blur,{Size=10},Config.AnimationSpeed) end
    Utility:Tween(LT,{TextTransparency=0},Config.AnimationSpeed)
    task.wait(Config.AnimationSpeed*0.5)
    Utility:Tween(LS,{TextTransparency=0},Config.AnimationSpeed)
    Utility:Tween(LFill,{Size=UDim2.new(1,0,1,0)},1.5,Enum.EasingStyle.Quart,Enum.EasingDirection.InOut)
    task.wait(1.8)
    Utility:Tween(LoadingFrame,{BackgroundTransparency=1},Config.AnimationSpeed)
    Utility:Tween(LT,{TextTransparency=1},Config.AnimationSpeed)
    Utility:Tween(LS,{TextTransparency=1},Config.AnimationSpeed)
    Utility:Tween(LBg,{BackgroundTransparency=1},Config.AnimationSpeed)
    Utility:Tween(LFill,{BackgroundTransparency=1},Config.AnimationSpeed)
    for _,c in pairs(LoadingFrame:GetDescendants()) do
        if c:IsA("UIStroke") then Utility:Tween(c,{Transparency=1},Config.AnimationSpeed) end
    end
    task.wait(Config.AnimationSpeed+0.1)
    LoadingFrame:Destroy()

    -- Main container (clips everything - fixes minimize cutoff)
    local MainContainer = Utility:Create("Frame",{
        Name="MainContainer", Parent=ScreenGui,
        BackgroundColor3=theme.Background, BackgroundTransparency=theme.BackgroundTransparency,
        Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.new(0,0,0,0),
        AnchorPoint=Vector2.new(0.5,0.5),
        ClipsDescendants=true
    },{
        Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.CornerRadius+6)}),
        Utility:Create("UIStroke",{Name="MainStroke",Color=theme.Border,Transparency=theme.BorderTransparency,Thickness=1.5}),
        Utility:Create("UIGradient",{
            Name="MainGradient",
            Color=ColorSequence.new({ColorSequenceKeypoint.new(0,theme.GradientStart),ColorSequenceKeypoint.new(1,theme.GradientEnd)}),
            Rotation=135,
            Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3),NumberSequenceKeypoint.new(0.5,0.5),NumberSequenceKeypoint.new(1,0.3)})
        })
    })

    local Glow = Utility:Create("ImageLabel",{
        Name="Glow", Parent=MainContainer, BackgroundTransparency=1,
        Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.new(1,50,1,50),
        AnchorPoint=Vector2.new(0.5,0.5),
        Image="rbxassetid://5028857084", ImageColor3=theme.Accent, ImageTransparency=0.85,
        ZIndex=0, ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(24,24,276,276)
    })

    Utility:Tween(MainContainer,{Size=UDim2.new(0,WIN_W,0,WIN_H)},Config.AnimationSpeed*1.6,Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
    task.wait(Config.AnimationSpeed*0.8)

    -- Header
    local Header = Utility:Create("Frame",{
        Name="Header", Parent=MainContainer,
        BackgroundColor3=theme.Container, BackgroundTransparency=theme.ContainerTransparency+0.1,
        Position=UDim2.new(0,15,0,15), Size=UDim2.new(1,-30,0,55)
    },{
        Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.CornerRadius)}),
        Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency+0.2,Thickness=1})
    })

    local TitleLabel = Utility:Create("TextLabel",{
        Name="Title", Parent=Header, BackgroundTransparency=1,
        Position=UDim2.new(0,15,0,8), Size=UDim2.new(0.6,0,0,22),
        Font=Enum.Font.GothamBold, Text=windowName, TextColor3=theme.Text, TextSize=18,
        TextXAlignment=Enum.TextXAlignment.Left
    })
    local SubtitleLabel = Utility:Create("TextLabel",{
        Name="Subtitle", Parent=Header, BackgroundTransparency=1,
        Position=UDim2.new(0,15,0,30), Size=UDim2.new(0.6,0,0,16),
        Font=Enum.Font.Gotham, Text=windowSub.." | "..windowVer, TextColor3=theme.TextMuted, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left
    })

    -- Controls: Minimize=1 (left), Close=2 (right)
    local ControlsContainer = Utility:Create("Frame",{
        Name="Controls", Parent=Header, BackgroundTransparency=1,
        Position=UDim2.new(1,-95,0,0), Size=UDim2.new(0,80,1,0)
    },{
        Utility:Create("UIListLayout",{
            FillDirection=Enum.FillDirection.Horizontal,
            HorizontalAlignment=Enum.HorizontalAlignment.Right,
            VerticalAlignment=Enum.VerticalAlignment.Center,
            SortOrder=Enum.SortOrder.LayoutOrder,
            Padding=UDim.new(0,8)
        })
    })

    local function CreateControlButton(name, text, layoutOrder, hoverColor, callback)
        local btn = Utility:Create("TextButton",{
            Name=name, Parent=ControlsContainer,
            BackgroundColor3=theme.Element, BackgroundTransparency=theme.ElementTransparency,
            Size=UDim2.new(0,34,0,34),
            Font=Enum.Font.GothamBold, Text=text, TextColor3=theme.TextDark, TextSize=16,
            AutoButtonColor=false, LayoutOrder=layoutOrder
        },{
            Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius)}),
            Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency+0.2,Thickness=1})
        })
        btn.MouseEnter:Connect(function()
            Utility:Tween(btn,{BackgroundColor3=hoverColor,BackgroundTransparency=0,TextColor3=theme.Text},Config.AnimationSpeed*0.5)
        end)
        btn.MouseLeave:Connect(function()
            Utility:Tween(btn,{BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency,TextColor3=theme.TextDark},Config.AnimationSpeed*0.5)
        end)
        btn.MouseButton1Click:Connect(function()
            Utility:Ripple(btn, theme, Config)
            callback()
        end)
        return btn
    end

    CreateControlButton("Minimize","-",1,theme.Warning,function()
        Window.Minimized = not Window.Minimized
        if Window.Minimized then
            Utility:Tween(MainContainer,{Size=UDim2.new(0,WIN_W,0,MIN_H)},Config.AnimationSpeed,Enum.EasingStyle.Quint)
            if Blur then Utility:Tween(Blur,{Size=5},Config.AnimationSpeed) end
        else
            Utility:Tween(MainContainer,{Size=UDim2.new(0,WIN_W,0,WIN_H)},Config.AnimationSpeed,Enum.EasingStyle.Quint)
            if Blur then Utility:Tween(Blur,{Size=10},Config.AnimationSpeed) end
        end
    end)

    CreateControlButton("Close","X",2,theme.Error,function()
        for _,c in pairs(Window.Connections) do
            if c and c.Connected then c:Disconnect() end
        end
        if Blur then Utility:Tween(Blur,{Size=0},Config.AnimationSpeed*1.2) end
        Utility:Tween(MainContainer,{
            Size=UDim2.new(0,0,0,0),
            BackgroundTransparency=1
        }, Config.AnimationSpeed*1.2, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
        local stroke = MainContainer:FindFirstChild("MainStroke")
        if stroke then Utility:Tween(stroke,{Transparency=1},Config.AnimationSpeed*1.2) end
        task.wait(Config.AnimationSpeed*1.4)
        CleanupAllBlur()
        ScreenGui:Destroy()
    end)

    Utility:MakeDraggable(MainContainer, Header, Config)

    -- Drag pill under the GUI (Rayfield-style)
    local DragPill = Utility:Create("Frame",{
        Name="DragPill", Parent=MainContainer,
        BackgroundColor3=Color3.fromRGB(200,200,200),
        BackgroundTransparency=0.7,
        BorderSizePixel=0,
        Position=UDim2.new(0.5,0,1,-8),
        Size=UDim2.new(0,55,0,4),
        AnchorPoint=Vector2.new(0.5,0.5),
        ZIndex=10
    },{ Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)}) })

    local DragPillHit = Utility:Create("TextButton",{
        Name="DragPillHit", Parent=MainContainer,
        BackgroundTransparency=1, Text="",
        AutoButtonColor=false,
        Position=UDim2.new(0.5,0,1,-8),
        Size=UDim2.new(0,90,0,20),
        AnchorPoint=Vector2.new(0.5,0.5),
        ZIndex=11
    })

    DragPillHit.MouseEnter:Connect(function()
        Utility:Tween(DragPill,{
            BackgroundColor3=Color3.fromRGB(255,255,255),
            BackgroundTransparency=0.1,
            Size=UDim2.new(0,70,0,5)
        }, Config.AnimationSpeed*0.5)
    end)
    DragPillHit.MouseLeave:Connect(function()
        Utility:Tween(DragPill,{
            BackgroundColor3=Color3.fromRGB(200,200,200),
            BackgroundTransparency=0.7,
            Size=UDim2.new(0,55,0,4)
        }, Config.AnimationSpeed*0.5)
    end)

    Utility:MakeDraggable(MainContainer, DragPillHit, Config)

    -- Content area
    local ContentArea = Utility:Create("Frame",{
        Name="ContentArea", Parent=MainContainer, BackgroundTransparency=1,
        Position=UDim2.new(0,15,0,80), Size=UDim2.new(1,-30,1,-95),
        ClipsDescendants=true
    })

    -- Tab list (scrolling)
    local TabContainer = Utility:Create("Frame",{
        Name="TabContainer", Parent=ContentArea,
        BackgroundColor3=theme.Container, BackgroundTransparency=theme.ContainerTransparency,
        Size=UDim2.new(0,150,1,0)
    },{
        Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.CornerRadius)}),
        Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency+0.2,Thickness=1})
    })

    local TabList = Utility:Create("ScrollingFrame",{
        Name="TabList", Parent=TabContainer, BackgroundTransparency=1,
        Position=UDim2.new(0,10,0,10), Size=UDim2.new(1,-20,1,-20),
        ScrollBarThickness=3, ScrollBarImageColor3=theme.Accent, ScrollBarImageTransparency=0.5,
        CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ClipsDescendants=true, BorderSizePixel=0
    },{ Utility:Create("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6)}) })

    -- MainContent: viewport for the reel
    local MainContent = Utility:Create("Frame",{
        Name="MainContent", Parent=ContentArea,
        BackgroundColor3=theme.Container, BackgroundTransparency=theme.ContainerTransparency,
        Position=UDim2.new(0,160,0,0), Size=UDim2.new(1,-160,1,0),
        ClipsDescendants=true
    },{
        Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.CornerRadius)}),
        Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency+0.2,Thickness=1})
    })

    local Reel = Utility:Create("Frame",{
        Name="Reel", Parent=MainContent,
        BackgroundTransparency=1,
        Position=UDim2.new(0,0,0,0),
        Size=UDim2.new(1,0,1,0)
    })

    -- Save config helper
    local function SaveConfig()
        if not configEnabled then return end
        local data = { Theme=Window.ThemeName, Elements={} }
        for id,el in pairs(Window.Elements) do
            if el.Value ~= nil then data.Elements[id]=el.Value end
        end
        Window.ConfigData = data
        ConfigManager:Save(configFolder, configFile, data)
    end

    -- ApplyTheme
    local function ApplyTheme(newName, animate)
        local nt = Themes[newName]; if not nt then return end
        Window.Theme=nt; Window.ThemeName=newName; theme=nt
        local d = animate and Config.AnimationSpeed or 0

        Utility:Tween(MainContainer,{BackgroundColor3=nt.Background,BackgroundTransparency=nt.BackgroundTransparency},d)
        local ms=MainContainer:FindFirstChild("MainStroke"); if ms then Utility:Tween(ms,{Color=nt.Border,Transparency=nt.BorderTransparency},d) end
        local mg=MainContainer:FindFirstChild("MainGradient")
        if mg then mg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,nt.GradientStart),ColorSequenceKeypoint.new(1,nt.GradientEnd)}) end
        Utility:Tween(Glow,{ImageColor3=nt.Accent},d)
        Utility:Tween(Header,{BackgroundColor3=nt.Container,BackgroundTransparency=nt.ContainerTransparency+0.1},d)
        Utility:Tween(TitleLabel,{TextColor3=nt.Text},d)
        Utility:Tween(SubtitleLabel,{TextColor3=nt.TextMuted},d)
        Utility:Tween(TabContainer,{BackgroundColor3=nt.Container,BackgroundTransparency=nt.ContainerTransparency},d)
        Utility:Tween(MainContent,{BackgroundColor3=nt.Container,BackgroundTransparency=nt.ContainerTransparency},d)

        for _,tab in pairs(Window.Tabs) do
            local isCur = tab==Window.CurrentTab
            Utility:Tween(tab.Button,{
                BackgroundColor3 = isCur and nt.Accent or nt.Element,
                BackgroundTransparency = isCur and 0 or nt.ElementTransparency
            }, d)
            Utility:Tween(tab.Label,{TextColor3=isCur and nt.Text or nt.TextDark},d)
            Utility:Tween(tab.Icon,{TextColor3=isCur and nt.Text or nt.TextDark},d)
            Utility:Tween(tab.Indicator,{BackgroundColor3=nt.Accent},d)
            local bs=tab.Button:FindFirstChildOfClass("UIStroke")
            if bs then Utility:Tween(bs,{Color=nt.Border,Transparency=nt.BorderTransparency+0.3},d) end
        end

        for _,ref in pairs(Window.ElementRefs) do
            local f = ref.Frame
            if ref.Type=="Toggle" then
                local on = ref.Element.Value
                Utility:Tween(f,{BackgroundColor3=nt.Element,BackgroundTransparency=nt.ElementTransparency},d)
                Utility:Tween(ref.Label,{TextColor3=nt.Text},d)
                Utility:Tween(ref.Switch,{BackgroundColor3=on and nt.Accent or nt.Element,BackgroundTransparency=on and 0 or nt.ElementTransparency-0.1},d)
                Utility:Tween(ref.Circle,{BackgroundColor3=nt.Text},d)
                local ss=ref.Switch:FindFirstChild("SwitchStroke"); if ss then Utility:Tween(ss,{Color=on and nt.Accent or nt.Border},d) end
                local fs=f:FindFirstChildOfClass("UIStroke"); if fs then Utility:Tween(fs,{Color=nt.Border},d) end
            elseif ref.Type=="Slider" then
                Utility:Tween(f,{BackgroundColor3=nt.Element,BackgroundTransparency=nt.ElementTransparency},d)
                Utility:Tween(ref.Label,{TextColor3=nt.Text},d)
                Utility:Tween(ref.ValueLabel,{TextColor3=nt.Accent},d)
                Utility:Tween(ref.BarBg,{BackgroundColor3=nt.Container,BackgroundTransparency=nt.ContainerTransparency-0.1},d)
                Utility:Tween(ref.Fill,{BackgroundColor3=nt.Accent},d)
                Utility:Tween(ref.Knob,{BackgroundColor3=nt.Text},d)
                local ks=ref.Knob:FindFirstChildOfClass("UIStroke"); if ks then Utility:Tween(ks,{Color=nt.Accent},d) end
                local fg=ref.Fill:FindFirstChildOfClass("UIGradient")
                if fg then fg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,nt.Accent),ColorSequenceKeypoint.new(1,nt.AccentGlow)}) end
                local fs=f:FindFirstChildOfClass("UIStroke"); if fs then Utility:Tween(fs,{Color=nt.Border},d) end
            elseif ref.Type=="Button" then
                Utility:Tween(f,{BackgroundColor3=nt.Element,BackgroundTransparency=nt.ElementTransparency},d)
                Utility:Tween(ref.Label,{TextColor3=nt.Text},d)
                Utility:Tween(ref.Icon,{TextColor3=nt.Accent},d)
                local fs=f:FindFirstChildOfClass("UIStroke"); if fs then Utility:Tween(fs,{Color=nt.Border},d) end
            elseif ref.Type=="Dropdown" then
                Utility:Tween(f,{BackgroundColor3=nt.Element,BackgroundTransparency=nt.ElementTransparency},d)
                Utility:Tween(ref.Label,{TextColor3=nt.Text},d)
                Utility:Tween(ref.Selected,{TextColor3=nt.TextDark},d)
                Utility:Tween(ref.Arrow,{TextColor3=nt.TextDark},d)
                local fs=f:FindFirstChildOfClass("UIStroke"); if fs then Utility:Tween(fs,{Color=nt.Border},d) end
                for _,opt in pairs(ref.OptionsContainer:GetChildren()) do
                    if opt:IsA("TextButton") then
                        local v = ref.Element.Value
                        local sel = (type(v)=="table") and (table.find(v,opt.Name)~=nil) or (v==opt.Name)
                        Utility:Tween(opt,{
                            BackgroundColor3=sel and nt.Accent or nt.Container,
                            BackgroundTransparency=sel and 0 or nt.ContainerTransparency,
                            TextColor3=sel and nt.Text or nt.TextDark
                        },d)
                    end
                end
            elseif ref.Type=="Input" then
                Utility:Tween(f,{BackgroundColor3=nt.Element,BackgroundTransparency=nt.ElementTransparency},d)
                Utility:Tween(ref.Label,{TextColor3=nt.Text},d)
                Utility:Tween(ref.BoxContainer,{BackgroundColor3=nt.Container,BackgroundTransparency=nt.ContainerTransparency},d)
                Utility:Tween(ref.TextBox,{TextColor3=nt.Text,PlaceholderColor3=nt.TextMuted},d)
                local fs=f:FindFirstChildOfClass("UIStroke"); if fs then Utility:Tween(fs,{Color=nt.Border},d) end
                local bs=ref.BoxContainer:FindFirstChild("BoxStroke"); if bs then Utility:Tween(bs,{Color=nt.Border},d) end
            elseif ref.Type=="Keybind" then
                Utility:Tween(f,{BackgroundColor3=nt.Element,BackgroundTransparency=nt.ElementTransparency},d)
                Utility:Tween(ref.Label,{TextColor3=nt.Text},d)
                Utility:Tween(ref.KeyButton,{BackgroundColor3=nt.Container,BackgroundTransparency=nt.ContainerTransparency,TextColor3=nt.TextDark},d)
                local fs=f:FindFirstChildOfClass("UIStroke"); if fs then Utility:Tween(fs,{Color=nt.Border},d) end
            elseif ref.Type=="ColorPicker" then
                Utility:Tween(f,{BackgroundColor3=nt.Element,BackgroundTransparency=nt.ElementTransparency},d)
                Utility:Tween(ref.Label,{TextColor3=nt.Text},d)
                Utility:Tween(ref.RGBLabel,{TextColor3=nt.TextDark},d)
                local ds=ref.Display:FindFirstChildOfClass("UIStroke"); if ds then Utility:Tween(ds,{Color=nt.Border},d) end
                local fs=f:FindFirstChildOfClass("UIStroke"); if fs then Utility:Tween(fs,{Color=nt.Border},d) end
            elseif ref.Type=="Label" then
                Utility:Tween(f,{BackgroundColor3=nt.Element,BackgroundTransparency=nt.ElementTransparency+0.1},d)
                Utility:Tween(ref.Text,{TextColor3=nt.TextDark},d)
            elseif ref.Type=="Paragraph" then
                Utility:Tween(f,{BackgroundColor3=nt.Element,BackgroundTransparency=nt.ElementTransparency},d)
                Utility:Tween(ref.Title,{TextColor3=nt.Text},d)
                Utility:Tween(ref.Content,{TextColor3=nt.TextDark},d)
                local fs=f:FindFirstChildOfClass("UIStroke"); if fs then Utility:Tween(fs,{Color=nt.Border},d) end
            end
        end

        TabList.ScrollBarImageColor3 = nt.Accent
        for _,tab in pairs(Window.Tabs) do
            tab.Content.ScrollBarImageColor3 = nt.Accent
        end
        SaveConfig()
    end
    Window.ApplyTheme = ApplyTheme

    -- ============================================================
    -- NOTIFICATION SYSTEM (Lucide-style icons, themed, queued)
    -- Position: options.NotificationPosition = "Top" or "Bottom"
    -- ============================================================
    local NotifConfig = {
        Position = (options.NotificationPosition or "Bottom"),
        Width = 280, Spacing = 8
    }
    local NotifQueue = {}
    local NotifActive = {}

    local function DrawLucideIcon(parent, kind, color)
        local box = Utility:Create("Frame",{
            Name="Icon", Parent=parent, BackgroundTransparency=1,
            Size=UDim2.new(0,16,0,16),
            Position=UDim2.new(0,0,0.5,0), AnchorPoint=Vector2.new(0,0.5)
        })
        local function ring()
            Utility:Create("Frame",{
                Parent=box, BackgroundTransparency=1, Size=UDim2.new(1,0,1,0)
            },{
                Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)}),
                Utility:Create("UIStroke",{Color=color, Thickness=1.5, Transparency=0})
            })
        end
        if kind == "Info" then
            ring()
            Utility:Create("Frame",{Parent=box, BackgroundColor3=color, BorderSizePixel=0,
                Position=UDim2.new(0.5,0,0,3), Size=UDim2.new(0,2,0,2),
                AnchorPoint=Vector2.new(0.5,0)},{Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})
            Utility:Create("Frame",{Parent=box, BackgroundColor3=color, BorderSizePixel=0,
                Position=UDim2.new(0.5,0,0.5,1), Size=UDim2.new(0,2,0,6),
                AnchorPoint=Vector2.new(0.5,0.5)},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,1)})})
        elseif kind == "Success" then
            ring()
            Utility:Create("Frame",{Parent=box, BackgroundColor3=color, BorderSizePixel=0,
                Position=UDim2.new(0.38,0,0.62,0), Size=UDim2.new(0,4,0,1.5),
                AnchorPoint=Vector2.new(0.5,0.5), Rotation=45},
                {Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})
            Utility:Create("Frame",{Parent=box, BackgroundColor3=color, BorderSizePixel=0,
                Position=UDim2.new(0.6,0,0.45,0), Size=UDim2.new(0,7,0,1.5),
                AnchorPoint=Vector2.new(0.5,0.5), Rotation=-45},
                {Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})
        elseif kind == "Warning" then
            local function line(x,y,w,rot)
                Utility:Create("Frame",{Parent=box, BackgroundColor3=color, BorderSizePixel=0,
                    Position=UDim2.new(x,0,y,0), Size=UDim2.new(0,w,0,1.5),
                    AnchorPoint=Vector2.new(0.5,0.5), Rotation=rot},
                    {Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})
            end
            line(0.32,0.65,10,-60); line(0.68,0.65,10,60); line(0.5,0.95,12,0)
            Utility:Create("Frame",{Parent=box, BackgroundColor3=color, BorderSizePixel=0,
                Position=UDim2.new(0.5,0,0.55,0), Size=UDim2.new(0,1.5,0,4),
                AnchorPoint=Vector2.new(0.5,0.5)},
                {Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})
            Utility:Create("Frame",{Parent=box, BackgroundColor3=color, BorderSizePixel=0,
                Position=UDim2.new(0.5,0,0.82,0), Size=UDim2.new(0,1.5,0,1.5),
                AnchorPoint=Vector2.new(0.5,0.5)},
                {Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})
        elseif kind == "Error" then
            ring()
            Utility:Create("Frame",{Parent=box, BackgroundColor3=color, BorderSizePixel=0,
                Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.new(0,7,0,1.5),
                AnchorPoint=Vector2.new(0.5,0.5), Rotation=45},
                {Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})
            Utility:Create("Frame",{Parent=box, BackgroundColor3=color, BorderSizePixel=0,
                Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.new(0,7,0,1.5),
                AnchorPoint=Vector2.new(0.5,0.5), Rotation=-45},
                {Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})
        end
    end

    local function GetNotifHolder()
        local existing = ScreenGui:FindFirstChild("NotificationHolder")
        if existing then return existing end
        local pos    = (NotifConfig.Position == "Top") and UDim2.new(1,-20,0,20) or UDim2.new(1,-20,1,-20)
        local anchor = (NotifConfig.Position == "Top") and Vector2.new(1,0) or Vector2.new(1,1)
        local vAlign = (NotifConfig.Position == "Top") and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
        return Utility:Create("Frame",{
            Name="NotificationHolder", Parent=ScreenGui, BackgroundTransparency=1,
            Position=pos, Size=UDim2.new(0,NotifConfig.Width,1,-40),
            AnchorPoint=anchor, ZIndex=50
        },{
            Utility:Create("UIListLayout",{
                SortOrder=Enum.SortOrder.LayoutOrder,
                VerticalAlignment=vAlign,
                HorizontalAlignment=Enum.HorizontalAlignment.Right,
                Padding=UDim.new(0,NotifConfig.Spacing)
            })
        })
    end

    local function ComputeMaxNotifs()
        local screen = ScreenGui.AbsoluteSize
        local available = screen.Y - 80
        return math.max(1, math.floor(available / (70 + NotifConfig.Spacing)))
    end

    local ShowNotification
    local function PopQueue()
        if #NotifQueue == 0 then return end
        local max = ComputeMaxNotifs()
        if #NotifActive >= max then return end
        ShowNotification(table.remove(NotifQueue, 1))
    end

    ShowNotification = function(opts)
        local title    = opts.Title or "Notification"
        local content  = opts.Content or ""
        local duration = opts.Duration or 5
        local nType    = opts.Type or "Info"
        local typeColors = {Info=theme.Accent, Success=theme.Success, Warning=theme.Warning, Error=theme.Error}
        local accent = typeColors[nType] or theme.Accent
        local Holder = GetNotifHolder()

        local NF = Utility:Create("Frame",{
            Name="Notification", Parent=Holder,
            BackgroundColor3=theme.Container,
            BackgroundTransparency=theme.ContainerTransparency-0.1,
            Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
            Position=UDim2.new(1,40,0,0), ClipsDescendants=true, BorderSizePixel=0
        },{
            Utility:Create("UICorner",{CornerRadius=UDim.new(0,10)}),
            Utility:Create("UIStroke",{Name="NStroke",Color=theme.Border,Transparency=theme.BorderTransparency+0.1,Thickness=1}),
            Utility:Create("UIGradient",{
                Color=ColorSequence.new({
                    ColorSequenceKeypoint.new(0, theme.GradientStart),
                    ColorSequenceKeypoint.new(1, theme.GradientEnd)
                }),
                Rotation=135, Transparency=NumberSequence.new(0.45)
            }),
            Utility:Create("UIPadding",{
                PaddingTop=UDim.new(0,10), PaddingBottom=UDim.new(0,10),
                PaddingLeft=UDim.new(0,12), PaddingRight=UDim.new(0,12)
            })
        })
        table.insert(NotifActive, NF)

        local Inner = Utility:Create("Frame",{
            Parent=NF, BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y
        },{
            Utility:Create("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4)})
        })

        local Row = Utility:Create("Frame",{
            Parent=Inner, BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,18), LayoutOrder=1
        })
        local IconHolder = Utility:Create("Frame",{
            Parent=Row, BackgroundTransparency=1,
            Position=UDim2.new(0,0,0.5,0), Size=UDim2.new(0,16,0,16),
            AnchorPoint=Vector2.new(0,0.5)
        })
        DrawLucideIcon(IconHolder, nType, accent)

        Utility:Create("TextLabel",{
            Parent=Row, BackgroundTransparency=1,
            Position=UDim2.new(0,22,0,0), Size=UDim2.new(1,-44,1,0),
            Font=Enum.Font.GothamBold, Text=title,
            TextColor3=theme.Text, TextSize=13,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextTruncate=Enum.TextTruncate.AtEnd
        })

        local CloseBtn = Utility:Create("TextButton",{
            Parent=Row, BackgroundTransparency=1,
            Position=UDim2.new(1,-16,0.5,0), Size=UDim2.new(0,16,0,16),
            AnchorPoint=Vector2.new(0,0.5),
            Font=Enum.Font.Gotham, Text="", AutoButtonColor=false
        })
        Utility:Create("Frame",{Parent=CloseBtn, BackgroundColor3=theme.TextMuted, BorderSizePixel=0,
            Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.new(0,9,0,1.2),
            AnchorPoint=Vector2.new(0.5,0.5), Rotation=45},
            {Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})
        Utility:Create("Frame",{Parent=CloseBtn, BackgroundColor3=theme.TextMuted, BorderSizePixel=0,
            Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.new(0,9,0,1.2),
            AnchorPoint=Vector2.new(0.5,0.5), Rotation=-45},
            {Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})

        CloseBtn.MouseEnter:Connect(function()
            for _, f in ipairs(CloseBtn:GetChildren()) do
                if f:IsA("Frame") then
                    Utility:Tween(f,{BackgroundColor3=theme.Text},Config.AnimationSpeed*0.4)
                end
            end
        end)
        CloseBtn.MouseLeave:Connect(function()
            for _, f in ipairs(CloseBtn:GetChildren()) do
                if f:IsA("Frame") then
                    Utility:Tween(f,{BackgroundColor3=theme.TextMuted},Config.AnimationSpeed*0.4)
                end
            end
        end)

        if content and #content > 0 then
            Utility:Create("TextLabel",{
                Parent=Inner, BackgroundTransparency=1,
                Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
                Font=Enum.Font.Gotham, Text=content,
                TextColor3=theme.TextDark, TextSize=12,
                TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true,
                LayoutOrder=2
            })
        end

        local PC = Utility:Create("Frame",{
            Parent=Inner, BackgroundColor3=theme.Element, BackgroundTransparency=0.6,
            Size=UDim2.new(1,0,0,1.5), LayoutOrder=3, BorderSizePixel=0
        },{ Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)}) })
        local PFill = Utility:Create("Frame",{
            Parent=PC, BackgroundColor3=accent, Size=UDim2.new(1,0,1,0), BorderSizePixel=0
        },{ Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)}) })

        Utility:Tween(NF, {Position=UDim2.new(0,0,0,0)}, Config.AnimationSpeed*1.0, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        Utility:Tween(PFill,{Size=UDim2.new(0,0,1,0)},duration,Enum.EasingStyle.Linear)

        local closed = false
        local function CloseN()
            if closed then return end
            closed = true
            local fd = Config.AnimationSpeed * 1.0
            local ti = TweenInfo.new(fd, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
            TweenService:Create(NF, ti, {Position=UDim2.new(1,40,0,0), BackgroundTransparency=1}):Play()
            for _, d in ipairs(NF:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    TweenService:Create(d, ti, {TextTransparency=1}):Play()
                elseif d:IsA("UIStroke") then
                    TweenService:Create(d, ti, {Transparency=1}):Play()
                elseif d:IsA("Frame") then
                    TweenService:Create(d, ti, {BackgroundTransparency=1}):Play()
                end
            end
            task.wait(fd + 0.05)
            for i, x in ipairs(NotifActive) do
                if x == NF then table.remove(NotifActive, i); break end
            end
            if NF then NF:Destroy() end
            PopQueue()
        end

        CloseBtn.MouseButton1Click:Connect(CloseN)
        task.delay(duration, function()
            if NF and NF.Parent then CloseN() end
        end)
    end

    function Window:Notify(opts)
        opts = opts or {}
        local max = ComputeMaxNotifs()
        if #NotifActive >= max then
            table.insert(NotifQueue, opts)
            return
        end
        ShowNotification(opts)
    end

    -- REEL helpers
    local function RecalculateReel(animateTo)
        local count = #Window.Tabs
        if count == 0 then return end
        local viewportH = MainContent.AbsoluteSize.Y
        if viewportH <= 0 then viewportH = WIN_H - 95 end
        Reel.Size = UDim2.new(1, 0, 0, viewportH * count)
        for i,tab in ipairs(Window.Tabs) do
            tab.Page.Position = UDim2.new(0, 0, 0, (i-1) * viewportH)
            tab.Page.Size     = UDim2.new(1, 0, 0, viewportH)
        end
        if animateTo then
            local idx = 0
            for i,t in ipairs(Window.Tabs) do if t==animateTo then idx=i break end end
            if idx>0 then
                Reel.Position = UDim2.new(0, 0, 0, -(idx-1)*viewportH)
            end
        end
    end

    MainContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if Window.CurrentTab then
            RecalculateReel(Window.CurrentTab)
        end
    end)

-- >>> END OF PART 2 — continue with PART 3 below <<<
-- >>> PART 3 OF 3 — paste this directly after PART 2 to finish the file <<<

    function Window:CreateTab(tabOpts)
        tabOpts = tabOpts or {}
        local tabName = tabOpts.Name or "Tab"
        local tabIcon = tabOpts.Icon or "📁"

        local Tab = {Name=tabName, Sections={}}

        local TabButton = Utility:Create("TextButton",{
            Name=tabName, Parent=TabList,
            BackgroundColor3=theme.Element, BackgroundTransparency=theme.ElementTransparency,
            Size=UDim2.new(1,0,0,40), Text="", AutoButtonColor=false
        },{
            Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius)}),
            Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency+0.3,Thickness=1})
        })
        local TabIcon = Utility:Create("TextLabel",{Name="Icon",Parent=TabButton,BackgroundTransparency=1,Position=UDim2.new(0,10,0,0),Size=UDim2.new(0,25,1,0),Font=Enum.Font.Gotham,Text=tabIcon,TextColor3=theme.TextDark,TextSize=16})
        local TabLabel = Utility:Create("TextLabel",{Name="Label",Parent=TabButton,BackgroundTransparency=1,Position=UDim2.new(0,38,0,0),Size=UDim2.new(1,-48,1,0),Font=Enum.Font.GothamSemibold,Text=tabName,TextColor3=theme.TextDark,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
        local TabIndicator = Utility:Create("Frame",{Name="Indicator",Parent=TabButton,BackgroundColor3=theme.Accent,BackgroundTransparency=1,Position=UDim2.new(1,-4,0.2,0),Size=UDim2.new(0,3,0.6,0)},{Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})

        local Page = Utility:Create("Frame",{
            Name=tabName.."Page", Parent=Reel,
            BackgroundTransparency=1,
            Size=UDim2.new(1,0,1,0),
            Position=UDim2.new(0,0,0,0),
            ClipsDescendants=true
        })

        local TabContent = Utility:Create("ScrollingFrame",{
            Name=tabName.."Content", Parent=Page,
            BackgroundTransparency=1,
            Position=UDim2.new(0,18,0,15), Size=UDim2.new(1,-36,1,-30),
            ScrollBarThickness=4, ScrollBarImageColor3=theme.Accent, ScrollBarImageTransparency=0.3,
            CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
            ClipsDescendants=true, BorderSizePixel=0
        },{
            Utility:Create("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,10)}),
            Utility:Create("UIPadding",{PaddingLeft=UDim.new(0,2), PaddingRight=UDim.new(0,6)})
        })

        Tab.Button    = TabButton
        Tab.Icon      = TabIcon
        Tab.Label     = TabLabel
        Tab.Indicator = TabIndicator
        Tab.Page      = Page
        Tab.Content   = TabContent

        table.insert(Window.Tabs, Tab)
        RecalculateReel()

        local function SelectTab()
            if Window.CurrentTab == Tab then return end
            local oldTab = Window.CurrentTab
            Window.CurrentTab = Tab
            if oldTab then
                Utility:Tween(oldTab.Button,{BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency},Config.AnimationSpeed)
                Utility:Tween(oldTab.Label,{TextColor3=theme.TextDark},Config.AnimationSpeed)
                Utility:Tween(oldTab.Icon,{TextColor3=theme.TextDark},Config.AnimationSpeed)
                Utility:Tween(oldTab.Indicator,{BackgroundTransparency=1},Config.AnimationSpeed)
            end
            Utility:Tween(TabButton,{BackgroundColor3=theme.Accent,BackgroundTransparency=0},Config.AnimationSpeed)
            Utility:Tween(TabLabel,{TextColor3=theme.Text},Config.AnimationSpeed)
            Utility:Tween(TabIcon,{TextColor3=theme.Text},Config.AnimationSpeed)
            Utility:Tween(TabIndicator,{BackgroundTransparency=0},Config.AnimationSpeed)

            local idx = 0
            for i,t in ipairs(Window.Tabs) do if t==Tab then idx=i break end end
            local viewportH = MainContent.AbsoluteSize.Y
            local targetY   = -(idx-1) * viewportH

            Utility:Tween(Reel, {Position = UDim2.new(0,0,0,targetY)},
                Config.TabSwitchSpeed, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            Utility:Ripple(TabButton, theme, Config)
        end

        TabButton.MouseEnter:Connect(function()
            if Window.CurrentTab ~= Tab then
                Utility:Tween(TabButton,{BackgroundColor3=theme.ElementHover,BackgroundTransparency=theme.ElementTransparency-0.1},Config.AnimationSpeed*0.5)
            end
        end)
        TabButton.MouseLeave:Connect(function()
            if Window.CurrentTab ~= Tab then
                Utility:Tween(TabButton,{BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency},Config.AnimationSpeed*0.5)
            end
        end)
        TabButton.MouseButton1Click:Connect(SelectTab)

        if #Window.Tabs == 1 then
            Window.CurrentTab = Tab
            TabButton.BackgroundColor3 = theme.Accent
            TabButton.BackgroundTransparency = 0
            TabLabel.TextColor3 = theme.Text
            TabIcon.TextColor3  = theme.Text
            TabIndicator.BackgroundTransparency = 0
            Reel.Position = UDim2.new(0,0,0,0)
        end

        function Tab:CreateSection(sectionName)
            local Section = {Name=sectionName}
            local SectionFrame = Utility:Create("Frame",{
                Name=sectionName or "Section", Parent=TabContent, BackgroundTransparency=1,
                Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y
            },{ Utility:Create("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8)}) })

            if sectionName then
                local SH = Utility:Create("Frame",{Parent=SectionFrame,BackgroundTransparency=1,Size=UDim2.new(1,0,0,28)})
                Utility:Create("TextLabel",{Parent=SH,BackgroundTransparency=1,Position=UDim2.new(0,5,0,0),Size=UDim2.new(1,-10,1,0),Font=Enum.Font.GothamBold,Text=sectionName:upper(),TextColor3=theme.TextMuted,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left})
                Utility:Create("Frame",{Name="Line",Parent=SH,BackgroundColor3=theme.Border,BackgroundTransparency=theme.BorderTransparency,Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1)})
            end
            table.insert(Tab.Sections, Section)

            function Section:CreateButton(opts)
                opts = opts or {}
                local name = opts.Name or "Button"
                local callback = opts.Callback or function() end
                local Frame = Utility:Create("Frame",{Name=name.."Button",Parent=SectionFrame,BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency,Size=UDim2.new(1,0,0,42)},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius)}),Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency+0.2,Thickness=1})})
                local Label = Utility:Create("TextLabel",{Name="Label",Parent=Frame,BackgroundTransparency=1,Position=UDim2.new(0,15,0,0),Size=UDim2.new(1,-60,1,0),Font=Enum.Font.GothamSemibold,Text=name,TextColor3=theme.Text,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left})
                local Icon = Utility:Create("TextLabel",{Name="Icon",Parent=Frame,BackgroundTransparency=1,Position=UDim2.new(1,-40,0,0),Size=UDim2.new(0,30,1,0),Font=Enum.Font.GothamBold,Text="→",TextColor3=theme.Accent,TextSize=16})
                local Click = Utility:Create("TextButton",{Parent=Frame,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Text="",AutoButtonColor=false})
                table.insert(Window.ElementRefs,{Type="Button",Frame=Frame,Label=Label,Icon=Icon})
                Click.MouseEnter:Connect(function()
                    Utility:Tween(Frame,{BackgroundColor3=theme.ElementHover,BackgroundTransparency=theme.ElementTransparency-0.1},Config.AnimationSpeed*0.5)
                    Utility:Tween(Icon,{Position=UDim2.new(1,-35,0,0)},Config.AnimationSpeed*0.5)
                end)
                Click.MouseLeave:Connect(function()
                    Utility:Tween(Frame,{BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency},Config.AnimationSpeed*0.5)
                    Utility:Tween(Icon,{Position=UDim2.new(1,-40,0,0)},Config.AnimationSpeed*0.5)
                end)
                Click.MouseButton1Click:Connect(function()
                    Utility:Ripple(Click,theme,Config)
                    Utility:Tween(Frame,{Size=UDim2.new(1,-4,0,40)},Config.AnimationSpeed*0.3)
                    task.wait(Config.AnimationSpeed*0.3)
                    Utility:Tween(Frame,{Size=UDim2.new(1,0,0,42)},Config.AnimationSpeed*0.3)
                    callback()
                end)
                return {SetText=function(_,t) Label.Text=t end}
            end

            function Section:CreateToggle(opts)
                opts = opts or {}
                local name=opts.Name or "Toggle"
                local id=opts.Flag or name
                local default=opts.CurrentValue or false
                local callback=opts.Callback or function() end
                if Window.ConfigData.Elements and Window.ConfigData.Elements[id]~=nil then default=Window.ConfigData.Elements[id] end
                local Toggle = {Value=default}
                Window.Elements[id]=Toggle
                local Frame = Utility:Create("Frame",{Name=name.."Toggle",Parent=SectionFrame,BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency,Size=UDim2.new(1,0,0,42)},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius)}),Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency+0.2,Thickness=1})})
                local Label = Utility:Create("TextLabel",{Name="Label",Parent=Frame,BackgroundTransparency=1,Position=UDim2.new(0,15,0,0),Size=UDim2.new(1,-70,1,0),Font=Enum.Font.GothamSemibold,Text=name,TextColor3=theme.Text,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left})
                local Switch = Utility:Create("Frame",{Name="Switch",Parent=Frame,BackgroundColor3=default and theme.Accent or theme.Element,BackgroundTransparency=default and 0 or theme.ElementTransparency-0.1,Position=UDim2.new(1,-55,0.5,0),Size=UDim2.new(0,44,0,24),AnchorPoint=Vector2.new(0,0.5)},{Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)}),Utility:Create("UIStroke",{Name="SwitchStroke",Color=default and theme.Accent or theme.Border,Transparency=default and 0.3 or theme.BorderTransparency,Thickness=1})})
                local Circle = Utility:Create("Frame",{Name="Circle",Parent=Switch,BackgroundColor3=theme.Text,Position=default and UDim2.new(1,-22,0.5,0) or UDim2.new(0,4,0.5,0),Size=UDim2.new(0,18,0,18),AnchorPoint=Vector2.new(0,0.5)},{Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})
                local Click = Utility:Create("TextButton",{Parent=Frame,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Text="",AutoButtonColor=false})
                table.insert(Window.ElementRefs,{Type="Toggle",Element=Toggle,Frame=Frame,Label=Label,Switch=Switch,Circle=Circle})
                local function Update(anim)
                    local d = anim and Config.AnimationSpeed or 0
                    local t = Window.Theme
                    if Toggle.Value then
                        Utility:Tween(Switch,{BackgroundColor3=t.Accent,BackgroundTransparency=0},d)
                        Utility:Tween(Circle,{Position=UDim2.new(1,-22,0.5,0)},d,Enum.EasingStyle.Quint)
                        Utility:Tween(Switch:FindFirstChild("SwitchStroke"),{Color=t.Accent,Transparency=0.3},d)
                    else
                        Utility:Tween(Switch,{BackgroundColor3=t.Element,BackgroundTransparency=t.ElementTransparency-0.1},d)
                        Utility:Tween(Circle,{Position=UDim2.new(0,4,0.5,0)},d,Enum.EasingStyle.Quint)
                        Utility:Tween(Switch:FindFirstChild("SwitchStroke"),{Color=t.Border,Transparency=t.BorderTransparency},d)
                    end
                end
                Click.MouseEnter:Connect(function() Utility:Tween(Frame,{BackgroundColor3=theme.ElementHover,BackgroundTransparency=theme.ElementTransparency-0.1},Config.AnimationSpeed*0.5) end)
                Click.MouseLeave:Connect(function() Utility:Tween(Frame,{BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency},Config.AnimationSpeed*0.5) end)
                Click.MouseButton1Click:Connect(function()
                    Toggle.Value = not Toggle.Value
                    Update(true); Utility:Ripple(Click,theme,Config); SaveConfig(); callback(Toggle.Value)
                end)
                function Toggle:Set(v, skip) Toggle.Value=v; Update(true); SaveConfig(); if not skip then callback(v) end end
                if default then callback(default) end
                return Toggle
            end

            function Section:CreateSlider(opts)
                opts = opts or {}
                local name=opts.Name or "Slider"
                local id=opts.Flag or name
                local min=opts.Range and opts.Range[1] or 0
                local max=opts.Range and opts.Range[2] or 100
                local inc=opts.Increment or 1
                local default=opts.CurrentValue or min
                local suffix=opts.Suffix or ""
                local callback=opts.Callback or function() end
                if Window.ConfigData.Elements and Window.ConfigData.Elements[id]~=nil then default=Window.ConfigData.Elements[id] end
                local Slider={Value=default}; Window.Elements[id]=Slider
                local Frame=Utility:Create("Frame",{Name=name.."Slider",Parent=SectionFrame,BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency,Size=UDim2.new(1,0,0,58)},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius)}),Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency+0.2,Thickness=1})})
                local Label=Utility:Create("TextLabel",{Name="Label",Parent=Frame,BackgroundTransparency=1,Position=UDim2.new(0,15,0,8),Size=UDim2.new(0.6,0,0,18),Font=Enum.Font.GothamSemibold,Text=name,TextColor3=theme.Text,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left})
                local ValueLabel=Utility:Create("TextLabel",{Name="Value",Parent=Frame,BackgroundTransparency=1,Position=UDim2.new(0.6,0,0,8),Size=UDim2.new(0.4,-15,0,18),Font=Enum.Font.GothamBold,Text=tostring(default)..suffix,TextColor3=theme.Accent,TextSize=14,TextXAlignment=Enum.TextXAlignment.Right})
                local BarBg=Utility:Create("Frame",{Name="BarBg",Parent=Frame,BackgroundColor3=theme.Container,BackgroundTransparency=theme.ContainerTransparency-0.1,Position=UDim2.new(0,15,0,36),Size=UDim2.new(1,-30,0,10)},{Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)})})
                local fp=(default-min)/(max-min)
                local Fill=Utility:Create("Frame",{Name="Fill",Parent=BarBg,BackgroundColor3=theme.Accent,Size=UDim2.new(fp,0,1,0)},{Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)}),Utility:Create("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,theme.Accent),ColorSequenceKeypoint.new(1,theme.AccentGlow)}),Rotation=0})})
                local Knob=Utility:Create("Frame",{Name="Knob",Parent=BarBg,BackgroundColor3=theme.Text,Position=UDim2.new(fp,0,0.5,0),Size=UDim2.new(0,18,0,18),AnchorPoint=Vector2.new(0.5,0.5),ZIndex=5},{Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)}),Utility:Create("UIStroke",{Color=theme.Accent,Thickness=2})})
                local Input=Utility:Create("TextButton",{Parent=BarBg,BackgroundTransparency=1,Size=UDim2.new(1,0,1,20),Position=UDim2.new(0,0,0,-10),Text="",AutoButtonColor=false})
                table.insert(Window.ElementRefs,{Type="Slider",Element=Slider,Frame=Frame,Label=Label,ValueLabel=ValueLabel,BarBg=BarBg,Fill=Fill,Knob=Knob})
                local dragging=false
                local function Upd(input, anim)
                    local p=math.clamp((input.Position.X-BarBg.AbsolutePosition.X)/BarBg.AbsoluteSize.X,0,1)
                    local v=math.floor((min+(max-min)*p)/inc+0.5)*inc
                    v=math.clamp(v,min,max)
                    Slider.Value=v
                    local fpos=(v-min)/(max-min)
                    local d = anim and Config.AnimationSpeed*0.5 or 0
                    ValueLabel.Text=tostring(v)..suffix
                    Utility:Tween(Fill,{Size=UDim2.new(fpos,0,1,0)},d)
                    Utility:Tween(Knob,{Position=UDim2.new(fpos,0,0.5,0)},d)
                    SaveConfig(); callback(v)
                end
                Input.MouseButton1Down:Connect(function() dragging=true; Utility:Tween(Knob,{Size=UDim2.new(0,22,0,22)},Config.AnimationSpeed*0.3) end)
                table.insert(Window.Connections, UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType==Enum.UserInputType.MouseButton1 and dragging then dragging=false; Utility:Tween(Knob,{Size=UDim2.new(0,18,0,18)},Config.AnimationSpeed*0.3) end
                end))
                table.insert(Window.Connections, UserInputService.InputChanged:Connect(function(input)
                    if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then Upd(input,false) end
                end))
                Input.MouseButton1Click:Connect(function() Upd({Position=Vector3.new(Mouse.X,Mouse.Y,0)},true); Utility:Ripple(Input,theme,Config) end)
                function Slider:Set(v, skip)
                    v=math.clamp(v,min,max); Slider.Value=v
                    local fpos=(v-min)/(max-min)
                    ValueLabel.Text=tostring(v)..suffix; Fill.Size=UDim2.new(fpos,0,1,0); Knob.Position=UDim2.new(fpos,0,0.5,0)
                    SaveConfig(); if not skip then callback(v) end
                end
                callback(default); return Slider
            end

            function Section:CreateDropdown(opts)
                opts = opts or {}
                local name=opts.Name or "Dropdown"
                local id=opts.Flag or name
                local options=opts.Options or {}
                local default=opts.CurrentOption or (options[1] or "")
                local multi=opts.MultiSelect or false
                local callback=opts.Callback or function() end
                if Window.ConfigData.Elements and Window.ConfigData.Elements[id]~=nil then default=Window.ConfigData.Elements[id] end
                local Dropdown={Value = multi and (type(default)=="table" and default or {default}) or default, Open=false, Options=options}
                Window.Elements[id]=Dropdown
                local Frame=Utility:Create("Frame",{Name=name.."Dropdown",Parent=SectionFrame,BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency,Size=UDim2.new(1,0,0,42),ClipsDescendants=true},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius)}),Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency+0.2,Thickness=1})})
                local Header=Utility:Create("TextButton",{Name="Header",Parent=Frame,BackgroundTransparency=1,Size=UDim2.new(1,0,0,42),Text="",AutoButtonColor=false})
                local Label=Utility:Create("TextLabel",{Name="Label",Parent=Header,BackgroundTransparency=1,Position=UDim2.new(0,15,0,0),Size=UDim2.new(0.5,-15,1,0),Font=Enum.Font.GothamSemibold,Text=name,TextColor3=theme.Text,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left})
                local function disp()
                    if multi then
                        if #Dropdown.Value==0 then return "None"
                        elseif #Dropdown.Value==1 then return Dropdown.Value[1]
                        else return #Dropdown.Value.." selected" end
                    else return Dropdown.Value or "Select..." end
                end
                local Selected=Utility:Create("TextLabel",{Name="Selected",Parent=Header,BackgroundTransparency=1,Position=UDim2.new(0.5,0,0,0),Size=UDim2.new(0.5,-45,1,0),Font=Enum.Font.Gotham,Text=disp(),TextColor3=theme.TextDark,TextSize=13,TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd})
                local Arrow=Utility:Create("TextLabel",{Name="Arrow",Parent=Header,BackgroundTransparency=1,Position=UDim2.new(1,-35,0,0),Size=UDim2.new(0,25,1,0),Font=Enum.Font.GothamBold,Text="v",TextColor3=theme.TextDark,TextSize=12,Rotation=0})
                local OC=Utility:Create("Frame",{Name="Options",Parent=Frame,BackgroundTransparency=1,Position=UDim2.new(0,8,0,48),Size=UDim2.new(1,-16,0,0),AutomaticSize=Enum.AutomaticSize.Y},{Utility:Create("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)})})
                table.insert(Window.ElementRefs,{Type="Dropdown",Element=Dropdown,Frame=Frame,Label=Label,Selected=Selected,Arrow=Arrow,OptionsContainer=OC})
                local function CreateOpt(optName)
                    local sel = multi and table.find(Dropdown.Value,optName) or Dropdown.Value==optName
                    local OB=Utility:Create("TextButton",{Name=optName,Parent=OC,BackgroundColor3=sel and theme.Accent or theme.Container,BackgroundTransparency=sel and 0 or theme.ContainerTransparency,Size=UDim2.new(1,0,0,32),Font=Enum.Font.Gotham,Text=optName,TextColor3=sel and theme.Text or theme.TextDark,TextSize=13,AutoButtonColor=false},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius-2)})})
                    OB.MouseEnter:Connect(function()
                        local s = multi and table.find(Dropdown.Value,optName) or Dropdown.Value==optName
                        if not s then Utility:Tween(OB,{BackgroundColor3=theme.AccentDark,BackgroundTransparency=0.5,TextColor3=theme.Text},Config.AnimationSpeed*0.5) end
                    end)
                    OB.MouseLeave:Connect(function()
                        local s = multi and table.find(Dropdown.Value,optName) or Dropdown.Value==optName
                        local t=Window.Theme
                        Utility:Tween(OB,{BackgroundColor3=s and t.Accent or t.Container,BackgroundTransparency=s and 0 or t.ContainerTransparency,TextColor3=s and t.Text or t.TextDark},Config.AnimationSpeed*0.5)
                    end)
                    OB.MouseButton1Click:Connect(function()
                        Utility:Ripple(OB,theme,Config)
                        local t=Window.Theme
                        if multi then
                            local idx=table.find(Dropdown.Value,optName)
                            if idx then table.remove(Dropdown.Value,idx); Utility:Tween(OB,{BackgroundColor3=t.Container,BackgroundTransparency=t.ContainerTransparency,TextColor3=t.TextDark},Config.AnimationSpeed)
                            else table.insert(Dropdown.Value,optName); Utility:Tween(OB,{BackgroundColor3=t.Accent,BackgroundTransparency=0,TextColor3=t.Text},Config.AnimationSpeed) end
                            Selected.Text=disp(); SaveConfig(); callback(Dropdown.Value)
                        else
                            Dropdown.Value=optName; Selected.Text=optName
                            for _,opt in pairs(OC:GetChildren()) do
                                if opt:IsA("TextButton") then
                                    local t2 = opt.Name==optName
                                    Utility:Tween(opt,{BackgroundColor3=t2 and t.Accent or t.Container,BackgroundTransparency=t2 and 0 or t.ContainerTransparency,TextColor3=t2 and t.Text or t.TextDark},Config.AnimationSpeed)
                                end
                            end
                            SaveConfig(); callback(optName)
                            task.wait(Config.AnimationSpeed*0.3)
                            Dropdown.Open=false
                            Utility:Tween(Frame,{Size=UDim2.new(1,0,0,42)},Config.AnimationSpeed)
                            Utility:Tween(Arrow,{Rotation=0},Config.AnimationSpeed)
                        end
                    end)
                    return OB
                end
                for _,o in pairs(options) do CreateOpt(o) end
                Header.MouseEnter:Connect(function() Utility:Tween(Frame,{BackgroundColor3=theme.ElementHover,BackgroundTransparency=theme.ElementTransparency-0.1},Config.AnimationSpeed*0.5) end)
                Header.MouseLeave:Connect(function() Utility:Tween(Frame,{BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency},Config.AnimationSpeed*0.5) end)
                Header.MouseButton1Click:Connect(function()
                    Dropdown.Open=not Dropdown.Open
                    Utility:Ripple(Header,theme,Config)
                    local oc=#options
                    local th = Dropdown.Open and math.min(42+8+oc*36,250) or 42
                    Utility:Tween(Frame,{Size=UDim2.new(1,0,0,th)},Config.AnimationSpeed)
                    Utility:Tween(Arrow,{Rotation=Dropdown.Open and 180 or 0},Config.AnimationSpeed)
                end)
                function Dropdown:Set(v, skip)
                    local t=Window.Theme
                    if multi then
                        Dropdown.Value = type(v)=="table" and v or {v}
                        for _,opt in pairs(OC:GetChildren()) do
                            if opt:IsA("TextButton") then
                                local s=table.find(Dropdown.Value,opt.Name)
                                opt.BackgroundColor3=s and t.Accent or t.Container
                                opt.BackgroundTransparency=s and 0 or t.ContainerTransparency
                                opt.TextColor3=s and t.Text or t.TextDark
                            end
                        end
                    else
                        Dropdown.Value=v
                        for _,opt in pairs(OC:GetChildren()) do
                            if opt:IsA("TextButton") then
                                local s=opt.Name==v
                                opt.BackgroundColor3=s and t.Accent or t.Container
                                opt.BackgroundTransparency=s and 0 or t.ContainerTransparency
                                opt.TextColor3=s and t.Text or t.TextDark
                            end
                        end
                    end
                    Selected.Text=disp(); SaveConfig(); if not skip then callback(Dropdown.Value) end
                end
                function Dropdown:Refresh(newOpts, keep)
                    options=newOpts; Dropdown.Options=newOpts
                    for _,c in pairs(OC:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                    if not keep then Dropdown.Value = multi and {} or (newOpts[1] or "") end
                    for _,o in pairs(newOpts) do CreateOpt(o) end
                    Selected.Text=disp()
                    if Dropdown.Open then
                        local th=math.min(42+8+#newOpts*36,250)
                        Utility:Tween(Frame,{Size=UDim2.new(1,0,0,th)},Config.AnimationSpeed)
                    end
                end
                if default then callback(Dropdown.Value) end
                return Dropdown
            end

            function Section:CreateInput(opts)
                opts=opts or {}
                local name=opts.Name or "Input"
                local id=opts.Flag or name
                local ph=opts.PlaceholderText or "Enter text..."
                local default=opts.CurrentValue or ""
                local rmv=opts.RemoveTextAfterFocusLost or false
                local callback=opts.Callback or function() end
                if Window.ConfigData.Elements and Window.ConfigData.Elements[id]~=nil then default=Window.ConfigData.Elements[id] end
                local Input={Value=default}; Window.Elements[id]=Input
                local Frame=Utility:Create("Frame",{Name=name.."Input",Parent=SectionFrame,BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency,Size=UDim2.new(1,0,0,42)},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius)}),Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency+0.2,Thickness=1})})
                local Label=Utility:Create("TextLabel",{Name="Label",Parent=Frame,BackgroundTransparency=1,Position=UDim2.new(0,15,0,0),Size=UDim2.new(0.35,0,1,0),Font=Enum.Font.GothamSemibold,Text=name,TextColor3=theme.Text,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
                local Box=Utility:Create("Frame",{Name="BoxContainer",Parent=Frame,BackgroundColor3=theme.Container,BackgroundTransparency=theme.ContainerTransparency,Position=UDim2.new(0.35,5,0.15,0),Size=UDim2.new(0.65,-20,0.7,0)},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius-2)}),Utility:Create("UIStroke",{Name="BoxStroke",Color=theme.Border,Transparency=theme.BorderTransparency,Thickness=1})})
                local TB=Utility:Create("TextBox",{Name="TextBox",Parent=Box,BackgroundTransparency=1,Position=UDim2.new(0,10,0,0),Size=UDim2.new(1,-20,1,0),Font=Enum.Font.Gotham,PlaceholderText=ph,PlaceholderColor3=theme.TextMuted,Text=default,TextColor3=theme.Text,TextSize=13,ClearTextOnFocus=false,ClipsDescendants=true})
                table.insert(Window.ElementRefs,{Type="Input",Element=Input,Frame=Frame,Label=Label,BoxContainer=Box,TextBox=TB})
                TB.Focused:Connect(function()
                    Utility:Tween(Box:FindFirstChild("BoxStroke"),{Color=theme.Accent,Transparency=0},Config.AnimationSpeed)
                    Utility:Tween(Frame,{BackgroundColor3=theme.ElementHover,BackgroundTransparency=theme.ElementTransparency-0.1},Config.AnimationSpeed)
                end)
                TB.FocusLost:Connect(function(enter)
                    Utility:Tween(Box:FindFirstChild("BoxStroke"),{Color=theme.Border,Transparency=theme.BorderTransparency},Config.AnimationSpeed)
                    Utility:Tween(Frame,{BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency},Config.AnimationSpeed)
                    Input.Value=TB.Text; SaveConfig()
                    if enter or not rmv then callback(TB.Text) end
                    if rmv then TB.Text=""; Input.Value="" end
                end)
                function Input:Set(t,skip) TB.Text=t; Input.Value=t; SaveConfig(); if not skip then callback(t) end end
                return Input
            end

            function Section:CreateKeybind(opts)
                opts=opts or {}
                local name=opts.Name or "Keybind"
                local id=opts.Flag or name
                local default=opts.CurrentKeybind or "None"
                local hold=opts.HoldToInteract or false
                local callback=opts.Callback or function() end
                if Window.ConfigData.Elements and Window.ConfigData.Elements[id]~=nil then default=Window.ConfigData.Elements[id] end
                local Keybind={Value = default~="None" and Enum.KeyCode[default] or nil, Listening=false}
                Window.Elements[id]={Value=default}
                local Frame=Utility:Create("Frame",{Name=name.."Keybind",Parent=SectionFrame,BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency,Size=UDim2.new(1,0,0,42)},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius)}),Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency+0.2,Thickness=1})})
                local Label=Utility:Create("TextLabel",{Name="Label",Parent=Frame,BackgroundTransparency=1,Position=UDim2.new(0,15,0,0),Size=UDim2.new(0.6,0,1,0),Font=Enum.Font.GothamSemibold,Text=name,TextColor3=theme.Text,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left})
                local KB=Utility:Create("TextButton",{Name="KeyButton",Parent=Frame,BackgroundColor3=theme.Container,BackgroundTransparency=theme.ContainerTransparency,Position=UDim2.new(1,-100,0.15,0),Size=UDim2.new(0,85,0.7,0),Font=Enum.Font.GothamBold,Text=default,TextColor3=theme.TextDark,TextSize=12,AutoButtonColor=false},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius-2)}),Utility:Create("UIStroke",{Name="ButtonStroke",Color=theme.Border,Transparency=theme.BorderTransparency,Thickness=1})})
                table.insert(Window.ElementRefs,{Type="Keybind",Element=Keybind,Frame=Frame,Label=Label,KeyButton=KB})
                KB.MouseEnter:Connect(function() if not Keybind.Listening then Utility:Tween(KB,{BackgroundTransparency=theme.ContainerTransparency-0.15},Config.AnimationSpeed*0.5) end end)
                KB.MouseLeave:Connect(function() if not Keybind.Listening then Utility:Tween(KB,{BackgroundTransparency=theme.ContainerTransparency},Config.AnimationSpeed*0.5) end end)
                KB.MouseButton1Click:Connect(function()
                    Keybind.Listening=true; KB.Text="..."
                    Utility:Tween(KB,{BackgroundColor3=theme.Accent,BackgroundTransparency=0},Config.AnimationSpeed)
                    Utility:Tween(KB:FindFirstChild("ButtonStroke"),{Color=theme.Accent,Transparency=0.3},Config.AnimationSpeed)
                    Utility:Ripple(KB,theme,Config)
                end)
                table.insert(Window.Connections, UserInputService.InputBegan:Connect(function(input, gpe)
                    if gpe then return end
                    if Keybind.Listening then
                        if input.UserInputType==Enum.UserInputType.Keyboard then
                            local kn=input.KeyCode.Name
                            if input.KeyCode==Enum.KeyCode.Escape then Keybind.Value=nil; kn="None" else Keybind.Value=input.KeyCode end
                            Keybind.Listening=false; KB.Text=kn; Window.Elements[id].Value=kn
                            Utility:Tween(KB,{BackgroundColor3=theme.Container,BackgroundTransparency=theme.ContainerTransparency},Config.AnimationSpeed)
                            Utility:Tween(KB:FindFirstChild("ButtonStroke"),{Color=theme.Border,Transparency=theme.BorderTransparency},Config.AnimationSpeed)
                            SaveConfig()
                        end
                    elseif Keybind.Value and input.KeyCode==Keybind.Value then
                        if hold then callback(true) else callback() end
                    end
                end))
                if hold then
                    table.insert(Window.Connections, UserInputService.InputEnded:Connect(function(input, gpe)
                        if gpe then return end
                        if Keybind.Value and input.KeyCode==Keybind.Value then callback(false) end
                    end))
                end
                function Keybind:Set(key, skip)
                    if type(key)=="string" then
                        if key=="None" then Keybind.Value=nil else Keybind.Value=Enum.KeyCode[key] end
                        KB.Text=key; Window.Elements[id].Value=key
                    else
                        Keybind.Value=key; KB.Text=key and key.Name or "None"; Window.Elements[id].Value=key and key.Name or "None"
                    end
                    SaveConfig()
                end
                return Keybind
            end

            function Section:CreateColorPicker(opts)
                opts=opts or {}
                local name=opts.Name or "Color Picker"
                local id=opts.Flag or name
                local default=opts.Color or Color3.fromRGB(255,255,255)
                local callback=opts.Callback or function() end
                if Window.ConfigData.Elements and Window.ConfigData.Elements[id]~=nil then
                    local s=Window.ConfigData.Elements[id]
                    if type(s)=="table" then default=Color3.fromRGB(s[1],s[2],s[3]) end
                end
                local CP={Value=default, Open=false}
                Window.Elements[id]={Value={math.floor(default.R*255),math.floor(default.G*255),math.floor(default.B*255)}}
                local h,s,v=default:ToHSV()
                local Frame=Utility:Create("Frame",{Name=name.."ColorPicker",Parent=SectionFrame,BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency,Size=UDim2.new(1,0,0,42),ClipsDescendants=true},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius)}),Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency+0.2,Thickness=1})})
                local Label=Utility:Create("TextLabel",{Name="Label",Parent=Frame,BackgroundTransparency=1,Position=UDim2.new(0,15,0,0),Size=UDim2.new(0.6,0,0,42),Font=Enum.Font.GothamSemibold,Text=name,TextColor3=theme.Text,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left})
                local Display=Utility:Create("TextButton",{Name="Display",Parent=Frame,BackgroundColor3=default,Position=UDim2.new(1,-55,0,9),Size=UDim2.new(0,40,0,24),Text="",AutoButtonColor=false},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius-2)}),Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency,Thickness=1})})
                local PC=Utility:Create("Frame",{Name="Picker",Parent=Frame,BackgroundTransparency=1,Position=UDim2.new(0,15,0,50),Size=UDim2.new(1,-30,0,130)})
                local SV=Utility:Create("ImageLabel",{Name="SatVal",Parent=PC,BackgroundColor3=Color3.fromHSV(h,1,1),Size=UDim2.new(1,-40,0,100),Image="rbxassetid://4155801252",ScaleType=Enum.ScaleType.Stretch},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius-2)})})
                local SVC=Utility:Create("Frame",{Name="Cursor",Parent=SV,BackgroundColor3=Color3.new(1,1,1),Position=UDim2.new(s,0,1-v,0),Size=UDim2.new(0,12,0,12),AnchorPoint=Vector2.new(0.5,0.5),ZIndex=5},{Utility:Create("UICorner",{CornerRadius=UDim.new(1,0)}),Utility:Create("UIStroke",{Color=Color3.new(0,0,0),Thickness=2})})
                local Hue=Utility:Create("Frame",{Name="Hue",Parent=PC,BackgroundColor3=Color3.new(1,1,1),Position=UDim2.new(1,-30,0,0),Size=UDim2.new(0,25,0,100)},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius-2)}),Utility:Create("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)),ColorSequenceKeypoint.new(0.167,Color3.fromRGB(255,255,0)),ColorSequenceKeypoint.new(0.333,Color3.fromRGB(0,255,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(0,255,255)),ColorSequenceKeypoint.new(0.667,Color3.fromRGB(0,0,255)),ColorSequenceKeypoint.new(0.833,Color3.fromRGB(255,0,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0))}),Rotation=90})})
                local HC=Utility:Create("Frame",{Name="Cursor",Parent=Hue,BackgroundColor3=Color3.new(1,1,1),Position=UDim2.new(0.5,0,h,0),Size=UDim2.new(1,6,0,8),AnchorPoint=Vector2.new(0.5,0.5),ZIndex=5},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,4)}),Utility:Create("UIStroke",{Color=Color3.new(0,0,0),Thickness=2})})
                local RGBL=Utility:Create("TextLabel",{Name="RGB",Parent=PC,BackgroundTransparency=1,Position=UDim2.new(0,0,0,108),Size=UDim2.new(1,0,0,20),Font=Enum.Font.Gotham,Text=string.format("RGB: %d, %d, %d",math.floor(default.R*255),math.floor(default.G*255),math.floor(default.B*255)),TextColor3=theme.TextDark,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left})
                table.insert(Window.ElementRefs,{Type="ColorPicker",Element=CP,Frame=Frame,Label=Label,Display=Display,RGBLabel=RGBL})
                local function UC()
                    local c=Color3.fromHSV(h,s,v)
                    CP.Value=c; Display.BackgroundColor3=c; SV.BackgroundColor3=Color3.fromHSV(h,1,1)
                    RGBL.Text=string.format("RGB: %d, %d, %d",math.floor(c.R*255),math.floor(c.G*255),math.floor(c.B*255))
                    Window.Elements[id].Value={math.floor(c.R*255),math.floor(c.G*255),math.floor(c.B*255)}
                    SaveConfig(); callback(c)
                end
                local dSV,dH=false,false
                local SVI=Utility:Create("TextButton",{Parent=SV,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Text="",AutoButtonColor=false})
                local function USV(input)
                    local rx=math.clamp((input.Position.X-SV.AbsolutePosition.X)/SV.AbsoluteSize.X,0,1)
                    local ry=math.clamp((input.Position.Y-SV.AbsolutePosition.Y)/SV.AbsoluteSize.Y,0,1)
                    s=rx; v=1-ry
                    Utility:Tween(SVC,{Position=UDim2.new(rx,0,ry,0)},Config.AnimationSpeed*0.3); UC()
                end
                SVI.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then dSV=true; USV(input) end end)
                local HI=Utility:Create("TextButton",{Parent=Hue,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Text="",AutoButtonColor=false})
                local function UH(input)
                    local ry=math.clamp((input.Position.Y-Hue.AbsolutePosition.Y)/Hue.AbsoluteSize.Y,0,1)
                    h=ry; Utility:Tween(HC,{Position=UDim2.new(0.5,0,ry,0)},Config.AnimationSpeed*0.3); UC()
                end
                HI.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then dH=true; UH(input) end end)
                table.insert(Window.Connections, UserInputService.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then dSV=false; dH=false end end))
                table.insert(Window.Connections, UserInputService.InputChanged:Connect(function(input)
                    if input.UserInputType==Enum.UserInputType.MouseMovement then
                        if dSV then USV(input) elseif dH then UH(input) end
                    end
                end))
                Display.MouseButton1Click:Connect(function()
                    CP.Open=not CP.Open; Utility:Ripple(Display,theme,Config)
                    Utility:Tween(Frame,{Size=UDim2.new(1,0,0,CP.Open and 190 or 42)},Config.AnimationSpeed)
                end)
                function CP:Set(color, skip)
                    h,s,v=color:ToHSV(); CP.Value=color; Display.BackgroundColor3=color
                    SV.BackgroundColor3=Color3.fromHSV(h,1,1); SVC.Position=UDim2.new(s,0,1-v,0); HC.Position=UDim2.new(0.5,0,h,0)
                    RGBL.Text=string.format("RGB: %d, %d, %d",math.floor(color.R*255),math.floor(color.G*255),math.floor(color.B*255))
                    Window.Elements[id].Value={math.floor(color.R*255),math.floor(color.G*255),math.floor(color.B*255)}
                    SaveConfig(); if not skip then callback(color) end
                end
                callback(default); return CP
            end

            function Section:CreateLabel(text)
                local Frame=Utility:Create("Frame",{Name="Label",Parent=SectionFrame,BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency+0.1,Size=UDim2.new(1,0,0,32)},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius)})})
                local Text=Utility:Create("TextLabel",{Name="Text",Parent=Frame,BackgroundTransparency=1,Position=UDim2.new(0,15,0,0),Size=UDim2.new(1,-30,1,0),Font=Enum.Font.Gotham,Text=text or "Label",TextColor3=theme.TextDark,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left})
                table.insert(Window.ElementRefs,{Type="Label",Frame=Frame,Text=Text})
                return {Set=function(_,t) Text.Text=t; Text.TextTransparency=0.5; Utility:Tween(Text,{TextTransparency=0},Config.AnimationSpeed) end}
            end

            function Section:CreateParagraph(opts)
                opts=opts or {}
                local title=opts.Title or "Paragraph"
                local content=opts.Content or "Content"
                local Frame=Utility:Create("Frame",{Name="Paragraph",Parent=SectionFrame,BackgroundColor3=theme.Element,BackgroundTransparency=theme.ElementTransparency,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius)}),Utility:Create("UIStroke",{Color=theme.Border,Transparency=theme.BorderTransparency+0.2,Thickness=1}),Utility:Create("UIPadding",{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,15),PaddingRight=UDim.new(0,15)})})
                local Title=Utility:Create("TextLabel",{Name="Title",Parent=Frame,BackgroundTransparency=1,Size=UDim2.new(1,0,0,20),Font=Enum.Font.GothamBold,Text=title,TextColor3=theme.Text,TextSize=15,TextXAlignment=Enum.TextXAlignment.Left})
                local Content=Utility:Create("TextLabel",{Name="Content",Parent=Frame,BackgroundTransparency=1,Position=UDim2.new(0,0,0,24),Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,Font=Enum.Font.Gotham,Text=content,TextColor3=theme.TextDark,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,RichText=true})
                table.insert(Window.ElementRefs,{Type="Paragraph",Frame=Frame,Title=Title,Content=Content})
                return {Set=function(_,nt,nc) if nt then Title.Text=nt end if nc then Content.Text=nc end Frame.BackgroundTransparency=theme.ElementTransparency+0.2; Utility:Tween(Frame,{BackgroundTransparency=theme.ElementTransparency},Config.AnimationSpeed) end}
            end

            function Section:CreateDivider()
                return Utility:Create("Frame",{Name="Divider",Parent=SectionFrame,BackgroundColor3=theme.Border,BackgroundTransparency=theme.BorderTransparency,Size=UDim2.new(1,0,0,1)})
            end

            return Section
        end

        return Tab
    end

    -- ============================================================
    -- Dialog (uniform fade, no text persisting)
    -- ============================================================
    function Window:Dialog(opts)
        opts = opts or {}
        local title=opts.Title or "Dialog"
        local content=opts.Content or ""
        local buttons=opts.Buttons or {}

        local Bg = Utility:Create("Frame",{
            Name="DialogBackground",Parent=ScreenGui,
            BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=1,
            Size=UDim2.new(1,0,1,0), ZIndex=100
        })

        local DF = Utility:Create("Frame",{
            Name="Dialog", Parent=Bg,
            BackgroundColor3=theme.Background, BackgroundTransparency=1,
            Position=UDim2.new(0.5,0,0.5,8),
            Size=UDim2.new(0,380,0,180),
            AnchorPoint=Vector2.new(0.5,0.5),
            ZIndex=101, ClipsDescendants=true
        },{
            Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.CornerRadius+4)}),
            Utility:Create("UIStroke",{Name="DStroke",Color=theme.Border,Transparency=1,Thickness=1.5}),
            Utility:Create("UIGradient",{
                Color=ColorSequence.new({ColorSequenceKeypoint.new(0,theme.GradientStart),ColorSequenceKeypoint.new(1,theme.GradientEnd)}),
                Rotation=135,Transparency=NumberSequence.new(0.2)
            })
        })

        local DTitle = Utility:Create("TextLabel",{Parent=DF,BackgroundTransparency=1,Position=UDim2.new(0,25,0,20),Size=UDim2.new(1,-50,0,25),Font=Enum.Font.GothamBold,Text=title,TextColor3=theme.Text,TextSize=18,TextTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=102})
        local DContent = Utility:Create("TextLabel",{Parent=DF,BackgroundTransparency=1,Position=UDim2.new(0,25,0,50),Size=UDim2.new(1,-50,0,60),Font=Enum.Font.Gotham,Text=content,TextColor3=theme.TextDark,TextSize=14,TextTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,ZIndex=102})
        local BC = Utility:Create("Frame",{Parent=DF,BackgroundTransparency=1,Position=UDim2.new(0,25,1,-60),Size=UDim2.new(1,-50,0,38),ZIndex=102},{Utility:Create("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,12)})})

        Utility:Tween(Bg,{BackgroundTransparency=0.5},Config.AnimationSpeed*1.2,Enum.EasingStyle.Quart)
        Utility:Tween(DF,{BackgroundTransparency=theme.BackgroundTransparency,Position=UDim2.new(0.5,0,0.5,0)},Config.AnimationSpeed*1.2,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
        Utility:Tween(DF:FindFirstChild("DStroke"),{Transparency=theme.BorderTransparency},Config.AnimationSpeed*1.2,Enum.EasingStyle.Quart)
        Utility:Tween(DTitle,{TextTransparency=0},Config.AnimationSpeed*1.4,Enum.EasingStyle.Quart)
        Utility:Tween(DContent,{TextTransparency=0},Config.AnimationSpeed*1.4,Enum.EasingStyle.Quart)
        if Blur then Utility:Tween(Blur,{Size=15},Config.AnimationSpeed*1.2,Enum.EasingStyle.Quart) end

        local closed = false
        local function CloseDialog()
            if closed then return end
            closed = true
            local fadeDur = Config.AnimationSpeed * 1.1
            local ti = TweenInfo.new(fadeDur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            TweenService:Create(Bg, ti, {BackgroundTransparency=1}):Play()
            TweenService:Create(DF, ti, {BackgroundTransparency=1}):Play()
            for _, d in ipairs(DF:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    TweenService:Create(d, ti, {TextTransparency=1}):Play()
                    if d:IsA("TextButton") then
                        TweenService:Create(d, ti, {BackgroundTransparency=1}):Play()
                    end
                elseif d:IsA("UIStroke") then
                    TweenService:Create(d, ti, {Transparency=1}):Play()
                elseif d:IsA("Frame") and d ~= DF then
                    TweenService:Create(d, ti, {BackgroundTransparency=1}):Play()
                end
            end
            if Blur then
                TweenService:Create(Blur, ti, {Size = Window.Minimized and 5 or 10}):Play()
            end
            task.wait(fadeDur + 0.05)
            if Bg then Bg:Destroy() end
        end

        for _,bi in pairs(buttons) do
            local btext = bi.Title or "Button"
            local bcb   = bi.Callback or function() end
            local prim  = bi.Primary or false
            local DB = Utility:Create("TextButton",{Parent=BC,BackgroundColor3=prim and theme.Accent or theme.Element,BackgroundTransparency=prim and 0 or theme.ElementTransparency,Size=UDim2.new(0,90,0,36),Font=Enum.Font.GothamBold,Text=btext,TextColor3=prim and theme.Text or theme.TextDark,TextSize=13,AutoButtonColor=false,ZIndex=103},{Utility:Create("UICorner",{CornerRadius=UDim.new(0,Config.ElementCornerRadius)}),Utility:Create("UIStroke",{Color=prim and theme.Accent or theme.Border,Transparency=prim and 0.3 or theme.BorderTransparency,Thickness=1})})
            DB.MouseEnter:Connect(function() Utility:Tween(DB,{BackgroundTransparency=0,BackgroundColor3=prim and theme.AccentDark or theme.Accent,TextColor3=theme.Text},Config.AnimationSpeed*0.5) end)
            DB.MouseLeave:Connect(function() Utility:Tween(DB,{BackgroundColor3=prim and theme.Accent or theme.Element,BackgroundTransparency=prim and 0 or theme.ElementTransparency,TextColor3=prim and theme.Text or theme.TextDark},Config.AnimationSpeed*0.5) end)
            DB.MouseButton1Click:Connect(function() Utility:Ripple(DB,theme,Config); bcb(); CloseDialog() end)
        end

        Bg.InputBegan:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 then
                local m=UserInputService:GetMouseLocation()
                local p=DF.AbsolutePosition; local s=DF.AbsoluteSize
                if m.X<p.X or m.X>p.X+s.X or m.Y<p.Y or m.Y>p.Y+s.Y then CloseDialog() end
            end
        end)
    end

    -- ============================================================
    -- Destroy / Toggle / Theme API
    -- ============================================================
    function Window:Destroy()
        for _,c in pairs(Window.Connections) do
            if c and c.Connected then c:Disconnect() end
        end
        if Blur then Utility:Tween(Blur,{Size=0},Config.AnimationSpeed*1.2,Enum.EasingStyle.Quart) end
        Utility:Tween(MainContainer,{Size=UDim2.new(0,0,0,0),BackgroundTransparency=1},Config.AnimationSpeed*1.2,Enum.EasingStyle.Quint,Enum.EasingDirection.InOut)
        local s=MainContainer:FindFirstChild("MainStroke"); if s then Utility:Tween(s,{Transparency=1},Config.AnimationSpeed*1.2) end
        task.wait(Config.AnimationSpeed*1.4)
        CleanupAllBlur()
        ScreenGui:Destroy()
    end

    function Window:Toggle(visible)
        if visible==nil then visible = not MainContainer.Visible end
        if visible then
            MainContainer.Visible=true
            MainContainer.Size=UDim2.new(0,0,0,0)
            Utility:Tween(MainContainer,{Size=UDim2.new(0,WIN_W, 0, Window.Minimized and MIN_H or WIN_H)},Config.AnimationSpeed*1.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
            if Blur then Utility:Tween(Blur,{Size = Window.Minimized and 5 or 10},Config.AnimationSpeed) end
        else
            Utility:Tween(MainContainer,{Size=UDim2.new(0,0,0,0)},Config.AnimationSpeed*1.2,Enum.EasingStyle.Quint,Enum.EasingDirection.InOut)
            if Blur then Utility:Tween(Blur,{Size=0},Config.AnimationSpeed) end
            task.wait(Config.AnimationSpeed*1.3)
            MainContainer.Visible=false
        end
    end

    function Window:GetTheme() return Window.ThemeName end
    function Window:SetTheme(n) ApplyTheme(n,true) end
    function Window:GetThemes() local l={}; for n,_ in pairs(Themes) do table.insert(l,n) end; return l end

    -- Toggle keybind (FIXED: properly handles gpe so RightShift works)
    local toggleKey = options.ToggleKey or Enum.KeyCode.RightShift
    table.insert(Window.Connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if input.KeyCode ~= toggleKey then return end
        local focused = UserInputService:GetFocusedTextBox()
        if focused then return end
        Window:Toggle()
    end))

    return Window
end

-- Static helpers
function AlexchadLibrary:GetThemes() local l={}; for n,_ in pairs(Themes) do table.insert(l,n) end; return l end
function AlexchadLibrary:AddTheme(name,data) Themes[name]=data end
function AlexchadLibrary:IsMobile() return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled end

return AlexchadLibrary
