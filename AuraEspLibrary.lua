--[[
    Universal ESP Library for Roblox
    Version: 1.0.0
    Author: Sigma Alexchad 
    Lines: ~950

    Features:
    - Player ESP (Box, Name, Health, Distance, Tracer)
    - "Everything" ESP: Tracks any Instance type within a specified parent (Folders, Models, Parts, etc.)
    - Real-time updates for added/removed objects.
    - Full customization via a central 'Settings' table.
    - Master and per-category toggles.
    - Performance-conscious design with update throttling and efficient cleanup.
    - Drawing Abstraction: Uses 'drawing' library if available, otherwise falls back to GUI objects.
    - Simple GUI for live configuration.
--]]

local ESP = {}
ESP.__index = ESP

--// Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("workspace")

--// Locals
local Camera = Workspace.Camera
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// Private State
local TrackedObjects = {} -- { [Instance] = tracker_data }
local GlobalConnections = {}
local IsUsingDrawingLib = pcall(function() return drawing and drawing.new end) and (drawing and drawing.new)

--//============================================================================//
--//                                 SETTINGS                                   //
--//============================================================================//

local Settings = {
    -- Master Toggle
    Enabled = true,
    ToggleKeybind = Enum.KeyCode.RightControl,

    -- Global Performance & Visuals
    MaxDistance = 500, -- in studs
    UpdateInterval = 0, -- Frames to skip between updates. 0 = every frame, 1 = every other frame, etc.
    FadeInTime = 0.2, -- Time for ESP elements to fade in. Set to 0 to disable.

    -- Player ESP Specific Settings
    Players = {
        Enabled = true,
        Box = true,
        Name = true,
        Healthbar = true,
        Distance = true,
        Tracer = true,
        TeamCheck = false, -- Only show ESP on enemy players

        -- Colors
        BoxColor = Color3.fromRGB(255, 0, 0),
        NameColor = Color3.fromRGB(255, 255, 255),
        TracerColor = Color3.fromRGB(255, 25, 25),
        Healthbar_High = Color3.fromRGB(0, 255, 0),
        Healthbar_Medium = Color3.fromRGB(255, 255, 0),
        Healthbar_Low = Color3.fromRGB(255, 0, 0),
    },

    -- Folder/Instance ESP Specific Settings
    Instances = {
        Enabled = true,
        Box = true,
        Name = true,
        Distance = true,

        -- Colors
        BoxColor = Color3.fromRGB(0, 150, 255),
        NameColor = Color3.fromRGB(255, 255, 255),
    },

    -- GUI Settings
    Menu = {
        Enabled = true,
        ToggleKeybind = Enum.KeyCode.RightShift
    }
}

--//============================================================================//
--//                           DRAWING ABSTRACTION LAYER                        //
--//============================================================================//

-- This internal module allows the ESP to use the 'drawing' global if it exists,
-- otherwise it falls back to creating traditional BillboardGui elements. This makes
-- the library versatile for both exploiters and regular developers.

local Drawing = {}
Drawing.__index = Drawing

local DrawingContainer -- Parent for all GUI-based drawings
if not IsUsingDrawingLib then
    DrawingContainer = Instance.new("ScreenGui")
    DrawingContainer.Name = "ESP_DrawingContainer_" .. tostring(math.random()):sub(3)
    DrawingContainer.ResetOnSpawn = false
    DrawingContainer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    DrawingContainer.Parent = PlayerGui
end

function Drawing.new(type, properties)
    if IsUsingDrawingLib then
        local d = drawing.new(type)
        if properties then
            for prop, value in pairs(properties) do
                d[prop] = value
            end
        end
        return d
    else
        local obj
        local billboard = Instance.new("BillboardGui")
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.fromOffset(0, 0)
        billboard.ClipsDescendants = false

        if type == "Text" then
            obj = Instance.new("TextLabel")
            obj.BackgroundTransparency = 1
            obj.TextSize = 14
            obj.Font = Enum.Font.SourceSans
            obj.TextColor3 = properties and properties.Color or Color3.new(1, 1, 1)
            obj.Text = properties and properties.Text or ""
            obj.Parent = billboard
        elseif type == "Line" then
            obj = Instance.new("Frame")
            obj.AnchorPoint = Vector2.new(0.5, 0.5)
            obj.BackgroundColor3 = properties and properties.Color or Color3.new(1, 1, 1)
            obj.BorderSizePixel = 0
            obj.Parent = billboard
        elseif type == "Quad" then -- For boxes and health bars
            obj = Instance.new("Frame")
            obj.BackgroundTransparency = 1
            obj.BorderSizePixel = 1
            obj.BorderColor3 = properties and properties.Color or Color3.new(1, 1, 1)
            obj.Parent = billboard
        elseif type == "Image" then
            obj = Instance.new("ImageLabel")
            obj.BackgroundTransparency = 1
            obj.Image = properties.Image
            obj.Parent = billboard
        end

        local drawingWrapper = {
            _guiObject = obj,
            _billboard = billboard,
            _type = type,
            Visible = true,
            Color = properties and properties.Color,
        }
        
        -- Compatibility setters/getters
        setmetatable(drawingWrapper, {
            __newindex = function(self, index, value)
                if rawget(self, "_guiObject") then
                    if index == "Visible" then
                        self._billboard.Enabled = value
                    elseif index == "Color" then
                        if self._type == "Text" then self._guiObject.TextColor3 = value
                        elseif self._type == "Line" then self._guiObject.BackgroundColor3 = value
                        elseif self._type == "Quad" then self._guiObject.BorderColor3 = value
                        end
                        rawset(self, "Color", value)
                    elseif index == "Text" and self._type == "Text" then
                        self._guiObject.Text = value
                    elseif index == "From" and self._type == "Line" then
                        rawset(self, "From", value)
                    elseif index == "To" and self._type == "Line" then
                        rawset(self, "To", value)
                    elseif index == "Size" and (self._type == "Quad" or self._type == "Text") then
                         self._guiObject.Size = UDim2.fromOffset(value.X, value.Y)
                    elseif index == "Position" and (self._type == "Quad" or self._type == "Text") then
                         self._guiObject.Position = UDim2.fromOffset(value.X, value.Y)
                    else
                        rawset(self, index, value)
                    end
                else
                    rawset(self, index, value)
                end
            end,
            __index = function(self, index)
                if index == "Remove" or index == "Destroy" then
                    return function()
                        if self._billboard then self._billboard:Destroy() end
                    end
                end
                return rawget(self, index)
            end
        })

        billboard.Parent = DrawingContainer
        return drawingWrapper
    end
end

--//============================================================================//
--//                             CORE ESP LOGIC                                 //
--//============================================================================//

function ESP:_cleanupInstance(instance)
    local data = TrackedObjects[instance]
    if not data then return end

    if data.drawings then
        for _, drawing in pairs(data.drawings) do
            if drawing.Remove then drawing:Remove() else drawing:Destroy() end
        end
    end

    if data.connections then
        for _, connection in ipairs(data.connections) do
            connection:Disconnect()
        end
    end

    TrackedObjects[instance] = nil
end

function ESP:_get3DInfo(instance)
    if not instance or not instance:IsA("PVInstance") then
        local parentPV = instance and instance:FindFirstAncestorWhichIsA("PVInstance")
        if parentPV then
            return parentPV.CFrame, parentPV:GetExtentsSize()
        else
            return nil, nil -- Cannot determine position
        end
    end
    
    if instance:IsA("Model") then
        return instance:GetBoundingBox()
    end
    
    if instance:IsA("BasePart") then
        return instance.CFrame, instance.Size
    end
    
    return instance.CFrame, instance.Size
end


function ESP:_updateDrawings(data, instance, cframe, size, onScreen, distance)
    local settings = Settings[data.espType]
    if not settings or not settings.Enabled then return end

    local halfSize = size / 2
    local corners = {
        cframe * CFrame.new(halfSize.X, halfSize.Y, 0), -- Top-Right
        cframe * CFrame.new(-halfSize.X, halfSize.Y, 0), -- Top-Left
        cframe * CFrame.new(-halfSize.X, -halfSize.Y, 0), -- Bottom-Left
        cframe * CFrame.new(halfSize.X, -halfSize.Y, 0), -- Bottom-Right
    }

    local screenCorners = {}
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge

    for _, cornerCF in ipairs(corners) do
        local screenPos, inViewport = Camera:WorldToViewportPoint(cornerCF.Position)
        if not inViewport then
            -- Fallback for off-screen corners to keep box shape reasonable
            local screenPosOnEdge = Camera:WorldToViewportPoint(cframe.Position)
            minX, minY = screenPosOnEdge.X, screenPosOnEdge.Y
            maxX, maxY = screenPosOnEdge.X, screenPosOnEdge.Y
            break
        end
        table.insert(screenCorners, Vector2.new(screenPos.X, screenPos.Y))
        minX = math.min(minX, screenPos.X)
        minY = math.min(minY, screenPos.Y)
        maxX = math.max(maxX, screenPos.X)
        maxY = math.max(maxY, screenPos.Y)
    end

    local boxWidth = maxX - minX
    local boxHeight = maxY - minY
    
    local nameText = instance.Name
    if data.espType == "Players" and instance.Parent then
        nameText = instance.Parent.Name
    end

    -- Update Box
    if data.drawings.Box and settings.Box then
        data.drawings.Box.Visible = onScreen
        data.drawings.Box.Color = settings.BoxColor
        data.drawings.Box.Position = Vector2.new(minX, minY)
        data.drawings.Box.Size = Vector2.new(boxWidth, boxHeight)
    end

    -- Update Name
    if data.drawings.Name and settings.Name then
        data.drawings.Name.Visible = onScreen
        data.drawings.Name.Color = settings.NameColor
        data.drawings.Name.Text = nameText
        data.drawings.Name.Position = Vector2.new(minX + boxWidth / 2, minY - 16)
    end

    -- Update Distance
    if data.drawings.Distance and settings.Distance then
        data.drawings.Distance.Visible = onScreen
        data.drawings.Distance.Text = `[{math.floor(distance)}m]`
        data.drawings.Distance.Position = Vector2.new(minX + boxWidth / 2, maxY + 2)
    end

    -- Update Tracer
    if data.drawings.Tracer and settings.Tracer then
        data.drawings.Tracer.Visible = onScreen
        data.drawings.Tracer.Color = settings.TracerColor
        data.drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y) -- Bottom-center of screen
        data.drawings.Tracer.To = Vector2.new(minX + boxWidth / 2, maxY) -- Bottom-center of box
    end
    
    -- Update Healthbar (Player specific)
    if data.drawings.Healthbar and settings.Healthbar and data.humanoid then
        local humanoid = data.humanoid
        local health = humanoid.Health
        local maxHealth = humanoid.MaxHealth
        local healthPercent = math.clamp(health / maxHealth, 0, 1)

        data.drawings.Healthbar.Visible = onScreen
        data.drawings.HealthbarBackground.Visible = onScreen

        local healthbarHeight = boxHeight
        local healthbarWidth = 4
        
        local healthColor = settings.Healthbar_High
        if healthPercent < 0.7 then healthColor = settings.Healthbar_Medium end
        if healthPercent < 0.35 then healthColor = settings.Healthbar_Low end

        data.drawings.HealthbarBackground.Position = Vector2.new(minX - healthbarWidth - 4, minY)
        data.drawings.HealthbarBackground.Size = Vector2.new(healthbarWidth, healthbarHeight)
        
        data.drawings.Healthbar.Position = Vector2.new(minX - healthbarWidth - 4, minY + healthbarHeight * (1 - healthPercent))
        data.drawings.Healthbar.Size = Vector2.new(healthbarWidth, healthbarHeight * healthPercent)
        data.drawings.Healthbar.Color = healthColor
    end
end

function ESP:_setVisibility(data, visible)
    for _, drawing in pairs(data.drawings) do
        drawing.Visible = visible
    end
end


function ESP:_trackInstance(instance, espType)
    if TrackedObjects[instance] then return end
    
    local settings = Settings[espType]
    if not settings then 
        warn(`[ESP] Unknown ESP type: '{espType}'. Aborting tracking for '{instance.Name}'.`)
        return
    end

    -- Create tracker data table
    local data = {
        espType = espType,
        drawings = {},
        connections = {},
        lastPosition = Vector3.new(),
    }
    TrackedObjects[instance] = data

    -- Create drawing objects
    if settings.Box then
        data.drawings.Box = Drawing.new("Quad", { Color = settings.BoxColor, Visible = false })
    end
    if settings.Name then
        data.drawings.Name = Drawing.new("Text", { Color = settings.NameColor, Visible = false, Size = 14, Center = true })
    end
    if settings.Distance then
        data.drawings.Distance = Drawing.new("Text", { Color = settings.NameColor, Visible = false, Size = 12, Center = true })
    end

    -- Add player-specific drawings and connections
    if espType == "Players" then
        if settings.Tracer then
            data.drawings.Tracer = Drawing.new("Line", { Color = settings.TracerColor, Visible = false, Thickness = 1 })
        end
        
        if settings.Healthbar then
            data.drawings.HealthbarBackground = Drawing.new("Quad", { Color = Color3.new(0.1, 0.1, 0.1), Visible = false })
            data.drawings.Healthbar = Drawing.new("Quad", { Color = settings.Healthbar_High, Visible = false })
        end

        local humanoid = instance:FindFirstChildOfClass("Humanoid")
        if humanoid then
            data.humanoid = humanoid
            table.insert(data.connections, humanoid:GetPropertyChangedSignal("Health"):Connect(function()
                -- Health changes frequently, no need for full redraw, just flag for update
                data.forceUpdate = true
            end))
            table.insert(data.connections, humanoid.Died:Connect(function()
                self:_cleanupInstance(instance)
            end))
        end
    end

    -- Create cleanup connection
    table.insert(data.connections, instance.AncestryChanged:Connect(function(_, parent)
        if not parent then
            self:_cleanupInstance(instance)
        end
    end))
end


--//============================================================================//
--//                         PUBLIC API & INITIALIZATION                        //
--//============================================================================//

--// Main Update Loop
function ESP:Start()
    if self.Started then return end
    self.Started = true
    
    local frameCounter = 0
    GlobalConnections.RenderStepped = RunService.RenderStepped:Connect(function()
        if not Settings.Enabled then
            if self.WasEnabled then
                for _, data in pairs(TrackedObjects) do
                    self:_setVisibility(data, false)
                end
                self.WasEnabled = false
            end
            return
        end
        self.WasEnabled = true

        frameCounter = frameCounter + 1
        if Settings.UpdateInterval > 0 and frameCounter % (Settings.UpdateInterval + 1) ~= 0 then
            return
        end

        local cameraCF = Camera.CFrame
        
        for instance, data in pairs(TrackedObjects) do
            -- Basic validity checks
            if not instance or not instance.Parent then
                self:_cleanupInstance(instance)
                continue
            end
            
            local config = Settings[data.espType]
            if not config or not config.Enabled then
                self:_setVisibility(data, false)
                continue
            end
            
            -- Player-specific team check
            if data.espType == "Players" and config.TeamCheck and instance.Parent then
                local player = Players:GetPlayerFromCharacter(instance)
                if player and player.Team == LocalPlayer.Team then
                    self:_setVisibility(data, false)
                    continue
                end
            end
            
            -- Get 3D position and size
            local cframe, size = self:_get3DInfo(instance)
            if not cframe then
                self:_setVisibility(data, false)
                continue
            end

            -- Check distance and visibility
            local distance = (cameraCF.Position - cframe.Position).Magnitude
            if distance > Settings.MaxDistance then
                self:_setVisibility(data, false)
                continue
            end
            
            local screenPos, onScreen = Camera:WorldToViewportPoint(cframe.Position)
            if onScreen then
                 if not data.lastVisibleState then
                    -- Fade-in logic
                    if Settings.FadeInTime > 0 then
                        for _, drawing in pairs(data.drawings) do
                            if drawing.Transparency then -- Drawing lib property
                                TweenService:Create(drawing, TweenInfo.new(Settings.FadeInTime), { Transparency = 0 }):Play()
                            end
                        end
                    end
                 end
                self:_updateDrawings(data, instance, cframe, size, true, distance)
                data.lastVisibleState = true
            else
                self:_setVisibility(data, false)
                data.lastVisibleState = false
            end
        end
    end)
end

function ESP:Stop()
    if not self.Started then return end
    self.Started = false
    
    for _, connection in pairs(GlobalConnections) do
        connection:Disconnect()
    end
    GlobalConnections = {}
    
    local instancesToClean = {}
    for instance in pairs(TrackedObjects) do
        table.insert(instancesToClean, instance)
    end
    for _, instance in ipairs(instancesToClean) do
        self:_cleanupInstance(instance)
    end

    if DrawingContainer then
        DrawingContainer:Destroy()
        DrawingContainer = nil
    end

    if self.MenuGui then
        self.MenuGui:Destroy()
        self.MenuGui = nil
    end
end

-- Adds ESP for all current and future players.
function ESP:AddPlayerESP()
    local function handlePlayer(player)
        local function handleCharacter(character)
            -- Wait for the character's primary part to ensure it's positioned correctly.
            local head = character:WaitForChild("Head", 5)
            if not head or player == LocalPlayer then return end

            self:_trackInstance(character, "Players")
        end

        player.CharacterAdded:Connect(handleCharacter)
        if player.Character then
            handleCharacter(player.Character)
        end

        player.CharacterRemoving:Connect(function(character)
            self:_cleanupInstance(character)
        end)
    end
    
    GlobalConnections.PlayerAdded = Players.PlayerAdded:Connect(handlePlayer)
    GlobalConnections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
        if player.Character then
            self:_cleanupInstance(player.Character)
        end
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        handlePlayer(player)
    end
end

-- Adds ESP for all descendants of a given folder/service.
function ESP:AddFolderESP(parentInstance)
    if not parentInstance or not parentInstance:IsA("Instance") then
        warn("[ESP] AddFolderESP requires a valid Instance.")
        return
    end

    local function handleDescendant(descendant)
        -- We only care about things we can visually represent.
        if descendant:IsA("PVInstance") and not descendant:IsA("Camera") and not descendant:IsA("WorldRoot") then
            -- Avoid tracking parts of player characters if Player ESP is on
            local player = Players:GetPlayerFromCharacter(descendant)
            if not player then
                self:_trackInstance(descendant, "Instances")
            end
        end
    end

    -- Connect to future additions/removals
    GlobalConnections[parentInstance] = {
        Added = parentInstance.DescendantAdded:Connect(handleDescendant),
        Removing = parentInstance.DescendantRemoving:Connect(function(descendant)
            self:_cleanupInstance(descendant)
        end)
    }

    -- Handle existing descendants
    for _, descendant in ipairs(parentInstance:GetDescendants()) do
        handleDescendant(descendant)
    end
end

-- Updates a setting value.
function ESP:SetConfig(category, key, value)
    if category == "Global" then
        if Settings[key] ~= nil then
            Settings[key] = value
        end
    elseif Settings[category] and Settings[category][key] ~= nil then
        Settings[category][key] = value
    else
        warn(`[ESP] Invalid setting: {category}.{key}`)
    end
end

--//============================================================================//
--//                                 GUI MENU                                   //
--//============================================================================//

function ESP:CreateMenu()
    if self.MenuGui or not Settings.Menu.Enabled then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ESP_Menu"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local main = Instance.new("Frame")
    main.Size = UDim2.fromOffset(250, 350)
    main.Position = UDim2.fromScale(0.5, 0.5)
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    main.BorderColor3 = Color3.fromRGB(80, 80, 80)
    main.Visible = false
    main.Draggable = true
    main.Active = true
    main.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    title.Text = "ESP Library Menu"
    title.Font = Enum.Font.SourceSansBold
    title.TextColor3 = Color3.new(1,1,1)
    title.TextSize = 16
    title.Parent = main

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 5)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.Parent = main

    local function createToggle(text, category, key, layoutOrder)
        local button = Instance.new("TextButton")
        button.LayoutOrder = layoutOrder
        button.Size = UDim2.new(0.9, 0, 0, 25)
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        button.Font = Enum.Font.SourceSans
        button.TextSize = 14
        button.TextColor3 = Color3.new(1,1,1)
        button.Parent = main

        local function updateText()
            local value = (category == "Global" and Settings[key]) or Settings[category][key]
            button.Text = text .. ": " .. (value and "ON" or "OFF")
            button.BackgroundColor3 = value and Color3.fromRGB(70, 110, 70) or Color3.fromRGB(110, 70, 70)
        end

        button.MouseButton1Click:Connect(function()
            local currentVal = (category == "Global" and Settings[key]) or Settings[category][key]
            self:SetConfig(category, key, not currentVal)
            updateText()
        end)
        
        updateText()
        return button
    end
    
    -- Add padding at the top
    local padding = Instance.new("Frame")
    padding.Size = UDim2.new(1, 0, 0, 35)
    padding.BackgroundTransparency = 1
    padding.LayoutOrder = 0
    padding.Parent = main

    createToggle("Master ESP", "Global", "Enabled", 1)
    createToggle("Player ESP", "Players", "Enabled", 2)
    createToggle("└ Player Boxes", "Players", "Box", 3)
    createToggle("└ Player Names", "Players", "Name", 4)
    createToggle("└ Player Healthbars", "Players", "Healthbar", 5)
    createToggle("└ Player Tracers", "Players", "Tracer", 6)
    createToggle("└ Team Check", "Players", "TeamCheck", 7)
    createToggle("Instance ESP", "Instances", "Enabled", 8)
    createToggle("└ Instance Boxes", "Instances", "Box", 9)
    createToggle("└ Instance Names", "Instances", "Name", 10)

    -- Keybind to toggle menu visibility
    GlobalConnections.MenuToggle = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Settings.Menu.ToggleKeybind then
            main.Visible = not main.Visible
        end
    end)
    
    self.MenuGui = gui
    gui.Parent = PlayerGui
end


--//============================================================================//
--//                       INITIALIZATION & RETURN                              //
--//============================================================================//

do
    local function init()
        -- Handle master toggle keybind
        GlobalConnections.MasterToggle = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.KeyCode == Settings.ToggleKeybind then
                Settings.Enabled = not Settings.Enabled
                if self.MenuGui then -- Update the master toggle button in the GUI if it exists
                    for _, child in ipairs(self.MenuGui.Frame:GetChildren()) do
                        if child:IsA("TextButton") and child.Text:match("Master ESP") then
                            local value = Settings.Enabled
                            child.Text = "Master ESP: " .. (value and "ON" or "OFF")
                            child.BackgroundColor3 = value and Color3.fromRGB(70, 110, 70) or Color3.fromRGB(110, 70, 70)
                        end
                    end
                end
            end
        end)

        ESP:Start()
        ESP:CreateMenu()
    end
    
    -- Allow the script to be re-required without breaking everything.
    if getfenv()._ESP_INITIALIZED then
        getfenv()._ESP_INITIALIZED:Stop()
    end
    
    init()
    getfenv()._ESP_INITIALIZED = ESP
end

return ESP
