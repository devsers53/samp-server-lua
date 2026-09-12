#if defined _inc_lua_salua
    #endinput
#endif
#define _inc_lua_salua

/*
	salua_lua plugin (SA-MP 0.3.7 + Lua 5.5)
	Скрипты: <сервер>/lua/ (main.lua автозапускается)
*/
native Lua_Run(const code[]);
native Lua_DoFile(const script[]);
native Lua_CallPublic(const name[]);
native Lua_Log(const text[]);