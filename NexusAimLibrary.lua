--[[
███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗
████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝
██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗
██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║
██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║
╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
Version: 1.0.0
Author: Gemini Advanced
Description:
A comprehensive and highly customizable Aim Assistance library for Roblox.
This library provides a framework for programmatically controlling the camera to assist
in aiming at targets. It is designed to be educational, demonstrating concepts like
PID controllers for smoothing, target validation, and CFrame manipulation.

Features:
- Advanced PID Smoothing: Creates natural, non-robotic camera movement.
- Rich Targeting System: Filters by FOV, distance, visibility, team, etc.
- Movement Prediction: Aims where the target is going, not where it is.
- Recoil Control System (RCS): Helps compensate for weapon recoil.
- Debug Visuals: On-screen display for FOV and target lines.
- Modular API: Easy to integrate and control via a LocalScript.

This script is for educational purposes only.
--]]

--//================================================================================================//
--//                                      LIBRARY INITIALIZATION                                    //
--//================================================================================================//

local Nexus = {}
Nexus.VERSION = "1.0.0"

--//================================================================================================//
--//                                         CORE SERVICES                                          //
--//================================================================================================//

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

--//================================================================================================//
--//                                       PRIVATE STATE & CACHE                                    //
--//================================================================================================//

local _private = {
    -- Active state
    IsInitialized = false,
    IsRunning = false, -- Master switch, controlled by the public API
    IsAiming = false, -- True when the aim key is active
    ToggledOn = false, -- State for the "Toggle" mode

    -- Core references
    LocalPlayer = nil,
    Camera = nil,
    CurrentTarget = nil,

    -- Connections and signals
    Connections = {},
    
    -- PID Controllers for smoothing (one for horizontal, one for vertical)
    PID_X = nil,
    PID_Y = nil,
    
    -- Visual drawing objects
    Drawings = {},
}

--//================================================================================================//
--//                                      MASTER CONFIGURATION                                      //
--//================================================================================================//
--[[
This table holds all user-configurable settings for the aim assistance.
Modify these values before calling Nexus.Init() to customize the behavior.
--]]
Nexus.Config = {
    --==================================// Global Settings //==================================--
    Enabled = true,          -- Master switch for the entire library.
    AimKey = Enum.KeyCode.E, -- The key to hold or toggle for aiming.
    AimMode = "Hold",        -- "Hold" (aims while key is down) or "Toggle".
    
    --==================================// Targeting Filters //==================================--
    Targeting = {
        TargetPart = "Head",          -- "Head" or "HumanoidRootPart". The part to aim at.
        MaxDistance = 500,            -- Maximum distance in studs to acquire a target. 0 for infinite.
        FieldOfView = 150,            -- Radius in pixels from the center of the screen to lock on.
        RequiresLineOfSight = true,   -- If true, won't target players behind walls.
        TeamCheck = true,             -- If true, won't target players on the same team.
        FriendCheck = false,          -- If true, won't target Roblox friends.
    },
    
    --===============================// Aiming & Smoothing (PID) //===============================--
    Aiming = {
        -- A PID Controller creates smooth, organic movement.
        -- P (Proportional): The main driving force. Higher = faster snap.
        -- I (Integral): Corrects for small, steady-state errors. Prevents "drooping".
        -- D (Derivative): Dampens the movement to prevent overshooting. Higher = less oscillation.
        
        -- Good starting values for a snappy but smooth feel.
        P = 0.15,
        I = 0.3,
        D = 0.015,
        
        -- Prediction attempts to aim where the target *will be*.
        Prediction = {
            Enabled = true,
            VelocityFactor = 0.08, -- Multiplies the target's velocity. Tune based on average ping/game physics.
        },
        
        -- Recoil Control System (RCS) applies a counter-movement to the camera.
        RecoilControl = {
            Enabled = true,
            VerticalStrength = 0.3,   -- How much to pull down (0 to 1).
            HorizontalStrength = 0.1, -- How much to compensate horizontally (0 to 1).
        },
    },

    --==================================// Visual Settings //==================================--
    Visuals = {
        -- Draws a circle on screen representing the Field of View.
        DrawFOV = {
            Enabled = true,
            Color = Color3.fromRGB(255, 255, 255),
            Thickness = 1,
            Transparency = 0.5,
            Filled = false,
            NumSides = 64, -- A higher number makes the circle smoother.
        },
        -- Draws a line from the screen center to the current target.
        DrawTargetLine = {
            Enabled = false,
            Color = Color3.fromRGB(255, 0, 0),
            Thickness = 2,
        },
    },
    
    --==================================// Performance & Debugging //==================================--
    Performance = {
        RaycastParams = RaycastParams.new(), -- Pre-create RaycastParams for efficiency.
    },
}

-- Configure RaycastParams to ignore the local player's character.
Nexus.Config.Performance.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

--//================================================================================================//
--//                                        PID CONTROLLER CLASS                                    //
--//================================================================================================//

local PIDController = {}
PIDController.__index = PIDController

--- Creates a new PID Controller instance.
function PIDController.new(p, i, d)
    local self = setmetatable({}, PIDController)
    self.p = p or 0
    self.i = i or 0
    self.d = d or 0
    self.integral = 0
    self.previous_error = 0
    return self
end

--- Updates the PID controller with a new error value.
-- @param error (number) The difference between the target and current value.
-- @param dt (number) DeltaTime, the time since the last update.
-- @return (number) The corrective force to apply.
function PIDController:Update(error, dt)
    self.integral = self.integral + error * dt
    local derivative = (error - self.previous_error) / dt
    self.previous_error = error
    
    return self.p * error + self.i * self.integral + self.d * derivative
end

--- Resets the controller's state.
function PIDController:Reset()
    self.integral = 0
    self.previous_error = 0
end


--//================================================================================================//
--//                                        UTILITY FUNCTIONS                                       //
--//================================================================================================//

local Utils = {}

--- Checks if a 3D position is visible from the camera.
function Utils.IsPositionVisible(targetPos, ignoreList)
    if not _private.Camera or not Nexus.Config.Targeting.RequiresLineOfSight then
        return true
    end
    
    local cameraPos = _private.Camera.CFrame.Position
    local direction = (targetPos - cameraPos).Unit
    local distance = (targetPos - cameraPos).Magnitude
    
    Nexus.Config.Performance.RaycastParams.FilterDescendantsInstances = ignoreList
    local result = Workspace:Raycast(cameraPos, direction * distance, Nexus.Config.Performance.RaycastParams)
    
    return not result
end

--- Finds the best valid target on the screen.
-- "Best" is defined as the player closest to the mouse cursor/center screen.
function Utils.GetBestTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local maxDist = math.huge
    local bestTarget = nil

    local targetingCfg = Nexus.Config.Targeting
    
    for _, player in ipairs(Players:GetPlayers()) do
        -- Basic validation checks
        if player == _private.LocalPlayer then continue end
        if targetingCfg.TeamCheck and player.Team == _private.LocalPlayer.Team then continue end
        if targetingCfg.FriendCheck and _private.LocalPlayer:IsFriendsWith(player.UserId) then continue end
        
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        local targetPart = character:FindFirstChild(targetingCfg.TargetPart)
        if not targetPart then continue end
        
        -- Distance check
        local distanceToTarget = (_private.LocalPlayer.Character.PrimaryPart.Position - targetPart.Position).Magnitude
        if targetingCfg.MaxDistance > 0 and distanceToTarget > targetingCfg.MaxDistance then
            continue
        end
        
        -- FOV check
        local screenPos, onScreen = _private.Camera:WorldToScreenPoint(targetPart.Position)
        if not onScreen then continue end
        
        local fovDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if fovDist > targetingCfg.FieldOfView then continue end
        
        -- Visibility check (can be expensive, so do it last)
        if not Utils.IsPositionVisible(targetPart.Position, { _private.LocalPlayer.Character, character }) then
            continue
        end

        -- If this target is closer to the crosshair, it's our new best target
        if fovDist < maxDist then
            maxDist = fovDist
            bestTarget = player
        end
    end
    
    return bestTarget
end

--- Toggles a drawing object's visibility and clears its cache if unused.
function Utils.SetDrawingVisible(name, visible)
    if _private.Drawings[name] then
        _private.Drawings[name].Visible = visible
        if not visible then
            _private.Drawings[name]:Remove()
            _private.Drawings[name] = nil
        end
    end
end

--//================================================================================================//
--//                                     CORE AIMING & DRAWING                                      //
--//================================================================================================//

local Core = {}

--- Main update loop, called every frame by RenderStepped.
function Core.OnRenderStep(dt)
    if not _private.IsRunning or not Nexus.Config.Enabled then return end
    
    _private.Camera = Workspace.CurrentCamera
    if not _private.Camera then return end
    
    Core.UpdateVisuals()
    
    if _private.IsAiming then
        -- If we have a target, keep aiming. If not, try to find a new one.
        if not Core.IsTargetStillValid(_private.CurrentTarget) then
            _private.CurrentTarget = Utils.GetBestTarget()
            -- Reset PID to prevent sudden jolts when switching targets
            _private.PID_X:Reset()
            _private.PID_Y:Reset()
        end
        
        if _private.CurrentTarget then
            Core.AimAtTarget(_private.CurrentTarget, dt)
        end
    else
        _private.CurrentTarget = nil
    end
end

--- Aims the camera at the given target using PID smoothing.
function Core.AimAtTarget(target, dt)
    local character = target.Character
    local targetPart = character and character:FindFirstChild(Nexus.Config.Targeting.TargetPart)
    if not targetPart then return end

    local targetPos = targetPart.Position
    
    -- Apply prediction
    if Nexus.Config.Aiming.Prediction.Enabled and character.PrimaryPart then
        targetPos += character.PrimaryPart.AssemblyLinearVelocity * Nexus.Config.Aiming.Prediction.VelocityFactor
    end

    -- Calculate the vector from camera to target
    local camCFrame = _private.Camera.CFrame
    local lookVector = (targetPos - camCFrame.Position).Unit
    
    -- Calculate the error (difference between where we are looking and where we want to look)
    -- We can get this by finding the angle between the current look vector and the desired one.
    local currentLookVector = camCFrame.LookVector
    local rotationAxis = currentLookVector:Cross(lookVector) -- The axis to rotate around
    local angleError = math.acos(math.clamp(currentLookVector:Dot(lookVector), -1, 1))

    -- Update PID controllers
    local correction_X = _private.PID_X:Update(angleError * rotationAxis.Y, dt)
    local correction_Y = _private.PID_Y:Update(angleError * rotationAxis.X, dt)

    -- Apply RCS (Recoil Control System)
    if Nexus.Config.Aiming.RecoilControl.Enabled then
        local rcs = Nexus.Config.Aiming.RecoilControl
        -- This is a simplified example. A real RCS would get recoil data from a weapon.
        -- Here we just apply a steady pull-down.
        correction_Y = correction_Y - (rcs.VerticalStrength * dt * 10) 
    end
    
    -- Apply the smoothed correction to the camera CFrame
    local newCFrame = camCFrame * CFrame.Angles(correction_Y, -correction_X, 0)
    _private.Camera.CFrame = newCFrame
end

--- Checks if the current target is still valid according to the rules.
function Core.IsTargetStillValid(target)
    if not target or not target.Parent then return false end
    
    local character = target.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    local targetPart = character:FindFirstChild(Nexus.Config.Targeting.TargetPart)
    if not targetPart then return false end
    
    -- Re-run the most important checks
    local screenPos, onScreen = _private.Camera:WorldToScreenPoint(targetPart.Position)
    if not onScreen then return false end
    
    local mousePos = UserInputService:GetMouseLocation()
    if (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude > Nexus.Config.Targeting.FieldOfView then
        return false
    end
    
    if not Utils.IsPositionVisible(targetPart.Position, { _private.LocalPlayer.Character, character }) then
        return false
    end
    
    return true
end

--- Updates the visual drawings like the FOV circle.
function Core.UpdateVisuals()
    local fovCfg = Nexus.Config.Visuals.DrawFOV
    
    -- Draw FOV Circle
    if fovCfg.Enabled then
        if not _private.Drawings.FOVCircle then
            _private.Drawings.FOVCircle = Drawing.new("Circle")
        end
        local circle = _private.Drawings.FOVCircle
        circle.Visible = true
        circle.Color = fovCfg.Color
        circle.Thickness = fovCfg.Thickness
        circle.Transparency = fovCfg.Transparency
        circle.Filled = fovCfg.Filled
        circle.Radius = Nexus.Config.Targeting.FieldOfView
        circle.NumSides = fovCfg.NumSides
        circle.Position = UserInputService:GetMouseLocation()
    else
        Utils.SetDrawingVisible("FOVCircle", false)
    end
    
    -- Draw Target Line
    local lineCfg = Nexus.Config.Visuals.DrawTargetLine
    if lineCfg.Enabled and _private.IsAiming and _private.CurrentTarget then
        local targetPart = _private.CurrentTarget.Character and _private.CurrentTarget.Character:FindFirstChild(Nexus.Config.Targeting.TargetPart)
        if targetPart then
            local screenPos, onScreen = _private.Camera:WorldToScreenPoint(targetPart.Position)
            if onScreen then
                if not _private.Drawings.TargetLine then
                    _private.Drawings.TargetLine = Drawing.new("Line")
                end
                local line = _private.Drawings.TargetLine
                line.Visible = true
                line.From = UserInputService:GetMouseLocation()
                line.To = Vector2.new(screenPos.X, screenPos.Y)
                line.Color = lineCfg.Color
                line.Thickness = lineCfg.Thickness
            else
                Utils.SetDrawingVisible("TargetLine", false)
            end
        end
    else
        Utils.SetDrawingVisible("TargetLine", false)
    end
end


--//================================================================================================//
--//                                      INPUT & EVENT HANDLERS                                    //
--//================================================================================================//

local Handlers = {}

--- Handles key presses for activating/deactivating the aimbot.
function Handlers.OnInputBegan(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Nexus.Config.AimKey then
        if Nexus.Config.AimMode == "Hold" then
            _private.IsAiming = true
        elseif Nexus.Config.AimMode == "Toggle" then
            _private.ToggledOn = not _private.ToggledOn
            _private.IsAiming = _private.ToggledOn
        end
    end
end

--- Handles key releases for "Hold" mode.
function Handlers.OnInputEnded(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Nexus.Config.AimKey then
        if Nexus.Config.AimMode == "Hold" then
            _private.IsAiming = false
            _private.CurrentTarget = nil -- Drop target immediately
        end
    end
end


--//================================================================================================//
--//                                         PUBLIC API                                             //
--//================================================================================================//

--- Initializes the Nexus Aim library.
-- Sets up local player, PID controllers, and connects to game events.
function Nexus.Init()
    if _private.IsInitialized then
        warn("[Nexus] Library is already initialized.")
        return
    end

    _private.LocalPlayer = Players.LocalPlayer
    if not _private.LocalPlayer then
        _private.LocalPlayer = Players.PlayerAdded:Wait()
    end
    
    if not _private.LocalPlayer.Character then
        _private.LocalPlayer.CharacterAdded:Wait()
    end
    Nexus.Config.Performance.RaycastParams.FilterDescendantsInstances = { _private.LocalPlayer.Character }
    
    -- Create PID controllers
    local pidCfg = Nexus.Config.Aiming
    _private.PID_X = PIDController.new(pidCfg.P, pidCfg.I, pidCfg.D)
    _private.PID_Y = PIDController.new(pidCfg.P, pidCfg.I, pidCfg.D)

    -- Connect events
    RunService:BindToRenderStep("NexusAim_Update", Enum.RenderPriority.Camera.Value, Core.OnRenderStep)
    table.insert(_private.Connections, UserInputService.InputBegan:Connect(Handlers.OnInputBegan))
    table.insert(_private.Connections, UserInputService.InputEnded:Connect(Handlers.OnInputEnded))

    _private.IsInitialized = true
    _private.IsRunning = true

    print("[Nexus] Aim Library Initialized. Version " .. Nexus.VERSION)
end

--- Toggles the entire library on or off.
-- @param state (boolean) True to enable, false to disable.
function Nexus.SetEnabled(state)
    Nexus.Config.Enabled = state
    _private.IsRunning = state
    if not state then
        -- If disabled, stop aiming and clear visuals
        _private.IsAiming = false
        _private.ToggledOn = false
        _private.CurrentTarget = nil
        Core.UpdateVisuals() -- One last call to hide everything
    end
    print("[Nexus] Library set to: " .. tostring(state))
end

--- Destroys the library instance, disconnecting all events and cleaning up.
function Nexus.Destroy()
    if not _private.IsInitialized then return end

    RunService:UnbindFromRenderStep("NexusAim_Update")
    
    for _, conn in ipairs(_private.Connections) do
        conn:Disconnect()
    end
    table.clear(_private.Connections)
    
    for _, drawing in pairs(_private.Drawings) do
        drawing:Remove()
    end
    table.clear(_private.Drawings)

    _private.IsInitialized = false
    _private.IsRunning = false
    _private.IsAiming = false

    print("[Nexus] Library destroyed and cleaned up.")
end

--//================================================================================================//
--//                                           RETURN                                               //
--//================================================================================================//

return Nexus
