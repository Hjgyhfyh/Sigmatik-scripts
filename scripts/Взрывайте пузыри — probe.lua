-- SIGMATIK | t.me/sigmatik323 | obfuscate-failed, raw copy
﻿local lp = game:GetService("Players").LocalPlayer
local paths = {
    "D:/Нужное/Скрипты роблокс/Делаем скрипты тут/Скрипты/Взрывайте пузыри.lua",
    "D:\\Нужное\\Скрипты роблокс\\Делаем скрипты тут\\Скрипты\\Взрывайте пузыри.lua",
    "D:/Нужное/Скрипты роблокс/Делаем скрипты тут/Скрипты/Взрывайте пузыри — probe.lua",
}
local out = {}
for i, p in ipairs(paths) do
    local ok, res = pcall(readfile, p)
    out[i] = {path = p, ok = ok, type = typeof(res), len = (ok and type(res) == "string") and #res or -1}
end
local ok2, res2 = pcall(readfile, paths[1])
if ok2 and type(res2) == "string" then
    local b = {}
    for i = 1, math.min(6, #res2) do b[i] = string.byte(res2, i) end
    out.firstBytes = b
    local compiles, err = pcall(loadstring, res2)
    out.compiles = compiles
    out.compileErr = (not compiles) and tostring(err) or nil
end
return out