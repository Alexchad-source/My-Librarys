--[[
    Universal ESP Library - v4.0 (Heavy-Duty Optimization)
    
    This version is re-engineered for maximum performance in high-load scenarios (e.g., crowded servers).
    It introduces dynamic throttling and spatial partitioning to maintain stable FPS.
    The code is more complex and larger, reflecting the advanced optimization techniques used.
--]]

local ESP = {}
ESP.__index = ESP

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local TrackedObjects = {}
local GlobalConnections = {}
local IsUsingDrawingLib = pcall(function() return drawing and drawing.new end) and (drawing and drawing.new)

--========================= SETTINGS =========================--

local Settings = {
    Enabled = true,
    ToggleKeybind = Enum.KeyCode.RightControl,

    MaxDistance = 1000,

    -- NEW: Dynamic Update Throttling
    -- The script will automatically adjust its update speed based on how many objects are on screen.
    DynamicThrottling = {
        Enabled = true,
        BaseInterval = 0,       -- Frames to skip when < 10 targets are on screen.
        MediumInterval = 1,     -- Frames to skip when 10-25 targets are on screen.
        HighInterval = 2,       -- Frames to skip when > 25 targets are on screen.
    },
    
    -- NEW: Spatial Update Frequency
    -- How often to update objects based on their distance from the player.
    ProximityUpdates = {
        Enabled = true,
        NearUpdateRate = 1,     -- Update every Nth valid frame for targets < 30% of max distance.
        MidUpdateRate = 2,      -- Update every Nth valid frame for targets between 30%-70%.
        FarUpdateRate = 4,      -- Update every Nth valid frame for targets > 70%.
    },
    
    Players = {
        Enabled = true, Box = true, Name = true, Healthbar = true, Distance = true, Tracer = true,
        TeamCheck = false,
        BoxColor = Color3.fromRGB(255, 50, 50), NameColor = Color3.fromRGB(255, 255, 255), TracerColor = Color3.fromRGB(255, 50, 50),
    },

    Instances = {
        Enabled = true, Box = true, Name = true, Distance = true,
        BoxColor = Color3.fromRGB(80, 160, 255), NameColor = Color3.fromRGB(255, 255, 255),
    },
    
    Menu = { Enabled = true, ToggleKeybind = Enum.KeyCode.RightShift }
}
ESP.Settings = Settings

--========================= DRAWING ABSTRACTION =========================--

local Drawing = {}
local DrawingContainer
if not IsUsingDrawingLib then
    DrawingContainer = Instance.new("ScreenGui", PlayerGui)
    DrawingContainer.Name = "ESP_DrawingContainer_"..tostring(math.random()):sub(3)
    DrawingContainer.ResetOnSpawn = false; DrawingContainer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
end

-- This Drawing factory is already quite optimized.
function Drawing.new(type, properties)
    if IsUsingDrawingLib then
        local d = drawing.new(type); if properties then for p, v in pairs(properties) do d[p] = v end end; return d
    else
        local obj; local billboard = Instance.new("BillboardGui", DrawingContainer)
        billboard.AlwaysOnTop = true; billboard.Size = UDim2.fromOffset(0, 0); billboard.ClipsDescendants = false
        if type == "Quad" then obj = Instance.new("Frame", billboard); obj.BackgroundTransparency = 1; obj.BorderSizePixel = 1
        elseif type == "Line" then obj = Instance.new("Frame", billboard); obj.AnchorPoint = Vector2.new(0.5, 0.5); obj.BorderSizePixel = 0
        elseif type == "Text" then obj = Instance.new("TextLabel", billboard); obj.BackgroundTransparency = 1; obj.Font = Enum.Font.SourceSans; obj.TextSize = 14 end
        local wrapper = { _gui = obj, _billboard = billboard, _cache = {} }
        return setmetatable(wrapper, {
            __newindex = function(self, i, v)
                if self._cache[i] == v then return end; self._cache[i] = v
                if i == "Visible" then self._billboard.Enabled = v
                elseif i == "Color" then if type == "Text" then self._gui.TextColor3 = v elseif type == "Line" then self._gui.BackgroundColor3 = v else self._gui.BorderColor3 = v end
                elseif i == "Position" then self._gui.Position = UDim2.fromOffset(v.X, v.Y)
                elseif i == "Size" then self._gui.Size = UDim2.fromOffset(v.X, v.Y)
                elseif i == "Text" and type == "Text" then self._gui.Text = v
                else rawset(self, i, v) end
            end,
            __index = function(self, i) if i == "Remove" then return function() self._billboard:Destroy() end end; return rawget(self, i) end
        })
    end
end

--========================= CORE ESP LOGIC =========================--

function ESP:Add(instance, options)
    if not instance or TrackedObjects[instance] then return end; options = options or {}
    local defaults = Settings[options.Type or "Instances"] or Settings.Instances; local finalOptions = {}
    for k, v in pairs(defaults) do finalOptions[k] = v end; for k, v in pairs(options) do finalOptions[k] = v end
    local data = { options = finalOptions, drawings = {}, connections = {}, isVisible = false, updateCounter = math.random(0, 5) }
    if finalOptions.Box then data.drawings.Box = Drawing.new("Quad") end
    if finalOptions.Name then data.drawings.Name = Drawing.new("Text", {Center = true}) end
    if finalOptions.Distance then data.drawings.Distance = Drawing.new("Text", {Center = true}) end
    if finalOptions.Tracer then data.drawings.Tracer = Drawing.new("Line") end
    if finalOptions.Healthbar and instance:FindFirstChildOfClass("Humanoid") then
        data.drawings.HealthbarBack = Drawing.new("Quad"); data.drawings.HealthbarFront = Drawing.new("Quad")
    end
    local humanoid = instance:FindFirstChildOfClass("Humanoid"); if humanoid then table.insert(data.connections, humanoid.Died:Connect(function() self:Remove(instance) end)) end
    table.insert(data.connections, instance.AncestryChanged:Connect(function(_, p) if not p then self:Remove(instance) end end))
    TrackedObjects[instance] = data
end

function ESP:Remove(instance)
    local data = TrackedObjects[instance]; if not data then return end
    for _, drawing in pairs(data.drawings) do drawing:Remove() end
    for _, connection in ipairs(data.connections) do connection:Disconnect() end
    TrackedObjects[instance] = nil
end

function ESP:_get3DInfo(instance)
    if instance:IsA("Model") then return instance:GetBoundingBox() end
    if instance:IsA("BasePart") then return instance.CFrame, instance.Size end
    local parentPV = instance:FindFirstAncestorWhichIsA("PVInstance"); if parentPV then return parentPV.CFrame, parentPV.Size end
    return nil, nil
end

function ESP:_setDrawingsVisible(data, visible)
    if data.isVisible == visible then return end; data.isVisible = visible
    for _, drawing in pairs(data.drawings) do drawing.Visible = visible end
end

function ESP:_updateDrawings(data, cframe, size, distance)
    local options, drawings = data.options, data.drawings; local halfSize = size / 2
    local corners = {
        cframe.Position + cframe.RightVector * halfSize.X + cframe.UpVector * halfSize.Y,
        cframe.Position + cframe.RightVector * halfSize.X - cframe.UpVector * halfSize.Y,
        cframe.Position - cframe.RightVector * halfSize.X + cframe.UpVector * halfSize.Y,
        cframe.Position - cframe.RightVector * halfSize.X - cframe.UpVector * halfSize.Y,
    }
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local camera = Workspace.CurrentCamera
    for _, worldPos in ipairs(corners) do
        local screenPos = camera:WorldToViewportPoint(worldPos)
        minX, minY = math.min(minX, screenPos.X), math.min(minY, screenPos.Y)
        maxX, maxY = math.max(maxX, screenPos.X), math.max(maxY, screenPos.Y)
    end
    local boxWidth, boxHeight = maxX - minX, maxY - minY
    if drawings.Box then
        drawings.Box.Color = options.BoxColor; drawings.Box.Position = Vector2.new(minX, minY); drawings.Box.Size = Vector2.new(boxWidth, boxHeight)
    end
    if drawings.Name then
        drawings.Name.Color = options.NameColor; drawings.Name.Text = data.instance.Name
        drawings.Name.Position = Vector2.new(minX + boxWidth / 2, minY - 16)
    end
    if drawings.Distance then
        drawings.Distance.Text = `[{math.floor(distance)}m]`; drawings.Distance.Position = Vector2.new(minX + boxWidth / 2, maxY + 2)
    end
    if drawings.Tracer then
        drawings.Tracer.Color = options.TracerColor; drawings.Tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
        drawings.Tracer.To = Vector2.new(minX + boxWidth / 2, maxY)
    end
    if drawings.HealthbarBack and data.instance:IsA("Model") then
        local humanoid = data.instance:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local percent = humanoid.Health / humanoid.MaxHealth
            drawings.HealthbarBack.Color = Color3.new(0,0,0); drawings.HealthbarBack.Position = Vector2.new(minX - 7, minY); drawings.HealthbarBack.Size = Vector2.new(4, boxHeight)
            drawings.HealthbarFront.Color = Color3.fromHSV(0.33 * percent, 1, 1); drawings.HealthbarFront.Position = Vector2.new(minX - 7, minY + boxHeight * (1 - percent)); drawings.HealthbarFront.Size = Vector2.new(4, boxHeight * percent)
        end
    end
end

--========================= MAIN CONTROLLER & HIGH-LEVEL API =========================--

function ESP:Start()
    if self.Started then return end; self.Started = true
    local frameCounter, visibleTargets = 0, 0
    
    GlobalConnections.RenderStepped = RunService.RenderStepped:Connect(function()
        local camera = Workspace.CurrentCamera; if not camera then return end
        if not Settings.Enabled then
            if self.WasEnabled then for _, data in pairs(TrackedObjects) do self:_setDrawingsVisible(data, false) end; self.WasEnabled = false end; return
        end; self.WasEnabled = true

        frameCounter = frameCounter + 1
        local currentInterval = 0
        if Settings.DynamicThrottling.Enabled then
            if visibleTargets > 25 then currentInterval = Settings.DynamicThrottling.HighInterval
            elseif visibleTargets > 10 then currentInterval = Settings.DynamicThrottling.MediumInterval
            else currentInterval = Settings.DynamicThrottling.BaseInterval end
        end
        if currentInterval > 0 and frameCounter % (currentInterval + 1) ~= 0 then return end
        
        visibleTargets = 0
        local cameraCF = camera.CFrame
        for instance, data in pairs(TrackedObjects) do
            data.updateCounter = data.updateCounter + 1
            if not data.options.Enabled then self:_setDrawingsVisible(data, false); continue end

            local cframe, size = self:_get3DInfo(instance)
            if not cframe then self:_setDrawingsVisible(data, false); continue end

            local distance = (cameraCF.Position - cframe.Position).Magnitude
            if distance > Settings.MaxDistance then self:_setDrawingsVisible(data, false); continue end
            
            -- Spatial/Proximity update logic
            if Settings.ProximityUpdates.Enabled then
                local distPercent = distance / Settings.MaxDistance
                local updateRate = Settings.ProximityUpdates.FarUpdateRate
                if distPercent < 0.3 then updateRate = Settings.ProximityUpdates.NearUpdateRate
                elseif distPercent < 0.7 then updateRate = Settings.ProximityUpdates.MidUpdateRate end
                if data.updateCounter % updateRate ~= 0 then continue end
            end
            
            local _, onScreen = camera:WorldToViewportPoint(cframe.Position)
            self:_setDrawingsVisible(data, onScreen)
            if onScreen then
                visibleTargets = visibleTargets + 1
                data.instance = instance -- Pass instance for name/health updates
                self:_updateDrawings(data, cframe, size, distance)
            end
        end
    end)
end

function ESP:AddPlayerESP(options)
    local function handlePlayer(player)
        local function handleCharacter(char) if player ~= LocalPlayer then self:Add(char, options or {Type = "Players"}) end end
        player.CharacterAdded:Connect(handleCharacter); if player.Character then handleCharacter(player.Character) end
    end
    for _, p in ipairs(Players:GetPlayers()) do handlePlayer(p) end; GlobalConnections.PlayerAdded = Players.PlayerAdded:Connect(handlePlayer)
end

function ESP:AddFolderESP(parentInstance, options)
    if not parentInstance then return end; local baseOptions = options or {Type = "Instances"}
    local function handleDescendant(desc) if desc:IsA("PVInstance") and not Players:GetPlayerFromCharacter(desc) then self:Add(desc, baseOptions) end end
    GlobalConnections[parentInstance] = { parentInstance.DescendantAdded:Connect(handleDescendant), parentInstance.DescendantRemoving:Connect(function(desc) self:Remove(desc) end) }
    for _, d in ipairs(parentInstance:GetDescendants()) do handleDescendant(d) end
end

function ESP:SetConfig(category, key, value)
    if category == "Global" then if Settings[key] ~= nil then Settings[key] = value end
    elseif Settings[category] and Settings[category][key] ~= nil then Settings[category][key] = value end
end

--========================= GUI MENU =========================--

function ESP:CreateMenu()
    if self.MenuGui or not Settings.Menu.Enabled then return end
    local gui = Instance.new("ScreenGui", PlayerGui); gui.Name = "ESP_Menu"; gui.ResetOnSpawn = false
    local main = Instance.new("Frame", gui); main.Size = UDim2.fromOffset(250, 320); main.Position = UDim2.fromScale(0.5, 0.5); main.AnchorPoint = Vector2.new(0.5, 0.5); main.BackgroundColor3 = Color3.fromRGB(35, 35, 35); main.BorderColor3 = Color3.fromRGB(80, 80, 80); main.Visible = false; main.Draggable = true; main.Active = true
    local title = Instance.new("TextLabel", main); title.Size = UDim2.new(1, 0, 0, 30); title.BackgroundColor3 = Color3.fromRGB(45, 45, 45); title.Text = "ESP Library Menu"; title.Font = Enum.Font.SourceSansBold; title.TextColor3 = Color3.new(1,1,1); title.TextSize = 16
    local list = Instance.new("UIListLayout", main); list.SortOrder = Enum.SortOrder.LayoutOrder; list.HorizontalAlignment = Enum.HorizontalAlignment.Center; list.Padding = UDim.new(0,5); list.From = UDim2.fromOffset(0,35)
    local function createToggle(text, cat, key, order)
        local btn = Instance.new("TextButton", main); btn.LayoutOrder = order; btn.Size = UDim2.new(0.9, 0, 0, 25); btn.Font = Enum.Font.SourceSans; btn.TextSize = 14; btn.TextColor3 = Color3.new(1,1,1)
        local function update() local v = (cat=="Global" and Settings[key]) or Settings[cat][key]; btn.Text = text..": "..(v and "ON" or "OFF"); btn.BackgroundColor3 = v and Color3.fromRGB(70,110,70) or Color3.fromRGB(110,70,70) end
        btn.MouseButton1Click:Connect(function() self:SetConfig(cat, key, not ((cat=="Global" and Settings[key]) or Settings[cat][key])); update() end); update()
    end
    createToggle("Master ESP", "Global", "Enabled", 1); createToggle("Player ESP", "Players", "Enabled", 2); createToggle("└ Player Boxes", "Players", "Box", 3); createToggle("└ Player Names", "Players", "Name", 4)
    createToggle("└ Player Health", "Players", "Healthbar", 5); createToggle("└ Player Tracers", "Players", "Tracer", 6); createToggle("└ Team Check", "Players", "TeamCheck", 7)
    createToggle("Instance ESP", "Instances", "Enabled", 8); createToggle("└ Instance Boxes", "Instances", "Box", 9);
    GlobalConnections.MenuToggle = UserInputService.InputBegan:Connect(function(i,g) if g then return end if i.KeyCode == Settings.Menu.ToggleKeybind then main.Visible = not main.Visible end end)
    self.MenuGui = gui
end

--========================= INITIALIZATION =========================--

do
    GlobalConnections.MasterToggle = UserInputService.InputBegan:Connect(function(i,g) if g then return end if i.KeyCode == Settings.ToggleKeybind then Settings.Enabled = not Settings.Enabled end end)
    ESP:Start(); ESP:CreateMenu()
end

return ESP
