#include <sdktools>
#include <tf2>
#include <morecolors>

#pragma dynamic 131072 

ConVar
	cvTag,
	cvRespawn,
	cvRespawnPerPlayer,
	cvIntro,
	cvWarn,
	cvLeaderboards,
	cvRespawnHudx,
	cvRespawnHudy,
	cvLeaderboardsHudx,
	cvLeaderboardsHudy;
	
bool
	g_bRoundStarted = false;
	
int
	g_iWarnTime = 0,
	g_iIntroTime = 0,
	g_iRespawnTime = 0,
	g_iRespawnTimePerPlayer = 0,
	g_iLeaderboards = 0,
	g_iStartingPlayers = 0,
	g_iRemaining[MAXPLAYERS+1] = 0;
	
float
	g_flRespawnHudx,
	g_flRespawnHudy,
	g_flLeaderboardsHudx,
	g_flLeaderboardsHudy;
	
char
	g_sTag[32];
	
Handle
	g_hRespawnTimer[MAXPLAYERS+1] = { null, ... },
	g_hRespawnHud_Timer[MAXPLAYERS + 1] = { null, ... },
	g_hRespawnHUD,
	g_hRespawnLeaderboards;
	
public Plugin myinfo = 
{
	name 			= 	"Titan 2 - 1 vs All Respawn",
	description 	= 	"Adds a respawn feature to boss gamemodes like Deathrun, VSH and Freak Fortress, aka a second life.",
	author 			= 	"myst",
	version 		= 	"2.0",
}

public void OnPluginStart()
{
	cvTag = CreateConVar("sm_1vA_tag", "{grey}[VSH]{white}", "Change the chat tag of the plugin");
	cvTag.GetString(g_sTag, sizeof(g_sTag));
	
	cvRespawn = CreateConVar("sm_1vA_respawntime", "20", "Change the base respawn time (in seconds)");
	g_iRespawnTime = cvRespawn.IntValue;
	
	cvRespawnPerPlayer = CreateConVar("sm_1vA_respawnperplayertime", "15", "Change the additional respawn time added per player (in seconds)");
	g_iRespawnTimePerPlayer = cvRespawnPerPlayer.IntValue;
	
	cvIntro = CreateConVar("sm_1vA_introtime", "10", "The first x seconds that shows you will respawn in y minutes z seconds before timer starts animating");
	g_iIntroTime = cvIntro.IntValue;
	
	cvWarn = CreateConVar("sm_1vA_preparetime", "10", "Show 'Prepare to Respawn' message when timer reaches this amount of seconds");
	g_iWarnTime = cvWarn.IntValue;
	
	cvLeaderboards = CreateConVar("sm_1vA_leaderboards", "1", "Display the next respawns (0 = no, 1 = yes, default: 1)", _, true, -1.0, true, 1.0);
	g_iLeaderboards = cvLeaderboards.IntValue;
	
	cvRespawnHudx = CreateConVar("sm_1vA_leaderboards_hud_x", "-1.0", "Change the x position of leaderboards hud", _, true, -1.0, true, 1.0);
	g_flRespawnHudx = cvRespawnHudx.FloatValue;
	
	cvRespawnHudy = CreateConVar("sm_1vA_leaderboards_hud_y", "-1.0", "Change the y position of leaderboards hud", _, true, -1.0, true, 1.0);
	g_flRespawnHudy = cvRespawnHudy.FloatValue;
	
	cvLeaderboardsHudx = CreateConVar("sm_1vA_respawn_hud_x", "0.01", "Change the x position of respawn hud", _, true, -1.0, true, 1.0);
	g_flLeaderboardsHudx = cvLeaderboardsHudx.FloatValue;
	
	cvLeaderboardsHudy = CreateConVar("sm_1vA_respawn_hud_y", "0.01", "Change the y position of respawn hud", _, true, -1.0, true, 1.0);
	g_flLeaderboardsHudy = cvLeaderboardsHudy.FloatValue;
	
	cvTag.AddChangeHook(OnCvarChanged);
	cvRespawn.AddChangeHook(OnCvarChanged);
	cvRespawnPerPlayer.AddChangeHook(OnCvarChanged);
	cvIntro.AddChangeHook(OnCvarChanged);
	cvWarn.AddChangeHook(OnCvarChanged);
	cvLeaderboards.AddChangeHook(OnCvarChanged);
	cvRespawnHudx.AddChangeHook(OnCvarChanged);
	cvRespawnHudy.AddChangeHook(OnCvarChanged);
	cvLeaderboardsHudx.AddChangeHook(OnCvarChanged);
	cvLeaderboardsHudy.AddChangeHook(OnCvarChanged);
	
	HookEvent("arena_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundEnd);	
	HookEvent("player_spawn", Player_Spawn);
	HookEvent("post_inventory_application", Player_Spawn);
	HookEvent("player_death", Player_Death, EventHookMode_Pre);
	
	g_hRespawnHUD = CreateHudSynchronizer();
	g_hRespawnLeaderboards = CreateHudSynchronizer();
	
	LoadTranslations("common.phrases");
}

public int OnCvarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if (cvar == cvTag)
		cvTag.GetString(g_sTag, sizeof(g_sTag));
		
	else if (cvar == cvRespawn)
		g_iRespawnTime = cvRespawn.IntValue;
		
	else if (cvar == cvRespawnPerPlayer)
		g_iRespawnTimePerPlayer = cvRespawnPerPlayer.IntValue;
		
	else if (cvar == cvIntro)
		g_iIntroTime = cvIntro.IntValue;	
		
	else if (cvar == cvWarn)
		g_iWarnTime = cvWarn.IntValue;
		
	else if (cvar == cvLeaderboards)
		g_iLeaderboards = cvLeaderboards.IntValue;
		
	else if (cvar == cvRespawnHudx)
		g_flRespawnHudx = cvRespawnHudx.FloatValue;
		
	else if (cvar == cvRespawnHudy)
		g_flRespawnHudy = cvRespawnHudy.FloatValue;
		
	else if (cvar == cvLeaderboardsHudx)
		g_flLeaderboardsHudx = cvLeaderboardsHudx.FloatValue;
		
	else if (cvar == cvLeaderboardsHudy)
		g_flLeaderboardsHudy = cvLeaderboardsHudy.FloatValue;
}

public void OnMapStart() {
	CreateTimer(1.0, Timer_Leaderboards, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientDisconnect(int iClient)
{
	if (IsValidClient(iClient) && !IsFakeClient(iClient))
		Client_ClearTimers(iClient);
}

public Action Player_Spawn(Handle hEvent, char[] sEventName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (IsValidClient(iClient))
		Client_ClearTimers(iClient);
		
	return Plugin_Continue;
}

public Action Player_Death(Handle hEvent, char[] sEventName, bool bDontBroadcast)
{
	if (g_bRoundStarted)
	{
		int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
		if (IsValidClient(iClient) && !IsFakeClient(iClient))
		{
			g_iRemaining[iClient] = GetRespawnTime();
			PrintToServer("%i", GetRespawnTime());
			g_hRespawnTimer[iClient] = CreateTimer(float(GetRespawnTime()), Timer_Respawn, iClient);
			g_hRespawnHud_Timer[iClient] = CreateTimer(1.0, Timer_RespawnHUD, iClient, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_RespawnHUD(Handle hTimer, int iClient)
{
	if (!IsValidClient(iClient))
		return Plugin_Stop;
		
	if (!g_bRoundStarted)
	{
		Client_ClearTimers(iClient);
		return Plugin_Stop;
	}
	
	g_iRemaining[iClient]--;
	if (g_iRemaining[iClient] >= GetRespawnTime() - g_iIntroTime)
	{
		SetHudTextParams(g_flRespawnHudx, g_flRespawnHudy, 1.0, 255, 255, 255, 255);
		if (GetRespawnTime() / 60 > 0)
			ShowSyncHudText(iClient, g_hRespawnHUD, "You will respawn in %d minutes %d seconds.", GetRespawnTime() / 60, GetRespawnTime() % 60);
		else
			ShowSyncHudText(iClient, g_hRespawnHUD, "You will respawn in %d seconds.", GetRespawnTime() % 60);
	}
	
	else if (g_iRemaining[iClient] <= 0)
	{
		SetHudTextParams(g_flRespawnHudx, g_flRespawnHudy, 3.0, 255, 255, 255, 255);
		ShowSyncHudText(iClient, g_hRespawnHUD, "You have respawned.");
		
		hTimer = null;
		return Plugin_Stop;
	}
	
	else if (g_iRemaining[iClient] <= g_iWarnTime)
	{
		SetHudTextParams(g_flRespawnHudx, g_flRespawnHudy, 1.1, 255, 255, 255, 255);
		ShowSyncHudText(iClient, g_hRespawnHUD, "Prepare to Respawn in %02d:%02d", g_iRemaining[iClient] / 60, g_iRemaining[iClient] % 60);
	}
	
	else
	{
		SetHudTextParams(g_flRespawnHudx, g_flRespawnHudy, 1.1, 255, 255, 255, 255);
		ShowSyncHudText(iClient, g_hRespawnHUD, "Respawning in %02d:%02d", g_iRemaining[iClient] / 60, g_iRemaining[iClient] % 60);
	}
	
	return Plugin_Handled;
}

public Action Timer_Leaderboards(Handle hTimer)
{
	if (g_iLeaderboards == 1)
	{
		int iLowest = 400;
		int iLowestClient = -1;
		for (int z = 1; z <= GetMaxClients(); z++)
		{
			if (IsValidClient(z) && !IsPlayerAlive(z) && g_iRemaining[z] >= 1 && g_iRemaining[z] < iLowest)
			{
				iLowest = g_iRemaining[z];
				iLowestClient = z;
			}
		}
		
		int iSecondLowest = 400;
		int iSecondLowestClient = -1;
		for (int z = 1; z <= GetMaxClients(); z++)
		{
			if (IsValidClient(z) && !IsPlayerAlive(z) && g_iRemaining[z] >= 1 && g_iRemaining[z] < iSecondLowest && z != iLowestClient)
			{
				iSecondLowest = g_iRemaining[z];
				iSecondLowestClient = z;
			}
		}
		
		int iThirdLowest = 400;
		int iThirdLowestClient = -1;
		for (int z = 1; z <= GetMaxClients(); z++)
		{
			if (IsValidClient(z) && !IsPlayerAlive(z) && g_iRemaining[z] >= 1 && g_iRemaining[z] < iThirdLowest && z != iLowestClient && z != iSecondLowestClient)
			{
				iThirdLowest = g_iRemaining[z];
				iThirdLowestClient = z;
			}
		}
		
		char sFormat[512];
		if (iLowest != 400)
			Format(sFormat, sizeof(sFormat), "%N - %02d:%02d", iLowestClient, (g_iRemaining[iLowestClient] - 1) / 60, g_iRemaining[iLowestClient] % 60);
			
		if (iSecondLowest != 400)
			Format(sFormat, sizeof(sFormat), "%s\n%N - %02d:%02d", sFormat, iSecondLowestClient, (g_iRemaining[iSecondLowestClient] - 1) / 60, g_iRemaining[iSecondLowestClient] % 60);
			
		if (iThirdLowest != 400)
			Format(sFormat, sizeof(sFormat), "%s\n%N - %02d:%02d", sFormat, iThirdLowestClient, (g_iRemaining[iThirdLowestClient] - 1) / 60, g_iRemaining[iThirdLowestClient] % 60);
			
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsValidClient(iClient))
			{
				SetHudTextParams(g_flLeaderboardsHudx, g_flLeaderboardsHudy, 1.1, 255, 255, 255, 255);
				ShowSyncHudText(iClient, g_hRespawnLeaderboards, sFormat);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Timer_Respawn(Handle hTimer, int iClient)
{
	if (!IsValidClient(iClient))
		return Plugin_Stop;
		
	if (!g_bRoundStarted)
	{
		Client_ClearTimers(iClient);
		return Plugin_Stop;
	}
	
	TF2_RespawnPlayer(iClient);
	CPrintToChatAll("%s %N has respawned!", g_sTag, iClient);
	
	SetHudTextParams(g_flRespawnHudx, g_flRespawnHudy, 3.0, 255, 255, 255, 255);
	ShowSyncHudText(iClient, g_hRespawnHUD, "You have respawned.");
	
	Client_ClearTimers(iClient);
	return Plugin_Handled;
}

public Action Event_RoundStart(Handle hEvent, char[] sEventName, bool bDontBroadcast)
{
	g_iStartingPlayers = GetPlayersCount(2);
	g_bRoundStarted = true;
	
	if (GetRespawnTime() / 60 > 0)
		CPrintToChatAll("%s Players will respawn after %d minutes %d seconds upon death this round.", g_sTag, GetRespawnTime() / 60, GetRespawnTime() % 60);
	else
		CPrintToChatAll("%s Players will respawn after %d seconds upon death this round.", g_sTag, GetRespawnTime() % 60);
		
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidClient(iClient))
			Client_ClearTimers(iClient);
}

public Action Event_RoundEnd(Handle hEvent, char[] sEventName, bool bDontBroadcast)
{
	g_bRoundStarted = false;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidClient(iClient))
			Client_ClearTimers(iClient);
}

stock int GetPlayersCount(int iTeam) 
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++) 
		if (IsValidClient(i) && GetClientTeam(i) == iTeam)
			iCount++; 
	
	return iCount; 
}  

stock int GetRespawnTime()
{
	return g_iRespawnTime + (g_iStartingPlayers * g_iRespawnTimePerPlayer)
}

public void Client_ClearTimers(int iClient)
{
	if (IsValidClient(iClient))
	{
		if (g_hRespawnTimer[iClient] != null)
			delete g_hRespawnTimer[iClient];
			
		if (g_hRespawnHud_Timer[iClient] != null)
			delete g_hRespawnHud_Timer[iClient];
			
		g_iRemaining[iClient] = 0;
	}
}

stock bool IsValidClient(int iClient, bool bReplay = true)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return false;
	if (bReplay && (IsClientSourceTV(iClient) || IsClientReplay(iClient)))
		return false;
	return true;
}