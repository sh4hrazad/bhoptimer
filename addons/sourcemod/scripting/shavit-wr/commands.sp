// #define DEBUG

void RegisterCommands()
{
	#if defined DEBUG
	RegConsoleCmd("sm_junk", Command_Junk);
	RegConsoleCmd("sm_printleaderboards", Command_PrintLeaderboards);
	#endif

	// player commands
	RegConsoleCmd("sm_wr", Command_WorldRecord, "View the leaderboard of a map. Usage: sm_wr [map]");
	RegConsoleCmd("sm_worldrecord", Command_WorldRecord, "View the leaderboard of a map. Usage: sm_worldrecord [map]");

	RegConsoleCmd("sm_btop", Command_BonusWorldRecord, "View the leaderboard of a map. Usage: sm_btop [map] [bonus number]");
	RegConsoleCmd("sm_wrb", Command_BonusWorldRecord, "View the leaderboard of a map. Usage: sm_wrb [map] [bonus number]");
	RegConsoleCmd("sm_bwr", Command_BonusWorldRecord, "View the leaderboard of a map. Usage: sm_bwr [map] [bonus number]");
	RegConsoleCmd("sm_bworldrecord", Command_BonusWorldRecord, "View the leaderboard of a map. Usage: sm_bworldrecord [map] [bonus number]");
	RegConsoleCmd("sm_bonusworldrecord", Command_BonusWorldRecord, "View the leaderboard of a map. Usage: sm_bonusworldrecord [map] [bonus number]");

	RegConsoleCmd("sm_recent", Command_RecentRecords, "View the recent #1 times set.");
	RegConsoleCmd("sm_recentrecords", Command_RecentRecords, "View the recent #1 times set.");
	RegConsoleCmd("sm_rr", Command_RecentRecords, "View the recent #1 times set.");

	RegConsoleCmd("sm_top", Command_Maptops, "main/bonus/stage records");

	// admin commands
	RegAdminCmd("sm_delete", Command_Delete, ADMFLAG_RCON, "Opens a record deletion menu interface.");
	RegAdminCmd("sm_deleterecord", Command_Delete, ADMFLAG_RCON, "Opens a record deletion menu interface.");
	RegAdminCmd("sm_deleterecords", Command_Delete, ADMFLAG_RCON, "Opens a record deletion menu interface.");
	RegAdminCmd("sm_deleteall", Command_DeleteAll, ADMFLAG_RCON, "Deletes all the records for this map.");
}

void RegisterWRCommands(int style)
{
	char sStyleCommands[32][32];
	int iCommands = ExplodeString(gS_StyleStrings[style].sChangeCommand, ";", sStyleCommands, 32, 32, false);

	char sDescription[128];
	FormatEx(sDescription, 128, "View the leaderboard of a map on style %s.", gS_StyleStrings[style].sStyleName);

	for (int x = 0; x < iCommands; x++)
	{
		TrimString(sStyleCommands[x]);
		StripQuotes(sStyleCommands[x]);

		if (strlen(sStyleCommands[x]) < 1)
		{
			continue;
		}


		char sCommand[40];
		FormatEx(sCommand, sizeof(sCommand), "sm_wr%s", sStyleCommands[x]);
		gSM_StyleCommands.SetValue(sCommand, style);
		RegConsoleCmd(sCommand, Command_WorldRecord_Style, sDescription);

		FormatEx(sCommand, sizeof(sCommand), "sm_bwr%s", sStyleCommands[x]);
		gSM_StyleCommands.SetValue(sCommand, style);
		RegConsoleCmd(sCommand, Command_WorldRecord_Style, sDescription);
	}
}

#if defined DEBUG
public Action Command_Junk(int client, int args)
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery),
		"INSERT INTO `playertimes` (auth, map, time, jumps, date, style, strafes, sync) VALUES (%d, '%s', %f, %d, %d, 0, %d, %.02f);",
		GetSteamAccountID(client), gS_Map, GetRandomFloat(10.0, 20.0), GetRandomInt(5, 15), GetTime(), GetRandomInt(5, 15), GetRandomFloat(50.0, 99.99));

	SQL_LockDatabase(gH_SQL);
	SQL_FastQuery(gH_SQL, sQuery);
	SQL_UnlockDatabase(gH_SQL);

	return Plugin_Handled;
}

public Action Command_PrintLeaderboards(int client, int args)
{
	char sArg[8];
	GetCmdArg(1, sArg, 8);

	int iStyle = StringToInt(sArg);
	int iRecords = GetRecordAmount(iStyle, Track_Main);

	ReplyToCommand(client, "Track: Main - Style: %d", iStyle);
	ReplyToCommand(client, "Current PB: %f", gF_PlayerRecord[client][iStyle][0]);
	ReplyToCommand(client, "Count: %d", iRecords);
	ReplyToCommand(client, "Rank: %d", Shavit_GetRankForTime(iStyle, gF_PlayerRecord[client][iStyle][0], iStyle));

	prcache_t pr;

	for(int i = 0; i < iRecords; i++)
	{
		gA_Leaderboard[iStyle][0].GetArray(i, pr, sizeof(pr));
		ReplyToCommand(client, "#%d: %f", i, pr.fTime);
	}

	return Plugin_Handled;
}
#endif

public Action Command_Delete(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	OpenSingleDeleteMenu_Pre(client);

	return Plugin_Handled;
}

public Action Command_DeleteAll(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	OpenAllDeleteMenu_Pre(client);

	return Plugin_Handled;
}

public Action Command_WorldRecord_Style(int client, int args)
{
	char sCommand[128];
	GetCmdArg(0, sCommand, sizeof(sCommand));

	int style = 0;

	if (gSM_StyleCommands.GetValue(sCommand, style))
	{
		gA_WRCache[client].bForceStyle = true;
		gA_WRCache[client].iLastStyle = style;
		Command_WorldRecord(client, args);
	}

	return Plugin_Handled;
}

public Action Command_WorldRecord(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	int track = Track_Main;
	bool havemap = false;

	if(StrContains(sCommand, "sm_b", false) == 0)
	{
		if (args >= 1)
		{
			char arg[6];
			GetCmdArg((args > 1) ? 2 : 1, arg, sizeof(arg));
			track = StringToInt(arg);

			// if the track doesn't fit in the bonus track range then assume it's a map name
			if (args > 1 || (track < Track_Bonus || track > Track_Bonus_Last))
			{
				havemap = true;
			}
		}

		if (track < Track_Bonus || track > Track_Bonus_Last)
		{
			track = Track_Bonus;
		}
	}
	else
	{
		havemap = (args >= 1);
	}

	if(!havemap)
	{
		gA_WRCache[client].sClientMap = gS_Map;
	}
	else
	{
		GetCmdArg(1, gA_WRCache[client].sClientMap, sizeof(wrcache_t::sClientMap));
		LowercaseString(gA_WRCache[client].sClientMap);

		if (!GuessBestMapName(gA_ValidMaps, gA_WRCache[client].sClientMap, gA_WRCache[client].sClientMap))
		{
			Shavit_PrintToChat(client, "%t", "Map was not found", gA_WRCache[client].sClientMap);
			return Plugin_Handled;
		}
	}

	gA_WRCache[client].iLastTrack = track;

	RetrieveWRMenu(client, track);
	return Plugin_Handled;
}

public Action Command_BonusWorldRecord(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	bool havemap = (args >= 1);

	// if the track doesn't fit in the bonus track range then assume it's a map name
	if (args > 1)
	{
		havemap = true;
	}

	if(!havemap)
	{
		strcopy(gA_WRCache[client].sClientMap, 128, gS_Map);
	}

	else
	{
		GetCmdArg(1, gA_WRCache[client].sClientMap, 128);
		if (!GuessBestMapName(gA_ValidMaps, gA_WRCache[client].sClientMap, gA_WRCache[client].sClientMap))
		{
			Shavit_PrintToChat(client, "%t", "Map was not found", gA_WRCache[client].sClientMap);
			return Plugin_Handled;
		}
	}

	OpenBonusWRMenu(client);

	return Plugin_Handled;
}

public Action Command_RecentRecords(int client, int args)
{
	if(gA_WRCache[client].bPendingMenu || !IsValidClient(client))
	{
		return Plugin_Handled;
	}

	OpenRRMenu(client);

	gA_WRCache[client].bPendingMenu = true;

	return Plugin_Handled;
}

public Action Command_Maptops(int client, int args)
{
	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	bool havemap = (args >= 1);

	// if the track doesn't fit in the bonus track range then assume it's a map name
	if (args > 1)
	{
		havemap = true;
	}

	if(!havemap)
	{
		strcopy(gA_WRCache[client].sClientMap, 128, gS_Map);
	}

	else
	{
		GetCmdArg(1, gA_WRCache[client].sClientMap, 128);
		if (!GuessBestMapName(gA_ValidMaps, gA_WRCache[client].sClientMap, gA_WRCache[client].sClientMap))
		{
			Shavit_PrintToChat(client, "%t", "Map was not found", gA_WRCache[client].sClientMap);
			return Plugin_Handled;
		}
	}

	OpenMaptopMenu(client);

	return Plugin_Handled;
}
