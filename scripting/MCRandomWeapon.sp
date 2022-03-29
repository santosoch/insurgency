// it won't work without correct weapon/attachment id.
// only for primary/secondary weapon, won't change bot's gears/grenade default theater loadout.
// it will remove bot's grenade 2nd slot default theater loadout if you have that.
// this version support for multiple theater asset. it will detect theater mode. modify it for your own use.
// use MCitemID plugin to list player loadouts in console.
// example weapon id format "12;56;24;127" -- first number is weapon id, the rest are weapon attachment id.

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

public Plugin myinfo =  
{
	name = "[INS] Bot Random Weapon",
	author = "Bot Chris",
	description = "[INS] Bot Random Weapon",
	version = "1.0",
	url = ""
}

char g_sPlayerClassTemplate[MAXPLAYERS+1][64];
int g_iTheaterMode; //1=expanded weapon, 2=vanilla, 3=WW2, 4=SSS
char g_sBotPrimary[MAXPLAYERS+1][32];
char g_sBotSecondary[MAXPLAYERS+1][32];
char g_sBotGrenade[MAXPLAYERS+1][32];
char g_sBotGear[MAXPLAYERS+1][32];

public void OnPluginStart()
{
	HookEvent("player_pick_squad", Event_PlayerPickSquad, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
}

public void OnMapStart() {
	g_iTheaterMode = GetTheaterMode();
}

public Action Event_PlayerPickSquad(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	GetEventString(event, "class_template", g_sPlayerClassTemplate[client], 64);
	if (IsFakeClient(client))
	{
		CreateTimer(0.1, Timer_GetBotLoadout, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public Action Timer_GetBotLoadout(Handle timer, int client)
{
	if (!IsValidPlayer(client)) return Plugin_Continue;

	int gearoffset = GetEntSendPropOffs(client, "m_EquippedGear", true);
	g_sBotGear[client] = "";
	if (gearoffset != -1)
	{
		int iGearID = GetEntData(client, gearoffset);
		Format(g_sBotGear[client], 32, "%d", iGearID);
		for (int i = 4; i <= 24; i+=4) {
			iGearID = GetEntData(client, gearoffset + i);
			if (iGearID != -1) Format(g_sBotGear[client], 32, "%s;%d", g_sBotGear[client], iGearID);
		}
	}

	//support only 1 bot grenade
	int playerGrenades = GetPlayerWeaponSlot(client, 3);
	g_sBotGrenade[client] = "";
	if (playerGrenades != -1)
	{
		int iWeaponID = GetEntProp(playerGrenades, Prop_Send, "m_hWeaponDefinitionHandle");
		if (iWeaponID > 0) Format(g_sBotGrenade[client], 32, "%d", iWeaponID);
	}
	//PrintToServer("Gears: %s | Grenade: %s", g_sBotGear[client], g_sBotGrenade[client]);
	return Plugin_Continue;
}

public Action Event_PlayerDeathPre(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (GetGameState() != 4 && !IsValidPlayer(victim) || !IsFakeClient(victim)) return Plugin_Continue;

//DEBUG
/*	int iWeapon = GetEntPropEnt(victim, Prop_Data, "m_hActiveWeapon");
	if (iWeapon > MaxClients && IsValidEntity(iWeapon))
	{
		char cWeaponName[256];
		GetEntityClassname(iWeapon, cWeaponName, sizeof(cWeaponName));
		PrintToChatAll("weapon: %s", cWeaponName);
	}	*/

	GetRandomWeapon(victim);
	return Plugin_Continue;
}

void GetRandomWeapon(int client)
{
	g_sBotPrimary[client] = "";
	g_sBotSecondary[client] = "";
	if (g_iTheaterMode == 1)
	{
		//get secondary pistol
		switch(GetRandomInt(1, 5))
		{
			case 1: g_sBotSecondary[client] = "43;48"; //fiveseven: 100;50;102
			case 2: g_sBotSecondary[client] = "62;48"; //glock18: 103;50;83
			case 3: g_sBotSecondary[client] = "42;48"; //glock33: 99;50;95
			case 4: g_sBotSecondary[client] = "60;48"; //deagle: 102;50;93
			case 5: g_sBotSecondary[client] = "58;48;125"; //waltherppk: 93;50;87
		}
		if (StrContains(g_sPlayerClassTemplate[client], "heavygunner", false) != -1)
		{
			switch(GetRandomInt(1, 7))
			{
				case 1: g_sBotPrimary[client] = "43;48"; //rpk: 43;48
				case 2: g_sBotPrimary[client] = "62;48"; //m240: 62;48
				case 3: g_sBotPrimary[client] = "42;48"; //m249: 42;48
				case 4: g_sBotPrimary[client] = "60;48"; //m60: 60;48
				case 5: g_sBotPrimary[client] = "58;48;125"; //mg36: 58;48;125
				case 6: g_sBotPrimary[client] = "59;48"; //mk46: 59;48
				case 7: g_sBotPrimary[client] = "61;48"; //m60: pecheneg: 61;48
			}
		}
		else if (StrContains(g_sPlayerClassTemplate[client], "scout", false) != -1) //shotgun
		{
			switch(GetRandomInt(1, 11)) //secondary killer weapon (shotguns in my case). will replace secondary pistol without primary weapon.
			{
				case 1: g_sBotSecondary[client] = "110;47"; //benelli m1014: 110;47
				case 2: g_sBotSecondary[client] = "112;49"; //nova: 112;49
				case 3: g_sBotSecondary[client] = "113;49"; //ksg: 113;49
				case 4: g_sBotSecondary[client] = "111;49"; //m500: 111;49
				case 5: g_sBotSecondary[client] = "40;49"; //m590: 40;49
				case 6: g_sBotSecondary[client] = "107;49"; //m590tactical: 107;49
				case 7: g_sBotSecondary[client] = "109;49"; //saiga2auto: 109;49
				case 8: g_sBotSecondary[client] = "108;48;147"; //saiga12: 108;48;147
				case 9: g_sBotSecondary[client] = "114;49"; //spas12: 114;49
				case 10: g_sBotSecondary[client] = "41;49"; //toz: 41;49
				case 11: g_sBotSecondary[client] = "106;47"; //typhoon: 106;47
			}
		}
		else if (StrContains(g_sPlayerClassTemplate[client], "sharpshooter", false) != -1)
		{
			switch(GetRandomInt(1, 7))
			{
				case 1: g_sBotPrimary[client] = "54;79;121"; //barret m107: 54;79;121
				case 2: g_sBotPrimary[client] = "56;80;115"; //svd: 56;80;115
				case 3: g_sBotPrimary[client] = "87;71;112"; //dragunovsvu: 87;71;112
				case 4: g_sBotPrimary[client] = "76;79;117"; //hk417: 76;79;117
				case 5: g_sBotPrimary[client] = "35;78;114"; //sks: 35;78;114
				case 6: g_sBotPrimary[client] = "74;79;117"; //sr25: 74;79;117
				case 7: g_sBotPrimary[client] = "31;71;97"; //l1a1: 31;71;97
			}
		}
		else //primary with pistol OR might replace secondary pistol without primary weapon. 
		{
			switch(GetRandomInt(1, 29))
			{
				case 1: g_sBotPrimary[client] = "86;48"; //saiga762: 86;48
				case 2: g_sBotPrimary[client] = "80;47"; //ak12u: 80;47
				case 3: g_sBotPrimary[client] = "29;48"; //ak74: 29;48
				case 4: g_sBotPrimary[client] = "78;48"; //car15: 78;48
				case 5: g_sBotPrimary[client] = "75;47"; //colt cm901: 75;47
				case 6: g_sBotPrimary[client] = "85;48"; //famas: 85;48
				case 7: g_sBotPrimary[client] = "69;47"; //f2000: 69;47
				case 8: g_sBotPrimary[client] = "84;47"; //g36c: 84;47
				case 9: g_sBotPrimary[client] = "65;48"; //g36k: 65;48
				case 10: g_sBotPrimary[client] = "27;48"; //galil: 27;48
				case 11: g_sBotPrimary[client] = "68;47"; //l85a2: 68;47
				case 12: g_sBotPrimary[client] = "66;48"; //groza1: 66;48
				case 13: g_sBotPrimary[client] = "82;48"; //sig553: 82;48
				case 14: g_sBotPrimary[client] = "70;47"; //steyraug: 70;47
				case 15: g_sBotPrimary[client] = "49;47"; //opaks74u: 49;47
				case 16: g_sBotPrimary[client] = "28;48"; //akm: 28;48
				case 17: g_sBotPrimary[client] = "30;48"; //fal: 30;48
				case 18: g_sBotSecondary[client] = "91;50;94;12"; //vp70m: 91;50;94;12
				case 19: g_sBotSecondary[client] = "39;48"; //aks74u: 39;48
				case 20: g_sBotSecondary[client] = "126;47;107"; //colt9mmL 126;47;107
				case 21: g_sBotSecondary[client] = "120;48;109"; //krissvector: 120;48;109
				case 22: g_sBotSecondary[client] = "116;90"; //m3greasegun: 116;90
				case 23: g_sBotSecondary[client] = "121;48;108"; //mac10: 121;48;108
				case 24: g_sBotSecondary[client] = "118;48;103"; //p90: 118;48;103
				case 25: g_sBotSecondary[client] = "117;48;107"; //scorpionevo3: 117;48;107
				case 26: g_sBotSecondary[client] = "119;48;107"; //spectre: 119;48;107
				case 27: g_sBotSecondary[client] = "37;48;108"; //sterling: 37;48;108
				case 28: g_sBotSecondary[client] = "125;48;107"; //uzi: 125;48;107
				case 29: g_sBotSecondary[client] = "71;48;85"; //asval: 71;48;85
			}
		}
	}
	else if (g_iTheaterMode == 4) // this theater,  all secondary weapons are pistol
	{
		g_sBotSecondary[client] = "28;42"; //makarov
		if (StrContains(g_sPlayerClassTemplate[client], "heavygunner", false) != -1)
		{
			switch(GetRandomInt(1, 4))
			{
				case 1: g_sBotPrimary[client] = "73;40"; //rpk: 73;40
				case 2: g_sBotPrimary[client] = "71;40"; //m240: 71;40
				case 3: g_sBotPrimary[client] = "72;40"; //m249: 72;40
				case 4: g_sBotPrimary[client] = "86;40"; //m60: 86;40
			}
		}
		else if (StrContains(g_sPlayerClassTemplate[client], "scout", false) != -1) //shotgun
		{
			switch(GetRandomInt(1, 4))
			{
				case 1: g_sBotPrimary[client] = "89;41"; //gallosa12: 89;41
				case 2: g_sBotPrimary[client] = "69;41"; //m780: 69;41
				case 3: g_sBotPrimary[client] = "68;37"; //saiga12: 68;37
				case 4: g_sBotPrimary[client] = "70;41"; //toz: 70;41
			}
		}
		else if (StrContains(g_sPlayerClassTemplate[client], "sharpshooter", false) != -1)
		{
			//special pistol for sharpshooter
			g_sBotSecondary[client] = "94;42;108"; //tt33: 94;42;108
			switch(GetRandomInt(1, 5))
			{
				case 1: g_sBotPrimary[client] = "87;55;130"; //m98b: 87;55;130
				case 2: g_sBotPrimary[client] = "54;55;138"; //m110: 54;55;138
				case 3: g_sBotPrimary[client] = "59;54;144"; //sks: 59;54;144
				case 4: g_sBotPrimary[client] = "58;54;142"; //svd: 58;54;142
				case 5: g_sBotPrimary[client] = "52;48;134"; //l1a1: 52;48;134
			}
		}
		else
		{
			switch(GetRandomInt(1, 24))
			{
				case 1: g_sBotPrimary[client] = "67;40"; //aks74u: 67;40
				case 2: g_sBotPrimary[client] = "78;40;114"; //p90: 78;40;114
				case 3: g_sBotPrimary[client] = "61"; //greasegun: 61
				case 4: g_sBotPrimary[client] = "77;40;146"; //miniuzi: 77;40;146
				case 5: g_sBotPrimary[client] = "64;40"; //mp7: 64;40
				case 6: g_sBotPrimary[client] = "62;40"; //sterling: 62;40
				case 7: g_sBotPrimary[client] = "76;37"; //striker45: 76;37
				case 8: g_sBotPrimary[client] = "63;40;150"; //uzi: 63;40;150
				case 9: g_sBotPrimary[client] = "50;40"; //ak74: 50;40
				case 10: g_sBotPrimary[client] = "39;40;124"; //asval: 39;40;124
				case 11: g_sBotPrimary[client] = "36;37;118"; //famas: 36;37;118
				case 12: g_sBotPrimary[client] = "45;37"; //g36k: 45;37
				case 13: g_sBotPrimary[client] = "46;40"; //galil: 46;40
				case 14: g_sBotPrimary[client] = "81;37"; //krig6/ak5: 81;37
				case 15: g_sBotPrimary[client] = "44;37"; //l85a1: 44;37
				case 16: g_sBotPrimary[client] = "37;37"; //auga3: 37;37
				case 17: g_sBotPrimary[client] = "32;37;122"; //mcx: 32;37;122
				case 18: g_sBotPrimary[client] = "35;40"; //qbz03: 35;40
				case 19: g_sBotPrimary[client] = "40;37"; //vhs2: 40;37
				//7.62 bullets
				case 20: g_sBotPrimary[client] = "49;40;128"; //akm: 49;40;128
				case 21: g_sBotPrimary[client] = "80;40;126"; //akmtactical: 80;40;126
				case 22: g_sBotPrimary[client] = "48;40;128"; //alphaak: 48;40;128
				case 23: g_sBotPrimary[client] = "51;40;134"; //FAL: 51;40;134
				case 24: g_sBotPrimary[client] = "84;40;128"; //type56: 84;40;128
			}
		}
	}
	if (g_sBotPrimary[client][0] != '\0' || g_sBotSecondary[client][0] != '\0')
	{
		BuyWeaponBot(client);
	}
}

void BuyWeaponBot(int client)
{
	char GearArray[9][32], PrimaryArray[9][32], SecondaryArray[9][32], ExplosivesArray[9][32];
	ExplodeString(g_sBotGear[client], ";", GearArray, sizeof(GearArray), sizeof(GearArray[]));
	ExplodeString(g_sBotPrimary[client], ";", PrimaryArray, sizeof(PrimaryArray), sizeof(PrimaryArray[]));
	ExplodeString(g_sBotSecondary[client], ";", SecondaryArray, sizeof(SecondaryArray), sizeof(SecondaryArray[]));
	ExplodeString(g_sBotGrenade[client], ";", ExplosivesArray, sizeof(ExplosivesArray), sizeof(ExplosivesArray[]));

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
	int iSlot = 0;
	if (PrimaryArray[0][0] != '\0')
	{
		FakeClientCommand(client, "inventory_buy_weapon %s", PrimaryArray[0]);
		iSlot++;
		for (int i = 1; i < sizeof(PrimaryArray); i++)
		{
			if (PrimaryArray[i][0] != '\0') FakeClientCommand(client, "inventory_buy_upgrade %d %s", iSlot, PrimaryArray[i]);
			else break;
		}
	}
	if (SecondaryArray[0][0] != '\0')
	{
		FakeClientCommand(client, "inventory_buy_weapon %s", SecondaryArray[0]);
		iSlot++;
		for (int i = 1; i < sizeof(SecondaryArray); i++)
		{
			if (SecondaryArray[i][0] != '\0') FakeClientCommand(client, "inventory_buy_upgrade %d %s", iSlot, SecondaryArray[i]);
			else break;
		}
	}
	if (ExplosivesArray[0][0] != '\0')
	{
		FakeClientCommand(client, "inventory_buy_weapon %s", ExplosivesArray[0]);
		iSlot++;
		for (int i = 1; i < sizeof(ExplosivesArray); i++)
		{
			if (ExplosivesArray[i][0] != '\0') FakeClientCommand(client, "inventory_buy_upgrade %d %s", iSlot, ExplosivesArray[i]);
			else break;
		}
	}
}

int GetTheaterMode() //1=expanded weapon, 2=vanilla, 3=WW2, 4=SSS
{
	if (IsValidWeaponName("weapon_typhoon12")) return 1;
	else if (IsValidWeaponName("weapon_sandstorm_galil_sar")) return 4;
	return 0;
}

bool IsValidWeaponName(const char[] className)
{
	int weapon = CreateEntityByName(className);
	if (weapon == INVALID_ENT_REFERENCE) return false;
	else
	{
		AcceptEntityInput(weapon, "kill");
		return true;
	}
}

int GetGameState() {
	return GameRules_GetProp("m_iGameState");
}

bool IsValidPlayer(int client) {
	return (0 < client <= MaxClients) && IsClientInGame(client);
}