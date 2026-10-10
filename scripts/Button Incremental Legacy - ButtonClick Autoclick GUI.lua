-- SIGMATIK | t.me/sigmatik323 | obfuscate-failed, raw copy
--[[
	=====================================================================
	 Button Incremental Legacy  |  GUI-автоклик ButtonClick("Starter")
	=====================================================================
	 Равномерный поток до 400 вызовов/сек (аккумулятор на Heartbeat,
	 а не «пачка раз в секунду»). Состояние (скорость + запущено)
	 переживает перезапуск — лежит в BIL_autoclick.json рядом с эксплоитом.
	 Анти-афк встроен.

	 УПРАВЛЕНИЕ:
		 getgenv().__BIL_STOP_ALL()   — стоп + снести GUI
	=====================================================================
]]

do
local _ok, _err = xpcall(function()

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")

local PLP   = Players.LocalPlayer
local Event = ReplicatedStorage.Remotes.ButtonClick
local GENV  = getgenv()

local MAX_RATE     = 400
local DEFAULT_RATE = 100
local PAYLOAD      = "Starter"
local STATE_FILE   = "BIL_autoclick.json"

--------------------------------------------------------------------- СТОП ПРЕДЫДУЩЕЙ ВЕРСИИ
if GENV.__BIL_STOP_ALL then pcall(GENV.__BIL_STOP_ALL) end

--------------------------------------------------------------------- СОСТОЯНИЕ
local savedRate, savedRunning = nil, nil
do
	local ok, raw = pcall(function() return readfile(STATE_FILE) end)
	if ok and type(raw) == "string" and raw ~= "" then
		local ok2, dec = pcall(function() return HttpService:JSONDecode(raw) end)
		if ok2 and type(dec) == "table" then
			if tonumber(dec.rate) then savedRate = math.clamp(math.floor(tonumber(dec.rate)), 1, MAX_RATE) end
			savedRunning = (dec.running == true)
		end
	end
end

local rate      = savedRate or DEFAULT_RATE
local isRunning = savedRunning == true
local sentTotal = 0

local function saveState()
	pcall(function()
		writefile(STATE_FILE, HttpService:JSONEncode({
			running = isRunning,
			rate    = rate,
		}))
	end)
end

--------------------------------------------------------------------- GUI
local gui = Instance.new("ScreenGui")
gui.Name               = "BILClickGUI"
gui.ResetOnParent      = false
gui.IgnoreGuiInset     = true
gui.ZIndexBehavior     = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder       = 999
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)

local C = {
	bg      = Color3.fromRGB(22, 22, 26),
	panel   = Color3.fromRGB(32, 33, 39),
	head    = Color3.fromRGB(40, 41, 49),
	stroke  = Color3.fromRGB(60, 62, 72),
	text    = Color3.fromRGB(235, 235, 240),
	dim     = Color3.fromRGB(150, 152, 165),
	accent  = Color3.fromRGB(0, 170, 255),
	go      = Color3.fromRGB(46, 190, 110),
	stop    = Color3.fromRGB(214, 68, 68),
	track   = Color3.fromRGB(58, 60, 70),
}

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local function corner(o, r) mk("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o) end
local function stroke(o, c, t) mk("UIStroke", { Color = c or C.stroke, Thickness = t or 1 }, o) end

-- ---------------------------------------------------------------- окно
local main = mk("Frame", {
	Name = "Main",
	Size = UDim2.fromOffset(330, 330),
	Position = UDim2.fromOffset(40, 220),
	BackgroundColor3 = C.bg,
	BorderSizePixel = 0,
	Active = true,
}, gui)
corner(main, 10)
stroke(main, C.stroke, 1)

local title = mk("Frame", {
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundColor3 = C.head,
	BorderSizePixel = 0,
}, main)
corner(title, 10)
mk("Frame", { Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = C.head, BorderSizePixel = 0 }, title)

mk("TextLabel", {
	Size = UDim2.new(1, -46, 1, 0),
	Position = UDim2.fromOffset(14, 0),
	BackgroundTransparency = 1,
	Text = "ButtonClick  ·  Starter",
	TextColor3 = C.text,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, title)

local btnClose = mk("TextButton", {
	Size = UDim2.fromOffset(28, 28),
	Position = UDim2.new(1, -36, 0, 6),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	Text = "X",
	TextColor3 = C.dim,
	TextSize = 13,
	Font = Enum.Font.GothamBold,
}, title)
corner(btnClose, 6)

-- перетаскивание окна
do
	local drag, sx, sy, ox, oy
	title.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = true
			sx, sy = i.Position.X, i.Position.Y
			ox, oy = main.Position.X, main.Position.Y
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
			main.Position = UDim2.fromOffset(ox + (i.Position.X - sx), oy + (i.Position.Y - sy))
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
	end)
end

--------------------------------------------------------------------- ХЕЛПЕРЫ UI
local y = 52

mk("TextLabel", {
	Size = UDim2.new(1, -32, 0, 18),
	Position = UDim2.fromOffset(16, y),
	BackgroundTransparency = 1,
	Text = "СКОРОСТЬ ВЫЗОВОВ",
	TextColor3 = C.dim,
	TextSize = 11,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, main)
y = y + 22

local lblRate = mk("TextLabel", {
	Size = UDim2.new(1, -120, 0, 34),
	Position = UDim2.fromOffset(16, y),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	Text = "100 / сек",
	TextColor3 = C.accent,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
}, main)
corner(lblRate, 8)

local boxRate = mk("TextBox", {
	Size = UDim2.fromOffset(96, 34),
	Position = UDim2.new(1, -112, 0, y),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	Text = tostring(rate),
	PlaceholderText = "число",
	TextColor3 = C.text,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	ClearTextOnFocus = false,
}, main)
corner(boxRate, 8)
y = y + 46

-- слайдер
local track = mk("Frame", {
	Size = UDim2.new(1, -32, 0, 10),
	Position = UDim2.fromOffset(16, y),
	BackgroundColor3 = C.track,
	BorderSizePixel = 0,
}, main)
corner(track, 5)

local fill = mk("Frame", {
	Size = UDim2.fromScale(0.25, 1),
	BackgroundColor3 = C.accent,
	BorderSizePixel = 0,
}, track)
corner(fill, 5)

local knob = mk("Frame", {
	Size = UDim2.fromOffset(18, 18),
	Position = UDim2.new(0.25, -9, 0.5, -9),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BorderSizePixel = 0,
	ZIndex = 2,
}, track)
corner(knob, 9)

mk("TextLabel", { -- невидимый ловец клика по треку
	Size = UDim2.fromOffset(14, 30),
	Position = UDim2.new(0, -7, 0.5, -15),
	BackgroundTransparency = 1,
	Text = "",
}, track).Name = "Grab"

local trackGrab = track:FindFirstChild("Grab")

local lblMin = mk("TextLabel", {
	Size = UDim2.fromOffset(40, 16),
	Position = UDim2.fromOffset(16, y + 12),
	BackgroundTransparency = 1,
	Text = "1",
	TextColor3 = C.dim,
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local lblMax = mk("TextLabel", {
	Size = UDim2.fromOffset(60, 16),
	Position = UDim2.new(1, -76, 0, y + 12),
	BackgroundTransparency = 1,
	Text = MAX_RATE .. "/с",
	TextColor3 = C.dim,
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Right,
}, main)
y = y + 40

--------------------------------------------------------------------- КНОПКИ +/- и СТАРТ
local btnMinus = mk("TextButton", {
	Size = UDim2.fromOffset(40, 32),
	Position = UDim2.fromOffset(16, y),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	Text = "-",
	TextColor3 = C.text,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
}, main)
corner(btnMinus, 7)

local btnPlus = mk("TextButton", {
	Size = UDim2.fromOffset(40, 32),
	Position = UDim2.fromOffset(62, y),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
	Text = "+",
	TextColor3 = C.text,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
}, main)
corner(btnPlus, 7)

local btnRun = mk("TextButton", {
	Size = UDim2.new(1, -32, 0, 36),
	Position = UDim2.fromOffset(16, y),
	BackgroundColor3 = C.go,
	BorderSizePixel = 0,
	Text = "ЗАПУСТИТЬ",
	TextColor3 = Color3.fromRGB(10, 12, 14),
	TextSize = 14,
	Font = Enum.Font.GothamBold,
}, main)
corner(btnRun, 7)
y = y + 44

--------------------------------------------------------------------- СТАТУС / СТАТИСТИКА
local lblStatus = mk("TextLabel", {
	Size = UDim2.new(1, -32, 0, 16),
	Position = UDim2.fromOffset(16, y),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = C.dim,
	TextSize = 12,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
}, main)
y = y + 22

local function statRow(label, name)
	mk("TextLabel", {
		Size = UDim2.new(0.5, -16, 0, 16),
		Position = UDim2.fromOffset(16, y),
		BackgroundTransparency = 1,
		Text = label,
		TextColor3 = C.dim,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, main)
	local v = mk("TextLabel", {
		Size = UDim2.new(0.5, -16, 0, 16),
		Position = UDim2.new(0.5, 0, 0, y),
		BackgroundTransparency = 1,
		Text = "-",
		TextColor3 = C.text,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, main)
	y = y + 18
	return v
end

local statSent = statRow("Отправлено", "sent")
local statReal = statRow("Факт. скорость", "real")
local statMoney = statRow("Money", "money")
y = y + 4

mk("TextLabel", {
	Size = UDim2.new(1, -32, 0, 28),
	Position = UDim2.fromOffset(16, y),
	BackgroundTransparency = 1,
	Text = "Равномерный поток (аккумулятор на Heartbeat).\nВыгрузка: getgenv().__BIL_STOP_ALL()",
	TextColor3 = C.dim,
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, main)

--------------------------------------------------------------------- ЛОГИКА СКОРОСТИ
local suppressBoxSync = false

local function renderRate()
	local t = (rate - 1) / (MAX_RATE - 1)
	fill.Size = UDim2.fromScale(t, 1)
	knob.Position = UDim2.new(t, -9, 0.5, -9)
	lblRate.Text = rate .. " / сек"
	if not suppressBoxSync then
		boxRate.Text = tostring(rate)
	end
	saveState()
end

local function setRate(v, fromBox)
	v = math.clamp(math.floor(tonumber(v) or 1), 1, MAX_RATE)
	if v == rate then
		if fromBox then lblRate.Text = rate .. " / сек" end
		return
	end
	rate = v
	renderRate()
end

local function setFromX(absX)
	local w = math.max(track.AbsoluteSize.X, 1)
	local t = math.clamp((absX - track.AbsolutePosition.X) / w, 0, 1)
	setRate(1 + t * (MAX_RATE - 1))
end

local dragging = false
trackGrab.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		setFromX(i.Position.X)
	end
end)
UserInputService.InputChanged:Connect(function(i)
	if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
		setFromX(i.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

btnMinus.MouseButton1Click:Connect(function() setRate(rate - (rate >= 100 and 25 or 5)) end)
btnPlus.MouseButton1Click:Connect(function()  setRate(rate + (rate >= 100 and 25 or 5)) end)

boxRate.FocusLost:Connect(function(enter)
	suppressBoxSync = true
	setRate(boxRate.Text, true)
	suppressBoxSync = false
	renderRate()
end)

--------------------------------------------------------------------- ПЛАНИРОВЩИК
local acc      = 0      -- накопитель дробной части
local lastTick = os.clock()
local frameCap = MAX_RATE -- страховка от догоняющего лавина

local function pump()
	local now = os.clock()
	local dt  = now - lastTick
	lastTick = now
	if not isRunning then return end

	acc = acc + dt * rate

	local due = math.floor(acc)
	if due > 0 then
		acc = acc - due
		if due > frameCap then due = frameCap end
		for i = 1, due do
			local ok = pcall(Event.FireServer, Event, PAYLOAD)
			if ok then sentTotal = sentTotal + 1 end
		end
	end
end

local hb = RunService.Heartbeat:Connect(pump)

--------------------------------------------------------------------- СТАРТ / СТОП
local function renderRun()
	btnRun.Text     = isRunning and "ОСТАНОВИТЬ" or "ЗАПУСТИТЬ"
	btnRun.BackgroundColor3 = isRunning and C.stop or C.go
	btnRun.TextColor3 = isRunning and Color3.fromRGB(255, 240, 240) or Color3.fromRGB(10, 12, 14)
	lblStatus.Text = isRunning
		and ("Работает  ·  " .. rate .. " вызовов/сек  ·  равномерно")
		or ("Остановлено  ·  готово " .. rate .. " вызовов/сек")
	lblStatus.TextColor3 = isRunning and C.go or C.dim
end

local function setRunning(v)
	isRunning = v and true or false
	if isRunning then lastTick = os.clock() acc = 0 end
	renderRun()
	saveState()
end

btnRun.MouseButton1Click:Connect(function() setRunning(not isRunning) end)

--------------------------------------------------------------------- АНТИ-АФК
do
	local function jump()
		local c = PLP and PLP.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end) end
	end
	if PLP then
		task.spawn(function()
			local conn
			conn = PLP.Idled:Connect(function()
				if conn then conn:Disconnect() end
				if gethui then pcall(function() gethui().ResetOnParent = nil end) end
				jump()
				task.wait(55)
				conn = PLP.Idled:Connect(jump)
			end)
		end)
	end
end

--------------------------------------------------------------------- СТАТИСТИКА
local lastSecCount, lastSecTime = 0, os.clock()
task.spawn(function()
	while gui.Parent do
		task.wait(0.5)
		local now = os.clock()
		if now - lastSecTime >= 1 then
			statReal.Text = string.format("%d/с", math.floor((sentTotal - lastSecCount) / (now - lastSecTime)))
			lastSecCount, lastSecTime = sentTotal, now
		end
		statSent.Text = tostring(sentTotal)
		local ls = PLP and PLP:FindFirstChild("leaderstats")
		local m  = ls and ls:FindFirstChild("Money")
		statMoney.Text = m and tostring(math.floor(m.Value)) or "-"
	end
end)

--------------------------------------------------------------------- ВЫГРУЗКА
local function unload()
	isRunning = false
	saveState()
	pcall(function() hb:Disconnect() end)
	pcall(function() gui:Destroy() end)
	pcall(function() GENV.__BIL_AUTOCLICK_STOP = nil end)
	GENV.__BIL_STOP_ALL = nil
end

btnClose.MouseButton1Click:Connect(unload)
GENV.__BIL_STOP_ALL = unload

--------------------------------------------------------------------- СТАРТ
renderRate()
renderRun()
setRunning(savedRunning == true)

end, function(e)
	getgenv().__BIL_LAST_ERROR = tostring(e) .. " || " .. debug.traceback()
end)