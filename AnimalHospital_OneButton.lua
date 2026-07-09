-- Animal Hospital - One Button Utility
-- Single toggle button: turns all supported automations on/off.

if getgenv().AH_ONEBTN_LOADED then
    warn("[AH] Script already loaded.")
    return
end
getgenv().AH_ONEBTN_LOADED = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")

local LP = Players.LocalPlayer

local cfg = {
    interactRange = 14,
    collectRange = 22,
    loopDelay = 0.12,
    walkSpeed = 24,
    jumpPower = 55,
    emergencyRange = 60,
    buyCooldown = 2.5,
    actionCooldown = 0.25
}

local state = {
    enabled = false,
    runtimeConns = {},
    lastBuyTick = 0,
    lastActionTick = 0,
    gfxApplied = false
}

local function notify(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "AnimalHospital",
            Text = msg,
            Duration = 3
        })
    end)
end

local function getRoot(character)
    character = character or LP.Character
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(character)
    character = character or LP.Character
    if not character then
        return nil
    end
    return character:FindFirstChildOfClass("Humanoid")
end

local function distanceTo(part)
    local root = getRoot()
    if not root or not part or not part:IsA("BasePart") then
        return math.huge
    end
    return (root.Position - part.Position).Magnitude
end

local function setMovementBoost(on)
    local hum = getHumanoid()
    if not hum then
        return
    end
    if on then
        hum.WalkSpeed = cfg.walkSpeed
        hum.JumpPower = cfg.jumpPower
    else
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end
end

local function antiAfk()
    local c = LP.Idled:Connect(function()
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.2)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end)
    table.insert(state.runtimeConns, c)
end

local function tryPrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then
        return
    end
    if not prompt.Enabled then
        return
    end
    local parent = prompt.Parent
    if parent and parent:IsA("BasePart") and distanceTo(parent) <= cfg.interactRange then
        pcall(function()
            fireproximityprompt(prompt)
        end)
    end
end

local function tryClick(cd)
    if not cd or not cd:IsA("ClickDetector") then
        return
    end
    local p = cd.Parent
    if p and p:IsA("BasePart") and distanceTo(p) <= cfg.interactRange then
        pcall(function()
            fireclickdetector(cd)
        end)
    end
end

local collectKeywords = {
    "coin", "cash", "reward", "money", "drop", "gift", "box", "crate"
}

local remoteKeywords = {
    "heal", "treat", "patient", "pet", "clean", "feed", "collect", "claim", "job", "work",
    "fire", "extinguish", "revive", "carry", "rescue", "coffee", "sanity", "candle", "ritual"
}

local coffeeKeywords = {
    "coffee", "cafe", "latte", "espresso", "cup", "drink", "machine"
}

local buyKeywords = {
    "buy", "shop", "purchase", "store", "vendor", "item", "tool", "med", "medicine", "bandage", "kit", "potion"
}

local useHealKeywords = {
    "med", "medicine", "bandage", "heal", "firstaid", "first_aid", "potion", "pill", "syringe", "treatment"
}

local emergencyKeywords = {
    "fire", "burn", "extinguish", "faint", "unconscious", "revive", "rescue", "critical", "cp", "cpr", "urgent",
    "carry", "ritual", "candle", "monster", "bed", "syrup"
}

local ritualKeywords = {
    "ritual", "candle", "eyedrop", "iv", "drop", "coffee", "tase", "defuse"
}

local fireResponseKeywords = {
    "fire", "burn", "extinguish", "extinguisher", "ointment"
}

local faintResponseKeywords = {
    "faint", "unconscious", "carry", "pickup", "drop", "bed", "revive"
}

local syrupKeywords = {
    "maple", "syrup", "bedmonster", "monster"
}

local function containsKeyword(name, keywords)
    name = string.lower(name or "")
    for _, k in ipairs(keywords) do
        if string.find(name, k, 1, true) then
            return true
        end
    end
    return false
end

local function autoInteractStep()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            tryPrompt(obj)
        elseif obj:IsA("ClickDetector") then
            tryClick(obj)
        end
    end
end

local function autoCollectStep()
    local root = getRoot()
    if not root then
        return
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and containsKeyword(obj.Name, collectKeywords) then
            local d = distanceTo(obj)
            if d <= cfg.collectRange then
                pcall(function()
                    firetouchinterest(root, obj, 0)
                    firetouchinterest(root, obj, 1)
                end)
            end
        end
    end
end

local function autoRemoteStep()
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and containsKeyword(obj.Name, remoteKeywords) then
            pcall(function()
                obj:FireServer()
            end)
        elseif obj:IsA("RemoteFunction") and containsKeyword(obj.Name, remoteKeywords) then
            pcall(function()
                obj:InvokeServer()
            end)
        end
    end
end

local function canAct()
    return os.clock() - state.lastActionTick >= cfg.actionCooldown
end

local function markAction()
    state.lastActionTick = os.clock()
end

local function canBuy()
    return os.clock() - state.lastBuyTick >= cfg.buyCooldown
end

local function markBuy()
    state.lastBuyTick = os.clock()
end

local function isEmergencyObject(obj)
    local name = string.lower(obj.Name or "")
    if containsKeyword(name, emergencyKeywords) then
        return true
    end

    for _, desc in ipairs(obj:GetDescendants()) do
        if desc:IsA("BoolValue") then
            local n = string.lower(desc.Name)
            if containsKeyword(n, emergencyKeywords) and desc.Value == true then
                return true
            end
        end
    end

    return false
end

local function nearestEmergencyTarget()
    local root = getRoot()
    if not root then
        return nil
    end

    local best, bestDist
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and (containsKeyword(obj.Name, {"patient", "pet"}) or isEmergencyObject(obj)) then
            local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if p then
                local d = (root.Position - p.Position).Magnitude
                if d <= cfg.emergencyRange and (not bestDist or d < bestDist) and isEmergencyObject(obj) then
                    best = obj
                    bestDist = d
                end
            end
        end
    end
    return best
end

local function getTargetPart(target)
    if not target then
        return nil
    end
    if target:IsA("BasePart") then
        return target
    end
    if target:IsA("Model") then
        return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

local function moveNear(part)
    local root = getRoot()
    if not root or not part then
        return
    end
    local d = (root.Position - part.Position).Magnitude
    if d > cfg.interactRange then
        root.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
    end
end

local function triggerPromptByKeywords(container, keywords)
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and containsKeyword(obj.Name, keywords) then
            local parentPart = getTargetPart(obj.Parent)
            if parentPart then
                moveNear(parentPart)
            end
            if canAct() then
                tryPrompt(obj)
                markAction()
            end
        end
    end
end

local function triggerRemoteByKeywords(keywords)
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if containsKeyword(obj.Name, keywords) then
            if obj:IsA("RemoteEvent") then
                pcall(function()
                    obj:FireServer()
                end)
            elseif obj:IsA("RemoteFunction") then
                pcall(function()
                    obj:InvokeServer()
                end)
            end
        end
    end
end

local function autoCoffeeStep()
    triggerPromptByKeywords(workspace, coffeeKeywords)
    triggerRemoteByKeywords(coffeeKeywords)
end

local function autoBuyHealItemsStep()
    if not canBuy() then
        return
    end

    triggerPromptByKeywords(workspace, buyKeywords)
    triggerRemoteByKeywords(buyKeywords)
    triggerRemoteByKeywords(useHealKeywords)
    markBuy()
end

local function autoConsumeHealStep()
    local char = LP.Character
    if not char then
        return
    end

    local hum = getHumanoid(char)
    if hum and hum.Health < hum.MaxHealth then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and containsKeyword(tool.Name, useHealKeywords) then
                pcall(function()
                    hum:EquipTool(tool)
                end)
                pcall(function()
                    tool:Activate()
                end)
            end
        end

        for _, tool in ipairs(LP.Backpack:GetChildren()) do
            if tool:IsA("Tool") and containsKeyword(tool.Name, useHealKeywords) then
                pcall(function()
                    hum:EquipTool(tool)
                end)
                pcall(function()
                    tool:Activate()
                end)
            end
        end
    end
end

local function autoEmergencyStep()
    local target = nearestEmergencyTarget()
    if not target then
        -- Even if no explicit target is detected, still handle global emergencies.
        triggerPromptByKeywords(workspace, ritualKeywords)
        triggerPromptByKeywords(workspace, fireResponseKeywords)
        triggerPromptByKeywords(workspace, faintResponseKeywords)
        triggerPromptByKeywords(workspace, syrupKeywords)
        triggerRemoteByKeywords(ritualKeywords)
        triggerRemoteByKeywords(fireResponseKeywords)
        triggerRemoteByKeywords(faintResponseKeywords)
        triggerRemoteByKeywords(syrupKeywords)
        return
    end

    local p = getTargetPart(target)
    if p then
        moveNear(p)
    end

    triggerPromptByKeywords(target, emergencyKeywords)
    triggerPromptByKeywords(target, fireResponseKeywords)
    triggerPromptByKeywords(target, faintResponseKeywords)
    triggerPromptByKeywords(target, ritualKeywords)
    triggerRemoteByKeywords(emergencyKeywords)
    triggerRemoteByKeywords(fireResponseKeywords)
    triggerRemoteByKeywords(faintResponseKeywords)
    triggerRemoteByKeywords(ritualKeywords)
end

local function applyLowGfx()
    if state.gfxApplied then
        return
    end
    state.gfxApplied = true

    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e10
        Lighting.Brightness = 1.8
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
    end)

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Decal") or obj:IsA("Texture") then
            pcall(function()
                obj.Texture = ""
                obj.Transparency = 1
            end)
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            pcall(function()
                obj.Enabled = false
            end)
        elseif obj:IsA("BasePart") then
            pcall(function()
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
            end)
        elseif obj:IsA("SurfaceAppearance") then
            pcall(function()
                obj:Destroy()
            end)
        end
    end
end

local function autoPriorityStep()
    -- High-night priority:
    -- 1) Emergency (fire/faint/ritual) -> 2) maintain sanity (coffee/heal) -> 3) buy supplies.
    autoEmergencyStep()
    autoConsumeHealStep()
    autoCoffeeStep()
    autoBuyHealItemsStep()
end

local function spawnLoop(fn)
    task.spawn(function()
        while state.enabled do
            local ok = pcall(fn)
            if not ok then
                -- Keep loops alive even if one action errors.
            end
            task.wait(cfg.loopDelay)
        end
    end)
end

local function clearConnections()
    for _, c in ipairs(state.runtimeConns) do
        pcall(function()
            c:Disconnect()
        end)
    end
    table.clear(state.runtimeConns)
end

local gui = Instance.new("ScreenGui")
gui.Name = "AH_OneButton_UI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    gui.Parent = game:GetService("CoreGui")
end)
if not gui.Parent then
    gui.Parent = LP:WaitForChild("PlayerGui")
end

local btn = Instance.new("TextButton")
btn.Name = "MainToggle"
btn.Size = UDim2.new(0, 150, 0, 48)
btn.Position = UDim2.new(0, 18, 0.5, -24)
btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
btn.BorderSizePixel = 0
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 15
btn.Text = "AH: OFF"
btn.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = btn

local dragging = false
local dragStart, startPos

btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = btn.Position
    end
end)

btn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        btn.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

local function setEnabled(on)
    if on == state.enabled then
        return
    end

    state.enabled = on
    btn.Text = on and "AH: ON" or "AH: OFF"
    btn.BackgroundColor3 = on and Color3.fromRGB(34, 145, 65) or Color3.fromRGB(35, 35, 35)

    if on then
        antiAfk()
        applyLowGfx()
        setMovementBoost(true)
        spawnLoop(autoInteractStep)
        spawnLoop(autoCollectStep)
        spawnLoop(autoRemoteStep)
        spawnLoop(autoPriorityStep)
        notify("All features enabled")
    else
        setMovementBoost(false)
        clearConnections()
        notify("All features disabled")
    end
end

btn.MouseButton1Click:Connect(function()
    setEnabled(not state.enabled)
end)

LP.CharacterAdded:Connect(function()
    task.wait(1)
    if state.enabled then
        setMovementBoost(true)
    end
end)

notify("One-button script loaded")
