--[[
    ===================================================================================
    🔥 UNIVERSAL FPS HUB - ROBLOX
    ===================================================================================
    Tính năng:
      • ESP Box (Highlight xuyên tường siêu mượt, hiện Tên, Máu & Khoảng cách)
      • ESP Line (Tracers từ đáy màn hình tới địch)
      • Silent Aim & Melee Reach (Đạn tự trúng & Dao chém tầm xa không cần ngắm)
      • Noclip (Đi xuyên tường mượt mà)
      • Fix Lag / FPS Boost (Tắt bóng, giảm texture, xóa hiệu ứng hạt lag)
      • Fullbright (Sáng toàn bản đồ, nhìn rõ kẻ địch trong góc tối)
      • Custom Crosshair (Tâm ảo giữa màn hình)
      • Infinite Jump & Speed Boost (Nhảy liên tục & Tăng tốc độ chạy)
      • Floating Mobile Toggle Button (Nút nổi bật/tắt menu cực tiện trên điện thoại)
    ===================================================================================
--]]

-- [[ SERVICES ]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- [[ QUẢN LÝ GUI AN TOÀN ]]
local function getSafeGuiParent()
    if typeof(gethui) == "function" then
        return gethui()
    end
    local s, res = pcall(function() return CoreGui end)
    if s and res then
        return res
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local GuiParent = getSafeGuiParent()

-- Xóa menu cũ nếu có đang chạy
if GuiParent:FindFirstChild("UniversalFPSHub") then
    GuiParent.UniversalFPSHub:Destroy()
end

-- [[ TRẠNG THÁI CONFIG TỔNG HỢP ]]
local Config = {
    -- Visuals
    EspBox = false,
    EspLine = false,
    EspNames = false,
    TeamCheck = true,
    EspColor = Color3.fromRGB(255, 65, 65),
    TeamColor = Color3.fromRGB(65, 255, 65),

    -- Combat
    SilentAim = false,
    HitboxReach = false,
    HitboxSize = 15, -- Kích thước mở rộng hitbox (chém dao từ xa & đạn tự trúng)
    SilentAimFov = 150,

    -- Movement
    Noclip = false,
    SpeedBoost = false,
    SpeedValue = 28,
    InfiniteJump = false,

    -- Optimization & Visual
    FixLag = false,
    Fullbright = false,
    Crosshair = false
}

-- [[ BỘ LƯU TRỮ VẬT THỂ ESP ]]
local EspHighlights = {}
local EspLines = {}
local EspBillboards = {}
local OriginalHitboxes = {}

-- [[ KIỂM TRA ĐỒNG ĐỘI ]]
local function isTeammate(player)
    if not Config.TeamCheck then return false end
    if player == LocalPlayer then return true end
    if LocalPlayer.Team and player.Team then
        return LocalPlayer.Team == player.Team
    end
    return false
end

-- [[ TẠO GIAO DIỆN (UI) CHUYÊN NGHIỆP ]]
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UniversalFPSHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = GuiParent

-- 1. NÚT NỔI BẬT/TẮT MENU TRÊN ĐIỆN THOẠI (FLOATING TOGGLE BUTTON)
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "MobileToggleBtn"
ToggleButton.Size = UDim2.new(0, 50, 0, 50)
ToggleButton.Position = UDim2.new(0.05, 0, 0.25, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
ToggleButton.Text = "🎯"
ToggleButton.TextSize = 24
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.AutoButtonColor = false
ToggleButton.Parent = ScreenGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(1, 0)
ToggleCorner.Parent = ToggleButton

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Thickness = 2
ToggleStroke.Color = Color3.fromRGB(255, 75, 75)
ToggleStroke.Parent = ToggleButton

-- Kéo thả nút di động
local isDraggingToggle = false
local dragStartToggle, startPosToggle

ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingToggle = true
        dragStartToggle = input.Position
        startPosToggle = ToggleButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isDraggingToggle = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDraggingToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartToggle
        ToggleButton.Position = UDim2.new(
            startPosToggle.X.Scale,
            startPosToggle.X.Offset + delta.X,
            startPosToggle.Y.Scale,
            startPosToggle.Y.Offset + delta.Y
        )
    end
end)

-- 2. KHUNG MENU CHÍNH (MAIN FRAME)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 360, 0, 390)
MainFrame.Position = UDim2.new(0.5, -180, 0.5, -195)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.5
MainStroke.Color = Color3.fromRGB(45, 45, 65)
MainStroke.Parent = MainFrame

-- Kéo thả MainFrame
local isDraggingFrame = false
local dragStartFrame, startPosFrame

MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if input.Position.Y < MainFrame.AbsolutePosition.Y + 40 then
            isDraggingFrame = true
            dragStartFrame = input.Position
            startPosFrame = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDraggingFrame = false
                end
            end)
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDraggingFrame and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartFrame
        MainFrame.Position = UDim2.new(
            startPosFrame.X.Scale,
            startPosFrame.X.Offset + delta.X,
            startPosFrame.Y.Scale,
            startPosFrame.Y.Offset + delta.Y
        )
    end
end)

-- Thanh tiêu đề (Top Bar)
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 38)
TopBar.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🎯 UNIVERSAL FPS HUB"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 15
TitleLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -34, 0, 4)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
CloseBtn.Parent = TopBar

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Danh sách nút cuộn (Scroll Area)
local ContentScroll = Instance.new("ScrollingFrame")
ContentScroll.Name = "ContentScroll"
ContentScroll.Size = UDim2.new(1, -16, 1, -48)
ContentScroll.Position = UDim2.new(0, 8, 0, 42)
ContentScroll.BackgroundTransparency = 1
ContentScroll.ScrollBarThickness = 3
ContentScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 75, 75)
ContentScroll.CanvasSize = UDim2.new(0, 0, 0, 480)
ContentScroll.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0, 8)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Parent = ContentScroll

-- HÀM TẠO NÚT TOGGLE
local function createToggle(name, labelText, defaultVal, callback)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 0, 40)
    Container.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    Container.BorderSizePixel = 0
    Container.Parent = ContentScroll

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Container

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -65, 1, 0)
    Title.Position = UDim2.new(0, 12, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = labelText
    Title.Font = Enum.Font.GothamSemibold
    Title.TextSize = 13
    Title.TextColor3 = Color3.fromRGB(230, 230, 240)
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Container

    local Switch = Instance.new("TextButton")
    Switch.Size = UDim2.new(0, 45, 0, 24)
    Switch.Position = UDim2.new(1, -52, 0.5, -12)
    Switch.BackgroundColor3 = defaultVal and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(60, 60, 75)
    Switch.Text = defaultVal and "ON" or "OFF"
    Switch.Font = Enum.Font.GothamBold
    Switch.TextSize = 11
    Switch.TextColor3 = Color3.fromRGB(255, 255, 255)
    Switch.AutoButtonColor = false
    Switch.Parent = Container

    local SwitchCorner = Instance.new("UICorner")
    SwitchCorner.CornerRadius = UDim.new(0, 12)
    SwitchCorner.Parent = Switch

    local state = defaultVal
    Switch.MouseButton1Click:Connect(function()
        state = not state
        Switch.Text = state and "ON" or "OFF"
        Switch.BackgroundColor3 = state and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(60, 60, 75)
        pcall(callback, state)
    end)

    return Container
end

-- ==============================================================================
-- 1. TÍNH NĂNG: ESP BOX & CHAMS (XUYÊN TƯỜNG SIÊU MƯỢT)
-- ==============================================================================
local function applyEspHighlight(player)
    if player == LocalPlayer then return end
    
    local function setupChar(char)
        if not char then return end
        
        -- Xóa cũ nếu có
        if char:FindFirstChild("ESPHighlight") then
            char.ESPHighlight:Destroy()
        end
        if char:FindFirstChild("ESPTag") then
            char.ESPTag:Destroy()
        end

        if not Config.EspBox then return end
        if isTeammate(player) then return end

        -- Tạo Highlight (vẽ viền xuyên tường mượt 100%)
        local hl = Instance.new("Highlight")
        hl.Name = "ESPHighlight"
        hl.Adornee = char
        hl.FillColor = Config.EspColor
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.55
        hl.OutlineTransparency = 0.1
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char
        EspHighlights[player] = hl

        -- Billboard tên & khoảng cách
        local head = char:WaitForChild("Head", 3)
        if head then
            local bbg = Instance.new("BillboardGui")
            bbg.Name = "ESPTag"
            bbg.Adornee = head
            bbg.Size = UDim2.new(0, 120, 0, 40)
            bbg.StudsOffset = Vector3.new(0, 2.2, 0)
            bbg.AlwaysOnTop = true
            bbg.Parent = char

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Name = "NameLabel"
            nameLbl.Size = UDim2.new(1, 0, 1, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.TextSize = 11
            nameLbl.TextColor3 = Config.EspColor
            nameLbl.TextStrokeTransparency = 0.4
            nameLbl.Text = player.Name
            nameLbl.Parent = bbg

            EspBillboards[player] = bbg
        end
    end

    if player.Character then
        setupChar(player.Character)
    end
    player.CharacterAdded:Connect(setupChar)
end

local function refreshAllEsp()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if Config.EspBox then
                applyEspHighlight(p)
            else
                if p.Character then
                    if p.Character:FindFirstChild("ESPHighlight") then p.Character.ESPHighlight:Destroy() end
                    if p.Character:FindFirstChild("ESPTag") then p.Character.ESPTag:Destroy() end
                end
            end
        end
    end
end

-- ==============================================================================
-- 2. TÍNH NĂNG: ESP LINE (TRACERS TỪ ĐÁY MÀN HÌNH TỚI ĐỊCH)
-- ==============================================================================
local function createTracerLine()
    if typeof(Drawing) == "table" and typeof(Drawing.new) == "function" then
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = Config.EspColor
        line.Thickness = 1.5
        line.Transparency = 0.85
        return line
    end
    return nil
end

RunService.RenderStepped:Connect(function()
    -- Cập nhật ESP Line
    if Config.EspLine and typeof(Drawing) == "table" then
        local screenBottom = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and not isTeammate(p) then
                local hrp = p.Character.HumanoidRootPart
                local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                
                local tracer = EspLines[p]
                if not tracer then
                    tracer = createTracerLine()
                    EspLines[p] = tracer
                end

                if tracer then
                    if onScreen then
                        tracer.From = screenBottom
                        tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                        tracer.Visible = true
                    else
                        tracer.Visible = false
                    end
                end
            else
                if EspLines[p] then
                    EspLines[p].Visible = false
                end
            end
        end
    else
        for _, line in pairs(EspLines) do
            line.Visible = false
        end
    end

    -- Cập nhật khoảng cách mét cho BillboardGui
    if Config.EspBox and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local myPos = LocalPlayer.Character.HumanoidRootPart.Position
        for p, bbg in pairs(EspBillboards) do
            if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") then
                local dist = math.floor((p.Character.HumanoidRootPart.Position - myPos).Magnitude)
                local hp = math.floor(p.Character.Humanoid.Health)
                local lbl = bbg:FindFirstChild("NameLabel")
                if lbl then
                    lbl.Text = string.format("%s\n[%d HP | %dm]", p.Name, hp, dist)
                end
            end
        end
    end
end)

-- ==============================================================================
-- 3. TÍNH NĂNG: SILENT AIM & MELEE REACH (CHÉM DAO TỪ XA & ĐẠN TỰ TRÚNG)
-- ==============================================================================
-- Cơ chế: Mở rộng Hitbox của địch (Hitbox Expander) + Đặt CanCollide = false.
-- Giúp mọi đường đạn và nhát chém vũ khí cận chiến (.Touched) tự trúng từ khoảng cách xa!
local function updateHitboxes()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and not isTeammate(p) then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local head = p.Character:FindFirstChild("Head")
            
            if Config.HitboxReach then
                if hrp then
                    if not OriginalHitboxes[hrp] then
                        OriginalHitboxes[hrp] = { Size = hrp.Size, Transparency = hrp.Transparency, CanCollide = hrp.CanCollide }
                    end
                    hrp.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                    hrp.Transparency = 0.75
                    hrp.Color = Color3.fromRGB(255, 50, 50)
                    hrp.Material = Enum.Material.Neon
                    hrp.CanCollide = false
                end
                if head then
                    if not OriginalHitboxes[head] then
                        OriginalHitboxes[head] = { Size = head.Size, Transparency = head.Transparency, CanCollide = head.CanCollide }
                    end
                    head.Size = Vector3.new(Config.HitboxSize * 0.7, Config.HitboxSize * 0.7, Config.HitboxSize * 0.7)
                    head.CanCollide = false
                end
            else
                -- Khôi phục kích thước ban đầu
                if hrp and OriginalHitboxes[hrp] then
                    hrp.Size = OriginalHitboxes[hrp].Size
                    hrp.Transparency = OriginalHitboxes[hrp].Transparency
                    hrp.CanCollide = OriginalHitboxes[hrp].CanCollide
                end
                if head and OriginalHitboxes[head] then
                    head.Size = OriginalHitboxes[head].Size
                    head.Transparency = OriginalHitboxes[head].Transparency
                    head.CanCollide = OriginalHitboxes[head].CanCollide
                end
            end
        end
    end
end

-- Vòng lặp giữ hitbox luôn duy trì kể cả khi địch hồi sinh
task.spawn(function()
    while true do
        task.wait(1.5)
        if Config.HitboxReach then
            pcall(updateHitboxes)
        end
    end
end)

-- Hook Raycast Silent Aim cho súng (bẻ hướng tia đạn về phía đầu của mục tiêu gần nhất)
pcall(function()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if Config.SilentAim and not checkcaller() and (method == "Raycast" or method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList") then
            -- Tìm mục tiêu địch gần tâm ngắm nhất
            local closestTarget = nil
            local shortestDist = Config.SilentAimFov

            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and not isTeammate(p) then
                    local head = p.Character:FindFirstChild("Head")
                    local hum = p.Character:FindFirstChild("Humanoid")
                    if head and hum and hum.Health > 0 then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                        if onScreen then
                            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - (Camera.ViewportSize / 2)).Magnitude
                            if screenDist < shortestDist then
                                shortestDist = screenDist
                                closestTarget = head
                            end
                        end
                    end
                end
            end

            -- Bẻ hướng bắn thẳng vào đầu địch
            if closestTarget then
                if method == "Raycast" and typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
                    local origin = args[1]
                    args[2] = (closestTarget.Position - origin).Unit * 1000
                    return oldNamecall(self, unpack(args))
                elseif method == "FindPartOnRay" and typeof(args[1]) == "Ray" then
                    local origin = args[1].Origin
                    local newRay = Ray.new(origin, (closestTarget.Position - origin).Unit * 1000)
                    args[1] = newRay
                    return oldNamecall(self, unpack(args))
                end
            end
        end

        return oldNamecall(self, ...)
    end)
end)

-- ==============================================================================
-- 4. TÍNH NĂNG: NOCLIP (ĐI XUYÊN TƯỜNG)
-- ==============================================================================
RunService.Stepped:Connect(function()
    if Config.Noclip and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

-- ==============================================================================
-- 5. TÍNH NĂNG: FIX LAG / FPS BOOST (TỐI ƯU HÓA ĐỒ HỌA MƯỢT 60 FPS)
-- ==============================================================================
local function applyFixLag()
    -- Tắt bóng toàn bộ vật thể
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.CastShadow = false
            obj.Material = Enum.Material.SmoothPlastic
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            obj.Enabled = false
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 0.5
        end
    end

    -- Tắt các hiệu ứng hậu kỳ làm mờ/lag màn hình
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("PostProcessEffect") or effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("BloomEffect") or effect:IsA("DepthOfFieldEffect") then
            effect.Enabled = false
        end
    end

    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
end

-- ==============================================================================
-- 6. TÍNH NĂNG: FULLBRIGHT (SÁNG TOÀN BẢN ĐỒ)
-- ==============================================================================
local originalLighting = {
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime
}

local function toggleFullbright(state)
    if state then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
    else
        Lighting.Ambient = originalLighting.Ambient
        Lighting.Brightness = originalLighting.Brightness
        Lighting.ClockTime = originalLighting.ClockTime
    end
end

-- ==============================================================================
-- 7. TÍNH NĂNG: CUSTOM CROSSHAIR (TÂM ẢO GIỮA MÀN HÌNH)
-- ==============================================================================
local CrosshairFrame = Instance.new("Frame")
CrosshairFrame.Name = "CustomCrosshair"
CrosshairFrame.Size = UDim2.new(0, 16, 0, 16)
CrosshairFrame.Position = UDim2.new(0.5, -8, 0.5, -8)
CrosshairFrame.BackgroundTransparency = 1
CrosshairFrame.Visible = false
CrosshairFrame.Parent = ScreenGui

local Dot = Instance.new("Frame")
Dot.Size = UDim2.new(0, 4, 0, 4)
Dot.Position = UDim2.new(0.5, -2, 0.5, -2)
Dot.BackgroundColor3 = Color3.fromRGB(0, 255, 170)
Dot.BorderSizePixel = 0
Dot.Parent = CrosshairFrame

local DotCorner = Instance.new("UICorner")
DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = Dot

-- 4 vạch tâm
local function makeLine(w, h, x, y)
    local l = Instance.new("Frame")
    l.Size = UDim2.new(0, w, 0, h)
    l.Position = UDim2.new(0.5, x, 0.5, y)
    l.BackgroundColor3 = Color3.fromRGB(0, 255, 170)
    l.BorderSizePixel = 0
    l.Parent = CrosshairFrame
end
makeLine(8, 2, -12, -1) -- Trái
makeLine(8, 2, 4, -1)   -- Phải
makeLine(2, 8, -1, -12) -- Trên
makeLine(2, 8, -1, 4)   -- Dưới

-- ==============================================================================
-- 8. TÍNH NĂNG: SPEED BOOST & INFINITE JUMP
-- ==============================================================================
RunService.Heartbeat:Connect(function()
    if Config.SpeedBoost and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum and hum.WalkSpeed < Config.SpeedValue then
            hum.WalkSpeed = Config.SpeedValue
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- ==============================================================================
-- THÊM CÁC NÚT ĐIỀU KHIỂN VÀO MENU
-- ==============================================================================
-- [COMBAT]
createToggle("MeleeReach", "🗡️ Melee Reach (Dao Chém Xa)", Config.HitboxReach, function(val)
    Config.HitboxReach = val
    updateHitboxes()
end)

createToggle("SilentAim", "🎯 Silent Aim (Đạn Tự Hút)", Config.SilentAim, function(val)
    Config.SilentAim = val
end)

-- [VISUALS]
createToggle("EspBox", "📦 ESP Box & Chams (Xuyên Tường)", Config.EspBox, function(val)
    Config.EspBox = val
    refreshAllEsp()
end)

createToggle("EspLine", "📏 ESP Line (Đường Dẫn Địch)", Config.EspLine, function(val)
    Config.EspLine = val
end)

createToggle("TeamCheck", "🛡️ Team Check (Bỏ Qua Đồng Đội)", Config.TeamCheck, function(val)
    Config.TeamCheck = val
    refreshAllEsp()
    updateHitboxes()
end)

-- [MOVEMENT]
createToggle("Noclip", "👻 Noclip (Đi Xuyên Tường)", Config.Noclip, function(val)
    Config.Noclip = val
end)

createToggle("SpeedBoost", "⚡ Speed Boost (Tăng Tốc Chạy)", Config.SpeedBoost, function(val)
    Config.SpeedBoost = val
    if not val and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = 16
    end
end)

createToggle("InfJump", "🦘 Infinite Jump (Nhảy Vô Hạn)", Config.InfiniteJump, function(val)
    Config.InfiniteJump = val
end)

-- [OPTIMIZATION & UTILITY]
createToggle("FixLag", "🚀 Fix Lag / FPS Boost (Tăng Mượt)", Config.FixLag, function(val)
    Config.FixLag = val
    if val then applyFixLag() end
end)

createToggle("Fullbright", "💡 Fullbright (Sáng Toàn Map)", Config.Fullbright, function(val)
    Config.Fullbright = val
    toggleFullbright(val)
end)

createToggle("Crosshair", "➕ Custom Crosshair (Tâm Ảo)", Config.Crosshair, function(val)
    Config.Crosshair = val
    CrosshairFrame.Visible = val
end)

-- Lắng nghe người chơi mới tham gia game
Players.PlayerAdded:Connect(function(p)
    if Config.EspBox then
        applyEspHighlight(p)
    end
    if Config.HitboxReach then
        p.CharacterAdded:Connect(function()
            task.wait(1)
            updateHitboxes()
        end)
    end
end)

print("[Universal FPS Hub] Đã tải thành công! Bấm vào nút 🎯 để ẩn/hiện menu.")
