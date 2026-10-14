-- SIGMATIK | t.me/sigmatik323 | obfuscate-failed, raw copy
--!strict
-- PetEggVisual — цельное белое яйцо: парение, вращение, мягкое свечение, искры.
-- hatch(template, player): тряска → скорлупа раскрывается → пет выходит из яйца и летит к игроку.
-- Возвращает true, когда всё доиграно; false — если анимация уже идёт (пропуск).

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local model = script.Parent

local whole = model:WaitForChild("Egg_Whole") :: BasePart
local egg = model:WaitForChild("Egg") :: BasePart

local eggParts: { BasePart } = {}
local capParts: { BasePart } = {}
local allParts: { BasePart } = {}
local allBases: { CFrame } = {}
local eggBases: { CFrame } = {}
local capBases: { CFrame } = {}

for _, ch in ipairs(model:GetChildren()) do
	if ch:IsA("BasePart") then
		local p3 = string.sub(ch.Name, 1, 3)
		if p3 == "Egg" or p3 == "Cap" then
			table.insert(allParts, ch)
			table.insert(allBases, ch.CFrame)
			if ch ~= whole then
				if p3 == "Egg" then
					table.insert(eggParts, ch)
					table.insert(eggBases, ch.CFrame)
				else
					table.insert(capParts, ch)
					table.insert(capBases, ch.CFrame)
				end
			end
		end
	end
end

local PetEggVisual = {}
local started = false
local animating = false

local function setWhole(on: boolean)
	whole.Transparency = on and 0 or 1
	whole.CastShadow = on
end

local function setPieces(on: boolean)
	for _, p in ipairs(allParts) do
		if p ~= whole then
			p.Transparency = on and 0 or 1
			p.CastShadow = on
		end
	end
end

setWhole(true)
setPieces(false)

-- мягкое свечение изнутри
local glow = Instance.new("PointLight")
glow.Name = "HatchGlow"
glow.Color = Color3.fromRGB(255, 238, 205)
glow.Range = 11
glow.Brightness = 0
glow.Parent = egg

-- искры вокруг яйца
local sparkles = Instance.new("ParticleEmitter")
sparkles.Name = "HatchSparkles"
sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 246, 220))
sparkles.LightEmission = 1
sparkles.Rate = 6
sparkles.Lifetime = NumberRange.new(1.2, 2.2)
sparkles.Speed = NumberRange.new(1.2, 2.6)
sparkles.SpreadAngle = Vector2.new(25, 25)
sparkles.Size = NumberSequence.new(0.13, 0)
sparkles.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.15),
	NumberSequenceKeypoint.new(0.5, 0.05),
	NumberSequenceKeypoint.new(1, 1),
})
sparkles.Acceleration = Vector3.new(0, 1.1, 0)
sparkles.EmissionDirection = Enum.NormalId.Top
sparkles.Parent = egg

-- звуки (встроенные)
local function mkSound(name: string, id: string, vol: number): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = vol
	s.RollOffMaxDistance = 70
	s.Parent = egg
	return s
end

local sndCrack = mkSound("EggCrack", "rbxasset://sounds/switch3.wav", 0.8)
local sndBoom = mkSound("EggBoom", "rbxasset://sounds/bass.wav", 0.5)
local sndPing = mkSound("EggPing", "rbxasset://sounds/electronicpingshort.wav", 0.6)

local function tw(inst: Instance, ti: TweenInfo, props: { [string]: any })
	local t = TweenService:Create(inst, ti, props)
	t:Play()
	return t
end

local function idleTransform(now: number): CFrame
	local bob = math.sin(now * 1.1) * 0.14
	local yaw = now * 0.25
	local sway = CFrame.Angles(math.sin(now * 0.9) * 0.02, 0, math.sin(now * 0.7) * 0.03)
	return CFrame.new(0, bob, 0) * CFrame.Angles(0, yaw, 0) * sway
end

local function applyParts(parts: { BasePart }, bases: { CFrame }, t: CFrame)
	for i, p in ipairs(parts) do
		p.CFrame = bases[i] * t
	end
end

function PetEggVisual.start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(function()
		if animating then
			return
		end
		local now = os.clock()
		applyParts(allParts, allBases, idleTransform(now))
		glow.Brightness = 0.9 + math.sin(now * 2.2) * 0.45
		sparkles.Rate = 5 + math.sin(now * 0.8) * 2
	end)
end

-- осколки скорлупы при расколе
local function spawnShards()
	for _ = 1, 7 do
		local sh = Instance.new("Part")
		sh.Name = "EggShard"
		sh.Size = Vector3.new(math.random(8, 16) / 100, math.random(8, 16) / 100, math.random(8, 16) / 100)
		sh.Material = Enum.Material.SmoothPlastic
		sh.Color = Color3.new(1, 1, 1)
		sh.CanCollide = false
		sh.CanQuery = false
		sh.CanTouch = false
		sh.CastShadow = false
		sh.CFrame = CFrame.new(
			-1 + (math.random() - 0.5) * 0.5,
			4.0 + math.random() * 0.5,
			-87 + (math.random() - 0.5) * 0.5
		)
		sh.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 14, 5 + math.random() * 6, (math.random() - 0.5) * 14)
		sh.AssemblyAngularVelocity = Vector3.new(math.random(-9, 9), math.random(-9, 9), math.random(-9, 9))
		sh.Parent = model
		Debris:AddItem(sh, 2.2)
	end
end

-- пет выходит из яйца и летит к игроку
local function playPetReveal(template: Model, player: Player?)
	local pet = template:Clone()
	pet.Name = "HatchReveal_" .. template.Name
	for _, d in ipairs(pet:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end

	local root = pet:FindFirstChildWhichIsA("BasePart")
	local trail
	if root then
		trail = sparkles:Clone()
		trail.Rate = 26
		trail.Lifetime = NumberRange.new(0.4, 0.9)
		trail.Speed = NumberRange.new(0.2, 1.2)
		trail.Size = NumberSequence.new(0.1, 0)
		trail.Parent = root
	end

	local startPos = Vector3.new(-1, 2.55, -87)
	pet:PivotTo(CFrame.new(startPos))
	local canScale = pcall(function()
		pet:ScaleTo(0.12)
	end)

	pet.Parent = model
	Debris:AddItem(pet, 20)

	-- выход из яйца: подъём с ростом
	local riseTo = Vector3.new(-1, 6.1, -87)
	local steps = 28
	for i = 1, steps do
		local a = i / steps
		local e = 1 - (1 - a) ^ 3
		if canScale then
			pcall(function()
				pet:ScaleTo(0.12 + 0.88 * e)
			end)
		end
		local pos = startPos:Lerp(riseTo, e)
		pet:PivotTo(CFrame.new(pos) * CFrame.Angles(0, a * 5, 0))
		task.wait(0.04)
	end

	-- полёт к игроку
	local flyTime = 1.0
	local t0 = os.clock()
	while os.clock() - t0 < flyTime do
		local a = (os.clock() - t0) / flyTime
		local e = a * a * (3 - 2 * a)
		local target = riseTo + Vector3.new(3, 0.5, 3)
		local char = player and player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			target = hrp.Position + Vector3.new(3, 2, 3)
		end
		local pos = riseTo:Lerp(target, e) + Vector3.new(0, math.sin(math.pi * a) * 1.8, 0)
		pet:PivotTo(CFrame.new(pos) * CFrame.Angles(0, a * 10, 0))
		task.wait(0.03)
	end

	if trail then
		trail.Enabled = false
	end
	if root then
		local burst = sparkles:Clone()
		burst.Rate = 0
		burst.Parent = root
		burst:Emit(45)
	end
	task.wait(0.18)
	pet:Destroy()
end

function PetEggVisual.hatch(template: Model?, player: Player?)
	if animating then
		return false
	end
	animating = true
	started = true

	setWhole(true)
	setPieces(false)

	-- 1. тряска цельного яйца
	local shakeTime = 1.4
	local t0 = os.clock()
	while os.clock() - t0 < shakeTime do
		local k = (os.clock() - t0) / shakeTime
		local p = 0.035 + k * 0.12
		local off = CFrame.new((math.random() - 0.5) * p * 1.6, (math.random() - 0.5) * p, (math.random() - 0.5) * p * 1.6)
			* CFrame.Angles((math.random() - 0.5) * p * 0.7, (math.random() - 0.5) * p * 0.7, (math.random() - 0.5) * p * 0.7)
		applyParts(allParts, allBases, off)
		glow.Brightness = 0.9 + 6 * k + math.random() * 0.6
		task.wait(0.04)
	end

	-- 2. раскол скорлупы: подмена на части, вспышка, крышка слетает
	setWhole(false)
	setPieces(true)
	applyParts(allParts, allBases, CFrame.new())
	sndCrack:Play()
	sndBoom:Play()
	spawnShards()
	sparkles:Emit(70)
	local capT = CFrame.new(0.7, 1.5, 0.25) * CFrame.Angles(math.rad(30), 0, math.rad(22))
	local ti = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for i, p in ipairs(capParts) do
		tw(p, ti, { CFrame = capBases[i] * capT })
	end
	tw(glow, TweenInfo.new(0.18), { Brightness = 12 })
	task.wait(0.55)

	-- 3. пет выходит и летит к игроку; крышка возвращается
	local backTi = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	for i, p in ipairs(capParts) do
		tw(p, backTi, { CFrame = capBases[i] })
	end
	tw(glow, TweenInfo.new(1.4), { Brightness = 0.9 })
	if template then
		sndPing:Play()
		playPetReveal(template, player)
	else
		task.wait(1.0)
	end
	task.wait(0.35)

	-- 4. яйцо снова цельное
	setPieces(false)
	setWhole(true)
	sparkles:Emit(22)
	task.wait(0.1)

	animating = false
	return true
end

return PetEggVisual
