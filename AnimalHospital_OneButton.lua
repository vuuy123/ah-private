-- AH Night100 M4 - stable one-button build (VN + EN)

local G = (typeof(getgenv) == "function" and getgenv()) or _G
if G.AH_NIGHT100_V2 then
    local old = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("AH_Night100_UI")
    if old then old:Destroy() end
end
G.AH_NIGHT100_V2 = true

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local VIM = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
if not LP then LP = Players.PlayerAdded:Wait() end

local canFirePrompt = typeof(fireproximityprompt) == "function"

local ON = false
local conns = {}
local lastPrompt = 0
local lastTool = 0
local gfxDone = false

local function log(msg)
    print("[AH]", msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "AH Night100",
            Text = tostring(msg),
            Duration = 2
        })
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
    if not r or not part or not part:IsA("BasePart") then return 9e9 end
    return (r.Position - part.Position).Magnitude
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

local function promptText(p)
    return string.lower(tostring(p.Name) .. "|" .. tostring(p.ActionText) .. "|" .. tostring(p.ObjectText))
end

local function hasAny(text, words)
    for _, w in ipairs(words) do
        if string.find(text, w, 1, true) then return true end
    end
    return false
end

local deskWords = {
    -- EN
    "check", "greet", "photo", "camera", "cctv", "shutter", "admit", "register",
    "inspect", "window", "patient", "form", "scan", "desk", "reception", "counter",
    -- VN
    "kiem", "kiểm", "chup", "chụp", "anh", "ảnh", "camera", "cua so", "cửa sổ",
    "benh nhan", "bệnh nhân", "tiep nhan", "tiếp nhận", "quay", "le tan", "lễ tân",
    "mo cua", "mở cửa", "dong cua", "đóng cửa", "man", "màn", "cho vao", "cho vào"
}

local healWords = {
    "med", "medicine", "bandage", "heal", "potion", "pill", "ointment", "chocolate",
    "thuoc", "thuốc", "hoi", "hồi", "chua", "chữa", "bang", "băng"
}

local coffeeWords = {
    "coffee", "cafe", "chocolate", "drink", "brew", "ca phe", "cà phê", "nuoc", "nước"
}

local emergencyWords = {
    "fire", "burn", "extinguish", "faint", "revive", "carry", "rescue", "ritual", "candle",
    "lua", "lửa", "chay", "cháy", "ngat", "ngất", "cuu", "cứu", "benh", "bệnh"
}

local function pressE()
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.08)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

local function firePrompt(p)
    if not p or not p:IsA("ProximityPrompt") or not p.Enabled then return false end
    local part = promptPart(p)
    if part and dist(part) > 14 then return false end

    if canFirePrompt then
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

local function nearestPrompt(words, maxDist)
    maxDist = maxDist or 14
    local best, bestD
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local part = promptPart(obj)
            if part then
                local d = dist(part)
                if d <= maxDist then
                    local t = promptText(obj)
                    if not words or hasAny(t, words) then
                        if not bestD or d < bestD then
                            best = obj
                            bestD = d
                        end
                    end
                end
            end
        end
    end
    return best
end

local function clickVisibleButtons(words)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, g in ipairs(pg:GetDescendants()) do
        if (g:IsA("TextButton") or g:IsA("ImageButton")) and g.Visible then
            local label = string.lower(tostring(g.Name) .. "|" .. tostring(g.Text or ""))
            if hasAny(label, words) then
                pcall(function()
                    if typeof(getconnections) == "function" then
                        for _, sig in ipairs({ g.MouseButton1Click, g.Activated }) do
                            if sig then
                                for _, c in ipairs(getconnections(sig)) do
                                    pcall(function() c:Fire() end)
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
end

local function useHealTool()
    if os.clock() - lastTool < 1.2 then return end
    local h = hum()
    if not h then return end

    local function tryTool(tool)
        if tool:IsA("Tool") and hasAny(string.lower(tool.Name), healWords) then
            pcall(function()
                h:EquipTool(tool)
                tool:Activate()
            end)
            lastTool = os.clock()
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

local function loopStep()
    if os.clock() - lastPrompt < 0.35 then return end

    -- Priority 1: desk / check-in (VN + EN)
    clickVisibleButtons(deskWords)
    local p = nearestPrompt(deskWords, 14)
    if not p then
        -- fallback: nearest prompt at desk area
        p = nearestPrompt(nil, 8)
    end
    if p and firePrompt(p) then
        lastPrompt = os.clock()
        return
    end

    -- Priority 2: emergency
    p = nearestPrompt(emergencyWords, 40)
    if p and firePrompt(p) then
        lastPrompt = os.clock()
        return
    end

    -- Priority 3: heal + coffee + buy nearby
    useHealTool()
    p = nearestPrompt(coffeeWords, 12)
    if p and firePrompt(p) then
        lastPrompt = os.clock()
        return
    end

    p = nearestPrompt({ "buy", "shop", "mua", "cua hang", "cửa hàng", "store" }, 12)
    if p and firePrompt(p) then
        lastPrompt = os.clock()
    end
end

local function setBoost(on)
    local h = hum()
    if not h then return end
    if on then
        h.WalkSpeed = 22
        h.JumpPower = 50
    else
        h.WalkSpeed = 16
        h.JumpPower = 50
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
            pcall(loopStep)
            task.wait(0.2)
        end
    end)
end

local function stop()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    setBoost(false)
end

-- UI
local oldGui = LP.PlayerGui:FindFirstChild("AH_Night100_UI")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "AH_Night100_UI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.Sibling
gui.Parent = LP:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 170, 0, 52)
btn.Position = UDim2.new(0, 20, 0.5, -26)
btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
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
    btn.BackgroundColor3 = ON and Color3.fromRGB(34, 145, 65) or Color3.fromRGB(45, 45, 45)
    if ON then
        start()
        log("Da bat")
    else
        stop()
        log("Da tat")
    end
end)

LP.CharacterAdded:Connect(function()
    task.wait(1)
    if ON then setBoost(true) end
end)

log("Load OK - bam AH de bat")
