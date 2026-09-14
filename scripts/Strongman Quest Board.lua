-- SIGMATIK | t.me/sigmatik323 | obfuscate-failed, raw copy
--[[====================================================================
  [X2]Strongman Simulator — Halloween 2025 Quest board (покупка) · v1.2
  --------------------------------------------------------------------
  Что делает:
    • Кнопка «КУПИТЬ — 1999 R$»: открывает НАСТОЯЩИЙ промпт Roblox на
      продукт 3437507722 «Halloween 2025 - Quest board».
      Оплата реальная, 1999 R$. Без оплаты ничего не выдаётся — так
      устроено на сервере (ProcessReceipt).
    • После оплаты сервер САМ:
        TGSTransactionLog.AddTransaction →
        EventHandler.InstantComplete(player, false) →
        все 6 целей квеста Event_Halloween2025 закрываются →
        TGSSimpleQuests.OnFinish → Scarecrow (Legendary) в питомцы.
      Скрипт только показывает прогресс и ловит выдачу.
    • Блок «Подарок»: покупка gift-версии 3437508404 на чужой UserId
      через серверный TGSDeveloperProductGifting_BuyProductAsGift.
      Получатель должен быть в этой же серверной сессии (онлайн).
    • Живой прогресс 6 целей квеста + статус Scarecrow + лог.
    • RightShift — скрыть/показать, X — выгрузить (кнопка Unload тоже).
  --------------------------------------------------------------------
  Важно (подводные камни):
    • Повторная покупка НЕ выдаёт второго Scarecrow: у завершённого
      квеста цели уже на максимуме, OnFinish повторно не вызывается.
    • Подарок себе технически работает (сервер не запрещает), цена та
      же — 1999 R$.
    • Скрипт НЕ трогает оплату: никаких спуфов PromptPurchaseFinished,
      никаких вызовов InstantComplete (он серверный, с клиента нельзя).
  --------------------------------------------------------------------
  Спам-лимит <= 400 запросов/сек, анти-АФК, конфиг между запусками.
  v1.2: executor клонит/пересоздаёт GUI — поэтому весь рендер идёт
        через живой резолв дерева по именам в цикле (2с), кнопки
        подключаются один раз на инстанс (атрибут QBWired), лог хранится
        в Lua-буфере и перерисовывается, а не пишется в захваченные
        ссылки.
====================================================================]]

if getgenv then getgenv().__SM_qb_error = nil end

local __ok, __err = xpcall(function()

local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService        = game:GetService("HttpService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local VirtualUser        = game:GetService("VirtualUser")
local plr                = Players.LocalPlayer

-- кеш глобалов: после yield к ним может не быть доступа
local InstanceC = Instance
local UDim2C    = UDim2
local UDimC     = UDim
local Color3C   = Color3
local Vector2C  = Vector2
local EnumC     = Enum

local SCRIPT_NAME = "StrongmanQuestBoard"
local CONFIG_FILE = "StrongmanQuestBoard_settings.json"
local TARGET_PLACE = 6766156863
local RATE_LIMIT_PER_SEC = 400

local PRODUCT_ID       = 3437507722
local GIFT_PRODUCT_ID  = 3437508404
local PRODUCT_NAME     = "GamepassHalloween"
local QUEST_ID         = "Event_Halloween2025"
local SCARECROW_PET_ID = "7925B6CA-8477-4872-AC40-8E179AFBCEDE"
local BUY_DEBOUNCE     = 3

local CLR = {
	ok     = Color3C.fromRGB(120, 230, 120),
	warn   = Color3C.fromRGB(255, 210, 80),
	bad    = Color3C.fromRGB(235, 120, 120),
	text   = Color3C.fromRGB(235, 235, 235),
	rowOk  = Color3C.fromRGB(70, 200, 90),
	rowMid = Color3C.fromRGB(230, 160, 60),
}

local QUEST_ROWS = {
	{ id = "CollectPumpkins1000",          label = "Тыквы: 1000" },
	{ id = "Play3hHalloween",              label = "Наиграть 3 ч" },
	{ id = "Workout10000Halloween",        label = "Тренировки: 10000" },
	{ id = "CollectPumpkins25000",         label = "Тыквы: 25000" },
	{ id = "PlayWithFriend360Halloween",   label = "С другом: 6 ч" },
	{ id = "Claim",                        label = "Забрать награду" },
}

local log = function(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	pcall(print, "[QuestBoard] " .. table.concat(parts, " "))
end

--====================================================================
-- ОЖИДАНИЕ ИГРЫ
--====================================================================
if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
if not plr then
	plr = Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer
end
if not plr then error("[QuestBoard] LocalPlayer не найден") end

--====================================================================
-- НАСТРОЙКИ
--====================================================================
local function loadConfig()
	local raw
	pcall(function() raw = readfile(CONFIG_FILE) end)
	if not raw then return {} end
	local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok and type(t) == "table" then return t end
	return {}
end
local cfg = loadConfig()
cfg.recipient = tostring(cfg.recipient or "")

local function saveConfig()
	pcall(function()
		writefile(CONFIG_FILE, HttpService:JSONEncode({
			x = cfg.x, y = cfg.y, visible = cfg.visible, recipient = cfg.recipient,
		}))
	end)
end

--====================================================================
-- ЛИМИТЕР + ДЕБАУНС
--====================================================================
local rateLast = 0
local function rateLimit()
	local minGap = 1 / RATE_LIMIT_PER_SEC
	local d = os.clock() - rateLast
	if d < minGap then task.wait(minGap - d) end
	rateLast = os.clock()
end
local lastBuy = 0
local function buyDebounced()
	if os.clock() - lastBuy < BUY_DEBOUNCE then return false end
	lastBuy = os.clock()
	return true
end

--====================================================================
-- МОДУЛИ
--====================================================================
local TGSMisc, Q, Event, DS, StatsEnum
pcall(function() TGSMisc = require(workspace.Lib.TGSMisc) end)
pcall(function() Q = require(workspace.Lib.QuestSystem.TGSSimpleQuests) end)
pcall(function() Event = require(workspace.Src.Configs.Events.Event_Halloween2025) end)
pcall(function() DS = require(workspace.Lib.Data.TGSDataStore) end)
pcall(function() StatsEnum = require(workspace.Lib.Data.StatsEnum) end)

local function resolveRemote(name, class)
	if TGSMisc then
		local helper = (class == "RemoteFunction") and TGSMisc.RemoteFunction or TGSMisc.RemoteEvent
		if type(helper) == "function" then
			local ok, r = pcall(helper, name)
			if ok and typeof(r) == "Instance" then return r end
		end
	end
	return ReplicatedStorage:FindFirstChild(name)
end

local giftRemote = resolveRemote("TGSDeveloperProductGifting_BuyProductAsGift", "RemoteFunction")
local promptFallbackRemote = resolveRemote("TGSDeveloperProducts_PromptBuyProduct", "RemoteEvent")

--====================================================================
-- КВЕСТ / ПЕТ
--====================================================================
local function objectiveMax(id)
	if Event then
		for _, obj in ipairs(Event.Objectives) do
			if obj.Id == id then return obj.MaxValue, obj.Title end
		end
	end
	return nil, nil
end

local function questProgress(id)
	if not Q or not Event then return nil end
	local max = objectiveMax(id) or 1
	local ok, v = pcall(Q.GetObjectiveProgress, plr, Event, { Id = id, MaxValue = max })
	if ok and type(v) == "number" then return v end
	return nil
end

local function hasScarecrow()
	if not DS or not StatsEnum then return false end
	local ok, res = pcall(function()
		local pets = DS.GetStat(plr, StatsEnum.OwnedSeasonPets) or {}
		for k, v in pairs(pets) do
			if tostring(k) == SCARECROW_PET_ID then return true end
			local t = type(v) == "table" and (v.Title or v.PetName or v.Name) or nil
			if tostring(t or k):lower():find("scarecrow") then return true end
		end
		return false
	end)
	return ok and res or false
end

--====================================================================
-- СОСТОЯНИЕ UI
--====================================================================
local LOG_MAX = 40
local logBuffer = {}
local statusText = "Готов. Ничего не куплено."
local statusColor = CLR.warn
local unloaded = false
local petWatchGen = 0

local function pushLog(text)
	log(text)
	logBuffer[#logBuffer + 1] = "• " .. text
	while #logBuffer > LOG_MAX do table.remove(logBuffer, 1) end
end

local function setStatus(text, color)
	statusText = text
	statusColor = color or CLR.warn
	log(text)
end

local conns = {}
local function track(c) conns[#conns + 1] = c; return c end

--====================================================================
-- ОПЛАТА / ПОКУПКА
--====================================================================
local function buySelf()
	if not buyDebounced() then return end
	local ok, err = pcall(function()
		rateLimit()
		MarketplaceService:PromptProductPurchase(plr, PRODUCT_ID)
	end)
	if not ok then
		log("Клиентский промпт не открылся: " .. tostring(err))
		if promptFallbackRemote then
			pcall(function() promptFallbackRemote:FireServer(PRODUCT_NAME) end)
			setStatus("Промпт через сервер...", CLR.warn)
		else
			setStatus("Не удалось открыть промпт", CLR.bad)
		end
		return
	end
	setStatus("Оплата: 1999 R$ через промпт Roblox. Жду результат...", CLR.warn)
end

local function doGift(userId)
	if not buyDebounced() then return end
	userId = tonumber(userId)
	if not userId or userId < 1 then
		setStatus("UserId не число", CLR.bad)
		return
	end
	if not giftRemote then
		setStatus("gift-remote не найден (игра обновилась?)", CLR.bad)
		return
	end
	setStatus(("Запрос подарка на UserId %d..."):format(userId), CLR.warn)
	task.spawn(function()
		local ok, err = pcall(function()
			rateLimit()
			return giftRemote:InvokeServer(PRODUCT_NAME, userId)
		end)
		if ok then
			setStatus("Сервер принял — оплати промпт подарка (1999 R$)", CLR.warn)
		else
			setStatus("Ошибка подарка: " .. tostring(err), CLR.bad)
		end
	end)
end

local function watchPet(seconds)
	petWatchGen = petWatchGen + 1
	local myGen = petWatchGen
	task.spawn(function()
		local deadline = os.clock() + (seconds or 90)
		while os.clock() < deadline and petWatchGen == myGen and not unloaded do
			if hasScarecrow() then
				setStatus("Scarecrow (Legendary) выдан! Квест закрыт сервером.", CLR.ok)
				return
			end
			task.wait(1)
		end
	end)
end

--====================================================================
-- ГРУППЫ GUI
--====================================================================
local function containerRoots()
	local roots = {}
	local ok, h = pcall(function() return gethui() end)
	if ok and h then roots[#roots + 1] = h end
	local ok2, pg = pcall(function() return plr:FindFirstChild("PlayerGui") end)
	if ok2 and pg then roots[#roots + 1] = pg end
	return roots
end

local cachedGui = nil

local function findLive()
	if cachedGui then
		local ok, parent = pcall(function() return cachedGui.Parent end)
		if ok and parent ~= nil then return cachedGui end
	end
	for _, root in ipairs(containerRoots()) do
		local ok, kids = pcall(function() return root:GetChildren() end)
		if ok then
			for _, c in ipairs(kids) do
				local ok2, name = pcall(function() return c.Name end)
				if ok2 and name == SCRIPT_NAME then
					cachedGui = c
					return c
				end
			end
		end
	end
	return nil
end

local function destroyOldGuis(except)
	for _, root in ipairs(containerRoots()) do
		local ok, kids = pcall(function() return root:GetChildren() end)
		if ok then
			for _, c in ipairs(kids) do
				if c ~= except then
					pcall(function()
						if c.Name == SCRIPT_NAME then c:Destroy() end
					end)
				end
			end
		end
	end
end

local function unload()
	if unloaded then return end
	unloaded = true
	local gui = findLive()
	if gui and gui:FindFirstChild("Main") then
		local m = gui.Main
		pcall(function()
			cfg.x = math.floor(m.AbsolutePosition.X)
			cfg.y = math.floor(m.AbsolutePosition.Y)
			cfg.visible = m.Visible
			saveConfig()
		end)
	end
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}
	destroyOldGuis(nil)
	if getgenv then getgenv().__SM_qb_unloaded = true end
	log("Выгружено")
end

local function new(class, props)
	local inst = InstanceC.new(class)
	for k, v in pairs(props or {}) do inst[k] = v end
	return inst
end

local function buildGui()
	local parent = containerRoots()[1]
	local gui = new("ScreenGui", {
		Name = SCRIPT_NAME,
		ResetOnSpawn = false,
		ZIndexBehavior = EnumC.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
		Parent = parent,
	})
	cachedGui = gui
	pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)

	local W, H = 400, 596
	local main = new("Frame", {
		Name = "Main",
		Size = UDim2C.fromOffset(W, H),
		Position = UDim2C.fromOffset(tonumber(cfg.x) or 24, tonumber(cfg.y) or 80),
		BackgroundColor3 = Color3C.fromRGB(24, 24, 28),
		BorderSizePixel = 0,
		Visible = cfg.visible ~= false,
		Parent = gui,
	})
	new("UICorner", { CornerRadius = UDimC.new(0, 8), Parent = main })
	new("UIStroke", { Color = Color3C.fromRGB(70, 70, 80), Thickness = 1, Parent = main })

	local title = new("TextLabel", {
		Name = "Title",
		Size = UDim2C.new(1, 0, 0, 34),
		BackgroundColor3 = Color3C.fromRGB(42, 30, 50),
		BorderSizePixel = 0,
		Text = "  Strongman • Halloween Quest board",
		TextColor3 = Color3C.fromRGB(245, 235, 255),
		TextSize = 14,
		Font = EnumC.Font.GothamBold,
		TextXAlignment = EnumC.TextXAlignment.Left,
		Parent = main,
	})
	new("UICorner", { CornerRadius = UDimC.new(0, 8), Parent = title })

	new("TextLabel", {
		Name = "Info",
		Size = UDim2C.new(1, -20, 0, 36),
		Position = UDim2C.fromOffset(10, 40),
		BackgroundTransparency = 1,
		Text = "Продукт 3437507722 «Halloween 2025 - Quest board» — 1999 R$\nGIFT: 3437508404. Оплата реальная (промпт Roblox).",
		TextColor3 = Color3C.fromRGB(210, 210, 220),
		TextSize = 12,
		Font = EnumC.Font.Gotham,
		TextXAlignment = EnumC.TextXAlignment.Left,
		TextYAlignment = EnumC.TextYAlignment.Top,
		TextWrapped = true,
		Parent = main,
	})

	new("TextButton", {
		Name = "BuyBtn",
		Size = UDim2C.new(1, -20, 0, 40),
		Position = UDim2C.fromOffset(10, 80),
		BackgroundColor3 = Color3C.fromRGB(40, 120, 60),
		BorderSizePixel = 0,
		Text = "КУПИТЬ — 1999 R$",
		TextColor3 = Color3C.fromRGB(255, 255, 255),
		TextSize = 16,
		Font = EnumC.Font.GothamBold,
		Parent = main,
	})
	new("UICorner", { CornerRadius = UDimC.new(0, 6), Parent = main.BuyBtn })

	new("TextLabel", {
		Name = "Status",
		Size = UDim2C.new(1, -20, 0, 30),
		Position = UDim2C.fromOffset(10, 124),
		BackgroundTransparency = 1,
		Text = statusText,
		TextColor3 = statusColor,
		TextSize = 12,
		Font = EnumC.Font.Gotham,
		TextXAlignment = EnumC.TextXAlignment.Left,
		TextWrapped = true,
		Parent = main,
	})

	new("TextLabel", {
		Name = "GiftTitle",
		Size = UDim2C.new(1, -20, 0, 18),
		Position = UDim2C.fromOffset(10, 158),
		BackgroundTransparency = 1,
		Text = "ПОДАРОК (gift 3437508404, 1999 R$)",
		TextColor3 = Color3C.fromRGB(200, 170, 255),
		TextSize = 12,
		Font = EnumC.Font.GothamBold,
		TextXAlignment = EnumC.TextXAlignment.Left,
		Parent = main,
	})

	new("TextBox", {
		Name = "GiftBox",
		Size = UDim2C.new(1, -150, 0, 28),
		Position = UDim2C.fromOffset(10, 178),
		BackgroundColor3 = Color3C.fromRGB(34, 34, 40),
		BorderSizePixel = 0,
		Text = cfg.recipient,
		PlaceholderText = "UserId получателя (онлайн)",
		TextColor3 = Color3C.fromRGB(235, 235, 235),
		PlaceholderColor3 = Color3C.fromRGB(140, 140, 150),
		TextSize = 13,
		Font = EnumC.Font.Code,
		ClearTextOnFocus = false,
		Parent = main,
	})
	new("UICorner", { CornerRadius = UDimC.new(0, 6), Parent = main.GiftBox })

	new("TextButton", {
		Name = "GiftBtn",
		Size = UDim2C.fromOffset(90, 28),
		Position = UDim2C.new(1, -136, 0, 178),
		BackgroundColor3 = Color3C.fromRGB(90, 60, 150),
		BorderSizePixel = 0,
		Text = "Подарить",
		TextColor3 = Color3C.fromRGB(255, 255, 255),
		TextSize = 13,
		Font = EnumC.Font.GothamBold,
		Parent = main,
	})
	new("UICorner", { CornerRadius = UDimC.new(0, 6), Parent = main.GiftBtn })

	new("TextButton", {
		Name = "SelfBtn",
		Size = UDim2C.fromOffset(44, 28),
		Position = UDim2C.new(1, -42, 0, 178),
		BackgroundColor3 = Color3C.fromRGB(50, 50, 60),
		BorderSizePixel = 0,
		Text = "себе",
		TextColor3 = Color3C.fromRGB(220, 220, 230),
		TextSize = 12,
		Font = EnumC.Font.Gotham,
		Parent = main,
	})
	new("UICorner", { CornerRadius = UDimC.new(0, 6), Parent = main.SelfBtn })

	new("TextLabel", {
		Name = "QuestSummary",
		Size = UDim2C.new(1, -20, 0, 18),
		Position = UDim2C.fromOffset(10, 212),
		BackgroundTransparency = 1,
		Text = "Прогресс квеста",
		TextColor3 = Color3C.fromRGB(200, 200, 210),
		TextSize = 12,
		Font = EnumC.Font.GothamBold,
		TextXAlignment = EnumC.TextXAlignment.Left,
		Parent = main,
	})

	for i, rowDef in ipairs(QUEST_ROWS) do
		local y = 232 + (i - 1) * 24
		local row = new("Frame", {
			Name = "Row_" .. rowDef.id,
			Size = UDim2C.new(1, -20, 0, 20),
			Position = UDim2C.fromOffset(10, y),
			BackgroundColor3 = Color3C.fromRGB(33, 33, 38),
			BorderSizePixel = 0,
			Parent = main,
		})
		new("UICorner", { CornerRadius = UDimC.new(0, 4), Parent = row })
		new("TextLabel", {
			Name = "Label",
			Size = UDim2C.new(0, 170, 1, 0),
			Position = UDim2C.fromOffset(8, 0),
			BackgroundTransparency = 1,
			Text = rowDef.label,
			TextColor3 = Color3C.fromRGB(230, 230, 235),
			TextSize = 12,
			Font = EnumC.Font.Gotham,
			TextXAlignment = EnumC.TextXAlignment.Left,
			Parent = row,
		})
		local barBg = new("Frame", {
			Name = "BarBg",
			Size = UDim2C.new(0, 130, 0, 8),
			Position = UDim2C.new(0, 180, 0.5, -4),
			BackgroundColor3 = Color3C.fromRGB(20, 20, 24),
			BorderSizePixel = 0,
			Parent = row,
		})
		new("UICorner", { CornerRadius = UDimC.new(1, 0), Parent = barBg })
		new("Frame", {
			Name = "BarFill",
			Size = UDim2C.new(0, 0, 1, 0),
			BackgroundColor3 = CLR.rowMid,
			BorderSizePixel = 0,
			Parent = barBg,
		})
		new("UICorner", { CornerRadius = UDimC.new(1, 0), Parent = barBg.BarFill })
		new("TextLabel", {
			Name = "Value",
			Size = UDim2C.new(0, 70, 1, 0),
			Position = UDim2C.new(1, -74, 0, 0),
			BackgroundTransparency = 1,
			Text = "?",
			TextColor3 = CLR.text,
			TextSize = 11,
			Font = EnumC.Font.Code,
			TextXAlignment = EnumC.TextXAlignment.Right,
			Parent = row,
		})
	end

	new("TextLabel", {
		Name = "PetStatus",
		Size = UDim2C.new(1, -20, 0, 20),
		Position = UDim2C.fromOffset(10, 380),
		BackgroundTransparency = 1,
		Text = "Scarecrow (Legendary): ?",
		TextColor3 = CLR.bad,
		TextSize = 13,
		Font = EnumC.Font.GothamBold,
		TextXAlignment = EnumC.TextXAlignment.Left,
		Parent = main,
	})

	local logBg = new("Frame", {
		Name = "LogBg",
		Size = UDim2C.new(1, -20, 0, 120),
		Position = UDim2C.fromOffset(10, 404),
		BackgroundColor3 = Color3C.fromRGB(18, 18, 22),
		BorderSizePixel = 0,
		Parent = main,
	})
	new("UICorner", { CornerRadius = UDimC.new(0, 6), Parent = logBg })
	local logScroll = new("ScrollingFrame", {
		Name = "LogScroll",
		Size = UDim2C.new(1, -12, 1, -12),
		Position = UDim2C.fromOffset(6, 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2C.new(0, 0, 0, 0),
		ScrollBarThickness = 4,
		Parent = logBg,
	})
	new("UIListLayout", {
		Padding = UDimC.new(0, 1),
		SortOrder = EnumC.SortOrder.LayoutOrder,
		Parent = logScroll,
	})
	for i = 1, LOG_MAX do
		new("TextLabel", {
			Name = "Line_" .. i,
			BackgroundTransparency = 1,
			Size = UDim2C.new(1, -6, 0, 16),
			Font = EnumC.Font.Code,
			TextSize = 12,
			TextXAlignment = EnumC.TextXAlignment.Left,
			TextColor3 = Color3C.fromRGB(200, 200, 205),
			Text = "",
			TextTruncate = EnumC.TextTruncate.AtEnd,
			LayoutOrder = i,
			Parent = logScroll,
		})
	end

	new("TextButton", {
		Name = "UnloadBtn",
		Size = UDim2C.fromOffset(90, 30),
		Position = UDim2C.fromOffset(10, H - 40),
		BackgroundColor3 = Color3C.fromRGB(120, 40, 40),
		BorderSizePixel = 0,
		Text = "Unload (X)",
		TextColor3 = Color3C.fromRGB(255, 235, 235),
		TextSize = 13,
		Font = EnumC.Font.GothamBold,
		Parent = main,
	})
	new("UICorner", { CornerRadius = UDimC.new(0, 6), Parent = main.UnloadBtn })

	new("TextLabel", {
		Name = "Hint",
		Size = UDim2C.new(1, -120, 0, 30),
		Position = UDim2C.fromOffset(106, H - 40),
		BackgroundTransparency = 1,
		Text = "RightShift — скрыть/показать",
		TextColor3 = Color3C.fromRGB(150, 150, 160),
		TextSize = 12,
		Font = EnumC.Font.Gotham,
		TextXAlignment = EnumC.TextXAlignment.Right,
		Parent = main,
	})

	return gui
end

--====================================================================
-- ПОДКЛЮЧЕНИЕ КНОПОК (один раз на инстанс)
--====================================================================
local function wireOnce(gui, main)
	local function mark(inst)
		if not inst then return false end
		local ok, wired = pcall(function() return inst:GetAttribute("QBWired") end)
		if wired then return false end
		pcall(function() inst:SetAttribute("QBWired", true) end)
		return true
	end

	local buy = main:FindFirstChild("BuyBtn")
	if mark(buy) then
		buy.MouseButton1Click:Connect(function() pcall(buySelf) end)
	end

	local giftBtn = main:FindFirstChild("GiftBtn")
	if mark(giftBtn) then
		giftBtn.MouseButton1Click:Connect(function()
			local box = main:FindFirstChild("GiftBox")
			cfg.recipient = box and box.Text or ""
			saveConfig()
			pcall(doGift, cfg.recipient)
		end)
	end

	local selfBtn = main:FindFirstChild("SelfBtn")
	if mark(selfBtn) then
		selfBtn.MouseButton1Click:Connect(function()
			pcall(function()
				local box = main:FindFirstChild("GiftBox")
				if box then box.Text = tostring(plr.UserId) end
				cfg.recipient = tostring(plr.UserId)
				saveConfig()
			end)
		end)
	end

	local giftBox = main:FindFirstChild("GiftBox")
	if mark(giftBox) then
		giftBox.FocusLost:Connect(function()
			cfg.recipient = giftBox.Text
			saveConfig()
		end)
	end

	local unloadBtn = main:FindFirstChild("UnloadBtn")
	if mark(unloadBtn) then
		unloadBtn.MouseButton1Click:Connect(function() pcall(unload) end)
	end

	local title = main:FindFirstChild("Title")
	if mark(title) then
		local dragging, dragStart, startPos
		title.InputBegan:Connect(function(input)
			local t = input.UserInputType
			if t == EnumC.UserInputType.MouseButton1 or t == EnumC.UserInputType.Touch then
				dragging = true
				dragStart = UserInputService:GetMouseLocation()
				startPos = Vector2C.new(main.AbsolutePosition.X, main.AbsolutePosition.Y)
			end
		end)
		track(UserInputService.InputChanged:Connect(function(input)
			if dragging then
				local t = input.UserInputType
				if t == EnumC.UserInputType.MouseMovement or t == EnumC.UserInputType.Touch then
					local delta = UserInputService:GetMouseLocation() - dragStart
					main.Position = UDim2C.fromOffset(startPos.X + delta.X, startPos.Y + delta.Y)
				end
			end
		end))
		track(UserInputService.InputEnded:Connect(function(input)
			local t = input.UserInputType
			if dragging and (t == EnumC.UserInputType.MouseButton1 or t == EnumC.UserInputType.Touch) then
				dragging = false
				cfg.x = math.floor(main.AbsolutePosition.X)
				cfg.y = math.floor(main.AbsolutePosition.Y)
				saveConfig()
			end
		end))
	end
end

--====================================================================
-- РЕНДЕР (живое дерево по именам)
--====================================================================
local function render()
	pcall(function()
	local gui = findLive()
	if not gui then return end
	local main = gui:FindFirstChild("Main")
	if not main then return end
	pcall(wireOnce, gui, main)

	local done = 0
	for _, rowDef in ipairs(QUEST_ROWS) do
		local row = main:FindFirstChild("Row_" .. rowDef.id)
		if row then
			local value = row:FindFirstChild("Value")
			local barFill = row:FindFirstChild("BarBg")
			barFill = barFill and barFill:FindFirstChild("BarFill")
			local max = objectiveMax(rowDef.id) or 1
			local prog = questProgress(rowDef.id)
			if value and barFill then
				if prog then
					value.Text = tostring(prog) .. "/" .. tostring(max)
					if prog >= max then
						done = done + 1
						value.TextColor3 = CLR.ok
						barFill.BackgroundColor3 = CLR.rowOk
					else
						value.TextColor3 = CLR.text
						barFill.BackgroundColor3 = CLR.rowMid
					end
					barFill.Size = UDim2C.new(math.clamp(prog / max, 0, 1), 0, 1, 0)
				else
					value.Text = "?/" .. tostring(max)
				end
			end
		end
	end

	pcall(function()
		local s = main:FindFirstChild("QuestSummary")
		if s then s.Text = ("Прогресс квеста — цели: %d/6"):format(done) end
	end)

	local owned = hasScarecrow()
	pcall(function()
		local p = main:FindFirstChild("PetStatus")
		if p then
			if owned then
				p.Text = "Scarecrow (Legendary): ПОЛУЧЕН"
				p.TextColor3 = CLR.ok
			else
				p.Text = "Scarecrow (Legendary): нет"
				p.TextColor3 = CLR.bad
			end
		end
	end)

	pcall(function()
		local st = main:FindFirstChild("Status")
		if st then
			st.Text = statusText
			st.TextColor3 = statusColor
		end
	end)

	pcall(function()
		local scroll = main:FindFirstChild("LogBg")
		scroll = scroll and scroll:FindFirstChild("LogScroll")
		if not scroll then return end
		for i = 1, LOG_MAX do
			local line = scroll:FindFirstChild("Line_" .. i)
			if line then
				line.Text = logBuffer[i] or ""
				line.LayoutOrder = i
			end
		end
		scroll.CanvasSize = UDim2C.new(0, 0, 0, math.max(1, #logBuffer) * 17)
	end)
end

--====================================================================
-- АНТИ-АФК + СОБЫТИЯ
--====================================================================
track(plr.Idled:Connect(function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2C.new())
	end)
end))

track(MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
	if userId ~= plr.UserId then return end
	if productId == PRODUCT_ID then
		if wasPurchased then
			setStatus("Оплата прошла! Сервер: InstantComplete → Scarecrow...", CLR.ok)
			watchPet(90)
		else
			setStatus("Покупка отменена", CLR.bad)
		end
	elseif productId == GIFT_PRODUCT_ID then
		if wasPurchased then
			setStatus("Подарок оплачен! Жду выдачу получателю.", CLR.ok)
		else
			setStatus("Покупка подарка отменена", CLR.bad)
		end
	end
end))

if Q and typeof(Q.ObjectiveProgressedClientEvent) == "Instance" then
	track(Q.ObjectiveProgressedClientEvent.OnClientEvent:Connect(function(questId)
		if questId == QUEST_ID then task.spawn(function() pcall(render) end) end
	end))
end
if Q and typeof(Q.QuestFinishedClientEvent) == "Instance" then
	track(Q.QuestFinishedClientEvent.OnClientEvent:Connect(function(questId)
		if questId == QUEST_ID then
			pushLog("Сервер закрыл квест Event_Halloween2025")
			watchPet(30)
		end
	end))
end

--====================================================================
-- ВЫГРУЗКА (функция объявлена выше, здесь только хоткеи)
--====================================================================

track(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	pcall(function()
		if input.KeyCode == EnumC.KeyCode.RightShift then
			local gui = findLive()
			local m = gui and gui:FindFirstChild("Main")
			if m then
				m.Visible = not m.Visible
				cfg.visible = m.Visible
				saveConfig()
			end
		elseif input.KeyCode == EnumC.KeyCode.X then
			unload()
		end
	end)
end))

--====================================================================
-- СТАРТ
--====================================================================
destroyOldGuis(nil)
buildGui()
render()
pushLog("Скрипт запущен. Продукт 1999 R$, выдача — на стороне сервера.")
if game.PlaceId ~= TARGET_PLACE then
	pushLog(("Внимание: PlaceId %d, а скрипт для %d"):format(game.PlaceId, TARGET_PLACE))
end
render()

-- цикл поддержки (лечит любые пересоздания дерева executor'ом)
task.spawn(function()
	while not unloaded do
		pcall(render)
		task.wait(2)
	end
end)

-- сетевые проверки (после них capability может срезаться)
task.spawn(function()
	local ok, info = pcall(function() return MarketplaceService:GetProductInfo(PRODUCT_ID, Enum.InfoType.Product) end)
	if ok and info then
		pushLog(("Продукт: %s — %s R$, в продаже: %s"):format(tostring(info.Name), tostring(info.PriceInRobux), tostring(info.IsForSale)))
	end
	local ok2, info2 = pcall(function() return MarketplaceService:GetProductInfo(GIFT_PRODUCT_ID, Enum.InfoType.Product) end)
	if ok2 and info2 then
		pushLog(("Gift: %s — %s R$, в продаже: %s"):format(tostring(info2.Name), tostring(info2.PriceInRobux), tostring(info2.IsForSale)))
	end
	pushLog("GUI готов")
end)

if getgenv then
	getgenv().StrongmanQuestBoard = {
		buy = buySelf,
		gift = doGift,
		unload = unload,
		refresh = render,
		hasScarecrow = hasScarecrow,
		productId = PRODUCT_ID,
		giftProductId = GIFT_PRODUCT_ID,
		show = function() pcall(function() local g = findLive(); local m = g and g:FindFirstChild("Main"); if m then m.Visible = true; cfg.visible = true; saveConfig() end end) end,
		hide = function() pcall(function() local g = findLive(); local m = g and g:FindFirstChild("Main"); if m then m.Visible = false; cfg.visible = false; saveConfig() end end) end,
	}
end

end, function(e)
	if getgenv then
		pcall(function()
			getgenv().__SM_qb_error = tostring(e) .. " @ " .. tostring(debug.traceback("", 2))
		end)
	end
	pcall(print, "[QuestBoard] ОШИБКА: " .. tostring(e))
end)

if not __ok then
	warn("[QuestBoard] скрипт упал: " .. tostring(__err))
end
