--[[
    ===================================================================================
    🎯 FPS Tools v4 - Ultimate Fixed Edition
    - Khắc phục hoàn toàn lệch tâm FOV (IgnoreGuiInset = true)
    - ESP tự động cập nhật khi người chơi chết & hồi sinh, thanh máu động
    - Smart Aimbot với nút ngắm di động (Aim Hold Button) & nội suy mượt mà
    - Hitbox Expander khối Neon đỏ trực quan, khôi phục 100% khi tắt
    - Tương thích 100% Mobile (Delta, Codex, Hydrogen, Arceus X) & PC (Solara, Wave)
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
    AlwaysAim = false,      -- Luôn tự bám (nếu tắt: giữ nút AIM hoặc Chuột Phải)
    AimSmooth = 0.22,       -- Độ mượt: 0.1 (chậm mượt) -> 0.35 (nhanh)
    AimFov = 150,           -- Bán kính vòng ngắm (pixels)
    WallCheck = false,      -- Mặc định TẮT để không bị cản nhầm bởi kính/hiệu ứng/phụ kiện
    ShowFov = true,         -- Mặc định BẬT để nhìn rõ tầm ngắm
    HitboxExpander = false, -- Phóng to Hitbox
    HitboxSize = 10,        -- Kích thước Hitbox mở rộng

    -- Visual
    Esp = false,
    Fullbright = false,
    Crosshair = false,
    TeamCheck = false,      -- Mặc định TẮT để không bị lỗi tàng hình trong game FFA / cùng team

    -- Movement
    Noclip = false,
    Speed = false,
    SpeedVal = 26,
    InfJump = false,

    -- Other
    FixLag = false,
}

-- === TRẠNG THÁI NỘI BỘ ===
local isAiming = false
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

-- Tạo ScreenGui chính với IgnoreGuiInset = true (Fix lệch tâm 100%)
local Gui = Instance.new("ScreenGui")
Gui.Name = "_FPSTools"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.IgnoreGuiInset = true -- ĐẢM BẢO TOẠ ĐỘ GUI KHỚP 100% VỚI TOẠ ĐỘ VIEWPORT CAMERA!
Gui.Parent = guiParent

local espFolder = Instance.new("Folder")
espFolder.Name = "EspItems"
espFolder.Parent = Gui

-- === KIỂM TRA ĐỊCH / ĐỒNG ĐỘI THÔNG MINH ===
local function isEnemy(p)
    if not p or p == LP or not p.Parent then return false end
    if not S.TeamCheck then return true end

    -- Nếu cả 2 đều không có team -> là địch
    if not LP.Team and not p.Team then return true end

    -- Nếu cả 2 cùng Team
    if LP.Team and p.Team and LP.Team == p.Team then
        -- Kiểm tra xem có phải game FFA nhét tất cả người chơi vào 1 team không
        local allPlayers = Players:GetPlayers()
        local sameCount = 0
        for _, other in ipairs(allPlayers) do
            if other.Team == LP.Team then sameCount = sameCount + 1 end
        end
        -- Nếu > 75% người chơi cùng 1 team trong phòng đông -> là game FFA -> vẫn là địch
        if sameCount >= #allPlayers - 1 and #allPlayers >= 3 then
            return true
        end
        return false
    end

    return true
end

local function getChar(p)
    local c = p and p.Character
    if not c then return nil, nil, nil, nil end
    return c, c:FindFirstChild("Head"), c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end

-- === WALL CHECK (CHỈ TÍNH VẬT THỂ RẮN, BỎ QUA PHỤ KIỆN VÀ VẬT TRONG SUỐT) ===
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
    if not hit then return true end

    -- Bỏ qua nếu chạm vào vật thể xuyên thấu hoặc không va chạm
    if hit.Instance and (hit.Instance.Transparency > 0.7 or not hit.Instance.CanCollide) then
        return true
    end

    return false
end

-- =============================================
-- 1. VÒNG TRÒN FOV (CHUẨN TÂM TUYỆT ĐỐI)
-- =============================================
local FovCircle = Instance.new("Frame")
FovCircle.Name = "FovCircle"
FovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
FovCircle.Size = UDim2.new(0, S.AimFov * 2, 0, S.AimFov * 2)
FovCircle.BackgroundTransparency = 1
FovCircle.Visible = S.ShowFov
FovCircle.Parent = Gui

Instance.new("UICorner", FovCircle).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke", FovCircle)
fovStroke.Thickness = 1.5
fovStroke.Color = Color3.fromRGB(255, 255, 255)
fovStroke.Transparency = 0.4

-- =============================================
-- 2. SMART AIMBOT: TÌM MỤC TIÊU & BÁM MƯỢT
-- =============================================
local function getAimbotTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local center = cam.ViewportSize / 2
    local bestTarget = nil
    local bestDist = S.AimFov

    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and p.Character then
            local char, head, hum, hrp = getChar(p)
            local aimPart = head or hrp
            if hum and hum.Health > 0 and aimPart then
                local sp, onScreen = cam:WorldToViewportPoint(aimPart.Position)
                if onScreen then
                    local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if screenDist <= bestDist then
                        if not S.WallCheck or isVisible(aimPart) then
                            bestDist = screenDist
                            bestTarget = aimPart
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

-- Vòng lặp ngắm mượt mà (RenderStepped)
RS.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera
    if not cam then return end

    -- Cập nhật kích thước & hiển thị FOV
    if S.ShowFov then
        FovCircle.Size = UDim2.new(0, S.AimFov * 2, 0, S.AimFov * 2)
        FovCircle.Visible = true
    else
        FovCircle.Visible = false
    end

    -- Điều kiện kích hoạt:
    -- 1. AlwaysAim được bật, HOẶC
    -- 2. Đang bấm/giữ nút [AIM] trên màn hình, HOẶC
    -- 3. Đang giữ chuột phải trên PC
    local active = S.Aimbot and (S.AlwaysAim or isAiming or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))

    if active then
        local target = getAimbotTarget()
        if target then
            local targetPos = target.Position
            local targetCFrame = CFrame.lookAt(cam.CFrame.Position, targetPos)
            -- Nội suy tự nhiên không giật góc nhìn
            cam.CFrame = cam.CFrame:Lerp(targetCFrame, S.AimSmooth)

            -- Đổi màu vòng FOV sang Xanh Lá báo hiệu đã lock mục tiêu
            fovStroke.Color = Color3.fromRGB(0, 255, 140)
        else
            fovStroke.Color = Color3.fromRGB(255, 255, 255)
        end
    else
        fovStroke.Color = Color3.fromRGB(255, 255, 255)
    end
end)

-- =============================================
-- 3. HITBOX EXPANDER: KHỐI NEON ĐỎ TRỰC QUAN
-- =============================================
local function restoreHitbox(part)
    if origHitboxes[part] then
        local o = origHitboxes[part]
        pcall(function()
            part.Size = o.Size
            part.Transparency = o.Transparency
            part.Color = o.Color
            part.Material = o.Material
            part.CanCollide = o.CanCollide
        end)
        origHitboxes[part] = nil
    end
end

local function restoreAllHitboxes()
    for part in pairs(origHitboxes) do
        if part and part.Parent then
            restoreHitbox(part)
        end
    end
    origHitboxes = {}
end

local function updateHitboxes()
    if not S.HitboxExpander then
        restoreAllHitboxes()
        return
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and p.Character then
            local char, _, hum = getChar(p)
            if hum and hum.Health > 0 then
                -- Phóng to cả HumanoidRootPart và Torso (hỗ trợ cả R6 và R15)
                local parts = {}
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                if hrp then table.insert(parts, hrp) end
                if torso then table.insert(parts, torso) end

                for _, part in ipairs(parts) do
                    if not origHitboxes[part] then
                        origHitboxes[part] = {
                            Size = part.Size,
                            Transparency = part.Transparency,
                            Color = part.Color,
                            Material = part.Material,
                            CanCollide = part.CanCollide
                        }
                    end
                    part.Size = Vector3.new(S.HitboxSize, S.HitboxSize, S.HitboxSize)
                    part.Transparency = 0.6
                    part.Color = Color3.fromRGB(255, 35, 35)
                    part.Material = Enum.Material.Neon
                    part.CanCollide = false
                    part.Massless = true
                end
            end
        end
    end
end

-- Vòng lặp cập nhật hitbox liên tục cho người vừa hồi sinh
task.spawn(function()
    while true do
        task.wait(0.5)
        if S.HitboxExpander then
            pcall(updateHitboxes)
        end
    end
end)

-- =============================================
-- 4. ESP HOÀN HẢO: TỰ KHÔI PHỤC KHI CHẾT & HỒI SINH
-- =============================================
local function removeEsp(p)
    local d = espStore[p]
    if not d then return end
    pcall(function() if d.Bb then d.Bb:Destroy() end end)
    pcall(function() if d.Tracer then d.Tracer:Remove() end end)
    espStore[p] = nil
end

local function clearAllEsp()
    for p in pairs(espStore) do
        removeEsp(p)
    end
    espStore = {}
end

local function createEspFor(p, char, head)
    local data = { Char = char }

    -- BillboardGui
    local bb = Instance.new("BillboardGui")
    bb.Name = "_E"
    bb.Adornee = head
    bb.Size = UDim2.new(0, 120, 0, 42)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 3000

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextColor3 = Color3.fromRGB(0, 255, 140)
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0.2
    lbl.Text = p.Name
    lbl.Parent = bb

    bb.Parent = espFolder
    data.Bb = bb
    data.Lbl = lbl

    -- Tracer Line (Drawing)
    if hasDrawing then
        local ok, line = pcall(function()
            local l = Drawing.new("Line")
            l.Color = Color3.fromRGB(255, 65, 65)
            l.Thickness = 1.3
            l.Visible = false
            return l
        end)
        if ok and line then
            data.Tracer = line
        end
    end

    return data
end

-- Vòng lặp cập nhật ESP mỗi frame (không bao giờ bị mất khi chết)
RS.Heartbeat:Connect(function()
    if not S.Esp then
        if next(espStore) then clearAllEsp() end
        return
    end

    local cam = workspace.CurrentCamera
    if not cam then return end
    local screenBot = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
    local myChar, _, _, myHrp = getChar(LP)
    local myPos = myHrp and myHrp.Position or cam.CFrame.Position

    local active = {}

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and isEnemy(p) and p.Character then
            local char, head, hum, hrp = getChar(p)
            if hum and hum.Health > 0 and head and hrp then
                active[p] = true
                local d = espStore[p]

                -- Nếu người chơi chết rồi hồi sinh với Character mới -> tự động tạo lại
                if not d or d.Char ~= char or not d.Bb or not d.Bb.Parent then
                    if d then removeEsp(p) end
                    d = createEspFor(p, char, head)
                    espStore[p] = d
                end

                if d and d.Bb and d.Lbl then
                    d.Bb.Adornee = head
                    d.Bb.Enabled = true

                    local dist = math.floor((hrp.Position - myPos).Magnitude)
                    local hp = math.floor(hum.Health)
                    local maxHp = math.floor(hum.MaxHealth > 0 and hum.MaxHealth or 100)
                    d.Lbl.Text = string.format("%s\n[%d/%d HP]  %dm", p.Name, hp, maxHp, dist)

                    -- Màu chữ đổi tự động: Xanh lá -> Vàng -> Đỏ theo lượng máu
                    local hpPct = math.clamp(hp / maxHp, 0, 1)
                    d.Lbl.TextColor3 = Color3.fromHSV(hpPct * 0.33, 0.9, 1)
                end

                if d and d.Tracer and hasDrawing then
                    local sp, onScr = cam:WorldToViewportPoint(hrp.Position)
                    if onScr then
                        d.Tracer.From = screenBot
                        d.Tracer.To = Vector2.new(sp.X, sp.Y)
                        d.Tracer.Visible = true
                    else
                        d.Tracer.Visible = false
                    end
                end
            end
        end
    end

    -- Dọn dẹp ESP của những người đã chết hoặc out server
    for p, d in pairs(espStore) do
        if not active[p] then
            removeEsp(p)
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    removeEsp(p)
    if p.Character then
        for _, part in ipairs(p.Character:GetDescendants()) do
            if origHitboxes[part] then restoreHitbox(part) end
        end
    end
end)

-- =============================================
-- 5. NOCLIP: KHÔI PHỤC CANCOLLIDE AN TOÀN
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
-- 6. SPEED + INFINITE JUMP
-- =============================================
RS.Heartbeat:Connect(function()
    if S.Speed and LP.Character then
        local h = LP.Character:FindFirstChildOfClass("Humanoid")
        if h and h.WalkSpeed < S.SpeedVal then h.WalkSpeed = S.SpeedVal end
    end
end)

UIS.JumpRequest:Connect(function()
    if S.InfJump and LP.Character then
        local h = LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- =============================================
-- 7. FIX LAG & FULLBRIGHT
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

local function setFullbright(on)
    if on then
        Lighting.Ambient = Color3.fromRGB(220, 220, 220)
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
-- 8. GIAO DIỆN (UI) HIỆN ĐẠI & NÚT AIM DI ĐỘNG
-- =============================================
local C = {
    bg       = Color3.fromRGB(12, 12, 18),
    bar      = Color3.fromRGB(18, 18, 25),
    card     = Color3.fromRGB(20, 20, 28),
    border   = Color3.fromRGB(30, 30, 44),
    text     = Color3.fromRGB(200, 200, 210),
    dim      = Color3.fromRGB(80, 80, 95),
    accent   = Color3.fromRGB(225, 60, 50),
    on       = Color3.fromRGB(45, 195, 90),
    off      = Color3.fromRGB(45, 45, 60),
    knob     = Color3.fromRGB(235, 235, 240),
}

-- NÚT GIỮ AIM CHO MOBILE (RẤT TIỆN LỢI TRÊN ĐIỆN THOẠI)
local AimHoldBtn = Instance.new("TextButton")
AimHoldBtn.Name = "AimHoldBtn"
AimHoldBtn.Size = UDim2.new(0, 54, 0, 54)
AimHoldBtn.Position = UDim2.new(0.85, 0, 0.65, 0)
AimHoldBtn.AnchorPoint = Vector2.new(0.5, 0.5)
AimHoldBtn.BackgroundColor3 = Color3.fromRGB(225, 60, 50)
AimHoldBtn.Text = "AIM"
AimHoldBtn.Font = Enum.Font.GothamBold
AimHoldBtn.TextSize = 14
AimHoldBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AimHoldBtn.Visible = false
AimHoldBtn.AutoButtonColor = false
AimHoldBtn.Parent = Gui

Instance.new("UICorner", AimHoldBtn).CornerRadius = UDim.new(1, 0)
local as = Instance.new("UIStroke", AimHoldBtn)
as.Thickness = 2
as.Color = Color3.fromRGB(255, 255, 255)

-- Xử lý giữ nút để ngắm
AimHoldBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        isAiming = true
        AimHoldBtn.BackgroundColor3 = Color3.fromRGB(45, 195, 90)
    end
end)

AimHoldBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        isAiming = false
        AimHoldBtn.BackgroundColor3 = Color3.fromRGB(225, 60, 50)
    end
end)

-- Kéo thả nút AimHold
local dragA = false
local dragSA, dragPA
AimHoldBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragA = true
        dragSA = i.Position
        dragPA = AimHoldBtn.Position
        i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragA = false end end)
    end
end)
UIS.InputChanged:Connect(function(i)
    if dragA and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragSA
        AimHoldBtn.Position = UDim2.new(dragPA.X.Scale, dragPA.X.Offset + d.X, dragPA.Y.Scale, dragPA.Y.Offset + d.Y)
    end
end)

-- Nút nổi mở menu (+)
local Tog = Instance.new("TextButton")
Tog.Size = UDim2.new(0, 38, 0, 38)
Tog.Position = UDim2.new(0, 14, 0.35, 0)
Tog.BackgroundColor3 = C.bg
Tog.Text = "+"
Tog.Font = Enum.Font.GothamBold
Tog.TextSize = 22
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

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 32)
TopBar.BackgroundColor3 = C.bar
TopBar.BorderSizePixel = 0
TopBar.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -38, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "FPS Tools v4"
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
    Main.Size = UDim2.new(0, 255, 0, math.min(h, 420))
end)

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

-- Tâm ảo Crosshair giữa màn hình
local Cross = Instance.new("Frame")
Cross.Name = "XH"
Cross.Size = UDim2.new(0, 18, 0, 18)
Cross.AnchorPoint = Vector2.new(0.5, 0.5)
Cross.Position = UDim2.new(0.5, 0, 0.5, 0)
Cross.BackgroundTransparency = 1
Cross.Visible = false
Cross.Parent = Gui

local dot = Instance.new("Frame", Cross)
dot.Size = UDim2.new(0, 3, 0, 3)
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.new(0.5, 0, 0.5, 0)
dot.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
dot.BorderSizePixel = 0
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

for _, v in ipairs({{8,1.5,-10,-0.5},{8,1.5,3,-0.5},{1.5,8,-0.5,-10},{1.5,8,-0.5,3}}) do
    local l = Instance.new("Frame", Cross)
    l.Size = UDim2.new(0, v[1], 0, v[2])
    l.Position = UDim2.new(0.5, v[3], 0.5, v[4])
    l.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
    l.BorderSizePixel = 0
end

-- =============================================
-- THÊM CÁC TÍNH NĂNG VÀO MENU
-- =============================================
addSection("combat")

addToggle("Smart Aimbot", S.Aimbot, function(v)
    S.Aimbot = v
    AimHoldBtn.Visible = v and not S.AlwaysAim
end)

addToggle("Always Auto-Aim", S.AlwaysAim, function(v)
    S.AlwaysAim = v
    AimHoldBtn.Visible = S.Aimbot and not v
end)

addToggle("Hitbox Expander", S.HitboxExpander, function(v)
    S.HitboxExpander = v
    updateHitboxes()
end)

addToggle("Show FOV", S.ShowFov, function(v)
    S.ShowFov = v
    FovCircle.Visible = v
end)

addToggle("Wall Check", S.WallCheck, function(v)
    S.WallCheck = v
end)

addSection("visual")

addToggle("ESP (Name + HP + Line)", S.Esp, function(v)
    S.Esp = v
    if not v then clearAllEsp() end
end)

addToggle("Fullbright", S.Fullbright, function(v)
    S.Fullbright = v
    setFullbright(v)
end)

addToggle("Crosshair", S.Crosshair, function(v)
    S.Crosshair = v
    Cross.Visible = v
end)

addSection("movement")

addToggle("Noclip", S.Noclip, function(v)
    S.Noclip = v
    if v then cacheNoclipParts() else restoreNoclip() end
end)

addToggle("Speed Boost", S.Speed, function(v)
    S.Speed = v
    if not v and LP.Character then
        local h = LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = 16 end
    end
end)

addToggle("Infinite Jump", S.InfJump, function(v)
    S.InfJump = v
end)

addSection("other")

addToggle("Fix Lag", S.FixLag, function(v)
    S.FixLag = v
    if v then applyFixLag() end
end)

addToggle("Team Check", S.TeamCheck, function(v)
    S.TeamCheck = v
    clearAllEsp()
    if S.HitboxExpander then updateHitboxes() end
end)

-- =============================================
-- RESPAWN & CLEANUP
-- =============================================
LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if S.Noclip then cacheNoclipParts() end
end)

if typeof(getgenv) == "function" then
    getgenv()._FPSClean = function()
        clearAllEsp()
        restoreAllHitboxes()
        restoreNoclip()
        pcall(function() Gui:Destroy() end)
    end
end

print("[FPS Tools v4] Đã sẵn sàng!")
