//==============================================================
//  salua_lua — SA-MP 0.3.7 plugin: полная эмуляция сценария на Lua
//
//  Архитектура:
//    * lua_gm.amx (прокси-геймод) перегоняет callbacks сервера
//      в натив Lua_Fire(...) -> Lua-функции On*;
//    * из Lua нативы вызываются через samp.call("SendClientMessage", ...),
//      плагин ищет public API_<имя> в прокси и исполняет amx_Exec;
//    * out-парам геттеры (GetPlayerPos/Name/Ip/Health/Armour)
//      реализованы через Amx_Allot + чтение буферов.
//==============================================================
#include <windows.h>
#include <stdio.h>
#include <string>
#include <vector>
#include <string.h>

#include "plugincommon.h"
#include "amx/amx.h"
#include "lua/lua.h"
#include "lua/lualib.h"
#include "lua/lauxlib.h"

extern void *pAMXFunctions;

typedef void (*logprintf_t)(const char *fmt, ...);
static logprintf_t logprintf = NULL;

// Конвертация UTF-8 (строки Lua) -> ANSI/з-кодировка сервера (на RU-системах Windows-1251),
// чтобы кириллица корректно отображалась в консоли и server_log.txt.
static std::string utf8_to_ansi(const char *utf8)
{
	if (!utf8)
		return std::string();
	if (!*utf8)
		return std::string();

	int wlen = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
	if (wlen <= 0)
		return std::string(utf8);

	std::vector<wchar_t> wbuf(wlen);
	MultiByteToWideChar(CP_UTF8, 0, utf8, -1, &wbuf[0], wlen);

	int alen = WideCharToMultiByte(CP_ACP, 0, &wbuf[0], -1, NULL, 0, NULL, NULL);
	if (alen <= 0)
		return std::string(utf8);

	std::string out(alen - 1, '\0');
	WideCharToMultiByte(CP_ACP, 0, &wbuf[0], -1, &out[0], alen, NULL, NULL);
	return out;
}

// Вывод строки в лог сервера с конвертацией в кодировку сервера.
static void lua_log(const std::string &text)
{
	if (!logprintf)
		return;
	std::string ansi = utf8_to_ansi(text.c_str());
	logprintf("[Lua] %s", ansi.c_str());
}

static lua_State *g_L = NULL;
static AMX *g_amx = NULL;
static bool g_autorun_done = false;

//==============================================================
//  Описатели сигнатур
//  I - int/bool, S - строка (const []), F - float
//==============================================================
struct Sig { const char *name; const char *sig; };

static const Sig g_callbacks[] = {
	{ "OnGameModeInit",          "" },
	{ "OnGameModeExit",          "" },
	{ "OnRconCommand",           "S" },
	{ "OnRconLoginAttempt",      "SS" },
	{ "OnPlayerConnect",         "I" },
	{ "OnPlayerDisconnect",      "II" },
	{ "OnPlayerRequestClass",    "II" },
	{ "OnPlayerRequestSpawn",    "I" },
	{ "OnPlayerSpawn",           "I" },
	{ "OnPlayerDeath",           "III" },
	{ "OnPlayerText",            "IS" },
	{ "OnPlayerCommandText",     "IS" },
	{ "OnPlayerUpdate",          "I" },
	{ "OnPlayerStateChange",     "III" },
	{ "OnPlayerEnterVehicle",    "III" },
	{ "OnPlayerExitVehicle",     "II" },
	{ "OnPlayerEnterCheckpoint", "I" },
	{ "OnPlayerLeaveCheckpoint", "I" },
	{ "OnPlayerEnterRaceCheckpoint", "I" },
	{ "OnPlayerLeaveRaceCheckpoint", "I" },
	{ "OnPlayerPickUpPickup",    "II" },
	{ "OnPlayerSelectedMenuRow", "II" },
	{ "OnPlayerExitedMenu",      "I" },
	{ "OnPlayerStreamIn",        "II" },
	{ "OnPlayerStreamOut",       "II" },
	{ "OnPlayerKeyStateChange",  "III" },
	{ "OnPlayerTakeDamage",      "IIFII" },
	{ "OnPlayerGiveDamage",      "IIFII" },
	{ "OnPlayerWeaponShot",      "IIIIFFF" },
	{ "OnPlayerClickMap",        "IFFF" },
	{ "OnPlayerClickPlayer",     "III" },
	{ "OnVehicleSpawn",          "I" },
	{ "OnVehicleDeath",          "II" },
	{ NULL, NULL }
};

static const Sig g_apis[] = {
	{ "SendClientMessage",       "IIS" },
	{ "SendClientMessageToAll",  "IS" },
	{ "SendPlayerMessageToAll",  "IS" },
	{ "SendDeathMessage",        "III" },
	{ "GameTextForPlayer",       "ISII" },
	{ "GameTextForAll",          "SII" },
	{ "ShowPlayerDialog",        "IIISSSS" },
	{ "SetPlayerPos",            "IIFFF" },
	{ "SetPlayerFacingAngle",    "IIF" },
	{ "SetPlayerInterior",       "II" },
	{ "SetPlayerHealth",         "IIF" },
	{ "SetPlayerArmour",         "IIF" },
	{ "SetPlayerSkin",           "II" },
	{ "SetPlayerColor",          "II" },
	{ "SetPlayerScore",          "II" },
	{ "SetPlayerTeam",           "II" },
	{ "GivePlayerMoney",         "II" },
	{ "ResetPlayerMoney",        "I" },
	{ "SpawnPlayer",             "I" },
	{ "Kick",                    "I" },
	{ "Ban",                     "I" },
	{ "TogglePlayerControllable","II" },
	{ "RemovePlayerFromVehicle", "I" },
	{ "SetPlayerAmmo",           "III" },
	{ "SetSpawnInfo",            "IIIFFFFIIIIII" },
	{ "AddPlayerClass",          "IFFFFIIIIII" },
	{ "AddStaticVehicle",        "IFFFFII" },
	{ "PutPlayerInVehicle",      "III" },
	{ "SetVehicleToRespawn",     "I" },
	{ "GivePlayerWeapon",        "III" },
	{ "ResetPlayerWeapons",      "I" },
	{ "SetWeather",              "I" },
	{ "SetWorldTime",            "I" },
	{ "SetObjectRot",            "IFFF" },
	{ "GetPlayerMoney",          "I" },
	{ "GetPlayerSkin",           "I" },
	{ "GetPlayerInterior",       "I" },
	{ "GetPlayerVehicleID",      "I" },
	{ "GetPlayerWeapon",         "I" },
	{ "IsPlayerConnected",       "I" },
	{ NULL, NULL }
};

//==============================================================
//  AMX helpers
//==============================================================
static int amx_get_string(AMX *amx, cell param, std::string &out)
{
	cell *addr = NULL;
	if (amx_GetAddr(amx, param, &addr) != AMX_ERR_NONE || addr == NULL)
		return AMX_ERR_PARAMS;

	int len = 0;
	if (amx_StrLen(addr, &len) != AMX_ERR_NONE || len <= 0)
	{
		out.clear();
		return 0;
	}
	out.resize(len);
	amx_GetString(&out[0], addr, 0, (size_t)len + 1);
	return 0;
}

static cell pack_float(double d)
{
	float f = (float)d;
	cell c = 0;
	memcpy(&c, &f, sizeof(c));
	return c;
}

static double unpack_float(cell c)
{
	float f = 0.f;
	memcpy(&f, &c, sizeof(c));
	return (double)f;
}

//==============================================================
//  Lua -> AMX мост
//==============================================================
static void lua_set_samp_amx(lua_State *L, AMX *amx)
{
	lua_pushlightuserdata(L, (void *)amx);
	lua_setfield(L, LUA_REGISTRYINDEX, "samp.amx");
}

static AMX *lua_get_samp_amx(lua_State *L)
{
	AMX *amx = NULL;
	lua_getfield(L, LUA_REGISTRYINDEX, "samp.amx");
	amx = (AMX *)lua_touserdata(L, -1);
	lua_pop(L, 1);
	return amx;
}

static int l_samp_log(lua_State *L)
{
	const char *msg = luaL_checkstring(L, 1);
	lua_log(msg ? msg : "(nil)");
	return 0;
}

// samp.callPublic(name) — вызов public в текущем amx (reentrant)
static int l_samp_call_public(lua_State *L)
{
	const char *name = luaL_checkstring(L, 1);
	AMX *amx = lua_get_samp_amx(L);
	if (!amx) { lua_pushnil(L); return 1; }

	int idx = -1;
	if (amx_FindPublic(amx, name, &idx) == AMX_ERR_NONE)
	{
		cell ret = 0;
		if (amx_Exec(amx, &ret, idx) == AMX_ERR_NONE)
			lua_pushinteger(L, (lua_Integer)ret);
		else
			lua_pushnil(L);
	}
	else
	{
		lua_pushnil(L);
	}
	return 1;
}

// samp.call("ApiName", args...) -> public API_<ApiName>(...)
static int l_samp_call(lua_State *L)
{
	const char *name = luaL_checkstring(L, 1);
	AMX *amx = lua_get_samp_amx(L);
	if (!amx) { lua_pushnil(L); return 1; }

	const Sig *s = NULL;
	for (const Sig *p = g_apis; p->name; ++p)
		if (strcmp(p->name, name) == 0) { s = p; break; }
	if (!s) { lua_pushnil(L); return 1; }

	std::string pub = "API_";
	pub += name;
	int idx = -1;
	if (amx_FindPublic(amx, pub.c_str(), &idx) != AMX_ERR_NONE) { lua_pushnil(L); return 1; }

	const int n = (int)strlen(s->sig);
	if (lua_gettop(L) != n + 1) { lua_pushnil(L); return 1; }

	std::vector<cell> free_addrs;
	bool failed = false;

	// Pawn: параметры пушатся в обратном порядке (последний первым)
	for (int i = n - 1; i >= 0; --i)
	{
		int argidx = 2 + i;
		char t = s->sig[i];
		if (t == 'S')
		{
			const char *v = luaL_checkstring(L, argidx);
			cell amx_addr = 0;
			cell *phys = NULL;
			if (amx_PushString(amx, &amx_addr, &phys, v, 0, 0) == AMX_ERR_NONE)
				free_addrs.push_back(amx_addr);
			else
				failed = true;
		}
		else if (t == 'F')
		{
			amx_Push(amx, pack_float(luaL_checknumber(L, argidx)));
		}
		else
		{
			amx_Push(amx, (cell)luaL_checkinteger(L, argidx));
		}
	}

	cell ret = 0;
	int err = failed ? AMX_ERR_NATIVE : amx_Exec(amx, &ret, idx);
	for (size_t k = 0; k < free_addrs.size(); ++k)
		amx_Release(amx, free_addrs[k]);

	if (err != AMX_ERR_NONE) { lua_pushnil(L); return 1; }
	lua_pushinteger(L, (lua_Integer)ret);
	return 1;
}

// out-парам геттеры
static int get_float_api(lua_State *L, const char *pub)
{
	const int pid = (int)luaL_checkinteger(L, 1);
	AMX *amx = lua_get_samp_amx(L);
	int idx = -1;
	if (!amx || amx_FindPublic(amx, pub, &idx) != AMX_ERR_NONE) return 0;

	cell amx_addr = 0;
	cell *phys = NULL;
	if (amx_Allot(amx, 1, &amx_addr, &phys) != AMX_ERR_NONE) return 0;

	amx_Push(amx, amx_addr);
	amx_Push(amx, pid);
	amx_Exec(amx, NULL, idx);

	double val = unpack_float(phys[0]);
	amx_Release(amx, amx_addr);
	lua_pushnumber(L, val);
	return 1;
}

static int get_string_api(lua_State *L, const char *pub)
{
	const int pid = (int)luaL_checkinteger(L, 1);
	AMX *amx = lua_get_samp_amx(L);
	int idx = -1;
	if (!amx || amx_FindPublic(amx, pub, &idx) != AMX_ERR_NONE) return 0;

	const int bufcells = 64;
	cell amx_addr = 0;
	cell *phys = NULL;
	if (amx_Allot(amx, bufcells, &amx_addr, &phys) != AMX_ERR_NONE) return 0;

	amx_Push(amx, (cell)bufcells);
	amx_Push(amx, amx_addr);
	amx_Push(amx, pid);
	amx_Exec(amx, NULL, idx);

	char buf[512];
	amx_GetString(buf, phys, 0, sizeof(buf));
	amx_Release(amx, amx_addr);
	lua_pushstring(L, buf);
	return 1;
}

static int get_vec3_api(lua_State *L)
{
	const int pid = (int)luaL_checkinteger(L, 1);
	AMX *amx = lua_get_samp_amx(L);
	int idx = -1;
	if (!amx || amx_FindPublic(amx, "API_GetPlayerPos", &idx) != AMX_ERR_NONE) return 0;

	cell amx_addr = 0;
	cell *phys = NULL;
	if (amx_Allot(amx, 3, &amx_addr, &phys) != AMX_ERR_NONE) return 0;

	amx_Push(amx, amx_addr + 2);
	amx_Push(amx, amx_addr + 1);
	amx_Push(amx, amx_addr + 0);
	amx_Push(amx, pid);
	amx_Exec(amx, NULL, idx);

	lua_pushnumber(L, unpack_float(phys[0]));
	lua_pushnumber(L, unpack_float(phys[1]));
	lua_pushnumber(L, unpack_float(phys[2]));
	amx_Release(amx, amx_addr);
	return 3;
}

static int l_samp_getplayerpos(lua_State *L)   { return get_vec3_api(L); }
static int l_samp_getplayerhealth(lua_State *L){ return get_float_api(L, "API_GetPlayerHealth"); }
static int l_samp_getplayerarmour(lua_State *L){ return get_float_api(L, "API_GetPlayerArmour"); }
static int l_samp_getplayername(lua_State *L)  { return get_string_api(L, "API_GetPlayerName"); }
static int l_samp_getplayerip(lua_State *L)    { return get_string_api(L, "API_GetPlayerIp"); }

static void lua_register_samp_table(lua_State *L)
{
	static const luaL_Reg lib[] = {
		{ "log",            l_samp_log },
		{ "callPublic",     l_samp_call_public },
		{ "call",           l_samp_call },
		{ "getPlayerPos",   l_samp_getplayerpos },
		{ "getPlayerName",  l_samp_getplayername },
		{ "getPlayerIp",    l_samp_getplayerip },
		{ "getPlayerHealth",l_samp_getplayerhealth },
		{ "getPlayerArmour",l_samp_getplayerarmour },
		{ NULL, NULL }
	};
	lua_newtable(L);
	luaL_setfuncs(L, lib, 0);
	lua_pushliteral(L, "salua_lua");
	lua_setfield(L, -2, "plugin");
	lua_setglobal(L, "samp");
}

static void run_lua_chunk(lua_State *L, const std::string &code)
{
	int status = luaL_loadstring(L, code.c_str());
	if (status == LUA_OK)
		status = lua_pcall(L, 0, 0, 0);
	if (status != LUA_OK)
	{
		lua_log(std::string("error: ") + (lua_tostring(L, -1) ? lua_tostring(L, -1) : "(nil)"));
		lua_pop(L, 1);
	}
}

static void run_lua_file(lua_State *L, const char *path)
{
	int status = luaL_loadfile(L, path);
	if (status == LUA_OK)
		status = lua_pcall(L, 0, 0, 0);
	if (status != LUA_OK)
	{
		lua_log(std::string(path) + ": " + (lua_tostring(L, -1) ? lua_tostring(L, -1) : "(nil)"));
		lua_pop(L, 1);
	}
}

//==============================================================
//  AMX natives (вызываются из Pawn)
//==============================================================
//  native Lua_Fire(const name[], {Float,_}:...);  -- сервер->Lua
static cell AMX_NATIVE_CALL n_Lua_Fire(AMX *amx, cell *params)
{
	if (!g_L)
		return 0;

	g_amx = amx;
	lua_set_samp_amx(g_L, amx);

	std::string cbname;
	if (amx_get_string(amx, params[1], cbname) != 0)
		return 0;

	const Sig *s = NULL;
	for (const Sig *p = g_callbacks; p->name; ++p)
		if (strcmp(p->name, cbname.c_str()) == 0) { s = p; break; }
	if (!s)
		return 0;

	const int n = (int)strlen(s->sig);
	int nargs = (int)(params[0] / 4) - 1;
	if (nargs < n)
		return 0;

	lua_getglobal(g_L, cbname.c_str());
	if (!lua_isfunction(g_L, -1))
	{
		lua_pop(g_L, 1);
		return 0;
	}

	for (int i = 0; i < n; ++i)
	{
		char t = s->sig[i];
		if (t == 'S')
		{
			std::string str;
			if (amx_get_string(amx, params[2 + i], str) == 0)
				lua_pushlstring(g_L, str.c_str(), str.size());
			else
				lua_pushnil(g_L);
		}
		else if (t == 'F')
		{
			lua_pushnumber(g_L, unpack_float(params[2 + i]));
		}
		else
		{
			lua_pushinteger(g_L, (lua_Integer)params[2 + i]);
		}
	}

	if (lua_pcall(g_L, n, 1, 0) != LUA_OK)
	{
		lua_log(cbname + ": " + (lua_tostring(g_L, -1) ? lua_tostring(g_L, -1) : "(nil)"));
		lua_pop(g_L, 1);
		return 0;
	}

	cell result = (cell)lua_tointeger(g_L, -1);
	lua_pop(g_L, 1);
	return result;
}

//  native Lua_Run(const code[]);
static cell AMX_NATIVE_CALL n_Lua_Run(AMX *amx, cell *params)
{
	if (!g_L)
		return 0;
	g_amx = amx;
	lua_set_samp_amx(g_L, amx);
	std::string code;
	if (amx_get_string(amx, params[1], code) == 0)
		run_lua_chunk(g_L, code);
	return 1;
}

//  native Lua_DoFile(const script[]);
static cell AMX_NATIVE_CALL n_Lua_DoFile(AMX *amx, cell *params)
{
	if (!g_L)
		return 0;
	g_amx = amx;
	lua_set_samp_amx(g_L, amx);
	std::string path;
	if (amx_get_string(amx, params[1], path) == 0)
	{
		std::string full = "lua/" + path;
		run_lua_file(g_L, full.c_str());
	}
	return 1;
}

//  native Lua_CallPublic(const name[]);
static cell AMX_NATIVE_CALL n_Lua_CallPublic(AMX *amx, cell *params)
{
	std::string name;
	if (amx_get_string(amx, params[1], name) != 0)
		return 0;
	int idx = -1;
	if (amx_FindPublic(amx, name.c_str(), &idx) == AMX_ERR_NONE)
	{
		cell ret = 0;
		if (amx_Exec(amx, &ret, idx) == AMX_ERR_NONE)
			return ret;
	}
	return 0;
}

//  native Lua_Log(const text[]);
static cell AMX_NATIVE_CALL n_Lua_Log(AMX *amx, cell *params)
{
	std::string msg;
	if (amx_get_string(amx, params[1], msg) == 0)
		lua_log(msg);
	return 1;
}

static const AMX_NATIVE_INFO lua_natives[] = {
	{ "Lua_Fire",      n_Lua_Fire },
	{ "Lua_Run",       n_Lua_Run },
	{ "Lua_DoFile",    n_Lua_DoFile },
	{ "Lua_CallPublic", n_Lua_CallPublic },
	{ "Lua_Log",       n_Lua_Log },
	{ NULL, NULL }
};

//==============================================================
//  Экспорт для samp-server.exe
//==============================================================
PLUGIN_EXPORT unsigned int PLUGIN_CALL Supports()
{
	return SUPPORTS_VERSION | SUPPORTS_AMX_NATIVES | SUPPORTS_PROCESS_TICK;
}

PLUGIN_EXPORT bool PLUGIN_CALL Load(void **ppData)
{
	pAMXFunctions = ppData[PLUGIN_DATA_AMX_EXPORTS];
	logprintf = (logprintf_t)ppData[PLUGIN_DATA_LOGPRINTF];

	g_L = luaL_newstate();
	if (g_L)
	{
		luaL_openlibs(g_L);
		lua_register_samp_table(g_L);
		lua_set_samp_amx(g_L, NULL);

		if (logprintf)
			logprintf("[Lua] salua_lua: Lua %s.%s embedded (c) 2026",
				LUA_VERSION_MAJOR, LUA_VERSION_MINOR);
	}
	else if (logprintf)
	{
		logprintf("[Lua] salua_lua: failed to create Lua state!");
	}
	return true;
}

PLUGIN_EXPORT void PLUGIN_CALL Unload()
{
	if (g_L)
	{
		lua_close(g_L);
		g_L = NULL;
	}
	if (logprintf)
		logprintf("[Lua] salua_lua unloaded");
}

PLUGIN_EXPORT int PLUGIN_CALL AmxLoad(AMX *amx)
{
	g_amx = amx;

	if (g_L && !g_autorun_done)
	{
		g_autorun_done = true;
		run_lua_file(g_L, "lua/main.lua");
	}

	return amx_Register(amx, lua_natives, -1);
}

PLUGIN_EXPORT int PLUGIN_CALL AmxUnload(AMX *amx)
{
	return AMX_ERR_NONE;
}

PLUGIN_EXPORT void PLUGIN_CALL ProcessTick()
{
	if (!g_L)
		return;

	lua_set_samp_amx(g_L, g_amx);

	lua_getglobal(g_L, "OnServerTick");
	if (lua_isfunction(g_L, -1))
	{
		if (lua_pcall(g_L, 0, 0, 0) != LUA_OK)
		{
			lua_log(std::string("OnServerTick: ") + (lua_tostring(g_L, -1) ? lua_tostring(g_L, -1) : "(nil)"));
			lua_pop(g_L, 1);
		}
	}
	else
	{
		lua_pop(g_L, 1);
	}
}