//open console with ~ key
//type command: mcitem

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>

public Plugin myinfo =  
{
	name = "[INS] Item ID List",
	author = "Bot Chris",
	description = "Get Player Loadouts Item ID",
	version = "1.0",
	url = ""
}

public void OnPluginStart()
{
	RegConsoleCmd("mcitem", CommandItemList, "List equipted items ID on player console");
}

public Action CommandItemList(int client, any args)
{
	if (client <= 0) return Plugin_Handled;
	PrintToConsole(client, "%N LOADOUTS", client);
	PrintToConsole(client, "================== WEAPONS ==================");
	char sWeaponName[64];

	int index = 0;
	int offset = Client_GetWeaponsOffset(client) + (index * 4);

	int iWeaponEnt;
	int iWeaponID;
	while (index < MAX_WEAPONS) {
		index++;
		iWeaponEnt = GetEntDataEnt2(client, offset);
		if (Weapon_IsValid(iWeaponEnt)) {
			iWeaponID = GetEntProp(iWeaponEnt, Prop_Send, "m_hWeaponDefinitionHandle");
			Entity_GetClassName(iWeaponEnt, sWeaponName, 64);
			PrintToConsole(client, "Offset: (%d) WeaponID (%d): %s", offset, iWeaponID, sWeaponName);

			int upoffset = GetEntSendPropOffs(iWeaponEnt, "m_upgradeSlots", true);
			for (int i = 0; i < 32; i+=4) {
				int iAttachID = GetEntData(iWeaponEnt, upoffset + i);
				if (iAttachID != -1) PrintToConsole(client, "AttachID: %d", iAttachID);
			}
			//PrintToConsole(client, "=============================================");
			PrintToConsole(client, "_____________________________________________");
		}
		offset += 4;
	}

	//get all player gears name and id
	PrintToConsole(client, "=================== GEARS ===================");

	offset = GetEntSendPropOffs(client, "m_EquippedGear", true);
	if (offset != -1) {
		for (int i = 0; i < 32; i+=4) {
			int value = GetEntData(client, offset + i);
			//if (value != -1) PrintToConsole(client, "Gear(%d)", value);
			if (value > 0) PrintToConsole(client, "GearID: %d", value);
		}
	}
	PrintToConsole(client, "================ END OF LIST ================");
	return Plugin_Handled;
}

public bool IsValidPlayer(int client) {
	return (0 < client <= MaxClients) && IsClientInGame(client);
}
