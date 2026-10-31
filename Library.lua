--[[
    AstatineLib v4.1 — Pixel-accurate LoveUp layout
    ──────────────────────────────────────────────────────────────────────────
    Top bar:   [⊡ LOVEUP logo] [Search box] [Username / Avatar chip]
    Left nav:  Icon + label rows, ~200px, active row = subtle bg highlight
    Content:   Two scrollable panels side by side, each with section headers
               (icon + label) and controls (toggle, slider, dropdown, etc.)
    Toggles:   Exact LoveUp pill — gray track / purple track, white knob
    Sliders:   Label left · "50%" value · dark track · purple fill · square knob
    Dropdowns: Full-width, chevron right, dark element bg
    ──────────────────────────────────────────────────────────────────────────
    Linoria-compatible API preserved.
]]

local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local ok_h, HapticService = pcall(function() return game:GetService("HapticService") end)
if not ok_h then HapticService = nil end

local LocalPlayer = Players.LocalPlayer
local IS_MOBILE   = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local function haptic()
    if IS_MOBILE and HapticService then
        pcall(function()
            HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.15)
            task.delay(0.05, function()
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
    Version     = "4.1.0",
    Flags       = {},
    Options     = {},
    Toggles     = {},
    Registry    = {},
    RegistryMap = {},
    HudRegistry = {},
    ScreenGui   = nil,
    Windows     = {},
    Unloaded    = false,
    ThemeManager = {},
    SaveManager  = {},

    Theme = {
        -- Exact colors from LoveUp screenshots
        Accent       = Color3.fromRGB(109, 76, 224),   -- purple, toggles/sliders/active
        AccentLight  = Color3.fromRGB(139, 109, 255),
        AccentDark   = Color3.fromRGB(82, 54, 180),

        -- Backgrounds
        BgDeep       = Color3.fromRGB(18, 18, 24),     -- outermost window bg
        BgNav        = Color3.fromRGB(22, 22, 30),     -- left nav panel
        BgPanel      = Color3.fromRGB(26, 26, 35),     -- content panel bg
        BgElement    = Color3.fromRGB(32, 32, 44),     -- input/toggle track bg
        BgElementHov = Color3.fromRGB(40, 40, 55),
        BgActive     = Color3.fromRGB(38, 32, 60),     -- active nav row bg (subtle purple)
        BgTopBar     = Color3.fromRGB(20, 20, 28),     -- top bar

        -- Borders
        Border       = Color3.fromRGB(44, 44, 62),
        BorderFocus  = Color3.fromRGB(109, 76, 224),
        BorderPanel  = Color3.fromRGB(38, 38, 52),

        -- Text
        TextPrimary  = Color3.fromRGB(232, 232, 245),
        TextSub      = Color3.fromRGB(140, 140, 168),
        TextMuted    = Color3.fromRGB(90, 90, 115),
        TextNav      = Color3.fromRGB(155, 155, 180),
        TextNavActive= Color3.fromRGB(232, 232, 245),
        TextDanger   = Color3.fromRGB(220, 64, 64),

        -- Fonts
        Font         = Enum.Font.Gotham,
        FontBold     = Enum.Font.GothamBold,
        FontMedium   = Enum.Font.GothamMedium,
        FontSemi     = Enum.Font.GothamSemibold,

        -- Sizing (LoveUp nav is ~200px wide)
        NavW         = IS_MOBILE and 52 or 200,
        TopH         = 54,
        RowH         = IS_MOBILE and 36 or 32,
        CornerWin    = 12,
        CornerPanel  = 8,
        CornerElem   = 6,
        CornerSmall  = 4,
    },
}

local T = Library.Theme

-- ─────────────────────────────────────────────────────────────────────────────
-- Micro-helpers
-- ─────────────────────────────────────────────────────────────────────────────
local function make(cls, props)
    local o = Instance.new(cls)
    if props then for k,v in pairs(props) do o[k] = v end end
    return o
end

local function corner(p, r)
    return make("UICorner", {Parent=p, CornerRadius=UDim.new(0, r or T.CornerElem)})
end

local function stroke(p, col, thick, trans)
    return make("UIStroke", {
        Parent=p, Color=col or T.Border, Thickness=thick or 1,
        Transparency=trans or 0, ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
    })
end

local function tw(obj, dur, props)
    local t = TweenService:Create(obj, TweenInfo.new(dur or 0.13, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    t:Play(); return t
end

local function lbl(parent, text, size, color, font, h)
    return make("TextLabel", {
        Parent=parent, BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,h or 18),
        Font=font or T.Font, Text=tostring(text or ""),
        TextColor3=color or T.TextPrimary, TextSize=size or 12,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,
        TextTruncate=Enum.TextTruncate.AtEnd,
    })
end

local function safeCall(fn, ...)
    if type(fn)~="function" then return end
    local ok,e = pcall(fn,...); if not ok then warn("[AstatineLib] "..tostring(e)) end
end

-- Signal / flag binding
local function signal(init, cb, id, isToggle)
    local o = {Value=init, Callback=cb, Changed=Instance.new("BindableEvent")}
    function o:SetValue(v, silent)
        self.Value=v
        if id then Library.Flags[id]=v end
        if not silent then safeCall(self.Callback,v); self.Changed:Fire(v) end
    end
    function o:OnChanged(fn)
        if type(fn)=="function" then self.Changed.Event:Connect(fn) end; return self
    end
    function o:Destroy() self.Changed:Destroy() end
    if id then
        Library.Flags[id]=init
        if isToggle then Library.Toggles[id]=o else Library.Options[id]=o end
    end
    return o
end

-- Hover effect on any frame/button
local function hoverEffect(b, colN, colH)
    b.MouseEnter:Connect(function() tw(b,0.1,{BackgroundColor3=colH or T.BgElementHov}) end)
    b.MouseLeave:Connect(function() tw(b,0.1,{BackgroundColor3=colN or T.BgElement}) end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Notification
-- ─────────────────────────────────────────────────────────────────────────────
function Library:Notify(msg, dur)
    local gui = self.ScreenGui
    if not gui or not gui.Parent then warn("[AstatineLib] "..tostring(msg)); return end
    local holder = gui:FindFirstChild("_notifs") or (function()
        local h = make("Frame",{Name="_notifs",Parent=gui,BackgroundTransparency=1,
            AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-12,1,-12),
            Size=UDim2.fromOffset(300,280)})
        make("UIListLayout",{Parent=h,SortOrder=Enum.SortOrder.LayoutOrder,
            VerticalAlignment=Enum.VerticalAlignment.Bottom,Padding=UDim.new(0,6)})
        return h
    end)()
    local item = make("Frame",{Parent=holder,BackgroundColor3=T.BgPanel,
        BorderSizePixel=0,Size=UDim2.new(1,0,0,52),BackgroundTransparency=1})
    corner(item,T.CornerElem); stroke(item,T.BorderFocus,1,0.5)
    make("Frame",{Parent=item,BackgroundColor3=T.Accent,BorderSizePixel=0,
        Size=UDim2.fromOffset(3,52)})
    local l=lbl(item,msg,12,T.TextPrimary,T.Font,52)
    l.Position=UDim2.fromOffset(10,0); l.Size=UDim2.new(1,-18,1,0); l.TextWrapped=true
    tw(item,0.18,{BackgroundTransparency=0})
    task.delay(dur or 3.5,function()
        if item.Parent then tw(item,0.15,{BackgroundTransparency=1})
            task.wait(0.18); if item.Parent then item:Destroy() end end
    end)
end
Library.CreateNotification = Library.Notify

-- ─────────────────────────────────────────────────────────────────────────────
-- CreateWindow — LoveUp shell
-- ─────────────────────────────────────────────────────────────────────────────
function Library:CreateWindow(settings)
    settings = settings or {}
    local existing = CoreGui:FindFirstChild("AstatineLib_v4")
    if existing then existing:Destroy() end

    local gui = make("ScreenGui",{Name="AstatineLib_v4",Parent=CoreGui,
        ResetOnSpawn=false,IgnoreGuiInset=true,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=65})
    self.ScreenGui = gui; self.Unloaded = false

    local vp     = workspace.CurrentCamera.ViewportSize
    local mobile = IS_MOBILE or vp.X < 680
    local winW   = mobile and math.min(vp.X-8,490) or (tonumber(settings.Width) or 860)
    local winH   = mobile and math.min(vp.Y-46,680) or (tonumber(settings.Height) or 560)
    local navW   = mobile and 52 or 200
    local topH   = T.TopH

    local initX  = settings.Center~=false and (vp.X-winW)/2 or 60
    local initY  = settings.Center~=false and (vp.Y-winH)/2 or 50

    -- Shadow
    local shadow = make("Frame",{Name="Shadow",Parent=gui,
        BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.55,BorderSizePixel=0,
        Position=UDim2.fromOffset(initX+6,initY+8),Size=UDim2.fromOffset(winW,winH),ZIndex=1})
    corner(shadow,T.CornerWin)

    -- Main window
    local main = make("Frame",{Name="Main",Parent=gui,BackgroundColor3=T.BgDeep,
        BorderSizePixel=0,Position=UDim2.fromOffset(initX,initY),
        Size=UDim2.fromOffset(winW,winH),ClipsDescendants=true,ZIndex=2})
    corner(main,T.CornerWin); stroke(main,T.Border,1,0)

    -- ── TOP BAR ──────────────────────────────────────────────────────────────
    local topBar = make("Frame",{Name="TopBar",Parent=main,
        BackgroundColor3=T.BgTopBar,BorderSizePixel=0,
        Size=UDim2.new(1,0,0,topH)})
    -- Extend corners only top
    make("Frame",{Parent=topBar,BackgroundColor3=T.BgTopBar,BorderSizePixel=0,
        Position=UDim2.new(0,0,1,-T.CornerWin),Size=UDim2.new(1,0,0,T.CornerWin)})
    corner(topBar,T.CornerWin)
    -- Bottom separator
    make("Frame",{Parent=topBar,BackgroundColor3=T.Border,BorderSizePixel=0,
        Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1)})

    -- Logo (left, width of nav)
    local logoArea = make("Frame",{Parent=topBar,BackgroundTransparency=1,
        Size=UDim2.fromOffset(navW,topH)})
    -- Square bracket icon — ⊡ style
    local iconFrame = make("Frame",{Parent=logoArea,BackgroundColor3=T.Accent,
        BorderSizePixel=0,AnchorPoint=Vector2.new(0,0.5),
        Position=UDim2.fromOffset(16,0),Size=UDim2.fromOffset(26,26)})
    corner(iconFrame,5)
    make("TextLabel",{Parent=iconFrame,BackgroundTransparency=1,
        Size=UDim2.new(1,0,1,0),Font=T.FontBold,Text="⊡",
        TextColor3=Color3.new(1,1,1),TextSize=14,
        TextXAlignment=Enum.TextXAlignment.Center})

    if not mobile then
        make("TextLabel",{Parent=logoArea,BackgroundTransparency=1,
            Position=UDim2.fromOffset(50,0),Size=UDim2.new(1,-58,1,0),
            Font=T.FontBold,Text=tostring(settings.Title or "LOVEUP"),
            TextColor3=T.TextPrimary,TextSize=16,
            TextXAlignment=Enum.TextXAlignment.Left})
    end

    -- Search bar (center)
    local searchW = mobile and winW-navW-120 or winW-navW-260
    local searchBox = make("Frame",{Parent=topBar,BackgroundColor3=T.BgElement,
        BorderSizePixel=0,AnchorPoint=Vector2.new(0,0.5),
        Position=UDim2.fromOffset(navW+8,0),Size=UDim2.fromOffset(searchW,32)})
    corner(searchBox,T.CornerElem); stroke(searchBox,T.Border,1,0.5)

    make("TextLabel",{Parent=searchBox,BackgroundTransparency=1,
        Position=UDim2.fromOffset(10,0),Size=UDim2.fromOffset(18,32),
        Font=T.Font,Text="🔍",TextColor3=T.TextMuted,TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Center})

    local searchInput = make("TextBox",{Parent=searchBox,BackgroundTransparency=1,
        Position=UDim2.fromOffset(30,0),Size=UDim2.new(1,-38,1,0),
        Font=T.Font,PlaceholderText="Search...",PlaceholderColor3=T.TextMuted,
        Text="",TextColor3=T.TextPrimary,TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false})

    -- Avatar chip (right side)
    local chipW = mobile and 42 or 190
    local avatarChip = make("Frame",{Parent=topBar,BackgroundTransparency=1,
        AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-10,0.5,0),
        Size=UDim2.fromOffset(chipW,topH)})

    -- Username + subtitle (desktop only)
    if not mobile then
        local userLbl = make("TextLabel",{Parent=avatarChip,BackgroundTransparency=1,
            AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-42,0.5,-7),
            Size=UDim2.fromOffset(140,18),Font=T.FontSemi,
            Text=LocalPlayer.DisplayName,
            TextColor3=T.TextPrimary,TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Right})
        make("TextLabel",{Parent=avatarChip,BackgroundTransparency=1,
            AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-42,0.5,8),
            Size=UDim2.fromOffset(140,14),Font=T.Font,
            Text="v" .. Library.Version,
            TextColor3=T.TextMuted,TextSize=10,
            TextXAlignment=Enum.TextXAlignment.Right})
        LocalPlayer:GetPropertyChangedSignal("DisplayName"):Connect(function()
            if userLbl and userLbl.Parent then userLbl.Text=LocalPlayer.DisplayName end
        end)
    end

    -- Circular avatar button
    local avatarBtn = make("ImageButton",{Parent=avatarChip,
        BackgroundColor3=T.BgElement,BorderSizePixel=0,
        AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),
        Size=UDim2.fromOffset(36,36),AutoButtonColor=false,
        Image="rbxthumb://type=AvatarHeadShot&id="..tostring(LocalPlayer.UserId).."&w=48&h=48"})
    corner(avatarBtn,18); stroke(avatarBtn,T.Border,1,0.2)

    -- Version tag bottom-right of window
    local verLbl = make("TextLabel",{Parent=main,BackgroundTransparency=1,
        AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,topH-18),
        Size=UDim2.fromOffset(80,14),Font=T.Font,
        Text="v"..Library.Version,TextColor3=T.TextMuted,TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Right})

    -- Close (×)
    local closeBtn = make("TextButton",{Parent=topBar,BackgroundTransparency=1,
        AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-8,0.5,0),
        Size=UDim2.fromOffset(28,28),AutoButtonColor=false,
        Font=T.FontBold,Text="×",TextColor3=T.TextSub,TextSize=20,
        BorderSizePixel=0})
    closeBtn.MouseEnter:Connect(function() tw(closeBtn,0.1,{TextColor3=T.TextPrimary}) end)
    closeBtn.MouseLeave:Connect(function() tw(closeBtn,0.1,{TextColor3=T.TextSub}) end)
    closeBtn.MouseButton1Click:Connect(function() gui.Enabled=false end)

    -- ── NAV RAIL (left) ───────────────────────────────────────────────────────
    local navRail = make("Frame",{Name="NavRail",Parent=main,
        BackgroundColor3=T.BgNav,BorderSizePixel=0,
        Position=UDim2.fromOffset(0,topH),
        Size=UDim2.new(0,navW,1,-topH),ClipsDescendants=true})
    -- Right border line
    make("Frame",{Parent=navRail,BackgroundColor3=T.Border,BorderSizePixel=0,
        Position=UDim2.new(1,-1,0,0),Size=UDim2.new(0,1,1,0)})

    local navScroll = make("ScrollingFrame",{Parent=navRail,
        BackgroundTransparency=1,BorderSizePixel=0,
        Position=UDim2.fromOffset(0,8),Size=UDim2.new(1,0,1,-8),
        CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollBarThickness=0,ScrollingEnabled=true})
    local navList = make("Frame",{Parent=navScroll,BackgroundTransparency=1,
        Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
    make("UIListLayout",{Parent=navList,SortOrder=Enum.SortOrder.LayoutOrder,
        Padding=UDim.new(0,2)})
    make("UIPadding",{Parent=navList,PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)})

    -- ── CONTENT (right of nav) ────────────────────────────────────────────────
    local content = make("Frame",{Name="Content",Parent=main,
        BackgroundColor3=T.BgDeep,BorderSizePixel=0,
        Position=UDim2.fromOffset(navW,topH),
        Size=UDim2.new(1,-navW,1,-topH),ClipsDescendants=true})

    -- ── DRAG ──────────────────────────────────────────────────────────────────
    local dragging,dragStart,startPos,dragInp = false,nil,nil,nil
    topBar.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=inp.Position; startPos=main.Position
            inp.Changed:Connect(function()
                if inp.UserInputState==Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    topBar.InputChanged:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch then dragInp=inp end
    end)
    local dragConn = UserInputService.InputChanged:Connect(function(inp)
        if not gui.Parent then return end
        if dragging and inp==dragInp then
            local d=inp.Position-dragStart
            local nx=math.clamp(startPos.X.Offset+d.X, 0, vp.X-winW)
            local ny=math.clamp(startPos.Y.Offset+d.Y, 0, vp.Y-winH)
            main.Position=UDim2.fromOffset(nx,ny)
            shadow.Position=UDim2.fromOffset(nx+6,ny+8)
        end
    end)

    -- ── WINDOW OBJECT ─────────────────────────────────────────────────────────
    local window = {WindowFrame=main,ScreenGui=gui,Tabs={},ActiveTab=nil,
        _conns={dragConn}}

    function window:SetTitle(v)
        local tl = logoArea:FindFirstChildWhichIsA("TextLabel")
        if tl then tl.Text=tostring(v) end
    end
    function window:SetVisible(v) gui.Enabled=v==true end
    function window:Toggle() gui.Enabled=not gui.Enabled end
    function window:Destroy()
        if gui and gui.Parent then gui:Destroy() end
        for _,c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    end

    -- ── CreateTab ─────────────────────────────────────────────────────────────
    function window:CreateTab(tabSettings)
        if type(tabSettings)=="string" then tabSettings={Name=tabSettings} end
        tabSettings = tabSettings or {}
        local tabName = tostring(tabSettings.Name or tabSettings.Title or "Tab")
        local tabIcon = tostring(tabSettings.Icon or "◈")
        local isFirst = #self.Tabs==0
        local navH    = mobile and 38 or 40

        -- Nav button row
        local navBtn = make("TextButton",{
            Name=tabName.."_nav",Parent=navList,
            BackgroundColor3=isFirst and T.BgActive or Color3.new(0,0,0),
            BackgroundTransparency=isFirst and 0 or 1,
            BorderSizePixel=0,AutoButtonColor=false,
            Size=UDim2.new(1,0,0,navH),Text="",
            LayoutOrder=#self.Tabs+1})
        corner(navBtn,T.CornerElem)

        -- Active left accent bar (3px, LoveUp doesn't use one — it uses full row bg)
        -- LoveUp uses a slightly purple-tinted bg for active row, no left bar
        -- Icon
        local iconLbl = make("TextLabel",{Parent=navBtn,BackgroundTransparency=1,
            Position=UDim2.fromOffset(mobile and 12 or 14,0),
            Size=UDim2.fromOffset(22,navH),
            Font=T.Font,Text=tabIcon,
            TextColor3=isFirst and T.TextPrimary or T.TextNav,
            TextSize=14,TextXAlignment=Enum.TextXAlignment.Center})

        local nameLbl
        if not mobile then
            nameLbl = make("TextLabel",{Parent=navBtn,BackgroundTransparency=1,
                Position=UDim2.fromOffset(40,0),Size=UDim2.new(1,-48,1,0),
                Font=T.FontMedium,Text=tabName,
                TextColor3=isFirst and T.TextNavActive or T.TextNav,
                TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,
                TextTruncate=Enum.TextTruncate.AtEnd})
        end

        -- Content page (full area, scrollable)
        local page = make("ScrollingFrame",{Name=tabName.."_page",Parent=content,
            BackgroundTransparency=1,BorderSizePixel=0,
            Position=UDim2.new(0,0,0,0),Size=UDim2.new(1,0,1,0),
            CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
            ScrollBarThickness=mobile and 5 or 4,
            ScrollBarImageColor3=T.Accent,ScrollBarImageTransparency=0.3,
            Visible=isFirst})
        make("UIPadding",{Parent=page,
            PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),
            PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12)})

        -- Two-column layout inside page
        -- LoveUp: left panel | right panel, each equal width, gap between
        local cols = make("Frame",{Parent=page,BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})

        local leftCol = make("Frame",{Name="Left",Parent=cols,BackgroundTransparency=1,
            Position=UDim2.new(0,0,0,0),
            Size=UDim2.new(mobile and 1 or 0.5, mobile and 0 or -6,0,0),
            AutomaticSize=Enum.AutomaticSize.Y})
        make("UIListLayout",{Parent=leftCol,SortOrder=Enum.SortOrder.LayoutOrder,
            Padding=UDim.new(0,8)})

        local rightCol = make("Frame",{Name="Right",Parent=cols,BackgroundTransparency=1,
            Position=UDim2.new(mobile and 0 or 0.5, mobile and 0 or 6,0,0),
            Size=UDim2.new(mobile and 0 or 0.5, mobile and 0 or -6,0,0),
            AutomaticSize=Enum.AutomaticSize.Y,Visible=not mobile})
        make("UIListLayout",{Parent=rightCol,SortOrder=Enum.SortOrder.LayoutOrder,
            Padding=UDim.new(0,8)})

        local tab = {Name=tabName,NavBtn=navBtn,Page=page,
            Left=leftCol,Right=rightCol,_gc={Left=0,Right=0}}

        local function selectTab()
            for _,other in ipairs(window.Tabs) do
                other.Page.Visible=false
                tw(other.NavBtn,0.12,{BackgroundTransparency=1})
                for _,ch in ipairs(other.NavBtn:GetChildren()) do
                    if ch:IsA("TextLabel") then tw(ch,0.12,{TextColor3=T.TextNav}) end
                end
            end
            page.Visible=true
            tw(navBtn,0.12,{BackgroundTransparency=0,BackgroundColor3=T.BgActive})
            tw(iconLbl,0.12,{TextColor3=T.TextPrimary})
            if nameLbl then tw(nameLbl,0.12,{TextColor3=T.TextNavActive}) end
            window.ActiveTab=tab; haptic()
        end
        navBtn.Activated:Connect(selectTab)

        if isFirst then window.ActiveTab=tab end
        table.insert(window.Tabs,tab)

        -- ── Groupbox factory ──────────────────────────────────────────────────
        local function makeGroup(groupName, side)
            side = side or "Left"
            local col = (side=="Right" and not mobile) and rightCol or leftCol
            tab._gc[side] = (tab._gc[side] or 0)+1

            -- LoveUp groupbox: dark bg panel, subtle border, section header row
            local gf = make("Frame",{Name=tostring(groupName or "Group"),Parent=col,
                BackgroundColor3=T.BgPanel,BorderSizePixel=0,
                Size=UDim2.new(1,0,0,40),AutomaticSize=Enum.AutomaticSize.Y,
                LayoutOrder=tab._gc[side],ClipsDescendants=false})
            corner(gf,T.CornerPanel); stroke(gf,T.BorderPanel,1,0)

            -- Section header (icon circle + label — LoveUp style)
            local hdr = make("Frame",{Name="Header",Parent=gf,
                BackgroundColor3=T.BgPanel,BorderSizePixel=0,
                Size=UDim2.new(1,0,0,38)})
            -- Square bracket icon
            local hdrIcon = make("TextLabel",{Parent=hdr,BackgroundTransparency=1,
                AnchorPoint=Vector2.new(0,0.5),Position=UDim2.fromOffset(12,0),
                Size=UDim2.fromOffset(18,18),
                Font=T.Font,Text="◈",TextColor3=T.Accent,TextSize=12,
                TextXAlignment=Enum.TextXAlignment.Center})
            local hdrLbl = lbl(hdr,groupName or "Group",12,T.TextSub,T.FontMedium,38)
            hdrLbl.Position=UDim2.fromOffset(32,0)
            hdrLbl.Size=UDim2.new(1,-40,1,0)

            -- Divider under header
            make("Frame",{Parent=gf,BackgroundColor3=T.Border,BorderSizePixel=0,
                Position=UDim2.fromOffset(0,38),Size=UDim2.new(1,0,0,1)})

            -- Controls container
            local ctrls = make("Frame",{Name="Ctrls",Parent=gf,
                BackgroundTransparency=1,
                Position=UDim2.fromOffset(0,40),
                Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
            make("UIListLayout",{Parent=ctrls,SortOrder=Enum.SortOrder.LayoutOrder,
                Padding=UDim.new(0,0)})   -- no gap — LoveUp rows are flush
            make("UIPadding",{Parent=ctrls,
                PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14),
                PaddingBottom=UDim.new(0,10)})

            local group={Container=gf,Controls=ctrls,Name=groupName}
            local ord=0
            local function reg(i) ord=ord+1; i.LayoutOrder=ord; return i end

            -- Shared: a subtle separator between rows (like LoveUp)
            local function rowSep()
                local s=make("Frame",{Parent=ctrls,BackgroundColor3=T.Border,
                    BackgroundTransparency=0.65,BorderSizePixel=0,
                    Size=UDim2.new(1,0,0,1)})
                reg(s); return s
            end

            -- ── AddLabel ───────────────────────────────────────────────────────
            function group:AddLabel(t)
                local l=lbl(ctrls,t,12,T.TextSub,T.Font,22)
                l.Position=UDim2.fromOffset(0,2); reg(l)
                local o={Instance=l}
                function o:SetText(v) l.Text=tostring(v) end
                function o:Destroy() l:Destroy() end
                return o
            end

            -- ── AddDivider ─────────────────────────────────────────────────────
            function group:AddDivider()
                local f=make("Frame",{Parent=ctrls,BackgroundColor3=T.Border,
                    BorderSizePixel=0,Size=UDim2.new(1,0,0,1)})
                reg(f); return f
            end

            -- ── AddParagraph ───────────────────────────────────────────────────
            function group:AddParagraph(title,body)
                local w=make("Frame",{Parent=ctrls,BackgroundColor3=T.BgElement,
                    BorderSizePixel=0,Size=UDim2.new(1,0,0,50),
                    AutomaticSize=Enum.AutomaticSize.Y})
                corner(w,T.CornerSmall); reg(w)
                make("UIPadding",{Parent=w,PaddingLeft=UDim.new(0,8),
                    PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,6),
                    PaddingBottom=UDim.new(0,8)})
                local tl=lbl(w,title or "Info",12,T.AccentLight,T.FontSemi,18)
                local bl=lbl(w,body or "",11,T.TextSub,T.Font,0)
                bl.Position=UDim2.fromOffset(0,20)
                bl.Size=UDim2.new(1,0,0,0)
                bl.AutomaticSize=Enum.AutomaticSize.Y; bl.TextWrapped=true
                local o={}
                function o:SetText(a,b) tl.Text=tostring(a or ""); bl.Text=tostring(b or "") end
                function o:Destroy() w:Destroy() end
                return o
            end

            -- ── AddButton ──────────────────────────────────────────────────────
            -- LoveUp button: full-width, slight outline, text centered
            function group:AddButton(nameOrOpts,cb)
                local opts=type(nameOrOpts)=="table" and nameOrOpts
                    or {Name=nameOrOpts,Callback=cb}
                local bh=T.RowH
                local b=make("TextButton",{Name=tostring(opts.Name or "Button"),
                    Parent=ctrls,BackgroundColor3=T.BgElement,BorderSizePixel=0,
                    AutoButtonColor=false,Size=UDim2.new(1,0,0,bh),
                    Font=T.FontMedium,Text=tostring(opts.Name or opts.Text or "Button"),
                    TextColor3=T.TextPrimary,TextSize=12,ClipsDescendants=true})
                corner(b,T.CornerSmall); stroke(b,T.Border,1,0.4); reg(b)
                -- Hover glow
                local glow=make("Frame",{Parent=b,BackgroundColor3=T.Accent,
                    BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,0)})
                corner(glow,T.CornerSmall)
                b.MouseEnter:Connect(function() tw(glow,0.12,{BackgroundTransparency=0.85}) end)
                b.MouseLeave:Connect(function() tw(glow,0.12,{BackgroundTransparency=1}) end)
                b.MouseButton1Down:Connect(function() tw(glow,0.07,{BackgroundTransparency=0.72}) end)
                b.MouseButton1Up:Connect(function() tw(glow,0.1,{BackgroundTransparency=0.85}) end)
                b.Activated:Connect(function() haptic(); safeCall(opts.Func or opts.Callback) end)
                local o={Instance=b}
                function o:SetText(v) b.Text=tostring(v) end
                function o:Press() safeCall(opts.Func or opts.Callback) end
                function o:Destroy() b:Destroy() end
                return o
            end

            -- ── AddToggle (exact LoveUp pill) ──────────────────────────────────
            -- LoveUp: label left · [pill] right on same row
            -- Row has top padding ~8px from previous element
            -- Pill: 40×22, gray bg off / purple bg on, white knob
            -- Small 'i' info icon just right of label (optional, skip for now)
            function group:AddToggle(identifier,opts)
                opts=opts or {}
                local labelText=tostring(opts.Text or opts.Name or identifier or "Toggle")
                local value=opts.Default==true
                local rowH=T.RowH+6   -- LoveUp rows are slightly taller than slim

                make("Frame",{Parent=ctrls,BackgroundTransparency=1,
                    Size=UDim2.new(1,0,0,6),LayoutOrder=(function() ord=ord+1 return ord end)()})

                local row=make("Frame",{Name=tostring(identifier or labelText),
                    Parent=ctrls,BackgroundTransparency=1,BorderSizePixel=0,
                    Size=UDim2.new(1,0,0,rowH)})
                reg(row)

                -- Label
                local nameLbl=lbl(row,labelText,12,value and T.TextPrimary or T.TextSub,T.Font,rowH)
                nameLbl.Size=UDim2.new(1,-60,1,0)

                -- Pill dimensions (LoveUp reference)
                local pillW,pillH=40,22
                local pill=make("Frame",{Parent=row,BackgroundColor3=value and T.Accent or T.BgElement,
                    BorderSizePixel=0,AnchorPoint=Vector2.new(1,0.5),
                    Position=UDim2.new(1,0,0.5,0),Size=UDim2.fromOffset(pillW,pillH)})
                corner(pill,pillH/2)
                stroke(pill,value and T.AccentDark or T.Border,1,0.3)

                -- White knob
                local kSz=pillH-6
                local knob=make("Frame",{Parent=pill,BackgroundColor3=Color3.new(1,1,1),
                    BorderSizePixel=0,AnchorPoint=Vector2.new(0,0.5),
                    Position=value and UDim2.new(1,-(kSz+3),0.5,0) or UDim2.fromOffset(3,0),
                    Size=UDim2.fromOffset(kSz,kSz)})
                corner(knob,kSz/2)

                local obj=signal(value,opts.Callback,identifier,true)
                obj.Instance=row

                local function update(nv,fire)
                    value=nv==true
                    tw(pill,0.16,{BackgroundColor3=value and T.Accent or T.BgElement})
                    tw(knob,0.16,{Position=value
                        and UDim2.new(1,-(kSz+3),0.5,0)
                        or  UDim2.fromOffset(3,0)})
                    tw(nameLbl,0.12,{TextColor3=value and T.TextPrimary or T.TextSub})
                    obj.Value=value
                    if identifier then Library.Flags[identifier]=value end
                    if fire then haptic(); safeCall(opts.Callback,value); obj.Changed:Fire(value) end
                end

                -- Clickable area is the whole row
                local rb=make("TextButton",{Parent=row,BackgroundTransparency=1,
                    BorderSizePixel=0,Size=UDim2.new(1,0,1,0),Text="",AutoButtonColor=false})
                rb.Activated:Connect(function() update(not value,true) end)

                function obj:SetValue(v,silent) update(v,not silent) end
                function obj:OnChanged(fn)
                    if type(fn)=="function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy() row:Destroy(); obj.Changed:Destroy() end
                return obj
            end

            -- ── AddSlider (exact LoveUp style) ─────────────────────────────────
            -- Label · "50%" right-aligned · then full-width track below
            function group:AddSlider(identifier,opts)
                opts=opts or {}
                local minV=tonumber(opts.Min) or 0
                local maxV=tonumber(opts.Max) or 100
                if maxV<minV then maxV=minV end
                local rnd=tonumber(opts.Rounding) or 0
                local value=math.clamp(tonumber(opts.Default) or minV,minV,maxV)

                make("Frame",{Parent=ctrls,BackgroundTransparency=1,
                    Size=UDim2.new(1,0,0,6),LayoutOrder=(function() ord=ord+1 return ord end)()})

                -- Label row
                local labelRow=make("Frame",{Parent=ctrls,BackgroundTransparency=1,
                    Size=UDim2.new(1,0,0,18)})
                reg(labelRow)
                local nameLbl=lbl(labelRow,opts.Text or opts.Name or identifier,
                    12,T.TextSub,T.FontMedium,18)
                nameLbl.Size=UDim2.new(1,-50,1,0)

                -- "50%" label right side (LoveUp has it bold, accent colored)
                local pctLbl=make("TextLabel",{Parent=labelRow,BackgroundTransparency=1,
                    AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,0),
                    Size=UDim2.fromOffset(50,18),
                    Font=T.FontSemi,Text="0%",TextColor3=T.Accent,TextSize=12,
                    TextXAlignment=Enum.TextXAlignment.Right})

                -- Track (below label row, 4px gap)
                local trackH=mobile and 8 or 6
                local track=make("TextButton",{Parent=ctrls,BackgroundColor3=T.BgElement,
                    BorderSizePixel=0,Size=UDim2.new(1,0,0,trackH),
                    Text="",AutoButtonColor=false,ClipsDescendants=true})
                corner(track,trackH/2); stroke(track,T.Border,1,0.5); reg(track)

                -- Purple fill
                local fill=make("Frame",{Parent=track,BackgroundColor3=T.Accent,
                    BorderSizePixel=0,Size=UDim2.new(0,0,1,0)})
                corner(fill,trackH/2)

                -- Square/rounded knob at end of fill (LoveUp has a small square-ish knob)
                local kSz=mobile and 14 or 12
                local knob=make("Frame",{Parent=fill,BackgroundColor3=Color3.new(1,1,1),
                    BorderSizePixel=0,AnchorPoint=Vector2.new(1,0.5),
                    Position=UDim2.new(1,0,0.5,0),Size=UDim2.fromOffset(kSz,kSz)})
                corner(knob,3)   -- slightly rounded square
                stroke(knob,T.AccentDark,1,0.2)

                local obj=signal(value,opts.Callback,identifier,false)
                obj.Instance=track

                local function fmt(v)
                    if rnd<=0 then return tostring(math.floor(v+0.5)).."%" end
                    return string.format("%."..math.clamp(rnd,0,4).."f",v).."%"
                end
                local function upd(nv,fire)
                    nv=math.clamp(tonumber(nv) or minV,minV,maxV)
                    local m=10^math.clamp(rnd,0,4)
                    value=math.floor(nv*m+0.5)/m
                    local a=(maxV==minV) and 0 or (value-minV)/(maxV-minV)
                    fill.Size=UDim2.new(a,0,1,0)
                    pctLbl.Text=fmt(value)
                    obj.Value=value
                    if identifier then Library.Flags[identifier]=value end
                    if fire then safeCall(opts.Callback,value); obj.Changed:Fire(value) end
                end

                local sliding=false
                local function fromX(x)
                    local a=math.clamp((x-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1)
                    upd(minV+(maxV-minV)*a,true)
                end
                track.InputBegan:Connect(function(inp)
                    if inp.UserInputType==Enum.UserInputType.MouseButton1
                    or inp.UserInputType==Enum.UserInputType.Touch then
                        sliding=true; fromX(inp.Position.X)
                    end
                end)
                local eC=UserInputService.InputEnded:Connect(function(inp)
                    if inp.UserInputType==Enum.UserInputType.MouseButton1
                    or inp.UserInputType==Enum.UserInputType.Touch then sliding=false end
                end)
                local mC=UserInputService.InputChanged:Connect(function(inp)
                    if sliding and (inp.UserInputType==Enum.UserInputType.MouseMovement
                    or inp.UserInputType==Enum.UserInputType.Touch) then fromX(inp.Position.X) end
                end)

                function obj:SetValue(v,silent) upd(v,not silent) end
                function obj:OnChanged(fn)
                    if type(fn)=="function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy()
                    eC:Disconnect(); mC:Disconnect()
                    labelRow:Destroy(); track:Destroy(); obj.Changed:Destroy()
                end
                upd(value,false); return obj
            end

            -- ── AddDropdown (LoveUp: full-width, chevron ▾, dark bg) ────────────
            function group:AddDropdown(identifier,opts)
                opts=opts or {}
                local values=opts.Values or opts.Options or {}
                local selected=type(opts.Default)=="table" and opts.Default[1] or opts.Default
                if selected==nil and not opts.AllowNull then selected=values[1] end

                make("Frame",{Parent=ctrls,BackgroundTransparency=1,
                    Size=UDim2.new(1,0,0,6),LayoutOrder=(function() ord=ord+1 return ord end)()})

                local l=lbl(ctrls,opts.Text or opts.Name or identifier,
                    12,T.TextSub,T.FontMedium,18)
                reg(l)

                -- Dropdown button — LoveUp style: dark bg, text left, chevron right
                local db=make("TextButton",{Name="DD",Parent=ctrls,
                    BackgroundColor3=T.BgElement,BorderSizePixel=0,
                    AutoButtonColor=false,Size=UDim2.new(1,0,0,T.RowH),
                    Text="",ClipsDescendants=false})
                corner(db,T.CornerSmall); stroke(db,T.Border,1,0.25); reg(db)

                local selLbl=lbl(db,tostring(selected or "None"),12,T.TextPrimary,T.Font,T.RowH)
                selLbl.Position=UDim2.fromOffset(10,0); selLbl.Size=UDim2.new(1,-34,1,0)

                local arrow=make("TextLabel",{Parent=db,BackgroundTransparency=1,
                    AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-10,0.5,0),
                    Size=UDim2.fromOffset(16,16),Font=T.Font,Text="▾",
                    TextColor3=T.TextSub,TextSize=11,TextXAlignment=Enum.TextXAlignment.Center})

                local menuOpen=false
                local menu=make("Frame",{Parent=gui,  -- parent gui so it floats above
                    BackgroundColor3=T.BgPanel,BorderSizePixel=0,
                    Size=UDim2.fromOffset(200,0),Visible=false,ZIndex=50,
                    ClipsDescendants=true})
                corner(menu,T.CornerSmall); stroke(menu,T.BorderFocus,1,0.45)
                local ml=make("UIListLayout",{Parent=menu,SortOrder=Enum.SortOrder.LayoutOrder,
                    Padding=UDim.new(0,1)})
                make("UIPadding",{Parent=menu,PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,4)})

                local obj=signal(selected,opts.Callback,identifier,false)
                obj.Instance=db

                local function closeMenu()
                    menuOpen=false; menu.Visible=false; arrow.Text="▾"
                end
                local function setSel(v,fire)
                    selected=v; obj.Value=v; selLbl.Text=tostring(v or "None")
                    if identifier then Library.Flags[identifier]=v end
                    closeMenu()
                    if fire then safeCall(opts.Callback,v); obj.Changed:Fire(v) end
                end
                local function rebuild()
                    for _,c in ipairs(menu:GetChildren()) do
                        if c:IsA("TextButton") then c:Destroy() end
                    end
                    for i,val in ipairs(values) do
                        local ob=make("TextButton",{Name="O"..i,Parent=menu,
                            BackgroundColor3=T.BgElement,BackgroundTransparency=1,
                            BorderSizePixel=0,AutoButtonColor=false,
                            Size=UDim2.new(1,0,0,mobile and 30 or 26),
                            Font=T.Font,Text=tostring(val),
                            TextColor3=val==selected and T.Accent or T.TextPrimary,
                            TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,
                            ZIndex=51,LayoutOrder=i})
                        make("UIPadding",{Parent=ob,PaddingLeft=UDim.new(0,10)})
                        ob.MouseEnter:Connect(function() tw(ob,0.08,{BackgroundTransparency=0}) end)
                        ob.MouseLeave:Connect(function() tw(ob,0.08,{BackgroundTransparency=1}) end)
                        ob.Activated:Connect(function() haptic(); setSel(val,true) end)
                    end
                end
                rebuild()

                db.Activated:Connect(function()
                    menuOpen=not menuOpen; arrow.Text=menuOpen and "▴" or "▾"
                    if menuOpen then
                        -- Position menu under the button
                        local absp=db.AbsolutePosition; local abss=db.AbsoluteSize
                        local mh=math.min(ml.AbsoluteContentSize.Y+8, 160)
                        menu.Position=UDim2.fromOffset(absp.X, absp.Y+abss.Y+2)
                        menu.Size=UDim2.fromOffset(abss.X, mh)
                        menu.Visible=true
                    else closeMenu() end
                    haptic()
                end)
                -- Close on outside click
                UserInputService.InputBegan:Connect(function(inp)
                    if menuOpen and inp.UserInputType==Enum.UserInputType.MouseButton1 then
                        task.defer(closeMenu)
                    end
                end)

                function obj:SetValue(v,silent) setSel(v,not silent) end
                function obj:SetValues(nv) values=nv or {}; rebuild() end
                function obj:OnChanged(fn)
                    if type(fn)=="function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy() l:Destroy(); db:Destroy(); menu:Destroy(); obj.Changed:Destroy() end
                return obj
            end

            -- ── AddInput ───────────────────────────────────────────────────────
            function group:AddInput(identifier,opts)
                opts=opts or {}
                make("Frame",{Parent=ctrls,BackgroundTransparency=1,
                    Size=UDim2.new(1,0,0,6),LayoutOrder=(function() ord=ord+1 return ord end)()})
                local l=lbl(ctrls,opts.Text or opts.Name or identifier,
                    12,T.TextSub,T.FontMedium,18); reg(l)
                local inp=make("TextBox",{Parent=ctrls,BackgroundColor3=T.BgElement,
                    BorderSizePixel=0,ClearTextOnFocus=false,
                    Size=UDim2.new(1,0,0,T.RowH),Font=T.Font,
                    PlaceholderText=opts.Placeholder or "Enter text...",
                    PlaceholderColor3=T.TextMuted,
                    Text=tostring(opts.Default or ""),
                    TextColor3=T.TextPrimary,TextSize=12,
                    TextXAlignment=Enum.TextXAlignment.Left})
                corner(inp,T.CornerSmall); stroke(inp,T.Border,1,0.3)
                make("UIPadding",{Parent=inp,PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
                reg(inp)
                inp.Focused:Connect(function() tw(inp,0.1,{BackgroundColor3=T.BgElementHov}) end)
                inp.FocusLost:Connect(function() tw(inp,0.1,{BackgroundColor3=T.BgElement}) end)
                local obj=signal(inp.Text,opts.Callback,identifier,false)
                obj.Instance=inp
                inp.FocusLost:Connect(function(enter)
                    obj.Value=inp.Text
                    if identifier then Library.Flags[identifier]=inp.Text end
                    if opts.FireOnEnterOnly and not enter then return end
                    safeCall(opts.Callback,inp.Text,enter); obj.Changed:Fire(inp.Text)
                end)
                function obj:SetValue(v,silent)
                    inp.Text=tostring(v or ""); obj.Value=inp.Text
                    if identifier then Library.Flags[identifier]=obj.Value end
                    if not silent then safeCall(opts.Callback,obj.Value); obj.Changed:Fire(obj.Value) end
                end
                function obj:OnChanged(fn)
                    if type(fn)=="function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy() l:Destroy(); inp:Destroy(); obj.Changed:Destroy() end
                return obj
            end

            -- ── AddKeyPicker ───────────────────────────────────────────────────
            function group:AddKeyPicker(identifier,opts)
                opts=opts or {}
                local labelText=tostring(opts.Text or opts.Name or identifier or "Keybind")
                make("Frame",{Parent=ctrls,BackgroundTransparency=1,
                    Size=UDim2.new(1,0,0,6),LayoutOrder=(function() ord=ord+1 return ord end)()})
                local row=make("Frame",{Parent=ctrls,BackgroundTransparency=1,
                    Size=UDim2.new(1,0,0,T.RowH)}); reg(row)
                local nl=lbl(row,labelText,12,T.TextSub,T.Font,T.RowH)
                nl.Size=UDim2.new(1,-110,1,0)
                local kb=make("TextButton",{Parent=row,BackgroundColor3=T.BgElement,
                    BorderSizePixel=0,AutoButtonColor=false,
                    AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),
                    Size=UDim2.fromOffset(100,T.RowH-6),
                    Font=T.FontMedium,Text=tostring(opts.Default or "None"),
                    TextColor3=T.TextPrimary,TextSize=11})
                corner(kb,T.CornerSmall); stroke(kb,T.Border,1,0.3)
                local curKey=opts.Default; local listening=false
                local obj=signal(curKey,opts.Callback,identifier,false)
                obj.Instance=kb
                kb.Activated:Connect(function()
                    listening=true; kb.Text="Press key..."
                    tw(kb,0.1,{TextColor3=T.AccentLight}); haptic()
                end)
                local conn=UserInputService.InputBegan:Connect(function(inp,proc)
                    if proc then return end
                    if listening and inp.UserInputType==Enum.UserInputType.Keyboard then
                        listening=false; curKey=inp.KeyCode
                        kb.Text=curKey.Name; tw(kb,0.1,{TextColor3=T.TextPrimary})
                        obj:SetValue(curKey)
                    elseif curKey and inp.KeyCode==curKey then
                        safeCall(opts.Callback,curKey)
                    end
                end)
                function obj:SetValue(v,silent)
                    curKey=v; kb.Text=typeof(v)=="EnumItem" and v.Name or tostring(v or "None")
                    obj.Value=v
                    if identifier then Library.Flags[identifier]=v end
                    if not silent then safeCall(opts.Callback,v); obj.Changed:Fire(v) end
                end
                function obj:OnChanged(fn)
                    if type(fn)=="function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy() conn:Disconnect(); row:Destroy(); obj.Changed:Destroy() end
                return obj
            end

            -- ── AddColorPicker ─────────────────────────────────────────────────
            function group:AddColorPicker(identifier,opts)
                opts=opts or {}
                local current=opts.Default or T.Accent
                make("Frame",{Parent=ctrls,BackgroundTransparency=1,
                    Size=UDim2.new(1,0,0,6),LayoutOrder=(function() ord=ord+1 return ord end)()})
                local row=make("Frame",{Parent=ctrls,BackgroundTransparency=1,
                    Size=UDim2.new(1,0,0,T.RowH)}); reg(row)
                local nl=lbl(row,opts.Text or opts.Name or identifier,
                    12,T.TextSub,T.Font,T.RowH)
                nl.Size=UDim2.new(1,-54,1,0)
                local sw=make("TextButton",{Parent=row,AnchorPoint=Vector2.new(1,0.5),
                    Position=UDim2.new(1,0,0.5,0),Size=UDim2.fromOffset(44,T.RowH-8),
                    BackgroundColor3=current,BorderSizePixel=0,Text="",AutoButtonColor=false})
                corner(sw,T.CornerSmall); stroke(sw,T.Border,1,0.15)
                local obj=signal(current,opts.Callback,identifier,false)
                obj.Instance=sw
                sw.Activated:Connect(function()
                    haptic()
                    local h,s,v=current:ToHSV()
                    current=Color3.fromHSV((h+0.08)%1,s,v)
                    sw.BackgroundColor3=current; obj:SetValue(current)
                end)
                function obj:SetValue(v,silent)
                    if typeof(v)~="Color3" then return end
                    current=v; sw.BackgroundColor3=current; obj.Value=current
                    if identifier then Library.Flags[identifier]=current end
                    if not silent then safeCall(opts.Callback,current); obj.Changed:Fire(current) end
                end
                function obj:OnChanged(fn)
                    if type(fn)=="function" then obj.Changed.Event:Connect(fn) end; return obj
                end
                function obj:Destroy() row:Destroy(); obj.Changed:Destroy() end
                return obj
            end

            return group
        end -- makeGroup

        function tab:AddLeftGroupbox(name)  return makeGroup(name,"Left")  end
        function tab:AddRightGroupbox(name) return makeGroup(name,"Right") end
        function tab:AddGroupbox(name)      return makeGroup(name,"Left")  end

        -- Compat shims
        function tab:CreateButton(opts,cb)
            return self:AddLeftGroupbox("Controls"):AddButton(opts,cb)
        end
        function tab:CreateToggle(opts)
            return self:AddLeftGroupbox("Controls"):AddToggle(opts.Flag or opts.Name,opts)
        end
        function tab:CreateSlider(opts)
            return self:AddLeftGroupbox("Controls"):AddSlider(opts.Flag or opts.Name,opts)
        end

        return tab
    end -- CreateTab

    window.AddTab = function(self,name)
        return self:CreateTab(type(name)=="table" and name or {Name=name})
    end
    window.Holder = content

    if settings.AutoShow then gui.Enabled=true end
    table.insert(Library.Windows,window)
    return window
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public helpers
-- ─────────────────────────────────────────────────────────────────────────────
function Library:Create(cls,props) return make(cls,props) end
function Library:CreateCorner(p,r) return corner(p,r) end
function Library:SetTheme(t)
    for k,v in pairs(t or {}) do if T[k]~=nil then T[k]=v end end
end
function Library:Unload()
    self.Unloaded=true
    for _,w in ipairs(self.Windows) do pcall(function() w:Destroy() end) end
    self.Windows={}; self.Registry={}; self.RegistryMap={}
    self.HudRegistry={}; self.Flags={}; self.Options={}
    self.Toggles={}; self.ScreenGui=nil
end

return Library
