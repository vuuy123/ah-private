-- Animal Hospital - One Button Utility (Desk-safe build)
-- Focus: reception check-in first, emergencies second, no blind remote spam.

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
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer

local cfg = {
    deskRange = 10,
    interactRange = 8,
    emergencyRange = 45,
    loopDelay = 0.35,
    scanRefresh = 4,
    walkSpeed = 22,
    jumpPower = 50,
    buyCooldown = 3,
    actionCooldown = 0.4,
    lowGfxBatch = 120
}

local state = {
    enabled = false,
    runtimeConns = {},
    lastBuyTick = 0,
    lastActionTick = 0,
    gfxApplied = false,
    gfxIndex = 1,
    cachedPrompts = {},
    lastScanTick = 0
}

local deskKeywords = {
    "check", "greet", "photo", "camera", "cctv", "shutter", "admit", "register",
    "inspect", "window", "patient", "form", "scan", "look", "take", "desk",
    "reception", "counter", "print", "compare", "open", "close", "raise", "lower"
}

local coffeeKeywords = {
    "coffee", "cafe", "latte", "espresso", "cup", "drink", "machine", "brew"
}

local buyKeywords = {
    "buy", "shop", "purchase", "store", "vendor", "medicine", "bandage", "kit", "potion", "extinguisher"
}

local useHealKeywords = {
    "med", "medicine", "bandage", "heal", "firstaid", "potion", "pill", "syringe", "ointment", "chocolate"
}

local emergencyKeywords = {
    "fire", "burn", "extinguish", "faint", "unconscious", "revive", "carry", "rescue",
    "critical", "ritual", "candle", "bedmonster", "syrup", "maple"
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

local function containsKeyword(name, keywords)
    name = string.lower(name or "")
    for _, k in ipairs(keywords) do
        if string.find(name, k, 1, true) then
            return true
        end
    end
    return false
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

local function getPromptPart(prompt)
    local parent = prompt.Parent
    if not parent then
        return nil
    end
    if parent:IsA("BasePart") then
        return parent
    end
    if parent:IsA("Attachment") and parent.Parent and parent.Parent:IsA("BasePart") then
        return parent.Parent
    end
    if parent:IsA("Model") then
        return parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
    end
    return parent:FindFirstChildWhichIsA("BasePart", true)
end

local function distanceTo(part)
    local root = getRoot()
    if not root or not part or not part:IsA("BasePart") then
        return math.huge
    end
    return (root.Position - part.Position).Magnitude
end

local function canAct()
    return os.clock() - state.lastActionTick >= cfg.actionCooldown
end

local function markAction()
    state.lastActionTick = os.clock()
end

local function firePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
        return false
    end
    local ok = pcall(function()
        if typeof(fireproximityprompt) == "function" then
            fireproximityprompt(prompt, 0)
            if prompt.HoldDuration and prompt.HoldDuration > 0 then
                task.wait(prompt.HoldDuration + 0.05)
                fireproximityprompt(prompt, 1)
            end
        end
    end)
    return ok
end

local function refreshPromptCache()
    if os.clock() - state.lastScanTick < cfg.scanRefresh then
        return
    end
    state.lastScanTick = os.clock()
    table.clear(state.cachedPrompts)

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local part = getPromptPart(obj)
            if part then
                table.insert(state.cachedPrompts, {
                    prompt = obj,
                    part = part,
                    name = string.lower(obj.Name .. " " .. obj.ActionText .. " " .. obj.ObjectText)
                })
            end
        end
    end
end

local function getNearbyPrompts(maxRange, keywords)
    refreshPromptCache()
    local list = {}
    for _, item in ipairs(state.cachedPrompts) do
        if item.prompt.Parent and distanceTo(item.part) <= maxRange then
            if not keywords or containsKeyword(item.name, keywords) then
                table.insert(list, item)
            end
        end
    end
    table.sort(list, function(a, b)
        return distanceTo(a.part) < distanceTo(b.part)
    end)
    return list
end

local function clickGuiButtons(keywords)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then
        return
    end

    for _, gui in ipairs(pg:GetDescendants()) do
        if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
            local label = string.lower(gui.Name .. " " .. (gui.Text or ""))
            if containsKeyword(label, keywords) then
                pcall(function()
                    for _, signal in ipairs({
                        gui.MouseButton1Click,
                        gui.MouseButton1Down,
                        gui.Activated
                    }) do
                        if signal then
                            for _, conn in ipairs(getconnections(signal)) do
                                conn:Fire()
                            end
                        end
                    end
                end)
            end
        end
    end
end

local function autoDeskCheckInStep()
    if not canAct() then
        return
    end

    -- 1) Click desk UI buttons (photo / shutter / camera / admit)
    clickGuiButtons(deskKeywords)

    -- 2) Trigger only nearby desk prompts (no map-wide spam)
    local deskPrompts = getNearbyPrompts(cfg.deskRange, deskKeywords)
    for i = 1, math.min(3, #deskPrompts) do
        if firePrompt(deskPrompts[i].prompt) then
            markAction()
            break
        end
    end
end

local function autoCoffeeStep()
    if not canAct() then
        return
    end

    local prompts = getNearbyPrompts(cfg.interactRange, coffeeKeywords)
    for _, item in ipairs(prompts) do
        if firePrompt(item.prompt) then
            markAction()
            break
        end
    end
end

local function autoBuyHealItemsStep()
    if os.clock() - state.lastBuyTick < cfg.buyCooldown then
        return
    end

    local prompts = getNearbyPrompts(cfg.interactRange, buyKeywords)
    for _, item in ipairs(prompts) do
        if firePrompt(item.prompt) then
            state.lastBuyTick = os.clock()
            break
        end
    end
end

local function autoConsumeHealStep()
    local hum = getHumanoid()
    if not hum then
        return
    end

    local function tryUseTool(tool)
        if tool:IsA("Tool") and containsKeyword(tool.Name, useHealKeywords) then
            pcall(function()
                hum:EquipTool(tool)
                tool:Activate()
            end)
            return true
        end
        return false
    end

    local char = LP.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tryUseTool(tool) then
                return
            end
        end
    end

    for _, tool in ipairs(LP.Backpack:GetChildren()) do
        if tryUseTool(tool) then
            return
        end
    end
end

local function hasActiveEmergency()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BoolValue") and obj.Value == true and containsKeyword(obj.Name, emergencyKeywords) then
            return true
        end
        if obj:IsA("Model") and containsKeyword(obj.Name, emergencyKeywords) then
            local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if p and distanceTo(p) <= cfg.emergencyRange then
                return true
            end
        end
    end
    return false
end

local function autoEmergencyStep()
    if not hasActiveEmergency() or not canAct() then
        return
    end

    local prompts = getNearbyPrompts(cfg.emergencyRange, emergencyKeywords)
    for _, item in ipairs(prompts) do
        if firePrompt(item.prompt) then
            markAction()
            break
        end
    end
end

local function applyLowGfxStep()
    if state.gfxApplied and state.gfxIndex > #workspace:GetDescendants() then
        return
    end

    if not state.gfxApplied then
        state.gfxApplied = true
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 1e10
            Lighting.Brightness = 1.8
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
        end)
    end

    local descendants = workspace:GetDescendants()
    local finish = math.min(#descendants, state.gfxIndex + cfg.lowGfxBatch - 1)

    for i = state.gfxIndex, finish do
        local obj = descendants[i]
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

    state.gfxIndex = finish + 1
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

local function mainLoopStep()
    -- Desk check-in is highest priority so it won't get stuck at reception.
    autoDeskCheckInStep()

    if hasActiveEmergency() then
        autoEmergencyStep()
    end

    autoConsumeHealStep()
    autoCoffeeStep()
    autoBuyHealItemsStep()
    applyLowGfxStep()
end

local function spawnLoop(fn)
    task.spawn(function()
        while state.enabled do
            pcall(fn)
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
        setMovementBoost(true)
        spawnLoop(mainLoopStep)
        notify("Desk-safe mode enabled")
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
