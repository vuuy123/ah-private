-- AH Night100 Pro - Opiumware/Mac safe, desk auto like premium scripts

local G = (typeof(getgenv) == "function" and getgenv()) or _G
if G.AH_NIGHT100_PRO then
    pcall(function()
        local pg = game:GetService("Players").LocalPlayer.PlayerGui
        local old = pg:FindFirstChild("AH_Night100_UI")
        if old then old:Destroy() end
    end)
end
G.AH_NIGHT100_PRO = true

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
if not LP then LP = Players.PlayerAdded:Wait() end

local hasFirePrompt = typeof(fireproximityprompt) == "function"
local hasFireSignal = typeof(firesignal) == "function"
local hasGetConnections = typeof(getconnections) == "function"

local ON = false
local conns = {}
local promptCache = {}
local lastCache = 0
local lastAct = 0
local deskStep = 1
local gfxDone = false

local cfg = {
    loopDelay = 0.15,
    cacheRefresh = 2.5,
    actionCooldown = 0.28,
    deskRange = 16,
    interactRange = 12,
    emergencyRange = 45,
}

local deskGuiWords = {
    { "photo", "chup", "chụp", "anh", "ảnh", "take" },
    { "camera", "cctv", "cam", "monitor" },
    { "admit", "accept", "register", "cho vao", "cho vào", "tiep nhan", "tiếp nhận", "stamp", "check" },
}

local promptGroups = {
    desk = {
        "check", "greet", "photo", "camera", "cctv", "shutter", "admit", "register",
        "inspect", "window", "patient", "form", "scan", "desk", "reception", "counter",
        "kiem", "kiểm", "chup", "chụp", "anh", "ảnh", "tiep nhan", "tiếp nhận",
        "quay", "le tan", "lễ tân", "mo cua", "mở cửa", "dong cua", "đóng cửa",
        "man", "màn", "cho vao", "cho vào", "stamp", "take", "interact", "e"
    },
    coffee = { "coffee", "cafe", "chocolate", "drink", "brew", "ca phe", "cà phê", "nuoc", "nước", "machine" },
    heal = { "med", "medicine", "bandage", "heal", "potion", "pill", "ointment", "chocolate", "thuoc", "thuốc", "hoi", "hồi", "chua", "chữa", "bang", "băng", "eat", "use", "drink" },
    buy = { "buy", "shop", "purchase", "store", "vendor", "mua", "cua hang", "cửa hàng" },
    emergency = { "fire", "burn", "extinguish", "faint", "unconscious", "revive", "carry", "rescue", "ritual", "candle", "lua", "lửa", "chay", "cháy", "ngat", "ngất", "cuu", "cứu", "extinguisher", "bed", "syrup", "maple" },
}

local function log(msg)
    print("[AH]", msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "AH Night100", Text = tostring(msg), Duration = 2 })
    end)
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
        task.wait(0.06)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

local function firePrompt(p)
    if not p or not p:IsA("ProximityPrompt") or not p.Enabled then return false end
    if hasFirePrompt then
        local ok = pcall(function()
            fireproximityprompt(p, 0)
            if p.HoldDuration and p.HoldDuration > 0 then
                task.wait(p.HoldDuration + 0.05)
                fireproximityprompt(p, 1)
            end
        end)
        if ok then return true end
    end
    pressE()
    return true
end

local function refreshPromptCache()
    if os.clock() - lastCache < cfg.cacheRefresh then return end
    lastCache = os.clock()
    promptCache = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled and obj.Parent then
            local part = promptPart(obj)
            if part then
                table.insert(promptCache, {
                    prompt = obj,
                    part = part,
                    label = promptLabel(obj),
                    dist = dist(part)
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

local function tryPrompts(maxRange, words)
    refreshPromptCache()
    local fired = false
    for _, item in ipairs(promptCache) do
        if item.dist <= maxRange and item.prompt.Parent then
            if not words or hasAny(item.label, words) then
                if firePrompt(item.prompt) then
                    fired = true
                end
            end
        end
    end
    return fired
end

local function clickGuiByWords(words)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return false end
    local clicked = false
    for _, g in ipairs(pg:GetDescendants()) do
        if (g:IsA("TextButton") or g:IsA("ImageButton")) and g.Visible then
            local label = lower(g.Name) .. "|" .. lower(g.Text or "")
            if hasAny(label, words) then
                fireSignal(g.MouseButton1Click)
                fireSignal(g.Activated)
                clicked = true
            end
        end
    end
    return clicked
end

local function deskGuiCycle()
    local words = deskGuiWords[deskStep]
    if clickGuiByWords(words) then
        deskStep = deskStep % #deskGuiWords + 1
        return true
    end
    return false
end

local function useHealItems()
    local h = hum()
    if not h or h.Health >= h.MaxHealth then return end
    local function tryTool(t)
        if t:IsA("Tool") and hasAny(t.Name, promptGroups.heal) then
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
                    obj.Texture = ""
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
    h.WalkSpeed = on and 22 or 16
    h.JumpPower = on and 50 or 50
end

local function mainStep()
    if os.clock() - lastAct < cfg.actionCooldown then return end

    -- 1) Desk GUI cycle (photo -> camera -> admit) like premium scripts
    if deskGuiCycle() then
        lastAct = os.clock()
        return
    end

    -- 2) Instant prompts at desk
    local p = nearestPrompt(cfg.deskRange, promptGroups.desk)
    if p and firePrompt(p) then
        lastAct = os.clock()
        return
    end

    -- 3) Emergency first if detected nearby
    if tryPrompts(cfg.emergencyRange, promptGroups.emergency) then
        lastAct = os.clock()
        return
    end

    -- 4) Self sustain
    useHealItems()
    if nearestPrompt(cfg.interactRange, promptGroups.coffee) and firePrompt(nearestPrompt(cfg.interactRange, promptGroups.coffee)) then
        lastAct = os.clock()
        return
    end

  -- 5) Buy supplies when near shop prompts
    p = nearestPrompt(cfg.interactRange, promptGroups.buy)
    if p and firePrompt(p) then
        lastAct = os.clock()
    end
end

local function start()
    table.insert(conns, LP.Idled:Connect(function()
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.2)
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
end

local function stop()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    setBoost(false)
end

-- UI (always create)
local pg = LP:WaitForChild("PlayerGui")
local oldGui = pg:FindFirstChild("AH_Night100_UI")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "AH_Night100_UI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.Sibling
gui.Parent = pg

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 180, 0, 54)
btn.Position = UDim2.new(0, 20, 0.5, -27)
btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 16
btn.Text = "AH: OFF"
btn.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = btn

local dragging, dragStart, startPos = false
btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = btn.Position
    end
end)
btn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

btn.MouseButton1Click:Connect(function()
    ON = not ON
    btn.Text = ON and "AH: ON" or "AH: OFF"
    btn.BackgroundColor3 = ON and Color3.fromRGB(34, 145, 65) or Color3.fromRGB(40, 40, 40)
    if ON then
        start()
        log("Pro mode ON")
    else
        stop()
        log("Pro mode OFF")
    end
end)

LP.CharacterAdded:Connect(function()
    task.wait(1)
    if ON then setBoost(true) end
end)

log("AH Night100 Pro loaded")
