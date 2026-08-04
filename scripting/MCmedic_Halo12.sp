#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <timers>
#include <loghelper>
#include <adt_trie>
#include <morecolors182>
#undef REQUIRE_PLUGIN
#include <gameme>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

//gameME callback
#define QUERY_TYPE_OTHER 0
#define QUERY_TYPE_ONCLIENTPUTINSERVER 1


#define MAXWEAPONNAME 64
#define MAXUSERNAME 64
#define TEAM_SPEC 	1
#define TEAM_SEC	2
#define TEAM_INS	3

#define MAXPLAYER	14

#define INS_PL_SPAWNZONE	(1 << 11)

#define DMG_BULLET		(1 << 1)
#define DMG_BURN		(1 << 3)
#define INS_ATTACK1		(1 << 0)
#define INS_USE			(1 << 6)
#define INS_AIM			(1 << 18)
#define INS_AIM_TOGGLE	(1 << 27)

#define COLOR_SECURITY	"84961CFF"
#define COLOR_GOLD	"FFD700FF"
#define HIDEHUD_MISCSTATUS ( 1<<6 )	// Hide miscellaneous status elements (trains, pickup history, death notices, etc) smlib/clients.inc

/*
* 죽은 위치 표시, 렉 제거
*/

//MEDIC AND SPECTATING PANEL
public Plugin myinfo =  
{
	name = "[MC] Medic",
	author = "Bot Chris based on rrrfffrrr's Medic",
	description = "[MC] Medic",
	version = "1.3",
	url = ""
}

//HALO
int g_iBeaconBeam,
	g_iBeaconHalo;

// Basic color arrays for temp entities
int redColor[4]		= {255, 0, 0, 255};
int greenColor[4]	= {0, 255, 0, 255};
int orangeColor[4]	= {255, 128, 0, 255};

ConVar cvarHaloEnable;
// END HALO

StringMap playerList;

ConVar cvarMedicEnable;
ConVar cvarMedicBanEnable;
ConVar cvarMedicPanelInfoEnable;
ConVar cvarMedicSkillCheck;
ConVar cvarMedicMinPoint;
ConVar cvarMedic_Class;
ConVar cvarMedicRoleTimer;
ConVar cvarMedicBanTimer;
ConVar cvarMedicBannedTime;
ConVar cvarMedicBanAddTimeAllAlive;
ConVar cvarRevDelay;
ConVar cvarRevMaxDistance;
ConVar cvarBonusScore;
ConVar cvarInitRevToken;
ConVar cvarAllowAddRevToken;
ConVar cvarTKlostToken;

Handle g_hRespawn = INVALID_HANDLE;
Handle g_hGameconfig;

float g_fRespawnTimer[MAXPLAYERS+1];
int g_iRespawnTarget[MAXPLAYERS+1];
int g_iBonusPoint[MAXPLAYERS+1];
int g_iReviveToken[MAXPLAYERS+1];
int g_nObjResource;
int g_nCurrentActiveObj;
int g_iCurrentControlPoint = -1;
float g_fMedicRoleTimer = 0.0;
float g_fDeadPosition[MAXPLAYERS+1][3];
bool g_bMedicPlayer[MAXPLAYERS+1];
bool g_bPlayerEverDead[MAXPLAYERS+1] = {false, ...};
bool g_bShowHalo[MAXPLAYERS+1] = {true, ...};

char g_sPlayerClass[MAXPLAYERS+1][64];
char g_sClient_Org_Name[MAXPLAYERS+1][64];
char g_sMedic_Class[64];
char g_sMedicMinPoint[32];


int g_iGameState = 0;
int g_iPlayersList[MAXPLAYER] = {-1, ...};
bool g_b2MedicMode = false; //true=2 medic mode	false=all medic mode
float g_fGameTime = 9999999999.0;
int g_iSecurityAlive = 0;
int g_iSecurityDead = 0;
bool g_bMedicForceToChange[MAXPLAYERS+1] = {false, ...};
float g_fMedicLastHealTime[MAXPLAYERS+1];
float g_fMedicBannedTime[MAXPLAYERS+1];
int g_iPlayerDeployedWeapon[MAXPLAYERS+1] = {-1, ...};
int g_iLastHealTarget[MAXPLAYERS+1] = {-1, ...};
float g_fLastHealingTime[MAXPLAYERS+1] = {0.0, ...};
int g_iLastHealPoint[MAXPLAYERS+1] = {-1, ...};

//ConVar cvUpdatedSpawnPoint;

//gameME
int g_iRank[MAXPLAYERS+1] = {-1, ...};
int g_iSkill[MAXPLAYERS+1] = {-1, ...};
float g_fKPD[MAXPLAYERS+1] = {0.0, ...};
float g_fAccuracy[MAXPLAYERS+1] = {0.0, ...};
//char g_sPlayerSkill[MAXPLAYERS+1][32]; //to show it in certified list
int g_iVETS_MEDIC_SKILL = 100000;

/***SPECTATING DETAILS-START***/
int g_iKills[MAXPLAYERS+1];
int g_iDeaths[MAXPLAYERS+1];
int g_iWShots[MAXPLAYERS+1];
int g_iWHits[MAXPLAYERS+1];
float g_fLastHitTime[MAXPLAYERS+1];
char g_sTagClass[MAXPLAYERS+1][64];
bool g_bShowPanel[MAXPLAYERS+1] = {true, ...};
/***SPECTATING DETAILS-END***/

char g_ServerName[64];
bool g_isTugServer;

//gameme library
bool g_bGameme;

public void OnPluginStart() {
	LoadTranslations("common.phrases");
	playerList = new StringMap();

	cvarMedicEnable = CreateConVar("sm_medic_enabled", "1", "Enable/disable Medic", FCVAR_PROTECTED);
	cvarHaloEnable = CreateConVar("sm_HaloEnable", "1", "Shows/disable Halo on Dead Location; 0 - disabled, 1 - enabled", FCVAR_PROTECTED);
	cvarMedicBanEnable = CreateConVar("sm_MedicBanEnable", "0", "Enable/disable Medic Ban", FCVAR_PROTECTED);
	cvarMedicPanelInfoEnable = CreateConVar("sm_MedicPanelInfoEnable", "1", "Enable/disable Medic Panel Info", FCVAR_PROTECTED);
	
	cvarMedicSkillCheck = CreateConVar("sm_MedicSkillCheck", "0", "Enable Medic Skill Check", FCVAR_PROTECTED);
	cvarMedicMinPoint = CreateConVar("sm_MedicMinPoint", "20000", "Min gameME point for Medic role", FCVAR_PROTECTED);
	cvarMedic_Class = CreateConVar("sm_medic_class", "", "Class name of Medic", FCVAR_PROTECTED);
	cvarMedicRoleTimer = CreateConVar("sm_MedicRoleTimer", "120", "Prevent Swap Medic after timer", FCVAR_PROTECTED);
	cvarMedicBanTimer = CreateConVar("sm_MedicBanTimer", "300.0", "Medic revive timer", FCVAR_PROTECTED);
	cvarMedicBannedTime = CreateConVar("sm_MedicBannedTime", "360.0", "Medic banned time", FCVAR_PROTECTED);
	cvarMedicBanAddTimeAllAlive = CreateConVar("sm_MedicBanAddTimeAllAlive", "0.0", "Add MedicBan timer if all alive", FCVAR_PROTECTED);

	cvarRevDelay = CreateConVar("sm_medic_delay", "1.0", "Delay for revive", FCVAR_PROTECTED);
	cvarRevMaxDistance = CreateConVar("sm_medic_distance", "100", "Distance for revive", FCVAR_PROTECTED);
	cvarBonusScore = CreateConVar("sm_bonus_score", "10", "Get score when revive/heal", FCVAR_PROTECTED);
	cvarInitRevToken = CreateConVar("sm_InitRevToken", "0", "How many times player can be revived. 0=infinite.", FCVAR_PROTECTED);
	cvarAllowAddRevToken = CreateConVar("sm_AllowAddRevToken", "1", "If enabled, will add revive token after reviving. enable/disable.", FCVAR_PROTECTED);
	cvarTKlostToken = CreateConVar("sm_TKlostToken", "1", "If enabled, TK will lost Revive Token. enable/disable.", FCVAR_PROTECTED);

	g_hGameconfig = LoadGameConfigFile("insurgency.games");
	if (g_hGameconfig == INVALID_HANDLE) SetFailState("Fatal Error: Missing File \"insurgency.games\"!");

	StartPrepSDKCall(SDKCall_Player);
	char game[40];
	GetGameFolderName(game, sizeof(game));
	if (StrEqual(game, "insurgency")) PrepSDKCall_SetFromConf(g_hGameconfig, SDKConf_Signature, "ForceRespawn");

	g_hRespawn = EndPrepSDKCall();
	if (g_hRespawn == INVALID_HANDLE) SetFailState("Fatal Error: Unable to find ForceRespawn");

	HookEvent("round_freeze_end", Event_RoundFreezeEnd);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd_Pre, EventHookMode_Pre);
	HookEvent("player_changename", Event_PlayerChangeName_Pre, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	HookEvent("player_pick_squad", Event_PlayerPickSquad);
	HookEvent("player_pick_squad", Event_PlayerPickSquad_Post, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath_Pre, EventHookMode_Pre);
	HookEvent("weapon_deploy", Event_WeaponDeploy_Pre, EventHookMode_Pre);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("object_destroyed", Event_ObjectDestroyed);
	HookEvent("controlpoint_captured", Event_ControlPointCaptured);


	HookConVarChange(cvarInitRevToken, cvarUpdate);
	HookConVarChange(cvarMedic_Class, cvarUpdate);
	HookConVarChange(cvarMedicMinPoint, cvarUpdate);
	UpdateCvar();

	RegAdminCmd("mclist", Command_ListPlayer, ADMFLAG_ROOT, "Player Skill");
	RegAdminCmd("banmedic", Command_BanMedic, ADMFLAG_KICK, "Drop Medic");
	RegConsoleCmd("mchalo", cmd_MChalo, "MChalo enable/disable");
	RegConsoleCmd("mcpanel", Command_MCpanel, "Turns on/off the spectator panel display");
}

public void OnLibraryAdded(const char[] szLibrary)
{
	if(StrEqual(szLibrary, "gameme")) g_bGameme = true;
}

public void OnLibraryRemoved(const char[] szLibrary)
{
	if(StrEqual(szLibrary, "gameme")) g_bGameme = false;
}

public void OnAllPluginsLoaded()
{
	g_bGameme = LibraryExists("gameme");
}

public void cvarUpdate(Handle cvar, const char[] oldvalue, const char[] newvalue) {
	UpdateCvar();
}

public void UpdateCvar() {
	for (int i = 1; i <= MaxClients; i++)
	{
		if (cvarInitRevToken.IntValue > 0) g_iReviveToken[i] = cvarInitRevToken.IntValue;
		if (cvarInitRevToken.IntValue <= 0) g_bShowHalo[i] = true;
	}
	GetConVarString(cvarMedic_Class, g_sMedic_Class, sizeof(g_sMedic_Class));
	if (strlen(g_sMedic_Class) > 1) g_b2MedicMode = true;
	else g_b2MedicMode = false;
	FormatNumber(cvarMedicMinPoint.IntValue, g_sMedicMinPoint, 32);

	UpdateMedicRole();
}

public void OnMapStart() {
	PrecacheSound_medic();
	SDKHook(GetPlayerResourceEntity(), SDKHook_ThinkPost, SHook_PlayerResourceThinkPost);
	FindConVar("hostname").GetString(g_ServerName, sizeof(g_ServerName));
	g_isTugServer = (StrContains(g_ServerName, "TUG GG", false) != -1);

	g_nObjResource = FindEntityByClassname(-1, "ins_objective_resource");
	g_nCurrentActiveObj = FindSendPropInfo("CINSObjectiveResource", "m_nActivePushPointIndex");
	g_iCurrentControlPoint = -1;

	//Materials for Medic HALO
	g_iBeaconBeam = PrecacheModel("sprites/laserbeam.vmt");
	g_iBeaconHalo = PrecacheModel("sprites/glow01.vmt");
	CreateTimer(3.0, Timer_ShowHalo, _ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	CreateTimer(0.1, Timer_RevMonitor, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(1.0, Timer_MedicMonitor, _ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Command_BanMedic(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: dropmedic <#userid|name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_MULTI,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToCommand(client, "No single target found.");
		//ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		//if (!IsClientInGame(target_list[i]) || GetClientTeam(target_list[i]) != TEAM_SEC) continue;
		int target = target_list[i];
		
		if (g_b2MedicMode && StrContains(g_sPlayerClass[target], g_sMedic_Class, false) != -1 && g_bMedicPlayer[target])
		{
			CPrintToChat(target, "{ghostwhite}You are {orangered}BANNED {mediumspringgreen}as MEDIC {ghostwhite}for %ds", cvarMedicBannedTime.IntValue);
			g_bMedicPlayer[target] = false;
			SetClientInfo(target, "name", g_sClient_Org_Name[target]);
			SetEntPropString(target, Prop_Data, "m_szNetname", g_sClient_Org_Name[target]);
			g_fMedicBannedTime[target] = g_fGameTime+cvarMedicBannedTime.FloatValue;

			g_sPlayerClass[target] = "";
			ChangeClientTeam(target, TEAM_SPEC);
			CreateTimer(0.1, Timer_MoveToSurvivors, target, TIMER_FLAG_NO_MAPCHANGE);
			CreateTimer(0.11, Timer_LostMedic, target, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Handled;
}

public void OnClientSettingsChanged(int client) {
	//PrintToChatAll("OnClientSettingsChanged");
}

public void OnClientPostAdminCheck(int client)
{
	if (IsFakeClient(client)) return;

	GetClientInfo(client, "name", g_sClient_Org_Name[client], 64);
	if (StrContains(g_sClient_Org_Name[client], "﷽﷽﷽", false) != -1)
	{
		ServerCommand("kickid %d %s", GetClientUserId(client), "Bad name \"﷽﷽﷽\"");
		return;
	}

	g_iRank[client] = -1;
	g_iSkill[client] = -1;
	g_iKills[client] = 0;
	g_iDeaths[client] = 0;
	g_iWShots[client] = 0;
	g_iWHits[client] = 0;
	g_bShowPanel[client] = true;

	if (client > 0) GetGameme(client);

	for (int i = 0;i < MAXPLAYER;i++)
	{
		if (g_iPlayersList[i] == -1 || !IsClientInGame(g_iPlayersList[i]))
		{
			g_iPlayersList[i] = client;
			break;
		}
	}

	g_fMedicBannedTime[client] = 0.0;
	g_bMedicForceToChange[client] = false;

	g_iRespawnTarget[client] = 0;
	g_fRespawnTimer[client] = 0.0;
	g_bMedicPlayer[client] = false;
	g_bPlayerEverDead[client] = false;
	g_iBonusPoint[client] = 0;
	//g_iReviveToken[client] = cvarInitRevToken.IntValue;
	g_bShowHalo[client] = true;

	char steamId[32];
	GetClientAuthId(client, AuthId_Steam3, steamId, sizeof(steamId));
	if (!playerList.GetValue(steamId, g_iReviveToken[client])) {
		g_iReviveToken[client] = cvarInitRevToken.IntValue;
		playerList.SetValue(steamId, cvarInitRevToken.IntValue, true);
	}

	char sName[64];
	strcopy(sName, 64, g_sClient_Org_Name[client]);
	ReplaceString(sName, 64, "(Admin) ", "", false);
	ReplaceString(sName, 64, "(Admin)", "", false);
	ReplaceString(sName, 64, "[MEDIC] ", "", false);
	ReplaceString(sName, 64, "[MEDIC]", "", false);
	ReplaceString(sName, 64, "[VIP] ", "", false);
	ReplaceString(sName, 64, "[VIP]", "", false);
	char CHSsteamId[32];
	GetClientAuthId(client, AuthId_Steam2, CHSsteamId, 32);
	if (g_isTugServer && CheckCommandAccess(client, "", ADMFLAG_BAN) && !StrEqual(CHSsteamId, "STEAM_1:1:45174426"))
		Format(sName, 64, "(Admin) %s", g_sClient_Org_Name[client]);

	if (strcmp(sName, g_sClient_Org_Name[client]) != 0) {
		strcopy(g_sClient_Org_Name[client], 64, sName);
		SetClientInfo(client, "name", g_sClient_Org_Name[client]);
		SetEntPropString(client, Prop_Data, "m_szNetname", g_sClient_Org_Name[client]);
	}
}

public Action QuerygameMEStatsCallback(int command, int payload, int client, Handle datapack)
{
	if ((client > 0) && (command == RAW_MESSAGE_CALLBACK_PLAYER)) {

		Handle data = CloneHandle(datapack);
		ResetPack(data);

		int iTemp = -1;
		float fTemp = -1.0;
		// total values
		g_iRank[client]		= ReadPackCell(data); //rank
		iTemp				= ReadPackCell(data); //players
		g_iSkill[client]	= ReadPackCell(data); //skill
		iTemp				= ReadPackCell(data); //kills
		iTemp				= ReadPackCell(data); //deaths
		g_fKPD[client]		= ReadPackFloat(data); //kpd
		iTemp				= ReadPackCell(data); //suicides
		iTemp				= ReadPackCell(data); //headshots
		fTemp				= ReadPackFloat(data); //headshots per kill
		g_fAccuracy[client]	= ReadPackFloat(data); //accuracy
		CloseHandle(data);


		// only write this message to gameserver log if client has connected
		if (payload == QUERY_TYPE_ONCLIENTPUTINSERVER) {
			LogToGame("Player %L is on rank %d with %d points", client, g_iRank[client], g_iSkill[client]);
		}
	}
}

public void OnClientDisconnect(int client)
{
	for (int i = 0;i < MAXPLAYER;i++)
	{
		if (g_iPlayersList[i] == -1) continue;
		if (client == g_iPlayersList[i])
			g_iPlayersList[i] = -1;
	}
}

public Action Timer_RevMonitor(Handle timer) {
	g_iGameState = GetGameState();
	g_fGameTime = GetGameTime();
	if (g_iGameState != 4) return Plugin_Continue;

	float fWarning = cvarMedicBanTimer.FloatValue/3;
	if (!cvarMedicEnable.BoolValue) return Plugin_Continue;
	for (int i = 0;i < MAXPLAYER;i++) {
		if (g_iPlayersList[i] == -1 || !IsClientInGame(g_iPlayersList[i])) continue;

		if (g_bMedicPlayer[g_iPlayersList[i]])
		{
			int medic = g_iPlayersList[i];
			int iButtons = GetClientButtons(medic);
			if (cvarMedicBanEnable.BoolValue && g_b2MedicMode && g_iSecurityAlive+g_iSecurityDead > 3) //2
			{
				if (g_iSkill[medic] >= g_iVETS_MEDIC_SKILL) g_fMedicLastHealTime[medic] = g_fGameTime;
				if (cvarMedicBanAddTimeAllAlive.FloatValue > 0.0 && g_iSecurityDead <= 0 && g_iSecurityAlive > 1 &&
					cvarMedicBanTimer.FloatValue-(g_fGameTime-g_fMedicLastHealTime[medic]) < cvarMedicBanTimer.FloatValue &&
					(g_fGameTime-g_fMedicLastHealTime[medic] < (cvarMedicBanTimer.FloatValue-(fWarning-1.0)) ||
					g_fGameTime-g_fMedicLastHealTime[medic] > (cvarMedicBanTimer.FloatValue-(fWarning-2.0))))
					{
						//if (cvarMedicBanTimer.FloatValue-(g_fGameTime-g_fMedicLastHealTime[medic]) < cvarMedicBanTimer.FloatValue/2) g_fMedicLastHealTime[medic] += 0.3;
						g_fMedicLastHealTime[medic] += cvarMedicBanAddTimeAllAlive.FloatValue;
					}

				if (g_fGameTime-g_fMedicLastHealTime[medic] >= cvarMedicBanTimer.FloatValue)
				{
					if (!g_bMedicForceToChange[medic])
					{
						if (g_iSecurityAlive > 1) //1
						{
							g_bMedicForceToChange[medic] = true;
							if (IsPlayerAlive(medic)) {
								CPrintToChat(medic, "{ghostwhite}If you don't revive teammate, {crimson}Class will be changed");
								Medic_ShowPopupMenu(medic);
							}
							else {
								CPrintToChat(medic, "{ghostwhite}You are {orangered}BANNED {mediumspringgreen}as MEDIC {ghostwhite}for %ds", cvarMedicBannedTime.IntValue);
								g_bMedicPlayer[medic] = false;
								SetClientInfo(medic, "name", g_sClient_Org_Name[medic]);
								SetEntPropString(medic, Prop_Data, "m_szNetname", g_sClient_Org_Name[medic]);
								g_fMedicBannedTime[medic] = g_fGameTime+cvarMedicBannedTime.FloatValue;

								g_sPlayerClass[medic] = "";
								ChangeClientTeam(medic, TEAM_SPEC);
								CreateTimer(0.1, Timer_MoveToSurvivors, medic, TIMER_FLAG_NO_MAPCHANGE);
								CreateTimer(0.11, Timer_LostMedic, medic, TIMER_FLAG_NO_MAPCHANGE);
							}
						}
						else g_fMedicLastHealTime[medic] += cvarMedicBanTimer.FloatValue-(fWarning-10.0); //MUST BE LOWER THAN (cvarMedicBanTimer.FloatValue-fWarning)
					}
				}
				else if (IsPlayerAlive(medic) && g_fGameTime-g_fMedicLastHealTime[medic] >= (cvarMedicBanTimer.FloatValue-fWarning) && g_fGameTime-g_fMedicLastHealTime[medic] <= (cvarMedicBanTimer.FloatValue-(fWarning-0.3)))
				{
					CPrintToChat(medic, "{ghostwhite}If you don't revive teammate in {mediumspringgreen}%ds, {crimson}Class will be changed", RoundFloat(fWarning));
					//Medic_ShowPopupMenu(medic);
				}
			}
			else if (cvarMedicBanEnable.BoolValue && g_b2MedicMode) g_fMedicLastHealTime[medic] = g_fGameTime;

			if (cvarMedicBanEnable.BoolValue && g_b2MedicMode && (iButtons & INS_USE) && g_iSecurityAlive > 1 && g_iSkill[medic] < g_iVETS_MEDIC_SKILL)
				PrintCenterText(medic, "Medic timer left: %.1fs", cvarMedicBanTimer.FloatValue-(g_fGameTime-g_fMedicLastHealTime[medic]));

			float vMedicPos[3];
			GetClientEyePosition(medic, vMedicPos);
			if (g_fRespawnTimer[medic] > 0.0)
			{
				if (IsValidPlayer(g_iRespawnTarget[medic]) && !IsPlayerAlive(g_iRespawnTarget[medic]) && GetVectorDistance(vMedicPos, g_fDeadPosition[g_iRespawnTarget[medic]]) <= cvarRevMaxDistance.FloatValue) {
					if (g_fGameTime >= g_fRespawnTimer[medic]) MedicRevive(medic);
					else {
						PrintCenterText(medic, "Reviving %N... \n%.2fs", g_iRespawnTarget[medic], g_fRespawnTimer[medic]-g_fGameTime);
					}
				}
				else {
					g_iRespawnTarget[medic] = 0;
					g_fRespawnTimer[medic] = 0.0;
					PrintCenterText(medic, "Cancel reviving");
				}
			}
			else if (IsPlayerAlive(medic))
			{
				int iHp, iNewHp, ent;
				float vTargetPos[3];
				int iTarget = GetClientAimTarget(medic, true);

				for (int j = 0;j < MAXPLAYER;j++) {
					if (g_iPlayersList[j] == -1 || !IsClientInGame(g_iPlayersList[j])) continue;
					if (IsPlayerAlive(g_iPlayersList[j]))
					{
						GetClientEyePosition(g_iPlayersList[j], vTargetPos);
						//int iMaxHp = GetEntProp(g_iPlayersList[j], Prop_Data, "m_iMaxHealth");
/*						if (cvarMedicBanEnable.BoolValue && g_b2MedicMode && (iButtons & INS_USE) && iHp < 100)
						{
							vMedicPos[2] -= 20;
							TE_SetupBeamPoints(vTargetPos, vMedicPos, g_iBeaconBeam, 0, 0, 0, 0.1, 1.0, 1.0, 0, 0.0, {50, 100, 250, 144}, 0); //blue
							TE_SendToClient(medic);
							vMedicPos[2] += 20;
						}	*/
		
						if (g_b2MedicMode && g_iPlayerDeployedWeapon[medic] == 20 && (iButtons & INS_ATTACK1) && !(GetEntityFlags(medic)&FL_ONFIRE))
						{
							iNewHp = iHp = GetEntProp(medic, Prop_Send, "m_iHealth");
							//iMaxHp = GetEntProp(medic, Prop_Data, "m_iMaxHealth");
							if (iHp < 100 && iHp >= 80)
							{
								iNewHp = 100;
								PrintCenterText(medic, "You Max Healed yourself.");
								if (iHp != iNewHp) SetEntProp(medic, Prop_Send, "m_iHealth", iNewHp);
							}
						}
						if (iTarget == g_iPlayersList[j] && g_iPlayerDeployedWeapon[medic] == 20 && (iButtons & INS_AIM || iButtons & INS_AIM_TOGGLE))
						{
							iNewHp = iHp = GetEntProp(g_iPlayersList[j], Prop_Send, "m_iHealth");
							vTargetPos[2] -= 20;
							float fDistance = GetVectorDistance(vMedicPos, vTargetPos);
							vTargetPos[2] += 20;
							if (fDistance <= 90.0)
							{
								if (iHp < 100)
								{
									if (GetEntityFlags(iTarget)&FL_ONFIRE)
									{
										ent = GetEntPropEnt(iTarget, Prop_Data, "m_hEffectEntity");
										if (ent != -1) SetEntPropFloat(ent, Prop_Data, "m_flLifetime", 0.0);
									}
									if (g_iLastHealTarget[medic] != iTarget || g_fGameTime-g_fLastHealingTime[medic] >= 15.0)
									{
										char sSoundFile[128];
										Format(sSoundFile, sizeof(sSoundFile), "lua_sounds/medic/letme/medic_letme_heal%d.ogg", GetRandomInt(1, 10));
										EmitSoundToAll(sSoundFile, medic, SNDCHAN_VOICE, _, _, 1.0);
										CPrintToChat(medic, "{mediumspringgreen}Healing... {ghostwhite}%s", g_sClient_Org_Name[iTarget]);
									}
									if (g_b2MedicMode)
									{
										if (g_iSkill[medic] >= g_iVETS_MEDIC_SKILL) iNewHp += 5;
										else iNewHp += 2;
									}
									else iNewHp ++;

									if (iNewHp > 100) iNewHp = 100;
									if (iNewHp >= 100)
									{
										g_bMedicForceToChange[medic] = false;
										g_fMedicLastHealTime[medic] = g_fGameTime;
										if (g_b2MedicMode)
										{
											g_iBonusPoint[medic] += (2*cvarBonusScore.IntValue);
											if (!g_bMedicPlayer[medic]) SetEntProp(iTarget, Prop_Send, "m_bGlowEnabled", 0);

											if (g_iLastHealPoint[medic] != iTarget)
											{
												LogPlayerEvent(medic, "triggered", "healing_medic");
												g_iLastHealPoint[medic] = iTarget;
											}
											if (cvarMedicBanEnable.BoolValue && g_iSkill[medic] < g_iVETS_MEDIC_SKILL) PrintCenterText(medic, "MAX Healed %s. MedicBan was Reset!", g_sClient_Org_Name[iTarget]);
											else PrintCenterText(medic, "%s was healed to MAX health!", g_sClient_Org_Name[iTarget]);
										}
										else
										{
											if (g_iLastHealPoint[medic] != iTarget)
											{
												LogPlayerEvent(medic, "triggered", "healing");
												g_iLastHealPoint[medic] = iTarget;
											}
											g_iBonusPoint[medic] += cvarBonusScore.IntValue;
											PrintCenterText(medic, "%s was healed to MAX health!", g_sClient_Org_Name[iTarget]);
										}
										g_iLastHealTarget[medic] = -1;

										char sVoice[128];
										switch(GetRandomInt(1, 2))
										{
											case 1: {
												Format(sVoice, sizeof(sVoice), "lua_sounds/medic/thx/medic_thanks%d.ogg", GetRandomInt(1, 20)); // total 20 voices
												EmitSoundToAll(sVoice, iTarget, SNDCHAN_VOICE, _, _, 1.0);
											}
											case 2: {
												Format(sVoice, sizeof(sVoice), "lua_sounds/medic/healed/medic_healed%d.ogg", GetRandomInt(1, 39)); // total 39 voices
												EmitSoundToAll(sVoice, medic, SNDCHAN_VOICE, _, _, 1.0);
											}
										}
									}

									g_iLastHealTarget[medic] = iTarget;
									g_fLastHealingTime[medic] = g_fGameTime;
									if (iHp != iNewHp) SetEntProp(iTarget, Prop_Send, "m_iHealth", iNewHp);
									PrintCenterText(iTarget, "Medic Healing (%d/%d)\n\n%N", iNewHp, 100, medic);
									PrintCenterText(medic, "Healing..  (%d/%d)\n\n%N", iNewHp, 100, iTarget);
								}
								else if (iHp == 100 && !g_b2MedicMode)
								{
									PrintCenterText(medic, "MAX HEALTH!");
								}
							}
							else if (iHp < 100 && fDistance > 90.0 && fDistance <= 140.0)
							{
								PrintCenterText(medic, "%N\n\nToo far away (%0.1fm)", iTarget, fDistance*0.01905);
							}
							else if (fDistance > 140.0) PrintCenterText(medic, " ");
						}
					}
					else if (g_bPlayerEverDead[g_iPlayersList[j]] && GetClientTeam(g_iPlayersList[j]) == TEAM_SEC && medic != g_iPlayersList[j])
					{
						int dead = g_iPlayersList[j];
/*						if (GetEntPropFloat(dead, Prop_Send, "m_flModelScale") > 1.0)
						{
							g_bPlayerEverDead[dead] = false;
							continue;
						}	*/
						if ((iButtons & INS_USE) && (cvarInitRevToken.IntValue == 0 || (g_iReviveToken[dead] > 0 && g_bShowHalo[dead])))
						{
							vMedicPos[2] -= 20;
							g_fDeadPosition[dead][2] += 72;
							TE_SetupBeamPoints(g_fDeadPosition[dead], vMedicPos, g_iBeaconBeam, 0, 0, 0, 0.1, 1.0, 1.0, 0, 0.0, {220, 20, 60, 255}, 0); //purple{199, 31, 255, 255} crimson{220, 20, 60, 255}
							TE_SendToClient(medic);
							vMedicPos[2] += 20;
							g_fDeadPosition[dead][2] -= 72;
						}
						if (GetVectorDistance(vMedicPos, g_fDeadPosition[dead]) <= cvarRevMaxDistance.FloatValue)
						{
							//if (cvarInitRevToken.IntValue == 0 || (g_iReviveToken[dead] > 0 && g_bShowHalo[dead])) PrintCenterText(medic, "%N's soul is detected...", dead);
							if (g_fRespawnTimer[medic] == 0.0 && (cvarInitRevToken.IntValue == 0 || (g_iReviveToken[dead] > 0 && g_bShowHalo[dead]))) //cvarInitRevToken=0 is infinite revive
							{
								bool bOtherMedicReviving = false;
								for (int m = 0;m < MAXPLAYER;m++) {
									if (g_iPlayersList[m] == -1 || !IsClientInGame(g_iPlayersList[m]) || g_iPlayersList[m] == medic) continue;
									if (g_iRespawnTarget[g_iPlayersList[m]] == dead)
									{
										bOtherMedicReviving = true;
										PrintCenterText(medic, "Other Medic is reviving...");
										break;
									}
								}
								if (!bOtherMedicReviving)
								{
									g_fRespawnTimer[medic] = g_fGameTime + cvarRevDelay.FloatValue;
									g_iRespawnTarget[medic] = dead;
								}
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

void MedicRevive(int medic) {
	int soul = g_iRespawnTarget[medic];
	if (!IsValidPlayer(soul) || IsPlayerAlive(soul) || !IsValidPlayer(medic) || !IsPlayerAlive(medic)) {
		if (IsValidPlayer(medic)) PrintCenterText(medic, "soul has disappeared...");
		g_iRespawnTarget[medic] = 0;
		g_fRespawnTimer[medic] = 0.0;
		return;
	}
	SDKCall(g_hRespawn, g_iRespawnTarget[medic]);
	if (cvarInitRevToken.IntValue > 0 && g_iReviveToken[soul] > 0 && (!g_b2MedicMode || !g_bMedicPlayer[medic])) g_iReviveToken[soul]--;
	
	if (cvarInitRevToken.IntValue > 0) {
		if (!g_b2MedicMode || !g_bMedicPlayer[medic]) PrintReviveToken(soul);
		if (cvarAllowAddRevToken.BoolValue && (!g_b2MedicMode || !g_bMedicPlayer[medic]))
		{
			g_iReviveToken[medic]++;
			CPrintToChat(medic, "{unique}You've got 1 revive token {fuchsia}for REVIVING!");
			PrintReviveToken(medic);
		}
	}

	TeleportEntity(soul, g_fDeadPosition[soul], NULL_VECTOR, NULL_VECTOR);
	g_bMedicForceToChange[medic] = false;
	g_fMedicLastHealTime[medic] = g_fGameTime;
	g_iRespawnTarget[medic] = 0;
	g_fRespawnTimer[medic] = 0.0;
	PrintCenterText(medic, "%N was revived...", soul);
	PrintCenterText(soul, "%N has revived you...", medic);
	if (g_b2MedicMode) {
		LogPlayerEvent(medic, "triggered", "revive_medic");
		if (cvarMedicBanEnable.BoolValue && g_iSkill[medic] < g_iVETS_MEDIC_SKILL) CPrintToChat(medic, "{fuchsia}MedicBan Timer is {ghostwhite}Reset {mediumspringgreen}for REVIVING!");
		g_iBonusPoint[medic] += (5*cvarBonusScore.IntValue);
	}
	else {
		LogPlayerEvent(medic, "triggered", "revive");
		g_iBonusPoint[medic] += cvarBonusScore.IntValue;
	}
	
	char sVoice[128];
	switch(GetRandomInt(1, 2))
	{
		case 1: {
			Format(sVoice, sizeof(sVoice), "lua_sounds/medic/thx/medic_thanks%d.ogg", GetRandomInt(1, 20)); // total 20 voices
			EmitSoundToAll(sVoice, soul, SNDCHAN_VOICE, _, _, 1.0);
		}
		case 2: {
			Format(sVoice, sizeof(sVoice), "lua_sounds/medic/healed/medic_healed%d.ogg", GetRandomInt(1, 39)); // total 39 voices
			EmitSoundToAll(sVoice, medic, SNDCHAN_VOICE, _, _, 1.0);
		}
	}
	return;
}

// hook
public void SHook_PlayerResourceThinkPost(int iEnt)
{
	if (cvarMedicEnable.BoolValue) {
		int offset = FindSendPropInfo("CINSPlayerResource", "m_iPlayerScore");

		int iTotalScore[MAXPLAYERS+1];
		GetEntDataArray(iEnt, offset, iTotalScore, MaxClients + 1);

		for (int i = 0;i < MAXPLAYER;i++) {
			if (g_iPlayersList[i] == -1) continue;
			if (g_iBonusPoint[g_iPlayersList[i]] > 0) {
				iTotalScore[g_iPlayersList[i]] += g_iBonusPoint[g_iPlayersList[i]];
			}
		}
		SetEntDataArray(iEnt, offset, iTotalScore, MaxClients + 1);
	}
}

//*** events
public Action Event_RoundFreezeEnd(Handle event, const char[] name, bool dontBroadcast)
{
	g_fMedicRoleTimer = g_fGameTime;
	UpdateMedicRole();

	for (int j = 0;j < MAXPLAYER; j++)
	{
		if (g_iPlayersList[j] == -1 || !IsPlayerAlive(g_iPlayersList[j])) continue;
		g_fMedicLastHealTime[g_iPlayersList[j]] = g_fGameTime;
	}
	return;
}

public Action Event_WeaponDeploy_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsFakeClient(client))
	{
		g_iPlayerDeployedWeapon[client] = GetEventInt(event, "weaponid");
	}
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsFakeClient(client))
	{
		g_iWShots[client]++;
	}
}

public Action Event_ObjectDestroyed(Event event, const char[] name, bool dontBroadcast)
{
	if (cvarInitRevToken.IntValue <= 0) return Plugin_Continue;
	for (int client = 1; client <= MaxClients; client++)
	{
		int iRandom = GetRandomInt(1, 100);
		if (iRandom <= 50 && IsValidPlayer(client) && !IsFakeClient(client) && g_iReviveToken[client]==0) {
			g_iReviveToken[client]++;
			CPrintToChat(client, "{fuchsia}LUCKY 7! {unique}You've got 1 revive token!");
			PrintReviveToken(client);
		}
	}
	return Plugin_Continue;
}

public Action Event_ControlPointCaptured(Event event, const char[] name, bool dontBroadcast)
{
	if (cvarInitRevToken.IntValue <= 0) return Plugin_Continue;
	for (int client = 1; client <= MaxClients; client++)
	{
		int iRandom = GetRandomInt(1, 100);
		if (iRandom <= 50 && IsValidPlayer(client) && !IsFakeClient(client) && g_iReviveToken[client]==0) {
			g_iReviveToken[client]++;
			CPrintToChat(client, "{fuchsia}LUCKY 7! {unique}You've got 1 revive token!");
			PrintReviveToken(client);
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (g_b2MedicMode && g_bMedicPlayer[client])
	{
		g_bMedicPlayer[client] = false;
		if (GetEventInt(event, "team") <= 1)
		{
			if (g_sClient_Org_Name[client][0] != '\0')
			{
				SetClientInfo(client, "name", g_sClient_Org_Name[client]);
				SetEntPropString(client, Prop_Data, "m_szNetname", g_sClient_Org_Name[client]);
			}
		}
	}
	//PrintToChatAll("Event_PlayerTeam Event_PlayerTeam");
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bPlayerEverDead[client] = false;
	g_bMedicPlayer[client] = false;
	g_iRank[client] = -1;
	g_iSkill[client] = -1;
	g_sClient_Org_Name[client] = "";

	char steamId[32];
	if (IsValidPlayer(client) && !IsFakeClient(client)) {
		GetClientAuthId(client, AuthId_Steam3, steamId, sizeof(steamId));
		playerList.SetValue(steamId, g_iReviveToken[client], true);
	}
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	//cvarRoundTime = FindConVar("mp_roundtime");
	playerList.Clear();
	char steamId[32];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidPlayer(i) && !IsFakeClient(i)) {
			GetClientAuthId(i, AuthId_Steam3, steamId, sizeof(steamId));
			playerList.SetValue(steamId, cvarInitRevToken.IntValue, true);
		}

		g_iReviveToken[i] = cvarInitRevToken.IntValue;
		g_bShowHalo[i] = true;
		g_bPlayerEverDead[i] = false;
		g_fDeadPosition[i][0] = 0.0;
		g_fDeadPosition[i][1] = 0.0;
		g_fDeadPosition[i][2] = 0.0;
	}
}

public Action Event_RoundEnd_Pre(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0;i < MAXPLAYER;i++)
	{
		if (g_iPlayersList[i] == -1 || !IsClientInGame(g_iPlayersList[i])) continue;
		CPrintToChat(g_iPlayersList[i], "{unique}Your Accuracy was {mediumspringgreen}%.2f{ghostwhite}\%", g_iWShots[g_iPlayersList[i]]>0?float(g_iWHits[g_iPlayersList[i]])/float(g_iWShots[g_iPlayersList[i]])*100: 0.0);
		g_fMedicLastHealTime[g_iPlayersList[i]] = g_fGameTime;
		g_bMedicForceToChange[g_iPlayersList[i]] = false;
	}
}

public Action Timer_MedicMonitor(Handle timer)
{
	if (GetGameState() != 4) return Plugin_Continue;

	g_iSecurityAlive = 0;
	g_iSecurityDead = 0;
	int iHp;
	//int iMaxHp;
	bool bMedAlive = IsMedicAlive();

	for (int i = 0;i < MAXPLAYER;i++) {
		if (g_iPlayersList[i] == -1 || !IsClientInGame(g_iPlayersList[i])) continue;
		int client = g_iPlayersList[i];
		int iTeam = GetClientTeam(client);
/* DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG 
		if (g_bMedicPlayer[client])
		{
			float fBantime = g_fMedicBannedTime[client]-g_fGameTime;
			if (g_fMedicBannedTime[client] <= 0.0) fBantime = 0.0;
			float fMedTimer = g_fGameTime-g_fMedicLastHealTime[client];
			PrintToChatAll("%s MEDtimer: %.1f medicBAN: %.1f forceChange: %d", g_sClient_Org_Name[client], fMedTimer, fBantime, g_bMedicForceToChange[client]);
		}
DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG */

		if (IsPlayerAlive(client))
		{
			g_iSecurityAlive++;
			if (g_b2MedicMode)
			{
				iHp = GetEntProp(client, Prop_Send, "m_iHealth");
				//iMaxHp = GetEntProp(client, Prop_Data, "m_iMaxHealth");
				if (bMedAlive && iHp < 100 && iTeam == TEAM_SEC) SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
				else if (g_bMedicPlayer[client]) SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
			}
		}
		else if (iTeam == TEAM_SEC)
		{
			if (cvarMedicPanelInfoEnable.BoolValue) ShowPanelInfo(client);
			if (g_bPlayerEverDead[client]) g_iSecurityDead++;
		}
	}

	int acp = GetEntData(g_nObjResource, g_nCurrentActiveObj); // Get active control point (CP)
	if (g_iCurrentControlPoint != acp && !IsCounterAttack()) {
		g_iCurrentControlPoint = acp;
		g_fMedicRoleTimer = g_fGameTime;
		UpdateMedicRole();
	}
	return Plugin_Continue;
}

void UpdateMedicRole()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i) || IsFakeClient(i)) continue;
		int iTeam = GetClientTeam(i);
		if (iTeam == TEAM_SEC)
		{
			if (!g_b2MedicMode) {
				g_bMedicPlayer[i] = true;
				//MedicChangeName(i);
			}
			else if (StrContains(g_sPlayerClass[i], g_sMedic_Class, false) != -1) {
				if (!g_bMedicPlayer[i])
				{
					g_bMedicPlayer[i] = true;
					g_fMedicLastHealTime[i] = g_fGameTime;
					MedicChangeName(i);
				}
			}
			else
			{
				g_bMedicPlayer[i] = false;
				MedicChangeName(i);
			}
		}
		else
		{
			g_bMedicPlayer[i] = false;
			MedicChangeName(i);
		}
	}
}

public Action Timer_MedicChangeName(Handle timer, int client)
{
	if (IsValidPlayer(client)) MedicChangeName(client);
	return Plugin_Continue;
}

//ONLY FOR 2 MEDIC THEATER
void MedicChangeName(int client)
{
	if (!g_b2MedicMode || !IsClientInGame(client)) return;

	char sName[MAXUSERNAME];
	GetClientInfo(client, "name", sName, MAXUSERNAME);
	if (g_bMedicPlayer[client]) {
		if (StrContains(sName, "[MEDIC]", false) == -1)
		{
			CPrintToChatAll("{unique}%s is {mediumspringgreen}[MEDIC]", g_sClient_Org_Name[client]);
			Format(sName, sizeof(sName), "[MEDIC] %s", g_sClient_Org_Name[client]);
			SetClientInfo(client, "name", sName);
			SetEntPropString(client, Prop_Data, "m_szNetname", sName);
		}
	}
	else
	{
		if (StrContains(sName, "[MEDIC]", false) != -1)
		{
			SetClientInfo(client, "name", g_sClient_Org_Name[client]);
			SetEntPropString(client, Prop_Data, "m_szNetname", g_sClient_Org_Name[client]);
		}
	}
}

public Action Event_PlayerPickSquad(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	GetEventString(event, "class_template", g_sPlayerClass[client], 64);
	g_bMedicPlayer[client] = false;

	if (!IsFakeClient(client) && GetClientTeam(client) == TEAM_INS) g_bPlayerEverDead[client] = false;
	if(IsValidPlayer(client) && GetClientTeam(client) == TEAM_SEC && strlen(g_sPlayerClass[client]) > 1)
	{
		if (g_iSkill[client] <= 0) GetGameme(client);
		if (StrContains(g_sPlayerClass[client], g_sMedic_Class, false) != -1)
		{
			g_iRespawnTarget[client] = 0;
			g_fRespawnTimer[client] = 0.0;
			g_bMedicPlayer[client] = true;
			g_fMedicLastHealTime[client] = g_fGameTime;
			g_bMedicForceToChange[client] = false;
			if (g_b2MedicMode)
			{
				if (g_fGameTime > g_fMedicBannedTime[client])
				{
					//g_iRank[client]
					if (!cvarMedicSkillCheck.BoolValue || g_iSkill[client] >= cvarMedicMinPoint.IntValue || FindQualifiedMedic() <= 0 )
					{
						if (cvarMedicBanEnable.BoolValue && g_b2MedicMode) Medic_ShowPopupMenu(client);
						g_fMedicBannedTime[client] = 0.0;

						//PrintToChatAll("MedicRoleTimer: %.2f", g_fGameTime - g_fMedicRoleTimer);
						if (g_fGameTime - g_fMedicRoleTimer > cvarMedicRoleTimer.FloatValue) {
							g_bMedicPlayer[client] = false;
							CPrintToChat(client, "%d sec passed. {ghostwhite}You will be {mediumspringgreen}MEDIC {fuchsia}next objective!", cvarMedicRoleTimer.IntValue);
						}
					}
					else
					{
						FindQualifiedMedic(client);
						g_bMedicPlayer[client] = false;
						g_sPlayerClass[client] = "";
						ChangeClientTeam(client, TEAM_SPEC);
						PrintCenterText(client, "Min gameMe skill is %d\n \nto play MEDIC role!", cvarMedicMinPoint.IntValue);
						CPrintToChat(client, "{orangered}Min gameMe skill is {ghostwhite}%d {orangered}to play {mediumspringgreen}MEDIC {orangered}role!", cvarMedicMinPoint.IntValue);
						if (GetRandomInt(0, 3) != 0)
							ClientCommand(client, "playgamesound Radial_Security.Subordinate_%s_Negative_Radio", GetRandomInt(0, 3) != 0 ? "UnSupp" : "Supp");
						else
							ClientCommand(client, "playgamesound Radial_Security.Leader_%s_Negative_Radio", GetRandomInt(0, 3) != 0 ? "UnSupp" : "Supp");
					}
				}
				else
				{
					g_bMedicPlayer[client] = false;
					float fBanTime = g_fMedicBannedTime[client]-g_fGameTime;
					g_sPlayerClass[client] = "";
					ChangeClientTeam(client, TEAM_SPEC);
					PrintCenterText(client, "You are banned to play Medic for %0.0fs\n \nYou need to revive players as Medic", fBanTime);
					PrintToChat(client, "\x04You are banned to play Medic for \x01%0.0fs, \x05You need to revive players as Medic", fBanTime);
					if (GetRandomInt(0, 3) != 0)
						ClientCommand(client, "playgamesound Radial_Security.Subordinate_%s_Negative_Radio", GetRandomInt(0, 3) != 0 ? "UnSupp" : "Supp");
					else
						ClientCommand(client, "playgamesound Radial_Security.Leader_%s_Negative_Radio", GetRandomInt(0, 3) != 0 ? "UnSupp" : "Supp");
					//return Plugin_Continue;
				}
				if (g_bMedicPlayer[client]) PrintCenterTextAll("%s is MEDIC!", g_sClient_Org_Name[client]);
				MedicChangeName(client);
			}
		}
		else if (g_b2MedicMode) MedicChangeName(client);
	}
	return Plugin_Continue;
}

public Action Event_PlayerPickSquad_Post(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if (!IsValidPlayer(client) || GetClientTeam(client) == TEAM_INS) return;
	
	char class_template[64];
	GetEventString(event, "class_template",class_template,sizeof(class_template));

	if (strlen(class_template) > 1) {
		if (StrContains(class_template, "sergeant", false) != -1) Format(g_sTagClass[client], 64, "[Sergeant]");
		else if (StrContains(class_template, "specialist", false) != -1) Format(g_sTagClass[client], 64, "[Specialist]");
		else if (StrContains(class_template, "engineer", false) != -1) Format(g_sTagClass[client], 64, "[Engineer]");
		else if (StrContains(class_template, "vip", false) != -1) Format(g_sTagClass[client], 64, "[VIP]");
		else if (StrContains(class_template, "medic", false) != -1) Format(g_sTagClass[client], 64, "[Medic]");
		else if (StrContains(class_template, "pilot", false) != -1) Format(g_sTagClass[client], 64, "[Pilot]");
		else if (StrContains(class_template, "rifleman", false) != -1) Format(g_sTagClass[client], 64, "[Rifleman]");
		else if (StrContains(class_template, "recon", false) != -1) Format(g_sTagClass[client], 64, "[Recon]");
		else if (StrContains(class_template, "marksman", false) != -1) Format(g_sTagClass[client], 64, "[Marksman]");
		else if (StrContains(class_template, "sniper", false) != -1) Format(g_sTagClass[client], 64, "[Sniper]");
		else if (StrContains(class_template, "demolition", false) != -1) Format(g_sTagClass[client], 64, "[Demolition]");
		else if (StrContains(class_template, "breacher", false) != -1) Format(g_sTagClass[client], 64, "[Breacher]");
		else if (StrContains(class_template, "grenadier", false) != -1) Format(g_sTagClass[client], 64, "[Grenadier]");
		else if (StrContains(class_template, "suppot", false) != -1) Format(g_sTagClass[client], 64, "[Support]");
	}
}

public Action Command_ListPlayer(int client, int args)
{
	int medic;
	int iCount = 0;
	char sSkill[32];

	if (client > 0) PrintToConsole(client, "[Players Skill]");
	for (int i = 0;i < MAXPLAYER;i++)
	{
		if (g_iPlayersList[i] == -1) continue;
		medic = g_iPlayersList[i];
		//if (g_iSkill[medic] > 0)

		iCount++;
		FormatNumber(g_iSkill[medic], sSkill, sizeof(sSkill));
		//CPrintToChatAll("{ghostwhite}%d. {mediumspringgreen}%s {unique}(skill: %s)", iCount, g_sClient_Org_Name[medic], sSkill);
		if (client > 0) PrintToConsole(client, "%d. %s (skill: %s)", iCount, g_sClient_Org_Name[medic], sSkill);
		PrintToServer("%d. %s (skill: %s)", iCount, g_sClient_Org_Name[medic], sSkill);
	}
	return Plugin_Handled;
}

int FindQualifiedMedic(int client=0)
{
	int medic;
	int iCount = 0;
	char sSkill[32];
	for (int i = 0;i < MAXPLAYER;i++)
	{
		if (g_iPlayersList[i] == -1) continue;
		medic = g_iPlayersList[i];
		if (GetClientTeam(medic) == TEAM_SEC && !g_bMedicPlayer[medic] && StrContains(g_sPlayerClass[medic], g_sMedic_Class, false) == -1 && g_iSkill[medic] >= cvarMedicMinPoint.IntValue && g_fGameTime > g_fMedicBannedTime[medic])
		{
			iCount++;
			if (client>0)
			{
				FormatNumber(g_iSkill[medic], sSkill, 32);
				CPrintToChatAll("{ghostwhite}Qualified Medic: %d. {mediumspringgreen}%s {unique}(skill: %s)", iCount, g_sClient_Org_Name[medic], sSkill);
			}
		}
	}
	if (client>0)
	{
		FormatNumber(g_iSkill[client], sSkill, 32);
		CPrintToChatAll("{ghostwhite}[{fuchsia}%s {unique}(skill: %s) {ghostwhite}need %s to be {mediumspringgreen}MEDIC{ghostwhite}]", g_sClient_Org_Name[client], g_iSkill[client]<=0? "0":sSkill, g_sMedicMinPoint);
	}
	return iCount;
}

public void Medic_ShowPopupMenu(int client)
{
	if (client <= 0 || !IsClientInGame(client) || g_iSkill[client] < g_iVETS_MEDIC_SKILL) return;
	if (!IsPlayerAlive(client))
		SetEntProp(client, Prop_Send, "m_iHideHUD", (1<<3));

	Handle panel = CreatePanel(GetMenuStyleHandle(MenuStyle_Radio));
	//int iCloseNumber = GetRandomInt(4, 9);

	char sMessage[64];
	FormatEx(sMessage, sizeof(sMessage), "If you don't revive/heal over %d sec,", cvarMedicBanTimer.IntValue);

	SetPanelTitle(panel, "You are playing as  [MEDIC]");
	DrawPanelText(panel, " ");
	DrawPanelItem(panel, "Revive player by standing near marked spot."); // 1
	DrawPanelItem(panel, "Heal others by using Healthkit right-mouse."); //2
	DrawPanelText(panel, " ");
	DrawPanelText(panel, "Revive or Heal to Max Health,");
	DrawPanelText(panel, "to reset MedicBan timer.");
	DrawPanelText(panel, " ");
	DrawPanelText(panel, "F key to find souls with laser.");
	DrawPanelText(panel, "Injured teammate will Glow.");
	DrawPanelText(panel, " ");
	DrawPanelText(panel, sMessage);
	DrawPanelText(panel, "Class will be changed!");

	for (int i = 3; i < 9; i++)
		DrawPanelItem(panel, "", ITEMDRAW_NOTEXT);
	DrawPanelItem(panel, "Confirm and Close"); // iCloseNumber

	SendPanelToClient(panel, client, NullMenuHandler, 10);
	CloseHandle(panel);
}

void ShowPanelInfo(int client)
{
	if (GetGameState() != 4 || IsVoteInProgress()) return;

	//m_iObserverMode=4 = 1st view
	//m_iObserverMode=5 = 3rd view
	if (g_bShowPanel[client] && IsClientObserver(client) && GetEntProp(client, Prop_Send, "m_iObserverMode") == 5)
	{
		//get target client
		int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		if (IsValidPlayer(target))
		{
			int iFlag = GetEntProp(client, Prop_Send, "m_iHideHUD");
			if (iFlag & HIDEHUD_MISCSTATUS) SetEntProp(client, Prop_Send, "m_iHideHUD", iFlag & ~HIDEHUD_MISCSTATUS);
			//SetEntProp(client, Prop_Send, "m_iHideHUD", 2059);
			if (client == target || GetClientTeam(target) == TEAM_INS) return;

			//get accuracy & kpd
			float fKPD = 0.0;
			if (g_iDeaths[target]>0) fKPD = float(g_iKills[target])/float(g_iDeaths[target]);
			else fKPD = float(g_iKills[target]);

			char sPrintAccuracy[32];
			//Format(sPrintAccuracy, sizeof(sPrintAccuracy), "Accuracy: %.2f\%", g_iWShots[target]>0?float(g_iWHits[target])/float(g_iWShots[target])*100: 0.0);
			if (g_iSkill[target] > 0) Format(sPrintAccuracy, sizeof(sPrintAccuracy), "Current Acc/Kpd: %.1f | %.1f", g_iWShots[target]>0?float(g_iWHits[target])/float(g_iWShots[target])*100:0.0, fKPD);
			else Format(sPrintAccuracy, sizeof(sPrintAccuracy), "Acc/Kpd: %.1f | %.1f", g_iWShots[target]>0?float(g_iWHits[target])/float(g_iWShots[target])*100:0.0, fKPD);

			//get health
			char sPrintHealth[32];
			Format(sPrintHealth, sizeof(sPrintHealth), "Health: %i", GetClientHealth(target));
			//Format(sPrintHealth, sizeof(sPrintHealth), "%s  |  HP: %i", sPrintKD, GetClientHealth(target));

			//get name
			char TargetName[56];
			GetClientName(target, TargetName, sizeof(TargetName));
			//get weapon
			char TargetWeapon[32];
			char sPrintWeapon[64];
			int weapon = GetEntPropEnt(target, Prop_Data, "m_hActiveWeapon");
			if (weapon != -1 && IsValidEntity(weapon))
			{
				GetEntityClassname(weapon, TargetWeapon, sizeof(TargetWeapon));
			}
			ReplaceString(TargetWeapon, sizeof(TargetWeapon), "weapon_doi2ins_", "");
			ReplaceString(TargetWeapon, sizeof(TargetWeapon), "weapon_sandstorm_", "");
			ReplaceString(TargetWeapon, sizeof(TargetWeapon), "weapon_", "");
			ReplaceString(TargetWeapon, sizeof(TargetWeapon), "_", " ");
			String_ToUpper(TargetWeapon, TargetWeapon, sizeof(TargetWeapon));
			Format(sPrintWeapon, sizeof(sPrintWeapon), "Weapon: %s", TargetWeapon);
			//get rank & skill info
			char sSkill[32];
			FormatNumber(g_iSkill[target], sSkill, sizeof(sSkill));
			char sPrintInfo1[64], sPrintInfo2[64];
			Format(sPrintInfo1, sizeof(sPrintInfo1), "Rank: %d  Skill: %s", g_iRank[target], sSkill);
			Format(sPrintInfo2, sizeof(sPrintInfo2), "Acc: %.1f  Kpd: %.1f", g_fAccuracy[target], g_fKPD[target]);

			//get class
			char sPrintClass[32];
			if (GetUserAdmin(target) == INVALID_ADMIN_ID) Format(sPrintClass, sizeof(sPrintClass), "%s", g_sTagClass[target]);
			else Format(sPrintClass, sizeof(sPrintClass), "%s  (A)", g_sTagClass[target]);

			Handle DetailsPanel = CreatePanel(INVALID_HANDLE);
			//DRAW PANEL DETAILS
			DrawPanelText(DetailsPanel, TargetName);
			if (g_iSkill[target] > 0)
			{
				DrawPanelText(DetailsPanel, sPrintInfo1);
				DrawPanelText(DetailsPanel, sPrintInfo2);
			}
			DrawPanelText(DetailsPanel, sPrintClass);
			DrawPanelText(DetailsPanel, sPrintWeapon);
			DrawPanelText(DetailsPanel, sPrintAccuracy);
			//DrawPanelText(DetailsPanel, sPrintKD);
			DrawPanelText(DetailsPanel, sPrintHealth);
			if (g_iSkill[target] > 0)
			{
				DrawPanelText(DetailsPanel, " ");
				if (StrContains(g_ServerName, "TUG GG", false) != -1) DrawPanelText(DetailsPanel, "Stat: tug.gg");
				else DrawPanelText(DetailsPanel, "Stat: masterchief.gg");
			}
			SendPanelToClient(DetailsPanel, client, NullMenuHandler, 1);
			CloseHandle(DetailsPanel);
		}
	}
	return;
}

public int NullMenuHandler(Handle menu, MenuAction action, int client, int select) 
{
}

public int Handler_MedicMenu(Handle menu, MenuAction action, int client, int select)
{
	if (action == MenuAction_Select)
	{
		if (select < 4)
			Medic_ShowPopupMenu(client);
		else FakeClientCommand(client, "use weapon_healthkit");
	}
}

public Action Event_PlayerChangeName_Pre(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientInGame(client)) return Plugin_Continue;
	if (GetClientTeam(client) != TEAM_SEC) return Plugin_Continue;

	CreateTimer(0.1, Timer_MedicChangeName, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

public Action Event_PlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int aTeam = (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) ? GetClientTeam(attacker) : -1);

	if (attacker > 0 && attacker != client && GetClientTeam(client) != aTeam)
	{
		int damagetype = GetEventInt(event, "damagebits");
		if ((damagetype & DMG_BULLET) && g_fLastHitTime[attacker] != GetGameTime())
		{
			g_iWHits[attacker]++;
			g_fLastHitTime[attacker] = GetGameTime();
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerDeath_Pre(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (g_iGameState != 4 && !IsValidPlayer(victim)) return Plugin_Continue;

	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int vTeam = GetClientTeam(victim);
	int aTeam = (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))?GetClientTeam(attacker):-1;

	g_iDeaths[victim]++;
	if (vTeam != aTeam)
	{
		g_iKills[attacker]++;
		//g_iDeaths[victim]++;
		if (g_iSkill[attacker] > 0 && FloatFraction(g_iKills[attacker]/50.0) == 0.0) GetGameme(attacker);
	}

	if (IsFakeClient(victim) || vTeam != TEAM_SEC) return Plugin_Continue;

	CPrintToChat(victim, "{unique}Your Accuracy was {mediumspringgreen}%.2f{ghostwhite}\%", g_iWShots[victim]>0?float(g_iWHits[victim])/float(g_iWShots[victim])*100: 0.0);
	if (g_iSkill[victim] <= 0) GetGameme(victim);

	if (vTeam == TEAM_SEC)
	{
		g_bPlayerEverDead[victim] = true;
		if (GetEntPropFloat(victim, Prop_Data, "m_flLocalTime") > 0.0)
		{
			g_bPlayerEverDead[victim] = false;
			PrintToChat(victim, "\x07F8F8FF You can't be\x0700FA9A Revived\x07F8F8FF for using\x07FF4500 MC-IED");
		}
		//CreateTimer(0.02, Timer_CheckMCIED, victim, TIMER_FLAG_NO_MAPCHANGE);
	}
	GetClientAbsOrigin(victim, g_fDeadPosition[victim]);

	//HALO
	if(g_bShowHalo[victim]) CreateTimer(0.5, Timer_ShowHalo, _, TIMER_FLAG_NO_MAPCHANGE); //added by CHS
	//END HALO

	if (g_bMedicPlayer[victim] && g_fRespawnTimer[victim] > 0.0) {
		PrintCenterText(victim, "Cancel reviving...");
		g_iRespawnTarget[victim] = 0;
		g_fRespawnTimer[victim] = 0.0;
	}

	if (cvarTKlostToken.BoolValue && cvarInitRevToken.IntValue > 0) {
		int iDamage = GetEventInt(event, "damagebits");
		if (!(iDamage & DMG_BURN) && vTeam == aTeam && victim != attacker) {
			g_iReviveToken[victim]++;
			CPrintToChat(victim, "{unique}You've got 1 revive token {fuchsia}for being Team Killed!");
			PrintReviveToken(victim);

			if (aTeam == TEAM_SEC && g_iReviveToken[attacker]>0) {
				g_iReviveToken[attacker]--;
				CPrintToChat(attacker, "{unique}You LOST 1 token {fuchsia}for TEAM KILLING!");
				PrintReviveToken(attacker);
			}
		}
	}

	if (cvarMedicBanEnable.BoolValue && g_bMedicForceToChange[victim] && g_bMedicPlayer[victim])
	{
		g_bMedicPlayer[victim] = false;
		SetClientInfo(victim, "name", g_sClient_Org_Name[victim]);
		SetEntPropString(victim, Prop_Data, "m_szNetname", g_sClient_Org_Name[victim]);
		g_fMedicBannedTime[victim] = g_fGameTime+cvarMedicBannedTime.FloatValue;
		CPrintToChat(victim, "{ghostwhite}You are {orangered}BANNED {mediumspringgreen}as MEDIC {ghostwhite}for %ds", cvarMedicBannedTime.IntValue);

		g_sPlayerClass[victim] = "";
		ChangeClientTeam(victim, TEAM_SPEC);
		CreateTimer(0.1, Timer_MoveToSurvivors, victim, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(0.11, Timer_LostMedic, victim, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public Action Timer_CheckMCIED(Handle timer, int client)
{
	if (GetEntPropFloat(client, Prop_Data, "m_flLocalTime") > 0.0) g_bPlayerEverDead[client] = false;
}

public Action Timer_MoveToSurvivors(Handle timer, any client)
{
	if (IsClientInGame(client)) ChangeClientTeam(client, TEAM_SEC);
}

public Action Timer_LostMedic(Handle timer, any client)
{
	if (IsClientInGame(client))
	{
		char sMessage[256];
		FormatEx(sMessage, 256, "[Medic] %N has been removed as MEDIC due to not reviving teammate", client);
		//MC_discordMsg(sMessage);
		ServerCommand("discordmsg %s", sMessage);
		CPrintToChatAll("{unique}%N {ghostwhite}has been removed as {mediumspringgreen}MEDIC {ghostwhite}due to not reviving teammate", client);
	}
}

public Action cmd_MChalo(int client, int args)
{
	if (cvarInitRevToken.IntValue <= 0) return Plugin_Handled; //won't work if infinite token

	g_bShowHalo[client] = !g_bShowHalo[client];
	CPrintToChat(client, "{unique}Revive Halo: {crimson}%s", g_bShowHalo[client] ? "ENABLED!" : "DISABLED!");
	if(g_bShowHalo[client]) CreateTimer(0.0, Timer_ShowHalo, _, TIMER_FLAG_NO_MAPCHANGE); //added by CHS
	return Plugin_Handled;
}

bool IsMedicAlive() {
	bool bValue = false;
	for (int i = 0;i < MAXPLAYER;i++)
	{
		if (g_iPlayersList[i] == -1) continue;
		if (IsPlayerAlive(g_iPlayersList[i]) && g_bMedicPlayer[g_iPlayersList[i]])
		{
			bValue = true;
			break;
		}
	}
	return bValue;
}

Action Timer_ShowHalo(Handle timer)
{
	if (GetGameState() != 4 || !cvarMedicEnable.BoolValue || !cvarHaloEnable.BoolValue || !IsMedicAlive()) return Plugin_Continue;
	float fHalo[3];

	for (int soul = 1; soul <= MaxClients; soul++)
	{
		//if (!IsClientInGame(soul) || IsPlayerAlive(soul)) continue;
		//if (!IsValidPlayer(soul) || IsFakeClient(soul) || IsPlayerAlive(soul) || GetClientTeam(soul) != TEAM_SEC) continue;
		if (!IsValidPlayer(soul) || IsPlayerAlive(soul) || GetClientTeam(soul) != TEAM_SEC || !g_bPlayerEverDead[soul] || (cvarInitRevToken.IntValue > 0 && (g_iReviveToken[soul] <= 0 || !g_bShowHalo[soul]))) continue;

		fHalo = g_fDeadPosition[soul];
		float beamPos[3];
		float end[3];
		beamPos = fHalo;
		end = fHalo;
		end[2] += 140.0; //height of green beam added by CHS
		beamPos[2] += 5; //changed by CHS array[2] is RED halo height

		//reference
		//TE_SetupBeamPoints(const float start[3], const float end[3], int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float EndWidth, int FadeLength, float Amplitude, const int Color[4], int Speed)
		//TE_SetupBeamRingPoint(const float center[3], float Start_Radius, float End_Radius, int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float Amplitude, const int Color[4], int Speed, int Flags)

		for (int effect=1 ;effect<=4; effect++)
		{
			switch(effect){
				case 1:{
					end[2] -= 70.0;
					TE_SetupBeamPoints(beamPos, end, g_iBeaconBeam, 0, 0, 0, 2.7, 1.0, 1.0, 0, 0.0, orangeColor, 0);
					end[2] += 70.0;
				}
				case 2:{
					beamPos[2] += 70;
					TE_SetupBeamPoints(beamPos, end, g_iBeaconBeam, 0, 0, 0, 2.7, 1.0, 1.0, 0, 0.0, greenColor, 0);
					beamPos[2] -= 70;
				}
				case 3:{
					beamPos[2] += 4.5;
					TE_SetupBeamRingPoint(beamPos, 55.0, 20.0, g_iBeaconBeam, g_iBeaconHalo, 0, 0, 3.0, 2.5, 0.0, greenColor, 10, 0);
					beamPos[2] -= 4.5;
				}
				case 4:{
					TE_SetupBeamRingPoint(beamPos, 20.0, 55.0, g_iBeaconBeam, g_iBeaconHalo, 0, 0, 3.0, 3.0, 0.0, redColor, 10, 0);
				}
			}
			TE_SendToAll();
		}
	}
	return Plugin_Continue;
}

void PrintReviveToken(int client) {
	CPrintToChat(client, "{fuchsia}Your revive token {deepskyblue}is now: {ghostwhite}%d", g_iReviveToken[client]);
	if (g_iReviveToken[client] == 0) CPrintToChat(client, "{unique}CAREFULL! {deepskyblue}YOU {fullred}CAN'T {deepskyblue}BE REVIVED AFTER THIS!");
}

public void PrecacheSound_medic()
{
	PrecacheSoundNumbers("lua_sounds/medic/letme/medic_letme_heal", ".ogg", 1, 10, false);
	PrecacheSoundNumbers("lua_sounds/medic/healed/medic_healed", ".ogg", 1, 39, false);
	PrecacheSoundNumbers("lua_sounds/medic/thx/medic_thanks", ".ogg", 1, 20, false);

	//in masterchief-assets-two.vpk
	//PrecacheSoundNumbers("medic/healed/medic_healed", ".ogg", 1, 39, false);
	//PrecacheSoundNumbers("medic/thanks/medic_thanks", ".ogg", 1, 20, false);
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

bool IsCounterAttack()
{
	return view_as<bool>(GameRules_GetProp("m_bCounterAttack")); //result int = 0 or 1
}

// etc
stock bool FormatNumber(int value, char[] buffer, int size, char[] seperator=',')
{
	buffer[0] = '\0';
	int divisor = 1000;

	while (value >= 1000 || value <= -1000) {
		int offcut = value % divisor;
		value = RoundToFloor(float(value) / float(divisor));

		Format(buffer, size, "%c%03.d%s", seperator, offcut, buffer);
	}

	Format(buffer, size, "%d%s", value, buffer);
	//return true;
}

stock bool String_ToUpper(const char[] input, char[] output, int size)
{
	size--;

	int x=0;
	while (input[x] != '\0' && x < size) {
		
		output[x] = CharToUpper(input[x]);
		
		x++;
	}

	output[x] = '\0';
}

public Action Command_MCpanel(int client, int args)
{
	if (client <= 0)return Plugin_Handled;

	g_bShowPanel[client] = !g_bShowPanel[client];
	CPrintToChat(client, "{unique}Spectating Panel: {crimson}%s", g_bShowPanel[client] ? "ENABLED!" : "DISABLED!");
	
	return Plugin_Handled;
}

public void GetGameme(int client)
{
	if (!g_bGameme) return;
	QueryGameMEStats("playerinfo", client, QuerygameMEStatsCallback, QUERY_TYPE_ONCLIENTPUTINSERVER);
}

stock bool String_StartsWith(const char[] str, const char[] subString)
{
	int n = 0;
	while (subString[n] != '\0') {

		if (str[n] == '\0' || str[n] != subString[n]) {
			return false;
		}

		n++;
	}
	return true;
}

int GetGameState()
{
	return GameRules_GetProp("m_iGameState");
}

public bool IsValidPlayer(int client) {
	return (0 < client <= MaxClients) && IsClientInGame(client);
}
