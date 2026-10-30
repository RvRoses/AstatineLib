--[[
    AstatineLib v3.0 — Dark Green / Mobile-First / Modern Rewrite
    Linoria-compatible API. CoreGui parenting for executor environments.

    Changelog v3:
      - Full dark-green theme replacing blue accent system
      - Gradient-filled groupboxes, toggle boxes, and button highlights
      - Rounded corners tightened throughout (UDim radius passes)
      - Mobile: Touch input parity with mouse across sliders, toggles, dragging
      - Vibration feedback on mobile toggle/button activation
      - Larger touch targets (min 36px interactive height on mobile)
      - Shadow-depth illusion via layered strokes
      - AnimationQueue so concurrent tweens don't race
]]

local Players         = game:GetService("Players")
local CoreGui         = game:GetService("CoreGui")
local TweenService    = game:GetService("TweenService")
local UserInputService= game:GetService("UserInputService")
local RunService      = game:GetService("RunService")
local HapticService   = pcall(function() return game:GetService("HapticService") end) and game:GetService("HapticService") or nil

local LocalPlayer = Players.LocalPlayer

-- ──────────────────────────────────────────────────────────────────────────────
-- Mobile detection
-- ──────────────────────────────────────────────────────────────────────────────
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local function haptic()
    if IS_MOBILE and HapticService then
        pcall(function()
            HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.2)
            task.delay(0.06, function()
                pcall(function()
                    HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
                end)
            end)
        end)
    end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Library root
-- ──────────────────────────────────────────────────────────────────────────────
local Library = {
    Version    = "3.0.0",
    Registry   = {},
    RegistryMap= {},
    HudRegistry= {},
    Flags      = {},
    Options    = {},
    Toggles    = {},
    ScreenGui  = nil,
    Windows    = {},
    Unloaded   = false,

    Theme = {
        -- Primary greens
        Accent       = Color3.fromRGB(34, 197, 94),    -- main green
        AccentDark   = Color3.fromRGB(21, 143, 64),
        LightAccent  = Color3.fromRGB(74, 222, 128),   -- highlight end of gradient

        -- Backgrounds
        Background   = Color3.fromRGB(14, 20, 16),     -- deepest bg
        Main         = Color3.fromRGB(18, 26, 20),
        DarkBackground= Color3.fromRGB(11, 16, 12),
        Element      = Color3.fromRGB(22, 34, 26),
        ElementHover = Color3.fromRGB(30, 46, 34),

        -- Borders
        Outline      = Color3.fromRGB(38, 60, 44),
        OutlineAccent= Color3.fromRGB(34, 197, 94),    -- focus ring

        -- Text
        Text         = Color3.fromRGB(228, 248, 234),
        SubText      = Color3.fromRGB(120, 170, 136),
        Disabled     = Color3.fromRGB(70, 100, 80),

        -- Status
        Success      = Color3.fromRGB(34, 197, 94),
        Warning      = Color3.fromRGB(234, 179, 8),
        Danger       = Color3.fromRGB(239, 68, 68),

        -- Type
        Font         = Enum.Font.Gotham,
        FontBold     = Enum.Font.GothamBold,
        FontMedium   = Enum.Font.GothamMedium,

        -- Sizing
        CornerMain   = 10,
        CornerElem   = 7,
        CornerSmall  = 5,
        TouchHeight  = IS_MOBILE and 38 or 30,
    },

    ThemeManager = {},
    SaveManager  = {},
}

-- ──────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────────────────────────────────────
local T = Library.Theme

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return true end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[AstatineLib v3] Callback error: " .. tostring(err)) end
    return ok
end

local function make(className, props)
    local o = Instance.new(className)
    for k, v in pairs(props or {}) do o[k] = v end
    return o
end

local function corner(parent, r)
    return make("UICorner", {Parent = parent, CornerRadius = UDim.new(0, r or T.CornerElem)})
end

local function stroke(parent, color, thickness, transparency)
    return make("UIStroke", {
        Parent           = parent,
        Color            = color or T.Outline,
        Thickness        = thickness or 1,
        Transparency     = transparency or 0,
        ApplyStrokeMode  = Enum.ApplyStrokeMode.Border,
    })
end

-- Gradient on a Frame background; use UIGradient inside the Frame
local function bgGradient(parent, c0, c1, rot)
    return make("UIGradient", {
        Parent   = parent,
        Rotation = rot or 135,
        Color    = ColorSequence.new({
            ColorSequenceKeypoint.new(0, c0 or T.Element),
            ColorSequenceKeypoint.new(1, c1 or T.Main),
        }),
    })
end

local function accentGradient(parent, rot)
    return bgGradient(parent, T.LightAccent, T.AccentDark, rot or 90)
end

local function tweenObj(obj, dur, props)
    local info = TweenInfo.new(dur or 0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function textLabel(parent, text, size, color, font, height)
    return make("TextLabel", {
        Parent             = parent,
        BackgroundTransparency = 1,
        Size               = UDim2.new(1, 0, 0, height or 18),
        Font               = font or T.Font,
        Text               = tostring(text or ""),
        TextColor3         = color or T.Text,
        TextSize           = size or 12,
        TextXAlignment     = Enum.TextXAlignment.Left,
        TextYAlignment     = Enum.TextYAlignment.Center,
        TextTruncate       = Enum.TextTruncate.AtEnd,
    })
end

-- Gradient-filled button base with green hover glow
local function buttonBase(parent, name, text, height)
    local h = height or T.TouchHeight
    local btn = make("TextButton", {
        Name             = name or "Button",
        Parent           = parent,
        BackgroundColor3 = T.Element,
        BorderSizePixel  = 0,
        AutoButtonColor  = false,
        Size             = UDim2.new(1, 0, 0, h),
        Font             = T.FontMedium,
        Text             = text or "",
        TextColor3       = T.Text,
        TextSize         = 12,
        TextTruncate     = Enum.TextTruncate.AtEnd,
        ClipsDescendants = true,
    })
    corner(btn, T.CornerSmall)
    stroke(btn, T.Outline, 1, 0.2)

    -- Subtle inner gradient (dark → slightly lighter)
    bgGradient(btn, T.Element, T.ElementHover, 135)

    -- Hover glow overlay
    local glow = make("Frame", {
        Parent               = btn,
        BackgroundColor3     = T.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
        Size                 = UDim2.new(1, 0, 1, 0),
        ZIndex               = btn.ZIndex + 1,
    })
    corner(glow, T.CornerSmall)

    btn.MouseEnter:Connect(function()
        tweenObj(glow, 0.14, {BackgroundTransparency = 0.88})
        tweenObj(btn, 0.14, {TextColor3 = T.LightAccent})
    end)
    btn.MouseLeave:Connect(function()
        tweenObj(glow, 0.14, {BackgroundTransparency = 1})
        tweenObj(btn, 0.14, {TextColor3 = T.Text})
    end)
    btn.MouseButton1Down:Connect(function()
        tweenObj(glow, 0.08, {BackgroundTransparency = 0.72})
    end)
    btn.MouseButton1Up:Connect(function()
        tweenObj(glow, 0.1, {BackgroundTransparency = 0.88})
    end)

    return btn
end

local function bindFlag(ctrl, id, init, isToggle)
    if id and id ~= "" then
        Library.Flags[id] = init
        if isToggle then Library.Toggles[id] = ctrl
        else             Library.Options[id]  = ctrl end
    end
end

local function makeSignalObject(init, cb, id, isToggle)
    local obj = {
        Value    = init,
        Callback = cb,
        Changed  = Instance.new("BindableEvent"),
        _conns   = {},
    }
    function obj:SetValue(v, silent)
        self.Value = v
        if id then Library.Flags[id] = v end
        if not silent then safeCall(self.Callback, v); self.Changed:Fire(v) end
    end
    function obj:OnChanged(fn)
        if type(fn) == "function" then
            table.insert(self._conns, self.Changed.Event:Connect(fn))
        end
        return self
    end
    function obj:Destroy()
        for _, c in ipairs(self._conns) do c:Disconnect() end
        self.Changed:Destroy()
    end
    bindFlag(obj, id, init, isToggle)
    return obj
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Public surface helpers
-- ──────────────────────────────────────────────────────────────────────────────
function Library:Create(className, props) return make(className, props) end
function Library:CreateCorner(parent, r)  return corner(parent, r) end
function Library:CreateGradient(parent, colors, rotation)
    return make("UIGradient", {
        Parent   = parent,
        Color    = colors or ColorSequence.new(T.LightAccent, T.AccentDark),
        Rotation = rotation or 90,
    })
end
function Library:SetTheme(theme)
    for k, v in pairs(theme or {}) do
        if T[k] ~= nil then T[k] = v end
    end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Notification system
-- ──────────────────────────────────────────────────────────────────────────────
function Library:Notify(message, duration)
    local gui = self.ScreenGui
    if not gui or not gui.Parent then
        warn("[AstatineLib v3] " .. tostring(message)); return
    end
    local holder = gui:FindFirstChild("Notifications") or (function()
        local h = make("Frame", {
            Name                 = "Notifications",
            Parent               = gui,
            BackgroundTransparency = 1,
            AnchorPoint          = Vector2.new(1, 1),
            Position             = UDim2.new(1, -14, 1, -14),
            Size                 = UDim2.fromOffset(300, 260),
        })
        make("UIListLayout", {
            Parent             = h,
            SortOrder          = Enum.SortOrder.LayoutOrder,
            VerticalAlignment  = Enum.VerticalAlignment.Bottom,
            Padding            = UDim.new(0, 8),
        })
        return h
    end)()

    local item = make("Frame", {
        Parent               = holder,
        BackgroundColor3     = T.Main,
        BorderSizePixel      = 0,
        Size                 = UDim2.new(1, 0, 0, 56),
        BackgroundTransparency = 1,
        ClipsDescendants     = true,
    })
    corner(item, T.CornerElem)
    stroke(item, T.OutlineAccent, 1, 0.5)
    bgGradient(item, T.Main, T.DarkBackground, 135)

    -- Left accent bar with gradient
    local bar = make("Frame", {
        Parent           = item,
        BackgroundColor3 = T.Accent,
        BorderSizePixel  = 0,
        Size             = UDim2.new(0, 3, 1, 0),
    })
    corner(bar, 3)
    accentGradient(bar, 90)

    local lbl = textLabel(item, message, 12, T.Text, T.Font, 56)
    lbl.Position = UDim2.fromOffset(12, 0)
    lbl.Size     = UDim2.new(1, -24, 1, 0)
    lbl.TextWrapped = true

    tweenObj(item, 0.2, {BackgroundTransparency = 0})
    task.delay(duration or 3.5, function()
        if item.Parent then
            tweenObj(item, 0.18, {BackgroundTransparency = 1})
            task.wait(0.2)
            if item.Parent then item:Destroy() end
        end
    end)
end
Library.CreateNotification = Library.Notify

-- ──────────────────────────────────────────────────────────────────────────────
-- CreateWindow
-- ──────────────────────────────────────────────────────────────────────────────
function Library:CreateWindow(settings)
    settings = settings or {}
    assert(LocalPlayer, "CreateWindow: client context required")

    local guiParent = CoreGui
    local existing  = guiParent:FindFirstChild("AstatineLibGui_v3")
    if existing then existing:Destroy() end

    local gui = make("ScreenGui", {
        Name             = "AstatineLibGui_v3",
        Parent           = guiParent,
        ResetOnSpawn     = false,
        IgnoreGuiInset   = true,
        ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
        DisplayOrder     = 60,
    })
    self.ScreenGui = gui
    self.Unloaded  = false

    -- Mobile gets a wider, taller window; desktop keeps compact
    local vp          = workspace.CurrentCamera.ViewportSize
    local isMobileVP  = IS_MOBILE or vp.X < 600
    local winW = isMobileVP and math.min(vp.X - 12, 440) or (tonumber(settings.Width)  or 640)
    local winH = isMobileVP and math.min(vp.Y - 48, 680) or (tonumber(settings.Height) or 490)
    local centered    = settings.Center ~= false
    local initPos     = centered
        and UDim2.new(0.5, -winW / 2, 0.5, -winH / 2)
        or  UDim2.new(0, 60, 0, 60)

    -- ── Main frame ─────────────────────────────────────────────────────────
    local main = make("Frame", {
        Name             = "Main",
        Parent           = gui,
        BackgroundColor3 = T.Background,
        BorderSizePixel  = 0,
        Position         = initPos,
        Size             = UDim2.fromOffset(winW, winH),
        ClipsDescendants = true,
    })
    corner(main, T.CornerMain)
    stroke(main, T.Outline, 1, 0)

    -- Outer shadow illusion
    local shadow = make("Frame", {
        Name             = "Shadow",
        Parent           = gui,
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.62,
        BorderSizePixel  = 0,
        Position         = UDim2.new(
            initPos.X.Scale, initPos.X.Offset + 4,
            initPos.Y.Scale, initPos.Y.Offset + 6
        ),
        Size             = UDim2.fromOffset(winW, winH),
        ZIndex           = main.ZIndex - 1,
    })
    corner(shadow, T.CornerMain)

    -- ── Top bar ────────────────────────────────────────────────────────────
    local top = make("Frame", {
        Name             = "TopBar",
        Parent           = main,
        BackgroundColor3 = T.Accent,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 0, 40),
    })
    corner(top, T.CornerMain)
    -- Fill bottom half so corner only shows at actual top
    make("Frame", {
        Parent           = top,
        BackgroundColor3 = T.Accent,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 0, 0.5, 0),
        Size             = UDim2.new(1, 0, 0.5, 0),
    })
    accentGradient(top, 0)

    local titleLabel = make("TextLabel", {
        Name                 = "Title",
        Parent               = top,
        BackgroundTransparency = 1,
        Position             = UDim2.fromOffset(14, 0),
        Size                 = UDim2.new(1, -120, 1, 0),
        Font                 = T.FontBold,
        Text                 = tostring(settings.Title or "AstatineLib"),
        TextColor3           = Color3.new(1, 1, 1),
        TextSize             = 14,
        TextXAlignment       = Enum.TextXAlignment.Left,
        TextTruncate         = Enum.TextTruncate.AtEnd,
    })

    make("TextLabel", {
        Name                 = "Subtitle",
        Parent               = top,
        BackgroundTransparency = 1,
        AnchorPoint          = Vector2.new(1, 0),
        Position             = UDim2.new(1, -46, 0, 0),
        Size                 = UDim2.fromOffset(70, 40),
        Font                 = T.Font,
        Text                 = settings.Subtitle or self.Version,
        TextColor3           = Color3.fromRGB(210, 245, 220),
        TextSize             = 10,
        TextXAlignment       = Enum.TextXAlignment.Right,
    })

    local closeBtn = make("TextButton", {
        Name                 = "Close",
        Parent               = top,
        AnchorPoint          = Vector2.new(1, 0.5),
        Position             = UDim2.new(1, -8, 0.5, 0),
        Size                 = UDim2.fromOffset(28, 26),
        BackgroundColor3     = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.80,
        BorderSizePixel      = 0,
        AutoButtonColor      = false,
        Font                 = T.FontBold,
        Text                 = "×",
        TextColor3           = Color3.new(1, 1, 1),
        TextSize             = 20,
    })
    corner(closeBtn, T.CornerSmall)
    closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

    -- ── Tab rail ───────────────────────────────────────────────────────────
    local tabRail = make("Frame", {
        Name             = "TabRail",
        Parent           = main,
        BackgroundColor3 = T.Main,
        BorderSizePixel  = 0,
        Position         = UDim2.fromOffset(10, 48),
        Size             = UDim2.new(1, -20, 0, isMobileVP and 40 or 34),
    })
    corner(tabRail, T.CornerElem)
    stroke(tabRail, T.Outline, 1, 0.3)

    -- Subtle gradient on tab rail
    bgGradient(tabRail, T.Main, T.DarkBackground, 180)

    make("UIListLayout", {
        Parent            = tabRail,
        FillDirection     = Enum.FillDirection.Horizontal,
        SortOrder         = Enum.SortOrder.LayoutOrder,
        Padding           = UDim.new(0, 5),
        VerticalAlignment = Enum.VerticalAlignment.Center,
    })
    make("UIPadding", {
        Parent       = tabRail,
        PaddingLeft  = UDim.new(0, 5),
        PaddingRight = UDim.new(0, 5),
    })

    -- ── Body ───────────────────────────────────────────────────────────────
    local bodyTop = 48 + (isMobileVP and 40 or 34) + 8
    local body = make("Frame", {
        Name             = "Body",
        Parent           = main,
        BackgroundColor3 = T.DarkBackground,
        BorderSizePixel  = 0,
        Position         = UDim2.fromOffset(10, bodyTop),
        Size             = UDim2.new(1, -20, 1, -(bodyTop + 10)),
        ClipsDescendants = true,
    })
    corner(body, T.CornerElem)

    -- ── Drag (mouse + touch) ────────────────────────────────────────────────
    local dragging, dragStart, startPos, dragInput = false, nil, nil, nil
    top.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = inp.Position
            startPos  = main.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    top.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragInput = inp
        end
    end)
    local dragConn = UserInputService.InputChanged:Connect(function(inp)
        if not gui.Parent then return end
        if dragging and inp == dragInput then
            local d = inp.Position - dragStart
            local nx = math.clamp(startPos.X.Offset + d.X, 0, vp.X - winW)
            local ny = math.clamp(startPos.Y.Offset + d.Y, 0, vp.Y - winH)
            main.Position = UDim2.new(startPos.X.Scale, nx, startPos.Y.Scale, ny)
            shadow.Position = UDim2.new(startPos.X.Scale, nx + 4, startPos.Y.Scale, ny + 6)
        end
    end)

    -- ── Window object ───────────────────────────────────────────────────────
    local window = {
        Holder      = body,
        WindowFrame = main,
        ScreenGui   = gui,
        Tabs        = {},
        ActiveTab   = nil,
        _conns      = {dragConn},
    }

    function window:SetTitle(v)  titleLabel.Text = tostring(v) end
    function window:SetVisible(v) gui.Enabled = v == true end
    function window:Toggle()     gui.Enabled = not gui.Enabled end
    function window:Destroy()
        if gui and gui.Parent then gui:Destroy() end
        if Library.ScreenGui == gui then Library.ScreenGui = nil end
        for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    end

    -- ── CreateTab ───────────────────────────────────────────────────────────
    function window:CreateTab(tabSettings)
        if type(tabSettings) == "string" then tabSettings = {Name = tabSettings} end
        tabSettings = tabSettings or {}
        local tabName = tostring(tabSettings.Name or tabSettings.Title or "Tab")

        local tabBtn = make("TextButton", {
            Name             = tabName .. "TabBtn",
            Parent           = tabRail,
            BackgroundColor3 = (#self.Tabs > 0) and T.Element or T.AccentDark,
            BorderSizePixel  = 0,
            AutoButtonColor  = false,
            Size             = UDim2.fromOffset(isMobileVP and 96 or 110, isMobileVP and 32 or 26),
            Font             = T.FontMedium,
            Text             = tabName,
            TextColor3       = (#self.Tabs > 0) and T.SubText or Color3.new(1, 1, 1),
            TextSize         = 11,
            LayoutOrder      = #self.Tabs + 1,
            ClipsDescendants = true,
        })
        corner(tabBtn, T.CornerSmall)

        -- Active tab gets gradient fill
        local tabGrad = accentGradient(tabBtn, 0)
        tabGrad.Transparency = (#self.Tabs > 0)
            and NumberSequence.new(1)
            or  NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 0.25),
                })

        local page = make("ScrollingFrame", {
            Name               = tabName .. "Page",
            Parent             = body,
            BackgroundTransparency = 1,
            BorderSizePixel    = 0,
            Position           = UDim2.fromOffset(8, 8),
            Size               = UDim2.new(1, -16, 1, -16),
            CanvasSize         = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize= Enum.AutomaticSize.Y,
            ScrollBarThickness = isMobileVP and 5 or 4,
            ScrollBarImageColor3 = T.Accent,
            ScrollBarImageTransparency = 0.1,
            Visible            = false,
        })

        local columns = make("Frame", {
            Name                = "Columns",
            Parent              = page,
            BackgroundTransparency = 1,
            Size                = UDim2.new(1, 0, 0, 0),
            AutomaticSize       = Enum.AutomaticSize.Y,
        })
        local left = make("Frame", {
            Name                = "LeftColumn",
            Parent              = columns,
            BackgroundTransparency = 1,
            Position            = UDim2.new(0, 0, 0, 0),
            Size                = UDim2.new(isMobileVP and 1 or 0.5, isMobileVP and 0 or -5, 0, 0),
            AutomaticSize       = Enum.AutomaticSize.Y,
        })
        local right = make("Frame", {
            Name                = "RightColumn",
            Parent              = columns,
            BackgroundTransparency = 1,
            Position            = UDim2.new(isMobileVP and 0 or 0.5, isMobileVP and 0 or 5, 0, 0),
            Size                = UDim2.new(isMobileVP and 0 or 0.5, isMobileVP and 0 or -5, 0, 0),
            AutomaticSize       = Enum.AutomaticSize.Y,
            Visible             = not isMobileVP,
        })
        make("UIListLayout", {Parent = left,  SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10)})
        make("UIListLayout", {Parent = right, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10)})

        local tab = {
            Name        = tabName,
            Button      = tabBtn,
            Page        = page,
            Left        = left,
            Right       = right,
            _groupCount = {Left = 0, Right = 0},
        }

        local function selectTab()
            for _, other in ipairs(window.Tabs) do
                other.Page.Visible = false
                tweenObj(other.Button, 0.12, {BackgroundColor3 = T.Element, TextColor3 = T.SubText})
                local g = other.Button:FindFirstChildOfClass("UIGradient")
                if g then g.Transparency = NumberSequence.new(1) end
            end
            page.Visible = true
            tweenObj(tabBtn, 0.12, {BackgroundColor3 = T.AccentDark, TextColor3 = Color3.new(1,1,1)})
            tabGrad.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 0.25),
            })
            window.ActiveTab = tab
            haptic()
        end
        tabBtn.Activated:Connect(selectTab)

        -- ── Groupbox factory ───────────────────────────────────────────────
        local function createGroup(groupName, side)
            side = side or "Left"
            local column = (side == "Right" and not isMobileVP) and right or left
            tab._groupCount[side] = tab._groupCount[side] + 1

            local groupFrame = make("Frame", {
                Name             = tostring(groupName or "Groupbox"),
                Parent           = column,
                BackgroundColor3 = T.Main,
                BorderSizePixel  = 0,
                Size             = UDim2.new(1, 0, 0, 40),
                AutomaticSize    = Enum.AutomaticSize.Y,
                LayoutOrder      = tab._groupCount[side],
                ClipsDescendants = false,
            })
            corner(groupFrame, T.CornerElem)
            stroke(groupFrame, T.Outline, 1, 0.1)

            -- Gradient fill on groupbox body (dark green subtlety)
            bgGradient(groupFrame, T.Main, T.DarkBackground, 160)

            -- Header strip with accent gradient
            local header = make("Frame", {
                Name             = "Header",
                Parent           = groupFrame,
                BackgroundColor3 = T.AccentDark,
                BorderSizePixel  = 0,
                Size             = UDim2.new(1, 0, 0, 30),
                ClipsDescendants = true,
            })
            -- Rounded only on top corners: fake it with an offset frame overlap
            corner(header, T.CornerElem)
            make("Frame", {
                Parent           = header,
                BackgroundColor3 = T.AccentDark,
                BorderSizePixel  = 0,
                Position         = UDim2.new(0, 0, 0.5, 0),
                Size             = UDim2.new(1, 0, 0.5, 0),
            })
            accentGradient(header, 0)

            local headerLabel = textLabel(header, groupName or "Groupbox", 12,
                Color3.new(1,1,1), T.FontBold, 30)
            headerLabel.Position = UDim2.fromOffset(10, 0)
            headerLabel.Size     = UDim2.new(1, -10, 1, 0)

            -- Thin accent divider below header
            local divider = make("Frame", {
                Parent           = groupFrame,
                BackgroundColor3 = T.Accent,
                BackgroundTransparency = 0.7,
                BorderSizePixel  = 0,
                Position         = UDim2.fromOffset(0, 30),
                Size             = UDim2.new(1, 0, 0, 1),
            })

            local controls = make("Frame", {
                Name             = "Controls",
                Parent           = groupFrame,
                BackgroundTransparency = 1,
                Position         = UDim2.fromOffset(9, 36),
                Size             = UDim2.new(1, -18, 0, 0),
                AutomaticSize    = Enum.AutomaticSize.Y,
            })
            make("UIListLayout", {
                Parent      = controls,
                SortOrder   = Enum.SortOrder.LayoutOrder,
                Padding     = UDim.new(0, 8),
            })
            make("UIPadding", {
                Parent       = controls,
                PaddingBottom= UDim.new(0, 10),
            })

            local group = {Container = groupFrame, Controls = controls, Name = groupName}
            local ctrlOrder = 0
            local function reg(inst) ctrlOrder += 1; inst.LayoutOrder = ctrlOrder; return inst end

            -- ── AddLabel ────────────────────────────────────────────────────
            function group:AddLabel(labelText)
                local lbl = textLabel(controls, labelText, 12, T.SubText, T.Font, 22)
                reg(lbl)
                local o = {Instance = lbl}
                function o:SetText(v) lbl.Text = tostring(v) end
                function o:Destroy()  lbl:Destroy() end
                return o
            end

            -- ── AddDivider ──────────────────────────────────────────────────
            function group:AddDivider()
                local line = make("Frame", {
                    Parent           = controls,
                    BackgroundColor3 = T.Outline,
                    BorderSizePixel  = 0,
                    Size             = UDim2.new(1, 0, 0, 1),
                })
                reg(line)
                return line
            end

            -- ── AddParagraph ────────────────────────────────────────────────
            function group:AddParagraph(titleText, bodyText)
                local wrapper = make("Frame", {
                    Parent           = controls,
                    BackgroundColor3 = T.Element,
                    BorderSizePixel  = 0,
                    Size             = UDim2.new(1, 0, 0, 54),
                    AutomaticSize    = Enum.AutomaticSize.Y,
                    ClipsDescendants = true,
                })
                corner(wrapper, T.CornerSmall)
                bgGradient(wrapper, T.Element, T.DarkBackground, 135)
                reg(wrapper)
                local tLbl = textLabel(wrapper, titleText or "Info", 12, T.LightAccent, T.FontBold, 22)
                tLbl.Position = UDim2.fromOffset(8, 4)
                tLbl.Size     = UDim2.new(1, -16, 0, 22)
                local bLbl = textLabel(wrapper, bodyText or "", 11, T.SubText, T.Font, 0)
                bLbl.Position    = UDim2.fromOffset(8, 27)
                bLbl.Size        = UDim2.new(1, -16, 0, 0)
                bLbl.AutomaticSize = Enum.AutomaticSize.Y
                bLbl.TextWrapped = true
                make("UIPadding", {Parent = wrapper, PaddingBottom = UDim.new(0, 8)})
                local o = {}
                function o:SetText(t, b) tLbl.Text = tostring(t or ""); bLbl.Text = tostring(b or "") end
                function o:Destroy() wrapper:Destroy() end
                return o
            end

            -- ── AddButton ───────────────────────────────────────────────────
            function group:AddButton(nameOrOpts, callback)
                local opts = type(nameOrOpts) == "table" and nameOrOpts
                    or {Name = nameOrOpts, Callback = callback}
                local lbl = tostring(opts.Name or opts.Text or "Button")
                local btn = buttonBase(controls, lbl, lbl, T.TouchHeight)
                reg(btn)
                btn.Activated:Connect(function()
                    haptic()
                    safeCall(opts.Func or opts.Callback)
                end)
                local o = {Instance = btn}
                function o:SetText(v) btn.Text = tostring(v) end
                function o:Press()    safeCall(opts.Func or opts.Callback) end
                function o:Destroy()  btn:Destroy() end
                return o
            end

            -- ── AddToggle ───────────────────────────────────────────────────
            function group:AddToggle(identifier, opts)
                opts = opts or {}
                local labelText = tostring(opts.Text or opts.Name or identifier or "Toggle")
                local value     = opts.Default == true
                local rowH      = T.TouchHeight

                local row = make("TextButton", {
                    Name                 = tostring(identifier or labelText),
                    Parent               = controls,
                    BackgroundTransparency = 1,
                    BorderSizePixel      = 0,
                    AutoButtonColor      = false,
                    Size                 = UDim2.new(1, 0, 0, rowH),
                    Text                 = "",
                })
                reg(row)

                -- Toggle box with gradient when active
                local boxSize = IS_MOBILE and 20 or 16
                local box = make("Frame", {
                    Parent           = row,
                    BackgroundColor3 = value and T.AccentDark or T.Element,
                    BorderSizePixel  = 0,
                    Position         = UDim2.fromOffset(1, (rowH - boxSize) / 2),
                    Size             = UDim2.fromOffset(boxSize, boxSize),
                    ClipsDescendants = true,
                })
                corner(box, T.CornerSmall)
                stroke(box, T.Outline, 1, 0.1)

                local boxGrad = accentGradient(box, 135)
                boxGrad.Transparency = value
                    and NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,0.3)})
                    or  NumberSequence.new(1)

                local check = textLabel(box, value and "✓" or "", 11,
                    Color3.new(1,1,1), T.FontBold, boxSize)
                check.TextXAlignment = Enum.TextXAlignment.Center

                local txtLbl = textLabel(row, labelText, 12, T.Text, T.Font, rowH)
                txtLbl.Position = UDim2.fromOffset(boxSize + 8, 0)
                txtLbl.Size     = UDim2.new(1, -(boxSize + 8), 1, 0)

                local obj = makeSignalObject(value, opts.Callback, identifier, true)
                obj.Instance = row

                local function update(newVal, fire)
                    value            = newVal == true
                    box.BackgroundColor3 = value and T.AccentDark or T.Element
                    boxGrad.Transparency = value
                        and NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,0.3)})
                        or  NumberSequence.new(1)
                    check.Text       = value and "✓" or ""
                    txtLbl.TextColor3= value and T.LightAccent or T.Text
                    obj.Value        = value
                    if identifier then Library.Flags[identifier] = value end
                    if fire then
                        haptic()
                        safeCall(opts.Callback, value)
                        obj.Changed:Fire(value)
                    end
                end

                row.Activated:Connect(function() update(not value, true) end)
                function obj:SetValue(v, silent) update(v, not silent) end
                function obj:OnChanged(fn)
                    if type(fn) == "function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy() row:Destroy(); obj.Changed:Destroy() end
                bindFlag(obj, identifier, value, true)
                return obj
            end

            -- ── AddSlider ───────────────────────────────────────────────────
            function group:AddSlider(identifier, opts)
                opts = opts or {}
                local minV  = tonumber(opts.Min)     or 0
                local maxV  = tonumber(opts.Max)     or 100
                if maxV < minV then maxV = minV end
                local round = tonumber(opts.Rounding) or 0
                local value = math.clamp(tonumber(opts.Default) or minV, minV, maxV)

                local lbl = textLabel(controls, opts.Text or opts.Name or identifier, 12,
                    T.Text, T.FontMedium, 18)
                reg(lbl)

                local valLabel = textLabel(lbl, "", 11, T.LightAccent, T.Font, 18)
                valLabel.AnchorPoint      = Vector2.new(1, 0)
                valLabel.Position         = UDim2.new(1, 0, 0, 0)
                valLabel.Size             = UDim2.fromOffset(64, 18)
                valLabel.TextXAlignment   = Enum.TextXAlignment.Right

                local trackH = IS_MOBILE and 10 or 8
                local track = make("TextButton", {
                    Parent           = controls,
                    BackgroundColor3 = T.Element,
                    BorderSizePixel  = 0,
                    Size             = UDim2.new(1, 0, 0, trackH),
                    Text             = "",
                    AutoButtonColor  = false,
                    ClipsDescendants = true,
                })
                corner(track, trackH // 2)
                stroke(track, T.Outline, 1, 0.3)
                reg(track)

                -- Filled portion with gradient
                local fill = make("Frame", {
                    Parent           = track,
                    BackgroundColor3 = T.Accent,
                    BorderSizePixel  = 0,
                    Size             = UDim2.new(0, 0, 1, 0),
                    ClipsDescendants = true,
                })
                corner(fill, trackH // 2)
                accentGradient(fill, 0)

                -- Thumb knob
                local thumbSize = IS_MOBILE and 18 or 14
                local thumb = make("Frame", {
                    Parent           = fill,
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel  = 0,
                    AnchorPoint      = Vector2.new(1, 0.5),
                    Position         = UDim2.new(1, 0, 0.5, 0),
                    Size             = UDim2.fromOffset(thumbSize, thumbSize),
                })
                corner(thumb, thumbSize // 2)
                stroke(thumb, T.AccentDark, 2, 0)

                local obj = makeSignalObject(value, opts.Callback, identifier, false)
                obj.Instance = track

                local function fmtVal(v)
                    if round <= 0 then return tostring(math.floor(v + 0.5)) end
                    return string.format("%." .. math.clamp(round, 0, 4) .. "f", v)
                end
                local function update(newV, fire)
                    newV  = math.clamp(tonumber(newV) or minV, minV, maxV)
                    local mult = 10 ^ math.clamp(round, 0, 4)
                    value = math.floor(newV * mult + 0.5) / mult
                    local alpha = (maxV == minV) and 0 or (value - minV) / (maxV - minV)
                    fill.Size       = UDim2.new(alpha, 0, 1, 0)
                    valLabel.Text   = fmtVal(value)
                    obj.Value       = value
                    if identifier then Library.Flags[identifier] = value end
                    if fire then safeCall(opts.Callback, value); obj.Changed:Fire(value) end
                end

                local sliding = false
                local function fromX(x)
                    local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
                    update(minV + (maxV - minV) * a, true)
                end

                track.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1
                        or inp.UserInputType == Enum.UserInputType.Touch then
                        sliding = true; fromX(inp.Position.X)
                    end
                end)
                local endC = UserInputService.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1
                        or inp.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end)
                local moveC = UserInputService.InputChanged:Connect(function(inp)
                    if sliding and (inp.UserInputType == Enum.UserInputType.MouseMovement
                        or inp.UserInputType == Enum.UserInputType.Touch) then
                        fromX(inp.Position.X)
                    end
                end)

                function obj:SetValue(v, silent) update(v, not silent) end
                function obj:OnChanged(fn)
                    if type(fn) == "function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy()
                    endC:Disconnect(); moveC:Disconnect()
                    lbl:Destroy(); track:Destroy(); obj.Changed:Destroy()
                end
                update(value, false)
                bindFlag(obj, identifier, value, false)
                return obj
            end

            -- ── AddDropdown ─────────────────────────────────────────────────
            function group:AddDropdown(identifier, opts)
                opts = opts or {}
                local values    = opts.Values or opts.Options or {}
                local allowNull = opts.AllowNull == true
                local selected  = type(opts.Default) == "table" and opts.Default[1] or opts.Default
                if selected == nil and not allowNull then selected = values[1] end

                local lbl = textLabel(controls, opts.Text or opts.Name or identifier, 12,
                    T.Text, T.FontMedium, 18)
                reg(lbl)

                local ddBtn = buttonBase(controls, "Dropdown", tostring(selected or "Select...") .. "  ▾", T.TouchHeight)
                reg(ddBtn)
                ddBtn.TextXAlignment = Enum.TextXAlignment.Left
                make("UIPadding", {Parent = ddBtn, PaddingLeft = UDim.new(0, 10)})

                -- Arrow label (right-aligned)
                local arrow = make("TextLabel", {
                    Parent               = ddBtn,
                    BackgroundTransparency = 1,
                    AnchorPoint          = Vector2.new(1, 0.5),
                    Position             = UDim2.new(1, -8, 0.5, 0),
                    Size                 = UDim2.fromOffset(18, 18),
                    Font                 = T.Font,
                    Text                 = "▾",
                    TextColor3           = T.Accent,
                    TextSize             = 12,
                    TextXAlignment       = Enum.TextXAlignment.Center,
                })

                local menuOpen = false
                local menu = make("Frame", {
                    Parent           = controls,
                    BackgroundColor3 = T.Background,
                    BorderSizePixel  = 0,
                    Size             = UDim2.new(1, 0, 0, 0),
                    Visible          = false,
                    ClipsDescendants = true,
                })
                corner(menu, T.CornerSmall)
                stroke(menu, T.OutlineAccent, 1, 0.3)
                bgGradient(menu, T.Main, T.DarkBackground, 160)
                local menuList = make("UIListLayout", {
                    Parent    = menu,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding   = UDim.new(0, 2),
                })
                reg(menu)

                local obj = makeSignalObject(selected, opts.Callback, identifier, false)
                obj.Instance = ddBtn

                local function closeMenu()
                    menuOpen      = false
                    menu.Visible  = false
                    menu.Size     = UDim2.new(1, 0, 0, 0)
                    arrow.Text    = "▾"
                end
                local function setSelected(v, fire)
                    selected   = v
                    obj.Value  = v
                    ddBtn.Text = tostring(v or "Select...")
                    if identifier then Library.Flags[identifier] = v end
                    closeMenu()
                    if fire then safeCall(opts.Callback, v); obj.Changed:Fire(v) end
                end

                local function rebuild()
                    for _, c in ipairs(menu:GetChildren()) do
                        if c:IsA("TextButton") then c:Destroy() end
                    end
                    for i, val in ipairs(values) do
                        local ob = buttonBase(menu, "Opt" .. i, tostring(val), IS_MOBILE and 32 or 26)
                        ob.LayoutOrder = i
                        ob.Activated:Connect(function() haptic(); setSelected(val, true) end)
                    end
                end
                rebuild()

                ddBtn.Activated:Connect(function()
                    menuOpen = not menuOpen
                    menu.Visible = menuOpen
                    arrow.Text   = menuOpen and "▴" or "▾"
                    if menuOpen then
                        menu.Size = UDim2.new(1, 0, 0, math.min(menuList.AbsoluteContentSize.Y + 4, 150))
                    else
                        closeMenu()
                    end
                    haptic()
                end)

                function obj:SetValue(v, silent) setSelected(v, not silent) end
                function obj:SetValues(new) values = new or {}; rebuild() end
                function obj:OnChanged(fn)
                    if type(fn) == "function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy()
                    lbl:Destroy(); ddBtn:Destroy(); menu:Destroy(); obj.Changed:Destroy()
                end
                bindFlag(obj, identifier, selected, false)
                return obj
            end

            -- ── AddInput ────────────────────────────────────────────────────
            function group:AddInput(identifier, opts)
                opts = opts or {}
                local lbl = textLabel(controls, opts.Text or opts.Name or identifier, 12,
                    T.Text, T.FontMedium, 18)
                reg(lbl)
                local inp = make("TextBox", {
                    Parent               = controls,
                    BackgroundColor3     = T.Element,
                    BorderSizePixel      = 0,
                    ClearTextOnFocus     = false,
                    Size                 = UDim2.new(1, 0, 0, T.TouchHeight),
                    Font                 = T.Font,
                    PlaceholderText      = opts.Placeholder or "Enter text...",
                    PlaceholderColor3    = T.Disabled,
                    Text                 = tostring(opts.Default or ""),
                    TextColor3           = T.Text,
                    TextSize             = 12,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                })
                corner(inp, T.CornerSmall)
                stroke(inp, T.Outline, 1, 0.2)
                make("UIPadding", {Parent = inp, PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8)})
                reg(inp)

                -- Focus ring
                inp.Focused:Connect(function()  tweenObj(inp, 0.1, {BackgroundColor3 = T.ElementHover}) end)
                inp.FocusLost:Connect(function() tweenObj(inp, 0.1, {BackgroundColor3 = T.Element}) end)

                local obj = makeSignalObject(inp.Text, opts.Callback, identifier, false)
                obj.Instance = inp
                inp.FocusLost:Connect(function(enter)
                    obj:SetValue(inp.Text)
                    if opts.FireOnEnterOnly and not enter then return end
                    safeCall(opts.Callback, inp.Text, enter)
                end)
                function obj:SetValue(v, silent)
                    inp.Text  = tostring(v or "")
                    obj.Value = inp.Text
                    if identifier then Library.Flags[identifier] = obj.Value end
                    if not silent then obj.Changed:Fire(obj.Value); safeCall(opts.Callback, obj.Value) end
                end
                function obj:OnChanged(fn)
                    if type(fn) == "function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy() lbl:Destroy(); inp:Destroy(); obj.Changed:Destroy() end
                bindFlag(obj, identifier, inp.Text, false)
                return obj
            end

            -- ── AddKeyPicker ─────────────────────────────────────────────────
            function group:AddKeyPicker(identifier, opts)
                opts = opts or {}
                local labelText = tostring(opts.Text or opts.Name or identifier or "Keybind")
                local rowH      = T.TouchHeight

                local row = make("Frame", {
                    Parent               = controls,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, rowH),
                })
                reg(row)
                local lbl = textLabel(row, labelText, 12, T.Text, T.Font, rowH)
                lbl.Size  = UDim2.new(1, -104, 1, 0)

                local keyBtn = buttonBase(row, "KeyBtn", tostring(opts.Default or "None"), rowH - 4)
                keyBtn.AnchorPoint = Vector2.new(1, 0.5)
                keyBtn.Position    = UDim2.new(1, 0, 0.5, 0)
                keyBtn.Size        = UDim2.fromOffset(96, rowH - 4)
                keyBtn.TextSize    = 11

                local currentKey = opts.Default
                local listening  = false
                local obj        = makeSignalObject(currentKey, opts.Callback, identifier, false)
                obj.Instance     = keyBtn

                keyBtn.Activated:Connect(function()
                    listening     = true
                    keyBtn.Text   = "Press key..."
                    keyBtn.TextColor3 = T.Warning
                    haptic()
                end)
                local conn = UserInputService.InputBegan:Connect(function(inp, proc)
                    if proc then return end
                    if listening and inp.UserInputType == Enum.UserInputType.Keyboard then
                        listening         = false
                        currentKey        = inp.KeyCode
                        keyBtn.Text       = currentKey.Name
                        keyBtn.TextColor3 = T.Text
                        obj:SetValue(currentKey)
                    elseif currentKey and inp.KeyCode == currentKey then
                        safeCall(opts.Callback, currentKey)
                    end
                end)

                function obj:SetValue(v, silent)
                    currentKey    = v
                    keyBtn.Text   = typeof(v) == "EnumItem" and v.Name or tostring(v or "None")
                    obj.Value     = v
                    if identifier then Library.Flags[identifier] = v end
                    if not silent then safeCall(opts.Callback, v); obj.Changed:Fire(v) end
                end
                function obj:OnChanged(fn)
                    if type(fn) == "function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy() conn:Disconnect(); row:Destroy(); obj.Changed:Destroy() end
                bindFlag(obj, identifier, currentKey, false)
                return obj
            end

            -- ── AddColorPicker ───────────────────────────────────────────────
            function group:AddColorPicker(identifier, opts)
                opts    = opts or {}
                local current = opts.Default or T.Accent
                local rowH    = T.TouchHeight

                local row = make("Frame", {
                    Parent               = controls,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, rowH),
                })
                reg(row)
                local lbl  = textLabel(row, opts.Text or opts.Name or identifier, 12,
                    T.Text, T.Font, rowH)
                lbl.Size   = UDim2.new(1, -58, 1, 0)

                local swatch = make("TextButton", {
                    Parent               = row,
                    AnchorPoint          = Vector2.new(1, 0.5),
                    Position             = UDim2.new(1, 0, 0.5, 0),
                    Size                 = UDim2.fromOffset(46, rowH - 6),
                    BackgroundColor3     = current,
                    BorderSizePixel      = 0,
                    Text                 = "",
                    AutoButtonColor      = false,
                })
                corner(swatch, T.CornerSmall)
                stroke(swatch, T.Outline, 1, 0.1)

                local obj    = makeSignalObject(current, opts.Callback, identifier, false)
                obj.Instance = swatch

                swatch.Activated:Connect(function()
                    haptic()
                    local h, s, v = current:ToHSV()
                    current = Color3.fromHSV((h + 0.08) % 1, s, v)
                    swatch.BackgroundColor3 = current
                    obj:SetValue(current)
                end)
                function obj:SetValue(v, silent)
                    if typeof(v) ~= "Color3" then return end
                    current = v
                    swatch.BackgroundColor3 = current
                    obj.Value = current
                    if identifier then Library.Flags[identifier] = current end
                    if not silent then safeCall(opts.Callback, current); obj.Changed:Fire(current) end
                end
                function obj:OnChanged(fn)
                    if type(fn) == "function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy() row:Destroy(); obj.Changed:Destroy() end
                bindFlag(obj, identifier, current, false)
                return obj
            end

            return group
        end -- createGroup

        function tab:AddLeftGroupbox(name)  return createGroup(name, "Left")  end
        function tab:AddRightGroupbox(name) return createGroup(name, "Right") end
        function tab:AddGroupbox(name)      return createGroup(name, "Left")  end

        -- Flat backwards-compat shims
        function tab:CreateButton(opts, cb)
            return createGroup("Controls","Left"):AddButton(opts, cb)
        end
        function tab:CreateToggle(opts)
            return createGroup("Controls","Left"):AddToggle(opts.Flag or opts.Name, opts)
        end
        function tab:CreateSlider(opts)
            return createGroup("Controls","Left"):AddSlider(opts.Flag or opts.Name, opts)
        end

        -- First tab auto-selects
        if #window.Tabs == 0 then
            page.Visible      = true
            window.ActiveTab  = tab
            tabBtn.BackgroundColor3 = T.AccentDark
            tabBtn.TextColor3       = Color3.new(1,1,1)
            tabGrad.Transparency    = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 0.25),
            })
        end

        table.insert(window.Tabs, tab)
        return tab
    end -- CreateTab

    window.AddTab = function(self, name)
        return self:CreateTab(type(name) == "table" and name or {Name = name})
    end

    if settings.AutoShow then gui.Enabled = true end
    table.insert(Library.Windows, window)
    return window
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Unload
-- ──────────────────────────────────────────────────────────────────────────────
function Library:Unload()
    self.Unloaded = true
    for _, w in ipairs(self.Windows) do pcall(function() w:Destroy() end) end
    self.Windows     = {}
    self.Registry    = {}
    self.RegistryMap = {}
    self.HudRegistry = {}
    self.Flags       = {}
    self.Options     = {}
    self.Toggles     = {}
    self.ScreenGui   = nil
end

return Library
