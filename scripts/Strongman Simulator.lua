-- Strongman Simulator | СУПЕР-УНИВЕРСАЛ под любую игру
-- Идея: обфускация (Luraph/Moonsec) прячет КОД, а не ИНСТАНСЫ. Ищем по объектам + ловим живые args.
-- Работает везде: хэши, nil-родитель, Bindable, Unreliable, кнопки/промпты/тулзы.

pcall(function() if getgenv().URF2_Unload then getgenv().URF2_Unload() end end)
local genv = getgenv and getgenv() or _G
local SAVE = "URF2_Save.json"
local Players = cloneref and cloneref(game:GetService("Players")) or game:GetService("Players")
local Http = cloneref and cloneref(game:GetService("HttpService")) or game:GetService("HttpService")
local VU = game:GetService("VirtualUser")
local LP = Players.LocalPlayer
local function ok(f) local r,outp=pcall(f) return r and outp end

-- анти-афк
pcall(function()
	LP.Idled:Connect(function()
		pcall(function()
			VU:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
			task.wait(1)
			VU:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
		end)
	end)
end)

-- состояние между перезапусками
local S = {favs={}, lastArgs={}, calls={}, throttleMs=3, logN=0}
pcall(function()
	if isfile and isfile(SAVE) then
		local d = Http:JSONDecode(readfile(SAVE))
		for k,v in pairs(d) do S[k]=v end
	end
end)
local function save() pcall(function() if writefile then writefile(SAVE, Http:JSONEncode({favs=S.favs,lastArgs=S.lastArgs,calls=S.calls,throttleMs=S.throttleMs})) end end) end

-- ===== ЯДРО: поиск =====
local function isRemote(v)
	return v:IsA("RemoteEvent") or v:IsA("RemoteFunction")
		or v:IsA("UnreliableRemoteEvent") or v:IsA("BindableEvent") or v:IsA("BindableFunction")
end
local function FindAll(includeNil)
	local out, seen = {}, {}
	for _,v in ipairs(game:GetDescendants()) do
		if pcall(function() return isRemote(v) end) and isRemote(v) then table.insert(out,v) seen[v]=true end
	end
	if includeNil ~= false and typeof(getnilinstances)=="function" then
		pcall(function()
			for _,v in pairs(getnilinstances()) do
				if not seen[v] and pcall(function() return isRemote(v) end) and isRemote(v) then table.insert(out,v) end
			end
		end)
	end
	return out
end
local function FindRemote(name)
	for _,svc in ipairs({"ReplicatedStorage","ReplicatedFirst","Workspace","StarterPack","Lighting","SoundService"}) do
		local s = ok(function() return game:GetService(svc) end)
		if s then local r = ok(function() return s:FindFirstChild(name,true) end) if r and isRemote(r) then return r end end
	end
	for _,v in ipairs(game:GetDescendants()) do
		if v.Name==name and pcall(function() return isRemote(v) end) and isRemote(v) then return v end
	end
	if typeof(getnilinstances)=="function" then
		for _,v in pairs(getnilinstances()) do
			if v.Name==name and pcall(function() return isRemote(v) end) and isRemote(v) then return v end
		end
	end
	return nil
end
local function shortPath(r)
	local pcallPath = ok(function() return r:GetFullName() end)
	if pcallPath then
		p = pcallPath
		p = p:gsub("^game%.",""):gsub("^Players%.[^%.]+%.","@P.")
		if #p>52 then p = "…"..p:sub(-51) end
		return p
	end
	return r.Name
end

-- ===== троттлинг ≤400/сек =====
local lastFire, win貼N, winT = 0, 0, os.clock()
local winN = 0
local function throttle()
	local gap = (S.throttleMs or 3)/1000
	local n = os.clock() local d = n-lastFire
	if d < gap then task.wait(gap-d) end
	local now = os.clock()
	if now-winT >= 1 then winT=now winN=0 end
	if winN >= 400 then task.wait(1-(now-winT)+0.01) winT=os.clock() winN=0 end
	lastFire=os.clock() winN=winN+1
end

-- ===== вызов по ссылке =====
local function parseArgsStr(s, fallback)
	if (s==nil or s=="") and fallback then return fallback end
	if s==nil or s=="" then return {} end
	s = s:gsub("^%s*%{%s*",""):gsub("%s*%}%s*$","")
	local env = {math=math,string=string,table=table,Vector3=Vector3,CFrame=CFrame,Color3=Color3,UDim=UDim,UDim2=UDim2,Vector2=Vector2,game=game,workspace=workspace,LocalPlayer=LP}
	local f,err = loadstring("return {"..s.."}")
	if not f then return nil,"арги: "..tostring(err):sub(1,120) end
	if setfenv then pcall(setfenv,f,env) end
	local okl,res = pcall(f)
	if not okl then return nil,"арги pcall" end
	return res
end
local function fireObj(r, argList)
	throttle()
	if r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent") then
		r:FireServer(table.unpack(argList)) return true,"FireServer → "..r.Name
	elseif r:IsA("RemoteFunction") then
		local res={r:InvokeServer(table.unpack(argList))}
		local js = ok(function() return Http:JSONEncode(res) end) or tostring(res[1])
		return true,"ответ: "..tostring(js):sub(1,200)
	elseif r:IsA("BindableEvent") then r:Fire(table.unpack(argList)) return true,"Bindable Fire"
	elseif r:IsA("BindableFunction") then local res={r:Invoke(table.unpack(argList))} return true,"Bindable ответ: "..tostring(res[1]):sub(1,200) end
	return false,"неизвестный класс"
end
local function FireByName(name, argList)
	local r = FindRemote(name)
	if not r then return false,"не найден: "..tostring(name) end
	return fireObj(r, argList)
end

-- ===== GUI =====
local parentGui = (gethui and ok(function() return gethui() end)) or (get_hidden_gui and ok(get_hidden_gui)) or LP:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui") gui.Name="URF2" gui.ResetOnSpawn=false gui.IgnoreGuiInset=true
pcall(function() gui.Parent = parentGui end)
local main = Instance.new("Frame",gui)
main.Size=UDim2.new(0,660,0,470) main.Position=UDim2.new(0,12,0,60)
main.BackgroundColor3=Color3.fromRGB(16,16,18) main.Active=true main.Draggable=true
Instance.new("UICorner",main).CornerRadius=UDim.new(0,10)
local st=Instance.new("UIStroke",main) st.Color=Color3.fromRGB(60,60,70) st.Thickness=1
pcall(function()
	if S.wpos and S.wpos[1] then main.Position=UDim2.new(0,S.wpos[1],0,S.wpos[2]) end
end)

local top = Instance.new("Frame",main) top.Size=UDim2.new(1,0,0,34) top.BackgroundColor3=Color3.fromRGB(24,24,28)
Instance.new("UICorner",top).CornerRadius=UDim.new(0,10)
local title = Instance.new("TextLabel",top) title.BackgroundTransparency=1
title.Size=UDim2.new(1,-110,1,0) title.Position=UDim2.new(0,12,0,0)
title.TextXAlignment=Enum.TextXAlignment.Left title.TextColor3=Color3.fromRGB(255,255,255) title.TextSize=14
title.Text="УНИВЕРСАЛ • ремоуты • любая игра"
local function topBtn(t,x,cb)
	local b=Instance.new("TextButton",top) b.Text=t b.Size=UDim2.new(0,44,0,24) b.Position=UDim2.new(1,x,0,5)
	b.BackgroundColor3=Color3.fromRGB(45,45,55) b.TextColor3=Color3.new(1,1,1) b.TextSize=14
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
	b.MouseButton1Click:Connect(cb) return b
end
local miniBtn
miniBtn=topBtn("—",-100,function() body.Visible=not body.Visible status.Text=body.Visible and "развёрнут" or "свёрнут • тащи за шапку" end)
topBtn("X",-50,function() if genv.URF2_Unload then genv.URF2_Unload() end end)

local tabs = Instance.new("Frame",main) tabs.Size=UDim2.new(1,0,0,32) tabs.Position=UDim2.new(0,0,0,36) tabs.BackgroundTransparency=1
local body = Instance.new("Frame",main) body.Size=UDim2.new(1,0,1,-102) body.Position=UDim2.new(0,0,0,70) body.BackgroundTransparency=1
local status = Instance.new("TextLabel",main) status.BackgroundTransparency=1
status.Size=UDim2.new(1,-12,0,28) status.Position=UDim2.new(0,12,1,-30)
status.TextXAlignment=Enum.TextXAlignment.Left status.TextColor3=Color3.fromRGB(0,255,150) status.TextSize=12 status.Text="готов"
local function say(t, bad) status.Text=t status.TextColor3=bad and Color3.fromRGB(255,120,120) or Color3.fromRGB(0,255,150) end

local pages, tabBtns, curTab = {}, {}, "scan"
local tabNames = {{"scan","СКАНЕР"},{"log","ЛОГ"},{"fire","ВЫЗОВ"},{"fuzz","ФАЗЗ"},{"map","КАРТА"}}
for i,tn in ipairs(tabNames) do
	local b=Instance.new("TextButton",tabs) b.Text=tn[2]
	b.Size=UDim2.new(0,100,0,26) b.Position=UDim2.new(0,8+(i-1)*106,0,3)
	b.BackgroundColor3=Color3.fromRGB(40,40,50) b.TextColor3=Color3.new(1,1,1) b.TextSize=12
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
	local pg=Instance.new("Frame",body) pg.Size=UDim2.new(1,0,1,0) pg.BackgroundTransparency=1 pg.Visible=(i==1)
	pages[tn[1]]=pg tabBtns[tn[1]]=b
	b.MouseButton1Click:Connect(function()
		curTab=tn[1]
		for k,p in pairs(pages) do p.Visible=(k==curTab) end
		for k,bb in pairs(tabBtns) do bb.BackgroundColor3=(k==curTab) and Color3.fromRGB(0,130,80) or Color3.fromRGB(40,40,50) end
	end)
end
tabBtns["scan"].BackgroundColor3=Color3.fromRGB(0,130,80)

local function darkBox(p,ph,y,h,multi)
	local t=Instance.new("TextBox",p) t.PlaceholderText=ph t.Text=""
	t.Position=UDim2.new(0,8,0,y) t.Size=UDim2.new(1,-16,0,h)
	t.BackgroundColor3=Color3.fromRGB(30,30,36) t.TextColor3=Color3.new(1,1,1)
	t.TextSize=12 t.ClearTextOnFocus=false t.MultiLine=(multi==true) t.TextXAlignment=Enum.TextXAlignment.Left
	if multi then t.TextYAlignment=Enum.TextYAlignment.Top end
	Instance.new("UICorner",t).CornerRadius=UDim.new(0,6) return t
end
local function btn(p,t,x,y,w,h,cb,col)
	local b=Instance.new("TextButton",p) b.Text=t b.Position=UDim2.new(0,x,0,y) b.Size=UDim2.new(0,w,0,h)
	b.BackgroundColor3=col or Color3.fromRGB(45,45,55) b.TextColor3=Color3.new(1,1,1) b.TextSize=12
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
	b.MouseButton1Click:Connect(function() pcall(cb) end) return b
end
local function scroll(p,y,h)
	local s=Instance.new("ScrollingFrame",p) s.Position=UDim2.new(0,8,0,y) s.Size=UDim2.new(1,-16,0,h)
	s.BackgroundColor3=Color3.fromRGB(12,12,14) s.CanvasSize=UDim2.new(0,0,0,0)
	s.AutomaticCanvasSize=Enum.AutomaticSize.Y s.ScrollBarThickness=5
	Instance.new("UICorner",s).CornerRadius=UDim.new(0,6)
	local l=Instance.new("UIListLayout",s) l.Padding=UDim.new(0,3) l.SortOrder=Enum.SortOrder.LayoutOrder
	return s
end

-- ДАННЫЕ
local all, filtered, selected, lastCall, incLog = {}, {}, nil, {}, {}
local filterClass, onlyFired, onlyFav, includeNil = "all", false, false, true

-- СКАНЕР
local pgS = pages["scan"]
local searchB = darkBox(pgS,"поиск: кусок хэша / имя / путь (пусто = все)",0,26,false)
local cntL = Instance.new("TextLabel",pgS) cntL.BackgroundTransparency=1
cntL.Position=UDim2.new(0,8,0,30) cntL.Size=UDim2.new(1,-16,0,18)
cntL.TextXAlignment=Enum.TextXAlignment.Left cntL.TextColor3=Color3.fromRGB(160,160,170) cntL.TextSize=12 cntL.Text="…"
local listS = scroll(pgS,50,270)
btn(pgS,"SCAN",8,324,70,26,function() doScan() end,Color3.fromRGB(0,130,80))
btn(pgS,"DEEP",82,324,70,26,function() doDeep() end)
btn(pgS,"Все",156,324,52,26,function() filterClass="all" doFilter() end)
btn(pgS,"Evt",212,324,44,26,function() filterClass="event" doFilter() end)
btn(pgS,"Func",260,324,52,26,function() filterClass="func" doFilter() end)
btn(pgS,"Bind",316,324,52,26,function() filterClass="bind" doFilter() end)
btn(pgS,"Unrel",372,324,52,26,function() filterClass="unrel" doFilter() end)
btn(pgS,"★",428,324,36,26,function() onlyFav=not onlyFav doFilter() say(onlyFav and "только ★" or "все") end)
btn(pgS,"Fired",468,324,56,26,function() onlyFired=not onlyFired doFilter() end)
btn(pgS,"nil",528,324,44,26,function() includeNil=not includeNil doScan() end)
btn(pgS,"COPY",576,324,60,26,function()
	if selected and setclipboard then
		local r=FindRemote(selected)
		local code = r and ('local r = '..shortPath(r)..'\n-- имя: '..r.Name..' ['..r.ClassName..']') or selected
		setclipboard(code) say("путь скопирован") else say("выбери ремоут",true) end
end)

function doScan()
	all = FindAll(includeNil)
	table.sort(all,function(a,b) return a.Name<b.Name end)
	hookIncoming()
	doFilter()
	say("найдено: "..#all.." • выбери строку → иди во ВЫЗОВ")
end
function doFilter()
	filtered={}
	local q = searchB.Text:lower()
	for _,r in ipairs(all) do
		local cn=r.ClassName
		if filterClass=="event" and cn~="RemoteEvent" then continue end
		if filterClass=="func" and cn~="RemoteFunction" then continue end
		if filterClass=="bind" and not cn:find("Bindable") then continue end
		if filterClass=="unrel" and cn~="UnreliableRemoteEvent" then continue end
		if onlyFav and not S.favs[r.Name] then continue end
		if onlyFired and not (S.calls[r.Name] or lastCall[r.Name]) then continue end
		if q~="" and not (r.Name:lower():find(q,1,true) or cn:lower():find(q,1,true)) then
			local sp = ok(function() return r:GetFullName():lower() end)
			if not sp or not sp:find(q,1,true) then continue end
		end
		table.insert(filtered,r)
	end
	for _,c in ipairs(listS:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
	for i,r in ipairs(filtered) do
		local calls = S.calls[r.Name] or 0
		local hint = lastCall[r.Name] and (" • "..lastCall[r.Name]) or (S.lastArgs[r.Name] and (" • "..tostring(S.lastArgs[r.Name]):sub(1,50)) or "")
		local fav = S.favs[r.Name] and "★ " or "☆ "
		local b=Instance.new("TextButton",listS)
		b.Size=UDim2.new(1,-6,0,24) b.LayoutOrder=i
		b.BackgroundColor3=(selected==r.Name) and Color3.fromRGB(0,120,80) or Color3.fromRGB(34,34,40)
		b.TextColor3=Color3.new(1,1,1) b.TextSize=12 b.TextXAlignment=Enum.TextXAlignment.Left b.TextTruncate=Enum.TextTruncate.AtEnd
		b.Text=" "..fav.."["..r.ClassName:sub(1,4).."] "..r.Name..(calls>0 and (" ×"..calls) or "")..hint
		Instance.new("UICorner",b).CornerRadius=UDim.new(0,4)
		b.MouseButton1Click:Connect(function()
			selected=r.Name
			selL.Text="выбран: "..r.Name.." ["..r.ClassName.."]\n"..shortPath(r)
			addLog("выбран "..r.Name)
			doFilter()
		end)
		b.MouseButton2Click and b.MouseButton2Click:Connect(function() end)
	end
	cntL.Text="всего "..#all.." • показано "..#filtered.." • ★ "..tostring((function() local n=0 for _ in pairs(S.favs) do n=n+1 end return n end)())
end
searchB:GetPropertyChangedSignal("Text"):Connect(function() pcall(doFilter) end)

-- ЛОГ
local pgL = pages["log"]
local listLog = scroll(pgL,0,318)
btn(pgL,"CLEAR",8,322,70,26,function() for _,c in ipairs(listLog:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end S.logN=0 end)
btn(pgL,"COPY LOG",82,322,90,26,function()
	if setclipboard then local t={} for _,c in ipairs(listLog:GetChildren()) do if c:IsA("TextLabel") then table.insert(t,c.Text) end end setclipboard(table.concat(t,"\n"):sub(1,8000)) say("лог скопирован") end
end)
local autoScroll = true
btn(pgL,"AUTO",176,322,60,26,function() autoScroll=not autoScroll say("автоскролл: "..(autoScroll and "вкл" or "выкл")) end)
function addLog(t)
	S.logN=S.logN+1
	local l=Instance.new("TextLabel",listLog) l.BackgroundTransparency=1
	l.Size=UDim2.new(1,-6,0,16) l.LayoutOrder=S.logN
	l.TextXAlignment=Enum.TextXAlignment.Left l.TextColor3=Color3.fromRGB(200,200,210) l.TextSize=11
	l.TextTruncate=Enum.TextTruncate.AtEnd l.Text=os.date("%H:%M:%S").." "..tostring(t):sub(1,160)
	if #listLog:GetChildren()>300 then local f=listLog:FindFirstChildOfClass("TextLabel") if f then f:Destroy() end end
	if autoScroll then pcall(function() listLog.CanvasPosition=Vector2.new(0,1e6) end) end
end

-- ВЫЗОВ
local pgF = pages["fire"]
local selL = Instance.new("TextLabel",pgF) selL.BackgroundTransparency=1
selL.Position=UDim2.new(0,8,0,0) selL.Size=UDim2.new(1,-16,0,40)
selL.TextXAlignment=Enum.TextXAlignment.Left selL.TextYAlignment=Enum.TextYAlignment.Top
selL.TextColor3=Color3.fromRGB(255,220,120) selL.TextSize=12 selL.TextWrapped=true selL.Text="ничего не выбрано — иди в СКАНЕР"
local argsB = darkBox(pgF,'арги Lua без {}:  "SeasonPass"  |  1, "x"  |  пусто = повтор',44,60,true)
argsB.TextYAlignment=Enum.TextYAlignment.Top
btn(pgF,'{}',8,108,44,24,function() argsB.Text="" end)
btn(pgF,'1',56,108,36,24,function() argsB.Text="1" end)
btn(pgF,'999M',96,108,60,24,function() argsB.Text="999999999" end)
btn(pgF,'-1',160,108,40,24,function() argsB.Text="-1" end)
btn(pgF,'huge',204,108,56,24,function() argsB.Text="math.huge" end)
btn(pgF,'LP',264,108,44,24,function() argsB.Text="game.Players.LocalPlayer" end)
btn(pgF,'true,"t"',312,108,70,24,function() argsB.Text='true, "test"' end)
btn(pgF,'★',386,108,36,24,function()
	if selected then if S.favs[selected] then S.favs[selected]=nil else S.favs[selected]=true end save() doFilter() say("★ "+0==0 and "обновлено" or "") say("★ обновлено") end
end)
btn(pgF,"FIRE ×1",8,136,120,30,function()
	if not selected then say("выбери ремоут в СКАНЕРЕ",true) return end
	local a,err=parseArgsStr(argsB.Text, lastCall[selected.."_raw"] and nil or (selected and nil))
	if a==nil then say(err,true) return end
	if argsB.Text=="" and lastCall[selected.."_raw"] then a=lastCall[selected.."_raw"] end
	local okm,msg=FireByName(selected,a)
	addLog((okm and "OUT " or "ERR ")..selected.." → "..tostring(msg):sub(1,120))
	say((okm and "OK " or "ERR ")..tostring(msg):sub(1,110), not okm)
end,Color3.fromRGB(0,130,80))
btn(pgF,"RACE ×10",132,136,120,30,function()
	if not selected then say("выбери ремоут",true) return end
	local a=parseArgsStr(argsB.Text,lastCall[selected.."_raw"]) or {}
	if argsB.Text=="" and lastCall[selected.."_raw"] then a=lastCall[selected.."_raw"] end
	for i=1,10 do task.spawn(function() pcall(FireByName,selected,a) end) end
	addLog("RACE ×10 "..selected) say("race ×10 улетел (троттлинг держит ≤400/с)")
end)
btn(pgF,"REPLAY",256,136,100,30,function()
	if not selected then say("выбери ремоут",true) return end
	local a=lastCall[selected.."_raw"]
	if not a then say("нет перехваченных args — нажми что-то в игре",true) return end
	local okm,msg=FireByName(selected,a)
	addLog("REPLAY "..selected.." → "..tostring(msg):sub(1,100)) say("replay: "..tostring(msg):sub(1,100), not okm)
end)
btn(pgF,"КОД",360,136,80,30,function()
	if not selected then return end
	local r=FindRemote(selected)
	local snippet='local r\nfor _,v in ipairs(game:GetDescendants()) do if v.Name=="'..selected..'" and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then r=v break end end\n'
		..'local a = {'..argsB.Text..'}\nif r then r:'..((r and r:IsA("RemoteFunction")) and "InvokeServer" or "FireServer")..'(table.unpack(a)) end'
	if setclipboard then setclipboard(snippet) say("код вызова скопирован") end
end)
local respL = Instance.new("TextLabel",pgF) respL.BackgroundTransparency=1
respL.Position=UDim2.new(0,8,0,170) respL.Size=UDim2.new(1,-16,0,180)
respL.TextXAlignment=Enum.TextXAlignment.Left respL.TextYAlignment=Enum.TextYAlignment.Top
respL.TextColor3=Color3.fromRGB(170,170,180) respL.TextSize=12 respL.TextWrapped=true
respL.Text="Подсказка:\n• хэш-имя не мешает: жмём по ССЫЛКЕ на объект.\n• пустые арги + REPLAY = точный повтор живого вызова.\n• RACE ×10 = проверка на дабл-трату (дюп).\n• троттлинг ≤400/сек включён всегда."

-- ФАЗЗ
local pgZ = pages["fuzz"]
local fuzzL = Instance.new("TextLabel",pgZ) fuzzL.BackgroundTransparency=1
fuzzL.Position=UDim2.new(0,8,0,0) fuzzL.Size=UDim2.new(1,-16,0,36)
fuzzL.TextXAlignment=Enum.TextXAlignment.Left fuzzL.TextColor3=Color3.fromRGB(255,200,120) fuzzL.TextSize=12
fuzzL.TextWrapped=true fuzzL.Text="Матрица вокруг живого вызова: берёт перехваченные args и мутирует."
local fzN = darkBox(pgZ,"сколько строк (4..24, по умолч. 12)",40,26,false) fzN.Text="12"
local fzRes = scroll(pgZ,70,220)
btn(pgZ,"MATRIX",8,294,120,28,function()
	if not selected then say("выбери ремоут",true) return end
	local base = lastCall[selected.."_raw"]
	if not base then say("нет живого вызова — сначала нажми в игре / REPLAY нечем",true) return end
	local n = math.clamp(tonumber(fzN.Text) or 12, 4, 24)
	local rows = {}
	local function clone(t) local n2={} for i,v in ipairs(t) do n2[i]=v end return n2 end
	table.insert(rows,{"exact",clone(base)})
	for i,v in ipairs(base) do
		if type(v)=="number" then
			table.insert(rows,{"arg"..i.." 0", (function() local c=clone(base) c[i]=0 return c end)()})
			table.insert(rows,{"arg"..i.." -1", (function() local c=clone(base) c[i]=-1 return c end)()})
			table.insert(rows,{"arg"..i.." 999M", (function() local c=clone(base) c[i]=999999999 return c end)()})
			table.insert(rows,{"arg"..i.." huge", (function() local c=clone(base) c[i]=math.huge return c end)()})
			table.insert(rows,{"arg"..i.." +1", (function() local c=clone(base) c[i]=v+1 return c end)()})
		elseif type(v)=="string" then
			table.insert(rows,{"arg"..i.." пусто", (function() local c=clone(base) c[i]="" return c end)()})
			table.insert(rows,{"arg"..i.." 0-строка", (function() local c=clone(base) c[i]="0" return c end)()})
			table.insert(rows,{"arg"..i.." длинная", (function() local c=clone(base) c[i]=string.rep("A",300) return c end)()})
		elseif typeof(v)=="Instance" and v:IsA("Player") then
			table.insert(rows,{"arg"..i.." →я", (function() local c=clone(base) c[i]=LP return c end)()})
		end
		if #rows>=n then break end
	end
	table.insert(rows,{"nil-вместо-1", (function() local c=clone(base) if #c>0 then c[1]=nil end return c end)()})
	for _,c in ipairs(fzRes:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
	task.spawn(function()
		for i=1,math.min(n,#rows) do
			local nm,payload=rows[i][1],rows[i][2]
			local okm,msg=pcall(FireByName,selected,payload)
			local l=Instance.new("TextLabel",fzRes) l.BackgroundTransparency=1
			l.Size=UDim2.new(1,-6,0,16) l.TextXAlignment=Enum.TextXAlignment.Left l.TextSize=11
			l.TextColor3=Color3.fromRGB(200,200,210) l.Text=i..". "..nm.." → "..tostring(msg):sub(1,100)
			addLog("FUZZ "..selected.." ["..nm.."]")
			task.wait(0.35)
		end
		say("матрица готова: смотри дельту (деньги/инвентарь) после каждой строки")
	end)
end,Color3.fromRGB(140,80,0))

-- КАРТА: кнопки/промпты/тулзы → ремоут
local pgM = pages["map"]
local mapList = scroll(pgM,0,280)
btn(pgM,"КНОПКИ",8,286,90,28,function()
	for _,c in ipairs(mapList:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
	local n=0
	pcall(function()
		for _,b in ipairs(game:GetDescendants()) do
			if b:IsA("TextButton") or b:IsA("ImageButton") then
				local cons = ok(function() return getconnections(b.MouseButton1Click) end) or ok(function() return getconnections(b.Activated) end) or {}
				if cons and #cons>0 then
					for _,cn in ipairs(cons) do
						local src = ok(function() return debug.info(cn.Function,"s") end) or "?"
						local l=Instance.new("TextLabel",mapList) l.BackgroundTransparency=1
						l.Size=UDim2.new(1,-6,0,16) l.TextXAlignment=Enum.TextXAlignment.Left l.TextSize=11
						l.TextColor3=Color3.fromRGB(200,200,210) l.Text=(b:GetFullName():sub(-70)).." → "..tostring(src):sub(-60)
						n=n+1 if n>80 then break end
					end
				end
				if n>80 then break end
			end
		end
	end)
	say("кнопок с хендлерами: "..n.." • жми кнопку в игре — живой вызов упадёт в ЛОГ")
end)
btn(pgM,"ПРОМТЫ",102,286,90,28,function()
	local n=0 for _,v in ipairs(game:GetDescendants()) do if v:IsA("ProximityPrompt") then n=n+1 end end
	say("промптов: "..n.." • встань к промпту и зажми E — вызов поймается в ЛОГ")
end)
btn(pgM,"ТУЛЗЫ",196,286,90,28,function()
	local t={} pcall(function() for _,v in ipairs(LP.Backpack:GetChildren()) do if v:IsA("Tool") then table.insert(t,v.Name) end end end)
	say("тулзы рюкзака: "..table.concat(t,", "):sub(1,100))
end)
btn(pgM,"DEEP-GC",290,286,90,28,function() doDeep() end)

function doDeep()
	addLog("deep: ищу строки-heш.. в getgc (до 500)")
	local found={}
	pcall(function()
		local gc = getgc(true)
		for i=1,math.min(#gc,5000) do
			local v=gc[i]
			if type(v)=="function" then
				local cs = ok(function() return getconstants(v) end)
				if cs then for _,c in pairs(cs) do
					if type(c)=="string" and #c==32 and c:match("^[0-9a-f]+$") then found[c]=true end
				end end
			end
			if i%1000==0 then task.wait() end
		end
	end)
	local n=0 for k in pairs(found) do n=n+1 end
	say("deep: хэшей в константах: "..n.." • они же имена ремоутов выше") addLog("deep хэшей: "..n)
end

-- ===== живой перехват исходящих + входящих =====
local hooked, incCons = false, {}
local function fmtArgs(a)
	local t={} for i,v in ipairs(a) do
		local s = typeof(v)=="Instance" and ("<"..v.Name..">") or tostring(v)
		t[i]=s:sub(1,60)
	end
	return table.concat(t,", ")
end
pcall(function()
	if hookmetamethod and getnamecallmethod then
		local old
		old = hookmetamethod(game,"__namecall",function(self,...)
			local m = getnamecallmethod()
			local a = {...}
			if typeof(self)=="Instance" and pcall(function() return isRemote(self) end) and isRemote(self) then
				if m=="FireServer" or m=="InvokeServer" or m=="Fire" or m=="Invoke" then
					S.calls[self.Name]=(S.calls[self.Name] or 0)+1
					lastCall[self.Name]=fmtArgs(a) lastCall[self.Name.."_raw"]=a
					S.lastArgs[self.Name]=fmtArgs(a)
					addLog("OUT "..m.." "..self.Name.." ("..fmtArgs(a):sub(1,90)..")")
					if selected==self.Name then pcall(doFilter) end
				end
			end
			return old(self,...)
		end)
		genv.URF2_OldNamecall = old
		hooked=true
	end
end)
function hookIncoming()
	pcall(function()
		if #incCons>0 then return end
		local n=0
		for _,r in ipairs(all) do
			if n>300 then break end
			if r:IsA("RemoteEvent") then
				local c = ok(function() return r.OnClientEvent:Connect(function(...) addLog("IN ← "..r.Name.." ("..fmtArgs({...}):sub(1,90)..")") end) end)
				if c then table.insert(incCons,c) n=n+1 end
			end
		end
	end)
end

genv.URF2_Unload = function()
	pcall(function()
		if genv.URF2_OldNamecall then pcall(hookmetamethod,game,"__namecall",genv.URF2_OldNamecall) end
		for _,c in ipairs(incCons) do pcall(function() c:Disconnect() end) end
		S.wpos={main.Position.X.Offset,main.Position.Y.Offset} save()
		gui:Destroy()
	end)
	genv.URF2_Unload=nil genv.URF2_OldNamecall=nil
end

doScan()
addLog("старт • всего "..#all.." • хук исходящих: "..(hooked and "да" or "нет"))
say("готово: "..#all.." ремоутов • фильтр + ВЫЗОВ + ФАЗЗ + КАРТА")
