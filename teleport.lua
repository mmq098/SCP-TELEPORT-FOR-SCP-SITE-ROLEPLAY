-- ...existing code...

-- ...existing code...

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")



local flySpeed = 60
local flyEnabled = false
local WALK_SPEED = humanoid.WalkSpeed
-- === Проверка наличия модераторов на сервере ===

-- Укажите groupId вашей группы и список ролей модерации
local MOD_GROUP_ID = 2935212 -- пример groupId
local MOD_ROLES = {
    ["Moderator"] = true,
    ["Admin"] = true,
    ["Модератор"] = true,
    ["Админ"] = true,
    ["Game Moderation and Administration"] = true
}

local function isModerator(player)
    if player:IsInGroup(MOD_GROUP_ID) then
        local role = player:GetRoleInGroup(MOD_GROUP_ID)
        return MOD_ROLES[role] == true
    end
    return false
end

local function checkModerators()
    for _, plr in ipairs(Players:GetPlayers()) do
        if isModerator(plr) then
            return plr
        end
    end
    return nil
end


local function showModeratorWarning(modPlayer)
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    local warnGui = Instance.new("ScreenGui")
    warnGui.Name = "WarnModeratorGUI"
    warnGui.Parent = playerGui
    local warnFrame = Instance.new("Frame", warnGui)
    warnFrame.Position = UDim2.new(0.5, -160, 0, 40)
    warnFrame.Size = UDim2.new(0, 320, 0, 60)
    warnFrame.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    warnFrame.BackgroundTransparency = 0.1
    warnFrame.ZIndex = 100
    local warnCorner = Instance.new("UICorner", warnFrame)
    warnCorner.CornerRadius = UDim.new(0, 16)
    local warnLabel = Instance.new("TextLabel", warnFrame)
    warnLabel.Size = UDim2.new(1, 0, 1, 0)
    warnLabel.BackgroundTransparency = 1
    warnLabel.Font = Enum.Font.SourceSansBold
    warnLabel.TextSize = 20
    warnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    warnLabel.Text = "На сервере обнаружен модератор: " .. (modPlayer.DisplayName or modPlayer.Name)
    warnLabel.ZIndex = 101
    task.spawn(function()
        task.wait(6)
        warnGui:Destroy()
    end)
end

local function onPlayersChanged()
    local mod = checkModerators()
    if mod then
        showModeratorWarning(mod)
    end
end

local function getTeleportSpeed()
    return flySpeed
end
local UNDERGROUND_OFFSET = 7

-- Обновленный список точек телепорта с номерами для сортировки
local LOCATIONS = {
    ["SCP-008"] = {pos = Vector3.new(-133.11, 5.57, 845.59), num = 8},
    ["SCP-017"] = {pos = Vector3.new(420.84, 5.52, 1274.16), num = 17},
    ["SCP-035"] = {pos = Vector3.new(-252.75, 5.57, 859.39), num = 35},
    ["SCP-087"] = {pos = Vector3.new(-128.73, 5.50, 712.92), num = 87},
    ["SCP-093"] = {pos = Vector3.new(-167.06, 5.57, 1047.45), num = 93},
    ["SCP-106"] = {pos = Vector3.new(552.60, -142.10, 1816.60), num = 106},
    ["SCP-120"] = {pos = Vector3.new(-172.59, 5.50, 724.95), num = 120},
    ["SCP-173"] = {pos = Vector3.new(-157.62, 19.57, 940.96), num = 173},
    ["SCP-178"] = {pos = Vector3.new(-2.99, 5.50, 559.65), num = 178},
    ["SCP-207"] = {pos = Vector3.new(-121.96, 5.50, 487.04), num = 207},
    ["SCP-224"] = {pos = Vector3.new(-15.52, 5.52, 737.85), num = 224},
    ["SCP-310"] = {pos = Vector3.new(-250.35, 5.57, 1020.30), num = 310},
    ["SCP-330"] = {pos = Vector3.new(-221.49, 5.52, 613.35), num = 330},
    ["SCP-394"] = {pos = Vector3.new(-56.80, 5.50, 355.44), num = 394},
    ["SCP-403"] = {pos = Vector3.new(-0.46, 5.50, 597.32), num = 403},
    ["SCP-409"] = {pos = Vector3.new(-245.42, 5.57, 956.29), num = 409},
    ["SCP-457"] = {pos = Vector3.new(190.71, 5.65, 1175.12), num = 457},
    ["SCP-517"] = {pos = Vector3.new(91.11, 5.50, 665.48), num = 517},
    ["SCP-569"] = {pos = Vector3.new(4.25, 5.57, 978.93), num = 569},
    ["SCP-701"] = {pos = Vector3.new(-30.51, 15.57, 1199.67), num = 701},
    ["SCP-714"] = {pos = Vector3.new(-3.12, 5.50, 475.03), num = 714},
    ["SCP-860"] = {pos = Vector3.new(26.12, 5.50, 732.43), num = 860},
    ["SCP-914"] = {pos = Vector3.new(1.80, 5.50, 614.67), num = 914},
    ["SCP-999"] = {pos = Vector3.new(-61.61, 5.50, 575.88), num = 999},
    ["SCP-2521"] = {pos = Vector3.new(-24.32, 5.57, 1056.30), num = 0},
    ["SCP-1025"] = {pos = Vector3.new(10.60, 5.50, 638.69), num = 1025},
    ["SCP-1056"] = {pos = Vector3.new(-146.83, 5.50, 644.00), num = 1056},
    ["SCP-1139"] = {pos = Vector3.new(-109.08, 5.50, 566.36), num = 1139},
    ["SCP-1162"] = {pos = Vector3.new(-117.31, 5.57, 1139.00), num = 1162},
    ["SCP-1193"] = {pos = Vector3.new(93.18, 5.50, 592.32), num = 1193},
    ["SCP-1499"] = {pos = Vector3.new(-2.99, 5.50, 559.65), num = 1499},
    ["SCP-2059"] = {pos = Vector3.new(-52.13, 5.57, 974.38), num = 2059},
    ["D-Block"] = {pos = Vector3.new(-356.76, -1.50, 517.23), num = 9999},
    ["Generator"] = {pos = Vector3.new(-233.49, 4.44, 195.04), num = 9998},
    ["Pocket Dimension"] = {pos = Vector3.new(5792.15, 2.50, 5520.05), num = 9997},
    ["Cont X"] = {pos = Vector3.new(127.89, 5.65, 1024.25), num = 9996},
    ["Nuke"] = {pos = Vector3.new(525.98, 5.65, 1023.73), num = 9995},
    ["Pumps"] = {pos = Vector3.new(-407.21, 4.31, 210.67), num = 9994},
    ["Arsenal"] = {pos = Vector3.new(91.89, 5.64, 475.40), num = 9993},
    ["Arsenal 2"] = {pos = Vector3.new(-40.87, 5.62, 811.13), num = 9992}
}

-- Формируем отсортированный список имен для кнопок (без дубликатов и с корректной сортировкой)
local sortedNames = {}
for name, data in pairs(LOCATIONS) do
    table.insert(sortedNames, {name = name, num = data.num})
end
table.sort(sortedNames, function(a, b)
    -- Сначала по num, если равны — по алфавиту
    if a.num == b.num then
        return a.name < b.name
    end
    return a.num < b.num
end)

-- Функция плавного перемещения
local function smoothTeleport(destination)
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
    local duration = distance / getTeleportSpeed()
    local startTime = os.clock()

    local finished = false
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local progress = math.min((os.clock() - startTime) / duration, 1)
        local currentPos = undergroundPos:Lerp(
            Vector3.new(destination.X, destination.Y - UNDERGROUND_OFFSET, destination.Z),
            progress
        )
        hrp.CFrame = CFrame.new(currentPos)
        if progress >= 1 and not finished then
            finished = true
            conn:Disconnect()
            -- Явно ставим персонажа под землю перед подъемом
            hrp.CFrame = CFrame.new(destination.X, destination.Y - UNDERGROUND_OFFSET, destination.Z)

            -- Пауза и плавный подъем с коллизиями включенными
            local steps = 30
            for i = 1, steps do
                local t = i / steps
                local smoothT = math.sin(t * math.pi / 2)
                local yPos = (destination.Y - UNDERGROUND_OFFSET) + (UNDERGROUND_OFFSET * smoothT)
                hrp.CFrame = CFrame.new(destination.X, yPos, destination.Z)
                -- Включаем коллизии на этапе подъема, чтобы не провалиться
                for part, canCollide in pairs(originalCollisions) do
                    part.CanCollide = canCollide
                end
                task.wait(0.02)
            end
            hrp.CFrame = CFrame.new(destination)
            for part, canCollide in pairs(originalCollisions) do
                part.CanCollide = canCollide
            end
            humanoid:ChangeState(originalState)
        end
    end)
end

-- Создание интерфейса
local gui = Instance.new("ScreenGui")
gui.Name = "TeleportGUI"
gui.ResetOnSpawn = false -- Окно не будет закрываться после смерти
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 300, 0, 500)
frame.Position = UDim2.new(0.5, -150, 0.5, -250)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.Active = true
frame.Draggable = false -- отключаем стандартное перетаскивание
local frameCorner = Instance.new("UICorner", frame)
frameCorner.CornerRadius = UDim.new(0, 16)

-- Title bar with close button
local titleBar = Instance.new("Frame", frame)
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
titleBar.BorderSizePixel = 0
-- Кастомное перетаскивание окна по заголовку
local dragging = false
local dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)
titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
local titleBarCorner = Instance.new("UICorner", titleBar)
titleBarCorner.CornerRadius = UDim.new(0, 12)

-- Обычный белый заголовок "SCP Teleport .0"
local titleWhite = Instance.new("TextLabel", titleBar)
titleWhite.Size = UDim2.new(1, -30, 1, 0)
titleWhite.Position = UDim2.new(0, 5, 0, 0)
titleWhite.BackgroundTransparency = 1
titleWhite.Font = Enum.Font.SourceSansBold
titleWhite.TextSize = 18
titleWhite.TextXAlignment = Enum.TextXAlignment.Left
titleWhite.Text = "SCP Teleport v2.4"
titleWhite.TextColor3 = Color3.fromRGB(255, 255, 255)
titleWhite.Name = "TitleWhite"

-- Кнопка закрытия
local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 30, 1, 0)
closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 0.3, 0.3)
closeBtn.BackgroundTransparency = 1
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 18
closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)
local closeBtnCorner = Instance.new("UICorner", closeBtn)
closeBtnCorner.CornerRadius = UDim.new(0, 8)

local scroll = Instance.new("ScrollingFrame", frame)
scroll.Size = UDim2.new(1, 0, 1, -30)
scroll.Position = UDim2.new(0, 0, 0, 30)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 6
local scrollCorner = Instance.new("UICorner", scroll)
scrollCorner.CornerRadius = UDim.new(0, 12)

local list = Instance.new("UIListLayout", scroll)
list.Padding = UDim.new(0, 5)

-- Создание кнопок в порядке сортировки по номеру
-- Сортируем список объектов по номеру
table.sort(sortedNames, function(a, b)
    return a.num < b.num
end)

for _, item in ipairs(sortedNames) do
    local name = item.name
    local pos = LOCATIONS[name].pos
    local button = Instance.new("TextButton", scroll)
    button.Size = UDim2.new(0.95, 0, 0, 40)
    button.Position = UDim2.new(0.025, 0, 0, 0)
    button.Text = name
    button.TextColor3 = Color3.new(1, 1, 1)
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    button.Font = Enum.Font.SourceSans
    button.TextSize = 16
    button.MouseButton1Click:Connect(function()
        smoothTeleport(pos + Vector3.new(0, 1.5, 0))
    end)
    local buttonCorner = Instance.new("UICorner", button)
    buttonCorner.CornerRadius = UDim.new(0, 10)
end

-- Кнопка "Freeze & Unfreeze" для взятия предмета
local freezeBtn = Instance.new("TextButton", scroll)
freezeBtn.Size = UDim2.new(0.95, 0, 0, 40)
freezeBtn.Position = UDim2.new(0.025, 0, 0, 0)
freezeBtn.Text = "FAST SCP 403"
freezeBtn.TextColor3 = Color3.new(1, 1, 1)
freezeBtn.BackgroundColor3 = Color3.fromRGB(70, 50, 50)
freezeBtn.Font = Enum.Font.SourceSansBold
freezeBtn.TextSize = 16
freezeBtn.MouseButton1Click:Connect(function()
    local targetCFrame = CFrame.new(1.52, 5.50, 616.29) -- координаты камеры
    local initialFreezeTime = 1.5 -- время первоначальной фиксации
    local postFreezeTime = 3 -- время после разморозки для взятия предмета
    hrp.CFrame = targetCFrame
    hrp.Anchored = true
    print("[INFO] Персонаж зафиксирован. Ждем "..initialFreezeTime.." секунд...")
    task.wait(initialFreezeTime)
    hrp.Anchored = false
    print("[INFO] Персонаж разморожен, можно брать предмет.")
    task.wait(postFreezeTime)
end)
local freezeBtnCorner = Instance.new("UICorner", freezeBtn)
freezeBtnCorner.CornerRadius = UDim.new(0, 10)

-- Авторазмер контента
list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 10)
end)

-- === Вкладка "Настройки" и панель настроек ===


-- Кнопка "Настройки" рядом с кнопкой закрытия
local settingsTab = Instance.new("TextButton", titleBar)
settingsTab.Size = UDim2.new(0, 90, 1, 0)
settingsTab.Position = UDim2.new(1, -120, 0, 0)
settingsTab.Text = "Settings"
settingsTab.TextColor3 = Color3.fromRGB(180, 200, 255)
settingsTab.BackgroundTransparency = 1
settingsTab.Font = Enum.Font.SourceSansBold
settingsTab.TextSize = 16
local settingsTabCorner = Instance.new("UICorner", settingsTab)
settingsTabCorner.CornerRadius = UDim.new(0, 8)

-- Панель настроек (отдельный слой, поверх основного меню)
local settingsPanel = Instance.new("Frame", gui)
settingsPanel.Size = UDim2.new(0, 320, 0, 260)
settingsPanel.Position = UDim2.new(0.5, -160, 0.5, -130)
settingsPanel.BackgroundColor3 = Color3.fromRGB(36, 40, 60)
settingsPanel.Visible = false
settingsPanel.ZIndex = 10
local settingsPanelCorner = Instance.new("UICorner", settingsPanel)
settingsPanelCorner.CornerRadius = UDim.new(0, 18)

-- Заголовок панели
local titleLabel = Instance.new("TextLabel", settingsPanel)
titleLabel.Size = UDim2.new(1, 0, 0, 38)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 22
titleLabel.Text = "Настройки телепортации"
titleLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
titleLabel.ZIndex = 11

-- Ползунок для скорости полёта
local speedLabel = Instance.new("TextLabel", settingsPanel)
speedLabel.Size = UDim2.new(0, 120, 0, 28)
speedLabel.Position = UDim2.new(0, 20, 0, 60)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.SourceSans
speedLabel.TextSize = 16
speedLabel.Text = "Скорость полёта:"
speedLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
speedLabel.ZIndex = 12

local speedSliderFrame = Instance.new("Frame", settingsPanel)
speedSliderFrame.Size = UDim2.new(0, 160, 0, 18)
speedSliderFrame.Position = UDim2.new(0, 150, 0, 66)
speedSliderFrame.BackgroundTransparency = 1
speedSliderFrame.ZIndex = 13

local speedSliderBar = Instance.new("Frame", speedSliderFrame)
speedSliderBar.Size = UDim2.new(1, 0, 0, 6)
speedSliderBar.Position = UDim2.new(0, 0, 0.5, -3)
speedSliderBar.BackgroundColor3 = Color3.fromRGB(80, 90, 120)
speedSliderBar.ZIndex = 14
local speedSliderBarCorner = Instance.new("UICorner", speedSliderBar)
speedSliderBarCorner.CornerRadius = UDim.new(0, 3)

local speedSliderKnob = Instance.new("Frame", speedSliderFrame)
speedSliderKnob.Size = UDim2.new(0, 18, 0, 18)
speedSliderKnob.Position = UDim2.new((flySpeed-1)/99, -9, 0.5, -9)
speedSliderKnob.BackgroundColor3 = Color3.fromRGB(120, 160, 255)
speedSliderKnob.ZIndex = 15
local speedSliderKnobCorner = Instance.new("UICorner", speedSliderKnob)
speedSliderKnobCorner.CornerRadius = UDim.new(1, 0)

local speedValueLabel = Instance.new("TextLabel", settingsPanel)
speedValueLabel.Size = UDim2.new(0, 48, 0, 20)
speedValueLabel.Position = UDim2.new(0, 320-48-20, 0, 52) -- выше ползунка
speedValueLabel.BackgroundTransparency = 1
speedValueLabel.Font = Enum.Font.SourceSansBold
speedValueLabel.TextSize = 16
speedValueLabel.Text = tostring(flySpeed)
speedValueLabel.TextColor3 = Color3.fromRGB(220, 255, 220)
speedValueLabel.ZIndex = 16

local draggingSpeedSlider = false

local function setSpeedSliderValue(val)
    flySpeed = math.clamp(math.floor(val+0.5), 1, 100)
    speedSliderKnob.Position = UDim2.new((flySpeed-1)/99, -9, 0.5, -9)
    speedValueLabel.Text = tostring(flySpeed)
end

setSpeedSliderValue(flySpeed)

speedSliderKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSpeedSlider = true
    end
end)
speedSliderKnob.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSpeedSlider = false
    end
end)
speedSliderFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSpeedSlider = true
        local x = input.Position.X - speedSliderFrame.AbsolutePosition.X
        local percent = math.clamp(x / speedSliderFrame.AbsoluteSize.X, 0, 1)
        setSpeedSliderValue(1 + percent * 99)
    end
end)
game:GetService("UserInputService").InputChanged:Connect(function(input)
    if draggingSpeedSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
        local x = input.Position.X - speedSliderFrame.AbsolutePosition.X
        local percent = math.clamp(x / speedSliderFrame.AbsoluteSize.X, 0, 1)
        setSpeedSliderValue(1 + percent * 99)
    end
end)
game:GetService("UserInputService").InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSpeedSlider = false
    end
end)

-- Ползунок для FOV (ниже)
local fovLabel = Instance.new("TextLabel", settingsPanel)
fovLabel.Size = UDim2.new(0, 120, 0, 28)
fovLabel.Position = UDim2.new(0, 20, 0, 100)
fovLabel.BackgroundTransparency = 1
fovLabel.Font = Enum.Font.SourceSans
fovLabel.TextSize = 16
fovLabel.Text = "FOV камеры:"
fovLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
fovLabel.ZIndex = 12

local fovSliderFrame = Instance.new("Frame", settingsPanel)
fovSliderFrame.Size = UDim2.new(0, 160, 0, 18)
fovSliderFrame.Position = UDim2.new(0, 150, 0, 106)
fovSliderFrame.BackgroundTransparency = 1
fovSliderFrame.ZIndex = 13

local fovSliderBar = Instance.new("Frame", fovSliderFrame)
fovSliderBar.Size = UDim2.new(1, 0, 0, 6)
fovSliderBar.Position = UDim2.new(0, 0, 0.5, -3)
fovSliderBar.BackgroundColor3 = Color3.fromRGB(80, 90, 120)
fovSliderBar.ZIndex = 14
local fovSliderBarCorner = Instance.new("UICorner", fovSliderBar)
fovSliderBarCorner.CornerRadius = UDim.new(0, 3)

local fovSliderKnob = Instance.new("Frame", fovSliderFrame)
fovSliderKnob.Size = UDim2.new(0, 18, 0, 18)
fovSliderKnob.Position = UDim2.new((workspace.CurrentCamera.FieldOfView-40)/80, -9, 0.5, -9)
fovSliderKnob.BackgroundColor3 = Color3.fromRGB(120, 160, 255)
fovSliderKnob.ZIndex = 15
local fovSliderKnobCorner = Instance.new("UICorner", fovSliderKnob)
fovSliderKnobCorner.CornerRadius = UDim.new(1, 0)

local fovValueLabel = Instance.new("TextLabel", settingsPanel)
fovValueLabel.Size = UDim2.new(0, 48, 0, 20)
fovValueLabel.Position = UDim2.new(0, 320-48-20, 0, 92) -- выше ползунка
fovValueLabel.BackgroundTransparency = 1
fovValueLabel.Font = Enum.Font.SourceSansBold
fovValueLabel.TextSize = 16
fovValueLabel.Text = tostring(math.floor(workspace.CurrentCamera.FieldOfView))
fovValueLabel.TextColor3 = Color3.fromRGB(220, 255, 220)
fovValueLabel.ZIndex = 16

local draggingFovSlider = false

-- Фиксация FOV: запрещаем серверу и другим скриптам менять FOV
local userFov = workspace.CurrentCamera.FieldOfView

-- Следим за изменением FOV и возвращаем пользовательское значение
workspace.CurrentCamera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
    if math.abs(workspace.CurrentCamera.FieldOfView - userFov) > 0.1 then
        workspace.CurrentCamera.FieldOfView = userFov
    end
end)

-- Обновляем userFov при изменении слайдера
local function setFovSliderValue(val)
    local fov = math.clamp(math.floor(val+0.5), 40, 120)
    userFov = fov
    workspace.CurrentCamera.FieldOfView = fov
    fovSliderKnob.Position = UDim2.new((fov-40)/80, -9, 0.5, -9)
    fovValueLabel.Text = tostring(fov)
end


setFovSliderValue(workspace.CurrentCamera.FieldOfView)

fovSliderKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingFovSlider = true
    end
end)
fovSliderKnob.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingFovSlider = false
    end
end)
fovSliderFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingFovSlider = true
        local x = input.Position.X - fovSliderFrame.AbsolutePosition.X
        local percent = math.clamp(x / fovSliderFrame.AbsoluteSize.X, 0, 1)
        setFovSliderValue(40 + percent * 80)
    end
end)
game:GetService("UserInputService").InputChanged:Connect(function(input)
    if draggingFovSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
        local x = input.Position.X - fovSliderFrame.AbsolutePosition.X
        local percent = math.clamp(x / fovSliderFrame.AbsoluteSize.X, 0, 1)
        setFovSliderValue(40 + percent * 80)
    end
end)
game:GetService("UserInputService").InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingFovSlider = false
    end
end)

-- Поле для ввода скорости полёта


-- Кнопка запуска SubmergeGUI в настройках (теперь выше)
local submergeBtn = Instance.new("TextButton", settingsPanel)
submergeBtn.Size = UDim2.new(0, 180, 0, 36)
submergeBtn.Position = UDim2.new(0, 20, 0, 170)
submergeBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 180)
submergeBtn.Font = Enum.Font.SourceSansBold
submergeBtn.TextSize = 16
submergeBtn.Text = "Submerge Menu"
submergeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
submergeBtn.ZIndex = 12
local submergeBtnCorner = Instance.new("UICorner", submergeBtn)
submergeBtnCorner.CornerRadius = UDim.new(0, 10)
submergeBtn.MouseButton1Click:Connect(function()
    launchSubmergeGUI()
end)

-- Кнопка "Сохранить" (теперь ниже)
local saveBtn = Instance.new("TextButton", settingsPanel)
saveBtn.Size = UDim2.new(0, 120, 0, 36)
saveBtn.Position = UDim2.new(0, 20, 0, 210)
saveBtn.BackgroundColor3 = Color3.fromRGB(60, 70, 120)
saveBtn.Font = Enum.Font.SourceSansBold
saveBtn.TextSize = 18
saveBtn.Text = "Сохранить"
saveBtn.TextColor3 = Color3.fromRGB(220, 220, 255)
saveBtn.ZIndex = 11
local saveBtnCorner = Instance.new("UICorner", saveBtn)
saveBtnCorner.CornerRadius = UDim.new(0, 10)

saveBtn.MouseButton1Click:Connect(function()
    saveBtn.Text = "Сохранено!"
    task.wait(0.7)
    saveBtn.Text = "Сохранить"
end)

-- Кнопка "Назад" (закрыть настройки)
local backBtn = Instance.new("TextButton", settingsPanel)
backBtn.Size = UDim2.new(0, 80, 0, 32)
backBtn.Position = UDim2.new(1, -100, 1, -44)
backBtn.BackgroundColor3 = Color3.fromRGB(50, 60, 90)
backBtn.Font = Enum.Font.SourceSans
backBtn.TextSize = 16
backBtn.Text = "Назад"
backBtn.TextColor3 = Color3.fromRGB(200, 220, 255)
backBtn.ZIndex = 11
local backBtnCorner = Instance.new("UICorner", backBtn)
backBtnCorner.CornerRadius = UDim.new(0, 8)
backBtn.MouseButton1Click:Connect(function()
    settingsPanel.Visible = false
    frame.Visible = true
end)

-- Открытие панели настроек по кнопке
settingsTab.MouseButton1Click:Connect(function()
    settingsPanel.Visible = true
    frame.Visible = false
end)

-- Гарантируем видимость всех элементов панели
for _, v in ipairs(settingsPanel:GetChildren()) do
    if v:IsA("GuiObject") then v.ZIndex = 11 end
end

-- Обработчик смерти персонажа
player.CharacterAdded:Connect(function(newChar)
    char = newChar
    hrp = newChar:WaitForChild("HumanoidRootPart")
    humanoid = newChar:WaitForChild("Humanoid")
end)

-- === Реализация полёта (простая) ===
local flyConn
RunService.RenderStepped:Connect(function()
    if flyEnabled and char and hrp and humanoid and humanoid.Health > 0 then
        local moveDir = Vector3.new(0, 0, 0)
        local uis = game:GetService("UserInputService")
        if uis:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + workspace.CurrentCamera.CFrame.LookVector end
        if uis:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - workspace.CurrentCamera.CFrame.LookVector end
        if uis:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - workspace.CurrentCamera.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + workspace.CurrentCamera.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if uis:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        if moveDir.Magnitude > 0 then
            hrp.Velocity = moveDir.Unit * flySpeed
        else
            hrp.Velocity = Vector3.new(0, 0, 0)
        end
        humanoid.PlatformStand = true
    elseif humanoid and humanoid.PlatformStand then
        humanoid.PlatformStand = false
        hrp.Velocity = Vector3.new(0, 0, 0)
    end
end)

-- === SubmergeGUI: запуск только по кнопке ===
local function launchSubmergeGUI()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    local camera = workspace.CurrentCamera
    local submerged = false
    local swimSpeed = 20
    local submergeOffset = 6.45
    local riseMultiplier = 1.1
    local noclipParts = {}
    local originalCameraCFrame = nil
    local savedSubmergePosition = nil
    local animationPlaying = false
    local animationToggleButton = nil
    local playerData = {
        buttonPosition = UDim2.new(1, -175, 0.5, -100),
        animationButtonPosition = UDim2.new(1, -175, 0.5, -40)
    }
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://536135263"
    local animator = humanoid:WaitForChild("Animator")
    local animationTrack = animator:LoadAnimation(animation)
    animationTrack.Looped = false
    local gui = Instance.new("ScreenGui")
    gui.Name = "SubmergeGUI"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")
    local button = Instance.new("TextButton")
    button.Name = "SubmergeButton"
    button.Parent = gui
    button.Size = UDim2.new(0, 150, 0, 50)
    button.Position = playerData.buttonPosition
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = "Submerge"
    button.Font = Enum.Font.GothamBold
    button.TextSize = 18
    button.TextStrokeTransparency = 0
    button.TextStrokeColor3 = Color3.new(0, 0, 0)
    button.BackgroundTransparency = 0.2
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Draggable = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = button
    animationToggleButton = Instance.new("TextButton")
    animationToggleButton.Name = "AnimationToggleButton"
    animationToggleButton.Parent = gui
    animationToggleButton.Size = UDim2.new(0, 150, 0, 50)
    animationToggleButton.Position = playerData.animationButtonPosition
    animationToggleButton.AnchorPoint = Vector2.new(1, 0.5)
    animationToggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    animationToggleButton.TextColor3 = Color3.new(1, 1, 1)
    animationToggleButton.Text = "Arm up: On/Off"
    animationToggleButton.Font = Enum.Font.GothamBold
    animationToggleButton.TextSize = 18
    animationToggleButton.TextStrokeTransparency = 0
    animationToggleButton.TextStrokeColor3 = Color3.new(0, 0, 0)
    animationToggleButton.BackgroundTransparency = 0.2
    animationToggleButton.BorderSizePixel = 0
    animationToggleButton.AutoButtonColor = true
    animationToggleButton.Draggable = true
    local animCorner = Instance.new("UICorner")
    animCorner.CornerRadius = UDim.new(0, 15)
    animCorner.Parent = animationToggleButton
    local highlight = Instance.new("Highlight")
    highlight.Enabled = false
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.Parent = character
    for _, part in pairs(character:GetChildren()) do
        if part.Name == "Left Arm" or part.Name == "Right Arm" then
            table.insert(noclipParts, part)
        end
    end
    local function toggleNoclip(state)
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if table.find(noclipParts, part) then
                    part.CanCollide = false
                else
                    part.CanCollide = not state
                end
            end
        end
    end
    local function submerge()
        originalCameraCFrame = camera.CFrame
        camera.CameraType = Enum.CameraType.Custom
        savedSubmergePosition = rootPart.Position - Vector3.new(0, submergeOffset, 0)
        toggleNoclip(true)
        rootPart.CFrame = CFrame.new(savedSubmergePosition)
        humanoid.PlatformStand = true
        highlight.Enabled = true
        submerged = true
        button.Text = "Rise Up"
    end
    local function surface()
        toggleNoclip(false)
        humanoid.PlatformStand = false
        rootPart.CFrame = rootPart.CFrame + Vector3.new(0, submergeOffset * riseMultiplier, 0)
        highlight.Enabled = false
        submerged = false
        button.Text = "Submerge"
        camera.CFrame = originalCameraCFrame
    end
    local function toggleAnimation()
        if animationPlaying then
            animationTrack:Stop()
            animationToggleButton.Text = "Arm up: On/Off"
            animationPlaying = false
        else
            animationPlaying = true
            animationToggleButton.Text = "Arm up: Off"
            while animationPlaying do
                animationTrack:Play()
                animationTrack.TimePosition = 0.2
                task.wait(0.03)
            end
        end
    end
    game:GetService("RunService").Stepped:Connect(function()
        if submerged then
            toggleNoclip(true)
        end
    end)
    game:GetService("RunService").RenderStepped:Connect(function()
        if submerged then
            rootPart.CFrame = CFrame.new(rootPart.Position.X, savedSubmergePosition.Y, rootPart.Position.Z)
            rootPart.Velocity = humanoid.MoveDirection * swimSpeed
        end
    end)
    button.MouseButton1Click:Connect(function()
        if submerged then
            surface()
        else
            submerge()
        end
    end)
    animationToggleButton.MouseButton1Click:Connect(toggleAnimation)
    button:GetPropertyChangedSignal("Position"):Connect(function()
        playerData.buttonPosition = button.Position
    end)
    animationToggleButton:GetPropertyChangedSignal("Position"):Connect(function()
        playerData.animationButtonPosition = animationToggleButton.Position
    end)
    game.Players.LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.01)
        button.Position = playerData.buttonPosition
        animationToggleButton.Position = playerData.animationButtonPosition
    end)
end
