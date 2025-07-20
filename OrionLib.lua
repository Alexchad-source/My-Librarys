--[[
    Library: ZenithUILib v1.0
    Author: AI Model
    Version: 1.0.0
    Description: A lightweight, draggable Roblox UI library with auto-scrolling frames, simple element creation,
    configuration saving, and smooth animations. Supports debug mode for side panel layout and verbose logging.
    Intended for educational purposes only.
]]

--================================================================================================================================--
--[[                                                 ENVIRONMENT SETUP                                                  ]]--
--================================================================================================================================--

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Environment check
local function checkEnvironment()
    local required = { "getgenv" }
    for _, func in ipairs(required) do
        if not _G[func] then
            warn("[ZenithUILib] Missing required function: " .. func .. ". Some features may not work.")
            return false
        end
    end
    return true
end

if not checkEnvironment() then
    warn("[ZenithUILib] Incompatible environment detected. Library may not function as expected.")
end

--================================================================================================================================--
--[[                                                      SHARED UTILITIES                                                      ]]--
--================================================================================================================================--

-- Centralized logging
local function logMessage(logType, message, debugMode)
    if debugMode then
        print(string.format("[ZenithUILib | %s] %s", logType, message))
    end
end

-- Simplified JSON encoder/decoder
local Json = {}
do
    local escapeChars = { ['\\'] = '\\\\', ['"'] = '\\"', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
    local function encodeString(s) return '"' .. s:gsub('[%c"\\]', escapeChars) .. '"' end
    local function encodeValue(val, stack)
        stack = stack or {}
        if stack[val] then error("Circular reference detected") end
        stack[val] = true
        local t = type(val)
        if t == "string" then return encodeString(val) end
        if t == "number" then return (val == val and val ~= math.huge and val ~= -math.huge) and tostring(val) or "null" end
        if t == "boolean" then return tostring(val) end
        if t == "nil" then return "null" end
        if t == "table" then
            local res, isArray = {}, rawget(val, 1) ~= nil or next(val) == nil
            if isArray then
                for i = 1, #val do res[i] = encodeValue(val[i], stack) end
                return "[" .. table.concat(res, ",") .. "]"
            else
                for k, v in pairs(val) do table.insert(res, encodeString(tostring(k)) .. ":" .. encodeValue(v, stack)) end
                return "{" .. table.concat(res, ",") .. "}"
            end
        end
        error("Unsupported type: " .. t)
    end
    Json.encode = function(val) return encodeValue(val) end
    Json.decode = function(str)
        local func = loadstring("return " .. str)
        if func then return pcall(func) end
        return false, nil
    end
end

-- Tween utility
local function tween(instance, properties, duration, easingStyle, easingDirection)
    easingStyle = easingStyle or Enum.EasingStyle.Quad
    easingDirection = easingDirection or Enum.EasingDirection.Out
    local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

--================================================================================================================================--
--[[                                                     ZENITH UI LIBRARY                                                     ]]--
--================================================================================================================================--

local ZenithUILib = {}
ZenithUILib.__index = ZenithUILib

function ZenithUILib.new(config)
    config = config or {}
    local self = setmetatable({}, ZenithUILib)
    self.title = config.title or "ZenithUILib"
    self.size = config.size or UDim2.new(0, 600, 0, 400)
    self.debugMode = config.debugMode or false
    self.toggleKey = config.toggleKey or Enum.KeyCode.End
    self.tabs = {}
    self.config = {}
    self.gui = Instance.new("ScreenGui")
    self.gui.Name = "ZenithUILib"
    self.gui.ResetOnSpawn = false
    self.gui.Parent = game:GetService("CoreGui")
    self.gui.Enabled = true

    -- Main window
    self.mainFrame = Instance.new("Frame")
    self.mainFrame.Size = self.size
    self.mainFrame.Position = UDim2.new(0.5, -self.size.X.Offset / 2, 0.5, -self.size.Y.Offset / 2)
    self.mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    self.mainFrame.BorderSizePixel = 0
    self.mainFrame.Parent = self.gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = self.mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = self.mainFrame

    -- Title bar
    self.titleBar = Instance.new("Frame")
    self.titleBar.Size = UDim2.new(1, 0, 0, 30)
    self.titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    self.titleBar.BorderSizePixel = 0
    self.titleBar.Parent = self.mainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = self.titleBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -10, 1, 0)
    titleLabel.Position = UDim2.new(0, 5, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = self.title
    titleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = self.titleBar

    -- Dragging logic
    local dragging, dragInput, dragStart, startPos
    self.titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = self.mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    self.titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local delta = input.Position - dragStart
            self.mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Tab bar
    self.tabBar = Instance.new("Frame")
    self.tabBar.Size = UDim2.new(1, 0, 0, 30)
    self.tabBar.Position = UDim2.new(0, 0, 0, 30)
    self.tabBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    self.tabBar.BorderSizePixel = 0
    self.tabBar.Parent = self.mainFrame

    -- Content area
    self.contentFrame = Instance.new("Frame")
    self.contentFrame.Size = UDim2.new(1, -10, 1, -70)
    self.contentFrame.Position = UDim2.new(0, 5, 0, 65)
    self.contentFrame.BackgroundTransparency = 1
    self.contentFrame.Parent = self.mainFrame

    -- Toggle GUI
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == self.toggleKey then
            self.gui.Enabled = not self.gui.Enabled
            logMessage("INFO", "GUI toggled: " .. tostring(self.gui.Enabled), self.debugMode)
        end
    end)

    return self
end

function ZenithUILib:AddTab(name)
    local tab = {}
    tab.name = name
    tab.frame = Instance.new("Frame")
    tab.frame.Size = UDim2.new(1, 0, 1, 0)
    tab.frame.BackgroundTransparency = 1
    tab.frame.Visible = false
    tab.frame.Parent = self.contentFrame
    tab.elements = {}
    tab.contentHeight = 0

    -- Auto-scrolling frame
    tab.scrollFrame = Instance.new("ScrollingFrame")
    tab.scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    tab.scrollFrame.Position = UDim2.new(0, 0, 0, 0)
    tab.scrollFrame.BackgroundTransparency = 1
    tab.scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    tab.scrollFrame.ScrollBarThickness = 6
    tab.scrollFrame.Visible = false
    tab.scrollFrame.Parent = tab.frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = self.debugMode and tab.frame or tab.scrollFrame

    -- Tab button
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 100, 1, 0)
    button.Position = UDim2.new(0, #self.tabs * 100, 0, 0)
    button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    button.Text = name
    button.TextColor3 = Color3.fromRGB(150, 150, 150)
    button.TextSize = 14
    button.Font = Enum.Font.SourceSans
    button.BorderSizePixel = 0
    button.Parent = self.tabBar

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = button

    button.MouseButton1Click:Connect(function()
        for _, t in pairs(self.tabs) do
            t.frame.Visible = t.name == name
            t.scrollFrame.Visible = t.name == name and t.contentHeight > self.contentFrame.AbsoluteSize.Y
            tween(t.frame, { BackgroundTransparency = t.name == name and 1 or 0.5 }, 0.2)
        end
        for _, btn in ipairs(self.tabBar:GetChildren()) do
            if btn:IsA("TextButton") then
                tween(btn, {
                    BackgroundColor3 = btn.Text == name and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(35, 35, 35),
                    TextColor3 = btn.Text == name and Color3.fromRGB(200, 200, 200) or Color3.fromRGB(150, 150, 150)
                }, 0.2)
            end
        end
        logMessage("INFO", "Switched to tab: " .. name, self.debugMode)
    end)

    button.MouseEnter:Connect(function()
        if button.Text ~= name or not self.tabs[name].frame.Visible then
            tween(button, { BackgroundColor3 = Color3.fromRGB(45, 45, 45) }, 0.1)
        end
    end)

    button.MouseLeave:Connect(function()
        if button.Text ~= name or not self.tabs[name].frame.Visible then
            tween(button, { BackgroundColor3 = Color3.fromRGB(35, 35, 35) }, 0.1)
        end
    end)

    self.tabs[name] = tab
    if #self.tabs == 1 then
        button:MouseButton1Click()
    end
    return tab
end

function ZenithUILib:AddButton(name, callback)
    local tab = self.tabs[name]
    if not tab then
        logMessage("ERROR", "Tab not found: " .. tostring(name), self.debugMode)
        return
    end

    local buttonFrame = self.debugMode and Instance.new("Frame") or tab.scrollFrame
    if self.debugMode then
        buttonFrame.Size = UDim2.new(0, 150, 1, 0)
        buttonFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        buttonFrame.Parent = tab.frame
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = buttonFrame
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 5)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = buttonFrame
    end

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -10, 0, 30)
    button.Position = UDim2.new(0, 5, 0, 0)
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    button.Text = name
    button.TextColor3 = Color3.fromRGB(200, 200, 200)
    button.TextSize = 14
    button.Font = Enum.Font.SourceSans
    button.Parent = self.debugMode and buttonFrame or tab.scrollFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button

    button.MouseButton1Click:Connect(function()
        tween(button, { Size = UDim2.new(1, -12, 0, 28) }, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Wait()
        tween(button, { Size = UDim2.new(1, -10, 0, 30) }, 0.1)
        if callback then callback() end
    end)

    button.MouseEnter:Connect(function()
        tween(button, { BackgroundColor3 = Color3.fromRGB(60, 60, 60) }, 0.1)
    end)

    button.MouseLeave:Connect(function()
        tween(button, { BackgroundColor3 = Color3.fromRGB(50, 50, 50) }, 0.1)
    end)

    tab.contentHeight = tab.contentHeight + 35
    tab.scrollFrame.Visible = tab.contentHeight > self.contentFrame.AbsoluteSize.Y
    tab.scrollFrame.CanvasSize = UDim2.new(0, 0, 0, tab.contentHeight)
    table.insert(tab.elements, { type = "button", name = name })
end

function ZenithUILib:AddToggle(name, default, callback)
    local tab = self.tabs[name]
    if not tab then
        logMessage("ERROR", "Tab not found: " .. tostring(name), self.debugMode)
        return
    end

    local buttonFrame = self.debugMode and Instance.new("Frame") or tab.scrollFrame
    if self.debugMode and not buttonFrame.Parent then
        buttonFrame.Size = UDim2.new(0, 150, 1, 0)
        buttonFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        buttonFrame.Parent = tab.frame
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = buttonFrame
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 5)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = buttonFrame
    end

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(1, -10, 0, 30)
    toggle.Position = UDim2.new(0, 5, 0, 0)
    toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    toggle.Text = name .. ": " .. (default and "ON" or "OFF")
    toggle.TextColor3 = Color3.fromRGB(200, 200, 200)
    toggle.TextSize = 14
    toggle.Font = Enum.Font.SourceSans
    toggle.Parent = self.debugMode and buttonFrame or tab.scrollFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = toggle

    local state = default
    toggle.MouseButton1Click:Connect(function()
        state = not state
        toggle.Text = name .. ": " .. (state and "ON" or "OFF")
        tween(toggle, { Size = UDim2.new(1, -12, 0, 28) }, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In):Wait()
        tween(toggle, { Size = UDim2.new(1, -10, 0, 30) }, 0.1)
        if callback then callback(state) end
        self.config[name] = state
        logMessage("INFO", "Toggle " .. name .. " set to " .. tostring(state), self.debugMode)
    end)

    toggle.MouseEnter:Connect(function()
        tween(toggle, { BackgroundColor3 = Color3.fromRGB(60, 60, 60) }, 0.1)
    end)

    toggle.MouseLeave:Connect(function()
        tween(toggle, { BackgroundColor3 = Color3.fromRGB(50, 50, 50) }, 0.1)
    end)

    self.config[name] = default
    tab.contentHeight = tab.contentHeight + 35
    tab.scrollFrame.Visible = tab.contentHeight > self.contentFrame.AbsoluteSize.Y
    tab.scrollFrame.CanvasSize = UDim2.new(0, 0, 0, tab.contentHeight)
    table.insert(tab.elements, { type = "toggle", name = name, instance = toggle })
end

function ZenithUILib:AddTextBox(name, default, callback)
    local tab = self.tabs[name]
    if not tab then
        logMessage("ERROR", "Tab not found: " .. tostring(name), self.debugMode)
        return
    end

    local textFrame = Instance.new("Frame")
    textFrame.Size = UDim2.new(1, -10, 0, 100)
    textFrame.Position = UDim2.new(0, 5, 0, 0)
    textFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    textFrame.Parent = tab.scrollFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = textFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 20)
    label.Position = UDim2.new(0, 5, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 14
    label.Font = Enum.Font.SourceSans
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = textFrame

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -10, 0, 70)
    textBox.Position = UDim2.new(0, 5, 0, 25)
    textBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    textBox.Text = default or ""
    textBox.PlaceholderText = "Enter text..."
    textBox.TextColor3 = Color3.fromRGB(200, 200, 200)
    textBox.TextSize = 14
    textBox.Font = Enum.Font.Code
    textBox.MultiLine = true
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.TextYAlignment = Enum.TextYAlignment.Top
    textBox.ClearTextOnFocus = false
    textBox.Parent = textFrame

    local corner2 = Instance.new("UICorner")
    corner2.CornerRadius = UDim.new(0, 4)
    corner2.Parent = textBox

    local lastInput = tick()
    textBox:GetPropertyChangedSignal("Text"):Connect(function()
        if tick() - lastInput < 0.1 then return end
        lastInput = tick()
        self.config[name] = textBox.Text
        if callback then callback(textBox.Text) end
    end)

    tab.contentHeight = tab.contentHeight + 105
    tab.scrollFrame.Visible = tab.contentHeight > self.contentFrame.AbsoluteSize.Y
    tab.scrollFrame.CanvasSize = UDim2.new(0, 0, 0, tab.contentHeight)
    table.insert(tab.elements, { type = "textbox", name = name, instance = textBox })
end

function ZenithUILib:SaveConfig()
    if not writefile then
        logMessage("ERROR", "Config saving failed: 'writefile' unavailable", self.debugMode)
        return
    end
    local success, result = pcall(Json.encode, self.config)
    if success then
        pcall(function()
            writefile("zenith_ui_config.json", result)
            logMessage("SUCCESS", "Config saved to zenith_ui_config.json", self.debugMode)
        end)
    else
        logMessage("ERROR", "Config encoding failed: " .. tostring(result), self.debugMode)
    end
end

function ZenithUILib:LoadConfig()
    if not readfile then
        logMessage("ERROR", "Config loading failed: 'readfile' unavailable", self.debugMode)
        return
    end
    local success, content = pcall(readfile, "zenith_ui_config.json")
    if not success then
        logMessage("ERROR", "Failed to read config: " .. tostring(content), self.debugMode)
        return
    end
    local success, config = Json.decode(content)
    if not success then
        logMessage("ERROR", "Failed to decode config: " .. tostring(config), self.debugMode)
        return
    end
    self.config = config or {}
    for tabName, tab in pairs(self.tabs) do
        for _, element in ipairs(tab.elements) do
            if element.type == "toggle" and config[element.name] ~= nil then
                element.instance.Text = element.name .. ": " .. (config[element.name] and "ON" or "OFF")
            elseif element.type == "textbox" and config[element.name] ~= nil then
                element.instance.Text = config[element.name]
            end
        end
    end
    logMessage("SUCCESS", "Config loaded from zenith_ui_config.json", self.debugMode)
end

function ZenithUILib:Destroy()
    self.gui:Destroy()
    logMessage("INFO", "ZenithUILib destroyed", self.debugMode)
end

--================================================================================================================================--
--[[                                                         FINALIZATION                                                       ]]--
--================================================================================================================================--

logMessage("SUCCESS", "ZenithUILib v1.0 loaded successfully", true)
return ZenithUILib
