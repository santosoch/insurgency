#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

bool g_bBotGlow = false;

public void OnPluginStart()
{
	RegAdminCmd("botglow", cmd_botglow, ADMFLAG_ROOT, "botglow");
}

public void OnMapStart()
{
	g_bBotGlow = false;
	CreateTimer(1.0, Timer_RadarOnline, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action cmd_botglow(int client, int args)
{
	g_bBotGlow = !g_bBotGlow;
	PrintToChatAll("BotGlow: %s", g_bBotGlow ? "ENABLED!" : "DISABLED!");
	return Plugin_Handled;
}

public Action Timer_RadarOnline(Handle timer)
{
	if (g_bBotGlow)
	{
		for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
		{
			if (!IsValidPlayer(iTarget) || !IsFakeClient(iTarget) || !IsPlayerAlive(iTarget)) continue;
			SetEntProp(iTarget, Prop_Send, "m_bGlowEnabled", true);
			CreateTimer(0.98, Timer_RadarGlowOff, iTarget, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Continue;
}

public Action Timer_RadarGlowOff(Handle timer, int client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
	}
}

public bool IsValidPlayer(int client)
{
	return (0 < client <= MaxClients) && IsClientInGame(client);
}
