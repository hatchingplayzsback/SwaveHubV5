local Services = setmetatable({}, {
    __index = function(t, k)
        local success, service = pcall(game.GetService, game, k)
        if success and service then
            t[k] = service
            return service
        end
        return nil
    end
})

local Players = Services.Players
local Workspace = Services.Workspace
local RunService = Services.RunService
local UserInputService = Services.UserInputService
local ProximityPromptService = Services.ProximityPromptService
local HttpService = Services.HttpService
local ReplicatedStorage = Services.ReplicatedStorage

local LocalPlayer = Players.LocalPlayer

-- ==================== CONFIGURATION ====================
local Config = {
    Gui = {
        Main = {
            Size = UDim2.new(0, 400, 0,340),
            Position = UDim2.new(0.5, -200, 0.5, -200),
            AccentColor = Color3.fromRGB(255, 50, 50),
            BgColor = Color3.fromRGB(15, 15, 15),
            Title = "SWAVE HUB",
            Draggable = true
        }
    },
    BaseATeleportPoints = {
        CFrame.new(-348.06, -7.00, 29.67, -0.99976, 0, -0.02195, 0, 1, 0, 0.02195, 0, -0.99976),
        CFrame.new(-346.31, -7.00, 94.75, -0.99729, 0, -0.07351, 0, 1, 0, 0.07351, 0, -0.99729),
        CFrame.new(-335, -5.04, 101.15, 0.91539, 0, 0.40256, 0, 1, 0, -0.40256, 0, 0.91539)
    },
    BaseBTeleportPoints = {
        CFrame.new(-348, -7.00, 101.67, -0.99976, 0, -0.02195, 0, 1, 0, 0.02195, 0, -0.99976),
        CFrame.new(-346, -5.04, 19.15, 0.91539, 0, 0.40256, 0, 1, 0, -0.40256, 0, 0.91539),
        CFrame.new(-335, -5.04, 19.15, 0.91539, 0, 0.40256, 0, 1, 0, -0.40256, 0, 0.91539)
    },
    VehicleNames = {"Flying Carpet", "Santa Sleigh", "Witch's Broom"},
    Beam = {
        Width = 0.7,
        Color = ColorSequence.new(Color3.fromRGB(255, 50, 50)),
        LightEmission = 1,
        Transparency = NumberSequence.new(0),
        FaceCamera = true
    },
    AutoSteal = {
        Cooldown = 0.1,
        ScanInterval = 0.5,
        HoldDuration = 0.5,
        MaxDistance = 10,
        RequireLineOfSight = true
    }
}

-- ==================== BASE LOCATIONS FOR SMART TP ====================
local BaseLocations = {
    {
        Name = "Base A",
        Pos = Vector3.new(-320.09, 30.72, 115.05),
        CFrame = CFrame.new(-320.094574, 30.7222672, 115.045204, 0.0375146195, -6.63311681e-08, 0.999296069, 1.29714266e-08, 1, 6.589093e-08, -0.999296069, 1.04904228e-08, 0.0375146195)
    },
    {
        Name = "Base B",
        Pos = Vector3.new(-318.48, 34.56, 2.24),
        CFrame = CFrame.new(-318.47876, 34.5589066, 2.24247718, -0.999901056, -0.000886384747, 0.0140370177, -0.000617493177, 0.999816477, 0.0191486496, -0.0140514141, 0.0191380884, -0.99971813)
    },
    {
        Name = "Base C",
        Pos = Vector3.new(-506.43, 34.56, -2.27),
        CFrame = CFrame.new(-506.425018, 34.5589142, -2.27490854, -0.999999523, -0.000586022798, -0.000794773456, -0.000600584783, 0.99982965, 0.018447401, 0.000783827447, 0.0184478704, -0.999829531)
    },
    {
        Name = "Base D",
        Pos = Vector3.new(-522.58, 37.75, 116.10),
        CFrame = CFrame.new(-522.575745, 37.7451401, 116.101784, 0.0295769963, -0.0317212045, -0.999059021, 0.000621425104, 0.999496698, -0.0317167044, 0.999562323, 0.000317244529, 0.0295818225)
    }
}

-- ==================== STATE ====================
local State = {
    mainGui = nil,
    savedPosition = nil,
    savedBeam = nil,
    savedBeamPart = nil,
    character = nil,
    humanoidRootPart = nil,
    humanoid = nil,
    characterAddedConnection = nil,
    characterRemovingConnection = nil,
    promptConnection = nil,
    isClickTpEnabled = false,
    clickTpConnection = nil,
    isAntiKnockbackEnabled = false,
    antiKnockbackConnection = nil,
    isAimbotEnabled = false,
    aimbotConnection = nil,
    autoStealEnabled = false,
    autoStealThread = nil,
    cachedStealPrompt = nil,
    cachedPromptPart = nil,
    lastScanTime = 0,
    cleanupFunctions = {},
    -- Smart TP
    isSmartTpEnabled = false,
    smartTpParts = {}
}

local function addCleanup(func)
    table.insert(State.cleanupFunctions, func)
end

local function cleanupAll()
    for _, f in ipairs(State.cleanupFunctions) do pcall(f) end
    State.cleanupFunctions = {}
end

-- ==================== UTILITIES ====================
local function safeParentGui(gui)
    if not gui then return end
    local pg = LocalPlayer:FindFirstChild("PlayerGui") or Instance.new("PlayerGui", LocalPlayer)
    if gui.Parent ~= pg then gui.Parent = pg end
end

local function updateCharacterCache()
    State.character = LocalPlayer.Character
    State.humanoidRootPart = State.character and State.character:FindFirstChild("HumanoidRootPart")
    State.humanoid = State.character and State.character:FindFirstChildOfClass("Humanoid")
end

local function setupCharacterListeners()
    if State.characterAddedConnection then State.characterAddedConnection:Disconnect() end
    State.characterAddedConnection = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        updateCharacterCache()
        if State.mainGui then safeParentGui(State.mainGui) end
        if State.isAntiKnockbackEnabled then enableAntiKnockback() end
        if State.isAimbotEnabled then enableAimbot() end
        State.cachedStealPrompt = nil
        State.cachedPromptPart = nil
    end)
    if State.characterRemovingConnection then State.characterRemovingConnection:Disconnect() end
    State.characterRemovingConnection = LocalPlayer.CharacterRemoving:Connect(function()
        State.savedBeam = nil
        State.savedBeamPart = nil
        if State.antiKnockbackConnection then
            State.antiKnockbackConnection:Disconnect()
            State.antiKnockbackConnection = nil
        end
        if State.aimbotConnection then
            State.aimbotConnection:Disconnect()
            State.aimbotConnection = nil
        end
        State.cachedStealPrompt = nil
        State.cachedPromptPart = nil
    end)
end

updateCharacterCache()
setupCharacterListeners()

-- ==================== GUI HELPERS ====================
local function createUICorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = radius or UDim.new(0,4)
    c.Parent = parent
    return c
end

local function createUIStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(255,255,255)
    s.Thickness = thickness or 1
    s.Parent = parent
    return s
end

local function createTextLabel(parent, size, pos, text, textColor, font, textSize)
    local l = Instance.new("TextLabel")
    l.Size = size
    l.Position = pos
    l.Text = text
    l.TextColor3 = textColor or Color3.new(1,1,1)
    l.Font = font or Enum.Font.Gotham
    l.TextSize = textSize or 14
    l.BackgroundTransparency = 1
    l.TextWrapped = true
    l.Parent = parent
    return l
end

local function createTextButton(parent, size, pos, text, bgColor, textColor)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos
    b.Text = text
    b.BackgroundColor3 = bgColor
    b.TextColor3 = textColor or Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.AutoButtonColor = false
    b.Parent = parent
    return b
end

local function createTextBox(parent, size, pos, placeholder)
    local tb = Instance.new("TextBox")
    tb.Size = size
    tb.Position = pos
    tb.PlaceholderText = placeholder
    tb.ClearTextOnFocus = false
    tb.BackgroundColor3 = Color3.fromRGB(30,30,30)
    tb.TextColor3 = Color3.new(1,1,1)
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 14
    tb.Parent = parent
    return tb
end

-- ==================== BEAM ====================
local function createBeam(position)
    if State.savedBeam then State.savedBeam:Destroy() end
    if State.savedBeamPart then State.savedBeamPart:Destroy() end
    updateCharacterCache()
    if not (State.character and State.humanoidRootPart) then return end
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.CFrame = CFrame.new(position)
    part.Parent = Workspace
    State.savedBeamPart = part
    local a0 = Instance.new("Attachment", part)
    local a1 = Instance.new("Attachment", State.humanoidRootPart)
    local beam = Instance.new("Beam")
    beam.Attachment0 = a0
    beam.Attachment1 = a1
    beam.Width0 = Config.Beam.Width
    beam.Width1 = Config.Beam.Width
    beam.FaceCamera = Config.Beam.FaceCamera
    beam.Color = Config.Beam.Color
    beam.LightEmission = Config.Beam.LightEmission
    beam.Transparency = Config.Beam.Transparency
    beam.Parent = Workspace
    State.savedBeam = beam
end

local function clearSavedPosition()
    State.savedPosition = nil
    if State.savedBeam then State.savedBeam:Destroy() State.savedBeam = nil end
    if State.savedBeamPart then State.savedBeamPart:Destroy() State.savedBeamPart = nil end
end

-- ==================== VEHICLE ====================
local function equipVehicle()
    updateCharacterCache()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local hum = State.character and State.character:FindFirstChildOfClass("Humanoid")
    if not (backpack and hum) then return end
    local set = {}
    for _, v in ipairs(Config.VehicleNames) do set[v] = true end
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and set[tool.Name] then
            hum:EquipTool(tool)
            return
        end
    end
end

-- ==================== TELEPORT (INSTANT) ====================
local function teleportSequence(points, warningLabel)
    if not warningLabel or not State.humanoidRootPart then
        if warningLabel then warningLabel.Visible = false end
        return
    end
    warningLabel.Visible = true
    for _, cf in ipairs(points) do
        State.humanoidRootPart.CFrame = cf
        task.wait(0.15)
    end
    task.wait(1)
    warningLabel.Visible = false
end

-- ==================== ANTI-KNOCKBACK ====================
local function enableAntiKnockback()
    updateCharacterCache()
    if not State.humanoidRootPart then return end
    local function handle(v)
        if v:IsA("BodyVelocity") then
            v.Velocity = Vector3.zero
        elseif v:IsA("LinearVelocity") then
            v.VectorVelocity = Vector3.zero
        elseif v:IsA("VectorForce") then
            v.Force = Vector3.zero
        end
    end
    for _, v in ipairs(State.humanoidRootPart:GetChildren()) do
        handle(v)
    end
    if State.antiKnockbackConnection then State.antiKnockbackConnection:Disconnect() end
    State.antiKnockbackConnection = State.humanoidRootPart.ChildAdded:Connect(handle)
end

local function disableAntiKnockback()
    if State.antiKnockbackConnection then
        State.antiKnockbackConnection:Disconnect()
        State.antiKnockbackConnection = nil
    end
end

-- ==================== INSTANT 2D AIMBOT (HORIZONTAL ONLY) ====================
local function getNearestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    updateCharacterCache()
    if not State.character or not State.humanoidRootPart then return nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local character = player.Character
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local distance = (rootPart.Position - State.humanoidRootPart.Position).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
    end
    return closestPlayer
end

local function enableAimbot()
    if State.aimbotConnection then return end
    State.aimbotConnection = RunService.RenderStepped:Connect(function()
        if not State.isAimbotEnabled then return end
        updateCharacterCache()
        if not State.humanoidRootPart then return end
        local targetPlayer = getNearestPlayer()
        if targetPlayer and targetPlayer.Character then
            local targetChar = targetPlayer.Character
            local head = targetChar:FindFirstChild("Head")
            local root = targetChar:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local targetPos = (head and head.Position) or root.Position

            local myPos = State.humanoidRootPart.Position
            local flatTargetPos = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)

            if (flatTargetPos - myPos).Magnitude > 0.5 then
                State.humanoidRootPart.CFrame = CFrame.lookAt(myPos, flatTargetPos)
            end
        end
    end)
end

local function disableAimbot()
    if State.aimbotConnection then
        State.aimbotConnection:Disconnect()
        State.aimbotConnection = nil
    end
end

-- ==================== AUTO STEAL FUNCTIONS (OPTIMIZED) ====================
local function getPromptPart(prompt)
    local parent = prompt.Parent
    if parent:IsA("BasePart") then return parent end
    if parent:IsA("Model") then
        return parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
    end
    if parent:IsA("Attachment") then return parent.Parent end
    return parent:FindFirstChildWhichIsA("BasePart", true)
end

local function isPromptValid(prompt, part)
    if not prompt or not prompt:IsDescendantOf(workspace) or not prompt.Enabled then
        return false
    end
    if not part or not part:IsDescendantOf(workspace) then
        return false
    end
    updateCharacterCache()
    if not State.humanoidRootPart then return false end

    local myPos = State.humanoidRootPart.Position
    local targetPos = part.Position
    local dist = (myPos - targetPos).Magnitude

    if dist > Config.AutoSteal.MaxDistance then return false end
    if not Config.AutoSteal.RequireLineOfSight then return true end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {State.character, part}

    local result = workspace:Raycast(myPos, (targetPos - myPos).Unit * dist, params)
    return not result
end

local function scanForBestPrompt()
    updateCharacterCache()
    if not State.humanoidRootPart then return nil end

    local bestPrompt = nil
    local bestPart = nil
    local bestDist = math.huge

    local searchRoot = workspace:FindFirstChild("Plots") or workspace

    for _, desc in ipairs(searchRoot:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled then
            local actionText = desc.ActionText or desc.ObjectText or ""
            if string.find(string.lower(actionText), "steal") then
                local part = getPromptPart(desc)
                if part then
                    local dist = (State.humanoidRootPart.Position - part.Position).Magnitude
                    if dist <= Config.AutoSteal.MaxDistance and dist < bestDist then
                        if not Config.AutoSteal.RequireLineOfSight or isPromptValid(desc, part) then
                            bestDist = dist
                            bestPrompt = desc
                            bestPart = part
                        end
                    end
                end
            end
        end
    end

    return bestPrompt, bestPart
end

local function triggerPrompt(prompt)
    if not prompt then return end
    prompt.MaxActivationDistance = 9e9
    prompt.RequiresLineOfSight = false
    prompt.ClickablePrompt = true

    local usedFire = pcall(function()
        fireproximityprompt(prompt, 9e9, Config.AutoSteal.HoldDuration)
    end)

    if not usedFire then
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(Config.AutoSteal.HoldDuration)
            prompt:InputHoldEnd()
        end)
    end
end

local function onStealCompleted()
    equipVehicle()
    if State.savedPosition and State.humanoidRootPart then
        local original = State.humanoidRootPart.CFrame
        local camera = Workspace.CurrentCamera
        local originalCameraCFrame = camera.CFrame
        local originalCameraType = camera.CameraType
        camera.CameraType = Enum.CameraType.Scriptable
        State.humanoidRootPart.CFrame = State.savedPosition
        task.wait(0.1)
        State.humanoidRootPart.CFrame = original
        camera.CFrame = originalCameraCFrame
        camera.CameraType = originalCameraType
    end
end

local function enableAutoSteal()
    if State.autoStealEnabled then return end
    State.autoStealEnabled = true

    State.autoStealThread = task.spawn(function()
        local lastScan = 0
        while State.autoStealEnabled do
            local now = tick()
            if now - lastScan >= Config.AutoSteal.ScanInterval then
                local newPrompt, newPart = scanForBestPrompt()
                if newPrompt then
                    State.cachedStealPrompt = newPrompt
                    State.cachedPromptPart = newPart
                else
                    State.cachedStealPrompt = nil
                    State.cachedPromptPart = nil
                end
                lastScan = now
            end

            if State.cachedStealPrompt and State.cachedPromptPart then
                if isPromptValid(State.cachedStealPrompt, State.cachedPromptPart) then
                    triggerPrompt(State.cachedStealPrompt)
                    task.wait(0.1)
                    onStealCompleted()
                else
                    State.cachedStealPrompt = nil
                    State.cachedPromptPart = nil
                    lastScan = 0
                end
            end

            task.wait(Config.AutoSteal.Cooldown)
        end
    end)
end

local function disableAutoSteal()
    State.autoStealEnabled = false
    State.autoStealThread = nil
    State.cachedStealPrompt = nil
    State.cachedPromptPart = nil
end

-- ==================== SMART TP (SCREEN GUI + VISUAL MARKERS + DRAGGABLE) ====================
local function createBaseMarker(location)
    -- A glowing part at the base location
    local part = Instance.new("Part")
    part.Name = "SmartTP_Marker_" .. location.Name
    part.Size = Vector3.new(4, 4, 4)
    part.CFrame = CFrame.new(location.Pos) * CFrame.Angles(0, 0, 0)
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 0.5
    part.BrickColor = BrickColor.new("Really red")
    part.Material = Enum.Material.Neon
    part.Shape = Enum.PartType.Ball
    part.Parent = workspace

    -- Add a point light for glow
    local light = Instance.new("PointLight")
    light.Color = Config.Gui.Main.AccentColor
    light.Range = 20
    light.Brightness = 2
    light.Parent = part

    -- Add a beam for visibility
    local attachment = Instance.new("Attachment", part)
    local beam = Instance.new("Beam")
    beam.Attachment0 = attachment
    beam.Attachment1 = attachment
    beam.Width0 = 5
    beam.Width1 = 5
    beam.Color = ColorSequence.new(Config.Gui.Main.AccentColor)
    beam.Transparency = NumberSequence.new(0.5)
    beam.FaceCamera = true
    beam.Parent = workspace

    return part
end

local function enableSmartTp()
    if State.isSmartTpEnabled then return end
    State.isSmartTpEnabled = true

    -- Create markers at each base
    for _, loc in ipairs(BaseLocations) do
        local marker = createBaseMarker(loc)
        table.insert(State.smartTpParts, marker)
    end

    -- Create ScreenGui with buttons
    local gui = Instance.new("ScreenGui")
    gui.Name = "SmartTPGui"
    gui.ResetOnSpawn = false
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    table.insert(State.smartTpParts, gui)  -- store to destroy later

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 250, 0, #BaseLocations * 50 + 20)
    frame.Position = UDim2.new(0.8, -270, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = gui

    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    -- Glowing outline
    local stroke = Instance.new("UIStroke")
    stroke.Color = Config.Gui.Main.AccentColor
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = frame

    -- Title (also serves as drag handle)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "⚡ SMART TP ⚡"
    title.TextColor3 = Config.Gui.Main.AccentColor
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    -- Make the panel draggable by the title
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Create a button for each base
    for i, loc in ipairs(BaseLocations) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.9, 0, 0, 35)
        btn.Position = UDim2.new(0.05, 0, 0, 40 + (i-1) * 45)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        btn.Text = "🚀 " .. loc.Name
        btn.TextColor3 = Color3.new(1,1,1)
        btn.TextScaled = true
        btn.Font = Enum.Font.GothamBold
        btn.AutoButtonColor = false
        btn.Parent = frame

        -- Style
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn

        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = Config.Gui.Main.AccentColor
        btnStroke.Thickness = 1.5
        btnStroke.Transparency = 0.5
        btnStroke.Parent = btn

        -- Hover effect
        btn.MouseEnter:Connect(function()
            btn.BackgroundColor3 = Config.Gui.Main.AccentColor
            btn.TextColor3 = Color3.new(0,0,0)
        end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            btn.TextColor3 = Color3.new(1,1,1)
        end)

        -- Teleport on click
        btn.MouseButton1Click:Connect(function()
            updateCharacterCache()
            if State.humanoidRootPart then
                -- Flash feedback
                btn.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                task.wait(0.1)
                btn.BackgroundColor3 = Config.Gui.Main.AccentColor

                State.humanoidRootPart.CFrame = loc.CFrame
            else
                task.wait(0.2)
                updateCharacterCache()
                if State.humanoidRootPart then
                    State.humanoidRootPart.CFrame = loc.CFrame
                end
            end
        end)
    end
end

local function disableSmartTp()
    if not State.isSmartTpEnabled then return end
    State.isSmartTpEnabled = false
    for _, obj in ipairs(State.smartTpParts) do
        pcall(function() obj:Destroy() end)
    end
    State.smartTpParts = {}
end

-- ==================== MAIN GUI ====================
local function createMainGUI()
    if State.mainGui then State.mainGui:Destroy() end
    local gui = Instance.new("ScreenGui")
    gui.Name = "SwaveHubPVPSlot"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    safeParentGui(gui)
    State.mainGui = gui
    local cfg = Config.Gui.Main
    local frame = Instance.new("Frame")
    frame.Size = cfg.Size
    frame.Position = cfg.Position
    frame.BackgroundColor3 = cfg.BgColor
    frame.Active = true
    frame.Draggable = cfg.Draggable
    frame.Parent = gui
    createUICorner(frame, UDim.new(0,6))
    createUIStroke(frame, cfg.AccentColor, 2)

    -- Warning label
    local warningLabel = createTextLabel(frame, UDim2.new(0.8,0,0,30), UDim2.new(0.1,0,0.86,0), "DO NOT MOVE", Color3.fromRGB(255,100,100), Enum.Font.GothamBold, 14)
    warningLabel.BackgroundColor3 = Color3.fromRGB(40,0,0)
    warningLabel.Visible = false
    createUICorner(warningLabel)
    createUIStroke(warningLabel, Color3.fromRGB(255,0,0), 1.5)

    -- Title & UserID
    createTextLabel(frame, UDim2.new(1,0,0,45), UDim2.new(0,0,0,8), cfg.Title, cfg.AccentColor, Enum.Font.GothamBold, 20)
    createTextLabel(frame, UDim2.new(1,0,0,25), UDim2.new(0,0,0,50), "UserID: "..LocalPlayer.UserId, Color3.new(1,1,1), Enum.Font.Gotham, 12)

    -- Button layout - two columns (5 buttons each)
    local buttonSize = UDim2.new(0.43, 0, 0, 38)
    local leftX = 0.04
    local rightX = 0.53
    local startY = 85
    local incY = 48
    local leftY = startY
    local rightY = startY

    -- Left column buttons
    local baseA = createTextButton(frame, buttonSize, UDim2.new(leftX, 0, 0, leftY), "TP to BASE A", Color3.fromRGB(50,100,255))
    leftY += incY
    local baseB = createTextButton(frame, buttonSize, UDim2.new(leftX, 0, 0, leftY), "TP to BASE B", Color3.fromRGB(255,50,50))
    leftY += incY
    local setPos = createTextButton(frame, buttonSize, UDim2.new(leftX, 0, 0, leftY), "SET POS", Color3.fromRGB(255,50,50))
    leftY += incY
    local forward = createTextButton(frame, buttonSize, UDim2.new(leftX, 0, 0, leftY), "TP forward", Color3.fromRGB(0,170,255))
    leftY += incY
    -- SMART TP BUTTON
    local smartTpBtn = createTextButton(frame, buttonSize, UDim2.new(leftX, 0, 0, leftY), "SMART TP: OFF", Color3.fromRGB(150,150,150))

    -- Right column buttons
    local clear = createTextButton(frame, buttonSize, UDim2.new(rightX, 0, 0, rightY), "CLEAR POS", Color3.fromRGB(80,80,80))
    rightY += incY
    local clickTpBtn = createTextButton(frame, buttonSize, UDim2.new(rightX, 0, 0, rightY), "CLICK TP: OFF", Color3.fromRGB(100,200,100))
    rightY += incY
    local antiKnockbackBtn = createTextButton(frame, buttonSize, UDim2.new(rightX, 0, 0, rightY), "ANTI KB: OFF", Color3.fromRGB(200,100,50))
    rightY += incY
    local aimbotBtn = createTextButton(frame, buttonSize, UDim2.new(rightX, 0, 0, rightY), "2D AIMBOT: OFF", Color3.fromRGB(255,50,255))
    rightY += incY
    local autoStealBtn = createTextButton(frame, buttonSize, UDim2.new(rightX, 0, 0, rightY), "AUTO STEAL: OFF", Color3.fromRGB(255,150,50))

    -- Style all buttons
    for _, btn in {baseA, baseB, setPos, forward, smartTpBtn, clear, clickTpBtn, antiKnockbackBtn, aimbotBtn, autoStealBtn} do
        createUICorner(btn, UDim.new(0,6))
        createUIStroke(btn, btn.BackgroundColor3:Lerp(Color3.new(0,0,0), 0.4), 1.5)
    end

    -- Connections
    baseA.MouseButton1Click:Connect(function() teleportSequence(Config.BaseATeleportPoints, warningLabel) end)
    baseB.MouseButton1Click:Connect(function() teleportSequence(Config.BaseBTeleportPoints, warningLabel) end)

    setPos.MouseButton1Click:Connect(function()
        updateCharacterCache()
        if State.humanoidRootPart then
            State.savedPosition = State.humanoidRootPart.CFrame
            createBeam(State.savedPosition.Position)
            setPos.Text = "POS SET"
            task.wait(0.5)
            setPos.Text = "SET POS"
        end
    end)

    forward.MouseButton1Click:Connect(function()
        updateCharacterCache()
        if State.humanoidRootPart then
            State.humanoidRootPart.CFrame = State.humanoidRootPart.CFrame * CFrame.new(0,0,-5)
        end
    end)

    clear.MouseButton1Click:Connect(function()
        clearSavedPosition()
        clear.Text = "CLEARED"
        task.wait(0.5)
        clear.Text = "CLEAR POS"
    end)

    -- CLICK TP
    clickTpBtn.MouseButton1Click:Connect(function()
        State.isClickTpEnabled = not State.isClickTpEnabled
        if State.isClickTpEnabled then
            clickTpBtn.Text = "CLICK TP: ON"
            clickTpBtn.BackgroundColor3 = Color3.fromRGB(50,255,50)
            local mouse = LocalPlayer:GetMouse()
            if State.clickTpConnection then State.clickTpConnection:Disconnect() end
            State.clickTpConnection = mouse.Button1Down:Connect(function()
                updateCharacterCache()
                if not State.humanoidRootPart then return end
                local hit = mouse.Hit
                if hit then
                    local destination = hit.Position + Vector3.new(0, 3, 0)
                    State.humanoidRootPart.CFrame = CFrame.new(destination)
                end
            end)
        else
            clickTpBtn.Text = "CLICK TP: OFF"
            clickTpBtn.BackgroundColor3 = Color3.fromRGB(100,200,100)
            if State.clickTpConnection then
                State.clickTpConnection:Disconnect()
                State.clickTpConnection = nil
            end
        end
    end)

    antiKnockbackBtn.MouseButton1Click:Connect(function()
        State.isAntiKnockbackEnabled = not State.isAntiKnockbackEnabled
        if State.isAntiKnockbackEnabled then
            antiKnockbackBtn.Text = "ANTI KB: ON"
            antiKnockbackBtn.BackgroundColor3 = Color3.fromRGB(50,255,50)
            enableAntiKnockback()
        else
            antiKnockbackBtn.Text = "ANTI KB: OFF"
            antiKnockbackBtn.BackgroundColor3 = Color3.fromRGB(200,100,50)
            disableAntiKnockback()
        end
    end)

    aimbotBtn.MouseButton1Click:Connect(function()
        State.isAimbotEnabled = not State.isAimbotEnabled
        if State.isAimbotEnabled then
            aimbotBtn.Text = "2D AIMBOT: ON"
            aimbotBtn.BackgroundColor3 = Color3.fromRGB(50,255,50)
            enableAimbot()
        else
            aimbotBtn.Text = "2D AIMBOT: OFF"
            aimbotBtn.BackgroundColor3 = Color3.fromRGB(255,50,255)
            disableAimbot()
        end
    end)

    autoStealBtn.MouseButton1Click:Connect(function()
        if not State.autoStealEnabled then
            enableAutoSteal()
            autoStealBtn.Text = "AUTO STEAL: ON"
            autoStealBtn.BackgroundColor3 = Color3.fromRGB(50,255,50)
        else
            disableAutoSteal()
            autoStealBtn.Text = "AUTO STEAL: OFF"
            autoStealBtn.BackgroundColor3 = Color3.fromRGB(255,150,50)
        end
    end)

    -- SMART TP TOGGLE
    smartTpBtn.MouseButton1Click:Connect(function()
        if not State.isSmartTpEnabled then
            enableSmartTp()
            smartTpBtn.Text = "SMART TP: ON"
            smartTpBtn.BackgroundColor3 = Color3.fromRGB(50,255,50)
        else
            disableSmartTp()
            smartTpBtn.Text = "SMART TP: OFF"
            smartTpBtn.BackgroundColor3 = Color3.fromRGB(150,150,150)
        end
    end)
end

-- ==================== PROXIMITY PROMPT HANDLER ====================
local function setupProximityPromptHandler()
    if not ProximityPromptService then return end
    if State.promptConnection then State.promptConnection:Disconnect() end
    State.promptConnection = ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, player)
        if player ~= LocalPlayer then return end
        if not string.find(string.lower(prompt.ActionText or ""), "steal") then return end
        onStealCompleted()
    end)
end

-- ==================== INIT ====================
createMainGUI()
setupProximityPromptHandler()
addCleanup(cleanupAll)
