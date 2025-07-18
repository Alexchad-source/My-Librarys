--[[
 ██████╗ ██████╗ ██╗ ██████╗ ███╗   ██╗
██╔═══██╗██╔══██╗██║██╔═══██╗████╗  ██║
██║   ██║██████╔╝██║██║   ██║██╔██╗ ██║
██║   ██║██╔══██╗██║██║   ██║██║╚██╗██║
╚██████╔╝██║  ██║██║╚██████╔╝██║ ╚████║
 ╚═════╝ ╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝
 
 Version: 1.0.0
 Author: Gemini Advanced
 Description:
 A powerful, object-oriented GUI library for Roblox designed to simplify and
 accelerate the UI development workflow. OrionUI provides a clean, chainable API
 for creating, configuring, and managing GUI elements, abstracting away the
 boilerplate of instance creation and property management.

 Features:
 - Fluent, chainable API for readable and concise code.
 - Object-oriented structure for all UI components.
 - Draggable windows and other complex components out-of-the-box.
 - Automatic memory management and cleanup.
 - Simplified event handling system.
 - Easily extensible with custom components.

 Example Usage:
 
 local ReplicatedStorage = game:GetService("ReplicatedStorage")
 local OrionUI = require(ReplicatedStorage.OrionUI)
 
 local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
 OrionUI:Init(PlayerGui) -- Set the default parent for top-level elements
 
 local window = OrionUI.Window({
     Title = "My First Window",
     Size = UDim2.fromOffset(300, 200),
     Position = UDim2.fromScale(0.5, 0.5),
     AnchorPoint = Vector2.new(0.5, 0.5)
 })
 
 local button = OrionUI.Button({
     Parent = window,
     Text = "Click Me!",
     Size = UDim2.new(0.8, 0, 0.2, 0),
     Position = UDim2.fromScale(0.5, 0.5),
     AnchorPoint = Vector2.new(0.5, 0.5)
 }):OnClick(function(self)
     self:SetText("Clicked!")
 end)
 
]]

--//================================================================================================//
--//                                      LIBRARY INITIALIZATION                                    //
--//================================================================================================//

local OrionUI = {}
OrionUI.ClassName = "OrionUI"
OrionUI.VERSION = "1.0.0"

local UserInputService = game:GetService("UserInputService")

local _private = {
    DefaultParent = nil,
    ActiveConnections = {},
    AllComponents = {},
}

--//================================================================================================//
--//                                     BASE COMPONENT CLASS                                       //
--//================================================================================================//
-- This is the foundation for ALL UI elements in the library.

local Component = {}
Component.ClassName = "Component"

--- The constructor for all components.
-- @param instanceType (string) The Roblox ClassName to create (e.g., "Frame", "TextButton").
-- @param properties (table) A table of initial properties to apply.
function Component.new(instanceType, properties)
    local self = setmetatable({}, Component)
    
    self.Instance = Instance.new(instanceType)
    self.Children = {}
    self.Connections = {}
    
    -- Register for cleanup
    table.insert(_private.AllComponents, self)

    -- Apply initial properties from the properties table
    if properties then
        -- Handle Parent property first
        if properties.Parent then
            self:SetParent(properties.Parent)
            properties.Parent = nil -- Prevent it from being set again
        end
        
        for prop, value in pairs(properties) do
            self:SetProperty(prop, value)
        end
    end
    
    return self
end

--- Sets a raw property on the underlying Roblox instance.
-- @param propertyName (string) The name of the property.
-- @param value (any) The value to set.
-- @return (Component) self, for chaining.
function Component:SetProperty(propertyName, value)
    self.Instance[propertyName] = value
    return self
end

--- Sets the parent of the component.
-- @param parent (GuiObject or OrionUI.Component) The new parent.
-- @return (Component) self, for chaining.
function Component:SetParent(parent)
    if typeof(parent) == "Instance" then
        self.Instance.Parent = parent
    elseif parent and parent.ClassName then
        self.Instance.Parent = parent.Instance
        table.insert(parent.Children, self)
    end
    return self
end

--- Sets the Name of the component's instance.
-- @param name (string) The new name.
-- @return (Component) self, for chaining.
function Component:SetName(name)
    self.Instance.Name = name
    return self
end

--- Sets the Size using a UDim2.
-- @param size (UDim2) The new size.
-- @return (Component) self, for chaining.
function Component:SetSize(size)
    self.Instance.Size = size
    return self
end

--- Sets the Position using a UDim2.
-- @param position (UDim2) The new position.
-- @return (Component) self, for chaining.
function Component:SetPosition(position)
    self.Instance.Position = position
    return self
end

--- Sets the AnchorPoint using a Vector2.
-- @param anchorPoint (Vector2) The new anchor point.
-- @return (Component) self, for chaining.
function Component:SetAnchorPoint(anchorPoint)
    self.Instance.AnchorPoint = anchorPoint
    return self
end

--- Sets the BackgroundColor3.
-- @param color (Color3) The new background color.
-- @return (Component) self, for chaining.
function Component:SetBackgroundColor(color)
    self.Instance.BackgroundColor3 = color
    return self
end

--- Sets the BackgroundTransparency.
-- @param transparency (number) The new transparency (0-1).
-- @return (Component) self, for chaining.
function Component:SetBackgroundTransparency(transparency)
    self.Instance.BackgroundTransparency = transparency
    return self
end

--- Connects a function to an event on the Roblox instance.
-- @param eventName (string) The name of the event (e.g., "MouseButton1Click").
-- @param callback (function) The function to run. It receives `self` as its first argument.
-- @return (Component) self, for chaining.
function Component:OnEvent(eventName, callback)
    local connection = self.Instance[eventName]:Connect(function(...)
        callback(self, ...) -- Pass the OrionUI object as the first argument
    end)
    table.insert(self.Connections, connection)
    return self
end

--- Destroys the component and all of its children created with OrionUI.
function Component:Destroy()
    -- Destroy all children first (recursively)
    for i, child in ipairs(self.Children) do
        child:Destroy()
    end
    self.Children = {}
    
    -- Disconnect all events
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.Connections = {}
    
    -- Remove from global registry
    for i, comp in ipairs(_private.AllComponents) do
        if comp == self then
            table.remove(_private.AllComponents, i)
            break
        end
    end

    -- Destroy the actual Roblox instance
    self.Instance:Destroy()
end


--//================================================================================================//
--//                                      SPECIFIC COMPONENTS                                       //
--//================================================================================================//
-- These classes inherit from the base Component and add their own specific features.

-----------------------------------
--            FRAME            --
-----------------------------------
local Frame = {}
Frame.ClassName = "Frame"
setmetatable(Frame, { __index = Component })

function Frame.new(properties)
    local self = setmetatable(Component.new("Frame", properties), Frame)
    return self
end

-----------------------------------
--            LABEL            --
-----------------------------------
local Label = {}
Label.ClassName = "Label"
setmetatable(Label, { __index = Component })

function Label.new(properties)
    local self = setmetatable(Component.new("TextLabel", properties), Label)
    self:SetProperty("BackgroundTransparency", 1) -- Default for labels
    return self
end

function Label:SetText(text) self.Instance.Text = text; return self end
function Label:SetTextColor(color) self.Instance.TextColor3 = color; return self end
function Label:SetFont(font) self.Instance.Font = font; return self end
function Label:SetTextSize(size) self.Instance.TextSize = size; return self end
function Label:SetTextWrapped(wrapped) self.Instance.TextWrapped = wrapped; return self end
function Label:SetTextXAlignment(align) self.Instance.TextXAlignment = align; return self end
function Label:SetTextYAlignment(align) self.Instance.TextYAlignment = align; return self end

-----------------------------------
--            BUTTON           --
-----------------------------------
local Button = {}
Button.ClassName = "Button"
setmetatable(Button, { __index = Label }) -- Inherits from Label to share text methods

function Button.new(properties)
    local self = setmetatable(Component.new("TextButton", properties), Button)
    return self
end

--- A convenient wrapper for the MouseButton1Click event.
-- @param callback (function) The function to call on click.
-- @return (Button) self, for chaining.
function Button:OnClick(callback)
    return self:OnEvent("MouseButton1Click", callback)
end

-----------------------------------
--           TEXTBOX           --
-----------------------------------
local TextBox = {}
TextBox.ClassName = "TextBox"
setmetatable(TextBox, { __index = Label }) -- Inherits from Label

function TextBox.new(properties)
    local self = setmetatable(Component.new("TextBox", properties), TextBox)
    return self
end

function TextBox:GetText() return self.Instance.Text end
function TextBox:SetPlaceholderText(text) self.Instance.PlaceholderText = text; return self end
function TextBox:SetClearTextOnFocus(clear) self.Instance.ClearTextOnFocus = clear; return self end

--- Event for when the user presses Enter.
-- @param callback (function) The function to call.
-- @return (TextBox) self, for chaining.
function TextBox:OnEnter(callback)
    self:OnEvent("FocusLost", function(self, enterPressed)
        if enterPressed then
            callback(self)
        end
    end)
    return self
end

-----------------------------------
--       SCROLLING FRAME       --
-----------------------------------
local ScrollingFrame = {}
ScrollingFrame.ClassName = "ScrollingFrame"
setmetatable(ScrollingFrame, { __index = Frame }) -- Inherits from Frame

function ScrollingFrame.new(properties)
    local self = setmetatable(Component.new("ScrollingFrame", properties), ScrollingFrame)
    self.Instance.CanvasSize = UDim2.new(0,0,0,0) -- Default canvas size
    return self
end

function ScrollingFrame:SetCanvasSize(size) self.Instance.CanvasSize = size; return self end
function ScrollingFrame:SetScrollingDirection(direction) self.Instance.ScrollingDirection = direction; return self end
function ScrollingFrame:ApplyUIGridLayout(props) 
    local layout = Instance.new("UIGridLayout")
    for k,v in pairs(props or {}) do layout[k] = v end
    layout.Parent = self.Instance
    return self
end

-----------------------------------
--            WINDOW           --
-----------------------------------
local Window = {}
Window.ClassName = "Window"
setmetatable(Window, { __index = Frame })

function Window.new(properties)
    local self = setmetatable(Frame.new(properties), Window)
    self.Instance.ClipsDescendants = true
    
    -- Create Title Bar
    self.TitleBar = OrionUI.Frame({
        Parent = self,
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor = Color3.fromRGB(40, 40, 40),
        ZIndex = self.Instance.ZIndex + 1,
    })
    
    -- Create Title Label
    self.TitleLabel = OrionUI.Label({
        Parent = self.TitleBar,
        Name = "TitleLabel",
        Size = UDim2.new(1, -30, 1, 0), -- Leave space for close button
        Position = UDim2.fromOffset(10, 0),
        Text = properties.Title or "Window",
        TextColor = Color3.new(1,1,1),
        Font = Enum.Font.SourceSansBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    
    -- Create Close Button
    self.CloseButton = OrionUI.Button({
        Parent = self.TitleBar,
        Name = "CloseButton",
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.new(1, -30, 0, 0),
        Text = "X",
        TextColor = Color3.new(1,1,1),
        BackgroundColor = Color3.fromRGB(200, 50, 50),
        Font = Enum.Font.SourceSansBold,
        TextSize = 20,
    }):OnClick(function()
        self:Destroy()
    end)
    
    if properties.Draggable ~= false then
        self:SetDraggable(true)
    end
    
    return self
end

function Window:SetTitle(text) self.TitleLabel:SetText(text); return self end

function Window:SetDraggable(isDraggable)
    -- Disconnect any existing drag connection first
    if self.DragConnection then
        self.DragConnection:Disconnect()
        self.DragConnection = nil
    end

    if not isDraggable then return self end

    local dragging = false
    local dragInput = nil
    local frameStartPos = nil
    local dragStartPos = nil

    self.DragConnection = self.TitleBar:OnEvent("InputBegan", function(_, input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            frameStartPos = self.Instance.Position
            dragStartPos = input.Position
            
            local inputChangedConn
            inputChangedConn = UserInputService.InputChanged:Connect(function(changedInput)
                if changedInput == dragInput and dragging then
                    local delta = changedInput.Position - dragStartPos
                    self:SetPosition(UDim2.new(
                        frameStartPos.X.Scale, frameStartPos.X.Offset + delta.X,
                        frameStartPos.Y.Scale, frameStartPos.Y.Offset + delta.Y
                    ))
                end
            end)
            
            local inputEndedConn
            inputEndedConn = UserInputService.InputEnded:Connect(function(endedInput)
                if endedInput == dragInput then
                    dragging = false
                    inputChangedConn:Disconnect()
                    inputEndedConn:Disconnect()
                end
            end)
        end
    end)
    
    return self
end

-- Override Destroy to also clean up sub-components
function Window:Destroy()
    self.TitleBar:Destroy() -- This will also destroy the label and button
    Component.Destroy(self) -- Call the base destroy method
end


--//================================================================================================//
--//                                         PUBLIC API                                             //
--//================================================================================================//

--- Sets the default parent for all top-level UI elements created by the library.
-- Usually a PlayerGui instance.
-- @param gui (ScreenGui or other GuiObject) The default parent.
function OrionUI:Init(gui)
    assert(typeof(gui) == "Instance" and gui:IsA("GuiBase"), "OrionUI:Init requires a valid GuiBase instance.")
    _private.DefaultParent = gui
end

--- The factory function for creating a Window.
-- @param properties (table) Initial properties for the window.
-- @return (Window) The created window object.
function OrionUI.Window(properties)
    properties = properties or {}
    if not properties.Parent and _private.DefaultParent then
        properties.Parent = _private.DefaultParent
    end
    return Window.new(properties)
end

--- The factory function for creating a Frame.
-- @param properties (table) Initial properties for the frame.
-- @return (Frame) The created frame object.
function OrionUI.Frame(properties)
    return Frame.new(properties)
end

--- The factory function for creating a Button.
-- @param properties (table) Initial properties for the button.
-- @return (Button) The created button object.
function OrionUI.Button(properties)
    return Button.new(properties)
end

--- The factory function for creating a Label.
-- @param properties (table) Initial properties for the label.
-- @return (Label) The created label object.
function OrionUI.Label(properties)
    return Label.new(properties)
end

--- The factory function for creating a TextBox.
-- @param properties (table) Initial properties for the textbox.
-- @return (TextBox) The created textbox object.
function OrionUI.TextBox(properties)
    return TextBox.new(properties)
end

--- The factory function for creating a ScrollingFrame.
-- @param properties (table) Initial properties for the scrolling frame.
-- @return (ScrollingFrame) The created scrolling frame object.
function OrionUI.ScrollingFrame(properties)
    return ScrollingFrame.new(properties)
end

--- Destroys all UI components ever created by the library.
-- Useful for full script cleanup.
function OrionUI:DestroyAll()
    -- Iterate backwards to safely remove elements while iterating
    for i = #_private.AllComponents, 1, -1 do
        local comp = _private.AllComponents[i]
        if comp and comp.Destroy then
            comp:Destroy()
        end
    end
end


return OrionUI
