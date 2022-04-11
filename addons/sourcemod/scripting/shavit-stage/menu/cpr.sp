void OpenCPRMenu(int client, int rank)
{
	int steamid = Shavit_GetSteamidForRank(0, rank, 0);
	if(steamid == -1)
	{
		Shavit_PrintToChat(client, "No records info");
		return;
	}

	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), sql_get_cpr_info, gS_Map, steamid);

	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteCell(steamid);

	gH_SQL.Query(SQL_GetWRCPsInfomation_Callback, sQuery, dp);
}

public void SQL_GetWRCPsInfomation_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	int steamid = dp.ReadCell();

	delete dp;

	if(results == null)
	{
		LogError("Timer (Stage GetWRCheckpointInfomation) SQL query failed. Reason: %s", error);

		return;
	}

	Menu menu = new Menu(CPRMenu_Handler);

	char sName[MAX_NAME_LENGTH];
	if(results.FetchRow())
	{
		results.FetchString(4, sName, MAX_NAME_LENGTH);
	}
	menu.SetTitle("Records Info [%s]", sName);

	for(int i = 0; i < TRACKS_SIZE; i++)
	{
		char sTrack[32];
		GetTrackName(client, i, sTrack, 32);

		int rank = Shavit_GetRankForSteamid(0, steamid, i);
		if(rank == 0)
		{
			continue;
		}

		char sWRTime[32];
		float wrTime = Shavit_GetTimeForRank(0, rank, i);
		FormatHUDSeconds(wrTime, sWRTime, 32);

		char sDiff[32];
		float diff = Shavit_GetClientPB(client, 0, i) - wrTime;
		FormatHUDSeconds(diff, sDiff, 32);

		char sItem[64];
		FormatEx(sItem, 64, 
			"%s: %s (%s)\n"...
			"    Rank: %d/%d\n"...
			" ", 
			sTrack, sWRTime, sDiff, rank, Shavit_GetRecordAmount(0, 0));
		menu.AddItem("track", sItem);
	}

	bool bLinear = Shavit_IsLinearMap();

	char sCP[8];
	if(bLinear)
	{
		FormatEx(sCP, 8, "CP");
	}
	else
	{
		FormatEx(sCP, 8, "Stage");
	}

	while(results.FetchRow())
	{
		float time = results.FetchFloat(0);
		char sTime[32];
		FormatHUDSeconds(time, sTime, 32);

		int cp = results.FetchInt(1);
		float startSpeed = results.FetchFloat(2);

		char sItem[64];
		FormatEx(sItem, 64, 
			"%s %d: %s\n"...
			"    Start: %d u/s\n"...
			" ", 
			sCP, cp, sTime, RoundToFloor(startSpeed));
		menu.AddItem("cp", sItem);
	}

	menu.Display(client, -1);
}

public int CPRMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{

	}
	
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}