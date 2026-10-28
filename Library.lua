-- AstatineLib (formerly LinoriaLib) - Modernized & Restyled UI Library
-- Default Color: Light Blue
-- Integrated Font Support & Gradient UI Polish

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local AstatineLib = {
    Registry = {},
    RegistryMap = {},
    HudRegistry = {},
    
    // Default Light Blue Theme
    Theme = {
        Accent = Color3.fromRGB(53, 162, 235),      // Light Blue Accent
        LightAccent = Color3.fromRGB(90, 185, 255),  // Soft Blue Hover
        Background = Color3.fromRGB(24, 28, 36),     // Sleek Dark Surface
        DarkBackground = Color3.fromRGB(16, 19, 25), // Container BG
        Outline = Color3.fromRGB(45, 53, 68),        // Clean Borders
        Text = Color3.fromRGB(240, 244, 248),        // Crisp Light Text
        SubText = Color3.fromRGB(140, 150, 165),     // Muted Text
        Font = "rbxassetid://12187365364"           // Proxima Nova TTF Reference
    },
    
    Flags = {},
    ScreenGui = nil
}

-- [1] Utility Functions & Gradient Builders
function AstatineLib:Create(class, properties)
    local instance = Instance.new(class)
    for k, v in pairs(properties) do
        instance[k] = v
    end
    return instance
end

function AstatineLib:CreateCorner(parent, radius)
    return AstatineLib:Create("UICorner", {
        CornerRadius = UDim.new(0, radius or 6),
        Parent = parent
    })
end

function AstatineLib:CreateGradient(parent, colorSequence, rotation)
    return AstatineLib:Create("UIGradient", {
        Color = colorSequence or ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200))
        }),
        Rotation = rotation or 90,
        Parent = parent
    })
end

-- [2] Main Window Factory
function AstatineLib:CreateWindow(settings)
    local windowName = settings.Title or "AstatineLib Window"
    
    local ScreenGui = AstatineLib:Create("ScreenGui", {
        Name = "AstatineLibGui",
        Parent = CoreGui,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false
    })
    AstatineLib.ScreenGui = ScreenGui

    local MainFrame = AstatineLib:Create("Frame", {
        Name = "MainFrame",
        Parent = ScreenGui,
        BackgroundColor3 = AstatineLib.Theme.Background,
        Position = UDim2.new(0.3, 0, 0.3, 0),
        Size = UDim2.new(0, 550, 0, 420),
        BorderSizePixel = 0
    })
    
    AstatineLib:CreateCorner(MainFrame, 10)
    
    local TopBar = AstatineLib:Create("Frame", {
        Name = "TopBar",
        Parent = MainFrame,
        BackgroundColor3 = AstatineLib.Theme.Accent,
        Size = UDim2.new(1, 0, 0, 32),
        BorderSizePixel = 0
    })
    AstatineLib:CreateCorner(TopBar, 10)
    
    local TopBarFix = AstatineLib:Create("Frame", {
        Parent = TopBar,
        BackgroundColor3 = AstatineLib.Theme.Accent,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0.5, 0),
        BorderSizePixel = 0
    })
    
    AstatineLib:CreateGradient(TopBar, ColorSequence.new({
        ColorSequenceKeypoint.new(0, AstatineLib.Theme.LightAccent),
        ColorSequenceKeypoint.new(1, AstatineLib.Theme.Accent)
    }), 45)

    local TitleLabel = AstatineLib:Create("TextLabel", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = windowName,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left
    })

    local Container = AstatineLib:Create("Frame", {
        Parent = MainFrame,
        BackgroundColor3 = AstatineLib.Theme.DarkBackground,
        Position = UDim2.new(0, 10, 0, 42),
        Size = UDim2.new(1, -20, 1, -52),
        BorderSizePixel = 0
    })
    AstatineLib:CreateCorner(Container, 8)

    -- Window Object with methods
    local WindowObj = {}
    
    function WindowObj:CreateTab(tabSettings)
        local TabName = tabSettings.Name or "Tab"
        
        local TabFrame = AstatineLib:Create("ScrollingFrame", {
            Name = TabName .. "Tab",
            Parent = Container,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(0, 0, 2, 0),
            ScrollBarThickness = 4,
            Visible = true
        })
        
        AstatineLib:Create("UIListLayout", {
            Parent = TabFrame,
            SortOrder = Enum.SortOrder.LayoutIndex,
            Padding = UDim.new(0, 8)
        })
        
        local SectionObj = {}
        function SectionObj:CreateButton(btnSettings)
            local Btn = AstatineLib:Create("TextButton", {
                Parent = TabFrame,
                BackgroundColor3 = AstatineLib.Theme.Accent,
                Size = UDim2.new(1, 0, 0, 32),
                Font = Enum.Font.GothamBold,
                Text = btnSettings.Name or "Button",
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextSize = 13,
                AutoButtonColor = true
            })
            AstatineLib:CreateCorner(Btn, 6)
            
            Btn.MouseButton1Click:Connect(function()
                if btnSettings.Callback then
                    pcall(btnSettings.Callback)
                end
            end)
        end
        
        return SectionObj
    end

    return WindowObj
end

return AstatineLib
