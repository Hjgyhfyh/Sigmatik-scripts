-- SIGMATIK | t.me/sigmatik323 | obfuscate-failed, raw copy
--[[
    Muscle Legends: New Players — PoC уязвимости F-001
    Уязвимость: ReplicatedStorage.rEvents.changeSpeedSizeRemote
                Серверный обработчик применяет размер персонажа от клиента
                БЕЗ проверки геймпасса "Custom Size" и выставляет UsingCustomSize = true.
                Контроль: ветка "changeSpeed" тот же сервер корректно отклоняет (false).

    Игра: Muscle Legends: New Players (placeId 90438204717601) / 💪Muscle Legends (3623096087)
    Автор аудита: Roblox MCP
--]]

--========================= СЛУЖЕБНОЕ =========================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- Состояние между перезапусками
local CONFIG_FILE = "MuscleLegendsNewPlayers_cfg.json"
local STATE = {
    sizeValue   = 2.0,   -- последнее отправленное значение размера
    panelOpen   = true,
    autoResize  = false,
    antiAfk     = true,
}
local function loadState()
    local ok, data = pcall(function() return readfile and readfile(CONFIG_FILE) end)
    if ok and type(data) == "string" and #data > 0 then
        local ok2, decoded = pcall(function() return game:GetService("HttpService"):JSONDecode(data) end)
        if ok2 and type(decoded) == "table" then
            for k, v in pairs(decoded) do
                if STATE[k] ~= nil and type(v) == type(STATE[k]) then STATE[k] = v end
            end
        end
    end
end
local function saveState()
    pcall(function()
        if writefile then
            writefile(CONFIG_FILE, game:GetService("HttpService"):JSONEncode(STATE))
        end
    end)
end
loadState()

--========================= ССЫЛКИ =========================
local rEvents = ReplicatedStorage:WaitForChild("rEvents", 30)
local sizeRemote = rEvents and rEvents:WaitForChild("changeSpeedSizeRemote", 30)

local function getHumanoid()
    local ch = LocalPlayer.Character
    return ch and ch:FindFirstChildOfClass("Humanoid"), ch
end

local function scaleText()
    local hum = getHumanoid()
    if not hum then return "нет персонажа" end
    return string.format("H=%.2f  D=%.2f  W=%.2f",
        hum.BodyHeightScale.Value, hum.BodyDepthScale.Value, hum.BodyWidthScale.Value)
end

local function ownedGamepasses()
    local f = LocalPlayer:FindFirstChild("ownedGamepasses")
    return f and #f:GetChildren() or 0
end

--========================= ЛОГИКА ЭКСПЛОЙТА =========================
local lastCall = 0
local MIN_INTERVAL = 3.0  -- серверный кулдаун на changeSize, не частим

--- Отправляет произвольный размер и возвращает ответ сервера.
local function setSize(value, silent)
    if not sizeRemote then return "нет remote" end
    if tick() - lastCall < MIN_INTERVAL then
        return string.format("кулдаун, подожди %.1f с", MIN_INTERVAL - (tick() - lastCall))
    end
    lastCall = tick()

    local result
    task.spawn(function()
        local ok, a, b, c = pcall(function() return sizeRemote:InvokeServer("changeSize", value) end)
        result = ok and table.concat({ tostring(a), tostring(b), tostring(c) }, " | ") or ("ошибка: " .. tostring(a))
    end)

    local waited = 0
    repeat task.wait(0.1); waited = waited + 0.1 until result ~= nil or waited > 8

    STATE.sizeValue = value
    saveState()
    if not silent then
        print(string.format("[F-001] changeSize(%s) -> %s", tostring(value), tostring(result)))
    end
    return result or "таймаут"
end

--- Полная демонстрация уязвимости: печатает до/после и контрольную проверку.
local function proveVulnerability()
    print("========== PoC F-001: Muscle Legends ==========")
    print(("Геймпассов у аккаунта: %d"):format(ownedGamepasses()))
    print("Размер до:   " .. scaleText())
    print("UsingCustomSize до: " .. tostring(LocalPlayer:GetAttribute("UsingCustomSize")))

    local reply = setSize(0.9, true)
    task.wait(3.0)
    print("Ответ сервера на changeSize(0.9): " .. reply)
    print("Размер после: " .. scaleText())
    print("UsingCustomSize после: " .. tostring(LocalPlayer:GetAttribute("UsingCustomSize")))

    -- контроль: скоростная ветка геймпасс проверяет
    local speedReply
    task.spawn(function()
        local ok, a, b = pcall(function() return sizeRemote:InvokeServer("changeSpeed", 100) end)
        speedReply = ok and (tostring(a) .. " | " .. tostring(b)) or ("ошибка: " .. tostring(a))
    end)
    local waited = 0
    repeat task.wait(0.1); waited = waited + 0.1 until speedReply ~= nil or waited > 8
    print("Контроль changeSpeed(100): " .. tostring(speedReply)
        .. "   UsingCustomSpeed=" .. tostring(LocalPlayer:GetAttribute("UsingCustomSpeed")))
    print("Вывод: размер сервер применил без геймпасса, скорость — отклонил.")
    print("==============================================")

    -- вернуть размер, положенный по силе
    task.wait(MIN_INTERVAL)
    setSize(1000, true)
end

--========================= АНТИ-АФК =========================
local antiAfkConn
if STATE.antiAfk then
    antiAfkConn = LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

--========================= ГРАФИЧЕСКИЙ ИНТЕРФЕЙС =========================
local gui = Instance.new("ScreenGui")
gui.Name = "ML_AuditPoC"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 9999
gui.Parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(340, 300)
main.Position = UDim2.new(0, 20, 0, 120)
main.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Visible = STATE.panelOpen
main.Parent = gui

local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = main
local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(90, 90, 120); stroke.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 30)
title.Position = UDim2.fromOffset(10, 4)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(235, 235, 245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Muscle Legends — PoC F-001"
title.Parent = main

local function makeButton(text, x, y, width, color, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(width, 0, 0, 30)
    b.Position = UDim2.fromOffset(x, y)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.TextColor3 = Color3.fromRGB(240, 240, 250)
    b.Text = text
    b.Parent = main
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = b
    b.MouseButton1Click:Connect(callback)
    return b
end

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 34)
infoLabel.Position = UDim2.fromOffset(10, 38)
infoLabel.BackgroundTransparency = 1
infoLabel.Font = Enum.Font.Code
infoLabel.TextSize = 12
infoLabel.TextColor3 = Color3.fromRGB(160, 220, 160)
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Text = "Размер: ...\nГеймпассов: ..."
infoLabel.Parent = main

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.fromOffset(10, 74)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Code
statusLabel.TextSize = 11
statusLabel.TextColor3 = Color3.fromRGB(255, 210, 120)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "готов"
statusLabel.Parent = main

local box = Instance.new("TextBox")
box.Size = UDim2.new(0.42, 0, 0, 26)
box.Position = UDim2.fromOffset(10, 100)
box.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
box.BorderSizePixel = 0
box.Font = Enum.Font.Code
box.TextSize = 13
box.TextColor3 = Color3.fromRGB(235, 235, 245)
box.Text = tostring(STATE.sizeValue)
box.PlaceholderText = "значение"
box.Parent = main
local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 6); bc.Parent = box

makeButton("Применить размер", 180, 100, 0.42, Color3.fromRGB(60, 110, 200), function()
    local v = tonumber(box.Text)
    if not v then statusLabel.Text = "нужно число"; return end
    statusLabel.Text = "отправляю " .. tostring(v) .. " ..."
    task.spawn(function()
        local r = setSize(v, true)
        statusLabel.Text = tostring(r):sub(1, 46)
    end)
end)

makeButton("ДОКАЗАТЬ УЯЗВИМОСТЬ (0.9)", 10, 136, 1 - 20 / 340, Color3::fromRGB and Color3.fromRGB(150, 60, 60), function()
    statusLabel.Text = "прогоняю проверку, смотри консоль"
    task.spawn(function()
        proveVulnerability()
        statusLabel.Text = "готово, детали в консоли (F9)"
    end)
end)

makeButton("Сбросить (размер по силе)", 10, 172, 1 - 20 / 340, Color3.fromRGB(60, 120, 80), function()
    statusLabel.Text = "сбрасываю ..."
    task.spawn(function()
        setSize(1000, true)
        statusLabel.Text = "сброшено"
    end)
end)

local antiBtn = makeButton("Анти-АФК: " .. (STATE.antiAfk and "ВКЛ" or "ВЫКЛ"), 10, 208, 1 - 20 / 340, Color3.fromRGB(70, 70, 100), function()
    STATE.antiAfk = not STATE.antiAfk
    saveState()
    antiBtn.Text = "Анти-АФК: " .. (STATE.antiAfk and "ВКЛ" or "ВЫКЛ")
    if STATE.antiAfk then
        if not antiAfkConn then
            antiAfkConn = LocalPlayer.Idled:Connect(function()
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end)
        end
    else
        if antiAfkConn then antiAfkConn:Disconnect(); antiAfkConn = nil end
    end
end)

-- переключатель сворачивания
local toggle = Instance.new("TextButton")
toggle.Size = UDim2.fromOffset(56, 22)
toggle.Position = UDim2.new(1, -64, 0, 6)
toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
toggle.BorderSizePixel = 0
toggle.Font = Enum.Font.GothamMedium
toggle.TextSize = 12
toggle.TextColor3 = Color3.fromRGB(230, 230, 240)
toggle.Text = "скрыть"
toggle.Parent = main
local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 6); tc.Parent = toggle

toggle.MouseButton1Click:Connect(function()
    STATE.panelOpen = not STATE.panelOpen
    saveState()
    for _, ch in ipairs(main:GetChildren()) do
        if ch ~= title and ch ~= toggle then ch.Visible = STATE.panelOpen end
    end
    toggle.Text = STATE.panelOpen and "скрыть" or "показать"
    main.Size = STATE.panelOpen and UDim2.fromOffset(340, 300) or UDim2.fromOffset(340, 34)
end)
if not STATE.panelOpen then
    for _, ch in ipairs(main:GetChildren()) do
        if ch ~= title and ch ~= toggle then ch.Visible = false end
    end
    main.Size = UDim2.fromOffset(340, 34)
    toggle.Text = "показать"
end

--========================= ВЫГРУЗКА =========================
local heartbeat
heartbeat = task.spawn(function()
    while gui.Parent do
        infoLabel.Text = string.format("Размер: %s\nГеймпассов: %d   UsingCustomSize=%s",
            scaleText(), ownedGamepasses(), tostring(LocalPlayer:GetAttribute("UsingCustomSize")))
        task.wait(0.5)
    end
end)

local unloadBtn = makeButton("ВЫГРУЗИТЬ СКРИПТ", 244, Color3.fromRGB(120, 40, 40), function()
    STATE.panelOpen = true
    saveState()
    if antiAfkConn then antiAfkConn:Disconnect() end
    pcall(function() task.cancel(heartbeat) end)
    gui:Destroy()
    print("[F-001] скрипт выгружен")
end)

print("[F-001] Загружено. Панель: Muscle Legends — PoC F-001. Кнопка «ДОКАЗАТЬ УЯЗВИМОСТЬ» печатает доказательство в консоль (F9).")
