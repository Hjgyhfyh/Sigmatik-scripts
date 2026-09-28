-- SIGMATIK | t.me/sigmatik323 | obfuscate-failed, raw copy
--!strict
-- Панель шансов у яйца: 2D-список петов с 3D-превью, названиями, шансами и бонусами.
-- Появляется с анимацией при подходе к яйцу, при отходе — уезжает.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local petsFolder = RS:WaitForChild("PetsFolder")

local RARITY_COLORS: {[string]: Color3} = {
	["Обычный"] = Color3.fromRGB(190, 190, 190),
	["Редкий"] = Color3.fromRGB(80, 150, 255),
	["Эпический"] = Color3.fromRGB(170, 80, 255),
	["Легендарный"] = Color3.fromRGB(255, 200, 60),
}
local RARITY_POWER: {[string]: number} = {
	["Обычный"] = 1,
	["Редкий"] = 2,
	["Эпический"] = 3,
	["Легендарный"] = 4,
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
screenGui.Name = "EggPetInfoGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5
screenGui.Parent = playerGui

-- ================= Панель (слева, чтобы не мешать инвентарю справа) =================

local PANEL_W = 308
local HIDDEN_X = PANEL_W + 40

local panel = Instance.new("Frame")
panel.Name = "EggPetPanel"
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0, -HIDDEN_X, 0.5, 0)
panel.Size = UDim2.fromOffset(PANEL_W, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
panel.BackgroundTransparency = 0.08
panel.Visible = false
panel.Parent = screenGui
round(panel, 16)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 220, 120)
stroke.Thickness = 2
stroke.Transparency = 0.3
stroke.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local title = makeLabel({
	Size = UDim2.new(1, 0, 0, 28),
	Text = "🥚 Шансы вылупления",
	TextColor3 = Color3.fromRGB(255, 220, 120),
	TextSize = 21,
	TextXAlignment = Enum.TextXAlignment.Left,
})
title.LayoutOrder = 1
title.Parent = panel

local subtitle = makeLabel({
	Size = UDim2.new(1, 0, 0, 16),
	Text = "Подойди и зажми E, чтобы открыть яйцо",
	TextColor3 = Color3.fromRGB(170, 170, 190),
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
})
subtitle.LayoutOrder = 2
subtitle.Parent = panel

local list = Instance.new("Frame")
list.Name = "List"
list.Size = UDim2.new(1, 0, 0, 0)
list.AutomaticSize = Enum.AutomaticSize.Y
list.BackgroundTransparency = 1
list.LayoutOrder = 3
list.Parent = panel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

-- ================= 3D-превью петов =================

local spinners: { { model: Model, center: Vector3, rel: Vector3, phase: number } } = {}

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
	local rel = clone:GetPivot():PointToObjectSpace(center)
	local ext = math.max(bsize.X, bsize.Y, bsize.Z)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(
		center + Vector3.new(ext * 1.1, ext * 0.6, ext * 1.1),
		center + Vector3.new(0, bsize.Y * 0.08, 0)
	)
	vp.CurrentCamera = cam

	table.insert(spinners, { model = clone, center = center, rel = rel, phase = phase })
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, s in ipairs(spinners) do
		s.model:PivotTo(CFrame.new(s.center) * CFrame.Angles(0, t * 0.9 + s.phase, 0) * CFrame.new(-s.rel))
	end
end)

-- ================= Строки списка =================

local rowFrames: { Frame } = {}

local function clearList()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	rowFrames = {}
	spinners = {}
end

local function buildRows()
	clearList()

	local pets = petsFolder:GetChildren()
	local total = 0
	for _, pet in ipairs(pets) do
		total += tonumber(pet:GetAttribute("Chance") or 0) or 0
	end
	if total <= 0 then
		total = 1
	end

	table.sort(pets, function(a, b)
		local ca = tonumber(a:GetAttribute("Chance") or 0) or 0
		local cb = tonumber(b:GetAttribute("Chance") or 0) or 0
		if ca ~= cb then
			return ca > cb
		end
		local ra = RARITY_POWER[a:GetAttribute("Rarity") or "Обычный"] or 0
		local rb = RARITY_POWER[b:GetAttribute("Rarity") or "Обычный"] or 0
		return ra > rb
	end)

	for i, pet in ipairs(pets) do
		local rarity = pet:GetAttribute("Rarity") or "Обычный"
		local rarityColor = RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
		local chance = tonumber(pet:GetAttribute("Chance") or 0) or 0
		local pct = chance / total * 100
		local energyBonus = tonumber(pet:GetAttribute("EnergyBonus") or 0) or 0
		local strengthBonus = tonumber(pet:GetAttribute("StrengthBonus") or 0) or 0

		local row = Instance.new("Frame")
		row.Name = pet.Name
		row.Size = UDim2.new(1, 0, 0, 62)
		row.BackgroundColor3 = Color3.fromRGB(40, 40, 56)
		row.ClipsDescendants = true
		row.LayoutOrder = i
		row.Parent = list
		round(row, 12)
		table.insert(rowFrames, row)

		makePreview(row, pet, 50, i * 1.3)

		local nameText = makeLabel({
			Size = UDim2.new(0.5, 0, 0, 20),
			Position = UDim2.new(0, 60, 0, 6),
			Text = pet.Name,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		nameText.Parent = row

		local rarityText = makeLabel({
			Size = UDim2.new(0.5, 0, 0, 14),
			Position = UDim2.new(0, 60, 0, 26),
			Text = rarity,
			TextColor3 = rarityColor,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		rarityText.Parent = row

		local bonusText = makeLabel({
			Size = UDim2.new(0.5, 0, 0, 14),
			Position = UDim2.new(0, 60, 0, 42),
			Text = "+" .. math.floor(energyBonus * 100 + 0.5) .. "% ⚡  +" .. math.floor(strengthBonus * 100 + 0.5) .. "% 💪",
			TextColor3 = Color3.fromRGB(150, 220, 160),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		bonusText.Parent = row

		local pctText = makeLabel({
			Size = UDim2.new(0, 74, 0, 20),
			Position = UDim2.new(1, -74, 0, 6),
			Text = string.format("%.1f%%", pct):gsub("%.0%%", "%%"),
			TextColor3 = Color3.fromRGB(120, 220, 120),
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		pctText.Parent = row

		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.new(0, 66, 0, 6)
		barBg.Position = UDim2.new(1, -70, 0, 30)
		barBg.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
		barBg.BorderSizePixel = 0
		barBg.Parent = row
		round(barBg, 3)

		local barFill = Instance.new("Frame")
		barFill.Size = UDim2.new(pct / 100, 0, 1, 0)
		barFill.BackgroundColor3 = rarityColor
		barFill.BorderSizePixel = 0
		barFill.Parent = barBg
		round(barFill, 3)

		local hint = makeLabel({
			Size = UDim2.new(0, 110, 0, 14),
			Position = UDim2.new(1, -110, 0, 42),
			Text = "шанс вылупления",
			TextColor3 = Color3.fromRGB(140, 140, 160),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		hint.Parent = row

		row.Size = UDim2.new(1, 0, 0, 0)
		TweenService:Create(
			row,
			TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.08 + i * 0.07),
			{ Size = UDim2.new(1, 0, 0, 62) }
		):Play()
	end
end

-- ================= Показ/скрытие при подходе =================

local eggModel = workspace:WaitForChild("PetEggModel", 30)
local eggPosition
if eggModel then
	eggPosition = eggModel:GetPivot().Position
end

local isShown = false
local SHOW_DISTANCE = 20

local function showPanel()
	if isShown then
		return
	end
	isShown = true
	buildRows()
	panel.Visible = true
	panel.Position = UDim2.new(0, -HIDDEN_X, 0.5, 0)
	TweenService:Create(
		panel,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, 16, 0.5, 0) }
	):Play()
end

local function hidePanel()
	if not isShown then
		return
	end
	isShown = false
	local tween = TweenService:Create(
		panel,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0, -HIDDEN_X, 0.5, 0) }
	)
	tween:Play()
	tween.Completed:Connect(function()
		if not isShown then
			panel.Visible = false
		end
	end)
end

if eggPosition then
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			hidePanel()
			return
		end
		if (hrp.Position - eggPosition).Magnitude <= SHOW_DISTANCE then
			showPanel()
		else
			hidePanel()
		end
	end)
end

petsFolder.ChildAdded:Connect(function()
	if isShown then
		buildRows()
	end
end)
petsFolder.ChildRemoved:Connect(function()
	if isShown then
		buildRows()
	end
end)
