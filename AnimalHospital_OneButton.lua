-- AH Night100 v3 - instant prompt hook + desk auto (Opiumware/Mac)

local G = (typeof(getgenv) == "function" and getgenv()) or _G
pcall(function()
    local pg = game:GetService("Players").LocalPlayer.PlayerGui
    local old = pg:FindFirstChild("AH_Night100_UI")
    if old then old:Destroy() end
end)
G.AH_NIGHT100_V3 = true

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local PPS = game:GetService("ProximityPromptService")
local GuiService = game:GetService("GuiService")

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

local cfg = {
    loopDelay = 0.12,
    cacheRefresh = 1.8,
    actionCooldown = 0.22,
    deskRange = 18,
    nearRange = 10,
    interactRange = 14,
    emergencyRange = 50,
    remoteCooldown = 1.8,
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

local remoteWords = {
    "check", "admit", "register", "patient", "reception", "desk", "front", "nurse",
    "photo", "camera", "cctv", "shutter", "stamp", "secretary", "coffee", "sanity",
    "notify", "deliver", "emergency", "fire", "revive", "carry", "treat", "heal",
    "shift", "work", "job", "dna", "analy", "monitor", "portal", "door",
}

local function log(msg)
    print("[AH]", msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "AH Night100", Text = tostring(msg), Duration = 2 })
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
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") and obj.Parent and obj.Parent:IsA("BasePart") then
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
    return false
end

local function clickGuiByWords(words)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return false end
    local clicked = false
    local ourGui = pg:FindFirstChild("AH_Night100_UI")
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
    setStatus(string.format("P:%d R:%d", #promptCache, #remotes))

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
local gui = Instance.new("ScreenGui")
gui.Name = "AH_Night100_UI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.Sibling
gui.DisplayOrder = 999
gui.Parent = pg

local menuOpen = false

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
    overlay.Visible = show
    panel.Visible = show
    hint.Visible = not show
    if show then freeMouse() end
end

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(0, 220, 0, 28)
hint.Position = UDim2.new(0, 12, 0, 12)
hint.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
hint.BackgroundTransparency = 0.35
hint.TextColor3 = Color3.fromRGB(220, 220, 220)
hint.Font = Enum.Font.Gotham
hint.TextSize = 12
hint.Text = "ESC / RCtrl = Menu  |  F6 = ON/OFF"
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
overlay.ZIndex = 1
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 300, 0, 220)
panel.Position = UDim2.new(0.5, -150, 0.5, -110)
panel.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 2
panel.Active = true
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 36)
title.Position = UDim2.new(0, 10, 0, 8)
title.BackgroundTransparency = 1
title.Text = "AH Night100"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.ZIndex = 3
title.Parent = panel

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -20, 0, 40)
sub.Position = UDim2.new(0, 10, 0, 44)
sub.BackgroundTransparency = 1
sub.TextColor3 = Color3.fromRGB(170, 170, 170)
sub.Font = Enum.Font.Gotham
sub.TextSize = 12
sub.TextWrapped = true
sub.Text = "v3 ready"
sub.ZIndex = 3
sub.Parent = panel

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -40, 0, 52)
btn.Position = UDim2.new(0, 20, 0, 100)
btn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 16
btn.Text = "TẮT AUTO (OFF)"
btn.ZIndex = 3
btn.Parent = panel
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(1, -40, 0, 36)
closeBtn.Position = UDim2.new(0, 20, 0, 164)
closeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
closeBtn.Font = Enum.Font.Gotham
closeBtn.TextSize = 14
closeBtn.Text = "Đóng (ESC)"
closeBtn.ZIndex = 3
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

task.spawn(function()
    while gui.Parent do
        sub.Text = statusText .. "\nF6 bật/tắt nhanh không cần chuột"
        task.wait(0.25)
    end
end)

btn.MouseButton1Click:Connect(toggleFarm)
closeBtn.MouseButton1Click:Connect(function() setMenuVisible(false) end)
overlay.MouseButton1Click:Connect(function() setMenuVisible(false) end)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Escape then
        task.defer(function()
            setMenuVisible(true)
            freeMouse()
        end)
    elseif input.KeyCode == Enum.KeyCode.RightControl then
        setMenuVisible(not menuOpen)
    elseif input.KeyCode == Enum.KeyCode.F6 then
        toggleFarm()
    end
end)

GuiService.MenuOpened:Connect(function()
    setMenuVisible(true)
    freeMouse()
end)

GuiService.MenuClosed:Connect(function()
    setMenuVisible(false)
end)

LP.CharacterAdded:Connect(function()
    task.wait(1)
    if ON then setBoost(true) end
end)

scanRemotes()
setStatus("v3 | R:" .. #remotes)
log("AH v3 loaded")
