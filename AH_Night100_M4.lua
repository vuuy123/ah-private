-- AH Night100 M4 - Mac/Opiumware safe build

local G = (typeof(getgenv) == "function" and getgenv()) or _G

if G.AH_NIGHT100_LOADED then
    warn("[AH] Da load roi. Rejoin hoac chay: G.AH_NIGHT100_LOADED=nil")
    return
end
G.AH_NIGHT100_LOADED = true

local ok, err = pcall(function()
    local Players = game:GetService("Players")
    local VirtualUser = game:GetService("VirtualUser")
    local StarterGui = game:GetService("StarterGui")
    local Lighting = game:GetService("Lighting")

    local LP = Players.LocalPlayer
    if not LP then
        LP = Players.PlayerAdded:Wait()
    end

    local hasFirePrompt = typeof(fireproximityprompt) == "function"
    local hasGetConnections = typeof(getconnections) == "function"

    local cfg = {
        deskRange = 12,
        interactRange = 10,
        emergencyRange = 50,
        loopDelay = 0.4,
        scanRefresh = 5,
        walkSpeed = 22,
        jumpPower = 50,
        buyCooldown = 3,
        actionCooldown = 0.5,
        lowGfxBatch = 80
    }

    local state = {
        enabled = false,
        runtimeConns = {},
        lastBuyTick = 0,
        lastActionTick = 0,
        gfxStarted = false,
        gfxIndex = 1,
        cachedPrompts = {},
        lastScanTick = 0
    }

    local deskKeywords = {
        "check", "greet", "photo", "camera", "cctv", "shutter", "admit", "register",
        "inspect", "window", "patient", "form", "scan", "look", "take", "desk",
        "reception", "counter", "print", "compare", "open", "close", "raise", "lower"
    }

    local coffeeKeywords = { "coffee", "cafe", "latte", "espresso", "cup", "drink", "machine", "brew" }
    local buyKeywords = { "buy", "shop", "purchase", "store", "vendor", "medicine", "bandage", "kit", "potion", "extinguisher" }
    local useHealKeywords = { "med", "medicine", "bandage", "heal", "firstaid", "potion", "pill", "syringe", "ointment", "chocolate" }
    local emergencyKeywords = { "fire", "burn", "extinguish", "faint", "unconscious", "revive", "carry", "rescue", "critical", "ritual", "candle", "syrup", "maple" }

    local function notify(msg)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "AH Night100",
                Text = tostring(msg),
                Duration = 3
            })
        end)
        print("[AH]", msg)
    end

    local function containsKeyword(name, keywords)
        name = string.lower(tostring(name or ""))
        for _, k in ipairs(keywords) do
            if string.find(name, k, 1, true) then
                return true
            end
        end
        return false
    end

    local function getRoot()
        local char = LP.Character
        if not char then return nil end
        return char:FindFirstChild("HumanoidRootPart")
    end

    local function getHumanoid()
        local char = LP.Character
        if not char then return nil end
        return char:FindFirstChildOfClass("Humanoid")
    end

    local function getPromptPart(prompt)
        local parent = prompt.Parent
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
        if not hasFirePrompt then return false end
        if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
            return false
        end
        local fired = false
        pcall(function()
            fireproximityprompt(prompt, 0)
            fired = true
            if prompt.HoldDuration and prompt.HoldDuration > 0 then
                task.wait(prompt.HoldDuration + 0.05)
                fireproximityprompt(prompt, 1)
            end
        end)
        return fired
    end

    local function refreshPromptCache()
        if os.clock() - state.lastScanTick < cfg.scanRefresh then return end
        state.lastScanTick = os.clock()
        state.cachedPrompts = {}

        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") and obj.Enabled then
                    local part = getPromptPart(obj)
                    if part then
                        table.insert(state.cachedPrompts, {
                            prompt = obj,
                            part = part,
                            name = string.lower(tostring(obj.Name) .. " " .. tostring(obj.ActionText) .. " " .. tostring(obj.ObjectText))
                        })
                    end
                end
            end
        end)
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
        if not hasGetConnections then return end
        local pg = LP:FindFirstChild("PlayerGui")
        if not pg then return end

        pcall(function()
            for _, gui in ipairs(pg:GetDescendants()) do
                if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
                    local label = string.lower(tostring(gui.Name) .. " " .. tostring(gui.Text or ""))
                    if containsKeyword(label, keywords) then
                        pcall(function()
                            local signals = { gui.MouseButton1Click, gui.Activated }
                            for _, signal in ipairs(signals) do
                                if signal then
                                    for _, conn in ipairs(getconnections(signal)) do
                                        pcall(function() conn:Fire() end)
                                    end
                                end
                            end
                        end)
                    end
                end
            end
        end)
    end

    local function tryNearbyPrompts(maxRange, keywords)
        local prompts = getNearbyPrompts(maxRange, keywords)
        for i = 1, math.min(2, #prompts) do
            if firePrompt(prompts[i].prompt) then
                markAction()
                return true
            end
        end
        return false
    end

    local function autoDeskCheckInStep()
        if not canAct() then return end
        clickGuiButtons(deskKeywords)
        tryNearbyPrompts(cfg.deskRange, deskKeywords)
    end

    local function autoCoffeeStep()
        if not canAct() then return end
        tryNearbyPrompts(cfg.interactRange, coffeeKeywords)
    end

    local function autoBuyHealItemsStep()
        if os.clock() - state.lastBuyTick < cfg.buyCooldown then return end
        if tryNearbyPrompts(cfg.interactRange, buyKeywords) then
            state.lastBuyTick = os.clock()
        end
    end

    local function autoConsumeHealStep()
        local hum = getHumanoid()
        if not hum then return end

        local function tryTool(tool)
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
                if tryTool(tool) then return end
            end
        end
        for _, tool in ipairs(LP.Backpack:GetChildren()) do
            if tryTool(tool) then return end
        end
    end

    local function hasActiveEmergency()
        local found = false
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BoolValue") and obj.Value == true and containsKeyword(obj.Name, emergencyKeywords) then
                    found = true
                    break
                end
            end
        end)
        return found
    end

    local function autoEmergencyStep()
        if not hasActiveEmergency() or not canAct() then return end
        tryNearbyPrompts(cfg.emergencyRange, emergencyKeywords)
    end

    local function applyLowGfxStep()
        if not state.gfxStarted then
            state.gfxStarted = true
            pcall(function()
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 1e10
                Lighting.Brightness = 1.8
            end)
        end

        pcall(function()
            local descendants = workspace:GetDescendants()
            if state.gfxIndex > #descendants then return end
            local finish = math.min(#descendants, state.gfxIndex + cfg.lowGfxBatch - 1)
            for i = state.gfxIndex, finish do
                local obj = descendants[i]
                if obj:IsA("Decal") or obj:IsA("Texture") then
                    obj.Texture = ""
                    obj.Transparency = 1
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                elseif obj:IsA("BasePart") then
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                elseif obj:IsA("SurfaceAppearance") then
                    obj:Destroy()
                end
            end
            state.gfxIndex = finish + 1
        end)
    end

    local function setMovementBoost(on)
        local hum = getHumanoid()
        if not hum then return end
        if on then
            hum.WalkSpeed = cfg.walkSpeed
            hum.JumpPower = cfg.jumpPower
        else
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
    end

    local function antiAfk()
        pcall(function()
            local c = LP.Idled:Connect(function()
                pcall(function()
                    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                    task.wait(0.2)
                    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                end)
            end)
            table.insert(state.runtimeConns, c)
        end)
    end

    local function mainLoopStep()
        autoDeskCheckInStep()
        if hasActiveEmergency() then autoEmergencyStep() end
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
            pcall(function() c:Disconnect() end)
        end
        state.runtimeConns = {}
    end

    -- GUI first: always show button even if features fail later
    local oldGui = LP.PlayerGui:FindFirstChild("AH_Night100_UI")
    if oldGui then oldGui:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AH_Night100_UI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LP:WaitForChild("PlayerGui")

    local btn = Instance.new("TextButton")
    btn.Name = "MainToggle"
    btn.Size = UDim2.new(0, 160, 0, 50)
    btn.Position = UDim2.new(0, 20, 0.5, -25)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.BorderSizePixel = 0
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.Text = "AH: OFF"
    btn.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    local dragging = false
    local dragStart, startPos

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

    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            btn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    local function setEnabled(on)
        if on == state.enabled then return end
        state.enabled = on
        btn.Text = on and "AH: ON" or "AH: OFF"
        btn.BackgroundColor3 = on and Color3.fromRGB(34, 145, 65) or Color3.fromRGB(40, 40, 40)

        if on then
            antiAfk()
            setMovementBoost(true)
            spawnLoop(mainLoopStep)
            notify("Da bat - uu tien check quay")
        else
            setMovementBoost(false)
            clearConnections()
            notify("Da tat")
        end
    end

    btn.MouseButton1Click:Connect(function()
        setEnabled(not state.enabled)
    end)

    LP.CharacterAdded:Connect(function()
        task.wait(1)
        if state.enabled then setMovementBoost(true) end
    end)

    notify("Load thanh cong! Bam nut AH de bat")
end)

if not ok then
    warn("[AH] Loi load script:", err)
end
