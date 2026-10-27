--[[
    ===================================================================================
    🎯 FPS Tools v3 - Smart Aimbot & Hitbox Expander
    Tested: Delta, Codex, Hydrogen, Arceus X, Solara, Wave
    ===================================================================================
]]

-- Dọn dẹp phiên chạy cũ
pcall(function()
    if typeof(getgenv) == "function" and getgenv()._FPSClean then
        getgenv()._FPSClean()
    end
end)

-- === SERVICES ===
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local LP = Players.LocalPlayer

-- === CẤU HÌNH ===
local S = {
    -- Combat
    Aimbot = false,
    AimSmooth = 0.20,       -- Độ mượt: 0.1 (cực mượt) -> 0.4 (bám nhanh)
    AimFov = 160,           -- Bán kính vùng ngắm (pixels)
    WallCheck = true,       -- Chỉ ngắm khi địch lộ diện (không sau tường)
    ShowFov = false,        -- Hiển thị vòng tròn FOV
    HitboxExpander = false, -- Phóng to Hitbox
    HitboxSize = 10,        -- Kích thước Hitbox mở rộng

    -- Visual
    Esp = false,
    Fullbright = false,
    Crosshair = false,
    TeamCheck = true,

    -- Movement
    Noclip = false,
    Speed = false,
    SpeedVal = 26,
    InfJump = false,

    -- Other
    FixLag = false,
}

-- === TRẠNG THÁI NỘI BỘ ===
local espStore = {}
local origHitboxes = {}
local noclipParts = {}
local noclipOriginals = {}
local hasDrawing = typeof(Drawing) == "table" and pcall(function() local t = Drawing.new("Line"); t:Remove() end)
local origLighting = {
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows
}

-- === GUI PARENT AN TOÀN ===
local guiParent
if typeof(gethui) == "function" then
    guiParent = gethui()
else
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    guiParent = (ok and cg) or LP:WaitForChild("PlayerGui")
end

pcall(function()
    if guiParent:FindFirstChild("_FPSTools") then
        guiParent._FPSTools:Destroy()
    end
end)

-- === HÀM TIỆN ÍCH ===
local function isEnemy(p)
    if not p or p == LP or not p.Parent then return false end
    if S.TeamCheck and LP.Team and p.Team and LP.Team == p.Team then return false end
    return true
end

local function getChar(p)
    local c = p and p.Character
    if not c then return nil, nil, nil, nil end
    return c, c:FindFirstChild("Head"), c:FindFirstChild("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end

-- Kiểm tra xem mục tiêu có bị cản bởi tường không (Wall Check)
local function isVisible(targetPart)
    local cam = workspace.CurrentCamera
    if not cam or not targetPart then return false end
    local origin = cam.CFrame.Position
    local dest = targetPart.Position
    local dir = dest - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filterList = {}
    if LP.Character then table.insert(filterList, LP.Character) end
    if targetPart.Parent then table.insert(filterList, targetPart.Parent) end
    params.FilterDescendantsInstances = filterList

    local hit = workspace:Raycast(origin, dir, params)
    return hit == nil
end

-- Tìm mục tiêu tốt nhất trong phạm vi FOV
local function getAimbotTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local center = cam.ViewportSize / 2
    local bestTarget = nil
    local bestDist = S.AimFov

    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) then
            local _, head, hum = getChar(p)
            if head and hum and hum.Health > 0 then
                local sp, onScreen = cam:WorldToViewportPoint(head.Position)
                if onScreen then
                    local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if screenDist <= bestDist then
                        if not S.WallCheck or isVisible(head) then
                            bestDist = screenDist
                            bestTarget = head
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

-- =============================================
-- 1. SMART AIMBOT: XOAY CAMERA MƯỢT MÀ TỰ NHIÊN
-- =============================================
RS.RenderStepped:Connect(function()
    if S.Aimbot then
        local target = getAimbotTarget()
        if target then
            local cam = workspace.CurrentCamera
            if cam then
                local targetCFrame = CFrame.lookAt(cam.CFrame.Position, target.Position)
                -- Nội suy mượt mà, không ghim cứng, không giật hình
                cam.CFrame = cam.CFrame:Lerp(targetCFrame, S.AimSmooth)
            end
        end
    end
end)

-- =============================================
-- 2. HITBOX EXPANDER: MỞ RỘNG KHỐI HITBOX ĐỊCH
-- =============================================
local function applyHitbox(p)
    if not isEnemy(p) then return end
    local _, _, hum, hrp = getChar(p)
    if hrp and hum and hum.Health > 0 then
        if not origHitboxes[hrp] then
            origHitboxes[hrp] = {
                Size = hrp.Size,
                Transparency = hrp.Transparency,
                Color = hrp.Color,
                Material = hrp.Material,
                CanCollide = hrp.CanCollide
            }
        end
        hrp.Size = Vector3.new(S.HitboxSize, S.HitboxSize, S.HitboxSize)
        hrp.Transparency = 0.65
        hrp.Color = Color3.fromRGB(255, 45, 45)
        hrp.Material = Enum.Material.ForceField
        hrp.CanCollide = false
    end
end

local function restoreHitbox(p)
    local _, _, _, hrp = getChar(p)
    if hrp and origHitboxes[hrp] then
        local orig = origHitboxes[hrp]
        pcall(function()
            hrp.Size = orig.Size
            hrp.Transparency = orig.Transparency
            hrp.Color = orig.Color
            hrp.Material = orig.Material
            hrp.CanCollide = orig.CanCollide
        end)
        origHitboxes[hrp] = nil
    end
end

local function restoreAllHitboxes()
    for _, p in ipairs(Players:GetPlayers()) do
        restoreHitbox(p)
    end
    origHitboxes = {}
end

local function updateAllHitboxes()
    if S.HitboxExpander then
        for _, p in ipairs(Players:GetPlayers()) do
            applyHitbox(p)
        end
    else
        restoreAllHitboxes()
    end
end

task.spawn(function()
    while true do
        task.wait(0.7)
        if S.HitboxExpander then
            pcall(updateAllHitboxes)
        end
    end
end)

-- =============================================
-- 3. ESP: TÊN, HP, KHOẢNG CÁCH VÀ TRACERS
-- =============================================
local espFolder = Instance.new("Folder")
espFolder.Name = "EspItems"

local function removeEsp(p)
    local d = espStore[p]
    if not d then return end
    pcall(function() if d.bb then d.bb:Destroy() end end)
    pcall(function() if d.tracer then d.tracer:Remove() end end)
    espStore[p] = nil
end

local function createEsp(p)
    if not isEnemy(p) then return end
    removeEsp(p)

    local _, head = getChar(p)
    if not head then return end

    local data = {}

    -- BillboardGui (Tên + Máu + Khoảng cách)
    local bb = Instance.new("BillboardGui")
    bb.Name = "_E"
    bb.Adornee = head
    bb.Size = UDim2.new(0, 110, 0, 38)
    bb.StudsOffset = Vector3.new(0, 2.4, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 2500

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextColor3 = Color3.fromRGB(255, 65, 65)
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0.25
    lbl.Text = p.Name
    lbl.Parent = bb

    bb.Parent = espFolder
    data.bb = bb
    data.lbl = lbl

    -- Tracer Line (Drawing)
    if hasDrawing then
        local ok, line = pcall(function()
            local l = Drawing.new("Line")
            l.Color = Color3.fromRGB(255, 65, 65)
            l.Thickness = 1.2
            l.Visible = false
            return l
        end)
        if ok and line then
            data.tracer = line
        end
    end

    espStore[p] = data
end

local function clearAllEsp()
    for p in pairs(espStore) do
        removeEsp(p)
    end
end

local function refreshEsp()
    if S.Esp then
        for _, p in ipairs(Players:GetPlayers()) do
            if isEnemy(p) then
                local _, head = getChar(p)
                if head and not espStore[p] then
                    createEsp(p)
                end
            end
        end
    else
        clearAllEsp()
    end
end

task.spawn(function()
    while true do
        task.wait(0.8)
        if S.Esp then
            refreshEsp()
        end
    end
end)

RS.Heartbeat:Connect(function()
    if not S.Esp then return end

    local _, _, _, myHrp = getChar(LP)
    if not myHrp then return end
    local myPos = myHrp.Position
    local cam = workspace.CurrentCamera
    local screenBot = cam and Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)

    for p, d in pairs(espStore) do
        if not p or not p.Parent then
            removeEsp(p)
        else
            local _, head, hum, hrp = getChar(p)
            if head and hum and hum.Health > 0 and hrp then
                if d.bb then
                    d.bb.Adornee = head
                    d.bb.Enabled = true
                    local dist = math.floor((hrp.Position - myPos).Magnitude)
                    local hp = math.floor(hum.Health)
                    d.lbl.Text = string.format("%s\n%d HP  |  %dm", p.Name, hp, dist)
                end

                if d.tracer and cam and screenBot then
                    local sp, onScr = cam:WorldToViewportPoint(hrp.Position)
                    if onScr then
                        d.tracer.From = screenBot
                        d.tracer.To = Vector2.new(sp.X, sp.Y)
                        d.tracer.Visible = true
                    else
                        d.tracer.Visible = false
                    end
                end
            else
                if d.bb then d.bb.Enabled = false end
                if d.tracer then d.tracer.Visible = false end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    removeEsp(p)
    restoreHitbox(p)
end)

-- =============================================
-- 4. NOCLIP: KHÔI PHỤC CANCOLLIDE AN TOÀN
-- =============================================
local function cacheNoclipParts()
    noclipParts = {}
    noclipOriginals = {}
    local char = LP.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            table.insert(noclipParts, part)
            noclipOriginals[part] = part.CanCollide
        end
    end
end

local function restoreNoclip()
    for part, orig in pairs(noclipOriginals) do
        pcall(function() part.CanCollide = orig end)
    end
    noclipParts = {}
    noclipOriginals = {}
end

RS.Stepped:Connect(function()
    if not S.Noclip then return end
    for _, part in ipairs(noclipParts) do
        if part and part.Parent then
            part.CanCollide = false
        end
    end
end)

-- =============================================
-- 5. SPEED + INFINITE JUMP
-- =============================================
RS.Heartbeat:Connect(function()
    if S.Speed and LP.Character then
        local h = LP.Character:FindFirstChild("Humanoid")
        if h then h.WalkSpeed = S.SpeedVal end
    end
end)

UIS.JumpRequest:Connect(function()
    if S.InfJump and LP.Character then
        local h = LP.Character:FindFirstChild("Humanoid")
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- =============================================
-- 6. FIX LAG
-- =============================================
local function applyFixLag()
    for _, obj in ipairs(workspace:GetDescendants()) do
        pcall(function()
            if obj:IsA("BasePart") then
                obj.CastShadow = false
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                obj.Enabled = false
            end
        end)
    end
    for _, fx in ipairs(Lighting:GetChildren()) do
        pcall(function()
            if fx:IsA("PostEffect") or fx:IsA("BlurEffect") or fx:IsA("SunRaysEffect") or fx:IsA("BloomEffect") or fx:IsA("DepthOfFieldEffect") then
                fx.Enabled = false
            end
        end)
    end
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
end

-- =============================================
-- 7. FULLBRIGHT
-- =============================================
local function setFullbright(on)
    if on then
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
    else
        Lighting.Ambient = origLighting.Ambient
        Lighting.Brightness = origLighting.Brightness
        Lighting.ClockTime = origLighting.ClockTime
        Lighting.GlobalShadows = origLighting.GlobalShadows
    end
end

-- =============================================
-- 8. GIAO DIỆN (UI) - THIẾT KẾ HIỆN ĐẠI
-- =============================================
local C = {
    bg       = Color3.fromRGB(12, 12, 18),
    bar      = Color3.fromRGB(18, 18, 25),
    card     = Color3.fromRGB(20, 20, 28),
    border   = Color3.fromRGB(28, 28, 40),
    text     = Color3.fromRGB(190, 190, 200),
    dim      = Color3.fromRGB(75, 75, 90),
    accent   = Color3.fromRGB(210, 65, 50),
    on       = Color3.fromRGB(50, 190, 85),
    off      = Color3.fromRGB(45, 45, 60),
    knob     = Color3.fromRGB(230, 230, 235),
}

local Gui = Instance.new("ScreenGui")
Gui.Name = "_FPSTools"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = guiParent
espFolder.Parent = Gui

-- Vòng tròn FOV Circle (GUI thuần, hoạt động 100% trên cả Mobile và PC)
local FovCircle = Instance.new("Frame")
FovCircle.Name = "FovCircle"
FovCircle.Size = UDim2.new(0, S.AimFov * 2, 0, S.AimFov * 2)
FovCircle.Position = UDim2.new(0.5, -S.AimFov, 0.5, -S.AimFov)
FovCircle.BackgroundTransparency = 1
FovCircle.Visible = false
FovCircle.Parent = Gui

Instance.new("UICorner", FovCircle).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke", FovCircle)
fovStroke.Thickness = 1.2
fovStroke.Color = Color3.fromRGB(255, 255, 255)
fovStroke.Transparency = 0.5

-- Nút nổi mở menu (Draggable)
local Tog = Instance.new("TextButton")
Tog.Size = UDim2.new(0, 38, 0, 38)
Tog.Position = UDim2.new(0, 12, 0.3, 0)
Tog.BackgroundColor3 = C.bg
Tog.Text = "+"
Tog.Font = Enum.Font.GothamBold
Tog.TextSize = 20
Tog.TextColor3 = C.accent
Tog.AutoButtonColor = false
Tog.Parent = Gui
Instance.new("UICorner", Tog).CornerRadius = UDim.new(1, 0)
local ts = Instance.new("UIStroke", Tog)
ts.Thickness = 1.5
ts.Color = C.border

local dragT = false
local dragST, dragPT
Tog.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragT = true
        dragST = i.Position
        dragPT = Tog.Position
        i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragT = false end end)
    end
end)
UIS.InputChanged:Connect(function(i)
    if dragT and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragST
        Tog.Position = UDim2.new(dragPT.X.Scale, dragPT.X.Offset + d.X, dragPT.Y.Scale, dragPT.Y.Offset + d.Y)
    end
end)

-- Khung menu chính
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 255, 0, 0)
Main.Position = UDim2.new(0.5, -127, 0.5, -170)
Main.BackgroundColor3 = C.bg
Main.BorderSizePixel = 0
Main.Active = true
Main.Visible = false
Main.ClipsDescendants = true
Main.Parent = Gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)
local ms = Instance.new("UIStroke", Main)
ms.Thickness = 1
ms.Color = C.border

-- Kéo thả Main
local dragM, dragSM, dragPM = false, nil, nil
Main.InputBegan:Connect(function(i)
    if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) and i.Position.Y < Main.AbsolutePosition.Y + 32 then
        dragM = true
        dragSM = i.Position
        dragPM = Main.Position
        i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragM = false end end)
    end
end)
UIS.InputChanged:Connect(function(i)
    if dragM and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragSM
        Main.Position = UDim2.new(dragPM.X.Scale, dragPM.X.Offset + d.X, dragPM.Y.Scale, dragPM.Y.Offset + d.Y)
    end
end)

-- Thanh tiêu đề
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 32)
TopBar.BackgroundColor3 = C.bar
TopBar.BorderSizePixel = 0
TopBar.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -38, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "FPS Tools v3"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextColor3 = C.accent
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local XBtn = Instance.new("TextButton")
XBtn.Size = UDim2.new(0, 28, 0, 28)
XBtn.Position = UDim2.new(1, -30, 0, 2)
XBtn.BackgroundTransparency = 1
XBtn.Text = "x"
XBtn.Font = Enum.Font.GothamBold
XBtn.TextSize = 14
XBtn.TextColor3 = C.dim
XBtn.Parent = TopBar
XBtn.MouseButton1Click:Connect(function() Main.Visible = false end)

Tog.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
end)

-- Nội dung cuộn
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -10, 1, -38)
Scroll.Position = UDim2.new(0, 5, 0, 35)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 2
Scroll.ScrollBarImageColor3 = C.dim
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.Parent = Main

local List = Instance.new("UIListLayout")
List.Padding = UDim.new(0, 4)
List.SortOrder = Enum.SortOrder.LayoutOrder
List.Parent = Scroll

local Pad = Instance.new("UIPadding")
Pad.PaddingTop = UDim.new(0, 2)
Pad.PaddingBottom = UDim.new(0, 8)
Pad.Parent = Scroll

List:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local h = List.AbsoluteContentSize.Y + 48
    Main.Size = UDim2.new(0, 255, 0, math.min(h, 400))
end)

-- Helper tạo section header
local order = 0
local function addSection(text)
    order = order + 1
    local h = Instance.new("TextLabel")
    h.Name = "S" .. order
    h.LayoutOrder = order
    h.Size = UDim2.new(1, 0, 0, 20)
    h.BackgroundTransparency = 1
    h.Text = string.upper(text)
    h.Font = Enum.Font.GothamBold
    h.TextSize = 9
    h.TextColor3 = C.dim
    h.TextXAlignment = Enum.TextXAlignment.Left
    h.Parent = Scroll
    return h
end

-- Helper tạo toggle switch
local function addToggle(text, default, callback)
    order = order + 1

    local row = Instance.new("Frame")
    row.Name = "T" .. order
    row.LayoutOrder = order
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundColor3 = C.card
    row.BorderSizePixel = 0
    row.Parent = Scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 32, 0, 16)
    track.Position = UDim2.new(1, -40, 0.5, -8)
    track.BackgroundColor3 = default and C.on or C.off
    track.BorderSizePixel = 0
    track.Parent = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = default and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    knob.BackgroundColor3 = C.knob
    knob.BorderSizePixel = 0
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = default
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row

    btn.MouseButton1Click:Connect(function()
        state = not state
        TS:Create(track, TweenInfo.new(0.15), {
            BackgroundColor3 = state and C.on or C.off
        }):Play()
        TS:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Position = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        }):Play()
        pcall(callback, state)
    end)

    return row
end

-- Tâm ảo Crosshair
local Cross = Instance.new("Frame")
Cross.Name = "XH"
Cross.Size = UDim2.new(0, 18, 0, 18)
Cross.Position = UDim2.new(0.5, -9, 0.5, -9)
Cross.BackgroundTransparency = 1
Cross.Visible = false
Cross.Parent = Gui

local dot = Instance.new("Frame", Cross)
dot.Size = UDim2.new(0, 3, 0, 3)
dot.Position = UDim2.new(0.5, -1, 0.5, -1)
dot.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
dot.BorderSizePixel = 0
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

for _, v in ipairs({{8,1.5,-11,-0.5},{8,1.5,3,-0.5},{1.5,8,-0.5,-11},{1.5,8,-0.5,3}}) do
    local l = Instance.new("Frame", Cross)
    l.Size = UDim2.new(0, v[1], 0, v[2])
    l.Position = UDim2.new(0.5, v[3], 0.5, v[4])
    l.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
    l.BorderSizePixel = 0
end

-- =============================================
-- THÊM CÁC NÚT ĐIỀU KHIỂN
-- =============================================
addSection("combat")

addToggle("Smart Aimbot", false, function(v)
    S.Aimbot = v
end)

addToggle("Hitbox Expander", false, function(v)
    S.HitboxExpander = v
    updateAllHitboxes()
end)

addToggle("Wall Check", true, function(v)
    S.WallCheck = v
end)

addToggle("Show FOV", false, function(v)
    S.ShowFov = v
    FovCircle.Visible = v
end)

addSection("visual")

addToggle("ESP", false, function(v)
    S.Esp = v
    if v then
        espFolder.Parent = Gui
        refreshEsp()
    else
        clearAllEsp()
    end
end)

addToggle("Fullbright", false, function(v)
    S.Fullbright = v
    setFullbright(v)
end)

addToggle("Crosshair", false, function(v)
    S.Crosshair = v
    Cross.Visible = v
end)

addSection("movement")

addToggle("Noclip", false, function(v)
    S.Noclip = v
    if v then
        cacheNoclipParts()
    else
        restoreNoclip()
    end
end)

addToggle("Speed", false, function(v)
    S.Speed = v
    if not v and LP.Character then
        local h = LP.Character:FindFirstChild("Humanoid")
        if h then h.WalkSpeed = 16 end
    end
end)

addToggle("Infinite Jump", false, function(v)
    S.InfJump = v
end)

addSection("other")

addToggle("Fix Lag", false, function(v)
    S.FixLag = v
    if v then applyFixLag() end
end)

addToggle("Team Check", true, function(v)
    S.TeamCheck = v
    if S.Esp then clearAllEsp(); refreshEsp() end
    if S.HitboxExpander then updateAllHitboxes() end
end)

-- =============================================
-- RESPAWN & CLEANUP
-- =============================================
LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if S.Noclip then cacheNoclipParts() end
end)

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        if S.Esp then createEsp(p) end
        if S.HitboxExpander then pcall(updateAllHitboxes) end
    end)
end)

if typeof(getgenv) == "function" then
    getgenv()._FPSClean = function()
        clearAllEsp()
        restoreAllHitboxes()
        restoreNoclip()
        pcall(function() Gui:Destroy() end)
    end
end

print("[FPS Tools v3] Sẵn sàng! Smart Aimbot & Hitbox Expander đã kích hoạt.")
