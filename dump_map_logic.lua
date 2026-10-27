--[[
    ===================================================================================
    ROBLOX FULL MAP LOGIC DUMPER FOR AI (Claude, GPT, Gemini, DeepSeek)
    ===================================================================================
    Mục đích:
      Trích xuất toàn bộ cấu trúc, logic vận hành, luồng mạng (Remotes), mã nguồn (Scripts),
      dữ liệu cấu hình (Module/Values), tương tác thế giới (NPCs, Prompts, Triggers) 
      của game Roblox thành 1 file JSON có cấu trúc tối ưu để AI đọc hiểu toàn bộ bản đồ.

    Tương thích hoàn toàn:
      - Executor Android/iOS: Delta, Codex, Hydrogen, Arceus X, Fluxus, Vega X,...
      - Executor PC: Wave, Solara, Celery, Synapse Z, Macsploit,...
      - Roblox Studio Command Bar / Plugin (có fallback an toàn)
    ===================================================================================
--]]

local Config = {
    -- Tên file xuất ra (Lưu vào thư mục workspace của Executor)
    FileName = string.format("MapLogic_%s_%d.json", tostring(game.PlaceId), os.time()),
    
    -- Decompile mã nguồn của LocalScript và ModuleScript (cần executor hỗ trợ decompile)
    DecompileScripts = true,
    
    -- Giới hạn ký tự tối đa cho 1 script decompiled (tránh file JSON bị phình to quá mức do Roact/Libraries)
    MaxScriptChars = 35000,
    
    -- Tự động require() các ModuleScript trong ReplicatedStorage để lấy dữ liệu config (vũ khí, giá cả, quest, v.v.)
    RequireModules = true,
    
    -- Quét các instance bị ẩn hoặc nằm trong nil (getnilinstances nếu executor hỗ trợ)
    ScanNilInstances = true,
    
    -- Tạm dừng (task.wait) sau mỗi N instance để chống giật lag / crash game trên mobile
    YieldBatchSize = 150,
    
    -- Lọc bớt các Part trang trí vô nghĩa (chỉ giữ lại Part có tương tác, chạm, prompt, hoặc tên logic)
    FilterUselessDecorations = true
}

-- [[ SERVICES ]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Teams = game:GetService("Teams")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer

-- [[ LOGGING & UI NOTIFICATION ]]
local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "Map Logic Dumper",
            Text = text or "",
            Duration = duration or 4
        })
    end)
    print(string.format("[%s] %s", title or "Dumper", text or ""))
end

notify("Map Dumper", "Bắt đầu trích xuất logic game...", 3)

-- [[ KIỂM TRA MÔI TRƯỜNG EXECUTOR ]]
local Env = {
    hasWriteFile = (typeof(writefile) == "function"),
    hasDecompile = (typeof(decompile) == "function"),
    hasGetNil = (typeof(getnilinstances) == "function"),
    hasSetClipboard = (typeof(setclipboard) == "function"),
    executorName = (identifyexecutor and identifyexecutor()) or "Unknown / Studio"
}

-- [[ HÀM LÀM TRÒN SỐ AN TOÀN ]]
local function roundNum(num)
    if type(num) ~= "number" then return 0 end
    if num ~= num then return "NaN" end
    if num == math.huge then return "Infinity" end
    if num == -math.huge then return "-Infinity" end
    return math.floor(num * 100 + 0.5) / 100
end

-- [[ SAFE VALUE SANITIZER FOR JSON ]]
-- Đảm bảo không bị lỗi Cyclic Table, Mixed Array/Dict, NaN, Infinity, CFrame, Vector3, Instance khi JSONEncode
local function sanitizeValue(val, depth, visited)
    depth = depth or 0
    visited = visited or {}

    if depth > 6 then
        return "[Max Depth Reached]"
    end

    local vType = typeof(val)

    if vType == "number" then
        if val ~= val then return "NaN" end
        if val == math.huge then return "Infinity" end
        if val == -math.huge then return "-Infinity" end
        return val
    elseif vType == "string" or vType == "boolean" then
        return val
    elseif vType == "nil" then
        return nil
    elseif vType == "Vector3" then
        return {
            _type = "Vector3",
            x = roundNum(val.X),
            y = roundNum(val.Y),
            z = roundNum(val.Z)
        }
    elseif vType == "CFrame" then
        return {
            _type = "CFrame",
            x = roundNum(val.Position.X),
            y = roundNum(val.Position.Y),
            z = roundNum(val.Position.Z)
        }
    elseif vType == "Color3" then
        return "#" .. val:ToHex()
    elseif vType == "EnumItem" then
        return tostring(val)
    elseif vType == "Instance" then
        return {
            _type = "InstanceRef",
            className = val.ClassName,
            name = val.Name,
            path = val:GetFullName()
        }
    elseif vType == "table" then
        if visited[val] then
            return "[Circular Reference]"
        end
        visited[val] = true

        -- Phân biệt bảng là pure Array hay Dictionary để HttpService:JSONEncode không bị crash "mixed table"
        local isArray = true
        local maxIndex = 0
        local keyCount = 0

        for k, _ in pairs(val) do
            keyCount = keyCount + 1
            if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
                isArray = false
            else
                if k > maxIndex then
                    maxIndex = k
                end
            end
        end

        if isArray and maxIndex ~= keyCount then
            -- Mảng thưa (sparse array), chuyển sang dictionary để an toàn
            isArray = false
        end

        if isArray then
            local cleanArray = {}
            local limit = math.min(keyCount, 300)
            for i = 1, limit do
                table.insert(cleanArray, sanitizeValue(val[i], depth + 1, visited))
            end
            if keyCount > 300 then
                table.insert(cleanArray, string.format("... [Đã cắt bớt %d phần tử]", keyCount - 300))
            end
            visited[val] = nil
            return cleanArray
        else
            local cleanDict = {}
            local count = 0
            for k, v in pairs(val) do
                count = count + 1
                if count > 300 then
                    cleanDict["_truncated"] = "... [Vượt quá 300 phần tử]"
                    break
                end
                cleanDict[tostring(k)] = sanitizeValue(v, depth + 1, visited)
            end
            visited[val] = nil
            return cleanDict
        end
    else
        return tostring(val)
    end
end

-- [[ SAFE SCRIPT SOURCE EXTRACTOR ]]
local function extractScriptSource(scr)
    if not Config.DecompileScripts then
        return "[Decompile Disabled in Config]"
    end

    -- 1. Thử dùng decompile của Executor
    if Env.hasDecompile then
        local success, res = pcall(decompile, scr)
        if success and type(res) == "string" and #res > 0 then
            if #res > Config.MaxScriptChars then
                return string.sub(res, 1, Config.MaxScriptChars) .. "\n\n-- [TRUNCATED: Script quá dài, đã cắt bớt cho AI...]"
            end
            return res
        end
    end

    -- 2. Thử đọc scr.Source trực tiếp (trong Roblox Studio hoặc executor có quyền nâng cao)
    local s, src = pcall(function() return scr.Source end)
    if s and type(src) == "string" and #src > 0 then
        if #src > Config.MaxScriptChars then
            return string.sub(src, 1, Config.MaxScriptChars) .. "\n\n-- [TRUNCATED: Script quá dài...]"
        end
        return src
    end

    return "[Source Unavailable / Decompile Failed]"
end

-- [[ LẤY ATTRIBUTES CỦA INSTANCE ]]
local function getSafeAttributes(inst)
    local success, attrs = pcall(function() return inst:GetAttributes() end)
    if success and type(attrs) == "table" and next(attrs) ~= nil then
        return sanitizeValue(attrs)
    end
    return nil
end

-- [[ KHỞI TẠO CẤU TRÚC JSON DUMP CHO AI ]]
local DumpData = {
    _metadata = {
        tool = "Roblox Full Map Logic Dumper (AI Ready)",
        version = "2.5",
        dump_time = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        place_id = game.PlaceId,
        game_id = game.GameId,
        place_version = game.PlaceVersion,
        job_id = game.JobId,
        executor = Env.executorName,
        player_name = LocalPlayer and LocalPlayer.Name or "Unknown",
        player_user_id = LocalPlayer and LocalPlayer.UserId or 0
    },
    _how_ai_should_read_this = {
        instruction = "Đây là file JSON trích xuất toàn bộ logic vận hành của một map game Roblox. AI hãy phân tích theo các bước:",
        step_1 = "Xem 'ai_summary' để nắm thể loại game và thống kê tổng quan.",
        step_2 = "Phân tích 'network_remotes' để hiểu các kênh giao tiếp Client-Server (mua đồ, đánh quái, giao dịch, v.v.).",
        step_3 = "Đọc 'configurations_and_modules' để nắm dữ liệu cấu hình kinh tế, chỉ số vũ khí, nhiệm vụ, gacha.",
        step_4 = "Đọc 'scripts_logic' để nắm chi tiết logic mã nguồn của Client Controllers và Handlers.",
        step_5 = "Xem 'interactive_world' để biết các vị trí NPC, ProximityPrompt, Trigger chạm, Spawn."
    },
    ai_summary = {
        overview = "Bản đồ dữ liệu logic toàn diện để AI hiểu cơ chế vận hành, network, hệ thống tương tác và mã nguồn.",
        total_remotes = 0,
        total_scripts = 0,
        total_modules = 0,
        total_interactive_objects = 0,
        detected_features = {}
    },
    game_environment = {
        lighting = {},
        teams = {}
    },
    network_remotes = {},
    scripts_logic = {},
    configurations_and_modules = {},
    interactive_world = {
        proximity_prompts = {},
        click_detectors = {},
        npcs_and_entities = {},
        spawners_and_checkpoints = {},
        touch_zones_and_triggers = {}
    },
    ui_systems = {},
    collection_tags = {},
    game_state_and_values = {}
}

-- 1. THÔNG TIN MÔI TRƯỜNG & LIGHTING & TEAMS
pcall(function()
    DumpData.game_environment.lighting = {
        clock_time = Lighting.ClockTime,
        ambient = tostring(Lighting.Ambient),
        brightness = Lighting.Brightness,
        fog_end = Lighting.FogEnd,
        global_shadows = Lighting.GlobalShadows
    }
    for _, team in ipairs(Teams:GetTeams()) do
        table.insert(DumpData.game_environment.teams, {
            name = team.Name,
            team_color = tostring(team.TeamColor),
            auto_assignable = team.AutoAssignable
        })
    end
end)

-- 2. QUÉT COLLECTION SERVICE (TAGS)
pcall(function()
    local tags = CollectionService:GetAllTags()
    for _, tag in ipairs(tags) do
        local taggedInstances = CollectionService:GetTagged(tag)
        local paths = {}
        for idx, inst in ipairs(taggedInstances) do
            if idx > 30 then
                table.insert(paths, string.format("... và %d instance khác", #taggedInstances - 30))
                break
            end
            table.insert(paths, inst:GetFullName())
        end
        DumpData.collection_tags[tag] = {
            count = #taggedInstances,
            sample_instances = paths
        }
    end
end)

-- 3. HÀM QUÉT INSTANCES ĐỆ QUY CÓ LỌC LOGIC
local processedCount = 0

local function processInstance(inst)
    processedCount = processedCount + 1
    if processedCount % Config.YieldBatchSize == 0 then
        task.wait()
    end

    local cName = inst.ClassName
    local path = inst:GetFullName()
    local attrs = getSafeAttributes(inst)

    -- A. QUÉT REMOTES & NETWORK CHANNELS
    if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") or inst:IsA("BindableEvent") or inst:IsA("BindableFunction") then
        DumpData.ai_summary.total_remotes = DumpData.ai_summary.total_remotes + 1
        
        -- Kiểm tra các giá trị con làm mẫu argument
        local childValues = {}
        for _, child in ipairs(inst:GetChildren()) do
            if child:IsA("ValueBase") then
                childValues[child.Name] = {
                    type = child.ClassName,
                    value = sanitizeValue(child.Value)
                }
            end
        end

        table.insert(DumpData.network_remotes, {
            type = cName,
            name = inst.Name,
            path = path,
            parent_service = string.split(path, ".")[2] or "Unknown",
            attributes = attrs,
            argument_templates = next(childValues) and childValues or nil
        })
        return
    end

    -- B. QUÉT SCRIPTS (LocalScript & ModuleScript)
    if inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
        if inst:IsA("ModuleScript") then
            DumpData.ai_summary.total_modules = DumpData.ai_summary.total_modules + 1
            
            -- Thử require Module để lấy data table cấu hình (vũ khí, shop, quest, chỉ số)
            local moduleData = nil
            if Config.RequireModules and (inst:IsDescendantOf(ReplicatedStorage) or inst:IsDescendantOf(StarterPlayer)) then
                local reqSuccess, reqRes = pcall(require, inst)
                if reqSuccess and type(reqRes) == "table" then
                    moduleData = sanitizeValue(reqRes)
                end
            end

            table.insert(DumpData.configurations_and_modules, {
                name = inst.Name,
                path = path,
                attributes = attrs,
                required_data_table = moduleData,
                source = extractScriptSource(inst)
            })
        else
            DumpData.ai_summary.total_scripts = DumpData.ai_summary.total_scripts + 1
            table.insert(DumpData.scripts_logic, {
                type = cName,
                name = inst.Name,
                path = path,
                enabled = inst.Enabled,
                attributes = attrs,
                source = extractScriptSource(inst)
            })
        end
        return
    end

    -- C. QUÉT THẾ GIỚI TƯƠNG TÁC (PROXIMITY PROMPT, CLICK DETECTOR, NPC, ZONES)
    if inst:IsA("ProximityPrompt") then
        DumpData.ai_summary.total_interactive_objects = DumpData.ai_summary.total_interactive_objects + 1
        table.insert(DumpData.interactive_world.proximity_prompts, {
            name = inst.Name,
            parent = inst.Parent and inst.Parent:GetFullName() or "None",
            action_text = inst.ActionText,
            object_text = inst.ObjectText,
            keyboard_key = tostring(inst.KeyboardKeyCode),
            hold_duration = inst.HoldDuration,
            max_distance = inst.MaxActivationDistance,
            requires_line_of_sight = inst.RequiresLineOfSight,
            enabled = inst.Enabled,
            attributes = attrs
        })
        return
    end

    if inst:IsA("ClickDetector") then
        DumpData.ai_summary.total_interactive_objects = DumpData.ai_summary.total_interactive_objects + 1
        table.insert(DumpData.interactive_world.click_detectors, {
            name = inst.Name,
            parent = inst.Parent and inst.Parent:GetFullName() or "None",
            max_distance = inst.MaxActivationDistance,
            attributes = attrs
        })
        return
    end

    if inst:IsA("SpawnLocation") then
        table.insert(DumpData.interactive_world.spawners_and_checkpoints, {
            name = inst.Name,
            path = path,
            team_color = tostring(inst.TeamColor),
            neutral = inst.Neutral,
            enabled = inst.Enabled,
            position = sanitizeValue(inst.Position)
        })
        return
    end

    if inst:IsA("Humanoid") and inst.Parent and inst.Parent:IsA("Model") and inst.Parent ~= (LocalPlayer and LocalPlayer.Character) then
        local model = inst.Parent
        local isPlayerModel = Players:GetPlayerFromCharacter(model) ~= nil
        if not isPlayerModel then
            -- NPC, Quái vật, hoặc Boss
            local tools = {}
            for _, child in ipairs(model:GetChildren()) do
                if child:IsA("Tool") then
                    table.insert(tools, child.Name)
                end
            end

            table.insert(DumpData.interactive_world.npcs_and_entities, {
                model_name = model.Name,
                path = model:GetFullName(),
                health = inst.Health,
                max_health = inst.MaxHealth,
                walk_speed = inst.WalkSpeed,
                tools_equipped = tools,
                attributes = getSafeAttributes(model),
                tags = CollectionService:GetTags(model)
            })
        end
        return
    end

    -- D. QUÉT VALUE OBJECTS & GAME STATE
    if inst:IsA("ValueBase") then
        local isLeaderstats = inst:IsDescendantOf(LocalPlayer and LocalPlayer:FindFirstChild("leaderstats") or inst)
        local isReplicated = inst:IsDescendantOf(ReplicatedStorage)
        
        if isLeaderstats or isReplicated or inst.Parent:IsA("Configuration") or inst.Parent:IsA("Folder") then
            table.insert(DumpData.game_state_and_values, {
                name = inst.Name,
                type = cName,
                path = path,
                value = sanitizeValue(inst.Value)
            })
        end
        return
    end

    -- E. QUÉT UI TƯƠNG TÁC (STARTERGUI / PLAYERGUI)
    if inst:IsA("TextButton") or inst:IsA("ImageButton") or inst:IsA("TextBox") then
        if inst:IsDescendantOf(StarterGui) or (LocalPlayer and inst:IsDescendantOf(LocalPlayer:FindFirstChild("PlayerGui") or inst)) then
            table.insert(DumpData.ui_systems, {
                type = cName,
                name = inst.Name,
                path = path,
                text = (inst:IsA("TextButton") or inst:IsA("TextBox")) and inst.Text or nil,
                visible = inst.Visible,
                attributes = attrs
            })
        end
        return
    end

    -- F. TOUCH TRANSLATOR / HITBOX / KILLZONE
    if inst:IsA("BasePart") and (string.find(string.lower(inst.Name), "kill") or 
       string.find(string.lower(inst.Name), "lava") or 
       string.find(string.lower(inst.Name), "checkpoint") or 
       string.find(string.lower(inst.Name), "zone") or 
       string.find(string.lower(inst.Name), "teleport") or 
       string.find(string.lower(inst.Name), "door") or 
       string.find(string.lower(inst.Name), "shop") or 
       string.find(string.lower(inst.Name), "portal")) then
        
        table.insert(DumpData.interactive_world.touch_zones_and_triggers, {
            name = inst.Name,
            path = path,
            can_touch = inst.CanTouch,
            can_collide = inst.CanCollide,
            position = sanitizeValue(inst.Position),
            size = sanitizeValue(inst.Size),
            attributes = attrs
        })
        return
    end
end

-- [[ BẮT ĐẦU QUÉT CÁC SERVICES TRỌNG TÂM ]]
local servicesToScan = {
    ReplicatedStorage,
    ReplicatedFirst,
    Workspace,
    StarterGui,
    StarterPlayer
}

if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
    table.insert(servicesToScan, LocalPlayer.PlayerGui)
end
if LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts") then
    table.insert(servicesToScan, LocalPlayer.PlayerScripts)
end

notify("Map Dumper", "Đang quét toàn bộ Services...", 3)

for _, service in ipairs(servicesToScan) do
    pcall(function()
        for _, descendant in ipairs(service:GetDescendants()) do
            processInstance(descendant)
        end
    end)
    task.wait()
end

-- Quét Nil Instances nếu có hỗ trợ (thường chứa các Remote hoặc Script ẩn)
if Config.ScanNilInstances and Env.hasGetNil then
    notify("Map Dumper", "Đang quét Nil Instances...", 2)
    pcall(function()
        local nilList = getnilinstances()
        for _, inst in ipairs(nilList) do
            if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("ModuleScript") or inst:IsA("LocalScript") then
                processInstance(inst)
            end
        end
    end)
end

-- [[ TỔNG HỢP VÀ PHÂN LOẠI TÍNH NĂNG (AI INSIGHTS) ]]
pcall(function()
    local detected = {}
    local allNames = ""
    for _, r in ipairs(DumpData.network_remotes) do allNames = allNames .. " " .. r.name end
    for _, s in ipairs(DumpData.scripts_logic) do allNames = allNames .. " " .. s.name end
    for _, m in ipairs(DumpData.configurations_and_modules) do allNames = allNames .. " " .. m.name end
    allNames = string.lower(allNames)

    if string.find(allNames, "inventory") or string.find(allNames, "backpack") or string.find(allNames, "item") then
        table.insert(detected, "Inventory System (Hệ thống túi đồ / vật phẩm)")
    end
    if string.find(allNames, "shop") or string.find(allNames, "buy") or string.find(allNames, "purchase") or string.find(allNames, "store") then
        table.insert(detected, "Shop & Economy System (Hệ thống cửa hàng / kinh tế)")
    end
    if string.find(allNames, "combat") or string.find(allNames, "attack") or string.find(allNames, "skill") or string.find(allNames, "damage") then
        table.insert(detected, "Combat & Skill System (Chiến đấu / Kỹ năng)")
    end
    if string.find(allNames, "quest") or string.find(allNames, "mission") or string.find(allNames, "task") then
        table.insert(detected, "Quest System (Hệ thống nhiệm vụ)")
    end
    if string.find(allNames, "pet") or string.find(allNames, "egg") or string.find(allNames, "hatch") then
        table.insert(detected, "Pet & Gacha System (Hệ thống thú cưng / ấp trứng)")
    end
    if string.find(allNames, "trade") or string.find(allNames, "trading") then
        table.insert(detected, "Trading System (Hệ thống giao dịch)")
    end
    if string.find(allNames, "tycoon") or string.find(allNames, "dropper") or string.find(allNames, "conveyor") then
        table.insert(detected, "Tycoon Mechanics (Hệ thống xây nhà / Tycoon)")
    end
    if string.find(allNames, "leaderstats") or string.find(allNames, "rank") or string.find(allNames, "level") then
        table.insert(detected, "Progression & Leveling (Hệ thống cấp độ / Cày cuốc)")
    end

    DumpData.ai_summary.detected_features = detected
end)

-- [[ ENCODE SANG JSON ]]
notify("Map Dumper", "Đang chuyển đổi cấu trúc sang JSON...", 3)
task.wait(0.2)

local encodeSuccess, jsonResult = pcall(function()
    return HttpService:JSONEncode(DumpData)
end)

if not encodeSuccess then
    warn("Lỗi JSONEncode lần đầu: " .. tostring(jsonResult) .. ". Đang làm sạch triệt để...")
    local deeplyCleaned = sanitizeValue(DumpData)
    encodeSuccess, jsonResult = pcall(function()
        return HttpService:JSONEncode(deeplyCleaned)
    end)
end

-- [[ LƯU FILE HOẶC COPY CLIPBOARD ]]
if encodeSuccess and type(jsonResult) == "string" then
    local fileSizeKb = roundNum(#jsonResult / 1024)
    local saveSuccess = false
    local savedLocation = ""

    -- 1. Lưu qua writefile của Executor
    if Env.hasWriteFile then
        local wOk, wErr = pcall(writefile, Config.FileName, jsonResult)
        if wOk then
            saveSuccess = true
            savedLocation = "Thư mục Workspace của Executor -> " .. Config.FileName
        else
            warn("Lỗi writefile: " .. tostring(wErr))
        end
    end

    -- 2. Nếu không có writefile hoặc lỗi, fallback sang setclipboard
    if not saveSuccess and Env.hasSetClipboard then
        local cOk, cErr = pcall(setclipboard, jsonResult)
        if cOk then
            saveSuccess = true
            savedLocation = "Clipboard (Đã copy toàn bộ JSON vào bộ nhớ tạm)"
        end
    end

    if saveSuccess then
        notify("Thành Công!", string.format("Đã xuất %s KB dữ liệu!\nVị trí: %s", tostring(fileSizeKb), savedLocation), 8)
        print("=================================================================")
        print("DUMP THÀNH CÔNG CHO AI!")
        print("Tên file: " .. Config.FileName)
        print("Kích thước: " .. tostring(fileSizeKb) .. " KB")
        print("Số Remotes bắt được: " .. DumpData.ai_summary.total_remotes)
        print("Số Scripts đã quét: " .. DumpData.ai_summary.total_scripts)
        print("Số Modules/Configs: " .. DumpData.ai_summary.total_modules)
        print("Vị trí lưu: " .. savedLocation)
        print("=================================================================")
    else
        notify("Cảnh báo", "Không thể ghi file tự động (thiếu quyền writefile). Vui lòng kiểm tra console!", 6)
        print("NỘI DUNG JSON DUMP (Copy thủ công nếu cần):")
        print(jsonResult)
    end
else
    notify("Thất Bại", "Lỗi mã hóa JSON: " .. tostring(jsonResult), 6)
    warn("JSON Encode Error:", jsonResult)
end
