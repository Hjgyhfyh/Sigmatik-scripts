-- SIGMATIK | t.me/sigmatik323 | obfuscate-failed, raw copy
--!strict
-- Инвентарь петов: панель сбоку, все петы списком, клик по пету — карточка
-- с 3D-превью и характеристиками (бонусы, редкость, шанс вылупления).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local petsFolder = RS:WaitForChild("PetsFolder")

local remotes = RS:WaitForChild("PetRemotes")
local equipRemote = remotes:WaitForChild("EquipPet")
local hatchRemote = remotes:WaitForChild("HatchPet")

local RARITY_COLORS: {[string]: Color3} = {
	["Обычный"] = Color3.fromRGB(190, 190, 190),
	["Редкий"] = Color3.fromRGB(80, 150, 255),
	["Эпический"] = Color3.fromRGB(170, 80, 255),
	["Легендарный"] = Color3.fromRGB(255, 200, 60),
}

local function round(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeLabel(props: {[string]: any}): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do
		(l :: any)[k] = v
	end
	return l
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PetGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 6
screenGui.Parent = playerGui

-- ================= Кнопка "Петы" =================

local openBtn = Instance.new("TextButton")
openBtn.Name = "OpenPetsButton"
openBtn.AnchorPoint = Vector2.new(1, 1)
openBtn.Position = UDim2.new(1, -20, 1, -20)
openBtn.Size = UDim2.fromOffset(72, 72)
openBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
openBtn.BackgroundTransparency = 0.1
openBtn.Text = ""
openBtn.AutoButtonColor = false
openBtn.Parent = screenGui
round(openBtn, 16)
local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.fromRGB(255, 220, 120)
btnStroke.Thickness = 3
btnStroke.Parent = openBtn
local btnIcon = makeLabel({
	Size = UDim2.fromScale(0.55, 0.6),
	Position = UDim2.fromScale(0.225, 0.05),
	Text = "🐾",
	TextScaled = true,
})
btnIcon.Parent = openBtn
local btnLabel = makeLabel({
	Size = UDim2.new(1, 0, 0, 22),
	Position = UDim2.new(0, 0, 1, -4),
	AnchorPoint = Vector2.new(0, 1),
	Text = "Петы",
	TextColor3 = Color3.fromRGB(255, 220, 120),
	TextScaled = true,
})
btnLabel.Parent = openBtn

-- ================= Панель сбоку =================

local PANEL_W = 340
local HIDDEN_X = PANEL_W + 40

local frame = Instance.new("Frame")
frame.Name = "PetsFrame"
frame.AnchorPoint = Vector2.new(1, 0.5)
frame.Position = UDim2.new(1, HIDDEN_X, 0.5, 0)
frame.Size = UDim2.fromOffset(PANEL_W, 430)
frame.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
frame.BackgroundTransparency = 0.06
frame.ClipsDescendants = true
frame.Visible = false
frame.Parent = screenGui
round(frame, 16)
local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(255, 220, 120)
frameStroke.Thickness = 2
frameStroke.Transparency = 0.3
frameStroke.Parent = frame

local title = makeLabel({
	Size = UDim2.new(1, -80, 0, 30),
	Position = UDim2.new(0, 16, 0, 12),
	Text = "🐾 Мои петомцы",
	TextColor3 = Color3.fromRGB(255, 220, 120),
	TextSize = 23,
	TextXAlignment = Enum.TextXAlignment.Left,
})
title.Parent = frame

local counter = makeLabel({
	Size = UDim2.new(1, -80, 0, 16),
	Position = UDim2.new(0, 16, 0, 40),
	Text = "",
	TextColor3 = Color3.fromRGB(160, 160, 185),
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
})
counter.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(34, 34)
closeBtn.Position = UDim2.new(1, -12, 0, 12)
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.TextSize = 17
closeBtn.Parent = frame
round(closeBtn, 10)

-- Список петов
local list = Instance.new("ScrollingFrame")
list.Name = "PetList"
list.Position = UDim2.new(0, 12, 0, 66)
list.Size = UDim2.new(1, -24, 1, -80)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 150)
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = frame
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = list

local emptyLabel = makeLabel({
	Size = UDim2.new(1, -20, 0, 60),
	Position = UDim2.new(0, 10, 0.5, -30),
	Text = "Пока нет петомцев...\nОткрой яйцо у спавна!",
	TextSize = 19,
})
emptyLabel.Parent = frame

-- ================= Карточка пета (детали) =================

local detail = Instance.new("Frame")
detail.Name = "PetDetail"
detail.Size = UDim2.new(1, 0, 1, 0)
detail.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
detail.BackgroundTransparency = 0.02
detail.Visible = false
detail.Parent = frame
round(detail, 16)

local backBtn = Instance.new("TextButton")
backBtn.Size = UDim2.fromOffset(80, 30)
backBtn.Position = UDim2.new(0, 14, 0, 12)
backBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
backBtn.Text = "‹ Назад"
backBtn.TextColor3 = Color3.new(1, 1, 1)
backBtn.Font = Enum.Font.FredokaOne
backBtn.TextSize = 15
backBtn.Parent = detail
round(backBtn, 9)

local detailTitle = makeLabel({
	Size = UDim2.new(1, -24, 0, 26),
	Position = UDim2.new(0, 12, 0, 50),
	Text = "",
	TextSize = 22,
})
detailTitle.Parent = detail

local detailRarity = makeLabel({
	Size = UDim2.new(1, -24, 0, 18),
	Position = UDim2.new(0, 12, 0, 76),
	Text = "",
	TextSize = 15,
})
detailRarity.Parent = detail

local detailPreviewHolder = Instance.new("Frame")
detailPreviewHolder.Size = UDim2.fromOffset(140, 140)
detailPreviewHolder.Position = UDim2.new(0.5, -70, 0, 100)
detailPreviewHolder.BackgroundTransparency = 1
detailPreviewHolder.Parent = detail

local statEnergy = makeLabel({
	Size = UDim2.new(1, -24, 0, 22),
	Position = UDim2.new(0, 20, 0, 250),
	Text = "",
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
})
statEnergy.Parent = detail

local statStrength = makeLabel({
	Size = UDim2.new(1, -24, 0, 22),
	Position = UDim2.new(0, 20, 0, 276),
	Text = "",
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
})
statStrength.Parent = detail

local statChance = makeLabel({
	Size = UDim2.new(1, -24, 0, 22),
	Position = UDim2.new(0, 20, 0, 302),
	Text = "",
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
})
statChance.Parent = detail

local detailCountInfo = makeLabel({
	Size = UDim2.new(1, -24, 0, 18),
	Position = UDim2.new(0, 20, 0, 326),
	Text = "",
	TextColor3 = Color3.fromRGB(160, 160, 185),
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
})
detailCountInfo.Parent = detail

local equipBtn = Instance.new("TextButton")
equipBtn.Size = UDim2.new(1, -40, 0, 46)
equipBtn.Position = UDim2.new(0, 20, 1, -62)
equipBtn.BackgroundColor3 = Color3.fromRGB(90, 160, 90)
equipBtn.Text = "Экипировать"
equipBtn.TextColor3 = Color3.new(1, 1, 1)
equipBtn.Font = Enum.Font.FredokaOne
equipBtn.TextSize = 19
equipBtn.Parent = detail
round(equipBtn, 12)

-- ================= Превью (3D) =================

local spinners: { { model: Model, center: Vector3, phase: number } } = {}

local function makePreview(parent: Instance, template: Model, size: number, phase: number)
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromOffset(size, size)
	vp.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	vp.BackgroundTransparency = 0.1
	vp.Ambient = Color3.fromRGB(175, 175, 190)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-0.45, -1, -0.3)
	vp.Parent = parent
	round(vp, 10)

	local clone = template:Clone()
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	clone.Parent = vp

	local bcf, bsize = clone:GetBoundingBox()
	local center = bcf.Position
	local ext = math.max(bsize.X, bsize.Y, bsize.Z)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(
		center + Vector3.new(ext * 0.95, ext * 0.55, ext * 0.95),
		center + Vector3.new(0, bsize.Y * 0.08, 0)
	)
	vp.CurrentCamera = cam

	table.insert(spinners, { model = clone, center = center, phase = phase })
	return vp
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, s in ipairs(spinners) do
		s.model:PivotTo(CFrame.new(s.center) * CFrame.Angles(0, t * 0.9 + s.phase, 0))
	end
end)

-- ================= Логика =================

local inventory = player:WaitForChild("Pets")
local currentlyEquipped: string? = nil
local selectedName: string? = nil

local function clearSpinners()
	spinners = {}
end

local function refreshList()
	clearSpinners()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Группируем по имени: {имя, количество, образец}
	local groups: { { name: string, count: number, sample: Instance } } = {}
	local byName: { [string]: any } = {}
	for _, pet in ipairs(inventory:GetChildren()) do
		local g = byName[pet.Name]
		if not g then
			g = { name = pet.Name, count = 0, sample = pet }
			byName[pet.Name] = g
			table.insert(groups, g)
		end
		g.count += 1
	end

	table.sort(groups, function(a, b)
		return a.name < b.name
	end)

	counter.Text = "Петомцев: " .. #inventory:GetChildren()
	emptyLabel.Visible = #groups == 0

	for i, g in ipairs(groups) do
		local rarity = g.sample:GetAttribute("Rarity") or "Обычный"
		local rarityColor = RARITY_COLORS[rarity] or Color3.new(1, 1, 1)

		local card = Instance.new("TextButton")
		card.Name = g.name
		card.Size = UDim2.new(1, -6, 0, 64)
		card.BackgroundColor3 = Color3.fromRGB(40, 40, 56)
		card.Text = ""
		card.AutoButtonColor = false
		card.Parent = list
		round(card, 12)

		local template = petsFolder:FindFirstChild(g.name)
		if template then
			makePreview(card, template, 52, i * 1.3)
		end

		local nameText = makeLabel({
			Size = UDim2.new(0.55, 0, 0, 22),
			Position = UDim2.new(0, 64, 0, 8),
			Text = g.name .. (g.count > 1 and ("  ×" .. g.count) or ""),
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		nameText.Parent = card

		local rarityText = makeLabel({
			Size = UDim2.new(0.55, 0, 0, 16),
			Position = UDim2.new(0, 64, 0, 32),
			Text = rarity,
			TextColor3 = rarityColor,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		rarityText.Parent = card

		local arrow = makeLabel({
			Size = UDim2.new(0, 30, 1, 0),
			Position = UDim2.new(1, -36, 0, 0),
			Text = "›",
			TextColor3 = Color3.fromRGB(255, 220, 120),
			TextSize = 26,
		})
		arrow.Parent = card

		if currentlyEquipped == g.name then
			local badge = makeLabel({
				Size = UDim2.new(0, 90, 0, 16),
				Position = UDim2.new(1, -126, 0, 24),
				Text = "Экипирован",
				TextColor3 = Color3.fromRGB(140, 230, 140),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			badge.Parent = card
		end

		card.MouseButton1Click:Connect(function()
			showDetails(g.name)
		end)

		-- Анимация появления карточки
		card.Size = UDim2.new(1, -6, 0, 0)
		TweenService:Create(
			card,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.05 + i * 0.06),
			{ Size = UDim2.new(1, -6, 0, 64) }
		):Play()
	end
end

local function showDetails(name: string)
	selectedName = name
	clearSpinners()
	for _, child in ipairs(detailPreviewHolder:GetChildren()) do
		child:Destroy()
	end

	local template = petsFolder:FindFirstChild(name)
	local rarity = "Обычный"
	local energyBonus, strengthBonus, chancePct = 0, 0, 0
	local count = 0
	for _, pet in ipairs(inventory:GetChildren()) do
		if pet.Name == name then
			count += 1
			rarity = pet:GetAttribute("Rarity") or rarity
		end
	end
	if template then
		energyBonus = tonumber(template:GetAttribute("EnergyBonus") or 0) or 0
		strengthBonus = tonumber(template:GetAttribute("StrengthBonus") or 0) or 0
		local total = 0
		for _, p in ipairs(petsFolder:GetChildren()) do
			total += tonumber(p:GetAttribute("Chance") or 0) or 0
		end
		if total > 0 then
			chancePct = (tonumber(template:GetAttribute("Chance") or 0) or 0) / total * 100
		end
		makePreview(detailPreviewHolder, template, 140, 0)
	end

	detailTitle.Text = name
	detailRarity.Text = rarity
	detailRarity.TextColor3 = RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
	statEnergy.Text = "⚡ Бонус энергии:  +" .. math.floor(energyBonus * 100 + 0.5) .. "%"
	statStrength.Text = "💪 Бонус силы:  +" .. math.floor(strengthBonus * 100 + 0.5) .. "%"
	statChance.Text = "🎲 Шанс вылупления:  " .. string.format("%.1f%%", chancePct):gsub("%.0%%", "%%")
	detailCountInfo.Text = "В инвентаре: " .. count .. (count > 1 and " шт." or "")

	local equippedNow = currentlyEquipped == name
	equipBtn.Text = equippedNow and "Снять" or "Экипировать"
	equipBtn.BackgroundColor3 = equippedNow and Color3.fromRGB(190, 90, 90) or Color3.fromRGB(90, 160, 90)

	detail.Visible = true
	detail.Position = UDim2.new(0, 30, 0, 0)
	TweenService:Create(
		detail,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, 0, 0, 0) }
	):Play()
end

local function hideDetails()
	selectedName = nil
	local tween = TweenService:Create(
		detail,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0, 30, 0, 0) }
	)
	tween:Play()
	tween.Completed:Connect(function()
		detail.Visible = false
		clearSpinners()
		refreshList()
	end)
end

backBtn.MouseButton1Click:Connect(hideDetails)

equipBtn.MouseButton1Click:Connect(function()
	if selectedName then
		equipRemote:FireServer(selectedName)
	end
end)

-- ================= Открытие/закрытие панели =================

local isOpen = false

local function openPanel()
	if isOpen then
		return
	end
	isOpen = true
	frame.Visible = true
	frame.Position = UDim2.new(1, HIDDEN_X, 0.5, 0)
	refreshList()
	TweenService:Create(
		frame,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -14, 0.5, 0) }
	):Play()
end

local function closePanel()
	if not isOpen then
		return
	end
	isOpen = false
	detail.Visible = false
	selectedName = nil
	local tween = TweenService:Create(
		frame,
		TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(1, HIDDEN_X, 0.5, 0) }
	)
	tween:Play()
	tween.Completed:Connect(function()
		if not isOpen then
			frame.Visible = false
			clearSpinners()
		end
	end)
end

openBtn.MouseButton1Click:Connect(function()
	if isOpen then
		closePanel()
	else
		openPanel()
	end
end)
closeBtn.MouseButton1Click:Connect(closePanel)

-- Обновление при изменении инвентаря
inventory.ChildAdded:Connect(function()
	if isOpen then
		refreshList()
	end
end)
inventory.ChildRemoved:Connect(function()
	if isOpen then
		refreshList()
	end
end)

-- Ответ сервера об экипировке
equipRemote.OnClientEvent:Connect(function(petName: string, isEquipped: boolean)
	currentlyEquipped = isEquipped and petName or nil
	if isOpen then
		if selectedName then
			showDetails(selectedName)
		else
			refreshList()
		end
	end
end)

-- Уведомление о вылуплении
local notifLabel = makeLabel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 80),
	Size = UDim2.fromOffset(400, 44),
	BackgroundColor3 = Color3.fromRGB(40, 40, 50),
	BackgroundTransparency = 0.1,
	Text = "",
	TextSize = 20,
})
notifLabel.Visible = false
notifLabel.Parent = screenGui
round(notifLabel, 12)

hatchRemote.OnClientEvent:Connect(function(message: string, color: Color3)
	notifLabel.Text = message
	notifLabel.TextColor3 = color
	notifLabel.Visible = true
	notifLabel.TextTransparency = 0
	notifLabel.Position = UDim2.new(0.5, 0, 0, 60)
	task.delay(2.5, function()
		local tween = TweenService:Create(notifLabel, TweenInfo.new(0.6), {
			Position = UDim2.new(0.5, 0, 0, 20),
			TextTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		notifLabel.Visible = false
	end)
end)
