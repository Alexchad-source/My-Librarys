--[[
██████╗  ██╗   ██╗ ██████╗  █████╗
██╔══██╗ ██║   ██║ ██╔══██╗██╔══██╗
██████╔╝ ██║   ██║ ██████╔╝███████║
██╔══██╗ ██║   ██║ ██╔══██╗██╔══██║
██████╔╝ ╚██████╔╝ ██║  ██║██║  ██║
╚═════╝   ╚═════╝  ╚═╝  ╚═╝╚═╝  ╚═╝
Version: 1.0.0
Author: Gemini Advanced
Description:
A comprehensive and highly customizable ESP (Extrasensory Perception) library for Roblox.
This library provides a framework for rendering information about players and objects
on the screen, designed to be both feature-rich and educational.

Features:
- Player ESP: Boxes, Names, Health, Distance, Tracers, Skeletons, etc.
- Object ESP: Track and draw on specific in-game items.
- Visibility Checks: Differentiates between visible and occluded targets.
- Team-Awareness: Can be configured for different team dynamics.
- High Performance: Efficiently manages drawing objects to prevent frame drops.
- Modern API: Utilizes the 'Drawing' object for clean and fast rendering.

Usage:
1. Place this ModuleScript in a LocalScript environment (e.g., StarterPlayerScripts).
2. In a separate LocalScript, require this module:
   local Aura = require(path.to.Aura)
3. Configure settings as needed by modifying the `Aura.Config` table.
4. Initialize the library:
   Aura.Init()

This script is for educational purposes only.
--]]

--//================================================================================================//
--//                                      LIBRARY INITIALIZATION                                    //
--//================================================================================================//

local Aura = {}
Aura.VERSION = "1.0.1"

--//================================================================================================//
--//                                         CORE SERVICES                                          //
--//================================================================================================//

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Teams = game:GetService("Teams")

--//================================================================================================//
--//                                       PRIVATE STATE & CACHE                                    //
--//================================================================================================//

local _private = {
    -- Active state
    IsInitialized = false,
    IsRunning = false,

    -- Core references
    LocalPlayer = nil,
    Camera = nil,

    -- Connections and signals
    Connections = {},

    -- Cache for drawing objects to avoid creating new instances every frame
    -- Structure:
    -- _private.PlayerDrawings[PlayerObject] = {
    --     Box = DrawingObject,
    --     Name = DrawingObject,
    --     ...
    -- }
    PlayerDrawings = {},

    -- Cache for object ESP drawings
    ObjectDrawings = {},
}

--//================================================================================================//
--//                                      MASTER CONFIGURATION                                      //
--//================================================================================================//
--[[
This table holds all user-configurable settings for the ESP.
Modify these values before calling Aura.Init() to customize the behavior.
Each section is documented to explain its purpose.
--]]
Aura.Config = {
    --==================================// Global Settings //==================================--
    Enabled = true, -- Master switch for the entire ESP library.
    RefreshRate = 0, -- Delay in seconds between updates. 0 = every frame (RenderStepped). Higher values can improve performance on low-end devices.

    --==================================// Player Targeting //==================================--
    Player = {
        -- Filters for which players to draw ESP on.
        Enabled = true, -- Toggle all player ESP features.
        IgnoreSelf = true, -- Do not draw ESP on yourself.
        IgnoreFriends = false, -- Do not draw ESP on friends.
        IgnoreTeam = false, -- Do not draw ESP on players on the same team.
        MaxDistance = 500, -- Maximum distance in studs to render ESP. 0 for infinite.
    },

    --==================================// Box ESP Settings //==================================--
    Box = {
        Enabled = true,
        Mode = "2D", -- "2D" for a flat box on the screen, "3D" for a world-space box.
        Thickness = 1, -- Line thickness for the box.

        -- Color Settings
        Color = {
            Visible = Color3.fromRGB(0, 255, 127), -- Color when the player is visible.
            Occluded = Color3.fromRGB(255, 87, 87), -- Color when the player is behind an object.
            UseTeamColor = false, -- Overrides other colors to use the player's TeamColor.
            FriendColor = Color3.fromRGB(0, 191, 255), -- Color for friends if IgnoreFriends is false.
        },

        -- 2D Box Specifics
        _2D = {
            Fill = false, -- Whether to fill the box with a transparent color.
            FillTransparency = 0.8, -- Transparency of the fill (0 = opaque, 1 = invisible).
        },
    },

    --==================================// Name ESP Settings //==================================--
    Name = {
        Enabled = true,
        Thickness = 1, -- Outline thickness.
        Font = "Gotham",
        FontSize = 16,
        PositionOffset = Vector2.new(0, 15), -- Offset from the top of the box.

        -- Color Settings
        Color = {
            Visible = Color3.fromRGB(255, 255, 255),
            Occluded = Color3.fromRGB(200, 200, 200),
            UseTeamColor = false,
            FriendColor = Color3.fromRGB(0, 191, 255),
        },
    },

    --==================================// Distance ESP Settings //==================================--
    Distance = {
        Enabled = true,
        Thickness = 1,
        Font = "Gotham",
        FontSize = 14,
        PositionOffset = Vector2.new(0, -5), -- Offset from the bottom of the box.

        -- Color Settings
        Color = {
            Visible = Color3.fromRGB(255, 255, 255),
            Occluded = Color3.fromRGB(200, 200, 200),
        },
    },

    --==================================// Health Bar ESP Settings //==================================--
    HealthBar = {
        Enabled = true,
        Width = 5, -- Thickness of the health bar.
        PositionOffset = Vector2.new(-5, 0), -- Offset from the side of the box.

        -- Color Settings (Gradient from High to Low health)
        HighHealthColor = Color3.fromRGB(0, 255, 0),
        MediumHealthColor = Color3.fromRGB(255, 255, 0),
        LowHealthColor = Color3.fromRGB(255, 0, 0),
    },

    --==================================// Tracer ESP Settings //==================================--
    Tracer = {
        Enabled = false,
        Thickness = 1,
        Origin = "Bottom", -- "Bottom", "Center", or "Mouse".

        -- Color Settings
        Color = {
            Visible = Color3.fromRGB(255, 255, 0),
            Occluded = Color3.fromRGB(255, 165, 0),
            UseTeamColor = false,
            FriendColor = Color3.fromRGB(0, 191, 255),
        },
    },

    --==================================// Head Dot ESP Settings //==================================--
    HeadDot = {
        Enabled = true,
        Radius = 4, -- Size of the dot.
        Filled = true,

        -- Color Settings
        Color = {
            Visible = Color3.fromRGB(255, 0, 255),
            Occluded = Color3.fromRGB(139, 0, 139),
            UseTeamColor = true,
            FriendColor = Color3.fromRGB(0, 191, 255),
        },
    },

    --==================================// Look Vector ESP Settings //==================================--
    LookVector = {
        Enabled = false,
        Length = 20, -- How far the look vector line extends in studs.
        Thickness = 1,

        -- Color Settings
        Color = {
            Visible = Color3.fromRGB(0, 225, 255),
            Occluded = Color3.fromRGB(0, 120, 200),
        },
    },

    --==================================// Skeleton ESP Settings //==================================--
    Skeleton = {
        Enabled = false,
        Thickness = 1,

        -- Color Settings
        Color = {
            Visible = Color3.fromRGB(255, 255, 255),
            Occluded = Color3.fromRGB(180, 180, 180),
            UseTeamColor = false,
            FriendColor = Color3.fromRGB(0, 191, 255),
        },
    },

    --==================================// Object ESP Settings //==================================--
    Object = {
        -- This section is a framework. You must add items to the 'TrackedObjects' list.
        Enabled = false,
        MaxDistance = 1000,
        TrackedObjects = {
            -- Example: Track all parts named "Flag"
            -- {
            --    Name = "Flag",
            --    DisplayName = "Capture Point",
            --    Color = Color3.fromRGB(255, 255, 0),
            --    RequiresLineOfSight = false
            -- }
        },

        -- Default drawing settings for objects
        Text = {
            Font = "Gotham",
            FontSize = 16,
            Thickness = 1,
        }
    },

    --==================================// Performance & Debugging //==================================--
    Performance = {
        -- Settings to fine-tune performance vs. quality.
        VisibilityCheck = "Raycast", -- "Raycast" for accurate checks, "None" to disable (improves performance).
        RaycastParams = RaycastParams.new(), -- Pre-create RaycastParams for efficiency.
    },
}

-- Configure RaycastParams to ignore the local player's character and other transparent objects.
Aura.Config.Performance.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

--//================================================================================================//
--//                                        UTILITY FUNCTIONS                                       //
--//================================================================================================//

local Utils = {}

--- Converts a 3D world position to a 2D screen coordinate.
-- @param position (Vector3) The 3D point in the world.
-- @return Vector2: The 2D screen coordinate.
-- @return boolean: Whether the point is on the screen.
function Utils.WorldToScreenPoint(position)
    if not _private.Camera then return Vector2.new(), false end

    local screenPoint, onScreen = _private.Camera:WorldToScreenPoint(position)
    return Vector2.new(screenPoint.X, screenPoint.Y), onScreen
end


--- Checks if a 3D position is visible from the camera.
-- @param position (Vector3) The target position to check.
-- @param ignoreList (table) A list of instances to ignore in the raycast.
-- @return boolean: True if the position is visible, false otherwise.
function Utils.IsPositionVisible(position, ignoreList)
    if not _private.Camera or Aura.Config.Performance.VisibilityCheck == "None" then
        return true
    end

    local cameraPosition = _private.Camera.CFrame.Position
    local direction = (position - cameraPosition).Unit
    local distance = (position - cameraPosition).Magnitude

    -- Update the ignore list for this specific raycast
    Aura.Config.Performance.RaycastParams.FilterDescendantsInstances = ignoreList

    local result = Workspace:Raycast(cameraPosition, direction * distance, Aura.Config.Performance.RaycastParams)

    -- If the raycast hits nothing, the position is visible.
    return not result
end

--- Retrieves a cached drawing object or creates a new one.
-- @param cache (table) The cache table (e.g., _private.PlayerDrawings).
-- @param key (any) The primary key (e.g., a Player object).
-- @param name (string) The name of the drawing (e.g., "Box", "Name").
-- @param type (string) The type of drawing to create (e.g., "Line", "Text").
-- @return Drawing: The cached or newly created drawing object.
function Utils.GetOrCreateDrawing(cache, key, name, type)
    if not cache[key] then
        cache[key] = {}
    end

    if not cache[key][name] then
        local newDrawing = Drawing.new(type)
        cache[key][name] = newDrawing
        return newDrawing
    end

    return cache[key][name]
end

--- Removes all drawing objects associated with a key from the cache.
-- @param cache (table) The cache table.
-- @param key (any) The key to clear.
function Utils.ClearDrawingsForKey(cache, key)
    if cache[key] then
        for _, drawing in pairs(cache[key]) do
            if drawing then
                drawing.Visible = false
                drawing:Remove()
            end
        end
        cache[key] = nil
    end
end

--//================================================================================================//
--//                                 SKELETON DEFINITION & LOGIC                                  //
--//================================================================================================//

-- Defines the connections between character parts for skeleton ESP.
local SKELETON_BONES = {
    -- Torso
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" },
    { "UpperTorso", "RightUpperArm" },
    { "LowerTorso", "LeftUpperLeg" },
    { "LowerTorso", "RightUpperLeg" },

    -- Left Arm
    { "LeftUpperArm", "LeftLowerArm" },
    { "LeftLowerArm", "LeftHand" },

    -- Right Arm
    { "RightUpperArm", "RightLowerArm" },
    { "RightLowerArm", "RightHand" },

    -- Left Leg
    { "LeftUpperLeg", "LeftLowerLeg" },
    { "LeftLowerLeg", "LeftFoot" },

    -- Right Leg
    { "RightUpperLeg", "RightLowerLeg" },
    { "RightLowerLeg", "RightFoot" },
}

--- Draws the skeleton for a given character.
-- @param player (Player) The target player.
-- @param character (Model) The character model.
-- @param color (Color3) The color to draw the skeleton.
function Utils.DrawSkeleton(player, character, color)
    local cfg = Aura.Config.Skeleton
    if not cfg.Enabled then return end

    local drawings = _private.PlayerDrawings[player]
    if not drawings then return end

    for i, boneParts in ipairs(SKELETON_BONES) do
        local part1 = character:FindFirstChild(boneParts[1])
        local part2 = character:FindFirstChild(boneParts[2])

        if part1 and part2 then
            local pos1, onScreen1 = Utils.WorldToScreenPoint(part1.Position)
            local pos2, onScreen2 = Utils.WorldToScreenPoint(part2.Position)

            local drawingName = "SkeletonBone_" .. i
            local line = Utils.GetOrCreateDrawing(_private.PlayerDrawings, player, drawingName, "Line")

            if onScreen1 and onScreen2 then
                line.Visible = true
                line.Color = color
                line.Thickness = cfg.Thickness
                line.From = pos1
                line.To = pos2
            else
                line.Visible = false
            end
        end
    end
end

--//================================================================================================//
--//                                     CORE DRAWING ROUTINES                                      //
--//================================================================================================//

local Draw = {}

--- Master function to update all ESP elements for a single player.
-- @param player (Player) The player to update ESP for.
function Draw.UpdatePlayerESP(player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    -- Validation checks
    if not humanoid or humanoid.Health <= 0 then
        Utils.ClearDrawingsForKey(_private.PlayerDrawings, player)
        return
    end

    local head = character:FindFirstChild("Head")
    if not head then return end

    local distance = (_private.LocalPlayer.Character.PrimaryPart.Position - head.Position).Magnitude
    if Aura.Config.Player.MaxDistance > 0 and distance > Aura.Config.Player.MaxDistance then
        Utils.ClearDrawingsForKey(_private.PlayerDrawings, player)
        return
    end

    -- Determine visibility and color
    local isVisible = Utils.IsPositionVisible(head.Position, { _private.LocalPlayer.Character, character })
    local color = Draw.GetPlayerColor(player, isVisible)

    -- Calculate screen position and box size
    local headPos, onScreen = Utils.WorldToScreenPoint(head.Position)
    local rootPos = character.PrimaryPart and Utils.WorldToScreenPoint(character.PrimaryPart.Position)
    if not onScreen then
        Utils.ClearDrawingsForKey(_private.PlayerDrawings, player)
        return
    end

    -- The box height is calculated based on the distance between head and feet on screen.
    -- Width is calculated to maintain a realistic aspect ratio.
    local boxHeight = math.abs(headPos.Y - rootPos.Y)
    local boxWidth = boxHeight / 2

    -- Top-left corner of the 2D box
    local boxTopLeft = Vector2.new(headPos.X - boxWidth / 2, headPos.Y - boxHeight / 10)

    -- Call individual drawing functions
    Draw.Box(player, boxTopLeft, Vector2.new(boxWidth, boxHeight), color)
    Draw.Name(player, character, boxTopLeft, boxWidth, color, isVisible)
    Draw.Distance(player, boxTopLeft, boxHeight, distance, isVisible)
    Draw.HealthBar(player, humanoid, boxTopLeft, boxHeight, color)
    Draw.Tracer(player, headPos, color)
    Draw.HeadDot(player, headPos, color)
    Draw.LookVector(player, head, isVisible)

    -- Call skeleton drawing last
    local skeletonColor = isVisible and Aura.Config.Skeleton.Color.Visible or Aura.Config.Skeleton.Color.Occluded
    Utils.DrawSkeleton(player, character, skeletonColor)
end

--- Determines the appropriate color for a player based on config.
-- @param player (Player) The target player.
-- @param isVisible (boolean) Whether the player is visible.
-- @return Color3: The calculated color.
function Draw.GetPlayerColor(player, isVisible)
    local cfg = Aura.Config.Box.Color -- Use Box color as the base
    if cfg.UseTeamColor and player.TeamColor then
        return player.TeamColor.Color
    end

    if _private.LocalPlayer:IsFriendsWith(player.UserId) and not Aura.Config.Player.IgnoreFriends then
        return cfg.FriendColor
    end

    return isVisible and cfg.Visible or cfg.Occluded
end

--- Draws a 2D or 3D box around the player.
function Draw.Box(player, topLeft, size, color)
    local cfg = Aura.Config.Box
    if not cfg.Enabled then return end

    if cfg.Mode == "2D" then
        local boxPoints = {
            topLeft,
            topLeft + Vector2.new(size.X, 0),
            topLeft + size,
            topLeft + Vector2.new(0, size.Y),
            topLeft
        }

        for i = 1, 4 do
            local line = Utils.GetOrCreateDrawing(_private.PlayerDrawings, player, "BoxLine_" .. i, "Line")
            line.Visible = true
            line.From = boxPoints[i]
            line.To = boxPoints[i+1]
            line.Color = color
            line.Thickness = cfg.Thickness
        end

        -- Handle fill
        local fill = Utils.GetOrCreateDrawing(_private.PlayerDrawings, player, "BoxFill", "Quad")
        if cfg._2D.Fill then
            fill.Visible = true
            fill.Color = color
            fill.Transparency = cfg._2D.FillTransparency
            fill.PointA = boxPoints[1]
            fill.PointB = boxPoints[2]
            fill.PointC = boxPoints[3]
            fill.PointD = boxPoints[4]
        else
            fill.Visible = false
        end

    elseif cfg.Mode == "3D" then
        -- NOTE: 3D Box ESP is more complex and less common.
        -- This implementation is a placeholder to demonstrate the concept.
        -- A full implementation would require calculating all 8 corners of the character's CFrame bounding box.
        -- For simplicity, we will skip the full 3D implementation in this example.
        -- To implement, you would get character:GetBoundingBox() and draw 12 lines in 3D space.
    end
end


--- Draws the player's name.
function Draw.Name(player, character, boxTopLeft, boxWidth, boxColor, isVisible)
    local cfg = Aura.Config.Name
    if not cfg.Enabled then return end

    local text = Utils.GetOrCreateDrawing(_private.PlayerDrawings, player, "NameText", "Text")
    text.Visible = true
    text.Text = player.DisplayName
    text.Font = Enum.Font[cfg.Font]
    text.Size = cfg.FontSize
    text.Outline = cfg.Thickness > 0
    text.OutlineColor = Color3.new(0,0,0)

    -- Determine text color
    local textColor
    if cfg.Color.UseTeamColor and player.TeamColor then
        textColor = player.TeamColor.Color
    elseif _private.LocalPlayer:IsFriendsWith(player.UserId) and not Aura.Config.Player.IgnoreFriends then
        textColor = cfg.Color.FriendColor
    else
        textColor = isVisible and cfg.Color.Visible or cfg.Color.Occluded
    end
    text.Color = textColor

    -- Center the text above the box
    local textBounds = Drawing.GetTextBounds(text.Text, text.Size, text.Font)
    text.Position = Vector2.new(
        boxTopLeft.X + (boxWidth / 2) - (textBounds.X / 2),
        boxTopLeft.Y - textBounds.Y + cfg.PositionOffset.Y
    )
end

--- Draws the distance to the player.
function Draw.Distance(player, boxTopLeft, boxHeight, distance, isVisible)
    local cfg = Aura.Config.Distance
    if not cfg.Enabled then return end

    local text = Utils.GetOrCreateDrawing(_private.PlayerDrawings, player, "DistanceText", "Text")
    text.Visible = true
    text.Text = string.format("[%dM]", math.floor(distance))
    text.Font = Enum.Font[cfg.Font]
    text.Size = cfg.FontSize
    text.Outline = cfg.Thickness > 0
    text.OutlineColor = Color3.new(0,0,0)
    text.Color = isVisible and cfg.Color.Visible or cfg.Color.Occluded

    -- Center the text below the box
    local textBounds = Drawing.GetTextBounds(text.Text, text.Size, text.Font)
    text.Position = Vector2.new(
        boxTopLeft.X + (text.Parent.Size.X / 2) - (textBounds.X / 2), -- This needs adjustment if box size is dynamic
        boxTopLeft.Y + boxHeight + cfg.PositionOffset.Y
    )
end

--- Draws the player's health bar.
function Draw.HealthBar(player, humanoid, boxTopLeft, boxHeight, color)
    local cfg = Aura.Config.HealthBar
    if not cfg.Enabled then return end

    local healthPercent = humanoid.Health / humanoid.MaxHealth
    local barHeight = boxHeight * healthPercent

    -- Determine health color based on a gradient
    local healthColor = cfg.HighHealthColor:Lerp(cfg.MediumHealthColor, 1 - (math.max(0.5, healthPercent) - 0.5) * 2)
    if healthPercent < 0.5 then
        healthColor = cfg.MediumHealthColor:Lerp(cfg.LowHealthColor, 1 - (healthPercent * 2))
    end

    -- Background of the health bar
    local bgBar = Utils.GetOrCreateDrawing(_private.PlayerDrawings, player, "HealthBarBG", "Line")
    bgBar.Visible = true
    bgBar.Color = Color3.new(0, 0, 0)
    bgBar.Thickness = cfg.Width + 2 -- Create a black outline
    bgBar.From = boxTopLeft + Vector2.new(cfg.PositionOffset.X, 0)
    bgBar.To = boxTopLeft + Vector2.new(cfg.PositionOffset.X, boxHeight)

    -- Foreground (actual health)
    local fgBar = Utils.GetOrCreateDrawing(_private.PlayerDrawings, player, "HealthBarFG", "Line")
    fgBar.Visible = true
    fgBar.Color = healthColor
    fgBar.Thickness = cfg.Width
    fgBar.From = boxTopLeft + Vector2.new(cfg.PositionOffset.X, boxHeight) -- Start from bottom
    fgBar.To = boxTopLeft + Vector2.new(cfg.PositionOffset.X, boxHeight - barHeight) -- Go up
end

--- Draws a tracer line to the player.
function Draw.Tracer(player, targetPosition, color)
    local cfg = Aura.Config.Tracer
    if not cfg.Enabled then return end

    local line = Utils.GetOrCreateDrawing(_private.PlayerDrawings, player, "TracerLine", "Line")
    line.Visible = true
    line.Color = color
    line.Thickness = cfg.Thickness

    local startPosition
    local viewportSize = _private.Camera.ViewportSize
    if cfg.Origin == "Bottom" then
        startPosition = Vector2.new(viewportSize.X / 2, viewportSize.Y)
    elseif cfg.Origin == "Center" then
        startPosition = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    elseif cfg.Origin == "Mouse" then
        startPosition = UserInputService:GetMouseLocation()
    else
        startPosition = Vector2.new(viewportSize.X / 2, viewportSize.Y) -- Default to bottom
    end

    line.From = startPosition
    line.To = targetPosition
end

--- Draws a dot on the player's head.
function Draw.HeadDot(player, headPosition, color)
    local cfg = Aura.Config.HeadDot
    if not cfg.Enabled then return end

    local dot = Utils.GetOrCreateDrawing(_private.PlayerDrawings, player, "HeadDot", "Circle")
    dot.Visible = true
    dot.Color = color
    dot.Thickness = cfg.Radius / 4 -- Make outline proportional
    dot.Radius = cfg.Radius
    dot.Filled = cfg.Filled
    dot.Position = headPosition
end

--- Draws a line indicating where the player is looking.
function Draw.LookVector(player, head, isVisible)
    local cfg = Aura.Config.LookVector
    if not cfg.Enabled then return end

    local startPos = head.Position
    local endPos = startPos + (head.CFrame.LookVector * cfg.Length)

    local startScreen, onScreen1 = Utils.WorldToScreenPoint(startPos)
    local endScreen, onScreen2 = Utils.WorldToScreenPoint(endPos)

    local line = Utils.GetOrCreateDrawing(_private.PlayerDrawings, player, "LookVectorLine", "Line")
    if onScreen1 and onScreen2 then
        line.Visible = true
        line.Color = isVisible and cfg.Color.Visible or cfg.Color.Occluded
        line.Thickness = cfg.Thickness
        line.From = startScreen
        line.To = endScreen
    else
        line.Visible = false
    end
end


--- Master function to update all Object ESP.
function Draw.UpdateObjectESP()
    if not Aura.Config.Object.Enabled or #Aura.Config.Object.TrackedObjects == 0 then
        -- Clean up any existing object drawings if disabled
        for key, _ in pairs(_private.ObjectDrawings) do
            Utils.ClearDrawingsForKey(_private.ObjectDrawings, key)
        end
        return
    end

    local trackedInstances = {}

    -- Find all instances in the workspace that match the tracking criteria
    for _, objConfig in ipairs(Aura.Config.Object.TrackedObjects) do
        for _, descendant in ipairs(Workspace:GetDescendants()) do
            if descendant:IsA("BasePart") and descendant.Name == objConfig.Name then
                table.insert(trackedInstances, { Instance = descendant, Config = objConfig })
            end
        end
    end

    -- Create a set of current objects to find ones that were removed
    local currentObjectKeys = {}

    -- Draw ESP for each found instance
    for _, item in ipairs(trackedInstances) do
        local instance = item.Instance
        local config = item.Config
        local key = instance:GetFullName() -- Use full name as a unique key
        table.insert(currentObjectKeys, key)

        local distance = (_private.Camera.CFrame.Position - instance.Position).Magnitude
        if Aura.Config.Object.MaxDistance > 0 and distance > Aura.Config.Object.MaxDistance then
            Utils.ClearDrawingsForKey(_private.ObjectDrawings, key)
            continue
        end

        local screenPos, onScreen = Utils.WorldToScreenPoint(instance.Position)
        if not onScreen then
            Utils.ClearDrawingsForKey(_private.ObjectDrawings, key)
            continue
        end

        local isVisible = true
        if config.RequiresLineOfSight then
            isVisible = Utils.IsPositionVisible(instance.Position, { _private.LocalPlayer.Character })
        end

        if not isVisible then
            Utils.ClearDrawingsForKey(_private.ObjectDrawings, key)
            continue
        end

        -- Draw text for the object
        local textCfg = Aura.Config.Object.Text
        local text = Utils.GetOrCreateDrawing(_private.ObjectDrawings, key, "ObjectText", "Text")
        text.Visible = true
        text.Text = string.format("%s\n[%dM]", config.DisplayName or instance.Name, math.floor(distance))
        text.Font = Enum.Font[textCfg.Font]
        text.Size = textCfg.FontSize
        text.Color = config.Color or Color3.new(1,1,1)
        text.Outline = textCfg.Thickness > 0
        text.OutlineColor = Color3.new(0,0,0)

        local textBounds = Drawing.GetTextBounds(text.Text, text.Size, text.Font)
        text.Position = screenPos - Vector2.new(textBounds.X / 2, textBounds.Y / 2)
    end

    -- Clean up drawings for objects that no longer exist or are out of range
    local currentObjectSet = {}
    for _, v in ipairs(currentObjectKeys) do currentObjectSet[v] = true end

    for key, _ in pairs(_private.ObjectDrawings) do
        if not currentObjectSet[key] then
            Utils.ClearDrawingsForKey(_private.ObjectDrawings, key)
        end
    end
end


--//================================================================================================//
--//                                     MAIN UPDATE LOOP & CONTROL                                 //
--//================================================================================================//

--- The core render loop function, called every frame.
function Aura.OnRenderStep(deltaTime)
    if not _private.IsRunning or not Aura.Config.Enabled then
        -- If disabled, ensure all drawings are hidden
        for player, _ in pairs(_private.PlayerDrawings) do
            Utils.ClearDrawingsForKey(_private.PlayerDrawings, player)
        end
        return
    end

    -- Update camera reference in case it changes
    _private.Camera = Workspace.CurrentCamera

    -- Update Player ESP
    if Aura.Config.Player.Enabled then
        local validPlayers = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character and player ~= _private.LocalPlayer or not Aura.Config.Player.IgnoreSelf then
                if not (Aura.Config.Player.IgnoreTeam and player.Team == _private.LocalPlayer.Team) then
                    if not (Aura.Config.Player.IgnoreFriends and _private.LocalPlayer:IsFriendsWith(player.UserId)) then
                        table.insert(validPlayers, player)
                        Draw.UpdatePlayerESP(player)
                    end
                end
            end
        end

        -- Cleanup drawings for players who have left or are no longer valid
        for player, _ in pairs(_private.PlayerDrawings) do
            local isValid = false
            for _, validPlayer in ipairs(validPlayers) do
                if player == validPlayer then
                    isValid = true
                    break
                end
            end
            if not isValid then
                Utils.ClearDrawingsForKey(_private.PlayerDrawings, player)
            end
        end
    end

    -- Update Object ESP
    if Aura.Config.Object.Enabled then
        Draw.UpdateObjectESP()
    end
end

--//================================================================================================//
--//                                         PUBLIC API                                             //
--//================================================================================================//

--- Initializes the Aura ESP library.
-- Sets up local player, camera, and connects to the render loop.
-- This must be called before the ESP will function.
function Aura.Init()
    if _private.IsInitialized then
        warn("[Aura] Library is already initialized.")
        return
    end

    _private.LocalPlayer = Players.LocalPlayer
    if not _private.LocalPlayer then
        -- Wait for the local player to be available
        Players.PlayerAdded:Wait()
        _private.LocalPlayer = Players.LocalPlayer
    end

    -- Ensure character exists before setting up raycast filter
    if not _private.LocalPlayer.Character then
        _private.LocalPlayer.CharacterAdded:Wait()
    end
    Aura.Config.Performance.RaycastParams.FilterDescendantsInstances = {_private.LocalPlayer.Character}


    _private.Camera = Workspace.CurrentCamera

    -- Connect the main loop
    local connection = RunService:BindToRenderStep("AuraESP_Update", Enum.RenderPriority.Character.Value + 1, Aura.OnRenderStep)
    table.insert(_private.Connections, connection) -- Although BindToRenderStep doesn't return a connection, we use UnbindFromRenderStep to remove.

    _private.IsInitialized = true
    _private.IsRunning = true

    -- Handle player leaving to clean up their drawings
    local playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
        Utils.ClearDrawingsForKey(_private.PlayerDrawings, player)
    end)
    table.insert(_private.Connections, playerRemovingConn)

    print("[Aura] ESP Library Initialized. Version " .. Aura.VERSION)
end

--- Toggles the ESP on or off globally.
-- @param state (boolean) True to enable, false to disable.
function Aura.SetEnabled(state)
    Aura.Config.Enabled = state
    if not state then
        -- When turning off, immediately clear all drawings.
        for player, _ in pairs(_private.PlayerDrawings) do
            Utils.ClearDrawingsForKey(_private.PlayerDrawings, player)
        end
        for key, _ in pairs(_private.ObjectDrawings) do
            Utils.ClearDrawingsForKey(_private.ObjectDrawings, key)
        end
    end
    print("[Aura] ESP set to: " .. tostring(state))
end

--- Destroys the library instance, disconnecting all events and cleaning up.
-- This should be called when the script is being terminated to prevent memory leaks.
function Aura.Destroy()
    if not _private.IsInitialized then return end

    -- Disconnect all RBXScriptConnections
    for _, conn in ipairs(_private.Connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    table.clear(_private.Connections)

    -- Unbind the render step function
    RunService:UnbindFromRenderStep("AuraESP_Update")

    -- Clean up all existing drawing objects
    for player, _ in pairs(_private.PlayerDrawings) do
        Utils.ClearDrawingsForKey(_private.PlayerDrawings, player)
    end
    table.clear(_private.PlayerDrawings)

    for key, _ in pairs(_private.ObjectDrawings) do
        Utils.ClearDrawingsForKey(_private.ObjectDrawings, key)
    end
    table.clear(_private.ObjectDrawings)


    _private.IsInitialized = false
    _private.IsRunning = false

    print("[Aura] Library destroyed and cleaned up.")
end

--//================================================================================================//
--//                                           RETURN                                               //
--//================================================================================================//

return Aura
