-- SIGMATIK | t.me/sigmatik323 | obfuscate-failed, raw copy
--!strict
-- Серверная логика системы петомцев: яйцо, инвентарь, экипировка
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local petsFolder = RS:WaitForChild("PetsFolder")
local remotes = RS:WaitForChild("PetRemotes")
local equipRemote = remotes:WaitForChild("EquipPet")
local hatchRemote = remotes:WaitForChild("HatchPet")

local activePets = Instance.new("Folder")
activePets.Name = "ActivePets"
activePets.Parent = workspace

local EGG_COOLDOWN = 6 -- секунд между открытиями яйца
local EQUIP_COOLDOWN = 0.4 -- защита от спама экипировкой
local hatchCooldowns: {[Player]: number} = {}
local lastEquip: {[Player]: number} = {}
local equipped: {[Player]: Model} = {}
local rarityWeights: {[string]: Color3} = {
	["Обычный"] = Color3.fromRGB(170, 170, 170),
	["Редкий"] = Color3.fromRGB(80, 150, 255),
	["Эпический"] = Color3.fromRGB(170, 80, 255),
	["Легендарный"] = Color3.fromRGB(255, 200, 60),
}

-- Взвешенный случайный выбор петомца по Chance
local function pickRandomPet(): (Model, string, Color3)
	local templates = petsFolder:GetChildren()
	local total = 0
	for _, tmpl in ipairs(templates) do
		total += tmpl:GetAttribute("Chance") or 0
	end
	local roll = math.random() * total
	local acc = 0
	for _, tmpl in ipairs(templates) do
		acc += tmpl:GetAttribute("Chance") or 0
		if roll <= acc then
			local rarity = tmpl:GetAttribute("Rarity") or "Обычный"
			return tmpl, rarity, rarityWeights[rarity] or Color3.new(1, 1, 1)
		end
	end
	local fallback = templates[1]
	return fallback, "Обычный", rarityWeights["Обычный"]
end

local function unequipPet(player: Player)
	local pet = equipped[player]
	if pet then
		equipped[player] = nil
		if pet then
			pet.Parent = nil
		end
	end
end

-- Вылупление петомца: визуально пет выходит из яйца и летит к игроку,
-- в инвентарь попадает после того, как долетел.
local function hatchPet(player: Player)
	local now = os.clock()
	if hatchCooldowns[player] and now < hatchCooldowns[player] then
		local remaining = math.ceil(hatchCooldowns[player] - now)
		hatchRemote:FireClient(player, "❌ Подожди " .. remaining .. " сек.", Color3.fromRGB(255, 100, 100))
		return
	end
	hatchCooldowns[player] = now + EGG_COOLDOWN

	local inventory = player:FindFirstChild("Pets")
	if not inventory then return end

	local template, rarity, rarityColor = pickRandomPet()
	if not template then return end

	local function award()
		if not inventory.Parent then return end
		local newPet = template:Clone()
		newPet:SetAttribute("OwnerId", player.UserId)
		newPet:SetAttribute("PetId", tostring(math.random(1, 10 ^ 9)) .. "-" .. tostring(os.clock() * 1000))
		newPet.Parent = inventory
		hatchRemote:FireClient(player, "🎉 Ты получил: " .. newPet.Name .. " (" .. rarity .. ")!", rarityColor)
	end

	local eggModel = workspace:FindFirstChild("PetEggModel")
	local visualModule = eggModel and eggModel:FindFirstChild("PetEggVisual")
	local visual = visualModule and require(visualModule)
	if visual then
		task.spawn(function()
			visual.hatch(template, player)
			award()
		end)
	else
		award()
	end
end

-- Экипировка/снятие петомца
local function onEquipPet(player: Player, petName: string)
	if typeof(petName) ~= "string" or #petName > 60 then return end
	local now = os.clock()
	if lastEquip[player] and now - lastEquip[player] < EQUIP_COOLDOWN then return end
	lastEquip[player] = now

	local inventory = player:FindFirstChild("Pets")
	if not inventory then return end

	local targetPet
	for _, pet in ipairs(inventory:GetChildren()) do
		if pet.Name == petName and pet:GetAttribute("OwnerId") == player.UserId then
			targetPet = pet
			break
		end
	end
	if not targetPet then return end

	local current = equipped[player]
	if current and current.Name == petName and current.Parent then
		unequipPet(player)
		equipRemote:FireClient(player, petName, false)
		return
	end

	unequipPet(player)

	local petModel = targetPet:Clone()
	petModel.Name = player.Name .. "_" .. petName
	petModel:SetAttribute("OwnerUserId", player.UserId)

	-- делаем части не-anchored и невидимой коллизии, физикой управляем сами
	for _, part in ipairs(petModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	petModel.Parent = activePets
	-- ставим пета сразу сбоку-спереди от игрока, чтобы он не прилетал из центра карты
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local right = Vector3.new(hrp.CFrame.RightVector.X, 0, hrp.CFrame.RightVector.Z)
		if right.Magnitude < 0.01 then
			right = Vector3.new(1, 0, 0)
		else
			right = right.Unit
		end
		petModel:PivotTo(CFrame.new(hrp.Position + right * 3 + Vector3.new(0, 2, 0)))
	end
	equipped[player] = petModel
	equipRemote:FireClient(player, petName, true)
end

-- Следование петомца за игроком: летит сбоку-спереди (не за спиной), смотрит вперёд
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, pet in pairs(equipped) do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp or not pet.Parent or not character or not character.Parent then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			unequipPet(player)
			continue
		end

		local base = hrp.CFrame
		local flatLook = Vector3.new(base.LookVector.X, 0, base.LookVector.Z)
		if flatLook.Magnitude < 0.01 then
			flatLook = Vector3.new(0, 0, -1)
		else
			flatLook = flatLook.Unit
		end
		local right = Vector3.new(base.RightVector.X, 0, base.RightVector.Z)
		if right.Magnitude < 0.01 then
			right = Vector3.new(1, 0, 0)
		else
			right = right.Unit
		end

		local bob = math.sin(now * 2.4) * 0.18
		local targetPos = hrp.Position + right * 3.1 + flatLook * 1.6 + Vector3.new(0, 2.1 + bob, 0)
		local targetCF = CFrame.lookAt(targetPos, targetPos + flatLook)

		local current = pet:GetPivot()
		if (targetPos - current.Position).Magnitude > 30 then
			pet:PivotTo(targetCF)
		else
			pet:PivotTo(current:Lerp(targetCF, 0.12))
		end
	end
end)

-- Игроки
local function onPlayerAdded(player: Player)
	local inventory = Instance.new("Folder")
	inventory.Name = "Pets"
	inventory.Parent = player

	-- каждому новичку даём стартового петомца
	task.wait(1)
	if player.Parent then
		local starter = petsFolder:FindFirstChild("Котик")
		if starter and inventory.Parent then
			local pet = starter:Clone()
			pet:SetAttribute("OwnerId", player.UserId)
			pet:SetAttribute("PetId", tostring(math.random(1, 10 ^ 9)))
			pet.Parent = inventory
		end
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	unequipPet(player)
	hatchCooldowns[player] = nil
	lastEquip[player] = nil
end)

-- Яйцо: ProximityPrompt (визуал вылупления вызывается внутри hatchPet)
local egg = workspace:FindFirstChild("PetEggModel")
if egg then
	local eggPart = egg:FindFirstChild("Egg")
	local prompt = eggPart and eggPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.ClickablePrompt = false
		prompt.Triggered:Connect(function(player)
			hatchPet(player)
		end)
	end
end

equipRemote.OnServerEvent:Connect(onEquipPet)
