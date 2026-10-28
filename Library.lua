-- AstatineLib - Modernized & Restyled UI Library
-- Default theme: Light Blue
-- Luau-compatible; returns the library table for loadstring/module loaders.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local AstatineLib = {
    Registry = {},
    RegistryMap = {},
    HudRegistry = {},
    Flags = {},
    ScreenGui = nil,

    Theme = {
        Accent = Color3.fromRGB(53, 162, 235),
        LightAccent = Color3.fromRGB(90, 185, 255),
        Background = Color3.fromRGB(24, 28, 36),
        DarkBackground = Color3.fromRGB(16, 19, 25),
        Outline = Color3.fromRGB(45, 53, 68),
        Text = Color3.fromRGB(240, 244, 248),
        SubText = Color3.fromRGB(140, 150, 165),
        Font = Enum.Font.Gotham,
    },
}

function AstatineLib:Create(className, properties)
    assert(type(className) == "string", "Create expects a class name string")
    local instance = Instance.new(className)
    for property, value in pairs(properties or {}) do
        instance[property] = value
    end
    return instance
end

function AstatineLib:CreateCorner(parent, radius)
    return self:Create("UICorner", {
        CornerRadius = UDim.new(0, radius or 6),
        Parent = parent,
    })
end

function AstatineLib:CreateGradient(parent, colorSequence, rotation)
    return self:Create("UIGradient", {
        Color = colorSequence or ColorSequence.new(
            Color3.fromRGB(255, 255, 255),
            Color3.fromRGB(200, 200, 200)
        ),
        Rotation = rotation or 90,
        Parent = parent,
    })
end

function AstatineLib:CreateWindow(settings)
    settings = settings or {}

    assert(LocalPlayer, "CreateWindow must be called on the client")
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")

    local oldGui = playerGui:FindFirstChild("AstatineLibGui")
    if oldGui then
        oldGui:Destroy()
    end

    local screenGui = self:Create("ScreenGui", {
        Name = "AstatineLibGui",
        Parent = playerGui,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
    })
    self.ScreenGui = screenGui

    local mainFrame = self:Create("Frame", {
        Name = "MainFrame",
        Parent = screenGui,
        BackgroundColor3 = self.Theme.Background,
        Position = UDim2.new(0.5, -275, 0.5, -210),
        Size = UDim2.fromOffset(550, 420),
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    self:CreateCorner(mainFrame, 10)
    self:Create("UIStroke", {
        Parent = mainFrame,
        Color = self.Theme.Outline,
        Thickness = 1,
    })

    local topBar = self:Create("Frame", {
        Name = "TopBar",
        Parent = mainFrame,
        BackgroundColor3 = self.Theme.Accent,
        Size = UDim2.new(1, 0, 0, 34),
        BorderSizePixel = 0,
    })
    self:CreateCorner(topBar, 10)
    self:Create("Frame", {
        Name = "TopBarSquareBottom",
        Parent = topBar,
        BackgroundColor3 = self.Theme.Accent,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0.5, 0),
        BorderSizePixel = 0,
    })
    self:CreateGradient(topBar, ColorSequence.new({
        ColorSequenceKeypoint.new(0, self.Theme.LightAccent),
        ColorSequenceKeypoint.new(1, self.Theme.Accent),
    }), 45)

    self:Create("TextLabel", {
        Name = "TitleLabel",
        Parent = topBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = tostring(settings.Title or "AstatineLib Window"),
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local tabBar = self:Create("Frame", {
        Name = "TabBar",
        Parent = mainFrame,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 42),
        Size = UDim2.new(1, -20, 0, 32),
        BorderSizePixel = 0,
    })
    self:Create("UIListLayout", {
        Parent = tabBar,
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    })

    local content = self:Create("Frame", {
        Name = "Container",
        Parent = mainFrame,
        BackgroundColor3 = self.Theme.DarkBackground,
        Position = UDim2.fromOffset(10, 82),
        Size = UDim2.new(1, -20, 1, -92),
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    self:CreateCorner(content, 8)

    -- Drag window by its title bar.
    local dragging = false
    local dragStart = nil
    local startPosition = nil
    local dragInput = nil

    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    topBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    local inputChangedConnection
    inputChangedConnection = UserInputService.InputChanged:Connect(function(input)
        if not screenGui.Parent then
            inputChangedConnection:Disconnect()
            return
        end
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)

    local window = {
        Holder = content,
        WindowFrame = mainFrame,
        ScreenGui = screenGui,
        Tabs = {},
        ActiveTab = nil,
    }

    function window:CreateTab(tabSettings)
        tabSettings = tabSettings or {}
        local tabName = tostring(tabSettings.Name or "Tab")

        local tabButton = AstatineLib:Create("TextButton", {
            Name = tabName .. "Button",
            Parent = tabBar,
            BackgroundColor3 = AstatineLib.Theme.Background,
            Size = UDim2.new(0, 105, 1, 0),
            BorderSizePixel = 0,
            AutoButtonColor = true,
            Font = Enum.Font.GothamSemibold,
            Text = tabName,
            TextColor3 = AstatineLib.Theme.SubText,
            TextSize = 12,
        })
        AstatineLib:CreateCorner(tabButton, 5)

        local page = AstatineLib:Create("ScrollingFrame", {
            Name = tabName .. "Page",
            Parent = content,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(8, 8),
            Size = UDim2.new(1, -16, 1, -16),
            BorderSizePixel = 0,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = AstatineLib.Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
        })
        AstatineLib:Create("UIListLayout", {
            Parent = page,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
        })

        local tab = {
            Name = tabName,
            Button = tabButton,
            Page = page,
        }
        table.insert(self.Tabs, tab)

        local function selectTab()
            for _, otherTab in ipairs(self.Tabs) do
                otherTab.Page.Visible = false
                otherTab.Button.BackgroundColor3 = AstatineLib.Theme.Background
                otherTab.Button.TextColor3 = AstatineLib.Theme.SubText
            end
            page.Visible = true
            tabButton.BackgroundColor3 = AstatineLib.Theme.Accent
            tabButton.TextColor3 = Color3.new(1, 1, 1)
            self.ActiveTab = tab
        end

        tabButton.Activated:Connect(selectTab)

        function tab:CreateButton(buttonSettings)
            buttonSettings = buttonSettings or {}
            local buttonName = tostring(buttonSettings.Name or "Button")
            local button = AstatineLib:Create("TextButton", {
                Name = buttonName,
                Parent = page,
                BackgroundColor3 = AstatineLib.Theme.Accent,
                Size = UDim2.new(1, -4, 0, 36),
                BorderSizePixel = 0,
                AutoButtonColor = true,
                Font = Enum.Font.GothamSemibold,
                Text = buttonName,
                TextColor3 = Color3.new(1, 1, 1),
                TextSize = 13,
            })
            AstatineLib:CreateCorner(button, 6)
            AstatineLib:Create("UIStroke", {
                Parent = button,
                Color = AstatineLib.Theme.Outline,
                Thickness = 1,
                Transparency = 0.35,
            })

            button.Activated:Connect(function()
                if type(buttonSettings.Callback) == "function" then
                    local ok, err = pcall(buttonSettings.Callback)
                    if not ok then
                        warn("[AstatineLib] Button callback failed: " .. tostring(err))
                    end
                end
            end)
            return button
        end

        if #self.Tabs == 1 then
            selectTab()
        end
        return tab
    end

    function window:Destroy()
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
        if AstatineLib.ScreenGui == screenGui then
            AstatineLib.ScreenGui = nil
        end
    end

    return window
end

return AstatineLib
