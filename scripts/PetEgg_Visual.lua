-- SIGMATIK | t.me/sigmatik323 | obfuscate-failed, raw copy
--!strict
-- PetEggVisual — анимация яйца: парение, вращение, свечение, искры + вылупление.
-- start() запускает idle, hatch() проигрывает анимацию вылупления (yield).
-- Двигает все части с именами Egg* и Cap* (Egg, Egg_Inner, Cap, Cap_Inner).

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local model = script.Parent

local eggParts: { BasePart } = {}
local capParts: { BasePart } = {}
local eggBases: { CFrame } = {}
local capBases: { CFrame } = {}

for _, ch in ipairs(model:GetChildren()) do
	if ch:IsA("BasePart") then
		if string.sub(ch.Name, 1, 3) == "Egg" then
			table.insert(eggParts, ch)
			table.insert(eggBases, ch.CFrame)
		elseif string.sub(ch.Name, 1, 3) == "Cap" then
			table.insert(capParts, ch)
			table.insert(capBases, ch.CFrame)
		end
	end
end

local egg = model:WaitForChild("Egg") :: BasePart

local PetEggVisual = {}

local started = false
local animating = false

-- тёплое свечение изнутри
local glow = Instance.new("PointLight")
glow.Name = "HatchGlow"
glow.Color = Color3.fromRGB(255, 236, 200)
glow.Range = 14
glow.Brightness = 0
glow.Parent = egg

-- искры вокруг яйца
local sparkles = Instance.new("ParticleEmitter")
sparkles.Name = "HatchSparkles"
sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 246, 220))
sparkles.LightEmission = 1
sparkles.Rate = 7
sparkles.Lifetime = NumberRange.new(1.2, 2.2)
sparkles.Speed = NumberRange.new(1.5, 3)
sparkles.SpreadAngle = Vector2.new(25, 25)
sparkles.Size = NumberSequence.new(0.14, 0)
sparkles.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.15),
	NumberSequenceKeypoint.new(0.5, 0.05),
	NumberSequenceKeypoint.new(1, 1),
})
sparkles.Acceleration = Vector3.new(0, 1.1, 0)
sparkles.EmissionDirection = Enum.NormalId.Top
sparkles.Parent = egg

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
		local t = idleTransform(now)
		applyParts(eggParts, eggBases, t)
		applyParts(capParts, capBases, t)
		glow.Brightness = 2.5 + math.sin(now * 2.2) * 1.2
	end)
end

function PetEggVisual.hatch()
	if animating then
		return
	end
	animating = true
	started = true

	-- тряска с нарастанием
	local shakeTime = 1.6
	local t0 = os.clock()
	while os.clock() - t0 < shakeTime do
		local k = (os.clock() - t0) / shakeTime
		local p = 0.05 + k * 0.16
		local r = CFrame.Angles((math.random() - 0.5) * p, (math.random() - 0.5) * p, (math.random() - 0.5) * p)
		local off = CFrame.new((math.random() - 0.5) * p * 2, (math.random() - 0.5) * p, (math.random() - 0.5) * p * 2) * r
		applyParts(eggParts, eggBases, off)
		applyParts(capParts, capBases, off)
		glow.Brightness = 3 + 9 * k
		task.wait(0.04)
	end
	applyParts(eggParts, eggBases, CFrame.new())
	applyParts(capParts, capBases, CFrame.new())

	-- крышка слетает + вспышка
	local capT = CFrame.new(0.7, 1.5, 0.25) * CFrame.Angles(math.rad(30), 0, math.rad(22))
	local ti = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for i, p in ipairs(capParts) do
		tw(p, ti, { CFrame = capBases[i] * capT })
	end
	tw(glow, TweenInfo.new(0.25), { Brightness = 30 })
	sparkles:Emit(90)
	task.wait(0.95)

	-- крышка возвращается, яйцо собирается
	local backTi = TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	for i, p in ipairs(capParts) do
		tw(p, backTi, { CFrame = capBases[i] })
	end
	tw(glow, TweenInfo.new(0.85), { Brightness = 3 })
	task.wait(0.9)

	animating = false
end

return PetEggVisual
