local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()
local enemies = Workspace:WaitForChild("Enemies")

local maxDistance = 2500
local predictionFactor = 0
local smoothingFactor = 0
local TARGET_UPDATE_INTERVAL = 0

local enabled = false
local targetMode = "Enemies"
local hasTarget = false
local currentTarget = nil
local lastTargetUpdate = 0
local smoothedTargetPos = Vector3.new()
local lookAtTargetPos = Vector3.new()

local BELLY_OFFSET = Vector3.new(0, -1.3, 0)

local lookAtEnabled = false
local remoteActive = false
local lastRemoteTime = 0
local REMOTE_TIMEOUT = 0.45

local espEnabled = false
local espInstances = {}

local mainLoopConnection = nil

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AimbotGui"
screenGui.Parent = playerGui
screenGui.DisplayOrder = 1000
screenGui.ResetOnSpawn = false

local dragging
local dragInput
local dragStart
local startPos

local function updateDrag(input)
    local delta = input.Position - dragStart
    screenGui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

local statusCircle = Instance.new("Frame")
statusCircle.Size = UDim2.new(0,30,0,30)
statusCircle.Position = UDim2.new(0,15,0,15)
statusCircle.BackgroundColor3 = Color3.new(1,0,0)
statusCircle.BorderSizePixel = 0
statusCircle.Visible = false
statusCircle.Parent = screenGui
Instance.new("UICorner", statusCircle).CornerRadius = UDim.new(1,0)

local menuFrame = Instance.new("Frame")
menuFrame.Size = UDim2.new(0,300,0,340)
menuFrame.Position = UDim2.new(0.5,-150,0.5,-170)
menuFrame.BackgroundColor3 = Color3.fromRGB(15,15,18)
menuFrame.BorderSizePixel = 0
menuFrame.Visible = false
menuFrame.Parent = screenGui
Instance.new("UICorner", menuFrame).CornerRadius = UDim.new(0,16)

menuFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = menuFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

menuFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end)

local lookAtBtn = Instance.new("TextButton")
lookAtBtn.Size = UDim2.new(0.88,0,0.13,0)
lookAtBtn.Position = UDim2.new(0.06,0,0.05,0)
lookAtBtn.BackgroundColor3 = Color3.fromRGB(0,140,255)
lookAtBtn.Text = "LOOK AT: OFF"
lookAtBtn.TextColor3 = Color3.new(1,1,1)
lookAtBtn.TextScaled = true
lookAtBtn.Font = Enum.Font.SourceSansBold
lookAtBtn.Parent = menuFrame
Instance.new("UICorner", lookAtBtn).CornerRadius = UDim.new(0,12)

local espBtn = Instance.new("TextButton")
espBtn.Size = UDim2.new(0.88,0,0.13,0)
espBtn.Position = UDim2.new(0.06,0,0.22,0)
espBtn.BackgroundColor3 = Color3.fromRGB(90,90,90)
espBtn.Text = "ESP: OFF"
espBtn.TextColor3 = Color3.new(1,1,1)
espBtn.TextScaled = true
espBtn.Font = Enum.Font.SourceSansBold
espBtn.Parent = menuFrame
Instance.new("UICorner", espBtn).CornerRadius = UDim.new(0,12)

local enemiesBtn = Instance.new("TextButton")
enemiesBtn.Size = UDim2.new(0.42,0,0.13,0)
enemiesBtn.Position = UDim2.new(0.06,0,0.39,0)
enemiesBtn.BackgroundColor3 = Color3.fromRGB(0,220,0)
enemiesBtn.Text = "Enemies"
enemiesBtn.TextColor3 = Color3.new(1,1,1)
enemiesBtn.TextScaled = true
enemiesBtn.Font = Enum.Font.SourceSansBold
enemiesBtn.Parent = menuFrame
Instance.new("UICorner", enemiesBtn).CornerRadius = UDim.new(0,12)

local playersBtn = Instance.new("TextButton")
playersBtn.Size = UDim2.new(0.42,0,0.13,0)
playersBtn.Position = UDim2.new(0.52,0,0.39,0)
playersBtn.BackgroundColor3 = Color3.fromRGB(220,0,0)
playersBtn.Text = "Players"
playersBtn.TextColor3 = Color3.new(1,1,1)
playersBtn.TextScaled = true
playersBtn.Font = Enum.Font.SourceSansBold
playersBtn.Parent = menuFrame
Instance.new("UICorner", playersBtn).CornerRadius = UDim.new(0,12)

local function updateLookAtButton()
    lookAtBtn.BackgroundColor3 = lookAtEnabled and Color3.fromRGB(60,220,100) or Color3.fromRGB(0,140,255)
    lookAtBtn.Text = "LOOK AT: " .. (lookAtEnabled and "ON" or "OFF")
end

local function updateEspButton()
    espBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(60,220,100) or Color3.fromRGB(90,90,90)
    espBtn.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
end

local function toggleMenu()
    if menuFrame.Visible then
        TweenService:Create(menuFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0,0,0,0), Position = UDim2.new(0.5,0,0.5,0), BackgroundTransparency = 1
        }):Play()
        task.delay(0.27, function() menuFrame.Visible = false end)
    else
        menuFrame.Size = UDim2.new(0,0,0,0)
        menuFrame.Position = UDim2.new(0.5,0,0.5,0)
        menuFrame.BackgroundTransparency = 1
        menuFrame.Visible = true
        TweenService:Create(menuFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0,300,0,340), Position = UDim2.new(0.5,-150,0.5,-170), BackgroundTransparency = 0
        }):Play()
    end
end

local function hideMenu()
    if menuFrame.Visible then
        toggleMenu()
    end
end

local function clearESPForTarget(target)
    if not target then return end
    local char = target.Parent
    if char and espInstances[char] then
        if espInstances[char].Highlight then
            espInstances[char].Highlight:Destroy()
        end
        espInstances[char] = nil
    end
end

local function applyESPToTarget(target)
    clearESPForTarget(target)
    if not target then return end
    local char = target.Parent
    if not char then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Adornee = char
    highlight.FillColor = Color3.fromRGB(255, 215, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 150)
    highlight.FillTransparency = 0.35
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = char
    
    espInstances[char] = {Highlight = highlight}
end

local function updateAllESP()
    if not espEnabled then
        for _, data in pairs(espInstances) do
            if data.Highlight then data.Highlight:Destroy() end
        end
        espInstances = {}
        return
    end

    local targets = targetMode == "Enemies" and enemies:GetChildren() or Players:GetPlayers()
    
    for _, obj in ipairs(targets) do
        if targetMode == "Players" then
            if obj == player then continue end
            local team = obj.Team
            if team and string.find(string.lower(team.Name or ""), "marine") then continue end
        end

        local targetChar = targetMode == "Players" and obj.Character or obj
        if not targetChar then continue end

        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        local humanoid = targetChar:FindFirstChild("Humanoid")

        if targetRoot and humanoid and humanoid.Health > 0 then
            applyESPToTarget(targetRoot)
        end
    end
end

local function isMarinePlayer(plr)
    local team = plr.Team
    if not team then return false end
    local name = team.Name or ""
    return string.find(string.lower(name), "marine") ~= nil
end

local function findClosestTarget()
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local playerPos = hrp.Position
    local closestRoot = nil
    local shortestDistance = maxDistance
    local currentTime = tick()

    if currentTime - lastTargetUpdate < TARGET_UPDATE_INTERVAL and currentTarget and currentTarget.Parent then
        local hum = currentTarget.Parent:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            return currentTarget
        end
    end

    lastTargetUpdate = currentTime

    local targets = targetMode == "Enemies" and enemies:GetChildren() or Players:GetPlayers()

    for _, obj in ipairs(targets) do
        if targetMode == "Players" then
            if obj == player or isMarinePlayer(obj) then continue end
        end

        local targetChar = targetMode == "Players" and obj.Character or obj
        if not targetChar then continue end

        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        local humanoid = targetChar:FindFirstChild("Humanoid")

        if targetRoot and humanoid and humanoid.Health > 0 then
            local dist = (playerPos - targetRoot.Position).Magnitude
            if dist < shortestDistance then
                shortestDistance = dist
                closestRoot = targetRoot
            end
        end
    end

    return closestRoot
end

local function startMainLoop()
    if mainLoopConnection then mainLoopConnection:Disconnect() end
    
    mainLoopConnection = RunService.Heartbeat:Connect(function()
        if not enabled then
            hasTarget = false
            remoteActive = false
            currentTarget = nil
            return
        end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local targetRoot = findClosestTarget()
        
        if targetRoot then
            hasTarget = true
            currentTarget = targetRoot

            local velocity = targetRoot.AssemblyLinearVelocity or Vector3.new()
            local predictedPos = targetRoot.Position + BELLY_OFFSET + velocity * predictionFactor

            smoothedTargetPos = smoothedTargetPos:Lerp(predictedPos, smoothingFactor)
            lookAtTargetPos = targetRoot.Position + BELLY_OFFSET

            if lookAtEnabled and remoteActive and (tick() - lastRemoteTime < REMOTE_TIMEOUT) then
                hrp.CFrame = CFrame.lookAt(hrp.Position, lookAtTargetPos)
            end
        else
            hasTarget = false
            currentTarget = nil
            remoteActive = false
        end
    end)
end

local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    if not hasTarget or not enabled or not currentTarget then 
        return oldNamecall(self, ...) 
    end

    local method = getnamecallmethod()
    local args = {...}

    if method == "FireServer" or method == "InvokeServer" then
        local remoteName = tostring(self):lower()
        if not (remoteName:find("leftclick") or remoteName:find("anticheat") or remoteName:find("validate")) then
            for i, arg in ipairs(args) do
                if typeof(arg) == "Vector3" then
                    args[i] = lookAtTargetPos
                    remoteActive = true
                    lastRemoteTime = tick()
                    break
                end
            end
        end
    end

    return oldNamecall(self, unpack(args))
end)

setreadonly(mt, true)

local function connectButton(btn, callback)
    btn.MouseButton1Click:Connect(function()
        callback()
        hideMenu()
    end)
end

connectButton(lookAtBtn, function()
    lookAtEnabled = not lookAtEnabled
    updateLookAtButton()
end)

connectButton(espBtn, function()
    espEnabled = not espEnabled
    updateEspButton()
    updateAllESP()
end)

connectButton(enemiesBtn, function()
    targetMode = "Enemies"
    enemiesBtn.BackgroundColor3 = Color3.fromRGB(0,255,0)
    playersBtn.BackgroundColor3 = Color3.fromRGB(220,0,0)
    currentTarget = nil
    lastTargetUpdate = 0
    updateAllESP()
end)

connectButton(playersBtn, function()
    targetMode = "Players"
    playersBtn.BackgroundColor3 = Color3.fromRGB(255,60,60)
    enemiesBtn.BackgroundColor3 = Color3.fromRGB(0,220,0)
    currentTarget = nil
    lastTargetUpdate = 0
    updateAllESP()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

    if input.KeyCode == Enum.KeyCode.C and shift then
        enabled = not enabled
        if enabled then 
            currentTarget = nil
            lastTargetUpdate = 0
            startMainLoop() 
        else
            if mainLoopConnection then mainLoopConnection:Disconnect() end
            hasTarget = false
            currentTarget = nil
            remoteActive = false
        end

        local col = enabled and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,60,60)
        statusCircle.BackgroundColor3 = col
        statusCircle.Visible = true
        TweenService:Create(statusCircle, TweenInfo.new(0.15), {Size = UDim2.new(0,45,0,45)}):Play()
        task.delay(0.8, function()
            TweenService:Create(statusCircle, TweenInfo.new(0.2), {Size = UDim2.new(0,0,0,0)}):Play()
            task.wait(0.22)
            statusCircle.Visible = false
        end)

    elseif input.KeyCode == Enum.KeyCode.F and shift then
        toggleMenu()

    elseif input.KeyCode == Enum.KeyCode.U then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp and espEnabled then
            local targetRoot = findClosestTarget()
            if targetRoot then
                applyESPToTarget(targetRoot)
            end
        end
    end
end)

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    currentTarget = nil
    lastTargetUpdate = 0
    task.wait(0.5)
    updateAllESP()
end)

RunService.Heartbeat:Connect(function()
    if espEnabled then
        updateAllESP()
    end
end)
