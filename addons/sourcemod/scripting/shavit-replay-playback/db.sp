void SQL_DBConnect()
{
	gH_SQL = GetTimerDatabaseHandle2();
}

void DB_GetUserName(int style, int track, int steamid)
{
	char sQuery[192];
	FormatEx(sQuery, 192, "SELECT name FROM `users` WHERE auth = %d;", steamid);

	DataPack hPack = new DataPack();
	hPack.WriteCell(style);
	hPack.WriteCell(track);

	gH_SQL.Query(SQL_GetUserName_Callback, sQuery, hPack, DBPrio_High);
}

public void SQL_GetUserName_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int style = data.ReadCell();
	int track = data.ReadCell();
	delete data;

	if(results == null)
	{
		LogError("Timer error! Get user name (replay) failed. Reason: %s", error);

		return;
	}

	if(results.FetchRow())
	{
		results.FetchString(0, gA_FrameCache[style][track].sReplayName, MAX_NAME_LENGTH);
	}
}

void DB_GetStageUserName(int style, int stage, int steamid)
{
	char sQuery[192];
	FormatEx(sQuery, 192, "SELECT name FROM `users` WHERE auth = %d;", steamid);

	DataPack hPack = new DataPack();
	hPack.WriteCell(style);
	hPack.WriteCell(stage);

	gH_SQL.Query(SQL_GetStageUserName_Callback, sQuery, hPack, DBPrio_High);
}

public void SQL_GetStageUserName_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int style = data.ReadCell();
	int stage = data.ReadCell();
	delete data;

	if(results == null)
	{
		LogError("Timer error! Get stage user name (replay) failed. Reason: %s", error);

		return;
	}

	if(results.FetchRow())
	{
		results.FetchString(0, gA_FrameCache_Stage[style][stage].sReplayName, MAX_NAME_LENGTH);
	}
}