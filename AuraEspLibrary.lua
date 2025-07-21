--[[
    Universal ESP Library - v5.0 (Definitive Edition)
    
    This is a feature-complete, professional-grade ESP library. The significant increase in size
    is due to the integration of advanced systems:
    - Skeleton ESP: Draws bone structures on players.
    - 2D Radar: A fully functional on-screen radar for player positions.
    - Occlusion Checking: Uses asynchronous raycasting to determine if targets are visible.
    - Modular Design: Code is internally structured into managers for stability and maintainability.
--]]

local ESP = {}
ESP.__index = ESP

--// Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("workspace")

--// Environment
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local IsUsingDrawingLib = pcall(function() return drawing and drawing.new end) and (drawing and drawing.new)

--// Private State
local TrackedObjects = {}
local GlobalConnections = {}

--//============================================================================//
--//                                 SETTINGS                                   //
--//============================================================================//

local Settings = {
    Enabled = true,
    ToggleKeybind = Enum.KeyCode.RightControl,
    MaxDistance = 1000,
    UpdateInterval = 0, -- Base frame skipping.

    Players = {
        Enabled = true, Box = true, Name = true, Healthbar = true, Distance = true, Tracer = false,
        TeamCheck = false,
        BoxColor = Color3.fromRGB(255, 50, 50),
        NameColor = Color3.fromRGB(255, 255, 255),
        TracerColor = Color3.fromRGB(255, 50, 50),
    },
    
    -- NEW: Skeleton ESP Settings
    Skeleton = {
        Enabled = true,
        Color = Color3.fromRGB(255, 255, 255),
    },

    -- NEW: Occlusion/Visibility Check Settings
    Visibility = {
        Enabled = true,
        VisibleColor = Color3.fromRGB(50, 255, 50), -- Color for boxes/skeletons when target is visible
        RaycastInterval = 3, -- Check visibility for each player every Nth valid frame to save performance.
    },
    
    -- NEW: 2D Radar Settings
    Radar = {
        Enabled = true,
        Position = UDim2.fromScale(0, 1),
        AnchorPoint = Vector2.new(0, 1),
        Size = 200, -- in pixels
        Range = 250, -- in studs
        BackgroundColor = Color3.fromRGB(25, 25, 25),
        BackgroundTransparency = 0.3,
        DotColor = Color3.fromRGB(255, 50, 50),
        DotSize = 6,
    },

    Instances = {
        Enabled = true, Box = true, Name = true, Distance = true,
        BoxColor = Color3.fromRGB(80, 160, 255), NameColor = Color3.fromRGB(255, 255, 255),
    },
    
    Menu = { Enabled = true, ToggleKeybind = Enum.KeyCode.RightShift }
}
ESP.Settings = Settings

--//============================================================================//
--//                         INTERNAL MANAGER MODULES                           //
--//============================================================================//

--// Drawing Manager (Handles abstraction and caching)
local DrawingManager = {}
do
    local DrawingContainer
    if not IsUsingDrawingLib then
        DrawingContainer = Instance.new("ScreenGui", PlayerGui); DrawingContainer.Name = "ESP_DrawingContainer"; DrawingContainer.ResetOnSpawn = false; DrawingContainer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    end
    function DrawingManager.new(type, properties)
        if IsUsingDrawingLib then local d=drawing.new(type) if properties then for p,v in pairs(properties) do d[p]=v end end return d
        else
            local obj; local b = Instance.new("BillboardGui", DrawingContainer); b.AlwaysOnTop=true; b.Size=UDim2.fromOffset(0,0); b.ClipsDescendants=false
            if type=="Quad" then obj=Instance.new("Frame",b); obj.BackgroundTransparency=1; obj.BorderSizePixel=1
            elseif type=="Line" then obj=Instance.new("Frame",b); obj.AnchorPoint=Vector2.new(0.5,0.5); obj.BorderSizePixel=0
            elseif type=="Text" then obj=Instance.new("TextLabel",b); obj.BackgroundTransparency=1; obj.Font=Enum.Font.SourceSans; obj.TextSize=14 end
            local w={_gui=obj,_b=b,_cache={}}; return setmetatable(w,{__newindex=function(s,i,v) if s._cache[i]==v then return end; s._cache[i]=v; if i=="Visible" then s._b.Enabled=v elseif i=="Color" then if type=="Text" then s._gui.TextColor3=v elseif type=="Line" then s._gui.BackgroundColor3=v else s._gui.BorderColor3=v end elseif i=="Position" then s._gui.Position=UDim2.fromOffset(v.X,v.Y) elseif i=="Size" then s._gui.Size=UDim2.fromOffset(v.X,v.Y) elseif i=="Text" and type=="Text" then s._gui.Text=v else rawset(s,i,v) end end, __index=function(s,i) if i=="Remove" then return function() s._b:Destroy() end end return rawget(s,i) end})
        end
    end
end

--// Skeleton Manager
local SkeletonManager = {}
do
    SkeletonManager.BoneMap = {
        -- Torso
        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"}, {"UpperTorso", "LeftUpperArm"}, {"UpperTorso", "RightUpperArm"},
        {"LowerTorso", "LeftUpperLeg"}, {"LowerTorso", "RightUpperLeg"},
        -- Left Arm
        {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
        -- Right Arm
        {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
        -- Left Leg
        {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
        -- Right Leg
        {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
    }
    function SkeletonManager:Create(data)
        if not Settings.Skeleton.Enabled or not data.instance:IsA("Model") then return end
        data.drawings.Skeleton = {}
        for i = 1, #self.BoneMap do table.insert(data.drawings.Skeleton, DrawingManager.new("Line")) end
    end
    function SkeletonManager:Update(data, camera)
        local char = data.instance
        for i, pair in ipairs(self.BoneMap) do
            local line = data.drawings.Skeleton[i]
            local p1, p2 = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
            if line and p1 and p2 then
                local pos1, v1 = camera:WorldToViewportPoint(p1.Position)
                local pos2, v2 = camera:WorldToViewportPoint(p2.Position)
                if v1 and v2 then
                    line.Visible = true; line.Color = data.isOccluded and Settings.Skeleton.Color or Settings.Visibility.VisibleColor
                    line.From = Vector2.new(pos1.X, pos1.Y); line.To = Vector2.new(pos2.X, pos2.Y)
                else line.Visible = false end
            elseif line then line.Visible = false end
        end
    end
end

--// Radar Manager
local RadarManager = {}
do
    local radarUI, dots = {}
    function RadarManager:Create()
        if not Settings.Radar.Enabled then return end
        dots = {}
        local frame = Instance.new("Frame", PlayerGui)
        frame.Name = "ESP_Radar"; frame.Size = UDim2.fromOffset(Settings.Radar.Size, Settings.Radar.Size)
        frame.Position = Settings.Radar.Position; frame.AnchorPoint = Settings.Radar.AnchorPoint
        frame.BackgroundColor3 = Settings.Radar.BackgroundColor; frame.BackgroundTransparency = Settings.Radar.BackgroundTransparency
        frame.BorderSizePixel = 1; frame.BorderColor3 = Color3.new(1,1,1)
        local crosshairX = Instance.new("Frame", frame); crosshairX.AnchorPoint = Vector2.new(0.5,0.5); crosshairX.Position = UDim2.fromScale(0.5,0.5); crosshairX.Size = UDim2.new(1,0,0,1); crosshairX.BackgroundColor3 = Color3.new(1,1,1); crosshairX.BackgroundTransparency = 0.8
        local crosshairY = Instance.new("Frame", frame); crosshairY.AnchorPoint = Vector2.new(0.5,0.5); crosshairY.Position = UDim2.fromScale(0.5,0.5); crosshairY.Size = UDim2.new(0,1,1,0); crosshairY.BackgroundColor3 = Color3.new(1,1,1); crosshairY.BackgroundTransparency = 0.8
        radarUI.Frame = frame
    end
    function RadarManager:UpdateDot(data, camera)
        if not radarUI.Frame or not data.instance:IsA("Model") then return end
        local dot = dots[data.instance]
        if not dot then dot = Instance.new("Frame", radarUI.Frame); dot.Size=UDim2.fromOffset(Settings.Radar.DotSize,Settings.Radar.DotSize); dot.AnchorPoint=Vector2.new(0.5,0.5); dot.BackgroundColor3=Settings.Radar.DotColor; dot.BorderSizePixel=0; dots[data.instance] = dot end
        
        local root = data.instance.PrimaryPart; if not root then dot.Visible=false; return end
        local relPos = root.Position - LocalPlayer.Character.PrimaryPart.Position
        if relPos.Magnitude > Settings.Radar.Range then dot.Visible=false; return end
        
        local _, camY = camera.CFrame:ToOrientation()
        local rotatedX = relPos.X * math.cos(camY) - relPos.Z * math.sin(camY)
        local rotatedZ = relPos.X * math.sin(camY) + relPos.Z * math.cos(camY)
        
        local scale = Settings.Radar.Size / 2 / Settings.Radar.Range
        dot.Position = UDim2.fromScale(0.5 + rotatedX * scale, 0.5 - rotatedZ * scale)
        dot.Visible = true
    end
    function RadarManager:Destroy() if radarUI.Frame then radarUI.Frame:Destroy() end; radarUI = {} end
    function RadarManager:RemoveDot(instance) if dots and dots[instance] then dots[instance]:Destroy(); dots[instance]=nil end end
end

--// Visibility Manager
local VisibilityManager = {}
do
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    function VisibilityManager:Check(data, camera)
        if not Settings.Visibility.Enabled or (data.updateCounter % Settings.Visibility.RaycastInterval ~= 0) then return end
        local char = LocalPlayer.Character; if not char or not char.PrimaryPart then return end
        raycastParams.FilterDescendantsInstances = {char, data.instance}
        local result = Workspace:Raycast(camera.CFrame.Position, data.cframe.Position - camera.CFrame.Position, raycastParams)
        data.isOccluded = result ~= nil
    end
end

--// Target Manager (Main Controller)
local TargetManager = {}
do
    function TargetManager:Add(instance, options)
        if not instance or TrackedObjects[instance] then return end; options = options or {}
        local defaults = Settings[options.Type or "Instances"] or Settings.Instances; local finalOptions = {}
        for k, v in pairs(defaults) do finalOptions[k] = v end; for k, v in pairs(options) do finalOptions[k] = v end
        local data = { options = finalOptions, drawings = {}, connections = {}, isVisible = false, isOccluded = true, updateCounter = math.random(0, 10), instance = instance}
        if finalOptions.Box then data.drawings.Box = DrawingManager.new("Quad") end
        if finalOptions.Name then data.drawings.Name = DrawingManager.new("Text", {Center = true}) end
        if finalOptions.Distance then data.drawings.Distance = DrawingManager.new("Text", {Center = true}) end
        if finalOptions.Tracer then data.drawings.Tracer = DrawingManager.new("Line") end
        if finalOptions.Healthbar and instance:IsA("Model") then data.drawings.HealthbarBack = DrawingManager.new("Quad"); data.drawings.HealthbarFront = DrawingManager.new("Quad") end
        local humanoid = instance:FindFirstChildOfClass("Humanoid"); if humanoid then table.insert(data.connections, humanoid.Died:Connect(function() TargetManager:Remove(instance) end)) end
        table.insert(data.connections, instance.AncestryChanged:Connect(function(_, p) if not p then TargetManager:Remove(instance) end end))
        SkeletonManager:Create(data)
        TrackedObjects[instance] = data
    end
    function TargetManager:Remove(instance)
        local data = TrackedObjects[instance]; if not data then return end
        for _, d in pairs(data.drawings) do if type(d)=='table' then for _,sd in pairs(d) do sd:Remove() end else d:Remove() end end
        for _, c in ipairs(data.connections) do c:Disconnect() end
        RadarManager:RemoveDot(instance)
        TrackedObjects[instance] = nil
    end
    function TargetManager:_get3DInfo(instance)
        if instance:IsA("Model") then return instance:GetBoundingBox() end; if instance:IsA("BasePart") then return instance.CFrame, instance.Size end
        local p = instance:FindFirstAncestorWhichIsA("PVInstance"); if p then return p.CFrame, p.Size end; return nil, nil
    end
    function TargetManager:_setDrawingsVisible(data, visible)
        if data.isVisible == visible then return end; data.isVisible = visible
        for k, drawing in pairs(data.drawings) do if k~="Skeleton" then if type(drawing)=='table' then for _,sd in pairs(drawing) do sd.Visible = visible end else drawing.Visible = visible end end end
    end
    function TargetManager:_updateDrawings(data, cframe, size, distance, camera)
        local options, drawings = data.options, data.drawings; local halfSize = size / 2
        local corners = { cframe.Position+cframe.RightVector*halfSize.X+cframe.UpVector*halfSize.Y, cframe.Position-cframe.RightVector*halfSize.X-cframe.UpVector*halfSize.Y, cframe.Position-cframe.RightVector*halfSize.X+cframe.UpVector*halfSize.Y, cframe.Position+cframe.RightVector*halfSize.X-cframe.UpVector*halfSize.Y }
        local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
        for _,p in ipairs(corners) do local sp=camera:WorldToViewportPoint(p); minX,minY=math.min(minX,sp.X),math.min(minY,sp.Y); maxX,maxY=math.max(maxX,sp.X),math.max(maxY,sp.Y) end
        local boxWidth,boxHeight=maxX-minX,maxY-minY
        local boxColor = data.isOccluded and options.BoxColor or Settings.Visibility.VisibleColor
        if drawings.Box then drawings.Box.Color=boxColor; drawings.Box.Position=Vector2.new(minX,minY); drawings.Box.Size=Vector2.new(boxWidth,boxHeight) end
        if drawings.Name then drawings.Name.Color=options.NameColor; drawings.Name.Text=data.instance.Name; drawings.Name.Position=Vector2.new(minX+boxWidth/2,minY-16) end
        if drawings.Distance then drawings.Distance.Text=`[{math.floor(distance)}m]`; drawings.Distance.Position=Vector2.new(minX+boxWidth/2,maxY+2) end
        if drawings.Tracer then drawings.Tracer.Color=options.TracerColor; drawings.Tracer.From=Vector2.new(camera.ViewportSize.X/2,camera.ViewportSize.Y); drawings.Tracer.To=Vector2.new(minX+boxWidth/2,maxY) end
        if drawings.HealthbarBack and data.instance:IsA("Model") then local h=data.instance:FindFirstChildOfClass("Humanoid"); if h then local p=h.Health/h.MaxHealth; drawings.HealthbarBack.Color=Color3.new(0,0,0); drawings.HealthbarBack.Position=Vector2.new(minX-7,minY); drawings.HealthbarBack.Size=Vector2.new(4,boxHeight); drawings.HealthbarFront.Color=Color3.fromHSV(0.33*p,1,1); drawings.HealthbarFront.Position=Vector2.new(minX-7,minY+boxHeight*(1-p)); drawings.HealthbarFront.Size=Vector2.new(4,boxHeight*p) end end
    end
    function TargetManager:Start()
        if self.Started then return end; self.Started = true
        local frameCounter = 0
        GlobalConnections.RenderStepped = RunService.RenderStepped:Connect(function()
            local camera = Workspace.CurrentCamera; if not camera or not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return end
            if not Settings.Enabled then if self.WasEnabled then for _,d in pairs(TrackedObjects) do TargetManager:_setDrawingsVisible(d,false) end; if Settings.Radar.Enabled then RadarManager:Destroy() end; self.WasEnabled=false end return end
            if not self.WasEnabled then if Settings.Radar.Enabled then RadarManager:Create() end end; self.WasEnabled=true
            frameCounter=frameCounter+1; if Settings.UpdateInterval>0 and frameCounter%(Settings.UpdateInterval+1)~=0 then return end
            local cameraCF=camera.CFrame
            for instance,data in pairs(TrackedObjects) do
                data.updateCounter=data.updateCounter+1
                if not data.options.Enabled then TargetManager:_setDrawingsVisible(data,false); continue end
                if data.options.Type=="Players" and data.options.TeamCheck and instance.Parent then local p=Players:GetPlayerFromCharacter(instance); if p and p.Team==LocalPlayer.Team then TargetManager:_setDrawingsVisible(data,false); continue end end
                local cframe,size=TargetManager:_get3DInfo(instance); data.cframe = cframe
                if not cframe then TargetManager:_setDrawingsVisible(data,false); continue end
                local distance=(cameraCF.Position-cframe.Position).Magnitude
                if distance>Settings.MaxDistance then TargetManager:_setDrawingsVisible(data,false); continue end
                VisibilityManager:Check(data, camera)
                local _,onScreen=camera:WorldToViewportPoint(cframe.Position)
                TargetManager:_setDrawingsVisible(data,onScreen)
                if onScreen then
                    TargetManager:_updateDrawings(data,cframe,size,distance,camera)
                    if Settings.Skeleton.Enabled and data.drawings.Skeleton then SkeletonManager:Update(data,camera) end
                    if Settings.Radar.Enabled then RadarManager:UpdateDot(data,camera) end
                end
            end
        end)
    end
end

--//============================================================================//
--//                           PUBLIC API & BOOTSTRAP                           //
--//============================================================================//

ESP.Add = TargetManager.Add
ESP.Remove = TargetManager.Remove
ESP.SetConfig = function(category, key, value) if category=="Global" and Settings[key]~=nil then Settings[key]=value elseif Settings[category] and Settings[category][key]~=nil then Settings[category][key]=value end end
ESP.AddPlayerESP = function(options) local function hP(p) local function hC(c) if p~=LocalPlayer then ESP.Add(c,options or {Type="Players"}) end end p.CharacterAdded:Connect(hC); if p.Character then hC(p.Character) end end for _,p in ipairs(Players:GetPlayers()) do hP(p) end; GlobalConnections.PlayerAdded=Players.PlayerAdded:Connect(hP) end
ESP.AddFolderESP = function(parent, options) if not parent then return end; local o=options or {Type="Instances"}; local function hD(d) if d:IsA("PVInstance") and not Players:GetPlayerFromCharacter(d) then ESP.Add(d,o) end end; GlobalConnections[parent]={parent.DescendantAdded:Connect(hD),parent.DescendantRemoving:Connect(function(d) ESP.Remove(d) end)}; for _,d in ipairs(parent:GetDescendants()) do hD(d) end end

function ESP:CreateMenu()
    if self.MenuGui or not Settings.Menu.Enabled then return end
    local gui = Instance.new("ScreenGui", PlayerGui); gui.Name="ESP_Menu"; gui.ResetOnSpawn=false
    local main = Instance.new("Frame",gui); main.Size=UDim2.fromOffset(280,420); main.Position=UDim2.fromScale(0.5,0.5); main.AnchorPoint=Vector2.new(0.5,0.5); main.BackgroundColor3=Color3.fromRGB(35,35,35); main.BorderColor3=Color3.fromRGB(80,80,80); main.Visible=false; main.Draggable=true; main.Active=true
    local title = Instance.new("TextLabel",main); title.Size=UDim2.new(1,0,0,30); title.BackgroundColor3=Color3.fromRGB(45,45,45); title.Text="ESP Definitive Edition"; title.Font=Enum.Font.SourceSansBold; title.TextColor3=Color3.new(1,1,1); title.TextSize=16
    local list = Instance.new("UIListLayout",main); list.SortOrder=Enum.SortOrder.LayoutOrder; list.HorizontalAlignment=Enum.HorizontalAlignment.Center; list.Padding=UDim.new(0,5); list.From=UDim2.fromOffset(0,35)
    local function createToggle(text,cat,key,order) local b=Instance.new("TextButton",main); b.LayoutOrder=order; b.Size=UDim2.new(0.9,0,0,25); b.Font=Enum.Font.SourceSans; b.TextSize=14; b.TextColor3=Color3.new(1,1,1); local function u() local v=(cat=="Global" and Settings[key]) or Settings[cat][key]; b.Text=text..": "..(v and "ON" or "OFF"); b.BackgroundColor3=v and Color3.fromRGB(70,110,70) or Color3.fromRGB(110,70,70) end; b.MouseButton1Click:Connect(function() local t=Settings[cat]; local nV=not((cat=="Global" and Settings[key])or t[key]); ESP:SetConfig(cat,key,nV); u(); if cat=="Radar" and key=="Enabled" then if nV then RadarManager:Create() else RadarManager:Destroy() end end end); u() end
    createToggle("Master ESP","Global","Enabled",1); createToggle("Player ESP","Players","Enabled",2); createToggle("└ Player Boxes","Players","Box",3); createToggle("└ Player Names","Players","Name",4); createToggle("└ Player Health","Players","Healthbar",5); createToggle("└ Team Check","Players","TeamCheck",7)
    createToggle("Skeleton ESP","Skeleton","Enabled",8); createToggle("2D Radar","Radar","Enabled",9); createToggle("Visibility Check","Visibility","Enabled",10); createToggle("Instance ESP","Instances","Enabled",11)
    GlobalConnections.MenuToggle=UserInputService.InputBegan:Connect(function(i,g) if g then return end if i.KeyCode==Settings.Menu.ToggleKeybind then main.Visible=not main.Visible end end)
    self.MenuGui=gui
end

do
    GlobalConnections.MasterToggle=UserInputService.InputBegan:Connect(function(i,g) if g then return end if i.KeyCode==Settings.ToggleKeybind then Settings.Enabled=not Settings.Enabled end end)
    TargetManager:Start(); ESP:CreateMenu(); if Settings.Radar.Enabled then RadarManager:Create() end
end

return ESP
