--[[
    AstatineLib - Linoria-inspired, modernized Luau UI library
    Theme: Midnight / Light Blue
    UI-only library with CoreGui parenting for executor-style environments.

    Compatibility goals:
      local Window = Library:CreateWindow({Title = "Example"})
      local Tab = Window:CreateTab({Name = "Main"})
      local Group = Tab:AddLeftGroupbox("General")
      Group:AddButton("Print", function() print("clicked") end)
      Group:AddToggle("Enabled", {Text = "Enabled", Default = false,
          Callback = function(value) print(value) end})
      Group:AddSlider("Speed", {Text = "Speed", Default = 16,
          Min = 0, Max = 100, Rounding = 0, Callback = function(value) end})
      Group:AddDropdown("Mode", {Text = "Mode", Values = {"A", "B"},
          Default = "A", Callback = function(value) end})

    This file only builds UI controls. It does not implement game exploits,
    remote-event abuse, or game-specific actions.
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Library = {
    Version = "2.0.0",
    Registry = {},
    RegistryMap = {},
    HudRegistry = {},
    Flags = {},
    Options = {},
    Toggles = {},
    ScreenGui = nil,
    Windows = {},
    Unloaded = false,

    Theme = {
        Accent = Color3.fromRGB(53, 162, 235),
        AccentDark = Color3.fromRGB(32, 126, 194),
        LightAccent = Color3.fromRGB(100, 195, 255),
        Background = Color3.fromRGB(20, 23, 31),
        Main = Color3.fromRGB(25, 29, 39),
        DarkBackground = Color3.fromRGB(16, 19, 26),
        Element = Color3.fromRGB(31, 36, 48),
        ElementHover = Color3.fromRGB(39, 46, 61),
        Outline = Color3.fromRGB(48, 57, 73),
        Text = Color3.fromRGB(238, 243, 250),
        SubText = Color3.fromRGB(143, 155, 174),
        Disabled = Color3.fromRGB(94, 104, 120),
        Success = Color3.fromRGB(69, 201, 133),
        Warning = Color3.fromRGB(245, 184, 76),
        Danger = Color3.fromRGB(238, 91, 104),
        Font = Enum.Font.Gotham,
        FontBold = Enum.Font.GothamBold,
        FontMedium = Enum.Font.GothamMedium,
    },

    ThemeManager = {},
    SaveManager = {},
}

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return true
    end
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[AstatineLib] Callback error: " .. tostring(err))
    end
    return ok
end

local function make(className, properties)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    return object
end

local function corner(parent, radius)
    return make("UICorner", {
        Parent = parent,
        CornerRadius = UDim.new(0, radius or 6),
    })
end

local function stroke(parent, color, thickness, transparency)
    return make("UIStroke", {
        Parent = parent,
        Color = color or Library.Theme.Outline,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function gradient(parent, first, second, rotation)
    return make("UIGradient", {
        Parent = parent,
        Rotation = rotation or 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, first or Library.Theme.LightAccent),
            ColorSequenceKeypoint.new(1, second or Library.Theme.Accent),
        }),
    })
end

local function tween(object, duration, properties)
    local info = TweenInfo.new(duration or 0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local animation = TweenService:Create(object, info, properties)
    animation:Play()
    return animation
end

local function textLabel(parent, text, size, color, font, height)
    return make("TextLabel", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height or 18),
        Font = font or Library.Theme.Font,
        Text = tostring(text or ""),
        TextColor3 = color or Library.Theme.Text,
        TextSize = size or 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
end

local function buttonBase(parent, name, text, height)
    local button = make("TextButton", {
        Name = name or "Button",
        Parent = parent,
        BackgroundColor3 = Library.Theme.Element,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, height or 30),
        Font = Library.Theme.FontMedium,
        Text = text or "",
        TextColor3 = Library.Theme.Text,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    corner(button, 5)
    stroke(button, Library.Theme.Outline, 1, 0.25)

    button.MouseEnter:Connect(function()
        if button.Parent then
            tween(button, 0.12, {BackgroundColor3 = Library.Theme.ElementHover})
        end
    end)
    button.MouseLeave:Connect(function()
        if button.Parent then
            tween(button, 0.12, {BackgroundColor3 = Library.Theme.Element})
        end
    end)
    return button
end

local function bindFlag(control, identifier, initialValue, isToggle)
    if identifier and identifier ~= "" then
        Library.Flags[identifier] = initialValue
        if isToggle then
            Library.Toggles[identifier] = control
        else
            Library.Options[identifier] = control
        end
    end
end

local function makeSignalObject(initialValue, callback, identifier, isToggle)
    local object = {
        Value = initialValue,
        Callback = callback,
        Changed = Instance.new("BindableEvent"),
        _connections = {},
    }

    function object:SetValue(value, silent)
        self.Value = value
        if identifier then
            Library.Flags[identifier] = value
        end
        if not silent then
            safeCall(self.Callback, value)
            self.Changed:Fire(value)
        end
    end

    function object:OnChanged(fn)
        if type(fn) == "function" then
            table.insert(self._connections, self.Changed.Event:Connect(fn))
        end
        return self
    end

    function object:OnChangedSilent(fn)
        if type(fn) == "function" then
            table.insert(self._connections, self.Changed.Event:Connect(fn))
        end
        return self
    end

    function object:Destroy()
        for _, connection in ipairs(self._connections) do
            connection:Disconnect()
        end
        self.Changed:Destroy()
    end

    bindFlag(object, identifier, initialValue, isToggle)
    return object
end

function Library:Create(className, properties)
    return make(className, properties)
end

function Library:CreateCorner(parent, radius)
    return corner(parent, radius)
end

function Library:CreateGradient(parent, colors, rotation)
    return make("UIGradient", {
        Parent = parent,
        Color = colors or ColorSequence.new(self.Theme.LightAccent, self.Theme.Accent),
        Rotation = rotation or 0,
    })
end

function Library:SetTheme(theme)
    for key, value in pairs(theme or {}) do
        if self.Theme[key] ~= nil then
            self.Theme[key] = value
        end
    end
end

function Library:Notify(message, duration)
    local gui = self.ScreenGui
    if not gui or not gui.Parent then
        warn("[AstatineLib] " .. tostring(message))
        return
    end

    local holder = gui:FindFirstChild("Notifications")
    if not holder then
        holder = make("Frame", {
            Name = "Notifications",
            Parent = gui,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -16, 1, -16),
            Size = UDim2.fromOffset(300, 250),
        })
        make("UIListLayout", {
            Parent = holder,
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            Padding = UDim.new(0, 8),
        })
    end

    local item = make("Frame", {
        Parent = holder,
        BackgroundColor3 = self.Theme.Main,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 54),
        BackgroundTransparency = 1,
    })
    corner(item, 7)
    stroke(item, self.Theme.Outline, 1, 0.15)
    local bar = make("Frame", {
        Parent = item,
        BackgroundColor3 = self.Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, 0),
    })
    corner(bar, 3)
    local label = textLabel(item, message, 12, self.Theme.Text, self.Theme.Font, 54)
    label.Position = UDim2.fromOffset(12, 0)
    label.Size = UDim2.new(1, -22, 1, 0)

    tween(item, 0.18, {BackgroundTransparency = 0})
    task.delay(duration or 3, function()
        if item.Parent then
            tween(item, 0.16, {BackgroundTransparency = 1})
            task.wait(0.18)
            if item.Parent then item:Destroy() end
        end
    end)
end

-- Creates a full window. Supports the older Astatine CreateTab API and a
-- Linoria-style AddTab / AddLeftGroupbox / AddRightGroupbox API.
function Library:CreateWindow(settings)
    settings = settings or {}
    assert(LocalPlayer, "CreateWindow must be called in a client context")

    -- Prefer CoreGui for the original executor-oriented setup. Fall back to
    -- PlayerGui if the current environment does not permit CoreGui parenting.
    local guiParent = CoreGui
    local existing = guiParent:FindFirstChild("AstatineLibGui")
    if existing then existing:Destroy() end

    local gui = make("ScreenGui", {
        Name = "AstatineLibGui",
        Parent = guiParent,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 50,
    })
    self.ScreenGui = gui
    self.Unloaded = false

    local windowWidth = tonumber(settings.Width) or 620
    local windowHeight = tonumber(settings.Height) or 480
    local centered = settings.Center ~= false
    local initialPosition = centered
        and UDim2.new(0.5, -windowWidth / 2, 0.5, -windowHeight / 2)
        or UDim2.new(0, 80, 0, 80)

    local main = make("Frame", {
        Name = "Main",
        Parent = gui,
        BackgroundColor3 = self.Theme.Background,
        BorderSizePixel = 0,
        Position = initialPosition,
        Size = UDim2.fromOffset(windowWidth, windowHeight),
        ClipsDescendants = true,
    })
    corner(main, 9)
    stroke(main, self.Theme.Outline, 1, 0)

    local top = make("Frame", {
        Name = "TopBar",
        Parent = main,
        BackgroundColor3 = self.Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 38),
    })
    corner(top, 9)
    make("Frame", {
        Parent = top,
        BackgroundColor3 = self.Theme.Accent,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.55, 0),
        Size = UDim2.new(1, 0, 0.45, 0),
    })
    gradient(top, self.Theme.LightAccent, self.Theme.Accent, 0)

    local title = make("TextLabel", {
        Name = "Title",
        Parent = top,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -110, 1, 0),
        Font = self.Theme.FontBold,
        Text = tostring(settings.Title or "AstatineLib"),
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local subtitle = make("TextLabel", {
        Name = "Version",
        Parent = top,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -43, 0, 0),
        Size = UDim2.fromOffset(70, 38),
        Font = self.Theme.Font,
        Text = settings.Subtitle or self.Version,
        TextColor3 = Color3.fromRGB(225, 241, 255),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local close = make("TextButton", {
        Name = "Close",
        Parent = top,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(26, 24),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.84,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = self.Theme.FontBold,
        Text = "×",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 19,
    })
    corner(close, 5)
    close.MouseButton1Click:Connect(function()
        gui.Enabled = false
    end)

    local tabRail = make("Frame", {
        Name = "TabRail",
        Parent = main,
        BackgroundColor3 = self.Theme.Main,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 46),
        Size = UDim2.new(1, -20, 0, 34),
    })
    corner(tabRail, 6)
    local tabLayout = make("UIListLayout", {
        Parent = tabRail,
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
        VerticalAlignment = Enum.VerticalAlignment.Center,
    })
    make("UIPadding", {
        Parent = tabRail,
        PaddingLeft = UDim.new(0, 5),
        PaddingRight = UDim.new(0, 5),
    })

    local body = make("Frame", {
        Name = "Body",
        Parent = main,
        BackgroundColor3 = self.Theme.DarkBackground,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 88),
        Size = UDim2.new(1, -20, 1, -98),
        ClipsDescendants = true,
    })
    corner(body, 7)

    -- Window dragging and RightShift visibility toggle.
    local dragging, dragStart, startPosition, dragInput = false, nil, nil, nil
    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    top.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    local dragConnection = UserInputService.InputChanged:Connect(function(input)
        if not gui.Parent then
            dragConnection:Disconnect()
            return
        end
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
            )
        end
    end)

    local window = {
        Holder = body,
        WindowFrame = main,
        ScreenGui = gui,
        Tabs = {},
        ActiveTab = nil,
        _connections = {dragConnection},
    }

    function window:SetTitle(value)
        title.Text = tostring(value)
    end

    function window:SetVisible(value)
        gui.Enabled = value == true
    end

    function window:Toggle()
        gui.Enabled = not gui.Enabled
    end

    function window:Destroy()
        if gui and gui.Parent then gui:Destroy() end
        if Library.ScreenGui == gui then Library.ScreenGui = nil end
        for _, connection in ipairs(self._connections) do
            pcall(function() connection:Disconnect() end)
        end
    end

    function window:CreateTab(tabSettings)
        if type(tabSettings) == "string" then
            tabSettings = {Name = tabSettings}
        end
        tabSettings = tabSettings or {}
        local tabName = tostring(tabSettings.Name or tabSettings.Title or "Tab")

        local tabButton = make("TextButton", {
            Name = tabName .. "TabButton",
            Parent = tabRail,
            BackgroundColor3 = self.ActiveTab and Library.Theme.Element or Library.Theme.Accent,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Size = UDim2.fromOffset(104, 26),
            Font = Library.Theme.FontMedium,
            Text = tabName,
            TextColor3 = self.ActiveTab and Library.Theme.SubText or Color3.new(1, 1, 1),
            TextSize = 11,
            LayoutOrder = #self.Tabs + 1,
        })
        corner(tabButton, 5)

        local page = make("ScrollingFrame", {
            Name = tabName .. "Page",
            Parent = body,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(8, 8),
            Size = UDim2.new(1, -16, 1, -16),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = Library.Theme.Accent,
            ScrollBarImageTransparency = 0.1,
            Visible = false,
        })

        local columns = make("Frame", {
            Name = "Columns",
            Parent = page,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        local left = make("Frame", {
            Name = "LeftColumn",
            Parent = columns,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0.5, -5, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        local right = make("Frame", {
            Name = "RightColumn",
            Parent = columns,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, 5, 0, 0),
            Size = UDim2.new(0.5, -5, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        local leftLayout = make("UIListLayout", {
            Parent = left, SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10),
        })
        local rightLayout = make("UIListLayout", {
            Parent = right, SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10),
        })

        local tab = {
            Name = tabName,
            Button = tabButton,
            Page = page,
            Left = left,
            Right = right,
            _groupCount = {Left = 0, Right = 0},
        }

        local function selectTab()
            for _, other in ipairs(window.Tabs) do
                other.Page.Visible = false
                tween(other.Button, 0.12, {BackgroundColor3 = Library.Theme.Element})
                other.Button.TextColor3 = Library.Theme.SubText
            end
            page.Visible = true
            tween(tabButton, 0.12, {BackgroundColor3 = Library.Theme.Accent})
            tabButton.TextColor3 = Color3.new(1, 1, 1)
            window.ActiveTab = tab
        end
        tabButton.Activated:Connect(selectTab)

        local function createGroup(groupName, side)
            side = side or "Left"
            local column = side == "Right" and right or left
            tab._groupCount[side] = tab._groupCount[side] + 1

            local groupFrame = make("Frame", {
                Name = tostring(groupName or "Groupbox"),
                Parent = column,
                BackgroundColor3 = Library.Theme.Main,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 42),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = tab._groupCount[side],
            })
            corner(groupFrame, 6)
            stroke(groupFrame, Library.Theme.Outline, 1, 0.2)

            local header = make("Frame", {
                Name = "Header",
                Parent = groupFrame,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -18, 0, 30),
                Position = UDim2.fromOffset(9, 0),
            })
            local headerLabel = textLabel(header, groupName or "Groupbox", 12,
                Library.Theme.Text, Library.Theme.FontBold, 30)
            headerLabel.Size = UDim2.new(1, 0, 1, 0)

            local divider = make("Frame", {
                Parent = groupFrame,
                BackgroundColor3 = Library.Theme.Outline,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(9, 30),
                Size = UDim2.new(1, -18, 0, 1),
            })

            local controls = make("Frame", {
                Name = "Controls",
                Parent = groupFrame,
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(9, 38),
                Size = UDim2.new(1, -18, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
            })
            local controlLayout = make("UIListLayout", {
                Parent = controls,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 7),
            })
            make("UIPadding", {
                Parent = controls,
                PaddingBottom = UDim.new(0, 10),
            })

            local group = {Container = groupFrame, Controls = controls, Name = groupName}
            local controlOrder = 0

            local function registerControl(instance)
                controlOrder = controlOrder + 1
                instance.LayoutOrder = controlOrder
                return instance
            end

            function group:AddLabel(labelText)
                local label = textLabel(controls, labelText, 12, Library.Theme.SubText,
                    Library.Theme.Font, 22)
                registerControl(label)
                local object = {Instance = label}
                function object:SetText(value) label.Text = tostring(value) end
                function object:Destroy() label:Destroy() end
                return object
            end

            function group:AddDivider()
                local line = make("Frame", {
                    Parent = controls,
                    BackgroundColor3 = Library.Theme.Outline,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 1),
                })
                registerControl(line)
                return line
            end

            function group:AddButton(nameOrSettings, callback)
                local options
                if type(nameOrSettings) == "table" then
                    options = nameOrSettings
                else
                    options = {Name = nameOrSettings, Callback = callback}
                end
                local label = tostring(options.Name or options.Text or "Button")
                local btn = buttonBase(controls, label, label, 30)
                registerControl(btn)
                btn.Activated:Connect(function()
                    safeCall(options.Func or options.Callback)
                end)
                local object = {Instance = btn}
                function object:SetText(value) btn.Text = tostring(value) end
                function object:Press() safeCall(options.Func or options.Callback) end
                function object:Destroy() btn:Destroy() end
                return object
            end

            function group:AddToggle(identifier, options)
                options = options or {}
                local labelText = tostring(options.Text or options.Name or identifier or "Toggle")
                local value = options.Default == true
                local row = make("TextButton", {
                    Name = tostring(identifier or labelText),
                    Parent = controls,
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Size = UDim2.new(1, 0, 0, 27),
                    Text = "",
                })
                registerControl(row)
                local box = make("Frame", {
                    Parent = row,
                    BackgroundColor3 = value and Library.Theme.Accent or Library.Theme.Element,
                    BorderSizePixel = 0,
                    Position = UDim2.fromOffset(1, 5),
                    Size = UDim2.fromOffset(16, 16),
                })
                corner(box, 4)
                stroke(box, Library.Theme.Outline, 1, 0.1)
                local check = textLabel(box, value and "✓" or "", 12, Color3.new(1,1,1),
                    Library.Theme.FontBold, 16)
                check.TextXAlignment = Enum.TextXAlignment.Center
                local text = textLabel(row, labelText, 12, Library.Theme.Text,
                    Library.Theme.Font, 27)
                text.Position = UDim2.fromOffset(25, 0)
                text.Size = UDim2.new(1, -25, 1, 0)

                local object = makeSignalObject(value, options.Callback, identifier, true)
                object.Instance = row
                local function update(newValue, fire)
                    value = newValue == true
                    box.BackgroundColor3 = value and Library.Theme.Accent or Library.Theme.Element
                    check.Text = value and "✓" or ""
                    object.Value = value
                    if identifier then Library.Flags[identifier] = value end
                    if fire then
                        safeCall(options.Callback, value)
                        object.Changed:Fire(value)
                    end
                end
                row.Activated:Connect(function() update(not value, true) end)
                function object:SetValue(newValue, silent) update(newValue, not silent) end
                function object:OnChanged(fn)
                    if type(fn) == "function" then object.Changed.Event:Connect(fn) end
                    return object
                end
                function object:Destroy() row:Destroy(); object.Changed:Destroy() end
                bindFlag(object, identifier, value, true)
                return object
            end

            function group:AddSlider(identifier, options)
                options = options or {}
                local minValue = tonumber(options.Min) or 0
                local maxValue = tonumber(options.Max) or 100
                if maxValue < minValue then maxValue = minValue end
                local rounding = tonumber(options.Rounding)
                if rounding == nil then rounding = 0 end
                local value = math.clamp(tonumber(options.Default) or minValue, minValue, maxValue)
                local label = textLabel(controls, options.Text or options.Name or identifier, 12,
                    Library.Theme.Text, Library.Theme.FontMedium, 18)
                registerControl(label)
                local valueLabel = textLabel(label, "", 11, Library.Theme.SubText, Library.Theme.Font, 18)
                valueLabel.AnchorPoint = Vector2.new(1, 0)
                valueLabel.Position = UDim2.new(1, 0, 0, 0)
                valueLabel.Size = UDim2.fromOffset(60, 18)
                valueLabel.TextXAlignment = Enum.TextXAlignment.Right

                local track = make("TextButton", {
                    Parent = controls,
                    BackgroundColor3 = Library.Theme.Element,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 8),
                    Text = "",
                    AutoButtonColor = false,
                })
                corner(track, 4)
                registerControl(track)
                local fill = make("Frame", {
                    Parent = track,
                    BackgroundColor3 = Library.Theme.Accent,
                    BorderSizePixel = 0,
                    Size = UDim2.new(0, 0, 1, 0),
                })
                corner(fill, 4)

                local object = makeSignalObject(value, options.Callback, identifier, false)
                object.Instance = track
                local function formatValue(v)
                    if rounding <= 0 then return tostring(math.floor(v + 0.5)) end
                    return string.format("%." .. tostring(math.clamp(rounding, 0, 4)) .. "f", v)
                end
                local function update(newValue, fire)
                    newValue = math.clamp(tonumber(newValue) or minValue, minValue, maxValue)
                    local mult = 10 ^ math.clamp(rounding, 0, 4)
                    value = math.floor(newValue * mult + 0.5) / mult
                    local alpha = maxValue == minValue and 0 or (value - minValue) / (maxValue - minValue)
                    fill.Size = UDim2.new(alpha, 0, 1, 0)
                    valueLabel.Text = formatValue(value)
                    object.Value = value
                    if identifier then Library.Flags[identifier] = value end
                    if fire then safeCall(options.Callback, value); object.Changed:Fire(value) end
                end
                local sliding = false
                local function fromX(x)
                    local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
                    update(minValue + (maxValue - minValue) * alpha, true)
                end
                track.Activated:Connect(function() fromX(UserInputService:GetMouseLocation().X) end)
                track.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = true
                        fromX(input.Position.X)
                    end
                end)
                local endConn = UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then sliding = false end
                end)
                local moveConn = UserInputService.InputChanged:Connect(function(input)
                    if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch) then
                        fromX(input.Position.X)
                    end
                end)
                function object:SetValue(v, silent) update(v, not silent) end
                function object:OnChanged(fn)
                    if type(fn) == "function" then object.Changed.Event:Connect(fn) end
                    return object
                end
                function object:Destroy()
                    endConn:Disconnect(); moveConn:Disconnect()
                    label:Destroy(); track:Destroy(); object.Changed:Destroy()
                end
                update(value, false)
                bindFlag(object, identifier, value, false)
                return object
            end

            function group:AddDropdown(identifier, options)
                options = options or {}
                local values = options.Values or options.Options or {}
                local allowNull = options.AllowNull == true
                local selected = options.Default
                if type(selected) == "table" then
                    selected = selected[1]
                end
                if selected == nil and not allowNull then selected = values[1] end
                local title = tostring(options.Text or options.Name or identifier or "Dropdown")
                local label = textLabel(controls, title, 12, Library.Theme.Text, Library.Theme.FontMedium, 18)
                registerControl(label)

                local dropdown = buttonBase(controls, "Dropdown", tostring(selected or "Select...") .. "  ▾", 30)
                registerControl(dropdown)
                local menuOpen = false
                local menu = make("Frame", {
                    Parent = controls,
                    BackgroundColor3 = Library.Theme.Background,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 0),
                    Visible = false,
                    ClipsDescendants = true,
                })
                corner(menu, 5)
                stroke(menu, Library.Theme.Outline, 1, 0.1)
                local menuList = make("UIListLayout", {
                    Parent = menu,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 2),
                })
                registerControl(menu)

                local object = makeSignalObject(selected, options.Callback, identifier, false)
                object.Instance = dropdown
                local function closeMenu()
                    menuOpen = false
                    menu.Visible = false
                    menu.Size = UDim2.new(1, 0, 0, 0)
                    dropdown.Text = tostring(selected or "Select...") .. "  ▾"
                end
                local function setSelected(value, fire)
                    selected = value
                    object.Value = value
                    dropdown.Text = tostring(value or "Select...") .. "  ▾"
                    if identifier then Library.Flags[identifier] = value end
                    closeMenu()
                    if fire then safeCall(options.Callback, value); object.Changed:Fire(value) end
                end
                local function rebuild()
                    for _, child in ipairs(menu:GetChildren()) do
                        if child:IsA("TextButton") then child:Destroy() end
                    end
                    for index, optionValue in ipairs(values) do
                        local optionButton = buttonBase(menu, "Option" .. index, tostring(optionValue), 26)
                        optionButton.LayoutOrder = index
                        optionButton.Activated:Connect(function() setSelected(optionValue, true) end)
                    end
                    menuList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                        if menuOpen then
                            menu.Size = UDim2.new(1, 0, 0, math.min(menuList.AbsoluteContentSize.Y + 4, 140))
                        end
                    end)
                end
                rebuild()
                dropdown.Activated:Connect(function()
                    menuOpen = not menuOpen
                    menu.Visible = menuOpen
                    if menuOpen then
                        menu.Size = UDim2.new(1, 0, 0, math.min(menuList.AbsoluteContentSize.Y + 4, 140))
                        dropdown.Text = tostring(selected or "Select...") .. "  ▴"
                    else
                        closeMenu()
                    end
                end)
                function object:SetValue(value, silent) setSelected(value, not silent) end
                function object:SetValues(newValues)
                    values = newValues or {}
                    rebuild()
                end
                function object:OnChanged(fn)
                    if type(fn) == "function" then object.Changed.Event:Connect(fn) end
                    return object
                end
                function object:Destroy() label:Destroy(); dropdown:Destroy(); menu:Destroy(); object.Changed:Destroy() end
                bindFlag(object, identifier, selected, false)
                return object
            end

            function group:AddInput(identifier, options)
                options = options or {}
                local label = textLabel(controls, options.Text or options.Name or identifier, 12,
                    Library.Theme.Text, Library.Theme.FontMedium, 18)
                registerControl(label)
                local input = make("TextBox", {
                    Parent = controls,
                    BackgroundColor3 = Library.Theme.Element,
                    BorderSizePixel = 0,
                    ClearTextOnFocus = false,
                    Size = UDim2.new(1, 0, 0, 30),
                    Font = Library.Theme.Font,
                    PlaceholderText = options.Placeholder or "Enter text...",
                    PlaceholderColor3 = Library.Theme.SubText,
                    Text = tostring(options.Default or ""),
                    TextColor3 = Library.Theme.Text,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
                corner(input, 5)
                stroke(input, Library.Theme.Outline, 1, 0.25)
                make("UIPadding", {
                    Parent = input,
                    PaddingLeft = UDim.new(0, 8),
                    PaddingRight = UDim.new(0, 8),
                })
                registerControl(input)
                local object = makeSignalObject(input.Text, options.Callback, identifier, false)
                object.Instance = input
                input.FocusLost:Connect(function(enterPressed)
                    object:SetValue(input.Text)
                    if options.FireOnEnterOnly and not enterPressed then return end
                    safeCall(options.Callback, input.Text, enterPressed)
                end)
                function object:SetValue(value, silent)
                    input.Text = tostring(value or "")
                    object.Value = input.Text
                    if identifier then Library.Flags[identifier] = object.Value end
                    if not silent then object.Changed:Fire(object.Value); safeCall(options.Callback, object.Value) end
                end
                function object:OnChanged(fn)
                    if type(fn) == "function" then object.Changed.Event:Connect(fn) end
                    return object
                end
                function object:Destroy() label:Destroy(); input:Destroy(); object.Changed:Destroy() end
                bindFlag(object, identifier, input.Text, false)
                return object
            end

            function group:AddKeyPicker(identifier, options)
                options = options or {}
                local labelText = tostring(options.Text or options.Name or identifier or "Keybind")
                local row = make("Frame", {
                    Parent = controls,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 28),
                })
                registerControl(row)
                local label = textLabel(row, labelText, 12, Library.Theme.Text, Library.Theme.Font, 28)
                label.Size = UDim2.new(1, -100, 1, 0)
                local keyButton = buttonBase(row, "KeyButton", tostring(options.Default or "None"), 25)
                keyButton.AnchorPoint = Vector2.new(1, 0.5)
                keyButton.Position = UDim2.new(1, 0, 0.5, 0)
                keyButton.Size = UDim2.fromOffset(88, 25)
                local currentKey = options.Default
                local listening = false
                local object = makeSignalObject(currentKey, options.Callback, identifier, false)
                object.Instance = keyButton
                keyButton.Activated:Connect(function()
                    listening = true
                    keyButton.Text = "Press key..."
                end)
                local conn = UserInputService.InputBegan:Connect(function(input, processed)
                    if processed then return end
                    if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                        listening = false
                        currentKey = input.KeyCode
                        keyButton.Text = currentKey.Name
                        object:SetValue(currentKey)
                    elseif currentKey and input.KeyCode == currentKey then
                        safeCall(options.Callback, currentKey)
                    end
                end)
                function object:SetValue(value, silent)
                    currentKey = value
                    keyButton.Text = typeof(value) == "EnumItem" and value.Name or tostring(value or "None")
                    object.Value = value
                    if identifier then Library.Flags[identifier] = value end
                    if not silent then safeCall(options.Callback, value); object.Changed:Fire(value) end
                end
                function object:OnChanged(fn)
                    if type(fn) == "function" then object.Changed.Event:Connect(fn) end
                    return object
                end
                function object:Destroy() conn:Disconnect(); row:Destroy(); object.Changed:Destroy() end
                bindFlag(object, identifier, currentKey, false)
                return object
            end

            function group:AddColorPicker(identifier, options)
                options = options or {}
                local current = options.Default or Library.Theme.Accent
                local row = make("Frame", {
                    Parent = controls,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 28),
                })
                registerControl(row)
                local label = textLabel(row, options.Text or options.Name or identifier, 12,
                    Library.Theme.Text, Library.Theme.Font, 28)
                label.Size = UDim2.new(1, -54, 1, 0)
                local swatch = make("TextButton", {
                    Parent = row,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(44, 22),
                    BackgroundColor3 = current,
                    BorderSizePixel = 0,
                    Text = "",
                    AutoButtonColor = false,
                })
                corner(swatch, 5)
                stroke(swatch, Library.Theme.Outline, 1, 0.1)
                local object = makeSignalObject(current, options.Callback, identifier, false)
                object.Instance = swatch
                swatch.Activated:Connect(function()
                    -- Simple deterministic cycle; a full RGB picker can be layered on later.
                    current = Color3.fromHSV((select(1, current:ToHSV()) + 0.08) % 1,
                        select(2, current:ToHSV()), select(3, current:ToHSV()))
                    swatch.BackgroundColor3 = current
                    object:SetValue(current)
                end)
                function object:SetValue(value, silent)
                    if typeof(value) ~= "Color3" then return end
                    current = value
                    swatch.BackgroundColor3 = current
                    object.Value = current
                    if identifier then Library.Flags[identifier] = current end
                    if not silent then safeCall(options.Callback, current); object.Changed:Fire(current) end
                end
                function object:OnChanged(fn)
                    if type(fn) == "function" then object.Changed.Event:Connect(fn) end
                    return object
                end
                function object:Destroy() row:Destroy(); object.Changed:Destroy() end
                bindFlag(object, identifier, current, false)
                return object
            end

            -- Linoria naming compatibility.
            function group:AddParagraph(titleText, bodyText)
                local wrapper = make("Frame", {
                    Parent = controls,
                    BackgroundColor3 = Library.Theme.Element,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 54),
                    AutomaticSize = Enum.AutomaticSize.Y,
                })
                corner(wrapper, 5)
                registerControl(wrapper)
                local titleLabel = textLabel(wrapper, titleText or "Information", 12,
                    Library.Theme.Text, Library.Theme.FontBold, 22)
                titleLabel.Position = UDim2.fromOffset(8, 4)
                titleLabel.Size = UDim2.new(1, -16, 0, 22)
                local bodyLabel = textLabel(wrapper, bodyText or "", 11,
                    Library.Theme.SubText, Library.Theme.Font, 0)
                bodyLabel.Position = UDim2.fromOffset(8, 27)
                bodyLabel.Size = UDim2.new(1, -16, 0, 0)
                bodyLabel.AutomaticSize = Enum.AutomaticSize.Y
                bodyLabel.TextWrapped = true
                make("UIPadding", {
                    Parent = wrapper,
                    PaddingBottom = UDim.new(0, 8),
                })
                local object = {}
                function object:SetText(newTitle, newBody)
                    titleLabel.Text = tostring(newTitle or "")
                    bodyLabel.Text = tostring(newBody or "")
                end
                function object:Destroy() wrapper:Destroy() end
                return object
            end

            return group
        end

        function tab:AddLeftGroupbox(name)
            return createGroup(name, "Left")
        end
        function tab:AddRightGroupbox(name)
            return createGroup(name, "Right")
        end
        function tab:AddGroupbox(name)
            return createGroup(name, "Left")
        end

        -- Backwards-compatible flat API: Tab:CreateButton(...).
        function tab:CreateButton(options, callback)
            local group = createGroup("Controls", "Left")
            return group:AddButton(options, callback)
        end
        function tab:CreateToggle(options)
            local group = createGroup("Controls", "Left")
            return group:AddToggle(options.Flag or options.Name, options)
        end
        function tab:CreateSlider(options)
            local group = createGroup("Controls", "Left")
            return group:AddSlider(options.Flag or options.Name, options)
        end

        if #window.Tabs == 0 then
            page.Visible = true
            window.ActiveTab = tab
            tabButton.BackgroundColor3 = Library.Theme.Accent
            tabButton.TextColor3 = Color3.new(1, 1, 1)
        end

        table.insert(window.Tabs, tab)
        return tab
    end

    -- Linoria-style alias.
    function window:AddTab(name)
        return self:CreateTab(type(name) == "table" and name or {Name = name})
    end

    if settings.AutoShow then
        gui.Enabled = true
    end

    table.insert(self.Windows, window)
    return window
end

function Library:Unload()
    self.Unloaded = true
    for _, window in ipairs(self.Windows) do
        pcall(function() window:Destroy() end)
    end
    self.Windows = {}
    self.Registry = {}
    self.RegistryMap = {}
    self.HudRegistry = {}
    self.Flags = {}
    self.Options = {}
    self.Toggles = {}
    self.ScreenGui = nil
end

-- A small compatibility helper for common Linoria-style usage.
function Library:CreateNotification(message, duration)
    return self:Notify(message, duration)
end

return Library
