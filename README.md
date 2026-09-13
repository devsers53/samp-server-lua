# samp-server-lua

![CI build](https://github.com/devsers53/samp-server-lua/actions/workflows/build.yml/badge.svg)

Плагин для SA-MP-сервера, который позволяет писать гейм-мод целиком на
**Lua 5.5** вместо Pawn: все колбэки сервера доходят до Lua, а SA-MP-нативы
вызываются из Lua через мост на плагин.

Протестировано SAMP:
| Версия | Статус |
|--------|--------|
| v0.3.7-R1 (Windows) | ❌ не тестировалось |
| v0.3.7-R2 (Windows) | ❌ не тестировалось |
| **v0.3.7-R3 (Windows)** | ✅ протестировано |
| v0.3.7-R4 (Windows) | ❌ не тестировалось |
| v0.3.7-R5 (Windows) | ❌ не тестировалось |

Плагин собран как **Windows .dll** (MSVC, x86).
Планируется под Linux собрать. 

## Как это работает

```text
samp-server.exe
      │
      │ колбэки (OnGameModeInit, OnPlayerCommandText, ...)
      ▼
lua_gm.amx  (прокси-геймод на Pawn, файл lua_gm.pwn)
      │             
      │ native Lua_Fire("OnPlayerCommandText", playerid, cmdtext)
      ▼
salua_lua.dll  (плагин, plugins/src/main.cpp, Lua 5.5 embedded)
      │
      │ глобальные функции Lua On*() в lua/main.lua
      ▼
  Lua-мод
      │
      │ samp.call("SendClientMessage", playerid, color, "текст")
      ▼
salua_lua.dll  → amx_FindPublic("API_SendClientMessage") → amx_Exec
      │
      ▼
lua_gm.amx  → натив SendClientMessage(...) (SA-MP API)
```

### Колбэки сервера → Lua
Прокси-геймод `lua_gm.pwn` дублирует все нужные public-функции
(`OnGameModeInit`, `OnPlayerConnect`, `OnPlayerCommandText`, ...) и каждая из них
вызывает натив плагина `Lua_Fire("Имя", args...)`. Плагин по сигнатуре из
`g_callbacks[]` вызывает одноимённую глобальную функцию Lua.

### SA-MP-нативы ← Lua
Из Lua нативы вызываются через таблицу `samp`:

- `samp.call("Имя", args...)` — вызывает SA-MP-натив. Плагин ищет в прокси public
  `API_<Имя>` (враппер на Pawn, вызывает нужный натив) и исполняет через
  `amx_Exec`. Опечатка/несоответствие аргументов → возвращает `nil`.
- `samp.callPublic("Имя")` — вызов произвольного public-паблика прокси (без аргументов).
- out-параметры (`Float:x, Float:y, Float:z` / `name[]` / `ip[]`):
  `samp.getPlayerPos(id)`, `samp.getPlayerName(id)`, `samp.getPlayerIp(id)`,
  `samp.getPlayerHealth(id)`, `samp.getPlayerArmour(id)` — реализованы через
  `amx_Allot` на стороне плагина.
- `samp.log("текст")` — вывод в лог сервера.
- `samp.plugin` — имя плагина.

Сигнатуры аргументов (`I`=int/bool, `S`=строка, `F`=float) задаются таблицами
`g_callbacks[]` и `g_apis[]` в `plugins/src/main.cpp`. Важно: параметры Pawn при
`amx_Exec` пушатся в обратном порядке (последний аргумент первым).

### Таймеры из Lua
Плагин экспортирует `ProcessTick` → вызывает Lua-функцию `OnServerTick()` на
каждый серверный тик. В `lua/main.lua` на ней построены `setInterval(ticks, fn)`
и `clearInterval(id)`.

## Структура репозитория

```text
plugins/
  src/main.cpp        — плагин (Lua-мост, нативы, диспетчеры, кодировки)
  src/lua/            — продакшен-исходники Lua 5.5.1 (lua.org)
  build.bat           — сборка DLL (MSVC x86, kомпилируется как C++)
  salua_lua.def       — имена экспортов без декорации MSVC
lua/main.lua          — пример Lua-гейм-мода
gamemodes/lua_gm.pwn  — прокси-геймод (колбэки → Lua_Fire, API_* врапперы)
gamemodes/lua_gm.amx  — предкомпилированный прокси (pawncc 3.2.3664)
pawno/include/lua_salua.inc — декларации нативов плагина
server.cfg            — пример конфигурации сервера
```

## Сборка плагина (Windows)

1. Установить Visual Studio (проверено VS 18 Community) с компонентом
   MSVC x86.
2. Из папки `plugins` запустить:
   ```bat
   build.bat
   ```
   Скрипт находит `vcvars32.bat`, компилирует `main.cpp` и `src\lua\*.c`
   как C++ (`/TP`, `/std:c++17`, `-DHAVE_STDINT_H` — в старом `amx.h`
   конфликт `uint32_t` со `stdint.h`), исключает `lua.c`/`luac.c` (дублируют
   `main`) и линкует `salua_lua.dll` по `salua_lua.def` (экспорты
   `Supports/Load/Unload/AmxLoad/AmxUnload/ProcessTick` без декорации).

SDK (`maddinat0r/samp-plugin-sdk`, нужен только для сборки) и продакшен-исходники
Lua 5.5.1 уже включены в репозиторий: `plugins/sdk/` и `plugins/src/lua/`.

Если меняли `gamemodes/lua_gm.pwn`, перекомпилировать прокси:
```bat
pawno\pawncc.exe -i pawno\include -o gamemodes\lua_gm.amx gamemodes\lua_gm.pwn
```

## Установка

1. Положить `salua_lua.dll` в `plugins\` сервера.
2. Скомпилированный `gamemodes\lua_gm.amx` — в `gamemodes\`.
3. `lua\main.lua` (и другие скрипты) — в `lua\`.
4. В `server.cfg`:
   ```
   plugins salua_lua
   gamemode0 lua_gm 1
   ```
   (этот билд сервера не автосканирует папку `plugins`).

## Тесты (SA-MP 0.3.7-R3, Windows)

- Плагин загружается сервером (`Loaded 1 plugins`), экспорты проверены
  (dumpbin): `Supports, Load, Unload, AmxLoad, AmxUnload, ProcessTick`.
- При старте грузится `lua/main.lua` и вызывается Lua-функция
  `OnGameModeInit` — в лог:
  ```
  [Lua] === main.lua: Lua gamemode loaded (Lua 5.5) ===
  [Lua] OnGameModeInit -> настройка мода
  [Lua] OnGameModeInit -> готово
  ```
- Кругосветка «Lua → samp.call → pawn (API_*) → SA-MP-натив» отработала в
  `OnGameModeInit` (SetWeather/SetWorldTime/AddPlayerClass) и в таймере-стрессе:
  `timer fired: samp.call('SendClientMessageToAll')` с интервалом ~2 с, сервер
  прожил 40 секунд, 22 срабатывания таймера, падений нет.
- Кодировка: строки Lua (UTF-8) конвертируются плагином в Windows-1251
  (кодировку сервера) — кириллица корректно отображается в `server_log.txt`
  и консоли.

Известные ограничения:
- SA-MP 0.3.7 требует `public main()` в геймоде — без него `Run time error 20`
  («Invalid index parameter»); в прокси `main()` добавлен.
- В `a_samp.inc` 0.3.7 у `AddPlayerClass` нет первого параметра classid (11
  аргументов) — это учтено в `g_apis` и `lua/main.lua`.

## Как расширить

1. Новый колбэк: добавить public в `lua_gm.pwn` (`Lua_Fire("OnX", ...)`) и
   строчку в `g_callbacks[]` в `main.cpp`, далее в Lua написать `function OnX(...)`.
2. Новый натив: добавить public-враппер `API_Имя(...)` в `lua_gm.pwn`, сигнатуру
   в `g_apis[]` — и он будет доступен через `samp.call("Имя", ...)`.

## Вклад в проект

Репозиторий открыт для всех:

- Если нашёл сбой, ошибку или краш сервера — заведи **Issue**: https://github.com/devsers53/samp-server-lua/issues
  (желательно с логом `server_log.txt` и версией SA-MP/плагина).
- Если чего-то не хватает (колбэк, натив, фича) — напиши **Issue** с пожеланием
  или PR: https://github.com/devsers53/samp-server-lua/pulls
- Любой может форкнуть репозиторий, внести правки и предложить **Pull Request** —
  их можно присылать по любому поводу: багфиксы, новые нативы/колбэки,
  улучшения документации, свои примеры Lua-модов.
