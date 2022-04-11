void RegisterCommands()
{
	RegConsoleCmd("sm_tier", Command_Tier, "Prints the map's tier to chat.");
	RegConsoleCmd("sm_maptier", Command_Tier, "Prints the map's tier to chat. (sm_tier alias)");

	RegConsoleCmd("sm_m", Command_MapDetails, "Prints the map's details information");

	RegConsoleCmd("sm_rankme", Command_Rank, "Show your or someone else's rank. Usage: sm_rank [name]");
	RegConsoleCmd("sm_rank", Command_Top, "Show the top 100 players.");
	RegConsoleCmd("sm_st", Command_Top, "Show the top 100 players.");
	RegConsoleCmd("sm_surftop", Command_Top, "Show the top 100 players.");

	RegAdminCmd("sm_settier", Command_SetTier, ADMFLAG_RCON, "Change the map's tier. Usage: sm_settier <tier>");
	RegAdminCmd("sm_setmaptier", Command_SetTier, ADMFLAG_RCON, "Change the map's tier. Usage: sm_setmaptier <tier> (sm_settier alias)");
	RegAdminCmd("sm_mapsettings", Command_MapSettings, ADMFLAG_RCON, "Change the map's tier, limitspeed and maxvelocity.");
	RegAdminCmd("sm_mapsetting", Command_MapSettings, ADMFLAG_RCON, "Change the map's tier, limitspeed and maxvelocity. Alias of sm_mapsettings");
	RegAdminCmd("sm_ms", Command_MapSettings, ADMFLAG_RCON, "Change the map's tier, limitspeed and maxvelocity. Alias of sm_mapsettings");

	RegAdminCmd("sm_recalcmap", Command_RecalcMap, ADMFLAG_RCON, "Recalculate the current map's records' points.");
	RegAdminCmd("sm_recalcall", Command_RecalcAll, ADMFLAG_ROOT, "Recalculate the points for every map on the server. Run this after you change the ranking multiplier for a style or after you install the plugin.");
}

public Action Command_Tier(int client, int args)
{
	int tier = gI_Tier;

	char sMap[PLATFORM_MAX_PATH];

	if(args == 0)
	{
		sMap = gS_Map;
	}
	else
	{
		GetCmdArgString(sMap, sizeof(sMap));
		LowercaseString(sMap);

		if(!GuessBestMapName(gA_ValidMaps, sMap, sMap) || !gA_MapTiers.GetValue(sMap, tier))
		{
			Shavit_PrintToChat(client, "%t", "Map was not found", sMap);
			return Plugin_Handled;
		}
	}

	Shavit_PrintToChat(client, "%T", "CurrentTier", client, sMap, tier);

	return Plugin_Handled;
}

public Action Command_MapDetails(int client, int args)
{
	int iBonuses = Shavit_GetMapBonuses();

	if(Shavit_IsLinearMap())
	{
		int iCps = Shavit_GetMapCheckpoints();
		Shavit_PrintToChat(client, "当前竞速图信息: 难度 %d | 检查点数 %d | 奖励关数 %d", gI_Tier, iCps, iBonuses);
	}
	else
	{
		int iStages = Shavit_GetMapStages();
		Shavit_PrintToChat(client, "当前关卡图信息: 难度 %d | 关卡数 %d | 奖励关数 %d", gI_Tier, iStages, iBonuses);
	}

	return Plugin_Handled;
}

public Action Command_Rank(int client, int args)
{
	int target = client;

	if(args > 0)
	{
		char sArgs[MAX_TARGET_LENGTH];
		GetCmdArgString(sArgs, MAX_TARGET_LENGTH);

		target = FindTarget(client, sArgs, true, false);

		if(target == -1)
		{
			return Plugin_Handled;
		}
	}

	if(gA_Rankings[target].fPoints == 0.0)
	{
		Shavit_PrintToChat(client, "%T", "Unranked", client, target);

		return Plugin_Handled;
	}

	Shavit_PrintToChat(client, "%T", "Rank", client, target, (gA_Rankings[target].iRank > gI_RankedPlayers)? gI_RankedPlayers:gA_Rankings[target].iRank, gI_RankedPlayers, gA_Rankings[target].fPoints);

	return Plugin_Handled;
}

public Action Command_Top(int client, int args)
{
	ShowTop100Menu(client);

	return Plugin_Handled;
}

public Action Command_SetTier(int client, int args)
{
	char sArg[8];
	GetCmdArg(1, sArg, 8);

	int tier = StringToInt(sArg);

	if(args == 0 || tier < 1 || tier > 10)
	{
		ReplyToCommand(client, "%T", "ArgumentsMissing", client, "sm_settier <tier> (1-10)");

		return Plugin_Handled;
	}

	gI_Tier = tier;
	gA_MapTiers.SetValue(gS_Map, tier);

	Call_OnTierAssigned(gS_Map, tier);

	Shavit_PrintToChat(client, "%T", "SetTier", client, tier);

	DB_SetTier(tier);

	return Plugin_Handled;
}

public Action Command_MapSettings(int client, int args)
{
	SetMapSettings(client);

	return Plugin_Handled;
}

public Action Command_RecalcMap(int client, int args)
{
	DB_RecalculateCurrentMap();
	DB_UpdateAllPoints(true);

	ReplyToCommand(client, "Done.");

	return Plugin_Handled;
}

public Action Command_RecalcAll(int client, int args)
{
	ReplyToCommand(client, "- Started recalculating points for all maps. Check console for output.");

	DB_RecalcAllRankings(client);

	return Plugin_Handled;
}