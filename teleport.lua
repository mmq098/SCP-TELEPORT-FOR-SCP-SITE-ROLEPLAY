-- SCP Teleport Menu (consolidated)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Character refs
local char, hrp, humanoid
local function updateCharacterVars()
    char = player.Character or player.CharacterAdded:Wait()
    hrp = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
end

-- Keep character references in sync across deaths/respawns
-- Clear refs on removing so handlers/teleport checks will call updateCharacterVars on next use
player.CharacterRemoving:Connect(function()
    char = nil
    hrp = nil
    humanoid = nil
end)

-- Ensure we update refs when character spawns (spawn in background to avoid blocking)
player.CharacterAdded:Connect(function()
    task.spawn(updateCharacterVars)
end)

-- Try initial population without blocking main thread
task.spawn(function()
    if player.Character then
        pcall(updateCharacterVars)
    end
end)

-- Submerge manager: централизованное создание/поддержка SubmergeGUI
local Submerge = {
    gui = nil,
    submergeBtnRef = nil,
    armUpBtnRef = nil,
    highlight = nil,
    noclipParts = {},
    submerged = false,
    animationPlaying = false,
    savedSubmergePosition = nil,
    originalCameraCFrame = nil,
    _conns = {}
}
local SUBMERGE_OFFSET = 6.45
local SUBMERGE_SWIM_SPEED = 20
local SUBMERGE_RISE_MULT = 1.1
local SUBMERGE_ANIM = "rbxassetid://536135263"

local function rebuildNoclipParts()
    Submerge.noclipParts = {}
    if char then
        for _, part in pairs(char:GetChildren()) do
            if part.Name == "Left Arm" or part.Name == "Right Arm" then
                table.insert(Submerge.noclipParts, part)
            end
        end
    end
end

local function toggleNoclip(state)
    if not char then return end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if table.find(Submerge.noclipParts, part) then
                part.CanCollide = false
            else
                part.CanCollide = not state
            end
        end
    end
end

function Submerge:destroyGui()
    -- disconnect runservice connections
    for k, v in pairs(self._conns) do
        pcall(function() if v and v.Connected then v:Disconnect() end end)
    end
    self._conns = {}
    if self.gui and self.gui.Parent then
        pcall(function() self.gui:Destroy() end)
    end
    -- destroy any created highlight to avoid leaving outlines after GUI destroyed
    pcall(function()
        if self.highlight and self.highlight.Parent then
            self.highlight:Destroy()
        end
    end)
    -- also defensively remove any leftover ScreenGui named SubmergeGUI in PlayerGui
    pcall(function()
        local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui")
        local old = pg:FindFirstChild("SubmergeGUI")
        if old and old.Parent then
            pcall(function() old:Destroy() end)
        end
    end)
    self.gui = nil
    self.submergeBtnRef = nil
    self.armUpBtnRef = nil
    self.highlight = nil
    self.submerged = false
    self.animationPlaying = false
    self.savedSubmergePosition = nil
    self.originalCameraCFrame = nil
end

function Submerge:createGui()
    -- avoid multiple copies
    if self.gui and self.gui.Parent then return self.gui end
    local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui")
    -- destroy stale
    local old = pg:FindFirstChild("SubmergeGUI")
    if old then pcall(function() old:Destroy() end) end

    local gui = Instance.new("ScreenGui")
    gui.Name = "SubmergeGUI"
    gui.ResetOnSpawn = false
    gui.Parent = pg

    local frame = Instance.new("Frame")
    frame.Name = "SubmergeMenu"
    frame.Parent = gui
    frame.Size = UDim2.new(0, 180, 0, 120)
    frame.Position = UDim2.new(0.5, -90, 0.5, -60)
    frame.BackgroundColor3 = Color3.fromRGB(36, 40, 60)
    frame.Active = true -- allow GUI to receive input
    -- use same corner radius as Full Chat toggle for visual consistency
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    -- Dragging
    local uis = game:GetService("UserInputService")
    local dragging = false
    local dragStart, startPos, dragInput

    frame.InputBegan:Connect(function(input)
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
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    uis.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local submergeBtn = Instance.new("TextButton")
    submergeBtn.Name = "SubmergeButton"
    submergeBtn.Parent = frame
    submergeBtn.Size = UDim2.new(1, -20, 0, 44)
    submergeBtn.Position = UDim2.new(0, 10, 0, 10)
    submergeBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 180)
    submergeBtn.TextColor3 = Color3.new(1, 1, 1)
    submergeBtn.Text = "Submerge"
    submergeBtn.Font = Enum.Font.GothamBold
    submergeBtn.TextSize = 18
    Instance.new("UICorner", submergeBtn).CornerRadius = UDim.new(0, 12)

    local armUpBtn = Instance.new("TextButton")
    armUpBtn.Name = "ArmUpButton"
    armUpBtn.Parent = frame
    armUpBtn.Size = UDim2.new(1, -20, 0, 44)
    armUpBtn.Position = UDim2.new(0, 10, 0, 64)
    armUpBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    armUpBtn.TextColor3 = Color3.new(1, 1, 1)
    armUpBtn.Text = "Arm Up: Off"
    armUpBtn.Font = Enum.Font.GothamBold
    armUpBtn.TextSize = 18
    Instance.new("UICorner", armUpBtn).CornerRadius = UDim.new(0, 12)

    local highlight = Instance.new("Highlight")
    highlight.Enabled = false
    -- make a subtle fill and a visible outline; render on top so it is always visible during submerge
    highlight.FillTransparency = 0.75
    highlight.FillColor = Color3.fromRGB(0, 45, 70)
    highlight.OutlineTransparency = 0
    highlight.OutlineColor = Color3.fromRGB(0, 200, 255)
    pcall(function() highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)
    -- keep the Highlight instance in workspace and apply it to the character via Adornee when available
    highlight.Parent = workspace
    if char then
        pcall(function() highlight.Adornee = char end)
    end

    self.gui = gui
    self.submergeBtnRef = submergeBtn
    self.armUpBtnRef = armUpBtn
    self.highlight = highlight

    -- internal functions
    local camera = workspace.CurrentCamera
    local function doSubmerge()
        pcall(updateCharacterVars)
        if not hrp or not humanoid then return end
        self.originalCameraCFrame = camera.CFrame
        self.savedSubmergePosition = hrp.Position - Vector3.new(0, SUBMERGE_OFFSET, 0)
        rebuildNoclipParts()
        toggleNoclip(true)
        pcall(function() hrp.CFrame = CFrame.new(self.savedSubmergePosition) end)
        humanoid.PlatformStand = true
        if self.highlight then
            pcall(function()
                -- ensure the highlight adorns the current character
                if char then self.highlight.Adornee = char end
                self.highlight.Enabled = true
            end)
        end
        self.submerged = true
        if self.submergeBtnRef then pcall(function() self.submergeBtnRef.Text = "Rise Up" end) end
    end
    local function doSurface()
        pcall(updateCharacterVars)
        toggleNoclip(false)
        if humanoid then pcall(function() humanoid.PlatformStand = false end) end
        if hrp then pcall(function() hrp.CFrame = hrp.CFrame + Vector3.new(0, SUBMERGE_OFFSET * SUBMERGE_RISE_MULT, 0) end) end
        if self.highlight then pcall(function() self.highlight.Enabled = false end) end
        self.submerged = false
        if self.submergeBtnRef then pcall(function() self.submergeBtnRef.Text = "Submerge" end) end
        if self.originalCameraCFrame then pcall(function() camera.CFrame = self.originalCameraCFrame end) end
    end

    -- arm up animation
    local animation = Instance.new("Animation")
    animation.AnimationId = SUBMERGE_ANIM
    local function toggleArmUpLocal()
        pcall(updateCharacterVars)
        if not humanoid then return end
        if self.animationPlaying then
            if self.animationTrack then pcall(function() self.animationTrack:Stop() end) end
            self.animationPlaying = false
            if self.armUpBtnRef then pcall(function() self.armUpBtnRef.Text = "Arm Up: Off" end) end
        else
            self.animationPlaying = true
            local ok, animator = pcall(function() return humanoid:FindFirstChild("Animator") end)
            if ok and animator then
                pcall(function()
                    self.animationTrack = animator:LoadAnimation(animation)
                    self.animationTrack.Looped = false
                end)
                spawn(function()
                    while self.animationPlaying do
                        if self.animationTrack then pcall(function() self.animationTrack:Play(); self.animationTrack.TimePosition = 0.2 end) end
                        task.wait(0.03)
                    end
                end)
            end
            if self.armUpBtnRef then pcall(function() self.armUpBtnRef.Text = "Arm Up: On" end) end
        end
    end

    -- connect buttons
    submergeBtn.MouseButton1Click:Connect(function()
        if not Submerge.submerged then doSubmerge() else doSurface() end
    end)
    armUpBtn.MouseButton1Click:Connect(toggleArmUpLocal)

    -- runtime connections
    self._conns.Stepped = RunService.Stepped:Connect(function()
        if Submerge.submerged then rebuildNoclipParts(); toggleNoclip(true) end
    end)
    self._conns.RenderStepped = RunService.RenderStepped:Connect(function()
        if Submerge.submerged then
            pcall(function()
                if hrp and Submerge.savedSubmergePosition then
                    hrp.CFrame = CFrame.new(hrp.Position.X, Submerge.savedSubmergePosition.Y, hrp.Position.Z)
                    if humanoid then hrp.Velocity = humanoid.MoveDirection * SUBMERGE_SWIM_SPEED end
                end
            end)
        end
    end)

    -- ensure CharacterAdded refreshes references
    player.CharacterAdded:Connect(function()
        task.spawn(function()
            pcall(updateCharacterVars)
            rebuildNoclipParts()
            -- update the highlight's adornee to the new character instead of reparenting
            if Submerge.highlight and char then
                pcall(function() Submerge.highlight.Adornee = char end)
            end
        end)
    end)

    return gui
end

function Submerge:ensureGui(recreate)
    if recreate then self:destroyGui() end
    if self.gui and self.gui.Parent then return self.gui end
    return self:createGui()
end

-- Config
local flySpeed = 60
local function getTeleportSpeed() return flySpeed end
local UNDERGROUND_OFFSET = 7

-- helper: whether the game loop is running (returns false when paused in Studio)
local function gameplayRunning()
    local ok, running = pcall(function() return RunService:IsRunning() end)
    if not ok then return true end -- if call fails, assume running
    return running
end

-- Moderator detection
local MOD_GROUP_ID = 2935212
local MOD_ROLES = {
    ["Moderator"] = true,
    ["Admin"] = true,
    ["Game Moderation and Administration"] = true,
    ["Management"] = true,
    ["Developer"] = true,
    ["Lead Developer"] = true,
    ["Owner"] = true
}
local function isModerator(plr)
    if not plr then return false end
    local ok, inGroup = pcall(function() return plr:IsInGroup(MOD_GROUP_ID) end)
    if not ok or not inGroup then return false end
    local ok2, role = pcall(function() return plr:GetRoleInGroup(MOD_GROUP_ID) end)
    if not ok2 or not role then return false end
    return MOD_ROLES[role] == true
end
local function checkModerators()
    for _, p in ipairs(Players:GetPlayers()) do if isModerator(p) then return p end end
    return nil
end
local function showModeratorWarning(modPlayer)
    if not player or not player.Parent then return end
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return end
    local existing = pg:FindFirstChild("WarnModeratorGUI")
    if existing then pcall(function() existing:Destroy() end) end
    local warnGui = Instance.new("ScreenGui")
    warnGui.Name = "WarnModeratorGUI"
    warnGui.ResetOnSpawn = false
    warnGui.Parent = pg
    local warnFrame = Instance.new("Frame", warnGui)
    warnFrame.Position = UDim2.new(0.5, -160, 0, 40)
    warnFrame.Size = UDim2.new(0, 320, 0, 60)
    warnFrame.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    warnFrame.ZIndex = 100
    local warnCorner = Instance.new("UICorner", warnFrame)
    warnCorner.CornerRadius = UDim.new(0, 16)
    local warnLabel = Instance.new("TextLabel", warnFrame)
    warnLabel.Size = UDim2.new(1, 0, 1, 0)
    warnLabel.BackgroundTransparency = 1
    warnLabel.Font = Enum.Font.SourceSansBold
    warnLabel.TextSize = 18
    warnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    -- determine a readable name for the moderator (prefer DisplayName, fallback to Name)
    local modName = "<unknown>"
    if modPlayer then
        -- use pcall to avoid any unexpected runtime errors reading properties
        local okDisp, disp = pcall(function() return modPlayer.DisplayName end)
        local okName, nm = pcall(function() return modPlayer.Name end)
        if okDisp and type(disp) == "string" and disp:match("%S") then
            modName = disp
        elseif okName and type(nm) == "string" and nm:match("%S") then
            modName = nm
        end
    end
    warnLabel.Text = "На сервере обнаружен модератор: " .. modName
    warnLabel.TextWrapped = true
    task.spawn(function() task.wait(6) pcall(function() warnGui:Destroy() end) end)
end

task.spawn(function()
    while true do
        local mod = checkModerators()
        if mod then showModeratorWarning(mod) end
        task.wait(2)
    end
end)

-- Locations
local LOCATIONS = {
    ["SCP-008"] = {pos = Vector3.new(-133.11, 5.57, 845.59), num = 8},
    ["SCP-017"] = {pos = Vector3.new(540.68, 5.45, 1351.60), num = 17},
    ["SCP-034"] = {pos = Vector3.new(-124.36, 5.57, 1134.73), num = 34},
    ["SCP-035"] = {pos = Vector3.new(-252.75, 5.57, 859.39), num = 35},
    ["SCP-049"] = {pos = Vector3.new(387.36, 5.57, 708.16), num = 49},
    ["SCP-087"] = {pos = Vector3.new(-128.73, 5.50, 712.92), num = 87},
    ["SCP-076"] = {pos = Vector3.new(1226.84, -221.18, 1576.31), num = 91},
    ["SCP-093"] = {pos = Vector3.new(-167.06, 5.57, 1047.45), num = 93},
    ["SCP-096"] = {pos = Vector3.new(1525.80, -189.15, 974.98), num = 96},
    ["SCP-106"] = {pos = Vector3.new(1127.61, -224.65, 783.97), num = 106},
    ["SCP-120"] = {pos = Vector3.new(-172.59, 5.50, 724.95), num = 120},
    ["SCP-173"] = {pos = Vector3.new(-157.62, 19.57, 940.96), num = 173},
    ["SCP-178"] = {pos = Vector3.new(-2.99, 5.50, 559.65), num = 178},
    ["SCP-207"] = {pos = Vector3.new(-121.96, 5.50, 487.04), num = 207},
    ["SCP-224"] = {pos = Vector3.new(-15.52, 5.52, 737.85), num = 224},
    ["SCP-310"] = {pos = Vector3.new(-250.35, 5.57, 1020.30), num = 310},
    ["SCP-330"] = {pos = Vector3.new(-221.49, 5.52, 613.35), num = 330},
    ["SCP-394"] = {pos = Vector3.new(-56.80, 5.50, 355.44), num = 394},
    ["SCP-403"] = {pos = Vector3.new(-0.46, 5.50, 597.32), num = 403},
    ["SCP-409"] = {pos = Vector3.new(-270.71, 5.57, 929.73), num = 409},
    ["SCP-457"] = {pos = Vector3.new(190.71, 5.65, 1175.12), num = 457},
    ["SCP-517"] = {pos = Vector3.new(91.11, 5.50, 665.48), num = 517},
    ["SCP-569"] = {pos = Vector3.new(4.25, 5.57, 978.93), num = 569},
    ["SCP-610"] = {pos = Vector3.new(1680.18, -201.93, 1260.38), num = 610},
    ["SCP-701"] = {pos = Vector3.new(-30.51, 15.57, 1199.67), num = 701},
    ["SCP-714"] = {pos = Vector3.new(-3.12, 5.50, 475.03), num = 714},
    ["SCP-860"] = {pos = Vector3.new(26.12, 5.50, 732.43), num = 860},
    ["SCP-914"] = {pos = Vector3.new(-78.02, 5.50, 643.57), num = 914},
    ["SCP-939"] = {pos = Vector3.new(741.42, 5.70, 1220.81), num = 953},
    ["SCP-963"] = {pos = Vector3.new(63.67, -2.15, 250.23), num = 963},
    ["SCP-999"] = {pos = Vector3.new(-61.66, 4.30, 573.70), num = 999},
    ["SCP-2521"] = {pos = Vector3.new(-24.32, 5.57, 1056.30), num = 0},
    ["SCP-1025"] = {pos = Vector3.new(10.60, 5.50, 638.69), num = 1025},
    ["SCP-1056"] = {pos = Vector3.new(-146.83, 5.50, 644.00), num = 1056},
    ["SCP-1139"] = {pos = Vector3.new(-109.08, 5.50, 566.36), num = 1139},
    ["SCP-1162"] = {pos = Vector3.new(-117.31, 5.57, 1139.00), num = 1162},
    ["SCP-1193"] = {pos = Vector3.new(93.18, 5.50, 592.32), num = 1193},
    ["SCP-1499"] = {pos = Vector3.new(-2.99, 5.50, 559.65), num = 1499},
    ["SCP-1499(Pocket Dimension)"] = {pos = Vector3.new(-24.95, 7.52, 8404.07), num = 2000},
    ["SCP-2006"] = {pos = Vector3.new(502.65, 5.57, 588.81), num = 2006},
    ["SCP-2059"] = {pos = Vector3.new(-52.13, 5.57, 974.38), num = 2059},
    ["D-Block"] = {pos = Vector3.new(-356.76, -1.50, 517.23), num = 9999},
    ["D-block(safe)"] = {pos = Vector3.new(-346.43, 15.74, 550.83), num = 9999},
    ["Generator"] = {pos = Vector3.new(-233.49, 4.44, 195.04), num = 9998},
    ["Chaos Insurgency"] = {pos = Vector3.new(231.91, 49.23, 268.73), num = 9997},
    ["Pocket Dimension"] = {pos = Vector3.new(5792.15, 2.50, 5520.05), num = 9997},
    ["Cont X"] = {pos = Vector3.new(73.68, 5.57, 1026.36), num = 9996},
    ["Cont X(end)"] = {pos = Vector3.new(438.15, 5.57, 1024.55), num = 9996},
    ["Nuke"] = {pos = Vector3.new(525.98, 5.65, 1023.73), num = 9995},
    ["Bunker"] = {pos = Vector3.new(-65.87, -100.12, 779.99), num = 9994},
    ["Reality Core"] = {pos = Vector3.new(658.00, 5.57, 1024.07), num = 9996},
    ["Pumps"] = {pos = Vector3.new(-407.21, 4.31, 210.67), num = 9994},
    ["Arsenal"] = {pos = Vector3.new(91.89, 5.64, 475.40), num = 9993},
    ["Arsenal 2"] = {pos = Vector3.new(-40.87, 5.62, 811.13), num = 9992},
    ["Surface"] = {pos = Vector3.new(607.02, 163.87, 489.42), num = 9991},
    ["Admin room"] = {pos = Vector3.new(747.07, -28.94, 252.56), num = 9990}
}

-- Build sorted list once
local sortedNames = {}
for name, data in pairs(LOCATIONS) do table.insert(sortedNames, {name = name, num = data.num}) end
table.sort(sortedNames, function(a, b)
    if a.num == b.num then return a.name < b.name end
    return a.num < b.num
end)

-- Additional custom FAST location (not part of sortedNames; appended as bottom FAST)
LOCATIONS["FAST SCP-409"] = {pos = Vector3.new(-226.36, 5.33, 961.34), num = 9991}
LOCATIONS["FAST SCP-403"] = {pos = Vector3.new(1.52, 5.50, 616.29), num = 9990}
LOCATIONS["FAST SCP-034"] = {pos = Vector3.new(-134.13, 5.57, 1150.41), num = 9989}
-- Ensure FAST Gun uses the coordinates provided (BP / custom)
LOCATIONS["FAST Gun"] = {pos = Vector3.new(266.76, 49.23, 269.42), num = 9988}

-- Smooth teleport (with fallback instant)
local function smoothTeleport(destination)
    if not gameplayRunning() then return end
    if not char or not hrp or not humanoid then updateCharacterVars() end
    if not char or not hrp or not humanoid then return end

    local originalState = humanoid:GetState()
    local originalCollisions = {}
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            originalCollisions[part] = part.CanCollide
            part.CanCollide = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    local startPos = hrp.Position
    local undergroundPos = Vector3.new(startPos.X, destination.Y - UNDERGROUND_OFFSET, startPos.Z)

    for i = 1, 10 do
        hrp.CFrame = CFrame.new(startPos:Lerp(undergroundPos, i/10))
        task.wait(0.02)
    end

    local distance = (destination - startPos).Magnitude
    local duration = math.max(0.01, distance / getTeleportSpeed())
    local startTime = os.clock()

    local finished = false
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local progress = math.min((os.clock() - startTime) / duration, 1)
        local currentPos = undergroundPos:Lerp(Vector3.new(destination.X, destination.Y - UNDERGROUND_OFFSET, destination.Z), progress)
        hrp.CFrame = CFrame.new(currentPos)
        if progress >= 1 and not finished then
            finished = true
            conn:Disconnect()
            hrp.CFrame = CFrame.new(destination.X, destination.Y - UNDERGROUND_OFFSET, destination.Z)
            local steps = 30
            for i = 1, steps do
                local t = i / steps
                local smoothT = math.sin(t * math.pi / 2)
                local yPos = (destination.Y - UNDERGROUND_OFFSET) + (UNDERGROUND_OFFSET * smoothT)
                hrp.CFrame = CFrame.new(destination.X, yPos, destination.Z)
                for part, canCollide in pairs(originalCollisions) do part.CanCollide = canCollide end
                task.wait(0.02)
            end
            hrp.CFrame = CFrame.new(destination)
            for part, canCollide in pairs(originalCollisions) do part.CanCollide = canCollide end
            humanoid:ChangeState(originalState)
        end
    end)
end

-- UI cleanup: remove any previous known GUIs to avoid duplicates
for _, g in ipairs(playerGui:GetChildren()) do
    if g:IsA("ScreenGui") and (g.Name == "VenuxUI" or g.Name == "TeleportGUI" or g.Name == "WarnModeratorGUI") then
        pcall(function() g:Destroy() end)
    end
end

-- Create single Venux-style UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VenuxUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = playerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 560, 0, 360)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BackgroundTransparency = 0.18
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
--MainFrame.Draggable = true  -- заменено на ручную реализацию ниже
MainFrame.Parent = ScreenGui

-- Manual drag implementation using UserInputService (replaces Draggable)
local UserInputService = game:GetService("UserInputService")
local frame = MainFrame -- главное окно меню
local dragging = false
local dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

frame.InputBegan:Connect(function(input)
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

frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

local Title = Instance.new("TextLabel", MainFrame)
Title.Text = "SCP Teleport Menu"
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Title.BackgroundTransparency = 0.25
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 20

local Tabs = {"TELEPORT", "MISC", "GUN", "LOCAL", "SETTINGS"}
local ButtonsFrame = Instance.new("Frame", MainFrame)
ButtonsFrame.Size = UDim2.new(0, 120, 1, -40)
ButtonsFrame.Position = UDim2.new(0, 0, 0, 40)
ButtonsFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
ButtonsFrame.BackgroundTransparency = 0.18

local ContentFrame = Instance.new("Frame", MainFrame)
ContentFrame.Size = UDim2.new(1, -120, 1, -40)
ContentFrame.Position = UDim2.new(0, 120, 0, 40)
ContentFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
ContentFrame.BackgroundTransparency = 0.18

for i, tabName in ipairs(Tabs) do
    local TabButton = Instance.new("TextButton")
    TabButton.Name = tabName
    TabButton.Size = UDim2.new(1, 0, 0, 40)
    TabButton.Position = UDim2.new(0, 0, 0, (i - 1) * 40)
    TabButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    TabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabButton.Font = Enum.Font.SourceSans
    TabButton.TextSize = 18
    TabButton.Text = tabName
    TabButton.Parent = ButtonsFrame
    Instance.new("UICorner", TabButton).CornerRadius = UDim.new(0, 4)
end

local function updateTabButtonStyle(button, isSelected)
    if isSelected then
        button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    else
        button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    end
end
for _, name in ipairs(Tabs) do
    local b = ButtonsFrame:FindFirstChild(name)
    if b then updateTabButtonStyle(b, false) end
end
updateTabButtonStyle(ButtonsFrame:FindFirstChild("TELEPORT"), true)

local tabFillers
local function fillTeleportTab()
    ContentFrame:ClearAllChildren()
    -- Scroll with teleport buttons (FAST buttons will be regular entries in the list)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -10)
    scroll.Position = UDim2.new(0, 5, 0, 5)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 8
    scroll.Parent = ContentFrame

    local uiList = Instance.new("UIListLayout", scroll)
    uiList.Padding = UDim.new(0, 8)
    uiList.SortOrder = Enum.SortOrder.LayoutOrder

    local function instantTeleportTo(name)
        local data = LOCATIONS[name]
        if data and data.pos then
            if not char or not hrp then updateCharacterVars() end
            if hrp then pcall(function() hrp.CFrame = CFrame.new(data.pos) end) end

            -- short freeze for FAST teleports to avoid server anti-cheat snapping back
            if type(name) == "string" and name:sub(1,4) == "FAST" then
                if not humanoid then updateCharacterVars() end
                if humanoid then
                    local ok1, prevWalk = pcall(function() return humanoid.WalkSpeed end)
                    local ok2, prevJump = pcall(function() return humanoid.JumpPower end)
                    prevWalk = (ok1 and prevWalk) or 16
                    prevJump = (ok2 and prevJump) or 50
                    -- set reduced movement instead of full freeze so player can pick up items
                    local reducedWalk = math.max(1, prevWalk * 0.25)
                    local reducedJump = math.max(0, prevJump * 0.5)
                    pcall(function()
                        humanoid.WalkSpeed = reducedWalk
                        humanoid.JumpPower = reducedJump
                        if hrp and hrp:IsA("BasePart") then
                            hrp.Velocity = Vector3.new(0, 0, 0)
                        end
                    end)
                    task.delay(1, function()
                        pcall(function()
                            humanoid.WalkSpeed = prevWalk
                            humanoid.JumpPower = prevJump
                        end)
                    end)
                end
            end
        end
    end

    -- create FAST entries as regular buttons in the scroll (LayoutOrder 1..3)
    local function makeFastEntry(order, text, nameKey)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 36)
        btn.LayoutOrder = order
        btn.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 16
        btn.Text = text
        btn.Parent = scroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        btn.MouseButton1Click:Connect(function() instantTeleportTo(nameKey) end)
    end

    -- FAST entries will be appended after the normal list (created later with higher LayoutOrder)

    local function updateCanvas()
        scroll.CanvasSize = UDim2.new(0, 0, 0, uiList.AbsoluteContentSize.Y + 12)
    end
    uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

    for idx, info in ipairs(sortedNames) do
        local name = info.name
        local data = LOCATIONS[name]
        if data and data.pos then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -12, 0, 36)
            btn.LayoutOrder = idx
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Font = Enum.Font.SourceSans
            btn.TextSize = 16
            btn.Text = name
            btn.Parent = scroll
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
            btn.MouseButton1Click:Connect(function()
                if not gameplayRunning() then return end
                if smoothTeleport then
                    smoothTeleport(data.pos)
                else
                    if not char or not hrp then updateCharacterVars() end
                    if hrp then hrp.CFrame = CFrame.new(data.pos) end
                end
            end)
        end
    end
    updateCanvas()
    -- debug: сколько кнопок создано
    pcall(function()
        local count = 0
        for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextButton") then count = count + 1 end end
        print("[Teleport] buttons created:", count)
    end)

    -- append FAST buttons at the bottom
    local baseOrder = #sortedNames + 1
    local function instantTeleportTo(name)
        local data = LOCATIONS[name]
        if data and data.pos then
            if not gameplayRunning() then return end
            if not char or not hrp then updateCharacterVars() end
            if hrp then pcall(function() hrp.CFrame = CFrame.new(data.pos) end) end
        end
    end
    local function makeBottomFast(i, text, key)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -12, 0, 36)
        b.LayoutOrder = baseOrder + (i - 1)
        b.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
        b.TextColor3 = Color3.fromRGB(255,255,255)
        b.Font = Enum.Font.SourceSans
        b.TextSize = 16
        b.Text = text
        b.Parent = scroll
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        if type(key) == "string" and key:sub(1,4) == "FAST" then
            b.MouseButton1Click:Connect(function()
                if not gameplayRunning() then return end
                local data = LOCATIONS[key]
                if not (data and data.pos) then return end
                if not char or not hrp then updateCharacterVars() end
                if not hrp then return end

                -- remove existing timer GUI if present
                pcall(function()
                    local existing = playerGui:FindFirstChild("FastTimerGUI")
                    if existing then existing:Destroy() end
                end)

                -- create timer GUI (2 seconds with milliseconds)
                local timerGui = Instance.new("ScreenGui")
                timerGui.Name = "FastTimerGUI"
                timerGui.ResetOnSpawn = false
                timerGui.Parent = playerGui

                local timerLabel = Instance.new("TextLabel")
                timerLabel.Size = UDim2.new(0, 240, 0, 48)
                timerLabel.Position = UDim2.new(0.5, -120, 0.12, 0)
                timerLabel.BackgroundColor3 = Color3.fromRGB(30,30,30)
                timerLabel.BackgroundTransparency = 0.12
                timerLabel.TextColor3 = Color3.fromRGB(230,230,230)
                timerLabel.Font = Enum.Font.SourceSansBold
                timerLabel.TextSize = 22
                timerLabel.Text = "1.800"
                timerLabel.Parent = timerGui
                Instance.new("UICorner", timerLabel).CornerRadius = UDim.new(0,8)

                local duration = 1.8
                local startTime = tick()
                -- update timer in background
                task.spawn(function()
                    while true do
                        local now = tick()
                        local elapsed = now - startTime
                        local remaining = math.max(0, duration - elapsed)
                        timerLabel.Text = string.format("%.3f", remaining)
                        if remaining <= 0 then
                            timerLabel.Text = "бери"
                            break
                        end
                        task.wait(0.03)
                    end
                end)

                -- perform teleport + anchor routine
                local targetCf = CFrame.new(data.pos)
                pcall(function() hrp.CFrame = targetCf end)
                pcall(function() hrp.Anchored = true end)
                local initialFreezeTime = 1.5
                local postFreezeTime = 3
                print("[FAST] Anchored at ", tostring(targetCf), ". Waiting ", initialFreezeTime)
                task.spawn(function()
                    -- wait while respecting pause: sleep in small increments and check gameplayRunning
                    local waited = 0
                    while waited < initialFreezeTime do
                        if not gameplayRunning() then
                            task.wait(0.2)
                        else
                            task.wait(0.1)
                            waited = waited + 0.1
                        end
                    end
                    pcall(function() hrp.Anchored = false end)
                    print("[FAST] Unanchored. You can pick items now. Waiting post time", postFreezeTime)
                    -- post-wait while handling pause
                    local waited2 = 0
                    while waited2 < postFreezeTime do
                        if not gameplayRunning() then
                            task.wait(0.2)
                        else
                            task.wait(0.1)
                            waited2 = waited2 + 0.1
                        end
                    end
                    -- cleanup timer GUI when returning/finishing
                    pcall(function()
                        if timerGui and timerGui.Parent then timerGui:Destroy() end
                    end)
                end)
            end)
        else
            b.MouseButton1Click:Connect(function() instantTeleportTo(key) end)
        end
    end
    makeBottomFast(1, "FAST SCP-403", "FAST SCP-403")
    makeBottomFast(2, "FAST SCP-034", "FAST SCP-034")
    makeBottomFast(3, "FAST Gun", "FAST Gun")
    makeBottomFast(4, "FAST SCP-409", "FAST SCP-409")
    updateCanvas()
end

local function fillMiscTab()
    ContentFrame:ClearAllChildren()
    -- Кнопка Full Chat (оставляем как было)
    local toggle = Instance.new("TextButton", ContentFrame)
    toggle.Size = UDim2.new(0, 200, 0, 36)
    toggle.Position = UDim2.new(0, 20, 0, 20)
    toggle.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    toggle.TextColor3 = Color3.fromRGB(255,255,255)
    toggle.Font = Enum.Font.SourceSans
    toggle.TextSize = 16
    toggle.Text = "Включить Full Chat"
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 8)

    local forceLoop = nil
    local enabled = false
    local bubbleEnabled = true
    local function doEnable()
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
            StarterGui:SetCore("ChatActive", true)
        end)
        if TextChatService then
            pcall(function()
                TextChatService.ChatWindowConfiguration.Enabled = true
                TextChatService.ChatInputBarConfiguration.Enabled = true
                TextChatService.BubbleChatConfiguration.Enabled = bubbleEnabled
            end)
        end
    end
    toggle.MouseButton1Click:Connect(function()
        enabled = not enabled
        if enabled then
            toggle.Text = "Отключить Full Chat"
            bubbleEnabled = true
            doEnable()
            forceLoop = task.spawn(function()
                while enabled do
                    task.wait(3)
                    pcall(function()
                        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
                        StarterGui:SetCore("ChatActive", true)
                        if TextChatService then
                            TextChatService.ChatWindowConfiguration.Enabled = true
                            TextChatService.ChatInputBarConfiguration.Enabled = true
                            TextChatService.BubbleChatConfiguration.Enabled = bubbleEnabled
                        end
                    end)
                end
            end)
        else
            enabled = false
            toggle.Text = "Включить Full Chat"
            bubbleEnabled = false
            pcall(function()
                if TextChatService then
                    TextChatService.BubbleChatConfiguration.Enabled = false
                end
            end)
            forceLoop = nil
        end
    end)

    -- Кнопка Box (оставляем как было)
    local boxBtn = Instance.new("TextButton", ContentFrame)
    boxBtn.Size = UDim2.new(0, 200, 0, 36)
    boxBtn.Position = UDim2.new(0, 20, 0, 64)
    boxBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 140)
    boxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    boxBtn.Font = Enum.Font.SourceSans
    boxBtn.TextSize = 16
    boxBtn.Text = "Box"
    Instance.new("UICorner", boxBtn).CornerRadius = UDim.new(0, 8)
    -- Insert original Zaya invisibility script into the button (local scope)
    boxBtn.MouseButton1Click:Connect(function()
        task.spawn(function()
            -- Local copy of original script, with binds swapped to X (toggle) and Z (hold)
            local plr_local = Players.LocalPlayer
            local char_local = nil
            local hum_local = nil
            local anim_local = nil
            local isInvisible_local = false
            local isDead_local = true
            local ScriptRunning_local = true

            local invisSettings_local = { HipHeight = 0.3 }
            local defaultSettings_local = { HipHeight = 2.11 }

            local uis_local = game:GetService("UserInputService")

            local function safeDisplayLocal(msg)
                pcall(function()
                    if TextChatService and TextChatService.TextChannels and TextChatService.TextChannels.RBXGeneral then
                        TextChatService.TextChannels.RBXGeneral:DisplaySystemMessage(msg)
                    end
                end)
            end

            local function startmsgLocal()
                local msg = [[
    [Zaya's Invisibility Thing]
    -–—————————————————————————————–−
    Press X to Toggle invisibility.
    Hold Z to be invisible.
    Press F1 to quit this script.

    (Note: this message is not seen by other players, and this script only works in R15.)
    -–—————————————————————————————–−
                ]]
                safeDisplayLocal(msg)
            end

            local function byemsgLocal()
                safeDisplayLocal("Script stopped, Thanks for using Zaya's Invisibility Thing!")
            end

            local function resetLocal(ch)
                char_local = ch
                hum_local = char_local:WaitForChild("Humanoid")
                anim_local = Instance.new("Animation")
                anim_local.AnimationId = "rbxassetid://122954953446602"
                local ok, track = pcall(function() return hum_local:LoadAnimation(anim_local) end)
                if ok and track then
                    anim_local = track
                    pcall(function() anim_local:AdjustSpeed(0.01) end)
                    pcall(function() anim_local.Priority = Enum.AnimationPriority.Action4 end)
                end
                isDead_local = false
            end

            local function SetLocal(state)
                if isDead_local or not ScriptRunning_local then return end
                if state then
                    isInvisible_local = true
                    pcall(function() if anim_local then anim_local:Play() end end)
                    pcall(function() if hum_local then hum_local.HipHeight = invisSettings_local.HipHeight end end)
                else
                    isInvisible_local = false
                    pcall(function() if anim_local then anim_local:Stop() end end)
                    pcall(function() if hum_local then hum_local.HipHeight = defaultSettings_local.HipHeight end end)
                end
            end

            plr_local.CharacterAdded:Connect(function(ch) pcall(function() resetLocal(ch) end) end)

            if plr_local.Character then
                pcall(function() resetLocal(plr_local.Character) end)
            else
                plr_local.CharacterAdded:Wait()
                pcall(function() resetLocal(plr_local.Character) end)
            end

            pcall(function()
                hum_local.HealthChanged:Connect(function(h)
                    if h <= 1 and not isDead_local and ScriptRunning_local then
                        SetLocal(false)
                        isDead_local = true
                        if char_local and char_local.PrimaryPart then
                            pcall(function() char_local:SetPrimaryPartCFrame(CFrame.new(0,workspace.FallenPartsDestroyHeight/1.05,0)) end)
                        end
                    end
                end)
            end)

            uis_local.InputBegan:Connect(function(input, isChat)
                if isChat or isDead_local or not ScriptRunning_local then return end
                if input.KeyCode == Enum.KeyCode.X then
                    SetLocal(not isInvisible_local)
                elseif uis_local:IsKeyDown(Enum.KeyCode.Z) then
                    repeat
                        task.wait()
                        SetLocal(true)
                    until uis_local:IsKeyDown(Enum.KeyCode.Z) ~= true
                    SetLocal(false)
                elseif uis_local:IsKeyDown(Enum.KeyCode.F1) then
                    SetLocal(false)
                    ScriptRunning_local = false
                    byemsgLocal()
                end
            end)

            startmsgLocal()

            -- mobile button: try to create a simple local button if getgenv().mobile is true
            local okmobile, mobileFlag = pcall(function() return getgenv().mobile end)
            if okmobile and mobileFlag then
                task.spawn(function()
                    local mg = Instance.new("ScreenGui")
                    mg.Name = "ZayaMobileGUI"
                    mg.ResetOnSpawn = false
                    mg.Parent = playerGui
                    local btn = Instance.new("TextButton")
                    btn.Size = UDim2.new(0, 80, 0, 40)
                    btn.Position = UDim2.new(0.02, 0, 0.85, 0)
                    btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
                    btn.TextColor3 = Color3.fromRGB(255,255,255)
                    btn.Text = "X"
                    btn.Font = Enum.Font.SourceSansBold
                    btn.TextSize = 20
                    btn.Parent = mg
                    btn.MouseButton1Click:Connect(function()
                        SetLocal(not isInvisible_local)
                    end)
                end)
            end
        end)
    end)

    -- Submerge buttons (MISC)
    local submergeMenuBtn = Instance.new("TextButton", ContentFrame)
    submergeMenuBtn.Size = UDim2.new(0, 200, 0, 36)
    -- position to the right of Full Chat toggle (which is at 20,20 with width 200): 20 + 200 + 12 = 232
    submergeMenuBtn.Position = UDim2.new(0, 232, 0, 20)
    submergeMenuBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 180)
    submergeMenuBtn.TextColor3 = Color3.new(1, 1, 1)
    submergeMenuBtn.Text = "Submerge Menu"
    submergeMenuBtn.Font = Enum.Font.GothamBold
    submergeMenuBtn.TextSize = 18
    -- match Full Chat corner radius
    Instance.new("UICorner", submergeMenuBtn).CornerRadius = UDim.new(0, 8)

    -- single-button behavior: короткий клик -> toggle (open/close), удержание (>0.6s) -> force recreate
    do
        local holdStart = nil
        local HOLD_THRESHOLD = 0.6

        local function toggleOrEnsure()
            if Submerge.gui and Submerge.gui.Parent then
                Submerge:destroyGui()
            else
                Submerge:ensureGui()
            end
        end

        -- start timing on button down
        submergeMenuBtn.MouseButton1Down:Connect(function()
            holdStart = tick()
        end)

        -- handle click (fires after release). Use holdStart to detect long press.
        submergeMenuBtn.MouseButton1Click:Connect(function()
            local dur = 0
            if holdStart then dur = tick() - holdStart end
            holdStart = nil
            pcall(function()
                if dur >= HOLD_THRESHOLD then
                    -- long press: force recreate
                    Submerge:ensureGui(true)
                else
                    -- short click: toggle open/close
                    toggleOrEnsure()
                end
            end)
        end)
    end

    -- Кнопка AutoFarm
    local farmBtn = Instance.new("TextButton", ContentFrame)
    farmBtn.Size = UDim2.new(0, 200, 0, 36)
    farmBtn.Position = UDim2.new(0, 20, 0, 108)
    farmBtn.BackgroundColor3 = Color3.fromRGB(80, 140, 80)
    farmBtn.TextColor3 = Color3.fromRGB(255,255,255)
    farmBtn.Font = Enum.Font.SourceSans
    farmBtn.TextSize = 16
    farmBtn.Text = "AutoFarm"
    Instance.new("UICorner", farmBtn).CornerRadius = UDim.new(0, 8)

    -- Статус
    local status = Instance.new("TextLabel", ContentFrame)
    status.Size = UDim2.new(0, 200, 0, 20)
    status.Position = UDim2.new(0, 20, 0, 148)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.SourceSans
    status.TextSize = 14
    status.Text = "AutoFarm: OFF"
    status.TextColor3 = Color3.fromRGB(200,200,200)

    -- Implement a single on-screen countdown timer (shows time until next action)
    local autoTimerGui = nil
    local autoTimerLabel = nil
    local timerConn = nil
    local displayCountdown = nil

    local function ensureTimerGui()
        if not autoTimerGui or not autoTimerGui.Parent then
            autoTimerGui = Instance.new("ScreenGui")
            autoTimerGui.Name = "AutoFarmTimerGUI"
            autoTimerGui.ResetOnSpawn = false
            autoTimerGui.Parent = playerGui

            autoTimerLabel = Instance.new("TextLabel")
            autoTimerLabel.Size = UDim2.new(0, 140, 0, 28)
            autoTimerLabel.Position = UDim2.new(0.5, -70, 0.05, 0)
            autoTimerLabel.BackgroundColor3 = Color3.fromRGB(30,30,30)
            autoTimerLabel.BackgroundTransparency = 0.12
            autoTimerLabel.TextColor3 = Color3.fromRGB(200,200,255)
            autoTimerLabel.Font = Enum.Font.SourceSansBold
            autoTimerLabel.TextSize = 18
            autoTimerLabel.Text = "0.000"
            autoTimerLabel.Parent = autoTimerGui
            Instance.new("UICorner", autoTimerLabel).CornerRadius = UDim.new(0,6)
        end
    end

    local function startTimer()
        if timerConn then return end
        ensureTimerGui()
        timerConn = RunService.Heartbeat:Connect(function()
                if displayCountdown then
                    local remaining = displayCountdown - tick()
                    if remaining <= 0 then
                        displayCountdown = nil
                        if autoTimerLabel then pcall(function() autoTimerLabel.Text = "0.000" end) end
                        return
                    end
                    local s = math.floor(remaining)
                    local ms = math.floor((remaining - s) * 1000)
                    pcall(function()
                        if autoTimerLabel then autoTimerLabel.Text = string.format("%d.%03d", s, ms) end
                    end)
            else
                -- when not waiting, clear display
                if autoTimerLabel then pcall(function() autoTimerLabel.Text = "0.000" end) end
            end
        end)
    end

    local function stopTimer(reset)
    if timerConn then pcall(function() timerConn:Disconnect() end) end
    timerConn = nil
    displayCountdown = nil
        if reset then
            pcall(function()
                if autoTimerGui and autoTimerGui.Parent then autoTimerGui:Destroy() end
            end)
            autoTimerGui = nil
            autoTimerLabel = nil
        end
    end

    -- helper to wait while showing a countdown on the on-screen timer
    local function waitWithCountdown(seconds)
        if not seconds or seconds <= 0 then return end
        -- ensure timer GUI is present and heartbeat running
        startTimer()
        local target = tick() + seconds
        -- set displayCountdown for UI only
        displayCountdown = target
        -- immediate visual update for very short waits
        if autoTimerLabel then
            local remaining = target - tick()
            local s = math.floor(remaining)
            local ms = math.floor((remaining - s) * 1000)
            pcall(function() autoTimerLabel.Text = string.format("%d.%03d", s, ms) end)
        end
        while target - tick() > 0 do
            if not autoRunning then break end
            -- respect studio pause
            if not gameplayRunning() then
                task.wait(0.1)
            else
                task.wait(0.02)
            end
        end
        -- clear displayCountdown only if it still equals this target
        if displayCountdown and math.abs(displayCountdown - target) < 0.001 then displayCountdown = nil end
    end

    -- AutoFarm logic
    local autoRunning = false
    local autoThread = nil

    local function tpwalk2(targetPos)
        -- Плавное перемещение (tpwalk 2)
        if not char or not hrp or not humanoid then pcall(updateCharacterVars) end
        if not char or not hrp or not humanoid then return end
        local startPos = hrp.Position
        local duration = math.max(0.5, (targetPos - startPos).Magnitude / 40)
        local startTime = tick()
        -- show ETA on the on-screen timer
        pcall(function()
            startTimer()
            countdownEnd = tick() + duration
        end)
        local conn
        conn = RunService.Heartbeat:Connect(function()
            local t = math.min((tick() - startTime) / duration, 1)
            local pos = startPos:Lerp(targetPos, t)
            hrp.CFrame = CFrame.new(pos)
            if t >= 1 then
                conn:Disconnect()
                -- clear ETA display for this movement
                countdownEnd = nil
            end
        end)
        repeat task.wait(0.02) until not conn or not conn.Connected
    end

    local function pressE()
        -- Trigger all nearby ProximityPrompts using fireproximityprompt when available
        if not char or not hrp then pcall(updateCharacterVars) end
        local origin = hrp and hrp.Position or Vector3.new(0,0,0)
        local maxDist = 15 -- only trigger prompts reasonably close to player
        for _, v in pairs(workspace:GetDescendants()) do
            if v and v:IsA("ProximityPrompt") then
                -- try to get a position for the prompt's parent
                local ok, ppos = pcall(function()
                    if v.Parent and v.Parent:IsA("BasePart") then return v.Parent.Position end
                    if v.Parent and v.Parent.PrimaryPart and v.Parent.PrimaryPart:IsA("BasePart") then return v.Parent.PrimaryPart.Position end
                    return nil
                end)
                if not ok then ppos = nil end
                if not ppos or (ppos - origin).Magnitude <= maxDist then
                    pcall(function()
                        if type(fireproximityprompt) == "function" then
                            fireproximityprompt(v)
                        else
                            -- fallback: Input hold sequence
                            if v.InputHoldBegin then pcall(function() v:InputHoldBegin() end) end
                            task.wait(0.06)
                            if v.InputHoldEnd then pcall(function() v:InputHoldEnd() end) end
                        end
                    end)
                end
            end
        end
    end

    farmBtn.MouseButton1Click:Connect(function()
        autoRunning = not autoRunning
        if autoRunning then
            startTimer()
            farmBtn.Text = "AutoFarm: ON"
            status.Text = "AutoFarm: Включен"
            autoThread = task.spawn(function()
                while autoRunning do
                    pcall(function()
                        if not char or not hrp or not humanoid then updateCharacterVars() end
                        if not char or not hrp or not humanoid then status.Text = "Ожидание персонажа..." waitWithCountdown(1) return end
                        -- 1. Летим к первой точке
                        tpwalk2(Vector3.new(-430.80, -1.50, 400.75))
                        waitWithCountdown(0.2)
                        -- 2. Нажимаем E (берём предмет)
                        pressE()
                        status.Text = "Взял предмет, лечу ко 2-й точке..."
                        waitWithCountdown(0.2)
                        -- 3. Летим ко второй точке
                        tpwalk2(Vector3.new(-440.53, -1.50, 399.17))
                        status.Text = "Жду 9 сек..."
                        -- 4. Ждём 9 сек
                        waitWithCountdown(9)
                        -- 5. Нажимаем E
                        pressE()
                        status.Text = "Нажал E, жду 9 сек..."
                        waitWithCountdown(9)
                        -- 6. Нажимаем E
                        pressE()
                        status.Text = "Цикл повторяется..."
                        waitWithCountdown(0.5)
                        -- Дополнительная последовательность действий (walkfling-подобно)
                        if not autoRunning then return end
                        -- 1
                        status.Text = "Перемещаюсь к точке 1..."
                        tpwalk2(Vector3.new(-407.06, 3.12, 332.61))
                        waitWithCountdown(0.15)
                        pressE()
                        -- 2
                        if not autoRunning then return end
                        status.Text = "Перемещаюсь к точке 2..."
                        tpwalk2(Vector3.new(-393.22, 3.11, 334.50))
                        waitWithCountdown(0.15)
                        pressE()
                        -- 3
                        if not autoRunning then return end
                        status.Text = "Перемещаюсь к точке 3..."
                        tpwalk2(Vector3.new(-356.80, 3.57, 332.68))
                        waitWithCountdown(0.15)
                        pressE()
                        -- 4
                        if not autoRunning then return end
                        status.Text = "Перемещаюсь к точке 4..."
                        tpwalk2(Vector3.new(-371.09, 3.11, 334.15))
                        waitWithCountdown(0.15)
                        pressE()
                        -- 5 wait and press
                        if not autoRunning then return end
                        status.Text = "Перемещаюсь к точке 5... (жду 5 с)"
                        tpwalk2(Vector3.new(-357.55, 3.12, 327.12))
                        waitWithCountdown(0.15)
                        waitWithCountdown(5)
                        pressE()
                        -- возвращаемся к точке 4 и снова E
                        if not autoRunning then return end
                        status.Text = "Возвращаюсь к точке 4 и нажимаю E..."
                        tpwalk2(Vector3.new(-371.09, 3.11, 334.15))
                        waitWithCountdown(0.15)
                        pressE()
                    end)
                end
                farmBtn.Text = "AutoFarm"
                status.Text = "AutoFarm: OFF"
                stopTimer(true)
            end)
        else
            farmBtn.Text = "AutoFarm"
            status.Text = "AutoFarm: OFF"
            autoRunning = false
            stopTimer(true)
        end
    end)
end
local function fillGunTab()
    ContentFrame:ClearAllChildren()
    local title = Instance.new("TextLabel", ContentFrame)
    title.Size = UDim2.new(1, -40, 0, 28)
    title.Position = UDim2.new(0, 20, 0, 20)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 18
    title.Text = "GUN: Инструменты диагностики и локальный патч"
    title.TextColor3 = Color3.fromRGB(220,220,255)

    local dumpBtn = Instance.new("TextButton", ContentFrame)
    dumpBtn.Size = UDim2.new(0, 220, 0, 36)
    dumpBtn.Position = UDim2.new(0, 20, 0, 60)
    dumpBtn.BackgroundColor3 = Color3.fromRGB(80,80,140)
    dumpBtn.TextColor3 = Color3.fromRGB(255,255,255)
    dumpBtn.Font = Enum.Font.SourceSans
    dumpBtn.TextSize = 16
    dumpBtn.Text = "Dump Gun Info"
    Instance.new("UICorner", dumpBtn).CornerRadius = UDim.new(0,8)

    local patchBtn = Instance.new("TextButton", ContentFrame)
    patchBtn.Size = UDim2.new(0, 220, 0, 36)
    patchBtn.Position = UDim2.new(0, 20, 0, 108)
    patchBtn.BackgroundColor3 = Color3.fromRGB(80,140,80)
    patchBtn.TextColor3 = Color3.fromRGB(255,255,255)
    patchBtn.Font = Enum.Font.SourceSans
    patchBtn.TextSize = 16
    patchBtn.Text = "Apply Local Patch"
    Instance.new("UICorner", patchBtn).CornerRadius = UDim.new(0,8)

    local infoLabel = Instance.new("TextLabel", ContentFrame)
    infoLabel.Size = UDim2.new(1, -260, 0, 140)
    infoLabel.Position = UDim2.new(0, 260, 0, 60)
    infoLabel.BackgroundTransparency = 0.2
    infoLabel.BackgroundColor3 = Color3.fromRGB(30,30,30)
    infoLabel.TextColor3 = Color3.fromRGB(220,220,220)
    infoLabel.Font = Enum.Font.SourceSans
    infoLabel.TextWrapped = true
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.Text = "Статус: ожидает действия. Dump выведет информацию в Output/Chat. Patch применяет локальное подавление отдачи и rapid toggle."
    Instance.new("UICorner", infoLabel).CornerRadius = UDim.new(0,6)

    local function safePrint(...)
        local args = {...}
        pcall(function()
            print(table.unpack(args))
        end)
    end

    dumpBtn.MouseButton1Click:Connect(function()
        -- Try to locate the MainModule in ReplicatedStorage and print remotes/config keys
        local ok, main = pcall(function()
            return game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("MainModule")
        end)
        if not ok or not main then
            infoLabel.Text = "MainModule не найден в ReplicatedStorage.Guns"
            return
        end
        infoLabel.Text = "Выполняется дамп... смотрите Output"
        -- require in pcall to avoid errors
        local succ, mod = pcall(function() return require(main) end)
        if not succ or type(mod) ~= "table" then
            infoLabel.Text = "Не удалось require MainModule"
            return
        end

        -- print available functions on module
        safePrint("[GUN DUMP] module keys:")
        for k, v in pairs(mod) do safePrint("  ", k, type(v)) end

        -- attempt to find active tool
        local plr = Players.LocalPlayer
        local tool = plr and (plr.Character and plr.Character:FindFirstChildOfClass("Tool") or plr.Backpack:FindFirstChildOfClass("Tool"))
        if not tool then
            safePrint("[GUN DUMP] No Tool found in character or backpack.")
            infoLabel.Text = "No Tool found. Наденьте оружие и нажмите Dump снова."
            return
        end

        safePrint("[GUN DUMP] Tool:", tool.Name)
        local remotes = tool:FindFirstChild("Remotes")
        if remotes then
            for _, r in ipairs(remotes:GetChildren()) do
                safePrint("  Remote:", r.Name, r.ClassName)
            end
        else
            safePrint("  No Remotes folder on tool")
        end

        -- try to find GunConfiguration / config values
        local cfg = tool:FindFirstChild("GunConfiguration") or tool:FindFirstChild("Config")
        if cfg and cfg:IsA("ModuleScript") then
            local okc, conf = pcall(function() return require(cfg) end)
            if okc and type(conf) == "table" then
                safePrint("[GUN DUMP] Config keys:")
                for kk, vv in pairs(conf) do
                    if type(vv) ~= "table" then
                        safePrint("  ", kk, vv)
                    else
                        safePrint("  ", kk, "(table)")
                    end
                end
            else
                safePrint("[GUN DUMP] Failed to require config module")
            end
        else
            safePrint("[GUN DUMP] No GunConfiguration ModuleScript found on tool")
        end
        infoLabel.Text = "Dump завершён. Смотрите Output/Console для деталей."
    end)

    patchBtn.MouseButton1Click:Connect(function()
        infoLabel.Text = "Попытка применения локального патча..."
        -- Safe monkey-patch: wrap require(module).new to patch instances after Initialize
        local ok, main = pcall(function()
            return game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("MainModule")
        end)
        if not ok or not main then
            infoLabel.Text = "MainModule не найден в ReplicatedStorage.Guns"
            return
        end
        local succ, mod = pcall(function() return require(main) end)
        if not succ or type(mod) ~= "table" then
            infoLabel.Text = "Не удалось require MainModule"
            return
        end

        -- apply monkey patch by replacing new (best-effort)
        local orig_new = mod.new
        if type(orig_new) ~= "function" then
            infoLabel.Text = "MainModule.new не является функцией"
            return
        end
        mod.new = function(...)
            local inst = orig_new(...)
            -- try to intercept Initialize to apply changes after setup
            local okInit, origInit = pcall(function() return inst.Initialize end)
            if okInit and type(origInit) == "function" then
                inst.Initialize = function(self, ...)
                    origInit(self, ...)
                    pcall(function()
                        if self.firstPersonModule and type(self.firstPersonModule.ShootEffect) == "function" then
                            self.firstPersonModule.ShootEffect = function() end
                        end
                        if self.thirdPersonModule and type(self.thirdPersonModule.ShootEffect) == "function" then
                            self.thirdPersonModule.ShootEffect = function() end
                        end
                        -- add rapid toggle helper (local only)
                        if not self._localRapid then
                            self._localRapid = false
                            function self:SetLocalRapid(val)
                                self._localRapid = val
                                if val then
                                    spawn(function()
                                        while self._localRapid do
                                            if (self.allowShoot == nil or self.allowShoot) and (self.ammo or 0) > 0 then
                                                pcall(function()
                                                    if self.Shoot then self:Shoot() end
                                                end)
                                            end
                                            task.wait(1 / ((self.config and self.config.RateOfFire) and (self.config.RateOfFire / 60) or 10))
                                        end
                                    end)
                                end
                            end
                        end
                    end)
                end
            else
                pcall(function()
                    if inst.firstPersonModule and type(inst.firstPersonModule.ShootEffect) == "function" then
                        inst.firstPersonModule.ShootEffect = function() end
                    end
                    if inst.thirdPersonModule and type(inst.thirdPersonModule.ShootEffect) == "function" then
                        inst.thirdPersonModule.ShootEffect = function() end
                    end
                end)
            end
            return inst
        end

        infoLabel.Text = "Патч применён (локально). Наденьте оружие и используйте Rapid через консоль: obj:SetLocalRapid(true)"
    end)
end
local function fillLocalTab()
    ContentFrame:ClearAllChildren()
    local label = Instance.new("TextLabel", ContentFrame)
    label.Size = UDim2.new(1, -40, 0, 40)
    label.Position = UDim2.new(0, 20, 0, 20)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 20
    label.Text = "LOCAL: Ваши локальные функции."
    label.TextColor3 = Color3.fromRGB(220, 230, 255)
end
local function fillSettingsTab()
    ContentFrame:ClearAllChildren()
    local label = Instance.new("TextLabel", ContentFrame)
    label.Size = UDim2.new(1, -40, 0, 40)
    label.Position = UDim2.new(0, 20, 0, 20)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 20
    label.Text = "SETTINGS: настройки меню."
    label.TextColor3 = Color3.fromRGB(220, 230, 255)
end

tabFillers = {
    TELEPORT = fillTeleportTab,
    MISC = fillMiscTab,
    GUN = fillGunTab,
    LOCAL = fillLocalTab,
    SETTINGS = fillSettingsTab
}

local function onTabButtonClicked(tabName)
    for _, b in ipairs(ButtonsFrame:GetChildren()) do if b:IsA("TextButton") then updateTabButtonStyle(b, false) end end
    local currentButton = ButtonsFrame:FindFirstChild(tabName)
    if currentButton then updateTabButtonStyle(currentButton, true) end
    if tabFillers and tabFillers[tabName] then tabFillers[tabName]() end
end

for _, tname in ipairs(Tabs) do
    local b = ButtonsFrame:FindFirstChild(tname)
    if b then b.MouseButton1Click:Connect(function() onTabButtonClicked(tname) end) end
end

-- Close button
local CloseBtn = Instance.new("TextButton", MainFrame)
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 100, 0, 28)
CloseBtn.Position = UDim2.new(1, -110, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
CloseBtn.Text = "Закрыть"
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 16
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

-- Initial fill
if tabFillers and tabFillers.TELEPORT then tabFillers.TELEPORT() end

-- быстрые бинт Vector3.new(-250.72, 24.68, 740.76)
-- ну где там надо заходить с противовазом Vector3.new(-402.26, 27.96, 211.41)
