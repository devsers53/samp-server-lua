//==============================================================
//  lua_gm.pwn — прокси "гейм-мод" для плагина salua_lua
//  Вся логика живёт в Lua (lua/main.lua). Этот стаб только
//  перегоняет callbacks в плагин (Lua_Fire) и предоставляет
//  SA-MP нативы наружу (API_*) для вызова из Lua через samp.call().
//==============================================================
#include <a_samp>

// натив плагина: Lua_Fire("OnXY", ...) -> диспетчер Lua
native Lua_Fire(const name[], {Float,_}:...);

// samp-server вызывает main() при загрузке геймода
main() { }

// forward для public API_* (чтобы компилятор не ругался warning 235)
forward API_SendClientMessage(playerid, color, const text[]);
forward API_SendClientMessageToAll(color, const text[]);
forward API_SendPlayerMessageToAll(playerid, const text[]);
forward API_SendDeathMessage(killer, victim, weapon);
forward API_GameTextForPlayer(playerid, const text[], time, style);
forward API_GameTextForAll(const text[], time, style);
forward API_ShowPlayerDialog(playerid, dialogid, style, caption[], info[], button1[], button2[]);
forward API_SetPlayerPos(playerid, Float:x, Float:y, Float:z);
forward API_SetPlayerFacingAngle(playerid, Float:ang);
forward API_SetPlayerInterior(playerid, interiorid);
forward API_SetPlayerHealth(playerid, Float:health);
forward API_SetPlayerArmour(playerid, Float:armour);
forward API_SetPlayerSkin(playerid, skinid);
forward API_SetPlayerColor(playerid, color);
forward API_SetPlayerScore(playerid, score);
forward API_SetPlayerTeam(playerid, teamid);
forward API_GivePlayerMoney(playerid, money);
forward API_ResetPlayerMoney(playerid);
forward API_SpawnPlayer(playerid);
forward API_Kick(playerid);
forward API_Ban(playerid);
forward API_TogglePlayerControllable(playerid, toggle);
forward API_RemovePlayerFromVehicle(playerid);
forward API_SetPlayerAmmo(playerid, weaponslot, ammo);
forward API_SetSpawnInfo(playerid, teamid, skinid, Float:x, Float:y, Float:z, Float:angle, weapon1, weapon1_ammo, weapon2, weapon2_ammo, weapon3, weapon3_ammo);
forward API_AddPlayerClass(modelid, Float:sx, Float:sy, Float:sz, Float:angle, weapon1, weapon1_ammo, weapon2, weapon2_ammo, weapon3, weapon3_ammo);
forward API_AddStaticVehicle(vehicletype, Float:x, Float:y, Float:z, Float:angle, color1, color2);
forward API_PutPlayerInVehicle(playerid, vehicleid, seatid);
forward API_SetVehicleToRespawn(vehicleid);
forward API_GivePlayerWeapon(playerid, weaponid, ammo);
forward API_ResetPlayerWeapons(playerid);
forward API_SetWeather(weatherid);
forward API_SetWorldTime(hour);
forward API_SetObjectRot(objid, Float:rx, Float:ry, Float:rz);
forward API_GetPlayerMoney(playerid);
forward API_GetPlayerSkin(playerid);
forward API_GetPlayerInterior(playerid);
forward API_GetPlayerVehicleID(playerid);
forward API_GetPlayerWeapon(playerid);
forward API_IsPlayerConnected(playerid);
forward API_GetPlayerPos(playerid, &Float:x, &Float:y, &Float:z);
forward API_GetPlayerHealth(playerid, &Float:health);
forward API_GetPlayerArmour(playerid, &Float:armour);
forward API_GetPlayerName(playerid, name[], size);
forward API_GetPlayerIp(playerid, ip[], size);

//--------------------------------------------------------------
//  Server -> Lua: callbacks
//--------------------------------------------------------------
public OnGameModeInit()               { return Lua_Fire("OnGameModeInit"); }
public OnGameModeExit()               { return Lua_Fire("OnGameModeExit"); }
public OnRconCommand(cmd[])           { return Lua_Fire("OnRconCommand", cmd); }
public OnRconLoginAttempt(ip[], password[]) { return Lua_Fire("OnRconLoginAttempt", ip, password); }

public OnPlayerConnect(playerid)      { return Lua_Fire("OnPlayerConnect", playerid); }
public OnPlayerDisconnect(playerid, reason) { return Lua_Fire("OnPlayerDisconnect", playerid, reason); }
public OnPlayerRequestClass(playerid, classid) { return Lua_Fire("OnPlayerRequestClass", playerid, classid); }
public OnPlayerRequestSpawn(playerid) { return Lua_Fire("OnPlayerRequestSpawn", playerid); }
public OnPlayerSpawn(playerid)        { return Lua_Fire("OnPlayerSpawn", playerid); }
public OnPlayerDeath(playerid, killerid, reason) { return Lua_Fire("OnPlayerDeath", playerid, killerid, reason); }
public OnPlayerText(playerid, text[]) { return Lua_Fire("OnPlayerText", playerid, text); }
public OnPlayerCommandText(playerid, cmdtext[]) { return Lua_Fire("OnPlayerCommandText", playerid, cmdtext); }
public OnPlayerUpdate(playerid)       { return Lua_Fire("OnPlayerUpdate", playerid); }
public OnPlayerStateChange(playerid, newstate, oldstate) { return Lua_Fire("OnPlayerStateChange", playerid, newstate, oldstate); }
public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger) { return Lua_Fire("OnPlayerEnterVehicle", playerid, vehicleid, ispassenger); }
public OnPlayerExitVehicle(playerid, vehicleid) { return Lua_Fire("OnPlayerExitVehicle", playerid, vehicleid); }
public OnPlayerEnterCheckpoint(playerid) { return Lua_Fire("OnPlayerEnterCheckpoint", playerid); }
public OnPlayerLeaveCheckpoint(playerid) { return Lua_Fire("OnPlayerLeaveCheckpoint", playerid); }
public OnPlayerEnterRaceCheckpoint(playerid) { return Lua_Fire("OnPlayerEnterRaceCheckpoint", playerid); }
public OnPlayerLeaveRaceCheckpoint(playerid) { return Lua_Fire("OnPlayerLeaveRaceCheckpoint", playerid); }
public OnPlayerPickUpPickup(playerid, pickupid) { return Lua_Fire("OnPlayerPickUpPickup", playerid, pickupid); }
public OnPlayerSelectedMenuRow(playerid, row) { return Lua_Fire("OnPlayerSelectedMenuRow", playerid, row); }
public OnPlayerExitedMenu(playerid)   { return Lua_Fire("OnPlayerExitedMenu", playerid); }
public OnPlayerStreamIn(playerid, forplayerid) { return Lua_Fire("OnPlayerStreamIn", playerid, forplayerid); }
public OnPlayerStreamOut(playerid, forplayerid) { return Lua_Fire("OnPlayerStreamOut", playerid, forplayerid); }
public OnPlayerKeyStateChange(playerid, newkeys, oldkeys) { return Lua_Fire("OnPlayerKeyStateChange", playerid, newkeys, oldkeys); }
public OnPlayerTakeDamage(playerid, issuerid, Float:amount, weaponid, bodypart) { return Lua_Fire("OnPlayerTakeDamage", playerid, issuerid, amount, weaponid, bodypart); }
public OnPlayerGiveDamage(playerid, damagedid, Float:amount, weaponid, bodypart) { return Lua_Fire("OnPlayerGiveDamage", playerid, damagedid, amount, weaponid, bodypart); }
public OnPlayerWeaponShot(playerid, weaponid, hittype, hitid, Float:fX, Float:fY, Float:fZ) { return Lua_Fire("OnPlayerWeaponShot", playerid, weaponid, hittype, hitid, fX, fY, fZ); }
public OnPlayerClickMap(playerid, Float:fX, Float:fY, Float:fZ) { return Lua_Fire("OnPlayerClickMap", playerid, fX, fY, fZ); }
public OnPlayerClickPlayer(playerid, clickedplayerid, source) { return Lua_Fire("OnPlayerClickPlayer", playerid, clickedplayerid, source); }

public OnVehicleSpawn(vehicleid)      { return Lua_Fire("OnVehicleSpawn", vehicleid); }
public OnVehicleDeath(vehicleid, killerid) { return Lua_Fire("OnVehicleDeath", vehicleid, killerid); }

//--------------------------------------------------------------
//  Lua -> Server: natives (вызываются плагином напрямую по имени)
//--------------------------------------------------------------
public API_SendClientMessage(playerid, color, const text[]) { return SendClientMessage(playerid, color, text); }
public API_SendClientMessageToAll(color, const text[]) { return SendClientMessageToAll(color, text); }
public API_SendPlayerMessageToAll(playerid, const text[]) { return SendPlayerMessageToAll(playerid, text); }
public API_SendDeathMessage(killer, victim, weapon) { return SendDeathMessage(killer, victim, weapon); }
public API_GameTextForPlayer(playerid, const text[], time, style) { return GameTextForPlayer(playerid, text, time, style); }
public API_GameTextForAll(const text[], time, style) { return GameTextForAll(text, time, style); }
public API_ShowPlayerDialog(playerid, dialogid, style, caption[], info[], button1[], button2[]) { return ShowPlayerDialog(playerid, dialogid, style, caption, info, button1, button2); }

public API_SetPlayerPos(playerid, Float:x, Float:y, Float:z) { return SetPlayerPos(playerid, x, y, z); }
public API_SetPlayerFacingAngle(playerid, Float:ang) { return SetPlayerFacingAngle(playerid, ang); }
public API_SetPlayerInterior(playerid, interiorid) { return SetPlayerInterior(playerid, interiorid); }
public API_SetPlayerHealth(playerid, Float:health) { return SetPlayerHealth(playerid, health); }
public API_SetPlayerArmour(playerid, Float:armour) { return SetPlayerArmour(playerid, armour); }
public API_SetPlayerSkin(playerid, skinid) { return SetPlayerSkin(playerid, skinid); }
public API_SetPlayerColor(playerid, color) { return SetPlayerColor(playerid, color); }
public API_SetPlayerScore(playerid, score) { return SetPlayerScore(playerid, score); }
public API_SetPlayerTeam(playerid, teamid) { return SetPlayerTeam(playerid, teamid); }
public API_GivePlayerMoney(playerid, money) { return GivePlayerMoney(playerid, money); }
public API_ResetPlayerMoney(playerid) { return ResetPlayerMoney(playerid); }
public API_SpawnPlayer(playerid)      { return SpawnPlayer(playerid); }
public API_Kick(playerid)             { return Kick(playerid); }
public API_Ban(playerid)              { return Ban(playerid); }
public API_TogglePlayerControllable(playerid, toggle) { return TogglePlayerControllable(playerid, toggle); }
public API_RemovePlayerFromVehicle(playerid) { return RemovePlayerFromVehicle(playerid); }
public API_SetPlayerAmmo(playerid, weaponslot, ammo) { return SetPlayerAmmo(playerid, weaponslot, ammo); }
public API_SetSpawnInfo(playerid, teamid, skinid, Float:x, Float:y, Float:z, Float:angle, weapon1, weapon1_ammo, weapon2, weapon2_ammo, weapon3, weapon3_ammo) { return SetSpawnInfo(playerid, teamid, skinid, x, y, z, angle, weapon1, weapon1_ammo, weapon2, weapon2_ammo, weapon3, weapon3_ammo); }
public API_AddPlayerClass(modelid, Float:sx, Float:sy, Float:sz, Float:angle, weapon1, weapon1_ammo, weapon2, weapon2_ammo, weapon3, weapon3_ammo) { return AddPlayerClass(modelid, sx, sy, sz, angle, weapon1, weapon1_ammo, weapon2, weapon2_ammo, weapon3, weapon3_ammo); }
public API_AddStaticVehicle(vehicletype, Float:x, Float:y, Float:z, Float:angle, color1, color2) { return AddStaticVehicle(vehicletype, x, y, z, angle, color1, color2); }
public API_PutPlayerInVehicle(playerid, vehicleid, seatid) { return PutPlayerInVehicle(playerid, vehicleid, seatid); }
public API_SetVehicleToRespawn(vehicleid) { return SetVehicleToRespawn(vehicleid); }
public API_GivePlayerWeapon(playerid, weaponid, ammo) { return GivePlayerWeapon(playerid, weaponid, ammo); }
public API_ResetPlayerWeapons(playerid) { return ResetPlayerWeapons(playerid); }
public API_SetWeather(weatherid)      { return SetWeather(weatherid); }
public API_SetWorldTime(hour)         { return SetWorldTime(hour); }
public API_SetObjectRot(objid, Float:rx, Float:ry, Float:rz) { return SetObjectRot(objid, rx, ry, rz); }

// int-геттеры: плагин просто берёт возврат публичной функции
public API_GetPlayerMoney(playerid)   { return GetPlayerMoney(playerid); }
public API_GetPlayerSkin(playerid)    { return GetPlayerSkin(playerid); }
public API_GetPlayerInterior(playerid) { return GetPlayerInterior(playerid); }
public API_GetPlayerVehicleID(playerid) { return GetPlayerVehicleID(playerid); }
public API_GetPlayerWeapon(playerid)  { return GetPlayerWeapon(playerid); }
public API_IsPlayerConnected(playerid) { return IsPlayerConnected(playerid); }

// out-парам геттеры (плагин выделяет буферы сам)
public API_GetPlayerPos(playerid, &Float:x, &Float:y, &Float:z) { return GetPlayerPos(playerid, x, y, z); }
public API_GetPlayerHealth(playerid, &Float:health) { return GetPlayerHealth(playerid, health); }
public API_GetPlayerArmour(playerid, &Float:armour) { return GetPlayerArmour(playerid, armour); }
public API_GetPlayerName(playerid, name[], size) { return GetPlayerName(playerid, name, size); }
public API_GetPlayerIp(playerid, ip[], size) { return GetPlayerIp(playerid, ip, size); }