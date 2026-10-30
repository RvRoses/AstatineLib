--[[
    AstatineLib v4.0 — LoveUp-Style Layout for Roblox
    Dark near-black shell · Purple accent · Left nav rail · Two-panel content
    Roblox avatar chip in top-right corner
    Linoria-compatible API preserved.

    Layout reference: LoveUp overlay (screenshots)
    Key differences from v3:
      - LEFT NAV RAIL (vertical, icon + label) instead of horizontal tab bar
      - TWO-PANEL content area (left groupboxes | right groupboxes side by side)
      - TOP BAR: logo/title left · avatar ImageLabel + username right
      - PILL toggles (rounded capsule, slide animation)
      - Slider rows show "XX%" right-aligned
      - No green — purple/violet accent throughout
      - Mobile: nav rail collapses to icon-only; panels stack
]]

local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local ok_haptic, HapticService = pcall(function()
    return game:GetService("HapticService")
end)
if not ok_haptic then HapticService = nil end

local LocalPlayer = Players.LocalPlayer

-- ─────────────────────────────────────────────────────────────────────────────
-- Mobile detection
-- ─────────────────────────────────────────────────────────────────────────────
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local function haptic()
    if IS_MOBILE and HapticService then
        pcall(function()
            HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.18)
            task.delay(0.055, function()
                pcall(function()
                    HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
                end)
            end)
        end)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Library root
-- ─────────────────────────────────────────────────────────────────────────────
local Library = {
    Version     = "4.0.0",
    Registry    = {},
    RegistryMap = {},
    HudRegistry = {},
    Flags       = {},
    Options     = {},
    Toggles     = {},
    ScreenGui   = nil,
    Windows     = {},
    Unloaded    = false,

    Theme = {
        -- Accent (purple/violet, matching reference)
        Accent        = Color3.fromRGB(124, 77, 255),
        AccentLight   = Color3.fromRGB(167, 139, 250),
        AccentDark    = Color3.fromRGB(91, 50, 200),
        AccentGlow    = Color3.fromRGB(139, 92, 246),

        -- Backgrounds (near-black like reference)
        Background    = Color3.fromRGB(15, 15, 20),
        NavBg         = Color3.fromRGB(20, 20, 28),
        Main          = Color3.fromRGB(24, 24, 33),
        Panel         = Color3.fromRGB(28, 28, 38),
        Element       = Color3.fromRGB(35, 35, 48),
        ElementHover  = Color3.fromRGB(44, 44, 60),

        -- Borders
        Outline       = Color3.fromRGB(50, 50, 68),
        OutlineFocus  = Color3.fromRGB(124, 77, 255),

        -- Text
        Text          = Color3.fromRGB(240, 240, 252),
        SubText       = Color3.fromRGB(140, 140, 170),
        Disabled      = Color3.fromRGB(80, 80, 105),
        NavText       = Color3.fromRGB(155, 155, 185),
        NavTextActive = Color3.fromRGB(240, 240, 252),

        -- Status
        Success       = Color3.fromRGB(52, 211, 153),
        Warning       = Color3.fromRGB(251, 191, 36),
        Danger        = Color3.fromRGB(239, 68, 68),

        -- Fonts
        Font          = Enum.Font.Gotham,
        FontBold      = Enum.Font.GothamBold,
        FontMedium    = Enum.Font.GothamMedium,

        -- Sizing
        CornerMain    = 12,
        CornerPanel   = 10,
        CornerElem    = 7,
        CornerSmall   = 5,
        NavWidth      = IS_MOBILE and 48 or 160,
        RowH          = IS_MOBILE and 36 or 30,
        TopH          = 48,
    },

    ThemeManager = {},
    SaveManager  = {},
}

local T = Library.Theme

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────
local function safeCall(fn, ...)
    if type(fn) ~= "function" then return true end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[AstatineLib v4] " .. tostring(err)) end
    return ok
end

local function make(cls, props)
    local o = Instance.new(cls)
    for k, v in pairs(props or {}) do o[k] = v end
    return o
end

local function corner(parent, r)
    return make("UICorner", {Parent = parent, CornerRadius = UDim.new(0, r or T.CornerElem)})
end

local function stroke(parent, color, thick, trans)
    return make("UIStroke", {
        Parent          = parent,
        Color           = color or T.Outline,
        Thickness       = thick or 1,
        Transparency    = trans or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function tw(obj, dur, props)
    local ti = TweenInfo.new(dur or 0.13, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local t  = TweenService:Create(obj, ti, props)
    t:Play()
    return t
end

local function lbl(parent, text, size, color, font, h)
    return make("TextLabel", {
        Parent               = parent,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, h or 18),
        Font                 = font or T.Font,
        Text                 = tostring(text or ""),
        TextColor3           = color or T.Text,
        TextSize             = size or 12,
        TextXAlignment       = Enum.TextXAlignment.Left,
        TextYAlignment       = Enum.TextYAlignment.Center,
        TextTruncate         = Enum.TextTruncate.AtEnd,
    })
end

-- Standard button with hover glow
local function btn(parent, name, text, h)
    h = h or T.RowH
    local b = make("TextButton", {
        Name             = name or "Btn",
        Parent           = parent,
        BackgroundColor3 = T.Element,
        BorderSizePixel  = 0,
        AutoButtonColor  = false,
        Size             = UDim2.new(1, 0, 0, h),
        Font             = T.FontMedium,
        Text             = text or "",
        TextColor3       = T.Text,
        TextSize         = 12,
        ClipsDescendants = true,
    })
    corner(b, T.CornerSmall)
    stroke(b, T.Outline, 1, 0.35)

    local glow = make("Frame", {
        Parent               = b,
        BackgroundColor3     = T.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
        Size                 = UDim2.new(1,0,1,0),
        ZIndex               = b.ZIndex + 1,
    })
    corner(glow, T.CornerSmall)

    b.MouseEnter:Connect(function() tw(glow, 0.13, {BackgroundTransparency = 0.87}) end)
    b.MouseLeave:Connect(function() tw(glow, 0.13, {BackgroundTransparency = 1}) end)
    b.MouseButton1Down:Connect(function() tw(glow, 0.07, {BackgroundTransparency = 0.74}) end)
    b.MouseButton1Up:Connect(function() tw(glow, 0.1, {BackgroundTransparency = 0.87}) end)
    return b
end

local function bindFlag(ctrl, id, init, isToggle)
    if id and id ~= "" then
        Library.Flags[id] = init
        if isToggle then Library.Toggles[id] = ctrl
        else             Library.Options[id]  = ctrl end
    end
end

local function signal(init, cb, id, isToggle)
    local o = {Value = init, Callback = cb, Changed = Instance.new("BindableEvent"), _c = {}}
    function o:SetValue(v, silent)
        self.Value = v
        if id then Library.Flags[id] = v end
        if not silent then safeCall(self.Callback, v); self.Changed:Fire(v) end
    end
    function o:OnChanged(fn)
        if type(fn) == "function" then table.insert(self._c, self.Changed.Event:Connect(fn)) end
        return self
    end
    function o:Destroy()
        for _, c in ipairs(self._c) do c:Disconnect() end
        self.Changed:Destroy()
    end
    bindFlag(o, id, init, isToggle)
    return o
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public helpers
-- ─────────────────────────────────────────────────────────────────────────────
function Library:Create(cls, props) return make(cls, props) end
function Library:CreateCorner(p, r) return corner(p, r) end
function Library:SetTheme(t)
    for k, v in pairs(t or {}) do if T[k] ~= nil then T[k] = v end end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Notifications
-- ─────────────────────────────────────────────────────────────────────────────
function Library:Notify(message, duration)
    local gui = self.ScreenGui
    if not gui or not gui.Parent then warn("[AstatineLib v4] " .. tostring(message)); return end

    local holder = gui:FindFirstChild("Notifs") or (function()
        local h = make("Frame", {
            Name = "Notifs", Parent = gui,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 1),
            Position    = UDim2.new(1, -14, 1, -14),
            Size        = UDim2.fromOffset(300, 260),
        })
        make("UIListLayout", {
            Parent = h, SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8),
        })
        return h
    end)()

    local item = make("Frame", {
        Parent = holder, BackgroundColor3 = T.Panel,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 56),
        BackgroundTransparency = 1, ClipsDescendants = true,
    })
    corner(item, T.CornerElem)
    stroke(item, T.OutlineFocus, 1, 0.6)

    local bar = make("Frame", {
        Parent = item, BackgroundColor3 = T.Accent,
        BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0),
    })
    corner(bar, 3)

    local l = lbl(item, message, 12, T.Text, T.Font, 56)
    l.Position = UDim2.fromOffset(12, 0)
    l.Size     = UDim2.new(1, -24, 1, 0)
    l.TextWrapped = true

    tw(item, 0.2, {BackgroundTransparency = 0})
    task.delay(duration or 3.5, function()
        if item.Parent then
            tw(item, 0.18, {BackgroundTransparency = 1})
            task.wait(0.2)
            if item.Parent then item:Destroy() end
        end
    end)
end
Library.CreateNotification = Library.Notify

-- ─────────────────────────────────────────────────────────────────────────────
-- CreateWindow  — the full LoveUp-style shell
-- ─────────────────────────────────────────────────────────────────────────────
function Library:CreateWindow(settings)
    settings = settings or {}
    assert(LocalPlayer, "CreateWindow: client context required")

    local existing = CoreGui:FindFirstChild("AstatineLib_v4")
    if existing then existing:Destroy() end

    local gui = make("ScreenGui", {
        Name = "AstatineLib_v4", Parent = CoreGui,
        ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 65,
    })
    self.ScreenGui = gui
    self.Unloaded  = false

    local vp = workspace.CurrentCamera.ViewportSize
    local mobile = IS_MOBILE or vp.X < 680

    local winW = mobile and math.min(vp.X - 10, 480) or (tonumber(settings.Width) or 780)
    local winH = mobile and math.min(vp.Y - 46, 700) or (tonumber(settings.Height) or 520)
    local navW = mobile and 48 or 160
    local topH = T.TopH

    local initPos = settings.Center ~= false
        and UDim2.new(0.5, -winW/2, 0.5, -winH/2)
        or  UDim2.new(0, 60, 0, 60)

    -- ── Shadow ───────────────────────────────────────────────────────────────
    local shadow = make("Frame", {
        Name = "Shadow", Parent = gui,
        BackgroundColor3 = Color3.new(0,0,0),
        BackgroundTransparency = 0.58, BorderSizePixel = 0,
        Position = UDim2.new(initPos.X.Scale, initPos.X.Offset + 5,
                             initPos.Y.Scale, initPos.Y.Offset + 8),
        Size = UDim2.fromOffset(winW, winH),
        ZIndex = 1,
    })
    corner(shadow, T.CornerMain)

    -- ── Main frame ────────────────────────────────────────────────────────────
    local main = make("Frame", {
        Name = "Main", Parent = gui,
        BackgroundColor3 = T.Background,
        BorderSizePixel = 0, Position = initPos,
        Size = UDim2.fromOffset(winW, winH),
        ClipsDescendants = true, ZIndex = 2,
    })
    corner(main, T.CornerMain)
    stroke(main, T.Outline, 1, 0)

    -- ── Top bar ───────────────────────────────────────────────────────────────
    local top = make("Frame", {
        Name = "TopBar", Parent = main,
        BackgroundColor3 = T.NavBg,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, topH),
    })
    -- Fake top-round: overlap bottom edge
    make("Frame", {
        Parent = top, BackgroundColor3 = T.NavBg,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -T.CornerMain),
        Size = UDim2.new(1, 0, 0, T.CornerMain),
    })
    corner(top, T.CornerMain)

    -- Bottom border line on top bar
    make("Frame", {
        Parent = top, BackgroundColor3 = T.Outline,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
    })

    -- Logo / title (left side)
    local logoBox = make("Frame", {
        Parent = top, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(0, navW - 20, 1, 0),
    })
    -- Accent square icon
    local iconBg = make("Frame", {
        Parent = logoBox, BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
    })
    corner(iconBg, 6)
    make("TextLabel", {
        Parent = iconBg, BackgroundTransparency = 1,
        Size = UDim2.new(1,0,1,0),
        Font = T.FontBold, Text = "✦",
        TextColor3 = Color3.new(1,1,1), TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    local titleLbl = make("TextLabel", {
        Parent = logoBox, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(32, 0),
        Size = UDim2.new(1, -32, 1, 0),
        Font = T.FontBold, Text = tostring(settings.Title or "AstatineLib"),
        TextColor3 = T.Text, TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    -- Avatar chip (right side)  — pulls from Roblox Thumbs service
    local avatarChip = make("Frame", {
        Parent = top, BackgroundColor3 = T.Element,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -42, 0.5, 0),
        Size = UDim2.fromOffset(mobile and 110 or 140, 32),
        ClipsDescendants = true,
    })
    corner(avatarChip, 16)
    stroke(avatarChip, T.Outline, 1, 0.25)

    local avatarImg = make("ImageLabel", {
        Parent = avatarChip, BackgroundColor3 = T.Element,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromOffset(4, 0),
        Size = UDim2.fromOffset(24, 24),
        Image = "rbxthumb://type=AvatarHeadShot&id=" ..
                tostring(LocalPlayer.UserId) .. "&w=48&h=48",
        ImageColor3 = Color3.new(1,1,1),
    })
    corner(avatarImg, 12)

    local avatarName = make("TextLabel", {
        Parent = avatarChip, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(32, 0),
        Size = UDim2.new(1, -38, 1, 0),
        Font = T.FontMedium, Text = LocalPlayer.DisplayName,
        TextColor3 = T.Text, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    -- Update display name if it changes
    LocalPlayer:GetPropertyChangedSignal("DisplayName"):Connect(function()
        if avatarName and avatarName.Parent then
            avatarName.Text = LocalPlayer.DisplayName
        end
    end)

    -- Close button
    local closeBtn = make("TextButton", {
        Parent = top, BackgroundColor3 = T.Element,
        BackgroundTransparency = 0.4, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        AutoButtonColor = false,
        Font = T.FontBold, Text = "×",
        TextColor3 = T.SubText, TextSize = 18,
    })
    corner(closeBtn, T.CornerSmall)
    closeBtn.MouseEnter:Connect(function() tw(closeBtn, 0.1, {TextColor3 = T.Text}) end)
    closeBtn.MouseLeave:Connect(function() tw(closeBtn, 0.1, {TextColor3 = T.SubText}) end)
    closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

    -- ── Nav rail (left vertical) ──────────────────────────────────────────────
    local navRail = make("Frame", {
        Name = "NavRail", Parent = main,
        BackgroundColor3 = T.NavBg,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, topH),
        Size = UDim2.new(0, navW, 1, -topH),
        ClipsDescendants = true,
    })
    -- Right border
    make("Frame", {
        Parent = navRail, BackgroundColor3 = T.Outline,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
    })

    local navList = make("Frame", {
        Parent = navRail, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(1, 0, 1, -8),
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    make("UIListLayout", {
        Parent = navList, SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })
    make("UIPadding", {
        Parent = navList, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
    })

    -- ── Content area (right of nav) ───────────────────────────────────────────
    local content = make("Frame", {
        Name = "Content", Parent = main,
        BackgroundColor3 = T.Background,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(navW, topH),
        Size = UDim2.new(1, -navW, 1, -topH),
        ClipsDescendants = true,
    })

    -- ── Drag ──────────────────────────────────────────────────────────────────
    local dragging, dragStart, startPos, dragInp = false, nil, nil, nil
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
            dragInp = inp
        end
    end)
    local dragConn = UserInputService.InputChanged:Connect(function(inp)
        if not gui.Parent then return end
        if dragging and inp == dragInp then
            local d  = inp.Position - dragStart
            local nx = math.clamp(startPos.X.Offset + d.X, 0, vp.X - winW)
            local ny = math.clamp(startPos.Y.Offset + d.Y, 0, vp.Y - winH)
            main.Position   = UDim2.new(startPos.X.Scale, nx, startPos.Y.Scale, ny)
            shadow.Position = UDim2.new(startPos.X.Scale, nx + 5, startPos.Y.Scale, ny + 8)
        end
    end)

    -- ── Window object ─────────────────────────────────────────────────────────
    local window = {
        WindowFrame = main,
        ScreenGui   = gui,
        Tabs        = {},
        ActiveTab   = nil,
        _conns      = {dragConn},
    }

    function window:SetTitle(v) titleLbl.Text = tostring(v) end
    function window:SetVisible(v) gui.Enabled = v == true end
    function window:Toggle() gui.Enabled = not gui.Enabled end
    function window:Destroy()
        if gui and gui.Parent then gui:Destroy() end
        if Library.ScreenGui == gui then Library.ScreenGui = nil end
        for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    end

    -- ── CreateTab / AddTab ────────────────────────────────────────────────────
    function window:CreateTab(tabSettings)
        if type(tabSettings) == "string" then tabSettings = {Name = tabSettings} end
        tabSettings = tabSettings or {}
        local tabName = tostring(tabSettings.Name or tabSettings.Title or "Tab")
        local tabIcon = tostring(tabSettings.Icon or "☰")

        local isFirst = #self.Tabs == 0

        -- Nav button
        local navH = mobile and 40 or 38
        local navBtn = make("TextButton", {
            Name = tabName .. "Nav",
            Parent = navList,
            BackgroundColor3 = isFirst and T.Element or Color3.new(0,0,0),
            BackgroundTransparency = isFirst and 0 or 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, navH),
            Text = "",
            LayoutOrder = #self.Tabs + 1,
        })
        corner(navBtn, T.CornerSmall)

        -- Accent left bar for active tab
        local navAccent = make("Frame", {
            Parent = navBtn,
            BackgroundColor3 = T.Accent,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 4),
            Size = UDim2.fromOffset(3, navH - 8),
            Visible = isFirst,
        })
        corner(navAccent, 2)

        if mobile then
            -- Icon only on mobile
            make("TextLabel", {
                Parent = navBtn, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Font = T.Font, Text = tabIcon,
                TextColor3 = isFirst and T.Text or T.NavText,
                TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center,
            })
        else
            local iconLbl = make("TextLabel", {
                Parent = navBtn, BackgroundTransparency = 1,
                Position = UDim2.fromOffset(12, 0),
                Size = UDim2.fromOffset(20, navH),
                Font = T.Font, Text = tabIcon,
                TextColor3 = isFirst and T.Text or T.NavText,
                TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center,
            })
            local nameLbl = make("TextLabel", {
                Parent = navBtn, BackgroundTransparency = 1,
                Position = UDim2.fromOffset(36, 0),
                Size = UDim2.new(1, -44, 1, 0),
                Font = T.FontMedium, Text = tabName,
                TextColor3 = isFirst and T.NavTextActive or T.NavText,
                TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
        end

        -- Content page (scroll)
        local page = make("ScrollingFrame", {
            Name = tabName .. "Page",
            Parent = content,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(12, 10),
            Size = UDim2.new(1, -24, 1, -20),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = mobile and 5 or 4,
            ScrollBarImageColor3 = T.Accent,
            ScrollBarImageTransparency = 0.2,
            Visible = isFirst,
        })

        -- Two-column layout inside page
        local columns = make("Frame", {
            Parent = page, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        })
        local leftCol = make("Frame", {
            Name = "Left", Parent = columns, BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(mobile and 1 or 0.5, mobile and 0 or -6, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        local rightCol = make("Frame", {
            Name = "Right", Parent = columns, BackgroundTransparency = 1,
            Position = UDim2.new(mobile and 0 or 0.5, mobile and 0 or 6, 0, 0),
            Size = UDim2.new(mobile and 0 or 0.5, mobile and 0 or -6, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = not mobile,
        })
        make("UIListLayout", {Parent = leftCol,  SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10)})
        make("UIListLayout", {Parent = rightCol, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10)})

        local tab = {
            Name = tabName, NavBtn = navBtn, Page = page,
            Left = leftCol, Right = rightCol,
            _gc = {Left = 0, Right = 0},
        }

        local function selectTab()
            for _, other in ipairs(window.Tabs) do
                other.Page.Visible = false
                tw(other.NavBtn, 0.12, {BackgroundTransparency = 1})
                -- hide accent bar + dim text
                local otherAccent = other.NavBtn:FindFirstChild("AccentBar")
                if otherAccent then otherAccent.Visible = false end
                for _, ch in ipairs(other.NavBtn:GetChildren()) do
                    if ch:IsA("TextLabel") then
                        tw(ch, 0.12, {TextColor3 = T.NavText})
                    end
                end
            end
            page.Visible = true
            tw(navBtn, 0.12, {BackgroundTransparency = 0, BackgroundColor3 = T.Element})
            navAccent.Visible = true
            for _, ch in ipairs(navBtn:GetChildren()) do
                if ch:IsA("TextLabel") then
                    tw(ch, 0.12, {TextColor3 = T.NavTextActive})
                end
            end
            window.ActiveTab = tab
            haptic()
        end
        navAccent.Name = "AccentBar"
        navBtn.Activated:Connect(selectTab)

        -- ── Groupbox factory ──────────────────────────────────────────────────
        local function makeGroup(groupName, side)
            side = side or "Left"
            local col = (side == "Right" and not mobile) and rightCol or leftCol
            tab._gc[side] = tab._gc[side] + 1

            local gf = make("Frame", {
                Name = tostring(groupName or "Group"),
                Parent = col,
                BackgroundColor3 = T.Panel,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 40),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = tab._gc[side],
                ClipsDescendants = false,
            })
            corner(gf, T.CornerPanel)
            stroke(gf, T.Outline, 1, 0.1)

            -- Section header (plain text, no gradient fill — matches reference)
            local hdr = make("Frame", {
                Name = "Header", Parent = gf,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 34),
            })

            -- Small accent icon dot
            local dot = make("Frame", {
                Parent = hdr, BackgroundColor3 = T.Accent,
                BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.fromOffset(12, 17),
                Size = UDim2.fromOffset(4, 4),
            })
            corner(dot, 2)

            local hdrLbl = lbl(hdr, groupName or "Group", 12, T.SubText, T.FontMedium, 34)
            hdrLbl.Position = UDim2.fromOffset(22, 0)
            hdrLbl.Size     = UDim2.new(1, -30, 1, 0)

            -- Divider
            make("Frame", {
                Parent = gf, BackgroundColor3 = T.Outline,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(0, 34),
                Size = UDim2.new(1, 0, 0, 1),
            })

            local ctrls = make("Frame", {
                Name = "Ctrls", Parent = gf,
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(12, 40),
                Size = UDim2.new(1, -24, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
            })
            make("UIListLayout", {
                Parent = ctrls, SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 8),
            })
            make("UIPadding", {Parent = ctrls, PaddingBottom = UDim.new(0, 12)})

            local group = {Container = gf, Controls = ctrls, Name = groupName}
            local ord = 0
            local function reg(i) ord = ord + 1; i.LayoutOrder = ord; return i end

            -- ── AddLabel ───────────────────────────────────────────────────────
            function group:AddLabel(t)
                local l = lbl(ctrls, t, 12, T.SubText, T.Font, 20)
                reg(l)
                local o = {Instance = l}
                function o:SetText(v) l.Text = tostring(v) end
                function o:Destroy() l:Destroy() end
                return o
            end

            -- ── AddDivider ─────────────────────────────────────────────────────
            function group:AddDivider()
                local line = make("Frame", {
                    Parent = ctrls, BackgroundColor3 = T.Outline,
                    BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1),
                })
                reg(line); return line
            end

            -- ── AddParagraph ───────────────────────────────────────────────────
            function group:AddParagraph(title, body)
                local w = make("Frame", {
                    Parent = ctrls, BackgroundColor3 = T.Element,
                    BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 54),
                    AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true,
                })
                corner(w, T.CornerSmall); reg(w)
                local tl = lbl(w, title or "Info", 12, T.AccentLight, T.FontBold, 22)
                tl.Position = UDim2.fromOffset(8, 4); tl.Size = UDim2.new(1, -16, 0, 22)
                local bl = lbl(w, body or "", 11, T.SubText, T.Font, 0)
                bl.Position = UDim2.fromOffset(8, 27); bl.Size = UDim2.new(1, -16, 0, 0)
                bl.AutomaticSize = Enum.AutomaticSize.Y; bl.TextWrapped = true
                make("UIPadding", {Parent = w, PaddingBottom = UDim.new(0, 8)})
                local o = {}
                function o:SetText(a, b) tl.Text = tostring(a or ""); bl.Text = tostring(b or "") end
                function o:Destroy() w:Destroy() end
                return o
            end

            -- ── AddButton ──────────────────────────────────────────────────────
            function group:AddButton(nameOrOpts, cb)
                local opts = type(nameOrOpts) == "table" and nameOrOpts
                    or {Name = nameOrOpts, Callback = cb}
                local b = btn(ctrls, tostring(opts.Name or "Button"),
                    tostring(opts.Name or opts.Text or "Button"), T.RowH)
                reg(b)
                b.Activated:Connect(function()
                    haptic(); safeCall(opts.Func or opts.Callback)
                end)
                local o = {Instance = b}
                function o:SetText(v) b.Text = tostring(v) end
                function o:Press() safeCall(opts.Func or opts.Callback) end
                function o:Destroy() b:Destroy() end
                return o
            end

            -- ── AddToggle (pill style) ─────────────────────────────────────────
            function group:AddToggle(identifier, opts)
                opts = opts or {}
                local labelText = tostring(opts.Text or opts.Name or identifier or "Toggle")
                local value     = opts.Default == true
                local rowH      = T.RowH

                local row = make("TextButton", {
                    Name = tostring(identifier or labelText),
                    Parent = ctrls, BackgroundTransparency = 1,
                    BorderSizePixel = 0, AutoButtonColor = false,
                    Size = UDim2.new(1, 0, 0, rowH), Text = "",
                })
                reg(row)

                local nameLbl = lbl(row, labelText, 12, T.Text, T.Font, rowH)
                nameLbl.Size = UDim2.new(1, -52, 1, 0)

                -- Pill track
                local pillW, pillH = 38, 20
                local pill = make("Frame", {
                    Parent = row, BackgroundColor3 = value and T.Accent or T.Element,
                    BorderSizePixel = 0,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(pillW, pillH),
                    ClipsDescendants = true,
                })
                corner(pill, pillH // 2)
                stroke(pill, value and T.AccentDark or T.Outline, 1, 0.1)

                -- Knob
                local knobSize = pillH - 6
                local knob = make("Frame", {
                    Parent = pill, BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0,
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = value
                        and UDim2.new(1, -(knobSize + 3), 0.5, 0)
                        or  UDim2.fromOffset(3, 0),
                    Size = UDim2.fromOffset(knobSize, knobSize),
                })
                corner(knob, knobSize // 2)

                local obj = signal(value, opts.Callback, identifier, true)
                obj.Instance = row

                local function update(newVal, fire)
                    value = newVal == true
                    tw(pill, 0.16, {BackgroundColor3 = value and T.Accent or T.Element})
                    tw(knob, 0.16, {
                        Position = value
                            and UDim2.new(1, -(knobSize + 3), 0.5, 0)
                            or  UDim2.fromOffset(3, 0),
                    })
                    tw(nameLbl, 0.12, {TextColor3 = value and T.Text or T.SubText})
                    obj.Value = value
                    if identifier then Library.Flags[identifier] = value end
                    if fire then haptic(); safeCall(opts.Callback, value); obj.Changed:Fire(value) end
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

            -- ── AddSlider ──────────────────────────────────────────────────────
            function group:AddSlider(identifier, opts)
                opts = opts or {}
                local minV  = tonumber(opts.Min)      or 0
                local maxV  = tonumber(opts.Max)      or 100
                if maxV < minV then maxV = minV end
                local rnd   = tonumber(opts.Rounding) or 0
                local value = math.clamp(tonumber(opts.Default) or minV, minV, maxV)

                -- Row: label left, percentage right
                local row = make("Frame", {
                    Parent = ctrls, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 18),
                })
                reg(row)
                local nameLbl = lbl(row, opts.Text or opts.Name or identifier,
                    12, T.Text, T.FontMedium, 18)
                nameLbl.Size = UDim2.new(1, -54, 1, 0)

                local pctLbl = lbl(row, "", 11, T.SubText, T.Font, 18)
                pctLbl.AnchorPoint = Vector2.new(1, 0)
                pctLbl.Position    = UDim2.new(1, 0, 0, 0)
                pctLbl.Size        = UDim2.fromOffset(54, 18)
                pctLbl.TextXAlignment = Enum.TextXAlignment.Right

                local trackH = mobile and 10 or 8
                local track = make("TextButton", {
                    Parent = ctrls, BackgroundColor3 = T.Element,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, trackH),
                    Text = "", AutoButtonColor = false, ClipsDescendants = true,
                })
                corner(track, trackH // 2)
                stroke(track, T.Outline, 1, 0.4)
                reg(track)

                local fill = make("Frame", {
                    Parent = track, BackgroundColor3 = T.Accent,
                    BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0),
                    ClipsDescendants = true,
                })
                corner(fill, trackH // 2)
                -- Accent gradient on fill
                make("UIGradient", {
                    Parent = fill, Rotation = 0,
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, T.AccentLight),
                        ColorSequenceKeypoint.new(1, T.AccentDark),
                    }),
                })

                local knobSz = mobile and 16 or 13
                local knob = make("Frame", {
                    Parent = fill, BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(knobSz, knobSz),
                })
                corner(knob, knobSz // 2)
                stroke(knob, T.AccentDark, 2, 0)

                local obj = signal(value, opts.Callback, identifier, false)
                obj.Instance = track

                local function fmt(v)
                    if rnd <= 0 then return tostring(math.floor(v + 0.5)) .. "%" end
                    return string.format("%." .. math.clamp(rnd, 0, 4) .. "f", v) .. "%"
                end
                local function upd(nv, fire)
                    nv = math.clamp(tonumber(nv) or minV, minV, maxV)
                    local m = 10 ^ math.clamp(rnd, 0, 4)
                    value = math.floor(nv * m + 0.5) / m
                    local a = (maxV == minV) and 0 or (value - minV) / (maxV - minV)
                    fill.Size     = UDim2.new(a, 0, 1, 0)
                    pctLbl.Text   = fmt(value)
                    obj.Value     = value
                    if identifier then Library.Flags[identifier] = value end
                    if fire then safeCall(opts.Callback, value); obj.Changed:Fire(value) end
                end

                local sliding = false
                local function fromX(x)
                    local a = math.clamp((x - track.AbsolutePosition.X)
                        / math.max(track.AbsoluteSize.X, 1), 0, 1)
                    upd(minV + (maxV - minV) * a, true)
                end

                track.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1
                        or inp.UserInputType == Enum.UserInputType.Touch then
                        sliding = true; fromX(inp.Position.X)
                    end
                end)
                local eC = UserInputService.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1
                        or inp.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end)
                local mC = UserInputService.InputChanged:Connect(function(inp)
                    if sliding and (inp.UserInputType == Enum.UserInputType.MouseMovement
                        or inp.UserInputType == Enum.UserInputType.Touch) then
                        fromX(inp.Position.X)
                    end
                end)

                function obj:SetValue(v, silent) upd(v, not silent) end
                function obj:OnChanged(fn)
                    if type(fn) == "function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy()
                    eC:Disconnect(); mC:Disconnect()
                    row:Destroy(); track:Destroy(); obj.Changed:Destroy()
                end
                upd(value, false)
                bindFlag(obj, identifier, value, false)
                return obj
            end

            -- ── AddDropdown ────────────────────────────────────────────────────
            function group:AddDropdown(identifier, opts)
                opts = opts or {}
                local values    = opts.Values or opts.Options or {}
                local allowNull = opts.AllowNull == true
                local selected  = type(opts.Default) == "table" and opts.Default[1] or opts.Default
                if selected == nil and not allowNull then selected = values[1] end

                local l = lbl(ctrls, opts.Text or opts.Name or identifier,
                    12, T.Text, T.FontMedium, 18)
                reg(l)

                local db = btn(ctrls, "DD", tostring(selected or "Select..."), T.RowH)
                db.TextXAlignment = Enum.TextXAlignment.Left
                make("UIPadding", {Parent = db, PaddingLeft = UDim.new(0, 10)})
                reg(db)

                -- Arrow
                local arrow = make("TextLabel", {
                    Parent = db, BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -8, 0.5, 0),
                    Size = UDim2.fromOffset(16, 16),
                    Font = T.Font, Text = "▾",
                    TextColor3 = T.Accent, TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Center,
                })

                local menuOpen = false
                local menu = make("Frame", {
                    Parent = ctrls, BackgroundColor3 = T.Main,
                    BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
                    Visible = false, ClipsDescendants = true,
                })
                corner(menu, T.CornerSmall)
                stroke(menu, T.OutlineFocus, 1, 0.5)
                local ml = make("UIListLayout", {
                    Parent = menu, SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 2),
                })
                reg(menu)

                local obj = signal(selected, opts.Callback, identifier, false)
                obj.Instance = db

                local function closeMenu()
                    menuOpen = false; menu.Visible = false
                    menu.Size = UDim2.new(1, 0, 0, 0); arrow.Text = "▾"
                end
                local function setSel(v, fire)
                    selected = v; obj.Value = v
                    db.Text = tostring(v or "Select...")
                    if identifier then Library.Flags[identifier] = v end
                    closeMenu()
                    if fire then safeCall(opts.Callback, v); obj.Changed:Fire(v) end
                end
                local function rebuild()
                    for _, c in ipairs(menu:GetChildren()) do
                        if c:IsA("TextButton") then c:Destroy() end
                    end
                    for i, val in ipairs(values) do
                        local ob = btn(menu, "O"..i, tostring(val), mobile and 30 or 24)
                        ob.LayoutOrder = i
                        ob.Activated:Connect(function() haptic(); setSel(val, true) end)
                    end
                end
                rebuild()

                db.Activated:Connect(function()
                    menuOpen = not menuOpen
                    menu.Visible = menuOpen
                    arrow.Text = menuOpen and "▴" or "▾"
                    if menuOpen then
                        menu.Size = UDim2.new(1, 0, 0, math.min(ml.AbsoluteContentSize.Y + 4, 144))
                    else closeMenu() end
                    haptic()
                end)

                function obj:SetValue(v, silent) setSel(v, not silent) end
                function obj:SetValues(nv) values = nv or {}; rebuild() end
                function obj:OnChanged(fn)
                    if type(fn) == "function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy()
                    l:Destroy(); db:Destroy(); menu:Destroy(); obj.Changed:Destroy()
                end
                bindFlag(obj, identifier, selected, false)
                return obj
            end

            -- ── AddInput ───────────────────────────────────────────────────────
            function group:AddInput(identifier, opts)
                opts = opts or {}
                local l = lbl(ctrls, opts.Text or opts.Name or identifier,
                    12, T.Text, T.FontMedium, 18)
                reg(l)
                local inp = make("TextBox", {
                    Parent = ctrls, BackgroundColor3 = T.Element,
                    BorderSizePixel = 0, ClearTextOnFocus = false,
                    Size = UDim2.new(1, 0, 0, T.RowH),
                    Font = T.Font,
                    PlaceholderText = opts.Placeholder or "Enter text...",
                    PlaceholderColor3 = T.Disabled,
                    Text = tostring(opts.Default or ""),
                    TextColor3 = T.Text, TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
                corner(inp, T.CornerSmall)
                stroke(inp, T.Outline, 1, 0.25)
                make("UIPadding", {Parent = inp, PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8)})
                reg(inp)

                inp.Focused:Connect(function() tw(inp, 0.1, {BackgroundColor3 = T.ElementHover}) end)
                inp.FocusLost:Connect(function() tw(inp, 0.1, {BackgroundColor3 = T.Element}) end)

                local obj = signal(inp.Text, opts.Callback, identifier, false)
                obj.Instance = inp
                inp.FocusLost:Connect(function(enter)
                    obj:SetValue(inp.Text)
                    if opts.FireOnEnterOnly and not enter then return end
                    safeCall(opts.Callback, inp.Text, enter)
                end)
                function obj:SetValue(v, silent)
                    inp.Text = tostring(v or ""); obj.Value = inp.Text
                    if identifier then Library.Flags[identifier] = obj.Value end
                    if not silent then obj.Changed:Fire(obj.Value); safeCall(opts.Callback, obj.Value) end
                end
                function obj:OnChanged(fn)
                    if type(fn) == "function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy() l:Destroy(); inp:Destroy(); obj.Changed:Destroy() end
                bindFlag(obj, identifier, inp.Text, false)
                return obj
            end

            -- ── AddKeyPicker ───────────────────────────────────────────────────
            function group:AddKeyPicker(identifier, opts)
                opts = opts or {}
                local labelText = tostring(opts.Text or opts.Name or identifier or "Keybind")
                local rowH = T.RowH

                local row = make("Frame", {
                    Parent = ctrls, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, rowH),
                })
                reg(row)
                local nl = lbl(row, labelText, 12, T.Text, T.Font, rowH)
                nl.Size = UDim2.new(1, -104, 1, 0)

                local kb = btn(row, "KB", tostring(opts.Default or "None"), rowH - 4)
                kb.AnchorPoint = Vector2.new(1, 0.5)
                kb.Position    = UDim2.new(1, 0, 0.5, 0)
                kb.Size        = UDim2.fromOffset(96, rowH - 4)
                kb.TextSize    = 11

                local curKey = opts.Default
                local listening = false
                local obj = signal(curKey, opts.Callback, identifier, false)
                obj.Instance = kb

                kb.Activated:Connect(function()
                    listening = true; kb.Text = "Press key..."
                    tw(kb, 0.1, {TextColor3 = T.Warning}); haptic()
                end)
                local conn = UserInputService.InputBegan:Connect(function(inp, proc)
                    if proc then return end
                    if listening and inp.UserInputType == Enum.UserInputType.Keyboard then
                        listening = false
                        curKey    = inp.KeyCode
                        kb.Text   = curKey.Name
                        tw(kb, 0.1, {TextColor3 = T.Text})
                        obj:SetValue(curKey)
                    elseif curKey and inp.KeyCode == curKey then
                        safeCall(opts.Callback, curKey)
                    end
                end)

                function obj:SetValue(v, silent)
                    curKey = v
                    kb.Text = typeof(v) == "EnumItem" and v.Name or tostring(v or "None")
                    obj.Value = v
                    if identifier then Library.Flags[identifier] = v end
                    if not silent then safeCall(opts.Callback, v); obj.Changed:Fire(v) end
                end
                function obj:OnChanged(fn)
                    if type(fn) == "function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy() conn:Disconnect(); row:Destroy(); obj.Changed:Destroy() end
                bindFlag(obj, identifier, curKey, false)
                return obj
            end

            -- ── AddColorPicker ─────────────────────────────────────────────────
            function group:AddColorPicker(identifier, opts)
                opts = opts or {}
                local current = opts.Default or T.Accent
                local rowH    = T.RowH

                local row = make("Frame", {
                    Parent = ctrls, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, rowH),
                })
                reg(row)
                local nl = lbl(row, opts.Text or opts.Name or identifier, 12, T.Text, T.Font, rowH)
                nl.Size = UDim2.new(1, -54, 1, 0)

                local sw = make("TextButton", {
                    Parent = row, AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(44, rowH - 6),
                    BackgroundColor3 = current,
                    BorderSizePixel = 0, Text = "", AutoButtonColor = false,
                })
                corner(sw, T.CornerSmall)
                stroke(sw, T.Outline, 1, 0.15)

                local obj = signal(current, opts.Callback, identifier, false)
                obj.Instance = sw
                sw.Activated:Connect(function()
                    haptic()
                    local h, s, v = current:ToHSV()
                    current = Color3.fromHSV((h + 0.08) % 1, s, v)
                    sw.BackgroundColor3 = current
                    obj:SetValue(current)
                end)
                function obj:SetValue(v, silent)
                    if typeof(v) ~= "Color3" then return end
                    current = v; sw.BackgroundColor3 = current; obj.Value = current
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
        end -- makeGroup

        function tab:AddLeftGroupbox(name)  return makeGroup(name, "Left")  end
        function tab:AddRightGroupbox(name) return makeGroup(name, "Right") end
        function tab:AddGroupbox(name)      return makeGroup(name, "Left")  end

        -- Compat shims
        function tab:CreateButton(opts, cb)
            return makeGroup("Controls","Left"):AddButton(opts, cb)
        end
        function tab:CreateToggle(opts)
            return makeGroup("Controls","Left"):AddToggle(opts.Flag or opts.Name, opts)
        end
        function tab:CreateSlider(opts)
            return makeGroup("Controls","Left"):AddSlider(opts.Flag or opts.Name, opts)
        end

        -- Auto-select first tab
        if #window.Tabs == 0 then
            page.Visible      = true
            window.ActiveTab  = tab
        end

        table.insert(window.Tabs, tab)
        return tab
    end -- CreateTab

    window.AddTab = function(self, name)
        return self:CreateTab(type(name) == "table" and name or {Name = name})
    end
    window.Holder = content

    if settings.AutoShow then gui.Enabled = true end
    table.insert(Library.Windows, window)
    return window
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Unload
-- ─────────────────────────────────────────────────────────────────────────────
function Library:Unload()
    self.Unloaded = true
    for _, w in ipairs(self.Windows) do pcall(function() w:Destroy() end) end
    self.Windows = {}; self.Registry = {}; self.RegistryMap = {}
    self.HudRegistry = {}; self.Flags = {}; self.Options = {}
    self.Toggles = {}; self.ScreenGui = nil
end

return Library
