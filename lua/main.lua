--==============================================================
--  lua/main.lua — простой гейм-мод (логика полностью на Lua)
--  Прокси-геймод (gamemodes/lua_gm.amx) перегоняет callbacks
--  в функции On* ниже; SA-MP нативы зовутся через samp.call().
--==============================================================

samp.log("=== main.lua: Lua gamemode loaded (" .. _VERSION .. ") ===")

-- простая таблица таймеров на тиках сервера
local timers = {}

function setInterval(ms, fn)
    local id = #timers + 1
    timers[id] = { next = ms, step = ms, fn = fn }
    return id
end

function clearInterval(id)
    timers[id] = nil
end

--==============================================================
--  Колбэки сервера
--==============================================================

function OnServerTick()
    for _, t in pairs(timers) do
        t.next = t.next - 1
        if t.next <= 0 then
            t.next = t.step
            local ok, err = pcall(t.fn)
            if not ok then
                samp.log("timer error: " .. tostring(err))
            end
        end
    end
end

function OnGameModeInit()
    samp.log("OnGameModeInit -> настройка мода")

    samp.call("SetWorldTime", 12)
    samp.call("SetWeather", 10)

    -- классы для спавна (скин, x, y, z, угол, оружия...)
    local skins = { 287, 288, 49, 250, 217 }
    for _, s in ipairs(skins) do
        samp.call("AddPlayerClass", s, 1529.6, -1691.2, 6.2, 270.0,
            0, 0, 0, 0, 0, 0)
    end

    samp.log("OnGameModeInit -> готово")
end

function OnGameModeExit()
    samp.log("OnGameModeExit")
end

function OnPlayerConnect(playerid)
    local name = samp.getPlayerName(playerid) or "?"
    samp.call("SendClientMessageToAll", 0xFF8C00AA, name .. " подключился к серверу.")
    samp.call("GameTextForPlayer", playerid, "Welcome!", 4000, 4)
end

function OnPlayerDisconnect(playerid, reason)
    local name = samp.getPlayerName(playerid) or "?"
    samp.call("SendClientMessageToAll", 0x808080AA, name .. " покинул сервер.")
end

function OnPlayerSpawn(playerid)
    samp.call("SetPlayerPos", playerid, 1529.6, -1691.2, 6.2)
    samp.call("SetPlayerFacingAngle", playerid, 270.0)
    samp.call("SetPlayerHealth", playerid, 100.0)
    samp.call("SetPlayerArmour", playerid, 50.0)
    samp.call("SetPlayerInterior", playerid, 0)
    samp.call("SetPlayerSkin", playerid, 250)
    samp.call("GivePlayerWeapon", playerid, 24, 500)
    samp.call("GivePlayerWeapon", playerid, 25, 120)
    samp.call("SendClientMessage", playerid, 0x00FF00AA,
        "Добро пожаловать! /help - список команд.")
end

function OnPlayerDeath(playerid, killerid, reason)
    samp.call("SendDeathMessage", killerid, playerid, reason)
    samp.call("SendClientMessage", playerid, 0xFF0000AA,
        "Вы погибли. Ожидайте респавна...")
end

function OnPlayerText(playerid, text)
    -- пропускаем обычный чат (return 0)
    return 0
end

function OnPlayerCommandText(playerid, cmdtext)
    local args = {}
    for w in cmdtext:gmatch("%S+") do
        args[#args + 1] = w
    end
    if #args == 0 then
        return 0
    end
    local cmd = string.lower(string.sub(args[1], 2))

    if cmd == "help" then
        samp.call("SendClientMessage", playerid, 0xFFFF00AA,
            "Команды: /help | /skin <0-311> | /heal | /pos | /money | /name")
        return 1

    elseif cmd == "skin" and args[2] then
        local s = tonumber(args[2])
        if s and s >= 0 and s <= 311 then
            samp.call("SetPlayerSkin", playerid, s)
            samp.call("SendClientMessage", playerid, 0x00FF00AA, "Скин установлен: " .. s)
        else
            samp.call("SendClientMessage", playerid, 0xFF0000AA, "Ошибка: скин 0-311.")
        end
        return 1

    elseif cmd == "heal" then
        samp.call("SetPlayerHealth", playerid, 100.0)
        samp.call("SetPlayerArmour", playerid, 100.0)
        samp.call("SendClientMessage", playerid, 0x00FF00AA, "HP/броня восстановлены.")
        return 1

    elseif cmd == "pos" then
        local x, y, z = samp.getPlayerPos(playerid)
        samp.call("SendClientMessage", playerid, 0x00FFAAFF,
            string.format("Позиция: %.2f, %.2f, %.2f", x, y, z))
        return 1

    elseif cmd == "money" then
        local money = samp.call("GetPlayerMoney", playerid)
        samp.call("SendClientMessage", playerid, 0x00FF00AA,
            "Ваши деньги: $" .. tostring(money))
        return 1

    elseif cmd == "name" then
        samp.call("SendClientMessage", playerid, 0x00FF00AA,
            "Ваше имя: " .. (samp.getPlayerName(playerid) or "?"))
        return 1
    end

    return 0
end

-- пример таймера (вывод всем раз в N серверных тиков)
setInterval(3000, function()
    samp.log("timer fired: samp.call('SendClientMessageToAll')")
    samp.call("SendClientMessageToAll", 0x00BBFFAA, "[salua_lua] сервер жив!")
end)