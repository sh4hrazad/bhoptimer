void DB_UpdatePlayerRank(int client, bool first)
{
	gA_Rankings[client].iRank = 0;
	gA_Rankings[client].fPoints = 0.0;

	int iSteamID = 0;

	if((iSteamID = GetSteamAccountID(client)) != 0)
	{
		// if there's any issue with this query,
		// add "ORDER BY points DESC " before "LIMIT 1"
		char sQuery[512];
		FormatEx(sQuery, 512, mysql_UpdatePlayerRank, iSteamID);

		DataPack hPack = new DataPack();
		hPack.WriteCell(GetClientSerial(client));
		hPack.WriteCell(first);

		gH_SQL.Query(SQL_UpdatePlayerRank_Callback, sQuery, hPack, DBPrio_Low);
	}
}

public void SQL_UpdatePlayerRank_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack hPack = view_as<DataPack>(data);
	hPack.Reset();

	int iSerial = hPack.ReadCell();
	bool bFirst = view_as<bool>(hPack.ReadCell());
	delete hPack;

	if(results == null)
	{
		LogError("Timer (rankings, update player rank) error! Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(iSerial);

	if(client == 0)
	{
		return;
	}

	if(results.FetchRow())
	{
		gA_Rankings[client].fPoints = results.FetchFloat(0);
		gA_Rankings[client].iRank = (gA_Rankings[client].fPoints > 0.0)? results.FetchInt(1):0;

		Call_OnRankAssigned(client, gA_Rankings[client].iRank, gA_Rankings[client].fPoints, bFirst);
	}
}

void DB_UpdateRankedPlayers()
{
	char sQuery[512];
	FormatEx(sQuery, 512, mysql_UpdateRankedPlayers);

	gH_SQL.Query(SQL_UpdateRankedPlayers_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_UpdateRankedPlayers_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (rankings, update ranked players) error! Reason: %s", error);

		return;
	}

	if(results.FetchRow())
	{
		gI_RankedPlayers = results.FetchInt(0);

		DB_UpdateTop100();
	}
}

void DB_UpdateTop100()
{
	gH_SQL.Query(SQL_UpdateTop100_Callback, mysql_UpdateTop100, 0, DBPrio_Low);
}

public void SQL_UpdateTop100_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (rankings, update top 100) error! Reason: %s", error);

		return;
	}

	if(gH_Top100Menu != null)
	{
		delete gH_Top100Menu;
	}

	gH_Top100Menu = new Menu(MenuHandler_Top);

	int row = 0;

	while(results.FetchRow())
	{
		if(row > 100)
		{
			break;
		}

		char sSteamID[32];
		results.FetchString(0, sSteamID, 32);

		char sName[MAX_NAME_LENGTH];
		results.FetchString(1, sName, MAX_NAME_LENGTH);

		char sPoints[16];
		results.FetchString(2, sPoints, 16);

		char sDisplay[96];
		FormatEx(sDisplay, 96, "#%d - %s (%s)", (++row), sName, sPoints);
		gH_Top100Menu.AddItem(sSteamID, sDisplay);
	}

	if(gH_Top100Menu.ItemCount == 0)
	{
		char sDisplay[64];
		FormatEx(sDisplay, 64, "%t", "NoRankedPlayers");
		gH_Top100Menu.AddItem("-1", sDisplay);
	}

	gH_Top100Menu.ExitButton = true;
}