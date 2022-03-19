//need simple-chatprocessor plugin to run (global forward OnChatMessage)
//can be compiled using sm 1.11
//it will show only in chat, like this: [Rifleman] Name: hello there...

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

public Plugin myinfo =
{
	name = "Chat Class Tag",
	author = "Bot Chris",
	description = "Chat Class Tag",
	version = "1.0",
	url = ""
}

#define		TEAM_SECURITY		2
#define		TEAM_INSURGENTS		3
#define		COLOR_SECURITY		"84961CFF"
#define		COLOR_INSURGENTS	"AC4029FF"
#define		COLOR_SPECTATOR		"F2EBD8FF"
#define		TAG_COLOR			"FFD700FF"

//COLOR_UNIQUE				"FFD700FF"
//COLOR_GHOSTWHITE			"F8F8FFFF"
//COLOR_MEDIUMSPRINGGREEN	"00FA9AFF"

char g_sPlayerClassTag[MAXPLAYERS+1][64];

public void OnPluginStart() {
	HookEvent("player_pick_squad", Event_PlayerPickSquad_Post, EventHookMode_Post);
}

public Action Event_PlayerPickSquad_Post(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if (!IsValidPlayer(client)) return;
	
	char class_template[64];
	GetEventString(event, "class_template",class_template,sizeof(class_template));

	if (strlen(class_template) > 1) {
		if (StrContains(class_template, "recon", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Recon]");
		else if (StrContains(class_template, "specialist", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Specialist]");
		else if (StrContains(class_template, "engineer", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Engineer]");
		else if (StrContains(class_template, "medic", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Medic]");
		else if (StrContains(class_template, "rifleman", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Rifleman]");
		else if (StrContains(class_template, "breacher", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Breacher]");
		else if (StrContains(class_template, "demolition", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Demolition]");
		else if (StrContains(class_template, "marksman", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Marksman]");
		else if (StrContains(class_template, "support", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Support]");
		else if (StrContains(class_template, "sniper", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Sniper]");
		else if (StrContains(class_template, "fighter", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Fighter]");
		else if (StrContains(class_template, "grenadier", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Grenadier]");
		else if (StrContains(class_template, "sapper", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Sapper]");
		else if (StrContains(class_template, "bomber", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Bomber]");
		else if (StrContains(class_template, "militant", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Militant]");
		else if (StrContains(class_template, "striker", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Striker]");
		else if (StrContains(class_template, "rocketeer", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Rocketeer]");
		else if (StrContains(class_template, "scout", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Scout]");
		else if (StrContains(class_template, "sharpshooter", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Sharpshooter]");
		else if (StrContains(class_template, "machinegunner", false) != -1) Format(g_sPlayerClassTag[client], 64, "[Machinegunner]");
		else Format(g_sPlayerClassTag[client], 64, "[UNKNOWN]");
	}
}

public Action OnChatMessage(int& author, Handle recipients, char[] name, char[] message)
{
	int iTeam = GetClientTeam(author);
	char sTeamColor[9];

	if (iTeam == TEAM_SECURITY)
	{
		sTeamColor = COLOR_SECURITY;
		Format(name, 255, "\x08%s%s \x08%s%s", TAG_COLOR, g_sPlayerClassTag[author], sTeamColor, name);
		return Plugin_Changed;
	}
	else if (iTeam == TEAM_INSURGENTS)
	{
		sTeamColor = COLOR_INSURGENTS;
		Format(name, 255, "\x08%s%s \x08%s%s", TAG_COLOR, g_sPlayerClassTag[author], sTeamColor, name);
		return Plugin_Changed;
	}
	else if (!IsFakeClient(author))
	{
		sTeamColor = COLOR_SPECTATOR;
		Format(name, 255, "\x08%s%s", sTeamColor, name);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public bool IsValidPlayer(int client) {
	return (0 < client <= MaxClients) && IsClientInGame(client);
}
