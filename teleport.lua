local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- Настройки
local flySpeed = 60
local flyEnabled = false
local WALK_SPEED = humanoid.WalkSpeed
-- TELEPORT_SPEED теперь вычисляется динамически через flySpeed
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
settingsTab.Text = "Настройки"
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

-- Поле для ввода скорости полёта

-- Ползунок для выбора скорости
local speedLabel = Instance.new("TextLabel", settingsPanel)
speedLabel.Size = UDim2.new(0, 120, 0, 28)
speedLabel.Position = UDim2.new(0, 20, 0, 60)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.SourceSans
speedLabel.TextSize = 16
speedLabel.Text = "Скорость полёта:"
speedLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
speedLabel.ZIndex = 11


local sliderFrame = Instance.new("Frame", settingsPanel)
sliderFrame.Size = UDim2.new(0, 160, 0, 18)
sliderFrame.Position = UDim2.new(0, 150, 0, 66)
sliderFrame.BackgroundTransparency = 1
sliderFrame.ZIndex = 12

local sliderBar = Instance.new("Frame", sliderFrame)
sliderBar.Size = UDim2.new(1, 0, 0, 6)
sliderBar.Position = UDim2.new(0, 0, 0.5, -3)
sliderBar.BackgroundColor3 = Color3.fromRGB(80, 90, 120)
sliderBar.ZIndex = 13
local sliderBarCorner = Instance.new("UICorner", sliderBar)
sliderBarCorner.CornerRadius = UDim.new(0, 3)

local sliderKnob = Instance.new("Frame", sliderFrame)
sliderKnob.Size = UDim2.new(0, 18, 0, 18)
sliderKnob.Position = UDim2.new((flySpeed-1)/99, -9, 0.5, -9)
sliderKnob.BackgroundColor3 = Color3.fromRGB(120, 160, 255)
sliderKnob.ZIndex = 14
local sliderKnobCorner = Instance.new("UICorner", sliderKnob)
sliderKnobCorner.CornerRadius = UDim.new(1, 0)

local valueLabel = Instance.new("TextLabel", settingsPanel)
valueLabel.Size = UDim2.new(0, 36, 0, 28)
valueLabel.Position = UDim2.new(0, 320-36-20, 0, 38) -- выше ползунка
valueLabel.BackgroundTransparency = 1
valueLabel.Font = Enum.Font.SourceSansBold
valueLabel.TextSize = 16
valueLabel.Text = tostring(flySpeed)
valueLabel.TextColor3 = Color3.fromRGB(220, 255, 220)
valueLabel.ZIndex = 13

local draggingSlider = false

local function setSliderValue(val)
    flySpeed = math.clamp(math.floor(val+0.5), 1, 100)
    sliderKnob.Position = UDim2.new((flySpeed-1)/99, -9, 0.5, -9)
    valueLabel.Text = tostring(flySpeed)
end

setSliderValue(flySpeed)

sliderKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSlider = true
    end
end)
sliderKnob.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSlider = false
    end
end)
sliderFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSlider = true
        local x = input.Position.X - sliderFrame.AbsolutePosition.X
        local percent = math.clamp(x / sliderFrame.AbsoluteSize.X, 0, 1)
        setSliderValue(1 + percent * 99)
    end
end)
game:GetService("UserInputService").InputChanged:Connect(function(input)
    if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
        local x = input.Position.X - sliderFrame.AbsolutePosition.X
        local percent = math.clamp(x / sliderFrame.AbsoluteSize.X, 0, 1)
        setSliderValue(1 + percent * 99)
    end
end)
game:GetService("UserInputService").InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSlider = false
    end
end)

-- Toggle-кнопка для полёта
local toggleBtn = Instance.new("TextButton", settingsPanel)
toggleBtn.Size = UDim2.new(0, 180, 0, 36)
toggleBtn.Position = UDim2.new(0, 20, 0, 110)
toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 60)
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.TextSize = 18
toggleBtn.TextColor3 = Color3.fromRGB(220, 255, 220)
toggleBtn.ZIndex = 11
local function updateToggleBtn()
    toggleBtn.Text = flyEnabled and "Полёт: ВКЛ" or "Полёт: ВЫКЛ"
    toggleBtn.BackgroundColor3 = flyEnabled and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(90, 60, 60)
end
updateToggleBtn()
local toggleBtnCorner = Instance.new("UICorner", toggleBtn)
toggleBtnCorner.CornerRadius = UDim.new(0, 10)

toggleBtn.MouseButton1Click:Connect(function()
    flyEnabled = not flyEnabled
    updateToggleBtn()
end)

-- Кнопка "Сохранить"
local saveBtn = Instance.new("TextButton", settingsPanel)
saveBtn.Size = UDim2.new(0, 120, 0, 36)
saveBtn.Position = UDim2.new(0, 20, 0, 170)
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

-- ...existing code...
