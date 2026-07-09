-- Vuuy Private - Animal Hospital auto (Opiumware/Mac)

local BRAND = "Vuuy Private"
local BRAND_SUB = "by vuuy · ah-private"
local GUI_NAME = "VuuyPrivate_UI"

local G = (typeof(getgenv) == "function" and getgenv()) or _G
pcall(function()
    local pg = game:GetService("Players").LocalPlayer.PlayerGui
    for _, child in ipairs(pg:GetChildren()) do
        if child:IsA("ScreenGui") and (child.Name == GUI_NAME or child.Name == "AH_Night100_UI") then
            child:Destroy()
        end
    end
end)
G.VUUY_PRIVATE_AH = true

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local PPS = game:GetService("ProximityPromptService")
local GuiService = game:GetService("GuiService")
local CAS = game:GetService("ContextActionService")

local LP = Players.LocalPlayer
if not LP then LP = Players.PlayerAdded:Wait() end

local hasFirePrompt = typeof(fireproximityprompt) == "function"
local hasFireSignal = typeof(firesignal) == "function"
local hasGetConnections = typeof(getconnections) == "function"

local ON = false
local conns = {}
local remotes = {}
local promptCache = {}
local lastCache = 0
local lastAct = 0
local deskStep = 1
local gfxDone = false
local statusText = "loaded"

local xraySeq = {}
local xrayLastFlash = 0
local xrayPhase = "idle"
local xrayLit = {}
local xrayBtns = {}
local xrayBase = {}
local xrayInRoom = false
local xrayRoomAt = 0
local xrayCollectAt = 0

local roomType = "none"
local roomAt = 0
local heartBusy = false

local cfg = {
    loopDelay = 0.12,
    cacheRefresh = 1.8,
    actionCooldown = 0.22,
    deskRange = 18,
    nearRange = 10,
    interactRange = 14,
    treatRange = 16,
    emergencyRange = 50,
    remoteCooldown = 1.8,
    xraySilence = 2.4,
    xrayClickGap = 0.42,
    heartClickGap = 0.14,
    autoStart = true,
}

local lastRemote = {}

local deskGuiSteps = {
    { "photo", "chup", "chụp", "picture", "snap", "take" },
    { "camera", "cctv", "cam", "monitor", "screen" },
    { "admit", "accept", "register", "stamp", "approve", "cho vao", "cho vào", "tiep nhan", "tiếp nhận", "check in", "checkin" },
    { "shutter", "reject", "deny", "close", "tu choi", "từ chối", "dong", "đóng" },
}

local promptDesk = {
    "check", "greet", "photo", "camera", "cctv", "shutter", "admit", "register",
    "inspect", "window", "patient", "form", "scan", "desk", "reception", "counter",
    "interact", "e", "press", "use", "talk", "view",
    "kiem", "kiểm", "chup", "chụp", "anh", "ảnh", "tiep nhan", "tiếp nhận",
    "quay", "le tan", "lễ tân", "mo cua", "mở cửa", "dong cua", "đóng cửa",
    "man", "màn", "cho vao", "cho vào", "stamp", "benh nhan", "bệnh nhân",
    "ca lam", "ca làm", "thu ky", "thư ký", "tiep", "tiếp",
}

local promptCoffee = { "coffee", "cafe", "chocolate", "drink", "brew", "ca phe", "cà phê", "machine", "nuoc", "nước" }
local promptHeal = { "med", "medicine", "bandage", "heal", "potion", "pill", "ointment", "thuoc", "thuốc", "hoi", "hồi", "chua", "chữa", "bang", "băng", "eat", "use", "drink" }
local promptBuy = { "buy", "shop", "purchase", "store", "vendor", "mua", "cua hang", "cửa hàng" }
local promptEmergency = { "fire", "burn", "extinguish", "faint", "unconscious", "revive", "carry", "rescue", "ritual", "candle", "extinguisher", "bed", "syrup", "maple", "lua", "lửa", "chay", "cháy", "ngat", "ngất", "cuu", "cứu" }

local promptXray = {
    "xray", "x-ray", "xray", "x quang", "x-quang", "quang", "chup x", "chụp x",
    "bone", "scan", "radiation", "sequence", "console", "panel", "button", "operate",
    "may chup", "máy chụp", "room6", "room 6",
}

local promptTreat = {
    "treat", "heal", "med", "medicine", "bandage", "inject", "give", "administer",
    "thuoc", "thuốc", "chua", "chữa", "tiem", "tiêm", "cho thuoc", "cho thuốc",
    "patient", "benh nhan", "bệnh nhân", "use on", "apply", "duong", "đường",
}

local promptDna = {
    "dna", "analy", "analyze", "analysis", "sample", "test", "lab", "sequence",
    "phan tich", "phân tích", "xet nghiem", "xét nghiệm", "lay mau", "lấy mẫu",
    "kiem tra", "kiểm tra", "may phan tich", "máy phân tích",
}

local promptHeart = {
    "heart", "monitor", "ecg", "ekg", "pulse", "vitals", "cardiac",
    "tim", "máy tim", "may tim", "nhip tim", "nhịp tim", "mach tim", "mạch tim",
    "room7", "room 7", "heartgame", "heart rate",
}

local promptSurgery = {
    "surgery", "operate", "operation", "scalpel", "scissor", "stitch", "suture",
    "clamp", "forceps", "tool", "cut", "sew", "begin", "start",
    "phau thuat", "phẫu thuật", "mo", "mổ", "keo", "kéo", "dao", "khau",
    "room8", "room 8", "surgeon",
}

local promptPatientItem = {
    "bandage", "pill", "syringe", "inject", "medicine", "ointment", "cream", "syrup",
    "antibiotic", "painkiller", "vitamin", "tablet", "capsule", "spray", "drop",
    "thuoc", "thuốc", "bang", "băng", "tiem", "tiêm", "kem", "vien", "viên",
    "ong tiem", "ống tiêm", "thuoc bo", "thuốc bôi",
}

local promptBasicRoom = {
    "dna", "medical", "treatment", "room1", "room2", "room3", "room4", "room5",
    "phong dieu tri", "phòng điều trị", "phong 1", "phong 2", "phong 3", "phong 4", "phong 5",
    "canh phai", "cánh phải",
}

local remoteWords = {
    "check", "admit", "register", "patient", "reception", "desk", "front", "nurse",
    "photo", "camera", "cctv", "shutter", "stamp", "secretary", "coffee", "sanity",
    "notify", "deliver", "emergency", "fire", "revive", "carry", "treat", "heal",
    "shift", "work", "job", "dna", "analy", "monitor", "portal", "door",
    "xray", "x-ray", "bone", "scan", "sequence", "color", "heart", "surgery",
    "dna", "analy", "operate", "scalpel", "inject", "medicine", "item", "tool",
}

local function log(msg)
    print("[" .. BRAND .. "]", msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = BRAND, Text = tostring(msg), Duration = 2 })
    end)
end

local function setStatus(t)
    statusText = t
end

local function root()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function hum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function dist(part)
    local r = root()
    if not r or not part or not part:IsA("BasePart") then return math.huge end
    return (r.Position - part.Position).Magnitude
end

local function lower(s)
    return string.lower(tostring(s or ""))
end

local function hasAny(text, words)
    text = lower(text)
    for _, w in ipairs(words) do
        if string.find(text, w, 1, true) then return true end
    end
    return false
end

local function guiLabel(g)
    local parts = { lower(g.Name) }
    if g:IsA("GuiObject") then
        if g:IsA("TextButton") or g:IsA("TextLabel") then
            table.insert(parts, lower(g.Text))
        end
    end
    for _, ch in ipairs(g:GetDescendants()) do
        if ch:IsA("TextLabel") or ch:IsA("TextButton") then
            table.insert(parts, lower(ch.Text))
        end
    end
    return table.concat(parts, "|")
end

local function isGuiShown(g)
    if not g:IsA("GuiObject") then return false end
    if not g.Visible then return false end
    local p = g
    while p do
        if p:IsA("GuiObject") and not p.Visible then return false end
        if p:IsA("ScreenGui") and not p.Enabled then return false end
        p = p.Parent
    end
    return true
end

local function promptPart(p)
    local parent = p.Parent
    if not parent then return nil end
    if parent:IsA("BasePart") then return parent end
    if parent:IsA("Attachment") and parent.Parent and parent.Parent:IsA("BasePart") then
        return parent.Parent
    end
    if parent:IsA("Model") then
        return parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
    end
    return parent:FindFirstChildWhichIsA("BasePart", true)
end

local function promptLabel(p)
    return lower(p.Name) .. "|" .. lower(p.ActionText) .. "|" .. lower(p.ObjectText)
end

local function fireSignal(sig)
    if not sig then return end
    if hasFireSignal then
        pcall(function() firesignal(sig) end)
        return
    end
    if hasGetConnections then
        pcall(function()
            for _, c in ipairs(getconnections(sig)) do
                pcall(function() c:Fire() end)
            end
        end)
    end
end

local function pressE()
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

local function firePrompt(p)
    if not p or not p:IsA("ProximityPrompt") or not p.Enabled or not p.Parent then
        return false
    end

    pcall(function()
        p.RequiresLineOfSight = false
        if p.MaxActivationDistance < 20 then
            p.MaxActivationDistance = 20
        end
    end)

    if hasFirePrompt then
        local ok = pcall(function()
            fireproximityprompt(p, 0)
            local hold = p.HoldDuration or 0
            if hold > 0 then task.wait(hold + 0.03) end
            fireproximityprompt(p, 1)
        end)
        if ok then return true end
    end

    local ok2 = pcall(function()
        p:InputHoldBegin()
        local hold = p.HoldDuration or 0
        if hold > 0 then task.wait(hold + 0.03) else task.wait(0.08) end
        p:InputHoldEnd()
    end)
    if ok2 then return true end

    pressE()
    return true
end

local function scanRemotes()
    remotes = {}
    local roots = { RS }
    for _, name in ipairs({ "Remotes", "Net", "RemoteEvents", "Events", "Packages" }) do
        local f = RS:FindFirstChild(name)
        if f then table.insert(roots, f) end
    end
    for _, tree in ipairs(roots) do
        for _, obj in ipairs(tree:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
                table.insert(remotes, obj)
            end
        end
    end
end

local function tryRemotes(words)
    local now = os.clock()
    for _, r in ipairs(remotes) do
        if hasAny(r.Name, words) then
            if now - (lastRemote[r] or 0) >= cfg.remoteCooldown then
                lastRemote[r] = now
                pcall(function()
                    if r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent") then
                        r:FireServer()
                    elseif r:IsA("RemoteFunction") then
                        r:InvokeServer()
                    end
                end)
                return true
            end
        end
    end
    return false
end

local function refreshPromptCache()
    if os.clock() - lastCache < cfg.cacheRefresh then return end
    lastCache = os.clock()
    promptCache = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled and obj.Parent then
            local part = promptPart(obj)
            if part then
                local d = dist(part)
                table.insert(promptCache, {
                    prompt = obj,
                    part = part,
                    label = promptLabel(obj),
                    dist = d,
                })
            end
        end
    end
    table.sort(promptCache, function(a, b) return a.dist < b.dist end)
end

local function nearestPrompt(maxRange, words)
    refreshPromptCache()
    for _, item in ipairs(promptCache) do
        if item.dist <= maxRange and item.prompt.Parent then
            if not words or hasAny(item.label, words) then
                return item.prompt
            end
        end
    end
    return nil
end

local function fireNearestAny(maxRange)
    refreshPromptCache()
    for _, item in ipairs(promptCache) do
        if item.dist <= maxRange and item.prompt.Parent then
            if firePrompt(item.prompt) then
                return true
            end
        end
    end
    return false
end

local function tryClickDetectors(maxRange)
    local r = root()
    if not r then return false end
    local skipSkull = detectRoom() == "heart"
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") and obj.Parent and obj.Parent:IsA("BasePart") then
            if not (skipSkull and isSkullTarget(obj.Parent)) then
                if dist(obj.Parent) <= maxRange then
                    pcall(function()
                        fireSignal(obj.MouseClick)
                        if fireclickdetector and typeof(fireclickdetector) == "function" then
                            fireclickdetector(obj, 0)
                        end
                    end)
                    return true
                end
            end
        end
    end
    return false
end

local function clickGuiByWords(words)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return false end
    local clicked = false
    local ourGui = pg:FindFirstChild(GUI_NAME)
    for _, g in ipairs(pg:GetDescendants()) do
        if (g:IsA("TextButton") or g:IsA("ImageButton")) and isGuiShown(g) then
            if not (ourGui and g:IsDescendantOf(ourGui)) then
                if hasAny(guiLabel(g), words) then
                    fireSignal(g.MouseButton1Click)
                    fireSignal(g.Activated)
                    clicked = true
                end
            end
        end
    end
    return clicked
end

local function deskGuiCycle()
    local words = deskGuiSteps[deskStep]
    if clickGuiByWords(words) then
        deskStep = deskStep % #deskGuiSteps + 1
        return true
    end
    return false
end

local function colorId(c)
    if c.R > 0.65 and c.G < 0.45 and c.B < 0.45 then return "red" end
    if c.G > 0.45 and c.R < 0.45 and c.B < 0.5 then return "green" end
    if c.R > 0.55 and c.G > 0.55 and c.B < 0.45 then return "yellow" end
    if c.B > 0.35 and c.R < 0.35 and c.G < 0.55 then return "blue" end
    if c.R > 0.65 and c.G > 0.45 and c.B < 0.35 then return "orange" end
    if c.R > 0.55 and c.G < 0.45 and c.B > 0.45 then return "pink" end
    if c.G > 0.45 and c.B > 0.5 and c.R < 0.45 then return "cyan" end
    return nil
end

local function btnBright(c)
    return (c.R + c.G + c.B) / 3
end

local function detectRoom(force)
    if not force and os.clock() - roomAt < 1.0 then return roomType end
    roomAt = os.clock()
    local r = root()
    if not r then
        roomType = "none"
        xrayInRoom = false
        return roomType
    end

    local found = "none"
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local t = lower(obj.Text)
            local part = obj:FindFirstAncestorWhichIsA("BasePart")
            local d = part and dist(part) or math.huge
            if d < 50 then
                if hasAny(t, { "phau thuat", "phẫu thuật", "surgery", "room 8", "room8", "phong mo", "phòng mổ" }) then
                    found = "surgery"
                    break
                elseif hasAny(t, { "tim", "heart", "monitor", "ecg", "máy tim", "may tim", "room 7", "room7", "nhip tim", "nhịp tim" }) then
                    found = "heart"
                    break
                elseif hasAny(t, { "chup x", "chụp x", "x-quang", "x quang", "x-ray", "xray", "chup x quang", "chụp x quang" }) then
                    found = "xray"
                    break
                elseif hasAny(t, { "dna", "phan tich", "phân tích", "xet nghiem", "xét nghiệm", "room 1", "room 2", "room 3", "room 4", "room 5" }) then
                    found = "basic"
                end
            end
        elseif obj:IsA("BasePart") and dist(obj) < 32 then
            local t = lower(obj.Name .. "|" .. obj:GetFullName())
            if hasAny(t, { "surgery", "surgeon", "room8", "scalpel" }) then
                found = "surgery"
                break
            elseif hasAny(t, { "heart", "ecg", "ekg", "heartmonitor", "room7" }) then
                found = "heart"
                break
            elseif hasAny(t, { "xray", "x-ray", "xrayroom", "room6", "x_quang", "xquang" }) then
                found = "xray"
                break
            elseif hasAny(t, { "dna", "analyzer", "basicmed", "room1", "room2", "room3", "room4", "room5" }) then
                found = "basic"
            end
        end
    end

    if found == "none" then
        local colored = 0
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("BasePart") and dist(p) < 18 and colorId(p.Color) then
                colored = colored + 1
                if colored >= 4 then
                    found = "xray"
                    break
                end
            end
        end
    end

    if found == "none" then
        local bedNear = false
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and dist(obj) < 14 then
                local t = lower(obj.Name)
                if hasAny(t, { "bed", "giuong", "giường", "patient", "danalyzer", "machine" }) then
                    bedNear = true
                    break
                end
            end
        end
        if bedNear then found = "basic" end
    end

    if found ~= "xray" then
        xrayBase = {}
    end
    roomType = found
    xrayInRoom = (found == "xray")
    xrayRoomAt = os.clock()
    return found
end

local function isInXrayRoom(force)
    return detectRoom(force) == "xray"
end

local function isInTreatmentRoom()
    return detectRoom() ~= "none"
end

local function isSkullTarget(g)
    if not g then return false end
    local label = guiLabel(g)
    if hasAny(label, { "skull", "death", "danger", "so", "sọ", "dead" }) then return true end
    if g:IsA("GuiObject") then
        local c = g.BackgroundColor3
        if c.R > 0.55 and c.G < 0.28 and c.B < 0.28 then return true end
        if g:IsA("ImageLabel") or g:IsA("ImageButton") then
            local ic = g.ImageColor3
            if ic.R > 0.55 and ic.G < 0.28 and ic.B < 0.28 then return true end
        end
    end
    if g:IsA("BasePart") then
        local c = g.Color
        if c.R > 0.55 and c.G < 0.25 and c.B < 0.25 then return true end
        if hasAny(lower(g.Name), { "skull", "death", "danger" }) then return true end
    end
    return false
end

local function isWhiteHeartTarget(g)
    if g:IsA("BasePart") then
        if isSkullTarget(g) then return false end
        if dist(g) > 22 then return false end
        return btnBright(g.Color) > 0.72
    end
    if not g:IsA("GuiObject") or not isGuiShown(g) then return false end
    if isSkullTarget(g) then return false end
    if not (g:IsA("ImageButton") or g:IsA("TextButton") or g:IsA("ImageLabel")) then return false end
    local bright = btnBright(g.BackgroundColor3)
    if bright > 0.72 and g.BackgroundTransparency < 0.55 then return true end
    if g:IsA("ImageLabel") or g:IsA("ImageButton") then
        if g.ImageTransparency < 0.45 and btnBright(g.ImageColor3) > 0.65 then return true end
    end
    return false
end

local function clickGameGui(words, skipSkull)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return false end
    local ourGui = pg:FindFirstChild(GUI_NAME)
    local best, bestScore = nil, 0
    local pools = { pg:GetDescendants() }
    for _, g in ipairs(workspace:GetDescendants()) do
        if g:IsA("BillboardGui") or g:IsA("SurfaceGui") then
            for _, ch in ipairs(g:GetDescendants()) do
                if ch:IsA("GuiObject") then
                    table.insert(pools[1], ch)
                end
            end
        end
    end
    for _, g in ipairs(pools[1]) do
        if (g:IsA("TextButton") or g:IsA("ImageButton")) and isGuiShown(g) then
            if not (ourGui and g:IsDescendantOf(ourGui)) and not (skipSkull and isSkullTarget(g)) then
                local label = guiLabel(g)
                local score = g.ZIndex
                if words and hasAny(label, words) then score = score + 120 end
                if g.Size.X.Offset > 20 or g.Size.X.Scale > 0.03 then score = score + 10 end
                if score > bestScore then
                    best, bestScore = g, score
                end
            end
        end
    end
    if best then
        fireSignal(best.MouseButton1Click)
        fireSignal(best.Activated)
        return true
    end
    return false
end

local function usePatientTools()
    local h = hum()
    if not h then return false end
    local function tryGive(t)
        if t:IsA("Tool") and hasAny(t.Name, promptPatientItem) then
            pcall(function()
                h:EquipTool(t)
                t:Activate()
            end)
            return true
        end
        return false
    end
    local char = LP.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if tryGive(t) then return true end
        end
    end
    for _, t in ipairs(LP.Backpack:GetChildren()) do
        if tryGive(t) then return true end
    end
    return false
end

local function treatPatientStep()
    local p = nearestPrompt(cfg.treatRange, promptTreat)
    if p and firePrompt(p) then return true end

    p = nearestPrompt(cfg.treatRange, promptPatientItem)
    if p and firePrompt(p) then return true end

    if usePatientTools() then return true end
    if clickGameGui(promptTreat, true) then return true end

    if fireNearestAny(cfg.nearRange) then return true end
    return false
end

local function basicMedicalStep()
    local p = nearestPrompt(cfg.treatRange, promptDna)
    if p and firePrompt(p) then return true end

    if clickGameGui(promptDna, true) then return true end
    if tryRemotes({ "dna", "analy", "sample", "test" }) then return true end

    if treatPatientStep() then return true end
    return false
end

local function heartClickTargets()
    if heartBusy then return true end
    local pg = LP:FindFirstChild("PlayerGui")
    local ourGui = pg and pg:FindFirstChild(GUI_NAME)
    local targets = {}
    if pg then
        for _, g in ipairs(pg:GetDescendants()) do
            if isWhiteHeartTarget(g) and not (ourGui and g:IsDescendantOf(ourGui)) then
                table.insert(targets, g)
            end
        end
    end
    for _, g in ipairs(workspace:GetDescendants()) do
        if g:IsA("BasePart") and isWhiteHeartTarget(g) then
            table.insert(targets, g)
        end
    end
    if #targets == 0 then return false end
    heartBusy = true
    task.spawn(function()
        for _, t in ipairs(targets) do
            if t:IsA("BasePart") then
                clickPart(t)
            else
                fireSignal(t.MouseButton1Click)
                fireSignal(t.Activated)
            end
            task.wait(cfg.heartClickGap)
        end
        heartBusy = false
    end)
    return true
end

local function heartStep()
    if heartClickTargets() then return true end

    local p = nearestPrompt(18, promptHeart)
    if p and firePrompt(p) then return true end

    if clickGameGui(promptHeart, true) then return true end
    if tryRemotes({ "heart", "monitor", "ecg", "pulse", "vitals" }) then return true end

    if treatPatientStep() then return true end
    return false
end

local function surgeryStep()
    if clickGameGui(promptSurgery, true) then return true end

    local p = nearestPrompt(18, promptSurgery)
    if p and firePrompt(p) then return true end

    if tryRemotes({ "surgery", "operate", "scalpel", "stitch", "tool" }) then return true end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and dist(obj) < 14 and not isSkullTarget(obj) then
            local t = lower(obj.Name)
            if hasAny(t, promptSurgery) then
                if clickPart(obj) then return true end
            end
        end
    end

    if treatPatientStep() then return true end
    if clickGameGui(nil, true) then return true end
    return false
end

local function treatmentRoomStep()
    local room = detectRoom()
    if room == "none" then return false end

    if room == "surgery" then
        if surgeryStep() then return true, "Surgery" end
    elseif room == "heart" then
        if heartStep() then return true, "Tim" end
    elseif room == "xray" then
        if xrayStep() then return true, "X-Quang" end
        if treatPatientStep() then return true, "X-Quang thuoc" end
    elseif room == "basic" then
        if basicMedicalStep() then return true, "Co ban" end
    end

    if treatPatientStep() then return true, "Dieu tri" end
    return false, room
end

local function clickWorldPart(part)
    local cam = workspace.CurrentCamera
    if not cam or not part then return false end
    local clicked = false
    pcall(function()
        local v, onScreen = cam:WorldToViewportPoint(part.Position)
        if onScreen and v.Z > 0 then
            VIM:SendMouseButtonEvent(v.X, v.Y, 0, true, game, 0)
            task.wait(0.04)
            VIM:SendMouseButtonEvent(v.X, v.Y, 0, false, game, 0)
            clicked = true
        end
    end)
    return clicked
end

local function clickPart(part)
    if not part or not part:IsA("BasePart") then return false end
    local cd = part:FindFirstChildWhichIsA("ClickDetector", true)
    if cd then
        local ok = false
        pcall(function()
            if typeof(fireclickdetector) == "function" then
                fireclickdetector(cd, 0)
                ok = true
            end
            fireSignal(cd.MouseClick)
            ok = true
        end)
        if ok then return true end
    end
    if clickWorldPart(part) then return true end
    for _, ch in ipairs(part:GetDescendants()) do
        if ch:IsA("ProximityPrompt") and firePrompt(ch) then return true end
    end
    return false
end

local function collectXrayButtons()
    if os.clock() - xrayCollectAt < 0.35 then return end
    xrayCollectAt = os.clock()
    xrayBtns = {}
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("BasePart") and dist(p) < 18 then
            local id = colorId(p.Color)
            if id then
                table.insert(xrayBtns, { part = p, id = id })
                if not xrayBase[p] then
                    xrayBase[p] = {
                        color = p.Color,
                        material = p.Material,
                        bright = btnBright(p.Color),
                    }
                end
            end
        end
    end
    table.sort(xrayBtns, function(a, b)
        return a.part.Position.X < b.part.Position.X
    end)
end

local function partLit(part)
    local hl = part:FindFirstChildOfClass("Highlight")
    if hl and hl.Enabled then return true end
    local pl = part:FindFirstChildOfClass("PointLight")
    if pl and pl.Enabled and pl.Brightness > 0.2 then return true end
    if part.Material == Enum.Material.Neon then return true end
    local sel = part:FindFirstChildOfClass("SelectionBox")
    if sel and sel.Visible then return true end
    local base = xrayBase[part]
    if base and btnBright(part.Color) > base.bright + 0.16 then return true end
    for _, ch in ipairs(part:GetDescendants()) do
        if ch:IsA("SurfaceGui") or ch:IsA("BillboardGui") then
            for _, g in ipairs(ch:GetDescendants()) do
                if g:IsA("GuiObject") and g.Visible then
                    if g:IsA("ImageLabel") and g.ImageTransparency < 0.4 then return true end
                    if (g:IsA("Frame") or g:IsA("TextLabel")) and g.BackgroundTransparency < 0.45 then
                        if btnBright(g.BackgroundColor3) > 0.72 then return true end
                    end
                end
            end
        end
    end
    return false
end

local function xrayStep()
    if xrayPhase == "play" then return true end

    if not isInXrayRoom() then
        xraySeq = {}
        xrayPhase = "idle"
        xrayLit = {}
        return false
    end

    collectXrayButtons()
    if #xrayBtns < 3 then
        setStatus("X-Quang: tim nut (" .. #xrayBtns .. ")")
        return false
    end

    for _, b in ipairs(xrayBtns) do
        local lit = partLit(b.part)
        local was = xrayLit[b.part]
        if lit and not was then
            table.insert(xraySeq, b.part)
            xrayLastFlash = os.clock()
            xrayPhase = "record"
            setStatus("X-Quang ghi:" .. #xraySeq)
        end
        xrayLit[b.part] = lit
    end

    if xrayPhase == "record" and #xraySeq > 0 and os.clock() - xrayLastFlash > cfg.xraySilence then
        xrayPhase = "play"
        local seq = xraySeq
        xraySeq = {}
        setStatus("X-Quang bam:" .. #seq)
        task.spawn(function()
            for _, part in ipairs(seq) do
                if part.Parent then
                    clickPart(part)
                    task.wait(cfg.xrayClickGap)
                end
            end
            xrayPhase = "idle"
            xrayLit = {}
            xrayBase = {}
            setStatus("X-Quang xong")
        end)
        return true
    end

    local p = nearestPrompt(18, promptXray)
    if p and firePrompt(p) then return true end

    if clickGuiByWords(promptXray) then return true end

    p = nearestPrompt(14, promptTreat)
    if p and firePrompt(p) then return true end

    return false
end

local function useHealItems()
    local h = hum()
    if not h or h.Health >= h.MaxHealth * 0.92 then return end
    local function tryTool(t)
        if t:IsA("Tool") and hasAny(t.Name, promptHeal) then
            pcall(function()
                h:EquipTool(t)
                t:Activate()
            end)
            return true
        end
        return false
    end
    local char = LP.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if tryTool(t) then return end
        end
    end
    for _, t in ipairs(LP.Backpack:GetChildren()) do
        if tryTool(t) then return end
    end
end

local function lowGfxOnce()
    if gfxDone then return end
    gfxDone = true
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e10
        Lighting.Brightness = 2
    end)
    task.spawn(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("Decal") or obj:IsA("Texture") then
                    obj.Transparency = 1
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                elseif obj:IsA("SurfaceAppearance") then
                    obj:Destroy()
                end
            end)
            task.wait()
        end
    end)
end

local function setBoost(on)
    local h = hum()
    if not h then return end
    h.WalkSpeed = on and 24 or 16
end

local function hookInstantPrompts()
    table.insert(conns, PPS.PromptShown:Connect(function(prompt)
        if not ON then return end
        task.defer(function()
            pcall(function() firePrompt(prompt) end)
        end)
    end))

    table.insert(conns, workspace.DescendantAdded:Connect(function(obj)
        if not ON then return end
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            task.defer(function()
                task.wait(0.05)
                if ON and obj.Parent then
                    pcall(function() firePrompt(obj) end)
                end
            end)
        end
    end))
end

local function mainStep()
    if os.clock() - lastAct < cfg.actionCooldown then return end

    refreshPromptCache()
    local room = detectRoom()
    setStatus(string.format("%s P:%d R:%d", room, #promptCache, #remotes))

    if room ~= "none" then
        local ok, tag = treatmentRoomStep()
        if ok then
            lastAct = os.clock()
            setStatus(tag or room)
            return
        end
    end

    -- Desk: GUI buttons (photo/camera/admit/shutter)
    if deskGuiCycle() then
        lastAct = os.clock()
        setStatus("desk GUI")
        return
    end

    -- Desk: nearest prompt (keyword OR any within 10 studs)
    local p = nearestPrompt(cfg.deskRange, promptDesk)
    if not p then
        p = nearestPrompt(cfg.nearRange, nil)
    end
    if p and firePrompt(p) then
        lastAct = os.clock()
        setStatus("desk prompt")
        return
    end

    if tryRemotes(remoteWords) then
        lastAct = os.clock()
        setStatus("remote")
        return
    end

    if tryClickDetectors(cfg.interactRange) then
        lastAct = os.clock()
        setStatus("click")
        return
    end

    -- Emergency
    p = nearestPrompt(cfg.emergencyRange, promptEmergency)
    if p and firePrompt(p) then
        lastAct = os.clock()
        setStatus("emergency")
        return
    end

    useHealItems()

    if isInTreatmentRoom() and treatPatientStep() then
        lastAct = os.clock()
        setStatus("Thuoc")
        return
    end

    p = nearestPrompt(cfg.interactRange, promptCoffee)
    if p and firePrompt(p) then
        lastAct = os.clock()
        setStatus("coffee")
        return
    end

    p = nearestPrompt(cfg.interactRange, promptBuy)
    if p and firePrompt(p) then
        lastAct = os.clock()
        setStatus("buy")
    end
end

local function start()
    scanRemotes()
    hookInstantPrompts()
    table.insert(conns, LP.Idled:Connect(function()
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.15)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end))
    setBoost(true)
    lowGfxOnce()
    task.spawn(function()
        while ON do
            pcall(mainStep)
            task.wait(cfg.loopDelay)
        end
    end)
    log("ON | firePrompt:" .. tostring(hasFirePrompt) .. " remotes:" .. #remotes)
end

local function stop()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    setBoost(false)
    setStatus("off")
end

-- UI (ESC / RightControl opens menu + frees mouse for T1)
local pg = LP:WaitForChild("PlayerGui")
local MENU_ACTION = "VuuyPrivate_MenuEsc"

local function getGuiParent()
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    return pg
end

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.DisplayOrder = 999999
gui.Parent = getGuiParent()

local menuOpen = false

local function raiseGuiOnTop()
    local parent = getGuiParent()
    if gui.Parent ~= parent then
        gui.Parent = parent
    end
    local top = 999999
    for _, child in ipairs(pg:GetChildren()) do
        if child:IsA("ScreenGui") and child ~= gui and child.DisplayOrder >= top then
            top = child.DisplayOrder + 1
        end
    end
    pcall(function()
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("ScreenGui") and child ~= gui and child.DisplayOrder >= top then
                top = child.DisplayOrder + 1
            end
        end
    end)
    gui.DisplayOrder = top
end

local function freeMouse()
    pcall(function()
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        UIS.MouseIconEnabled = true
    end)
end

local function refreshBtn()
    btn.Text = ON and "BẬT AUTO (ON)" or "TẮT AUTO (OFF)"
    btn.BackgroundColor3 = ON and Color3.fromRGB(34, 145, 65) or Color3.fromRGB(55, 55, 55)
end

local function toggleFarm()
    ON = not ON
    refreshBtn()
    if ON then start() else stop() end
end

local function setMenuVisible(show)
    menuOpen = show
    if show then
        raiseGuiOnTop()
        freeMouse()
    end
    overlay.Visible = show
    panel.Visible = show
    hint.Visible = not show
end

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(0, 220, 0, 28)
hint.Position = UDim2.new(0, 12, 0, 12)
hint.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
hint.BackgroundTransparency = 0.35
hint.TextColor3 = Color3.fromRGB(220, 220, 220)
hint.Font = Enum.Font.Gotham
hint.TextSize = 12
hint.Text = BRAND .. " | ESC/RCtrl Menu | F6 ON/OFF"
hint.ZIndex = 50
hint.Parent = gui
Instance.new("UICorner", hint).CornerRadius = UDim.new(0, 6)

local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.45
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Visible = false
overlay.ZIndex = 10000
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 310, 0, 248)
panel.Position = UDim2.new(0.5, -155, 0.5, -124)
panel.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 10001
panel.Active = true
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 36)
title.Position = UDim2.new(0, 10, 0, 8)
title.BackgroundTransparency = 1
title.Text = BRAND
title.TextColor3 = Color3.fromRGB(130, 200, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.ZIndex = 10002
title.Parent = panel

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -20, 0, 40)
sub.Position = UDim2.new(0, 10, 0, 40)
sub.BackgroundTransparency = 1
sub.TextColor3 = Color3.fromRGB(170, 170, 170)
sub.Font = Enum.Font.Gotham
sub.TextSize = 11
sub.TextWrapped = true
sub.Text = BRAND_SUB
sub.ZIndex = 10002
sub.Parent = panel

local note = Instance.new("TextLabel")
note.Size = UDim2.new(1, -20, 0, 28)
note.Position = UDim2.new(0, 10, 0, 72)
note.BackgroundTransparency = 1
note.TextColor3 = Color3.fromRGB(140, 140, 150)
note.Font = Enum.Font.Gotham
note.TextSize = 10
note.TextWrapped = true
note.Text = "Auto tat ca phong: 1-5 DNA | 6 XQuang | 7 Tim | 8 Mo"
note.ZIndex = 10002
note.Parent = panel

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -40, 0, 52)
btn.Position = UDim2.new(0, 20, 0, 108)
btn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 16
btn.Text = "TẮT AUTO (OFF)"
btn.ZIndex = 10002
btn.Parent = panel
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(1, -40, 0, 36)
closeBtn.Position = UDim2.new(0, 20, 0, 192)
closeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
closeBtn.Font = Enum.Font.Gotham
closeBtn.TextSize = 14
closeBtn.Text = "Đóng (ESC)"
closeBtn.ZIndex = 10002
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

task.spawn(function()
    while gui.Parent do
        sub.Text = statusText .. "\n" .. BRAND_SUB .. "\nF6 = bật/tắt nhanh"
        task.wait(0.25)
    end
end)

btn.MouseButton1Click:Connect(toggleFarm)
closeBtn.MouseButton1Click:Connect(function() setMenuVisible(false) end)
overlay.MouseButton1Click:Connect(function() setMenuVisible(false) end)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        setMenuVisible(not menuOpen)
    elseif input.KeyCode == Enum.KeyCode.F6 then
        toggleFarm()
    end
end)

pcall(function()
    CAS:UnbindAction(MENU_ACTION)
    CAS:BindActionAtPriority(MENU_ACTION, function(_, state)
        if state ~= Enum.UserInputState.Begin then
            return Enum.ContextActionResult.Pass
        end
        setMenuVisible(not menuOpen)
        return Enum.ContextActionResult.Sink
    end, false, 3000, Enum.KeyCode.Escape)
end)

GuiService.MenuOpened:Connect(function()
    task.defer(function()
        setMenuVisible(true)
        raiseGuiOnTop()
        freeMouse()
    end)
end)

GuiService.MenuClosed:Connect(function()
    setMenuVisible(false)
end)

LP.CharacterAdded:Connect(function()
    task.wait(1)
    if ON then setBoost(true) end
end)

scanRemotes()
setStatus(BRAND .. " | R:" .. #remotes)
log(BRAND .. " loaded | F6 bat/tat | ESC menu")

if cfg.autoStart then
    task.defer(function()
        task.wait(0.6)
        if not ON then
            toggleFarm()
            log("Auto ON")
        end
    end)
end
