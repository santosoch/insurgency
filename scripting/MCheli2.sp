#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <define_heli>
#undef REQUIRE_PLUGIN
#include <gameme>
#define REQUIRE_PLUGIN
#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Helicopter",
	author = "Pan Xiaohai - Mod by SilverShot - fs by rrrfffrrr - INS compatiability by Bot Chris",
	description = "Attack Heli",
	version = "2.0",
	url = ""
}

//gameME callback
#define QUERY_TYPE_OTHER 0
#define QUERY_TYPE_ONCLIENTPUTINSERVER 1

#define LEN64 64
#define PARTICLE_MUZZLE_FLASH		"muzzleflash_m249_1p" //"ins_weapon_rpg_frontblast" "ins_weapon_at4_frontblast"
//#define PARTICLE_BLOOD				"blood_impact_red_01_goop"
#define SOUND_ENGINE				"vehicles/airboat/fan_blade_fullthrottle_loop1.wav" //fan_blade_fullthrottle_loop1.wav fan_blade_idle_loop1.wav
#define SOUND_SHOT					"weapons/mk18/mk18_tp.wav"
#define MODEL_HELICOPTER			"models/vehicles/aircraft_uh1.mdl"

ConVar cvheli_size;
ConVar cvheli_gun_accuracy;
ConVar cvheli_gun_damage;
ConVar cvheli_speed;
ConVar cvheli_fuel;
ConVar cvheli_bullet;
ConVar cvheli_hellfire;
ConVar cvheli_usage_limit;
ConVar cvheli_pilotclass;
ConVar cvheli_cooldowntimer;
float UP_VECTOR[3] = {-90.0, 0.0, 0.0};

// new g_sprite;
int g_iVelocity;

int MaxUsage[MAXPLAYERS+1];
int LastButton[MAXPLAYERS+1];
float LastTime[MAXPLAYERS+1];

int DummyEnt[MAXPLAYERS+1];
int HelicopterEnt[MAXPLAYERS+1];
int HelicopterEnt_other[MAXPLAYERS+1];
float Pitch[MAXPLAYERS+1];
float Roll[MAXPLAYERS+1];

float Gravity[MAXPLAYERS+1];
float Fuel[MAXPLAYERS+1];
float LastPos[MAXPLAYERS+1][3];
float MaxSpeed[MAXPLAYERS+1];

int Bullet[MAXPLAYERS+1];
float ShotTime[MAXPLAYERS+1];

//1=bullet, 3=fuel
int Info[MAXPLAYERS+1][4];


Handle cGameConfig;
Handle g_hPlayerRespawn = INVALID_HANDLE;
Handle fCreateRocket;
float g_fRocketTime[MAXPLAYERS+1];
bool g_IsPilot[MAXPLAYERS + 1];
int g_iHellfireCount[MAXPLAYERS + 1];
int g_iHeliTime;
bool g_bIsAlone;
int g_iTotalHeli;
bool g_bUpdatedSpawnPoint = false;

//gameme
bool g_bGameme;
int g_iSkill[MAXPLAYERS+1] = {-1, ...};

//bullet tracer
int g_iTargetRef[MAXPLAYERS+1];
int g_iGunfireRef[MAXPLAYERS+1];

//HALO
int g_iBeaconBeam;
int	g_iBeaconHalo;

//ThirdView
ConVar g_cvThirdPerson;
bool g_bThirdView[MAXPLAYERS+1];
int ga_iSetting[MAXPLAYERS+1];

public void OnPluginStart()
{
	if (!(g_cvThirdPerson = FindConVar("sv_thirdperson"))) {
		SetFailState("Couldn't find 'sv_thirdperson'!");
	}
	LoadTranslations("common.phrases");
	cGameConfig = LoadGameConfigFile("insurgency.games");
	if (cGameConfig == INVALID_HANDLE) {
		SetFailState("Fatal Error: Missing File \"insurgency.games\"!");
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(cGameConfig, SDKConf_Signature, "ForceRespawn");
	g_hPlayerRespawn = EndPrepSDKCall();

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

	cvheli_size = CreateConVar("heli_size", "2.5", "helicopter's size");
	cvheli_speed = CreateConVar("heli_speed", "400", "fly speed  [100.0, 500.0]");
	cvheli_gun_accuracy = CreateConVar("heli_gun_accuracy", "0.8", "gun's Accuracy [0.0, 1.5]");
	cvheli_gun_damage = CreateConVar("heli_gun_damage", "5000", "damage of the gun  [1.0, 100.0]");
	cvheli_usage_limit = CreateConVar("heli_usage_limit", "500", "amount of times the user can create a helicopter per map");
	cvheli_fuel = CreateConVar("heli_fuel", "120", "seconds");
	cvheli_bullet = CreateConVar("heli_bullet", "1000", "bullet count");
	cvheli_hellfire = CreateConVar("heli_hellfire", "8", "hellfire rocket count");
	cvheli_pilotclass = CreateConVar("heli_pilotclass", "pilot", "classname pilot");
	cvheli_cooldowntimer = CreateConVar("heli_cooldowntimer", "480", "global heli cooldown timer");

	HookEvent("player_pick_squad", Event_PlayerPickSquad_Post, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", player_death);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("weapon_ironsight", Event_WeaponIronsight, EventHookMode_Pre);
	HookEvent("weapon_lower_sight", Event_WeaponLowerSight, EventHookMode_Pre);
	AddNormalSoundHook(SoundHook);

	RegConsoleCmd("tp", cmd_thirdPerson, "Set your view to third person");
	RegConsoleCmd("tpp", cmd_thirdPersonMenu, "Set your view to third person");
	RegConsoleCmd("mcheli", Cmd_Heli);
	ResetAllState();
	g_iVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
}

public void OnLibraryAdded(const char[] szLibrary)
{
	if (StrEqual(szLibrary, "gameme")) g_bGameme = true;
}

public void OnLibraryRemoved(const char[] szLibrary)
{
	if (StrEqual(szLibrary, "gameme")) g_bGameme = false;
}

public void OnAllPluginsLoaded()
{
	g_bGameme = LibraryExists("gameme");
}

public void OnMapStart()
{
	g_bIsAlone = false;
	g_iTotalHeli = 0;
	g_bUpdatedSpawnPoint = false;
	PrecacheModel(MODEL_HELICOPTER);
	PrecacheSound(SOUND_ENGINE, true);
	PrecacheSound(SOUND_SHOT, true);
	PrecacheSound("weapons/m16A4/M16A4_tp.wav", true);
	PrecacheParticle(PARTICLE_MUZZLE_FLASH);
	//PrecacheParticle(PARTICLE_BLOOD);
	g_iBeaconBeam = PrecacheModel("sprites/laserbeam.vmt");
	g_iBeaconHalo = PrecacheModel("sprites/glow01.vmt");
	CreateTimer(0.1, Timer_UpdatedSpawnPoint, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.1, Timer_ThinkTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	ResetAllState();
}

Action Timer_ThinkTimer(Handle timer) {
	if (!g_bUpdatedSpawnPoint || GetGameState() != 4) return Plugin_Continue;

	int iPlayerCount = 0;
	int iHeliCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i)) continue;
		iPlayerCount++;
		if (DummyEnt[i] > 0) iHeliCount++;
		if (iPlayerCount > 1 && iHeliCount > 1) break;
	}
	g_iTotalHeli = iHeliCount;
	g_bIsAlone = (iPlayerCount <= 1);
	return Plugin_Continue;
}

Action Timer_UpdatedSpawnPoint(Handle timer) {
	if (!g_bUpdatedSpawnPoint && GetGameState() == 4 && GetRoundTime() > 500.0)
	{
		g_bUpdatedSpawnPoint = true;
		KillTimer(timer);
		return Plugin_Handled;
	}
	//PrintToChatAll("Timer_UpdatedSpawnPoint");
	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	ResetClientState(client);
	MaxUsage[client]=0;
	g_bThirdView[client] = false;
	ga_iSetting[client] = 4;
}

public void OnClientPostAdminCheck(int client)
{
/*	if (0 < client <= MaxClients)
	{
		g_iSkill[client] = -1;
		if (!IsFakeClient(client)) GetGameme(client);
	}	*/
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetAllState();
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	RemoveHelicopterAll();
	ResetAllState();
}

public Action Event_PlayerPickSquad_Post(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	char template[64];
	event.GetString("class_template", template, sizeof(template), "");
	char class[64];
	GetConVarString(cvheli_pilotclass, class, 64);

	g_IsPilot[client] = (StrContains(template, class, false) > -1);

	if (cvheli_fuel.FloatValue <= 0.0) return Plugin_Continue;

	if (!g_IsPilot[client] && DummyEnt[client]>0)
		RemoveHelicopter(client);

	if (g_IsPilot[client] || g_iSkill[client] >= 1000000)
	{
		//if (cvheli_fuel.FloatValue <= 0.0) PrintToChat(client, "\x0700FA9AHelicopter\x01 is\x07FF4500 DISABLED.");
		PrintToChat(client, "\x07F8F8FFYou can spawn\x07FFD700 Heli\x07F8F8FF with command:\x0700FA9A mcheli \nSHIFT-F\x07F8F8FF to Exit Heli");
	}
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event hEvent, const char[] strName, bool DontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	ResetClientState(client);
	if (!IsClientInGame(client) || IsFakeClient(client)) return Plugin_Continue;

	if (g_bThirdView[client]) SetPlayerView(client, g_bThirdView[client]);
	return Plugin_Continue;
}

public Action player_death(Event hEvent, const char[] strName, bool DontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	LostControl(client);
	ResetClientState(client);

	if (!IsClientInGame(client) || IsFakeClient(client)) return Plugin_Continue;

	SetPlayerView(client, false);
	return Plugin_Continue;
}

public Action Event_WeaponIronsight(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsClientInGame(client) || IsFakeClient(client) || !g_bThirdView[client] || DummyEnt[client]>0) {
		return Plugin_Continue;
	}
	ClientCommand(client, "r_screenoverlay null");
	SendConVarValue(client, g_cvThirdPerson, "0");
	return Plugin_Continue;
}

public Action Event_WeaponLowerSight(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsClientInGame(client) || IsFakeClient(client) || !g_bThirdView[client] || DummyEnt[client]>0) {
		return Plugin_Continue;
	}
	SetPlayerView(client, g_bThirdView[client]);
	return Plugin_Continue;
}

public Action SoundHook(int clients[64], int &numClients, char sound[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags) 
{
	if (entity > MaxClients+1 && IsValidEntity(entity))
	{
		char classname[32];
		GetEntityClassname(entity, classname, 32);
		if (StrEqual(classname, "env_gunfire"))
		{
			flags |= SND_STOP;
			return Plugin_Handled;
		}
	}
	else if (IsValidPlayer(entity) && DummyEnt[entity] > 0 && StrContains(sound, "coop/rpg", false) != -1) return Plugin_Handled;

	return Plugin_Continue;
}

// Debug
/*
int MAX_BUTTONS = 32;
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	for (int i = 0; i < MAX_BUTTONS; i++)
	{
		int button = (1 << i);
		if ((buttons & button))
		{
			PrintToChat(client, "BUTTON: %i = (1 << %i)\n", button, i);
		}
	}
	return Plugin_Continue;
}
*/

public Action cmd_thirdPerson(int client, int args) {
	if (client <= 0 || !IsClientInGame(client) || GetClientTeam(client) != 2 || DummyEnt[client] > 0) {
		return Plugin_Handled;
	}
	if (!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "You must be alive.");
		return Plugin_Handled;
	}
	g_bThirdView[client] = !g_bThirdView[client];
	SetPlayerView(client, g_bThirdView[client]);
	return Plugin_Handled;
}

public Action cmd_thirdPersonMenu(int client, int args) {
	if (client < 1 || !IsClientInGame(client) || GetClientTeam(client) != 2 || DummyEnt[client] > 0) {
		return Plugin_Handled;
	}
	if (!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "You must be alive.");
		return Plugin_Handled;
	}
	TpMenuSetup(client);
	return Plugin_Handled;
}

void TpMenuSetup (int client) {
	Menu menu = new Menu(Handle_TpMenu);
	menu.SetTitle("Third Person Options");
	menu.AddItem("0", "off", (!g_bThirdView[client]) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("1", "on (without crosshair)", (g_bThirdView[client] && ga_iSetting[client] == 1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("2", "dot: red small", (g_bThirdView[client] && ga_iSetting[client] == 2) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("3", "dot: red medium", (g_bThirdView[client] && ga_iSetting[client] == 3) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("4", "dot: red large", (g_bThirdView[client] && ga_iSetting[client] == 4) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("5", "dot: blue small", (g_bThirdView[client] && ga_iSetting[client] == 5) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("6", "dot: blue medium", (g_bThirdView[client] && ga_iSetting[client] == 6) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("7", "dot: blue large", (g_bThirdView[client] && ga_iSetting[client] == 7) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.Display(client, 15);
}

public int Handle_TpMenu(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			if (param2 != 0) g_bThirdView[param1] = true;
			else g_bThirdView[param1] = false;

			ga_iSetting[param1] = param2;
			switch (param2) {
				case 0: ReplyToCommand(param1, "third person off");
				case 1: ReplyToCommand(param1, "third person on (without crosshair)");
				case 2: ReplyToCommand(param1, "crosshair set to: red dot small");
				case 3: ReplyToCommand(param1, "crosshair set to: red dot medium");
				case 4: ReplyToCommand(param1, "crosshair set to: red dot large");
				case 5: ReplyToCommand(param1, "crosshair set to: blue dot small");
				case 6: ReplyToCommand(param1, "crosshair set to: blue dot medium");
				case 7: ReplyToCommand(param1, "crosshair set to: blue dot large");
			}
			SetPlayerView(param1, g_bThirdView[param1]);
		}
		case MenuAction_End: {
			delete menu;
		}
	}
}

void SetPlayerView(int client, bool Set3rdView)
{
	char sModel[64];
	if (Set3rdView) {
		switch (ga_iSetting[client]) {
			case 1: sModel = "null";
			case 2: sModel = "thirdperson/crosshair/dot/red_small.vtf";
			case 3: sModel = "thirdperson/crosshair/dot/red_medium.vtf";
			case 4: sModel = "thirdperson/crosshair/dot/red_large.vtf";
			case 5: sModel = "thirdperson/crosshair/dot/blue_small.vtf";
			case 6: sModel = "thirdperson/crosshair/dot/blue_medium.vtf";
			case 7: sModel = "thirdperson/crosshair/dot/blue_large.vtf";
			default: sModel = "thirdperson/crosshair/dot/red_large.vtf";
		}
		SendConVarValue(client, g_cvThirdPerson, "1");
		ClientCommand(client, "r_screenoverlay %s", sModel);
	}
	else {
		ClientCommand(client, "r_screenoverlay null");
		SendConVarValue(client, g_cvThirdPerson, "0");
	}
}

public Action Cmd_Heli(int client, int args)
{
	if (cvheli_fuel.FloatValue <= 0.0)
	{
		PrintToChat(client, "\x0700FA9AHelicopter\x01 is\x07FF4500 DISABLED.");
		return Plugin_Handled;
	}
	if (client>0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		if (DummyEnt[client]>0)
		{
			RemoveHelicopter(client);
		}
		else
		{
			if (g_iTotalHeli > 1)
			{
				PrintToChat(client, "\x07F8F8FFMax Spawned Heli:\x0700FA9A 2\x07FFD700, please try again later");
				return Plugin_Handled;
			}

			if (!g_IsPilot[client] && g_iSkill[client] < 1000000)
			{
				PrintToChat(client, "\x07F8F8FFYou are not qualified to fly \x0700FA9A Heli");
				return Plugin_Handled;
			}

			int iTime = GetTime();
			if ((g_IsPilot[client] && iTime-g_iHeliTime < cvheli_cooldowntimer.IntValue))
			{
				if (g_iHeliTime > 0) PrintToChat(client, "\x07FF4500Attack Heli\x01 on cooldown\x0700FA9A %d\x01 secs", cvheli_cooldowntimer.IntValue-(iTime-g_iHeliTime));
				return Plugin_Handled;
			}

			float pos[3];
			GetClientAbsOrigin(client, pos);
			if (!GetSkyPos(client, pos))
			{
				PrintToChat(client, "\x07F8F8FFCan't spawn Attack Heli\x07FF00FF here.");
				return Plugin_Handled;
			}
			SetEntProp(client, Prop_Send, "m_iCurrentStance", 0);
			CreateHelicopter(client, -1);
		}
	}
	return Plugin_Handled;
}

void CreateHelicopter(int client, int infoIndex)
{
	if (!g_bUpdatedSpawnPoint || GetGameState() != 4) return;
	//if (GetGameState() != 4) return;
	
	if (DummyEnt[client] > 0)
		RemoveHelicopter(client);

	// We hit the max usage?
	if (MaxUsage[client] >= cvheli_usage_limit.IntValue)
	{
		PrintToChat(client, "You have reached the maximum of usages of %d for this map!", cvheli_usage_limit.IntValue);
		return;
	}
	if (g_iSkill[client] >= 1000000 && !g_IsPilot[client] && MaxUsage[client] > 0)
	{
		PrintToChat(client, "You have reached the maximum of usages for this map!");
		return;
	}

	char sMessage[128];
	FormatEx(sMessage, 128, "[Heli] %N has spawned Bell UH-1 Iroquois Huey Gunship", client);
	ServerCommand("discordmsg %s", sMessage);
	PrintToChatAll("\x07FF4500Huey Gunship\x01 support\x0700FA9A has arrived \x01(\x07FFD700%N\x01)", client);

	// Increase usage
	MaxUsage[client]++;
	g_iHellfireCount[client] = 0;
	g_iTargetRef[client] = 0;
	g_iGunfireRef[client] = 0;
	if (g_IsPilot[client]) g_iHeliTime = GetTime();
	SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	RemoveWeapons(client);

	float modelScale = cvheli_size.FloatValue;
/*	if (modelScale < 1.0)
		modelScale = 1.0;	*/

	if (IsValidPlayer(client))
	{
		float ang[3];
		float pos_old[3];
		float pos[3];

		GetClientAbsOrigin(client, pos_old);

		// Move it up a bit
		pos_old[2] += 2.0;

		// Set new pos
		SetEntPropFloat(client, Prop_Send, "m_flModelScale", 0.1);
		TeleportEntity(client, pos_old, NULL_VECTOR, NULL_VECTOR);

		GetClientAbsAngles(client, ang);
		GetClientAbsOrigin(client, pos);
		ang[0]=0.0;

		int ment=CreateEntityByName("prop_dynamic");
		DispatchKeyValue(ment, "model", MODEL_HELICOPTER);
		SetEntProp(ment, Prop_Data, "m_CollisionGroup", 2);
		SetEntPropFloat(ment, Prop_Send, "m_flModelScale", modelScale);

		DispatchSpawn(ment);

		char tname[20];
		Format(tname, 20, "target%d", client);
		DispatchKeyValue(client, "targetname", tname);

		SetVariantString(tname);
		AcceptEntityInput(ment, "SetParent",ment, ment, 0);

		SetVector(pos, -0.0, 0.0, 2.5);
		TeleportEntity(ment, pos, NULL_VECTOR, NULL_VECTOR);

		//SetEntPropVector(ment, Prop_Send, "m_angRotation", ang);

//		DispatchKeyValueFloat(ment, "fademindist", 10000.0);
//		DispatchKeyValueFloat(ment, "fademaxdist", 20000.0);
//		DispatchKeyValueFloat(ment, "fadescale", 0.0);

		//SetVariantString("3ready");//3ready
		//AcceptEntityInput(ment, "SetAnimation");
		SetEntPropFloat(ment, Prop_Send, "m_flPlaybackRate" ,0.3);

		SetEntityMoveType(ment, MOVETYPE_NONE);

		VisiblePlayer(client,false);
		GotoThirdPerson(client,true);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
		DummyEnt[client]=ment;
		HelicopterEnt[client]=ment;
		HelicopterEnt_other[client]=CreateModel(client);
		MaxSpeed[client]=cvheli_speed.FloatValue;
		Pitch[client]=0.0;
		Roll[client]=0.0;
		EmitSoundToAll(SOUND_ENGINE, ment, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.6, SNDPITCH_NORMAL, -1, pos, NULL_VECTOR, true, 0.0);

		LastTime[client]=GetEngineTime();
		LastButton[client]=0;
		GetClientAbsOrigin(client, LastPos[client]);
		if (g_bThirdView[client]) SetPlayerView(client, false);
		ClientCommand(client, "r_screenoverlay thirdperson/crosshair/dot/red_large.vtf");

		if (infoIndex<0)
		{
			Fuel[client]=cvheli_fuel.FloatValue;
			Bullet[client]=cvheli_bullet.IntValue;
		}
		else
		{
			Bullet[client]=Info[infoIndex][1];
			Fuel[client]=Info[infoIndex][3]*1.0;
		}

		ShotTime[client]=0.0;
		g_fRocketTime[client]=0.0;

		SDKUnhook(client, SDKHook_PreThink,  PreThink);
		SDKHook(client, SDKHook_PreThink,  PreThink);

		SDKUnhook(client, SDKHook_PostThinkPost,  PostThinkPost);
		SDKHook(client, SDKHook_PostThinkPost,  PostThinkPost);

		SDKUnhook(client, SDKHook_SetTransmit,  OnSetTransmitClient);
		//SDKHook(client, SDKHook_SetTransmit, OnSetTransmitClient);

		SDKUnhook(HelicopterEnt[client], SDKHook_SetTransmit,  OnSetTransmitModel);
		SDKHook(HelicopterEnt[client], SDKHook_SetTransmit, OnSetTransmitModel);

		SDKUnhook(HelicopterEnt_other[client], SDKHook_SetTransmit,  OnSetTransmitModel_Other);
		SDKHook(HelicopterEnt_other[client], SDKHook_SetTransmit, OnSetTransmitModel_Other);
	}
}

int CreateModel(int client)
{
	float modelScale = cvheli_size.FloatValue;
/*	if (modelScale < 1.0)
		modelScale = 1.0;	*/

	float ang[3];
	float pos[3];

	int ment=CreateEntityByName("prop_dynamic");
	DispatchKeyValue(ment, "model", MODEL_HELICOPTER);
	SetEntProp(ment, Prop_Data, "m_CollisionGroup", 2);
	SetEntPropFloat(ment, Prop_Send, "m_flModelScale", modelScale);

	DispatchSpawn(ment);
	char tname[20];
	Format(tname, 20, "target%d", client);
	DispatchKeyValue(client, "targetname", tname);
	SetVariantString(tname);
	AcceptEntityInput(ment, "SetParent",ment, ment, 0);

	SetVector(pos, -0.0, 0.0, 2.5); //front, up
	SetVector(ang,  0.0, 0.0, 0.0);
	TeleportEntity(ment, pos, NULL_VECTOR,NULL_VECTOR);

	SetEntPropVector(ment, Prop_Send, "m_angRotation", ang);

	DispatchKeyValueFloat(ment, "fademindist", 10000.0);
	DispatchKeyValueFloat(ment, "fademaxdist", 20000.0);
	DispatchKeyValueFloat(ment, "fadescale", 0.0);

	//SetVariantString("3ready");//3ready
	//AcceptEntityInput(ment, "SetAnimation");
	SetEntPropFloat(ment, Prop_Send, "m_flPlaybackRate" ,0.3);
	SetEntityMoveType(ment, MOVETYPE_NOCLIP);


	return ment;
}

void RemoveHelicopter(int client)
{
	if (client>0 && DummyEnt[client]>0)
	{
		// You were resetting stuff on the client that shouldn't be reset unless they were in a helicopter. Hence the spectator cannot move bug
		if (IsClientInGame(client))
		{
			SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.0);
			SDKUnhook(client, SDKHook_SetTransmit,  OnSetTransmitClient);
			SDKUnhook(client, SDKHook_PostThinkPost,  PostThinkPost);
			SDKUnhook(client, SDKHook_PreThink,  PreThink);
			GotoThirdPerson(client, false);
			VisiblePlayer(client, true);
			SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
			SetEntityMoveType(client, MOVETYPE_WALK);
			SetEntityGravity(client, 1.0);
			SetEntProp(client, Prop_Send, "m_iHideHUD", 2048);
			SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);

			//int weapon= GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
			//if (weapon>0) SetEntPropFloat(weapon, Prop_Data, "m_flNextPrimaryAttack", GetGameTime());
			if (g_IsPilot[client]) g_iHeliTime = GetTime();
			PrintCenterText(client, " ");
			if (IsPlayerAlive(client)) SetPlayerView(client, g_bThirdView[client]);
		}

		StopSound(DummyEnt[client], SNDCHAN_AUTO,SOUND_ENGINE);
		StopSound(HelicopterEnt[client], SNDCHAN_AUTO,SOUND_ENGINE);

		if (IsValidEnt(HelicopterEnt[client]))
		{
			SDKUnhook(HelicopterEnt[client], SDKHook_SetTransmit,  OnSetTransmitModel);
			AcceptEntityInput(HelicopterEnt[client], "kill");
		}
		if (IsValidEnt(HelicopterEnt_other[client]))
		{
			SDKUnhook(HelicopterEnt_other[client], SDKHook_SetTransmit,  OnSetTransmitModel_Other);
			AcceptEntityInput(HelicopterEnt_other[client], "kill");
		}
		if (IsValidEnt(DummyEnt[client]))
		{
			AcceptEntityInput(DummyEnt[client], "ClearParent");
			AcceptEntityInput(DummyEnt[client], "kill");
		}
		//RESPAWN PLAYER
		if (IsPlayerAlive(client))
		{
			float ang[3], pos[3];
			GetClientAbsAngles(client, ang);
			GetClientAbsOrigin(client, pos);
			SDKCall(g_hPlayerRespawn, client);
			TeleportEntity(client, pos, ang, NULL_VECTOR);
		}
 	}
	DummyEnt[client]=0;
	HelicopterEnt[client]=0;
	HelicopterEnt_other[client]=0;

	int gunfire = EntRefToEntIndex(g_iGunfireRef[client]);
	if(gunfire > MaxClients && IsValidEntity(gunfire)) {
		AcceptEntityInput(gunfire, "Kill");
		g_iGunfireRef[client] = 0;
	}
	int target = EntRefToEntIndex(g_iTargetRef[client]);
	if(target > MaxClients && IsValidEntity(target)) {
		AcceptEntityInput(target, "Kill");
		g_iTargetRef[client] = 0;
	}
}

void LostControl(int client)
{
	if (client>0 && DummyEnt[client]>0)
	{
		//PrintCenterText(client, "Lost control to the helicopter...");
		RemoveHelicopter(client);
	}
	SDKUnhook(client, SDKHook_PreThink,  PreThink);
	SDKUnhook(client, SDKHook_PostThinkPost,  PostThinkPost);
	SDKUnhook(client, SDKHook_SetTransmit,  OnSetTransmitClient);
}

public void PreThink(int client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		float time=GetEngineTime();
		float intervual=time-LastTime[client];
		if (intervual<0.01)intervual=0.01;
		else if (intervual>0.1)intervual=0.1;
		int button=GetClientButtons(client);
		Fly(client,button, intervual, time);
		LastTime[client]=time;
		LastButton[client]=button;
	}
	else
	{
		LostControl(client);
	}
}

public void PostThinkPost(int client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && DummyEnt[client]>0)
	{
		int button=GetClientButtons(client);
		if ((button & INS_USE) && (button & INS_SPRINT)) SetEntProp(client, Prop_Send, "m_iHideHUD",2048);
		else SetEntProp(client, Prop_Send, "m_iHideHUD", 64);

		SetEntProp(client, Prop_Send, "m_iAddonBits", 0);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
		SetEntityMoveType(client, MOVETYPE_FLYGRAVITY);

		int weapon= GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if (weapon>0) SetEntPropFloat(weapon, Prop_Data, "m_flNextPrimaryAttack", GetGameTime()+1.0);
	}

}

public Action OnSetTransmitClient(int polit, int client)
{
	//PrintToChatAll("%N client %d", client , polit);
	if (polit!=client)
	{
		return Plugin_Handled;
	}
	else return Plugin_Continue;
}

public Action OnSetTransmitModel(int model, int client)
{
	if (HelicopterEnt[client]==model)
	{
		 return Plugin_Continue;
	}
	else return Plugin_Handled;
}

public Action OnSetTransmitModel_Other(int model, int client)
{
	if (HelicopterEnt_other[client]!=model)
	{
		 return Plugin_Continue;
	}
	else return Plugin_Handled;
}

void Fly(int client, int button, float intervual, float time)
{
	int dummy=DummyEnt[client];
	int modelEnt=HelicopterEnt[client];
	if (!IsValidEnt(modelEnt)) return;

	int flag=GetEntityFlags(client);
	if (!g_bIsAlone) SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	else SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);

	float clientAngle[3];
	float modelAng[3];
 	GetEntPropVector(modelEnt, Prop_Send, "m_angRotation", modelAng);
 	GetClientEyeAngles(client, clientAngle);

	modelAng[0]=0.0;
	modelAng[1]=0.0;

	float clientPos[3];
	float temp[3];
	float volicity[3];
	float pushForce[3];
	float pushForceVertical[3];
	float liftForce=50.0;
	float speedLimit=MaxSpeed[client];
	float fuelUsed=intervual;
	float gravity=0.001;
	float gravityNormal=0.001;
	GetEntDataVector(client, g_iVelocity, volicity);

	GetClientAbsOrigin(client, clientPos);
	CopyVector(clientPos,LastPos[client]);
	clientAngle[0]=0.0;

	SetVector(pushForce, 0.0, 0.0, 0.0);
	SetVector(pushForceVertical, 0.0, 0.0,  0.0);
	bool up=false;
	bool down=false;
	bool speed=false;
	bool move=false;
	float pitch=0.0;
	float roll=0.0;

	if ((button & INS_JUMP))
	{
		SetVector(pushForceVertical, 0.0, 0.0, 1.5);
		up=true;

		if (gravity>0.0)gravity=-0.01;
		gravity=Gravity[client]-1.0*intervual;
	}

	if ((button & INS_DUCK) && !up)
	{
		SetVector(pushForceVertical, 0.0, 0.0, -2.0);
		down=true;
		if (gravity<0.0)gravity=0.01;
		gravity=Gravity[client]+1.0*intervual;
	}
	//PrintToChatAll("g %f %f ",Gravity[client], gravity);
	if (button & INS_FORWARD)
	{
		GetAngleVectors(clientAngle, temp, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(temp,temp);
		AddVectors(pushForce,temp,pushForce);
		move=true;
		pitch=1.0;

	}
	else if (button & INS_BACKWARD)
	{
		GetAngleVectors(clientAngle, temp, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(temp,temp);
		SubtractVectors(pushForce, temp, pushForce);
		move=true;
		pitch=-1.0;
	}
	if (button & INS_LEFT)
	{
		GetAngleVectors(clientAngle, NULL_VECTOR, temp, NULL_VECTOR);
		NormalizeVector(temp,temp);
		SubtractVectors(pushForce,temp,pushForce);
		move=true;
		roll=-1.0;
	}
	else if (button & INS_RIGHT)
	{
		GetAngleVectors(clientAngle, NULL_VECTOR, temp, NULL_VECTOR);
		NormalizeVector(temp,temp);
		AddVectors(pushForce,temp,pushForce);
		roll=1.0;
	}
	if ((button & INS_SPRINT))
	{
		speed=true;
	}

	if (move && up)
	{
		ScaleVector(pushForceVertical, 0.3);
		ScaleVector(pushForce, 1.5);
	}

	//NormalizeVector(pushForce, pushForce);
	if (speed || up || down)
	{
		fuelUsed*=3.0;
		speedLimit*=1.5;
		liftForce*=2.0;
	}

	AddVectors(pushForceVertical,pushForce,pushForce);
	NormalizeVector(pushForce, pushForce);
	//ShowDir(client, clientPos, pushForce, 0.06);
	//PrintToChatAll("v %f", GetVectorLength(volicity));
	ScaleVector(pushForce,liftForce*intervual);
	if (!(up || down) )
	{
		if (FloatAbs(volicity[2])>40.0)gravity=volicity[2]*intervual;
		else gravity=gravityNormal;
	}

	float v=GetVectorLength(volicity);
	if (gravity>0.5)gravity=0.5;
	if (gravity<-0.5)gravity=-0.5;
	if (speed && !(up || down))
	{
		volicity[2]*=0.8;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, volicity);
	}
	else if (v>speedLimit)
	{
		NormalizeVector(volicity,volicity);
		ScaleVector(volicity, speedLimit);
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, volicity);
	}
	SetEntityGravity(client, gravity);
	Gravity[client]=gravity;

	Fuel[client]-=fuelUsed;

	if (pitch==0.0)
	{
		if (Pitch[client]>0.0)pitch=-1.0;
		else if (Pitch[client]<0.0)pitch=1.0;
		else pitch=0.0;
		if (FloatAbs(Pitch[client])<5.0)
		{
			Pitch[client]=0.0;
			pitch=0.0;
		}
	}
	else
	{
		if (Pitch[client]>0.0 && pitch<0.0)pitch=-3.0;
		else if (Pitch[client]<0.0 && pitch>0.0)pitch=3.0;
	}
	Pitch[client]+=pitch*30.0*intervual;
	if (Pitch[client]>30.0)Pitch[client]=30.0;
	else if (Pitch[client]<-35.0)Pitch[client]=-35.0;

	if (roll==0.0)
	{
		if (Roll[client]>0.0)roll=-1.0;
		else if (Roll[client]<0.0)roll=1.0;
		else roll=0.0;
		if (FloatAbs(Roll[client])<5.0)
		{
			Roll[client]=0.0;
			roll=0.0;
		}
	}
	else
	{
		if (Roll[client]>0.0 && roll<0.0)roll=-3.0;
		else if (Roll[client]<0.0 && roll>0.0)roll=3.0;
	}
	Roll[client]+=roll*60.0*intervual;
	if (Roll[client]>35.0)Roll[client]=35.0;
	else if (Roll[client]<-35.0)Roll[client]=-35.0;

	bool shot1=false;
	if (button & INS_ATTACK1)
	{
		if (time>ShotTime[client])
		{
			ShotTime[client]=time+0.06;
			if (Bullet[client]>0)
			{
				shot1=true;
			}
		}
	}
	bool rocketshot = false;
	if (button & INS_SPECIAL1)
	{
		if (time>g_fRocketTime[client])
		{
			g_fRocketTime[client]=time+1.0;
			rocketshot=true;
		}
	}

	if (Fuel[client]<=0.0 || ((button & INS_USE) && (button & INS_SPRINT)))
	{
		LostControl(client);
		return;
	}

	if (flag & FL_ONGROUND)
	{
		//PrintToChatAll("FL_ONGROUND");
		/* if (Fuel[client]<=0.0)
		{
			LostControl(client);
			return;
		}	*/
		modelAng[2]=0.0;
		shot1=false;
		rocketshot = false;
		SetVector(volicity, 0.0, 0.0, 100.0);
		if (button & INS_JUMP)
		{
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, volicity);
			SetEntityGravity(client, -0.5);
		}
		else
		{
			SetEntityGravity(client, 1.0);
		}

	}
	else
	{
		modelAng[0]+=Pitch[client];
		modelAng[2]=Roll[client];
	}
	
	//PrintToChatAll("modelAng  %f", modelAng[0]);
	GetClientEyeAngles(client, clientAngle);

	float zero[3];
	SetVector(zero,  0.0, 0.0, 2.5);
	TeleportEntity(dummy , zero, zero, NULL_VECTOR);
	TeleportEntity(modelEnt , zero, zero, NULL_VECTOR);
	SetEntPropVector(modelEnt, Prop_Send, "m_angRotation", modelAng);
	if (HelicopterEnt_other[client]>0)
	{
		modelAng[0]=Pitch[client];
		modelAng[1]=clientAngle[1];
		TeleportEntity(HelicopterEnt_other[client] , zero, zero, NULL_VECTOR);
		SetEntPropVector(HelicopterEnt_other[client], Prop_Send, "m_angRotation", modelAng);
	}

	if (shot1)
	{
		Bullet[client]--;
		float clientEyePos[3];
		GetClientEyePosition(client, clientEyePos);
		Shot(client, clientPos,clientEyePos, clientAngle);
	}
	else if (rocketshot && cvheli_hellfire.IntValue-g_iHellfireCount[client] > 0)
	{
		float clientEyePos[3];
		GetClientEyePosition(client, clientEyePos);
		ShotRocket(client, clientPos,clientEyePos, clientAngle);
		g_iHellfireCount[client]++;
	}

	if (Fuel[client]<0.0)Fuel[client]=-1.0;
	PrintCenterText(client, "Hellfire %d \nBullet %d \nFuel %d", cvheli_hellfire.IntValue-g_iHellfireCount[client], Bullet[client], RoundFloat(Fuel[client]));

	if (Fuel[client]<0.0)
	{
		SetEntityGravity(client, 1.0);
	}

	/*
	// Source Engine branch 2010 (and it's modified versions) no longer support
	// GoldSrc styled HudText.
	//
	// Fake crosshair
	if (IsClientConnected(client) && IsClientInGame(client))
	{
		SetHudTextParams(-1.0, -1.0, 0.5, 148,13,8,255, 0, 6.0, 0.1, 0.2);
		ShowHudText(client, -1, "∙");
	}
	*/
}

void ShotRocket(int client, float helpos[3], float clientEyePos[3], float clientAngle[3])
{
	float hitpos[3];
	float gunpos[3];
	float pos[3];
	float angle[3];

	float right[3];
	float dir[3];

	CopyVector(helpos, pos);
	GetHitPos(client, clientEyePos, clientAngle, hitpos);

	GetAngleVectors(clientAngle, NULL_VECTOR, right, NULL_VECTOR);
	CopyVector(right, gunpos);
	bool leftgun=g_iHellfireCount[client]%2==0;
 	if (leftgun)ScaleVector(gunpos, 20.0);
	else ScaleVector(gunpos, -20.0);
	AddVectors(pos, gunpos, gunpos);

	SubtractVectors(hitpos,  gunpos, dir);
	NormalizeVector(dir,dir);

	GetVectorAngles(dir, angle);

	SDKCall(fCreateRocket, client, "rocket_hellfire", gunpos, angle);
}

void Shot(int client, float helpos[3], float clientEyePos[3], float clientAngle[3])
{
	float hitpos[3];
	float gunpos[3];
	float pos[3];
	float angle[3];

	float right[3];
	float dir[3];

	CopyVector(helpos, pos);
	GetHitPos(client, clientEyePos, clientAngle, hitpos);

	GetAngleVectors(clientAngle, NULL_VECTOR, right, NULL_VECTOR);
	CopyVector(right, gunpos);
	bool leftgun=Bullet[client]%2==0;
 	if (leftgun)ScaleVector(gunpos, 20.0);
	else ScaleVector(gunpos, -20.0);
	AddVectors(pos, gunpos, gunpos);

	SubtractVectors(hitpos,  gunpos, dir);
	NormalizeVector(dir,dir);

	float acc=cvheli_gun_accuracy.FloatValue;
	if (acc<0.0)acc=0.0;
	else if (acc>1.5)acc=1.5;

	acc=0.005+acc*0.018;

	dir[0]+=GetRandomFloat(-1.0, 1.0)*acc;
	dir[1]+=GetRandomFloat(-1.0, 1.0)*acc;
	dir[2]+=GetRandomFloat(-1.0, 1.0)*acc;
	GetVectorAngles(dir, angle);

	FireBullet(client, gunpos, angle, hitpos);

	ShowMuzzleFlash(gunpos, clientAngle);

	//EmitSoundToAll(SOUND_SHOT, DummyEnt[client], SNDCHAN_WEAPON, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	EmitSoundToAll(SOUND_SHOT, DummyEnt[client], SNDCHAN_WEAPON, _, _, 1.0);

}

void GetHitPos(int client, float pos[3], float ang[3], float hitpos[3])
{
	Handle trace = TR_TraceRayFilterEx(pos, ang, MASK_SHOT, RayType_Infinite, TraceBulletTest, client);
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(hitpos, trace);
	}
	delete trace;
}

int FireBullet(int client, float pos[3], float angle[3], float hitpos[3])
{
	Handle trace = TR_TraceRayFilterEx(pos, angle, MASK_SHOT, RayType_Infinite, TraceBulletTest, client);
	int ent = 0;
	bool hit = false;
	bool alive = false;
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(hitpos, trace);
		ent = TR_GetEntityIndex(trace);
		hit = true;
		if (ent > 0)
		{
			if (ent >=1 && ent <= MaxClients)
				alive = true;
			DealDamage(ent, cvheli_gun_damage.IntValue, client, DMG_BULLET, "UH-1 Huey");
		}
	}
	delete trace;
	
	if (alive)
	{
		float Direction[3];
		GetAngleVectors(angle, Direction, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(Direction, -1.0);
		GetVectorAngles(Direction,Direction);
		//ShowParticle(hitpos, Direction, PARTICLE_BLOOD, 0.1);
	}
	else if (hit)
	{
		BulletTracer(client, pos, angle, hitpos);
		float Direction[3];
		Direction[0] = GetRandomFloat(-1.0, 1.0);
		Direction[1] = GetRandomFloat(-1.0, 1.0);
		Direction[2] = GetRandomFloat(-1.0, 1.0);
		TE_SetupSparks(hitpos,Direction,1,3);
		TE_SendToAll();

		TE_SetupBeamRingPoint(hitpos, 10.0, 10.1, g_iBeaconBeam, g_iBeaconHalo, 0, 0, 0.2, 1.0, 0.0, {255, 0, 0, 255}, 1, 0);
		TE_SendToAll();
	}
	return ent;
}

void BulletTracer(int client, float gunpos[3], float angle[3], float hitpos[3]) {
	int gunfire = EntRefToEntIndex(g_iGunfireRef[client]);
	if(gunfire > MaxClients && IsValidEntity(gunfire)) {
		AcceptEntityInput(gunfire, "Kill");
		//g_iGunfireRef[client] = 0;
	}
	int target = EntRefToEntIndex(g_iTargetRef[client]);
	if(target > MaxClients && IsValidEntity(target)) {
		AcceptEntityInput(target, "Kill");
		//g_iTargetRef[client] = 0;
	}
	char AddOutput[256];
	target = CreateEntityByName("info_target"); 
	if(IsValidEntity(target)) {
		TeleportEntity(target, hitpos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(target);
		Format(AddOutput, sizeof(AddOutput), "OnUser3 !self:kill::%0.1f:-1", 10.0);
		SetVariantString(AddOutput);
		AcceptEntityInput(target, "AddOutput");
		AcceptEntityInput(target, "FireUser1");
	}
	gunfire = CreateEntityByName("env_gunfire"); 
	if(IsValidEntity(gunfire)){ 
		DispatchKeyValue(gunfire, "bias", "1");
		DispatchKeyValue(gunfire, "maxburstdelay", "1");
		DispatchKeyValue(gunfire, "maxburstsize", "100");
		DispatchKeyValue(gunfire, "minburstdelay", "1");
		DispatchKeyValue(gunfire, "minburstsize", "100");
		DispatchKeyValue(gunfire, "rateoffire", "100");
		DispatchKeyValue(gunfire, "StartDisabled", "0");
		
		//The only properties that do anything.
		DispatchKeyValue(gunfire, "spread", "1"); // 1, 5, 10, 15 how much the bullets spread.
		DispatchKeyValue(gunfire, "shootsound", "Weapon_M16A4.Single"); //Weapon_M16A4.Single Weapon_mk18.Single Weapon_AK74.Single
		//DispatchKeyValue(gunfire, "weaponname", "weapon_m4a1");
		SetEntPropEnt(gunfire, Prop_Data, "m_hTarget", target);
		//SetEntPropEnt(gunfire, Prop_Send, "m_hOwnerEntity", client);
		//Must teleport BEFORE SPAWNING, one spawns that's when it shoots.
		TeleportEntity(gunfire, gunpos, angle, NULL_VECTOR);
		DispatchSpawn(gunfire);
		ActivateEntity(gunfire);

		//Multiple firing mechanism.
		float shootSpeed = 0.1; // lowest it can go.
		
		Format(AddOutput, sizeof(AddOutput), "OnUser1 !self:kill::%0.1f:-1", 0.1); //10.0
		SetVariantString(AddOutput);
		AcceptEntityInput(gunfire, "AddOutput");
		Format(AddOutput, sizeof(AddOutput), "OnUser2 !self:Disable:::-1");
		SetVariantString(AddOutput);
		AcceptEntityInput(gunfire, "AddOutput");
		Format(AddOutput, sizeof(AddOutput), "OnUser2 !self:FireUser3:::-1");
		SetVariantString(AddOutput);
		AcceptEntityInput(gunfire, "AddOutput");
		Format(AddOutput, sizeof(AddOutput), "OnUser3 !self:Enable:::-1");
		SetVariantString(AddOutput);
		AcceptEntityInput(gunfire, "AddOutput");
		Format(AddOutput, sizeof(AddOutput), "OnUser3 !self:FireUser2::%0.1f:-1", shootSpeed);
		SetVariantString(AddOutput);
		AcceptEntityInput(gunfire, "AddOutput");
		AcceptEntityInput(gunfire, "FireUser1");
		AcceptEntityInput(gunfire, "FireUser2");
	}
	g_iGunfireRef[client] = EntIndexToEntRef(gunfire);
	g_iTargetRef[client] = EntIndexToEntRef(target);
	return;
}

void ShowMuzzleFlash(float pos[3], float angle[3])
{
 	int particle = CreateEntityByName("info_particle_system");
	DispatchKeyValue(particle, "effect_name", PARTICLE_MUZZLE_FLASH);
	DispatchSpawn(particle);
	ActivateEntity(particle);
	TeleportEntity(particle, pos, angle, NULL_VECTOR);
	AcceptEntityInput(particle, "start");
	CreateTimer(0.01, DeleteParticles, particle, TIMER_FLAG_NO_MAPCHANGE);

}

bool IsValidEnt(int ent)
{
	if (ent>0 && IsValidEdict(ent) && IsValidEntity(ent))
	{
		return true;
	}
	return false;
}

void CopyVector(float source[3], float target[3])
{
	target[0]=source[0];
	target[1]=source[1];
	target[2]=source[2];
}

void SetVector(float target[3], float x, float y, float z)
{
	target[0]=x;
	target[1]=y;
	target[2]=z;
}

public void OnPluginEnd()
{
	RemoveHelicopterAll();
}

void ResetAllState()
{
	g_iHeliTime = 0;
	g_iTotalHeli = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		ResetClientState(i);
	}
}

void ResetClientState(int client)
{
	DummyEnt[client]=0;
	HelicopterEnt[client]=0;
	HelicopterEnt_other[client]=0;
	g_iTargetRef[client] = 0;
	g_iGunfireRef[client] = 0;
}

void RemoveHelicopterAll()
{
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			RemoveHelicopter(i);
		}
	}
}

public void PrecacheParticle(char[] particlename)
{
	int particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(0.01, DeleteParticles, particle, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action DeleteParticles(Handle timer, any particle)
{
	 if (IsValidEntity(particle))
	 {
		 char classname[64];
		 GetEdictClassname(particle, classname, sizeof(classname));
		 if (StrEqual(classname, "info_particle_system", false))
			{
				AcceptEntityInput(particle, "stop");
				AcceptEntityInput(particle, "kill");
				RemoveEdict(particle);

			}
	 }
}

public Action DeleteParticletargets(Handle timer, any target)
{
	if (IsValidEntity(target))
	{
		char classname[64];
		GetEdictClassname(target, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_target", false))
		{
			AcceptEntityInput(target, "stop");
			AcceptEntityInput(target, "kill");
			RemoveEdict(target);
		}
	}
}

public int ShowParticle(float pos[3], float ang[3], char[] particlename, float time)
{
	int particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchSpawn(particle);
		ActivateEntity(particle);
		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle, TIMER_FLAG_NO_MAPCHANGE);
		return particle;
	}
	return 0;
}

void VisiblePlayer(int client, bool visible = true)
{
	if (visible)
	{
		SetEntityRenderMode(client, RENDER_NORMAL);
		SetEntityRenderColor(client, 255, 255, 255, 255);
	}
	else
	{
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, 0, 0, 0, 0);
	}
}

void GotoThirdPerson(int client, bool state)
{
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", state ? 0 : 1);
	//ClientCommand(client, "%s", state ? "thirdperson" : "firstperson");
}

public bool TraceBulletTest(int entity, int mask, any data)
{
	// We found ourselves? ignore...
	if (entity == data) return false;
	if (entity >= 1 && entity <= MaxClients)
	{
		// Teamkilling is a no
		if (GetClientTeam(entity) == GetClientTeam(data))
			return false;
	}
	return true;
}

void DealDamage(int victim, int damage, int attacker = 0, int dmg_type = DMG_GENERIC, char weapon[32] = "")
{
	if (victim > 0 && IsValidEdict(victim) && damage > 0)
	{
		char dmg_str[16];
		IntToString(damage, dmg_str, 16);
		char dmg_type_str[32];
		IntToString(dmg_type, dmg_type_str, 32);
		int pointHurt = CreateEntityByName("point_hurt");
		if (pointHurt)
		{
			DispatchKeyValue(victim, "targetname", "war3_hurtme");
			DispatchKeyValue(pointHurt, "DamageTarget", "war3_hurtme");
			DispatchKeyValue(pointHurt, "Damage", dmg_str);
			DispatchKeyValue(pointHurt, "DamageType", dmg_type_str);
			if (!StrEqual(weapon,""))
				DispatchKeyValue(pointHurt, "classname", weapon);
			DispatchSpawn(pointHurt);
			AcceptEntityInput(pointHurt, "Hurt", (attacker > 0) ? attacker : -1);
			DispatchKeyValue(pointHurt, "classname", "point_hurt");
			DispatchKeyValue(victim, "targetname", "donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}

public Action DeletePushForce(Handle timer, any ent)
{
	if (ent> 0 && IsValidEntity(ent) && IsValidEdict(ent))
	{
		char classname[64];
		GetEdictClassname(ent, classname, sizeof(classname));
		if (StrEqual(classname, "point_push", false))
		{
			AcceptEntityInput(ent, "Disable");
			AcceptEntityInput(ent, "Kill");
			RemoveEdict(ent);
		}
	}
}

bool GetSkyPos(int client, float pos[3]) {
	Handle ray = TR_TraceRayFilterEx(pos, UP_VECTOR, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceWorldOnly, client);

	if (TR_DidHit(ray)) {
		char surface[64];
		TR_GetSurfaceName(ray, surface, sizeof(surface));
		if (StrContains(surface, "TOOLS/TOOLSSKYBOX", false) != -1) {
			CloseHandle(ray);
			return true;
		}
	}
	CloseHandle(ray);
	return false;
}

public bool TraceWorldOnly(int entity, int mask, any data) {
	if (entity == data || entity > 0)
		return false;
	return true;
}

public Action QuerygameMEStatsCallback(int command, int payload, int client, Handle datapack)
{
	if ((client > 0) && (command == RAW_MESSAGE_CALLBACK_PLAYER)) {

		Handle data = CloneHandle(datapack);
		ResetPack(data);

		// total values
		g_iSkill[client]	= ReadPackCell(data); //rank
		g_iSkill[client]	= ReadPackCell(data); //players
		g_iSkill[client]	= ReadPackCell(data); //skill
		CloseHandle(data);
		if (CheckCommandAccess(client, "", ADMFLAG_ROOT)) g_iSkill[client] = 1500000;
	}
}

void GetGameme(int client)
{
	if (!g_bGameme) return;
	QueryGameMEStats("playerinfo", client, QuerygameMEStatsCallback, QUERY_TYPE_ONCLIENTPUTINSERVER);
}

void RemoveWeapons(int client)
{
	int primaryWeapon = GetPlayerWeaponSlot(client, 0);
	int secondaryWeapon = GetPlayerWeaponSlot(client, 1);
	int meleeWeapon = GetPlayerWeaponSlot(client, 2); //2 is melee
	int playerGrenades = GetPlayerWeaponSlot(client, 3);

	// Check and remove meleeWeapon
	if (meleeWeapon != -1 && IsValidEntity(meleeWeapon))
	{
		//since we have more than 1 melee in current theater (healthkit and flaregun as melee)
		while (meleeWeapon != -1 && IsValidEntity(meleeWeapon))
		{
			meleeWeapon = GetPlayerWeaponSlot(client, 2);
			if (meleeWeapon != -1 && IsValidEntity(meleeWeapon))
			{
				// Remove meleeWeapon
				char weapon[32];
				GetEntityClassname(meleeWeapon, weapon, sizeof(weapon));
				//PrintToChatAll("melee weapon: %s", weapon);
				RemovePlayerItem(client, meleeWeapon);
				AcceptEntityInput(meleeWeapon, "kill");
			}
		}
	}

	// Check and remove primaryWeapon
	if (primaryWeapon != -1 && IsValidEntity(primaryWeapon))
	{
		//since we have more than 1 primary in current theater
		while (primaryWeapon != -1 && IsValidEntity(primaryWeapon))
		{
			primaryWeapon = GetPlayerWeaponSlot(client, 0);
			if (primaryWeapon != -1 && IsValidEntity(primaryWeapon))
			{
				// Remove primaryWeapon
				char weapon[32];
				GetEntityClassname(primaryWeapon, weapon, sizeof(weapon));
				//PrintToChatAll("primary weapon: %s", weapon);
				RemovePlayerItem(client, primaryWeapon);
				AcceptEntityInput(primaryWeapon, "kill");
			}
		}
	}

	// Check and remove secondaryWeapon
	if (secondaryWeapon != -1 && IsValidEntity(secondaryWeapon))
	{
		//since we have more than 1 primary in current theater
		while (secondaryWeapon != -1 && IsValidEntity(secondaryWeapon))
		{
			secondaryWeapon = GetPlayerWeaponSlot(client, 1);
			if (secondaryWeapon != -1 && IsValidEntity(secondaryWeapon))
			{
				// Remove secondaryWeapon
				char weapon[32];
				GetEntityClassname(secondaryWeapon, weapon, sizeof(weapon));
				//PrintToChatAll("secondary weapon: %s", weapon);
				RemovePlayerItem(client, secondaryWeapon);
				AcceptEntityInput(secondaryWeapon, "kill");
			}
		}
	}

	// Check and remove grenades
	if (playerGrenades != -1 && IsValidEntity(playerGrenades))
	{
		//since we have more than 1 primary in current theater
		while (playerGrenades != -1 && IsValidEntity(playerGrenades))
		{
			playerGrenades = GetPlayerWeaponSlot(client, 3);
			if (playerGrenades != -1 && IsValidEntity(playerGrenades))
			{
				// Remove playerGrenades
				char weapon[32];
				GetEntityClassname(playerGrenades, weapon, sizeof(weapon));
				//PrintToChatAll("secondary weapon: %s", weapon);
				RemovePlayerItem(client, playerGrenades);
				AcceptEntityInput(playerGrenades, "kill");
			}
		}
	}
}

int GetGameState()
{
	return GameRules_GetProp("m_iGameState");
}

stock float GetRoundTime()
{
	return GameRules_GetPropFloat("m_flRoundLength")-(GetGameTime()-GameRules_GetPropFloat("m_flRoundStartTime"));
}

bool IsValidPlayer(int client) {
	return (0 < client <= MaxClients) && IsClientInGame(client);
}