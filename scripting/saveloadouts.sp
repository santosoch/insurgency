/* inspired by Nullifidian */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo = {
	name = "[INS] saveloadouts",
	author = "Bot Chris",
	description = "Save Loadout Public",
	version = "1.0",
	url = ""
};

#define INS_PL_BUYZONE (1 << 7)

Database SQLiteDB = null;
bool g_bUsedSaveLoBefore[MAXPLAYERS+1];
bool g_bClassSaveLoBefore[MAXPLAYERS+1];

//cooldown for commands
int loload_cooldowntime[MAXPLAYERS+1] = {-1, ...};
int losave_cooldowntime[MAXPLAYERS+1] = {-1, ...};

//cooldown for ads
int ad_cooldowntime[MAXPLAYERS+1] = {-1, ...};

//strings
char g_sPlayerClassTemplate[MAXPLAYERS+1][64];
char g_sPlayerSaveloClass[MAXPLAYERS+1][64];
char g_sPlayerSteamID[MAXPLAYERS+1][32];
char g_sGameMode[32];

public void OnPluginStart()
{
	char error[255];

	SQLiteDB = SQLite_UseDatabase("saveloadout", error, sizeof(error));
	if (SQLiteDB == INVALID_HANDLE)
		SetFailState(error);

	SQL_LockDatabase(SQLiteDB);
	SQL_FastQuery(SQLiteDB, "CREATE TABLE IF NOT EXISTS saveloadout (steamid TEXT NOT NULL, classname TEXT NOT NULL, type TEXT NOT NULL, itemid TEXT);");
	SQL_FastQuery(SQLiteDB, "CREATE INDEX IF NOT EXISTS data_idx ON saveloadout(steamid, classname);");
	SQL_UnlockDatabase(SQLiteDB);


	HookEvent("round_freeze_end", Event_RoundFreezeEnd);
	HookEvent("player_pick_squad", Event_PlayerPickSquad_Post, EventHookMode_Post);

	RegConsoleCmd("inventory_reset", inventory_reset_cmd);		//loads saved loadout when player press reset button in inventory
	RegConsoleCmd("inventory_confirm", inventory_confirm_cmd);	//display ad(with cooldown) about save loadout
	RegConsoleCmd("inventory_resupply", inventory_confirm_cmd);	//display ad(with cooldown) about save loadout
	RegConsoleCmd("savelo", losave_cmd, "Save your loadout");
}

public void OnMapStart()
{
	PrecacheSound("ui/vote_success.wav", true);
	GetConVarString(FindConVar("mp_gamemode"), g_sGameMode, sizeof(g_sGameMode));
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client)) return;

	g_bUsedSaveLoBefore[client] = false;
	g_bClassSaveLoBefore[client] = false;
	losave_cooldowntime[client] = 0;
	loload_cooldowntime[client] = 0;
	ad_cooldowntime[client] = 0;
	g_sPlayerSaveloClass[client] = "";
	GetClientAuthId(client, AuthId_Steam2, g_sPlayerSteamID[client], sizeof(g_sPlayerSteamID[]));

	DBResultSet rs;
	char query[255];
	char error[255];
	Format(query, sizeof(query), "SELECT steamid FROM saveloadout WHERE steamid = '%s'", g_sPlayerSteamID[client]);

	if ((rs = SQL_Query(SQLiteDB, query)) == null)
	{
		SQL_GetError(SQLiteDB, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		LogMessage("[savelo] Failed to query (error: %s)", error);
		return;
	} 
	if (rs.RowCount > 0)
	{
		g_bUsedSaveLoBefore[client] = true;
	}
	delete rs;
}

public Action Event_PlayerPickSquad_Post(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsFakeClient(client)) return Plugin_Continue;

	GetEventString(event, "class_template", g_sPlayerClassTemplate[client], sizeof(g_sPlayerClassTemplate[]));
	int CurrentTime = GetTime();
	
	if (!StrEqual(g_sPlayerClassTemplate[client], g_sPlayerSaveloClass[client])) g_bClassSaveLoBefore[client] = false;
	if (!g_bClassSaveLoBefore[client])
	{
		DBResultSet rs;
		char query[255];
		char error[255];
		Format(query, sizeof(query), "SELECT steamid, classname FROM saveloadout WHERE steamid = '%s' AND classname = '%s'", g_sPlayerSteamID[client], g_sPlayerClassTemplate[client]);

		if ((rs = SQL_Query(SQLiteDB, query)) == null)
		{
			SQL_GetError(SQLiteDB, error, sizeof(error));
			PrintToServer("Failed to query (error: %s)", error);
			LogMessage("[savelo] Failed to query (error: %s)", error);
			return Plugin_Continue;
		}
		if (rs.RowCount > 0)
		{
			rs.FetchString(1, g_sPlayerSaveloClass[client], sizeof(g_sPlayerSaveloClass[]));
			g_bUsedSaveLoBefore[client] = true;
			g_bClassSaveLoBefore[client] = true;
		}
		delete rs;
	}

	if (CurrentTime-loload_cooldowntime[client] > 3)
	{
		if (g_bClassSaveLoBefore[client])
		{
			loload_cmd(client);
			loload_cooldowntime[client] = CurrentTime;
		}
	}
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	g_bUsedSaveLoBefore[client] = false;
	g_bClassSaveLoBefore[client] = false;
}

public Action Event_RoundFreezeEnd(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidPlayer(client) || IsFakeClient(client)) return Plugin_Continue;

	if (!g_bUsedSaveLoBefore[client]) PrintToChatAll("\x07FFD700[savelo]\x01 You can save your loadout with a \x0700FA9A!savelo\x01 chat command.");
	return Plugin_Continue;
}

public Action losave_cmd(int client, int args)
{
	if (IsFakeClient(client) || client <= 0) return Plugin_Handled;

	if (StrEqual(g_sGameMode, "checkpoint"))
	{
		int iFlags = GetEntProp(client, Prop_Send, "m_iPlayerFlags");
		if (!(iFlags & INS_PL_BUYZONE))
		{
			PrintToChat(client,"\x0700FA9A[savelo]\x07F8F8FF You must be\x0700FA9A IN\x07FFD700 BUYING/RESUPPLY\x07F8F8FF ZONE");
			return Plugin_Handled;
		}
	}

	int CurrentTime = GetTime();
	if (CurrentTime-losave_cooldowntime[client] <= 3)
	{
		PrintToChat(client, "\x0700FA9A[savelo]\x01 You must wait before using savelo command again.");
		return Plugin_Handled;
	}
	losave_cooldowntime[client] = CurrentTime;

	FakeClientCommand(client, "inventory_confirm");
	char sBuffer[64];
	char error[255];
	char query[255];
	char sType[32];

	//player gears
	int gearoffset = GetEntSendPropOffs(client, "m_EquippedGear", true);
	sBuffer = "";
	if (gearoffset != -1)
	{
		int iGearID = GetEntData(client, gearoffset);
		Format(sBuffer, sizeof(sBuffer), "%d", iGearID);
		for (int i = 4; i <= 24; i+=4) {
			iGearID = GetEntData(client, gearoffset + i);
			if (iGearID != -1) Format(sBuffer, sizeof(sBuffer), "%s;%d", sBuffer, iGearID);
		}
	}
	sType = "gear";
	DBResultSet rs;
	Format(query, sizeof(query), "SELECT steamid, classname, type, itemid FROM saveloadout WHERE steamid = '%s' AND classname = '%s' AND type = '%s'", g_sPlayerSteamID[client], g_sPlayerClassTemplate[client], sType);

	if ((rs = SQL_Query(SQLiteDB, query)) == null)
	{
		SQL_GetError(SQLiteDB, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		LogMessage("[savelo] Failed to query (error: %s)", error);
		return Plugin_Handled;
	}
	if (rs.RowCount > 0) UpdateWeaponRecord(client, sType, sBuffer);
	else AddWeaponRecord(client, sType, sBuffer);
	delete rs;

	int primaryWeapon = GetPlayerWeaponSlot(client, 0);
	int secondaryWeapon = GetPlayerWeaponSlot(client, 1);
	int playerGrenades = GetPlayerWeaponSlot(client, 3);

	sBuffer = "";
	if (primaryWeapon != -1)
	{
		int iWeaponID = GetEntProp(primaryWeapon, Prop_Send, "m_hWeaponDefinitionHandle");
		Format(sBuffer, sizeof(sBuffer), "%d", iWeaponID);
		int upoffset = GetEntSendPropOffs(primaryWeapon, "m_upgradeSlots", true);
		for (int i = 0; i <= 32; i+=4) {
			int iAttachID = GetEntData(primaryWeapon, upoffset + i);
			if (iAttachID != -1) Format(sBuffer, sizeof(sBuffer), "%s;%d", sBuffer, iAttachID);
		}
	}
	sType = "primary";
	Format(query, sizeof(query), "SELECT steamid, classname, type, itemid FROM saveloadout WHERE steamid = '%s' AND classname = '%s' AND type = '%s'", g_sPlayerSteamID[client], g_sPlayerClassTemplate[client], sType);

	if ((rs = SQL_Query(SQLiteDB, query)) == null)
	{
		SQL_GetError(SQLiteDB, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		LogMessage("[savelo] Failed to query (error: %s)", error);
		return Plugin_Handled;
	}
	if (rs.RowCount > 0) UpdateWeaponRecord(client, sType, sBuffer);
	else AddWeaponRecord(client, sType, sBuffer);
	delete rs;

	sBuffer = "";
	if (secondaryWeapon != -1)
	{
		int iWeaponID = GetEntProp(secondaryWeapon, Prop_Send, "m_hWeaponDefinitionHandle");
		Format(sBuffer, sizeof(sBuffer), "%d", iWeaponID);
		int upoffset = GetEntSendPropOffs(secondaryWeapon, "m_upgradeSlots", true);
		for (int i = 0; i <= 32; i+=4) {
			int iAttachID = GetEntData(secondaryWeapon, upoffset + i);
			if (iAttachID != -1) Format(sBuffer, sizeof(sBuffer), "%s;%d", sBuffer, iAttachID);
		}
	}
	sType = "secondary";
	Format(query, sizeof(query), "SELECT steamid, classname, type, itemid FROM saveloadout WHERE steamid = '%s' AND classname = '%s' AND type = '%s'", g_sPlayerSteamID[client], g_sPlayerClassTemplate[client], sType);

	if ((rs = SQL_Query(SQLiteDB, query)) == null)
	{
		SQL_GetError(SQLiteDB, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		LogMessage("[savelo] Failed to query (error: %s)", error);
		return Plugin_Handled;
	}
	if (rs.RowCount > 0) UpdateWeaponRecord(client, sType, sBuffer);
	else AddWeaponRecord(client, sType, sBuffer);
	delete rs;

	sBuffer = "";
	if (playerGrenades != -1)
	{
		int iWeaponID = GetEntProp(playerGrenades, Prop_Send, "m_hWeaponDefinitionHandle");
		Format(sBuffer, sizeof(sBuffer), "%d", iWeaponID);
		int upoffset = GetEntSendPropOffs(playerGrenades, "m_upgradeSlots", true);
		for (int i = 0; i <= 32; i+=4) {
			int iAttachID = GetEntData(playerGrenades, upoffset + i);
			if (iAttachID != -1) Format(sBuffer, sizeof(sBuffer), "%s;%d", sBuffer, iAttachID);
		}

		sType = "explosive";
		Format(query, sizeof(query), "SELECT steamid, classname, type, itemid FROM saveloadout WHERE steamid = '%s' AND classname = '%s' AND type = '%s'", g_sPlayerSteamID[client], g_sPlayerClassTemplate[client], sType);

		if ((rs = SQL_Query(SQLiteDB, query)) == null)
		{
			SQL_GetError(SQLiteDB, error, sizeof(error));
			PrintToServer("Failed to query (error: %s)", error);
			LogMessage("[savelo] Failed to query (error: %s)", error);
			return Plugin_Handled;
		}
		if (rs.RowCount > 0) UpdateWeaponRecord(client, sType, sBuffer);
		else AddWeaponRecord(client, sType, sBuffer);
		delete rs;
	}

	g_bUsedSaveLoBefore[client] = true;
	g_bClassSaveLoBefore[client] = true;
	PrintToChat(client, "\x0700FA9A[savelo]\x07F8F8FF Loadout saved.");
	PrintToChat(client, "\x0700FA9A[savelo]\x07FFD700 Your loadout load when you choose your class or by pressing reset button.");
	ClientCommand(client, "play ui/vote_success.wav");

	return Plugin_Handled;
}

public void AddWeaponRecord(int client, const char[] sType, const char[] sBuffer)
{
	char sQuery[255];
	if (sBuffer[0] != '\0') Format(sQuery, sizeof(sQuery), "INSERT OR IGNORE INTO saveloadout VALUES ('%s','%s','%s','%s')", g_sPlayerSteamID[client], g_sPlayerClassTemplate[client], sType, sBuffer);
	else Format(sQuery, sizeof(sQuery), "INSERT OR IGNORE INTO saveloadout VALUES ('%s','%s','%s', NULL)", g_sPlayerSteamID[client], g_sPlayerClassTemplate[client], sType);

	SQL_TQuery(SQLiteDB, SQL_ErrorCheckCallBack, sQuery);
}

public void UpdateWeaponRecord(int client, const char[] sType, const char[] sBuffer)
{
	char sQuery[255];
	if (sBuffer[0] != '\0') Format(sQuery, sizeof(sQuery), "UPDATE OR IGNORE saveloadout SET itemid = '%s' WHERE steamid = '%s' AND classname = '%s' AND type = '%s'", sBuffer, g_sPlayerSteamID[client], g_sPlayerClassTemplate[client], sType);
	else Format(sQuery, sizeof(sQuery), "UPDATE OR IGNORE saveloadout SET itemid = NULL WHERE steamid = '%s' AND classname = '%s' AND type = '%s'", g_sPlayerSteamID[client], g_sPlayerClassTemplate[client], sType);
	
	SQL_TQuery(SQLiteDB, SQL_ErrorCheckCallBack, sQuery);
}

public void SQL_ErrorCheckCallBack(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogMessage("Query failed! %s", error);
		SetFailState("Query failed! %s", error);
	}
}

void loload_cmd(int client)
{
	char sBuffer[64];
	char error[255];
	char query[255];
	char sType[32];
	char
		GearArray[9][64],
		PrimaryArray[9][64],
		SecondaryArray[9][64],
		ExplosivesArray[9][64];

	DBResultSet rs;

	sType = "explosive";
	Format(query, sizeof(query), "SELECT steamid, classname, type, itemid FROM saveloadout WHERE steamid = '%s' AND classname = '%s'", g_sPlayerSteamID[client], g_sPlayerClassTemplate[client]);

	if ((rs = SQL_Query(SQLiteDB, query)) == null)
	{
		SQL_GetError(SQLiteDB, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		LogMessage("[savelo] Failed to query (error: %s)", error);
		return;
	}

	int iWeaponCount = 0;
	while (rs.MoreRows)
	{
		if (!rs.FetchRow()) continue;

		rs.FetchString(2, sType, sizeof(sType));
		if (StrEqual(sType, "gear"))
		{
			rs.FetchString(3, sBuffer, sizeof(sBuffer));
			ExplodeString(sBuffer, ";", GearArray, sizeof(GearArray), sizeof(GearArray[]));
		}
		else if (StrEqual(sType, "primary"))
		{
			rs.FetchString(3, sBuffer, sizeof(sBuffer));
			ExplodeString(sBuffer, ";", PrimaryArray, sizeof(PrimaryArray), sizeof(PrimaryArray[]));
		}
		else if (StrEqual(sType, "secondary"))
		{
			rs.FetchString(3, sBuffer, sizeof(sBuffer));
			ExplodeString(sBuffer, ";", SecondaryArray, sizeof(SecondaryArray), sizeof(SecondaryArray[]));
		}
		else if (StrEqual(sType, "explosive"))
		{
			rs.FetchString(3, sBuffer, sizeof(sBuffer));
			ExplodeString(sBuffer, ";", ExplosivesArray, sizeof(ExplosivesArray), sizeof(ExplosivesArray[]));
		}
	}
	delete rs;

	FakeClientCommand(client, "inventory_sell_all");

	if (GearArray[0][0] != '\0')
	{
		FakeClientCommand(client, "inventory_buy_gear %s", GearArray[0]);
		for (int i = 1; i < sizeof(GearArray); i++)
		{
			if (GearArray[i][0] != '\0') FakeClientCommand(client, "inventory_buy_gear %s", GearArray[i]);
			else break;
		}
	}

	iWeaponCount = 0;
	if (PrimaryArray[0][0] != '\0')
	{
		FakeClientCommand(client, "inventory_buy_weapon %s", PrimaryArray[0]);
		iWeaponCount++;
		for (int i = 1; i < sizeof(PrimaryArray); i++)
		{
			if (PrimaryArray[i][0] != '\0') FakeClientCommand(client, "inventory_buy_upgrade %d %s", iWeaponCount, PrimaryArray[i]);
			else break;
		}
	}

	if (SecondaryArray[0][0] != '\0')
	{
		FakeClientCommand(client, "inventory_buy_weapon %s", SecondaryArray[0]);
		iWeaponCount++;
		for (int i = 1; i < sizeof(SecondaryArray); i++)
		{
			if (SecondaryArray[i][0] != '\0') FakeClientCommand(client, "inventory_buy_upgrade %d %s", iWeaponCount, SecondaryArray[i]);
			else break;
		}
	}

	if (ExplosivesArray[0][0] != '\0')
	{
		FakeClientCommand(client, "inventory_buy_weapon %s", ExplosivesArray[0]);
		iWeaponCount++;
		for (int i = 1; i < sizeof(ExplosivesArray); i++)
		{
			if (ExplosivesArray[i][0] != '\0') FakeClientCommand(client, "inventory_buy_upgrade %d %s", iWeaponCount, ExplosivesArray[i]);
			else break;
		}
	}
}

public Action inventory_reset_cmd(int client, int args)
{
	if (!g_bClassSaveLoBefore[client]) return Plugin_Continue;
	int CurrentTime = GetTime();

	if (CurrentTime-loload_cooldowntime[client] > 3)
	{
		if (g_bClassSaveLoBefore[client])
		{
			loload_cmd(client);
			loload_cooldowntime[client] = CurrentTime;
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action inventory_confirm_cmd(int client, int args)
{
	if (!IsFakeClient(client) && !g_bUsedSaveLoBefore[client])
	{
		int CurrentTime = GetTime();
		if (CurrentTime-ad_cooldowntime[client] > 180)
		{
			PrintToChat(client, "\x0700FA9A[savelo]\x01 You can save your loadout with a \x0700FA9A!savelo\x01 command.");
			ad_cooldowntime[client] = CurrentTime;
		}
	}
	return Plugin_Continue;
}

bool IsValidPlayer(int client) {
	return (0 < client <= MaxClients) && IsClientInGame(client);
}
