-- SIGMATIK | t.me/sigmatik323 | obfuscate-failed, raw copy
--!strict
-- PetEggVisual — анимация яйца: парение, вращение, свечение, искры + вылупление.
-- start() запускает idle, hatch() проигрывает анимацию вылупления (yield).

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local model = script.Parent
local Egg = model:WaitForChild("Egg") :: MeshPart
local Cap = model:WaitForChild("Cap") :: MeshPart

local PetEggVisual = {}

local started = false
local animating = false

local eggBase = Egg.CFrame
local capBase = Cap.CFrame

-- тёплое свечение изнутри
local glow = Instance.new("PointLight")
glow.Name = "HatchGlow"
glow.Color = Color3.fromRGB(255, 236, 200)
glow.Range = 14
glow.Brightness = 0
glow.Parent = Egg

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
sparkles.Parent = Egg

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
		Egg.CFrame = eggBase * t
		Cap.CFrame = capBase * t
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
		Egg.CFrame = eggBase * off
		Cap.CFrame = capBase * off
		glow.Brightness = 3 + 9 * k
		task.wait(0.04)
	end
	Egg.CFrame = eggBase
	Cap.CFrame = capBase

	-- крышка слетает + вспышка
	local flyTo = capBase * CFrame.new(0.7, 1.5, 0.25) * CFrame.Angles(math.rad(30), 0, math.rad(22))
	tw(Cap, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = flyTo })
	tw(glow, TweenInfo.new(0.25), { Brightness = 30 })
	sparkles:Emit(90)
	task.wait(0.95)

	-- крышка возвращается, яйцо собирается
	tw(Cap, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = capBase })
	tw(glow, TweenInfo.new(0.85), { Brightness = 3 })
	task.wait(0.9)

	animating = false
end

return PetEggVisual
