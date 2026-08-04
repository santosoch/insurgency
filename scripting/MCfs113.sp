//(C) 2020 rrrfffrrr <rrrfffrrr@naver.com>
// 1.1.3 - remove napalm, add gCvarBotM777Warning

#include <sourcemod>
#include <datapack>
#include <float>
#include <sdktools>
#include <sdktools_trace>
#include <sdktools_functions>
#include <timers>
#include <loghelper>
#include <morecolors182>

#pragma semicolon 1
#pragma newdecls required

#define SIZE_OF_INT 2147483647 // without 0
#define MATH_PI 3.14159265359
#define TEAM_SEC	2
#define TEAM_INS	3

public Plugin myinfo = {
	name		= "M777 Fire Support",
	author		= "rrrfffrrr & Bot Chris",
	description	= "M777 Fire Support",
	version		= "1.1.3",
	url			= ""
};

int redColor[4]		= {255, 0, 0, 255};
int greenColor[4]	= {0, 255, 0, 255};
int orangeColor[4]	= {255, 128, 0, 255};

float UP_VECTOR[3] = {-90.0, 0.0, 0.0};
float DOWN_VECTOR[3] = {90.0, 0.0, 0.0};

Handle cGameConfig;
Handle fCreateRocket;
int gBeamSprite;
int g_iObjResource;
int g_iCurrentActiveObj;
int g_iTotalObj;

ConVar gCvarM777MaxSpread;
ConVar gCvarM777Round;
ConVar gCvarFS_Delay;
ConVar gCvarM777DeployCount;
ConVar gCvarKillForBonus;

ConVar gCvarM203Round;
ConVar gCvarM203MaxSpread;
ConVar gCvarAdminInfinite;
ConVar gCvarBotM777Chance;
ConVar gCvarBotF18_Enabled;
ConVar gCvarBotFS_ShowHalo;
ConVar gCvarBotFS_NapalmChance;
ConVar gCvarBotFS_Delay;
ConVar gCvarBotM777Round;
ConVar gCvarBotM777MaxSpread;
ConVar gCvarBotM777Warning;

StringMap playerList;
int g_iTokenM777[MAXPLAYERS+1];
int g_iTokenM203[MAXPLAYERS+1];
int g_iKillCount[MAXPLAYERS+1];
int g_iBotDeadCount;
bool g_bObjectCache = false;
float g_fLaunchSoundTime;
int g_iM777ShellCount;
bool g_bIsCheckpointMode = false;
bool g_bIsOutpostMode = false;
bool g_bIsHuntMode = false;
bool g_bIsAlone;

//native int MC_discordMsg(const char[] sMsg, bool bTime = true);

public void OnPluginStart() {
	cGameConfig = LoadGameConfigFile("insurgency.games");
	if (cGameConfig == INVALID_HANDLE) {
		SetFailState("Fatal Error: Missing File \"insurgency.games\"!");
	}

	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(cGameConfig, SDKConf_Signature, "CBaseRocketMissile::CreateRocketMissile");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_ByValue);
	fCreateRocket = EndPrepSDKCall();
	if (fCreateRocket == INVALID_HANDLE) {
		SetFailState("Fatal Error: Unable to find CBaseRocketMissile::CreateRocketMissile");
	}

	g_iObjResource = FindEntityByClassname(-1, "ins_objective_resource");
	g_iCurrentActiveObj = FindSendPropInfo("CINSObjectiveResource", "m_nActivePushPointIndex");
	g_iTotalObj = FindSendPropInfo("CINSObjectiveResource", "m_iNumControlPoints");

	gCvarM777Round = CreateConVar("sm_M777_Shell_Num", "20.0", "Shells to fire.", FCVAR_PROTECTED);
	gCvarM777MaxSpread = CreateConVar("sm_M777_Spread", "10.0", "Max spread.", FCVAR_PROTECTED);
	gCvarFS_Delay = CreateConVar("sm_FS_delay", "1.0", "Min delay to first shell.", FCVAR_PROTECTED);
	gCvarM777DeployCount = CreateConVar("sm_M777DeployCount", "1", "Max amount player can deploy M777 support.", FCVAR_PROTECTED);
	gCvarKillForBonus = CreateConVar("sm_M777KillForBonus", "100", "Kills needed for bonus M777 token.", FCVAR_PROTECTED);

	gCvarM203Round = CreateConVar("sm_M203_Shell_Num", "10.0", "M203 Shells to fire.", FCVAR_PROTECTED);
	gCvarM203MaxSpread = CreateConVar("sm_M203_Spread", "10.0", "M203 Max spread.", FCVAR_PROTECTED);
	gCvarAdminInfinite = CreateConVar("sm_AdminInfinite_FS", "0", "Admin has infinite M777 token.", FCVAR_PROTECTED);

	gCvarBotM777Chance = CreateConVar("sm_BotM777_Chance", "0", "chance by percent bot might deploy M777", FCVAR_PROTECTED);
	gCvarBotF18_Enabled = CreateConVar("sm_BotF18_Enabled", "0", "enable bot F18", FCVAR_PROTECTED);
	gCvarBotFS_ShowHalo = CreateConVar("sm_BotFS_BotFS_ShowHalo", "1", "Bot m777 will show Halo", FCVAR_PROTECTED);
	gCvarBotFS_NapalmChance = CreateConVar("sm_BotFS_NapalmChance", "0", "Chance Bot add Napalm FS.", FCVAR_PROTECTED);
	gCvarBotFS_Delay = CreateConVar("sm_BotFS_delay", "7.0", "Bot m777 Min delay to first shell.", FCVAR_PROTECTED);
	gCvarBotM777Round = CreateConVar("sm_BotM777_Shell_Num", "10", "Bot M777 Shells to fire.", FCVAR_PROTECTED);
	gCvarBotM777MaxSpread = CreateConVar("sm_BotM777_Spread", "10.0", "Bot M777 Max spread.", FCVAR_PROTECTED);
	gCvarBotM777Warning = CreateConVar("sm_BotM777_Warning", "1", "Bot M777 Warning.", FCVAR_PROTECTED);

	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	HookEvent("controlpoint_captured", Event_ObjectReached, EventHookMode_Post);
	HookEvent("object_destroyed", Event_ObjectReached, EventHookMode_Post);

	//RegAdminCmd("sm_firesupport", CmdCallFS, 0);
	RegAdminCmd("fs", Command_RandomFS, ADMFLAG_ROOT, "Random Bot FS");
	RegConsoleCmd("m777", CmdCallM777, "M777 Howitzer");
	RegConsoleCmd("m203", CmdCallM203, "M203 Smoke Support");
	playerList = new StringMap();

}

public void OnMapStart() {
	char sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, 32);
	g_bIsCheckpointMode = StrEqual(sGameMode, "checkpoint");
	g_bIsOutpostMode = StrEqual(sGameMode, "outpost");
	g_bIsHuntMode = StrEqual(sGameMode, "hunt");

	g_bIsAlone = true;
	g_iObjResource = FindEntityByClassname(-1, "ins_objective_resource");
	CreateTimer(0.1, Timer_ThinkTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	PrecacheSound_m777();
	gBeamSprite = PrecacheModel("sprites/laserbeam.vmt", true);
	PrecacheSound("weapons/ied/handling/ied_throw.wav", true);
	PrecacheSound("weapons/ied/handling/ied_trigger_ins.wav", true);
	PrecacheSound("weapons/ied/water/ied_water_detonate_01.wav", true);
	PrecacheSound("weapons/ied/water/ied_water_detonate_02.wav", true);
	PrecacheSound("weapons/ied/water/ied_water_detonate_03.wav", true);
	PrecacheSound("weapons/ied/water/ied_water_detonate_dist_01.wav", true);
	PrecacheSound("weapons/ied/water/ied_water_detonate_dist_02.wav", true);
	PrecacheSound("weapons/ied/water/ied_water_detonate_dist_03.wav", true);
	PrecacheSound("weapons/ied/ied_bounce_01.wav", true);
	PrecacheSound("weapons/ied/ied_bounce_02.wav", true);
	PrecacheSound("weapons/ied/ied_bounce_03.wav", true);
	PrecacheSound("weapons/ied/ied_detonate_01.wav", true);
	PrecacheSound("weapons/ied/ied_detonate_02.wav", true);
	PrecacheSound("weapons/ied/ied_detonate_03.wav", true);
	PrecacheSound("weapons/ied/ied_detonate_dist_01.wav", true);
	PrecacheSound("weapons/ied/ied_detonate_dist_02.wav", true);
	PrecacheSound("weapons/ied/ied_detonate_dist_03.wav", true);
	PrecacheSound("weapons/ied/ied_detonate_far_dist_01.wav", true);
	PrecacheSound("weapons/ied/ied_detonate_far_dist_02.wav", true);
	PrecacheSound("weapons/ied/ied_detonate_far_dist_03.wav", true);
}

public void OnClientPutInServer(int client) 
{
	g_iTokenM777[client] = 0;
	g_iTokenM203[client] = 0;
	g_iKillCount[client] = 0;
	if (!IsValidPlayer(client) || IsFakeClient(client)) return;

	char steamId[32];
	int temp;
	GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));
	
	if (!playerList.GetValue(steamId, temp)) {
		g_iTokenM777[client] = gCvarM777DeployCount.IntValue;
		g_iTokenM203[client] = 1;
	}
}

Action Timer_ThinkTimer(Handle timer) {
	if (GetGameState() != 4) return Plugin_Continue;

	int iPlayerCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i)) continue;
		iPlayerCount++;
		if (iPlayerCount > 3) break;
	}
	g_bIsAlone = (iPlayerCount <= 3);
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (gCvarM777Round.IntValue <= 0) return Plugin_Continue;
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	bool bLastCheckpointObj = false;
	if (g_bIsCheckpointMode)
	{
		int acp = GetEntData(g_iObjResource, g_iCurrentActiveObj); // Get active push point
		int ncp = GetEntData(g_iObjResource, g_iTotalObj); // Get the number of control points
		bLastCheckpointObj = (acp+1 != ncp);
	}

	if (IsValidPlayer(attacker) && !IsFakeClient(attacker)) {
		g_iKillCount[attacker]++;
		if (g_iKillCount[attacker] >= gCvarKillForBonus.IntValue) {
			g_iTokenM777[attacker]++;
			g_iKillCount[attacker] = 0;
			PrintCenterText(attacker, "%d KILLS! YOU'VE GOT 1 TOKEN FOR M777 FIRE SUPPORT.", gCvarKillForBonus.IntValue);
			CPrintToChat(attacker, "{ghostwhite}Your {fuchsia}M777 token {ghostwhite}is now: {deepskyblue}%d", g_iTokenM777[attacker]);
		}
	}

	if (g_bIsHuntMode) g_iBotDeadCount = 100; //in hunt mode, no need min kill count
	if (gCvarBotM777Chance.IntValue > 0 && IsValidPlayer(client) && IsFakeClient(client)) {
		g_iBotDeadCount++;
		int iRand1 = GetRandomInt(1, 5000);
		int iRand2 = GetRandomInt(1, 100);
		if (g_iBotDeadCount >= 25 && iRand1 <= gCvarBotM777Chance.IntValue && iRand2 <= 50 && (!IsCounterAttack() || bLastCheckpointObj)) {
			BotCall_FS(client, attacker);
			g_iBotDeadCount = 0;
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_iTokenM777[client] = 0;
	g_iTokenM203[client] = 0;
	g_iKillCount[client] = 0;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_iBotDeadCount = 10;
	playerList.Clear();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i) || IsFakeClient(i)) continue;

		g_iTokenM777[i] -= gCvarM777DeployCount.IntValue;
		if (g_iTokenM777[i] < 0) g_iTokenM777[i] = 0;

		g_iTokenM777[i] += gCvarM777DeployCount.IntValue;
		g_iTokenM203[i] = 1;
	}
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	playerList.Clear();
}

public Action Event_ObjectReached(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bIsCheckpointMode) g_bObjectCache = StrEqual(name, "object_destroyed", false);
	else g_bObjectCache = false;
}

public Action Command_RandomFS(int client, any args)
{
	int target = GetRandomTarget(TEAM_SEC);
	if (args < 1)
	{
		BotCallRandomM777(target);
		return Plugin_Handled;
	}
	char arg[8];
	int type = 1;
	GetCmdArg(1, arg, sizeof(arg));
	type = StringToInt(arg);

	if (type == 1 && !g_bIsOutpostMode) BotCallRandomNapalm(target);
	else if (type == 2) BotCallRandomSarinGas(target);
	else if (type == 3)
	{
		BotCallRandomM777(target);
		if (!g_bIsOutpostMode) BotCallRandomNapalm(target);
		BotCallRandomSarinGas(target);
	}

	return Plugin_Handled;
}

void BotCallRandomM777(int target, bool sound = true)
{
	if (GetGameState() != 4) return;

	int bot = GetRandomPlayer(TEAM_INS);
	//int target = GetRandomTarget(TEAM_SEC);

	char sMsg[255];
	float pos[3];
	float sky[3];

	if (bot > 0 && target > 0)
	{
		GetClientAbsOrigin(target, pos);
		if (GetSkyPos(target, pos, sky)) {
			BotCallRandomFS(bot, pos, sky, 1); //type 1=m777, 2=napalm, 3=sarin
			if (sound && gCvarBotM777Warning.BoolValue) PlayIncomingSound();
			FormatEx(sMsg, sizeof(sMsg), "[ENEMY BOT] has called Random M777 fire support!");
			//MC_discordMsg(sMsg);
			ServerCommand("discordmsg %s", sMsg);
		}
	}
}

void BotCallRandomNapalm(int target, bool sound = true)
{
	if (GetGameState() != 4) return;

	int bot = GetRandomPlayer(TEAM_INS);
	//int target = GetRandomTarget(TEAM_SEC);

	char sMsg[255];
	float pos[3];
	float sky[3];

	if (bot > 0 && target > 0)
	{
		GetClientAbsOrigin(target, pos);
		if (GetSkyPos(target, pos, sky)) {
			BotCallRandomFS(bot, pos, sky, 2); //type 1=m777, 2=napalm, 3=sarin
			if (sound && gCvarBotM777Warning.BoolValue) PlayIncomingSound();
			FormatEx(sMsg, sizeof(sMsg), "[ENEMY BOT] has called Random NAPALM fire support!");
			//MC_discordMsg(sMsg);
			ServerCommand("discordmsg %s", sMsg);
		}
	}
}

void BotCallRandomSarinGas(int target, bool sound = true)
{
	if (GetGameState() != 4) return;

	int bot = GetRandomPlayer(TEAM_INS);
	//int target = GetRandomTarget(TEAM_SEC);

	char sMsg[255];
	float pos[3];
	float sky[3];

	if (bot > 0 && target > 0)
	{
		GetClientAbsOrigin(target, pos);
		if (GetSkyPos(target, pos, sky)) {
			BotCallRandomFS(bot, pos, sky, 3); //type 1=m777, 2=napalm, 3=sarin
			if (sound && gCvarBotM777Warning.BoolValue) PlayIncomingSound();
			FormatEx(sMsg, sizeof(sMsg), "[ENEMY BOT] has called Random Sarin Gas fire support!");
			//MC_discordMsg(sMsg);
			ServerCommand("discordmsg %s", sMsg);
		}
	}
}

public void BotCall_FS(int bot, int killer)
{
	if (GetGameState() != 4) return;

	char sMsg[255];
	float pos[3];
	float sky[3];
	int iIarget = -1;
	bool bHasTarget = false;

	if (IsValidPlayer(killer) && !IsFakeClient(killer) && IsPlayerAlive(killer)) {
		GetClientAbsOrigin(killer, pos);
		if (GetSkyPos(killer, pos, sky)) {
			iIarget = killer;
			bHasTarget = true;
		}
	}

	if (GetRandomInt(1, 2) == 1 && bHasTarget && gCvarBotF18_Enabled.BoolValue && !g_bIsAlone)
	{
		BotCallF18Support(bot, pos, sky);
		if (gCvarBotM777Warning.BoolValue) CPrintToChatAll("{unique}[ENEMY'S F-18] {deepskyblue}has dropped {fullred}GBU-12 A/B {ghostwhite}Laser Guided Bomb.");
		FormatEx(sMsg, sizeof(sMsg), "[ENEMY'S F-18] has dropped GBU-12 A/B Laser Guided Bomb!");
		ServerCommand("discordmsg %s", sMsg);
		return;
	}

	if (!bHasTarget)
	{
		iIarget = GetRandomTarget(TEAM_SEC);
		if (iIarget > 0)
		{
			GetClientAbsOrigin(iIarget, pos);
			if (GetSkyPos(iIarget, pos, sky)) bHasTarget = true;
		}
	}

	if (bHasTarget)
	{
		BotCallM777Support(bot, pos, sky, iIarget);
		if (gCvarBotM777Warning.BoolValue) PlayIncomingSound();
		FormatEx(sMsg, sizeof(sMsg), "[ENEMY BOT] has called M777 Howitzer fire support!");
		ServerCommand("discordmsg %s", sMsg);
	}
}

public float GetDistance(int client, int target)
{
	float fClientOrigin[3], fTargetOrigin[3];
	GetClientAbsOrigin(client, fClientOrigin);
	GetClientAbsOrigin(target, fTargetOrigin);
	return GetVectorDistance(fClientOrigin, fTargetOrigin) * 0.01905; //in meters
}

public void PlayIncomingSound()
{
	char sVoice[128];
	Format(sVoice, sizeof(sVoice), "m777/incoming/incoming%d.ogg", GetRandomInt(1, 29)); // total 29 voices
	for (int i = 1; i < MaxClients+1; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			ClientCommand(i, "play %s", sVoice);
		}
	}
}

Action CmdCallM777(int client, int args) {
	if (GetGameState() != 4 || !IsValidPlayer(client) || GetClientTeam(client) == TEAM_INS || !IsPlayerAlive(client)) return Plugin_Handled;
	if (gCvarM777Round.IntValue <= 0) {
		CPrintToChat(client, "{mediumspringgreen}CAN'T DO! {fuchsia}M777 Howitzer {unique}is DISABLE!");
		return Plugin_Handled;
	}

	//gCvarAdminInfinite
	if (g_iTokenM777[client] <= 0 && (!gCvarAdminInfinite.BoolValue || !CheckCommandAccess(client, "adminaccesscheck", ADMFLAG_ROOT))) {
		PrintCenterText(client, "NO MORE M777 TOKEN.");
		return Plugin_Handled;
	}

	char steamId[32];
	int temp;
	GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));
	if (!playerList.GetValue(steamId, temp)) playerList.SetValue(steamId, temp, true);

	float ground[3];
	if (GetAimGround(client, ground)) {
		ground[2] += 20.0;
		CallM777Support(client, ground);
	}
	return Plugin_Handled;
}

Action CmdCallM203(int client, int args) {
	if (GetGameState() != 4 || !IsValidPlayer(client) || GetClientTeam(client) == TEAM_INS || !IsPlayerAlive(client)) return Plugin_Handled;
	if (gCvarM203Round.IntValue <= 0) {
		CPrintToChat(client, "{mediumspringgreen}CAN'T DO! {fuchsia}M203 Smoke Support {unique}is DISABLE!");
		return Plugin_Handled;
	}

	//gCvarAdminInfinite
	if (g_iTokenM203[client] <= 0 && (!gCvarAdminInfinite.BoolValue || !CheckCommandAccess(client, "adminaccesscheck", ADMFLAG_ROOT))) {
		PrintCenterText(client, "NO MORE M203 TOKEN.");
		return Plugin_Handled;
	}

	char steamId[32];
	int temp;
	GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));
	if (!playerList.GetValue(steamId, temp)) playerList.SetValue(steamId, temp, true);

	float ground[3];
	if (GetAimGround(client, ground)) {
		ground[2] += 20.0;
		CallM203Support(client, ground);
	}
	return Plugin_Handled;
}

/// FireSupport
public void CallM777Support(int client, float ground[3]) {
	float sky[3];
	char sVoice[128];
	if (GetSkyPos(client, ground, sky)) {
		LogPlayerEvent(client, "triggered", "chaos_arty");
		Format(sVoice, sizeof(sVoice), "m777/requestartillery/requestartillery%d.ogg", GetRandomInt(1, 28)); // total 28 voices
		EmitSoundToAll(sVoice, client, SNDCHAN_VOICE, _, _, 1.0);

		sky[2] -= 20.0;
		float time = gCvarFS_Delay.FloatValue;
		int shells = gCvarM777Round.IntValue;
		DataPack pack = new DataPack();
		pack.WriteCell(client);
		pack.WriteCell(shells);
		pack.WriteFloat(sky[0]);
		pack.WriteFloat(sky[1]);
		pack.WriteFloat(sky[2]);

		ShowDelayEffect(ground, sky, time, orangeColor);
		if (gCvarM777Round.IntValue > 2) CreateTimer(time + 0.05, Timer_LaunchM777, pack, TIMER_FLAG_NO_MAPCHANGE);
		else CreateTimer(time + 0.05, Timer_LaunchF18, pack, TIMER_FLAG_NO_MAPCHANGE);

		g_iTokenM777[client]--;
		if (g_iTokenM777[client] < 0) g_iTokenM777[client] = 0;
		if (IsValidPlayer(client)) {
			CPrintToChatAll("{unique}%N {deepskyblue}has called {fullred}M777 Howitzer {ghostwhite}fire support.", client);
			CPrintToChat(client, "{ghostwhite}Your {fuchsia}M777 token {ghostwhite}is now: {deepskyblue}%d", g_iTokenM777[client]);
		}
	}
	else {
		CPrintToChat(client, "{ghostwhite}TARGET is {orange}NOT VALID! {skyblue}(T=%d)", g_iTokenM777[client]);
		Format(sVoice, sizeof(sVoice), "m777/invalid/invalidtarget%d.ogg", GetRandomInt(1, 10)); // total 10 voices
		EmitSoundToClient(client, sVoice, client);
	}
}

public void CallM203Support(int client, float ground[3]) {
	float sky[3];
	char sVoice[128];
	if (GetSkyPos(client, ground, sky)) {
		Format(sVoice, sizeof(sVoice), "m777/requestsmoke/requestsmokeartillery%d.ogg", GetRandomInt(1, 30)); // total 30 voices
		EmitSoundToAll(sVoice, client, SNDCHAN_VOICE, _, _, 1.0);

		sky[2] -= 20.0;
		float time = gCvarFS_Delay.FloatValue;
		int shells = gCvarM203Round.IntValue;
		DataPack pack = new DataPack();
		pack.WriteCell(client);
		pack.WriteCell(shells);
		pack.WriteFloat(sky[0]);
		pack.WriteFloat(sky[1]);
		pack.WriteFloat(sky[2]);

		ShowDelayEffect(ground, sky, time, greenColor);
		CreateTimer(time + 0.05, Timer_LaunchM203, pack, TIMER_FLAG_NO_MAPCHANGE);

		g_iTokenM203[client]--;
		if (g_iTokenM203[client] < 0) g_iTokenM203[client] = 0;
		if (IsValidPlayer(client)) {
			CPrintToChatAll("{unique}%N {ghostwhite}has called {mediumspringgreen}M203 Smoke {ghostwhite}fire support.", client);
			CPrintToChat(client, "{ghostwhite}Your {fuchsia}M203 token {ghostwhite}is now: {deepskyblue}%d", g_iTokenM203[client]);
		}
	}
	else {
		CPrintToChat(client, "{ghostwhite}TARGET is {orange}NOT VALID!");
		Format(sVoice, sizeof(sVoice), "m777/invalid/invalidtarget%d.ogg", GetRandomInt(1, 10)); // total 10 voices
		EmitSoundToClient(client, sVoice, client);
	}
}

void BotCallRandomFS(int client, float ground[3], float sky[3], int type = 1) //type 1=m777, 2=napalm, 3=sarin
{
	sky[2] -= 20.0;
	float time = gCvarBotFS_Delay.FloatValue;
	int shells = gCvarBotM777Round.IntValue;
	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(shells);
	pack.WriteFloat(sky[0]);
	pack.WriteFloat(sky[1]);
	pack.WriteFloat(sky[2]);

	if (type==3)
	{
		if (g_fLaunchSoundTime < GetGameTime())
		{
			//distant launch sound
			g_fLaunchSoundTime = GetGameTime() + gCvarBotFS_Delay.FloatValue - 0.5;
			g_iM777ShellCount = gCvarBotM777Round.IntValue;
			CreateTimer(0.5, Timer_BotLaunchSoundM777, _, TIMER_FLAG_NO_MAPCHANGE);
		}

		CreateTimer(time + 0.05, Timer_BotLaunchSarinGas, pack, TIMER_FLAG_NO_MAPCHANGE);
		if (gCvarBotM777Warning.BoolValue) CPrintToChatAll("{unique}[ENEMY BOT] {ghostwhite}has called {fullred}SARIN GAS FS!!! {mediumspringgreen}RUN.....!!!");
	}
	else if (type==2)
	{
		if (g_fLaunchSoundTime < GetGameTime())
		{
			//distant launch sound
			g_fLaunchSoundTime = GetGameTime() + gCvarBotFS_Delay.FloatValue - 0.5;
			g_iM777ShellCount = gCvarBotM777Round.IntValue;
			CreateTimer(0.5, Timer_BotLaunchSoundM777, _, TIMER_FLAG_NO_MAPCHANGE);
		}

		CreateTimer(time + 0.05, Timer_BotLaunchNapalm, pack, TIMER_FLAG_NO_MAPCHANGE);
		if (gCvarBotM777Warning.BoolValue) CPrintToChatAll("{unique}[ENEMY BOT] {ghostwhite}has called {fullred}NAPALM BOMB!!! {mediumspringgreen}RUN.....!!!");
	}
	else if (type==1)
	{
		//distant launch sound
		g_fLaunchSoundTime = GetGameTime() + gCvarBotFS_Delay.FloatValue - 0.5;
		g_iM777ShellCount = gCvarBotM777Round.IntValue;
		CreateTimer(0.5, Timer_BotLaunchSoundM777, _, TIMER_FLAG_NO_MAPCHANGE);

		if (gCvarBotFS_ShowHalo.BoolValue) ShowDelayEffect_Bot(ground, sky, time);
		PlayIncomingEffect();
		CreateTimer(time + 0.05 + GetURandomFloat(), Timer_BotLaunchM777, pack, TIMER_FLAG_NO_MAPCHANGE);
		if (gCvarBotM777Warning.BoolValue) CPrintToChatAll("{unique}[ENEMY BOT] {deepskyblue}has called {fullred}M777 Howitzer {ghostwhite}fire support.");
	}
}

public void BotCallM777Support(int client, float ground[3], float sky[3], int target) {
	sky[2] -= 20.0;
	float time = gCvarBotFS_Delay.FloatValue;
	int shells = gCvarBotM777Round.IntValue;
	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(shells);
	pack.WriteFloat(sky[0]);
	pack.WriteFloat(sky[1]);
	pack.WriteFloat(sky[2]);

	if (GetRandomInt(1, 100) <= gCvarBotFS_NapalmChance.IntValue)
	{
		int othertarget = GetRandomTarget(TEAM_SEC, target);
		BotCallRandomSarinGas(othertarget, false);

/*		if (!g_bIsOutpostMode && GetRandomInt(1, 2) <= 1)
		{
			if (!g_bObjectCache || !IsCounterAttack()) BotCallRandomNapalm(othertarget, false);
			else BotCallRandomSarinGas(othertarget, false);
		}
		else BotCallRandomSarinGas(othertarget, false); */
	}

	//distant launch sound
	g_fLaunchSoundTime = GetGameTime() + gCvarBotFS_Delay.FloatValue - 0.5;
	g_iM777ShellCount = gCvarBotM777Round.IntValue;
	CreateTimer(0.5, Timer_BotLaunchSoundM777, _, TIMER_FLAG_NO_MAPCHANGE);

	if (gCvarBotFS_ShowHalo.BoolValue) ShowDelayEffect_Bot(ground, sky, time);
	PlayIncomingEffect();
	CreateTimer(time + 0.05 + GetURandomFloat(), Timer_BotLaunchM777, pack, TIMER_FLAG_NO_MAPCHANGE);
	if (gCvarBotM777Warning.BoolValue) CPrintToChatAll("{unique}[ENEMY BOT] {deepskyblue}has called {fullred}M777 Howitzer {ghostwhite}fire support.");
}

public void BotCallF18Support(int client, float ground[3], float sky[3]) {
	sky[2] -= 20.0;
	float time = 2.0;
	int shells = 1;
	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(shells);
	pack.WriteFloat(sky[0]);
	pack.WriteFloat(sky[1]);
	pack.WriteFloat(sky[2]);

	if (gCvarBotFS_ShowHalo.BoolValue) ShowDelayEffect_Bot(ground, sky, 0.2);
	CreateTimer(time, Timer_BotLaunchF18, pack, TIMER_FLAG_NO_MAPCHANGE);
}

void ShowDelayEffect(float ground[3], float sky[3], float time, int iColor[4]) {	// WARNING: Tempent can't alive more than 25 second. must use env_beam entity
	TE_SetupBeamPoints(ground, sky, gBeamSprite, 0, 0, 1, time, 2.0, 0.0, 5, 0.0, iColor, 10);
	TE_SendToAll();
	TE_SetupBeamRingPoint(ground, 500.0, 0.0, gBeamSprite, 0, 0, 1, time, 5.0, 0.0, iColor, 10, 0);
	TE_SendToAll();
}

void ShowDelayEffect_Bot(float ground[3], float sky[3], float time) {	// WARNING: Tempent can't alive more than 25 second. must use env_beam entity
	TE_SetupBeamPoints(ground, sky, gBeamSprite, 0, 0, 1, time, 20.0, 0.0, 5, 0.0, redColor, 10);
	TE_SendToAll();
	ground[2] += 15.0;
	TE_SetupBeamRingPoint(ground, 800.0, 0.0, gBeamSprite, 0, 0, 1, time, 20.0, 0.0, redColor, 10, 0);
	TE_SendToAll();
}

public Action Timer_LaunchM777(Handle timer, DataPack pack) {
	float dir = GetURandomFloat() * MATH_PI * 8.0;	// not 2π for good result
	float length = GetURandomFloat() * gCvarM777MaxSpread.FloatValue / 0.01905; //in meter

	pack.Reset();
	int client = pack.ReadCell();

	DataPackPos cursor = pack.Position;
	int shells = pack.ReadCell();
	pack.Position = cursor;
	pack.WriteCell(shells - 1);

	float pos[3];
	pos[0] = pack.ReadFloat() + Cosine(dir) * length;
	pos[1] = pack.ReadFloat() + Sine(dir) * length;
	pos[2] = pack.ReadFloat();

	if (IsValidPlayer(client) && GetGameState() == 4) {
		SDKCall(fCreateRocket, client, "grenade_m777", pos, DOWN_VECTOR);
		if (shells > 1) {
			CreateTimer(0.05 + GetURandomFloat() + GetURandomFloat(), Timer_LaunchM777, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		else CreateTimer(0.1, Timer_DataPackExpire, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	}
	else CreateTimer(0.1, Timer_DataPackExpire, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	return Plugin_Handled;
}

public Action Timer_LaunchF18(Handle timer, DataPack pack) {
	float dir = GetURandomFloat() * MATH_PI * 8.0;	// not 2π for good result
	float length = GetURandomFloat() * gCvarM777MaxSpread.FloatValue / 0.01905; //in meter

	pack.Reset();
	int client = pack.ReadCell();

	DataPackPos cursor = pack.Position;
	int shells = pack.ReadCell();
	pack.Position = cursor;
	pack.WriteCell(shells - 1);

	float pos[3];
	pos[0] = pack.ReadFloat() + Cosine(dir) * length;
	pos[1] = pack.ReadFloat() + Sine(dir) * length;
	pos[2] = pack.ReadFloat();

	if (IsValidPlayer(client) && GetGameState() == 4) {
		SDKCall(fCreateRocket, client, "grenade_f18", pos, DOWN_VECTOR);
		if (shells > 1) {
			CreateTimer(0.05 + GetURandomFloat() + GetURandomFloat(), Timer_LaunchF18, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		else CreateTimer(0.1, Timer_DataPackExpire, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	}
	else CreateTimer(0.1, Timer_DataPackExpire, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	return Plugin_Handled;
}

public Action Timer_LaunchM203(Handle timer, DataPack pack) {
	float dir = GetURandomFloat() * MATH_PI * 8.0;	// not 2π for good result
	float length = GetURandomFloat() * gCvarM203MaxSpread.FloatValue / 0.01905; //in meter

	pack.Reset();
	int client = pack.ReadCell();

	DataPackPos cursor = pack.Position;
	int shells = pack.ReadCell();
	pack.Position = cursor;
	pack.WriteCell(shells - 1);

	float pos[3];
	pos[0] = pack.ReadFloat() + Cosine(dir) * length;
	pos[1] = pack.ReadFloat() + Sine(dir) * length;
	pos[2] = pack.ReadFloat();

	if (IsValidPlayer(client) && GetGameState() == 4) {
		SDKCall(fCreateRocket, client, "grenade_m79_smoke", pos, DOWN_VECTOR);
		if (shells > 1) {
			CreateTimer(0.05 + GetURandomFloat() + GetURandomFloat(), Timer_LaunchM203, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		else CreateTimer(0.1, Timer_DataPackExpire, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	}
	else CreateTimer(0.1, Timer_DataPackExpire, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	return Plugin_Handled;
}

public Action Timer_BotLaunchSoundM777(Handle timer)
{
	if (g_iM777ShellCount > 0 && g_fLaunchSoundTime > GetGameTime() && GetGameState() == 4)
	{
		g_iM777ShellCount--;
		char sSoundFile[128];
		Format(sSoundFile, sizeof(sSoundFile), "m777/m777launch/distant_rocket_artillery_fire_0%d.ogg", GetRandomInt(1, 4)); // total 4 voices
		EmitSoundToAll(sSoundFile, _, SNDCHAN_STATIC, _, _, 1.0); //SNDCHAN_AUTO SNDCHAN_STATIC
		CreateTimer(0.2 + GetURandomFloat(), Timer_BotLaunchSoundM777, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Handled;
}

public Action Timer_BotLaunchM777(Handle timer, DataPack pack)
{
	float dir = GetURandomFloat() * MATH_PI * 8.0;	// not 2π for good result
	float length = GetURandomFloat() * gCvarBotM777MaxSpread.FloatValue / 0.01905; //in meter

	pack.Reset();
	int client = pack.ReadCell();

	DataPackPos cursor = pack.Position;
	int shells = pack.ReadCell();
	pack.Position = cursor;
	pack.WriteCell(shells - 1);

	float pos[3];
	pos[0] = pack.ReadFloat() + Cosine(dir) * length;
	pos[1] = pack.ReadFloat() + Sine(dir) * length;
	pos[2] = pack.ReadFloat();

	if (IsValidPlayer(client) && GetGameState() == 4) {
		SDKCall(fCreateRocket, client, "grenade_m777", pos, DOWN_VECTOR);
		if (shells > 1) {
			CreateTimer(0.5 + GetURandomFloat(), Timer_BotLaunchM777, pack, TIMER_FLAG_NO_MAPCHANGE);
			if (IsOdd(shells) || shells==3) PlayIncomingEffect();
		}
		else CreateTimer(0.1, Timer_DataPackExpire, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	}
	else CreateTimer(0.1, Timer_DataPackExpire, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	return Plugin_Handled;
	//Format(sSoundFile, sizeof(sSoundFile), "m777/incomingeffect/incomingeffect%d.ogg", GetRandomInt(1, 12)); // total 12 voices
}

public Action Timer_BotLaunchF18(Handle timer, DataPack pack)
{
	float dir = GetURandomFloat() * MATH_PI * 8.0;	// not 2π for good result
	float length = GetURandomFloat() * 0.1 / 0.01905; //in meter

	pack.Reset();
	int client = pack.ReadCell();

	DataPackPos cursor = pack.Position;
	int shells = pack.ReadCell();
	pack.Position = cursor;
	pack.WriteCell(shells - 1);

	float pos[3];
	pos[0] = pack.ReadFloat() + Cosine(dir) * length;
	pos[1] = pack.ReadFloat() + Sine(dir) * length;
	pos[2] = pack.ReadFloat();

	if (IsValidPlayer(client) && GetGameState() == 4) {
		SDKCall(fCreateRocket, client, "grenade_f18", pos, DOWN_VECTOR);
		if (shells > 1) {
			CreateTimer(0.2, Timer_BotLaunchF18, pack, TIMER_FLAG_NO_MAPCHANGE);
			//if (IsOdd(shells) || shells==3) PlayIncomingEffect();
		}
		else CreateTimer(0.1, Timer_DataPackExpire, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	}
	else CreateTimer(0.1, Timer_DataPackExpire, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	return Plugin_Handled;
}

public void PlayIncomingEffect()
{
	char sSoundFile[128];
	Format(sSoundFile, sizeof(sSoundFile), "m777/incomingeffect/incomingeffect%d.ogg", GetRandomInt(1, 12)); // total 12 voices
	for (int i = 1; i < MaxClients+1; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			ClientCommand(i, "play %s", sSoundFile);
		}
	}
}

public Action Timer_BotLaunchNapalm(Handle timer, DataPack pack) {
	float dir = GetURandomFloat() * MATH_PI * 8.0;	// not 2π for good result
	float length = GetURandomFloat() * gCvarBotM777MaxSpread.FloatValue / 0.01905; //in meter

	pack.Reset();
	int client = pack.ReadCell();

	DataPackPos cursor = pack.Position;
	int shells = pack.ReadCell();
	pack.Position = cursor;
	pack.WriteCell(shells - 1);

	float pos[3];
	pos[0] = pack.ReadFloat() + Cosine(dir) * length;
	pos[1] = pack.ReadFloat() + Sine(dir) * length;
	pos[2] = pack.ReadFloat();

	if (IsValidPlayer(client) && GetGameState() == 4) {
		SDKCall(fCreateRocket, client, "grenade_m79_napalm", pos, DOWN_VECTOR);
		if (shells > 1) {
			CreateTimer(0.05, Timer_BotLaunchNapalm, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		else CreateTimer(0.1, Timer_DataPackExpire, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	}
	else CreateTimer(0.1, Timer_DataPackExpire, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	return Plugin_Handled;
}

public Action Timer_BotLaunchSarinGas(Handle timer, DataPack pack) {
	float dir = GetURandomFloat() * MATH_PI * 8.0;	// not 2π for good result
	float length = GetURandomFloat() * (gCvarBotM777MaxSpread.FloatValue+5.0) / 0.01905; //in meter

	pack.Reset();
	int client = pack.ReadCell();

	DataPackPos cursor = pack.Position;
	int shells = pack.ReadCell();
	pack.Position = cursor;
	pack.WriteCell(shells - 1);

	float pos[3];
	pos[0] = pack.ReadFloat() + Cosine(dir) * length;
	pos[1] = pack.ReadFloat() + Sine(dir) * length;
	pos[2] = pack.ReadFloat();

	if (IsValidPlayer(client) && GetGameState() == 4) {
		SDKCall(fCreateRocket, client, "grenade_sarin_fs", pos, DOWN_VECTOR);
		if (shells > 1) {
			CreateTimer(0.05, Timer_BotLaunchSarinGas, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		else CreateTimer(0.1, Timer_DataPackExpire, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	}
	else CreateTimer(0.1, Timer_DataPackExpire, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	return Plugin_Handled;
}

public Action Timer_DataPackExpire(Handle timer, DataPack pack) {
	return Plugin_Handled;
}

/// UTILS
bool GetAimGround(int client, float vec[3]) {
	float pos[3];
	float dir[3];
	GetClientEyePosition(client, pos);
	GetClientEyeAngles(client, dir);
	Handle ray = TR_TraceRayFilterEx(pos, dir, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceWorldOnly, client);

	if (TR_DidHit(ray)) {
		TR_GetEndPosition(pos, ray);
		CloseHandle(ray);

		ray = TR_TraceRayFilterEx(pos, DOWN_VECTOR, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceWorldOnly, client);
		if (TR_DidHit(ray)) {
			TR_GetEndPosition(vec, ray);
			CloseHandle(ray);
			return true;
		}
	}

	CloseHandle(ray);
	return false;
}

bool GetSkyPos(int client, float pos[3], float vec[3]) {
	Handle ray = TR_TraceRayFilterEx(pos, UP_VECTOR, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceWorldOnly, client);

	if (TR_DidHit(ray)) {
		char surface[64];
		TR_GetSurfaceName(ray, surface, sizeof(surface));
		if (StrContains(surface, "TOOLS/TOOLSSKYBOX", false) != -1) {
			TR_GetEndPosition(vec, ray);
			CloseHandle(ray);
			return true;
		}
	}
	CloseHandle(ray);
	return false;
}

public bool TraceWorldOnly(int entity, int mask, any data) {
	if(entity == data || entity > 0)
		return false;
	return true;
}

public void PrecacheSound_m777()
{
	PrecacheSound("weapons/nam/napalm/burn.wav");
	PrecacheSoundNumbers("m777/m777launch/distant_rocket_artillery_fire_0", ".ogg", 1, 4, false);
	PrecacheSoundNumbers("m777/incoming/incoming", ".ogg", 1, 29, false);
	PrecacheSoundNumbers("m777/incomingeffect/incomingeffect", ".ogg", 1, 12, false);
	PrecacheSoundNumbers("m777/invalid/invalidtarget", ".ogg", 1, 10, false);
	PrecacheSoundNumbers("m777/notready/notready", ".ogg", 1, 13, false);
	PrecacheSoundNumbers("m777/ready/artilleryready", ".ogg", 1, 10, false);
	PrecacheSoundNumbers("m777/requestartillery/requestartillery", ".ogg", 1, 28, false);
	PrecacheSoundNumbers("m777/requestsmoke/requestsmokeartillery", ".ogg", 1, 30, false);
}

void PrecacheSoundNumbers(const char[] soundprefix, const char[] soundpost, int number_begin, int number_end, bool zeroforlownumber = false)
{
	char soundfileformat[512];
	for (int i = number_begin;i <= number_end;i++)
	{
		if (zeroforlownumber && i < 10 && i > -1)
			Format(soundfileformat, sizeof(soundfileformat), "%s0%d%s", soundprefix, i, soundpost);
		else
			Format(soundfileformat, sizeof(soundfileformat), "%s%d%s", soundprefix, i, soundpost);
		PrecacheSound(soundfileformat);
		//PrintToServer("Precached Sound: %s", soundfileformat);
	}
	return;
}

// Get random alive player
stock int GetRandomPlayer(int team)
{
	int[] clients = new int[MaxClients];
	int clientCount;

	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
	{
		if ((GetClientTeam(i) == team) && IsPlayerAlive(i))
		{
			clients[clientCount++] = i;
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

stock int GetRandomTarget(int team, int exclude = 0)
{
	float pos[3];
	float sky[3];
	int[] clients = new int[MaxClients];
	int clientCount;

	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
	{
		if ((GetClientTeam(i) == team) && IsPlayerAlive(i) && i != exclude)
		{
			GetClientAbsOrigin(i, pos);
			if (GetSkyPos(i, pos, sky))
			{
				clients[clientCount++] = i;
			}
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

stock int MGetRandomInt(int min, int max)
{
	int random = GetURandomInt();

	if (random == 0) {
		random++;
	}
	return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}

stock float MGetRandomFloat(float min, float max)
{
	return (GetURandomFloat() * (max  - min)) + min;
}

stock bool IsOdd(int num)
{
    return (num & 1) == 1;
}

stock bool IsEven(int num)
{
    return num % 2 == 0;
} 

bool IsCounterAttack()
{
	if (!g_bIsCheckpointMode) return false;
	else return view_as<bool>(GameRules_GetProp("m_bCounterAttack")); //result int = 0 or 1
}

int GetGameState()
{
	return GameRules_GetProp("m_iGameState");
}

public bool IsValidPlayer(int client) {
	return (0 < client <= MaxClients) && IsClientInGame(client);
}
