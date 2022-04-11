/*
	Caches all the wrstage(zone's stage) data on the map.
*/



void DB_ReloadWRStages()
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), sql_reload_wr_stages, gS_Map);

	gH_SQL.Query(SQL_ReloadWRCP_Callback, sQuery);

	DB_UpdateStageLeaderboards();
}

public void SQL_ReloadWRCP_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (LoadWRCP) SQL query failed. Reason: %s", error);
		return;
	}

	while(results.FetchRow())
	{
		int style = results.FetchInt(0);
		int stage = results.FetchInt(1);
		gA_WRStageInfo[style][stage].iSteamid = results.FetchInt(2);
		gA_WRStageInfo[style][stage].fTime = results.FetchFloat(3);
		gA_WRStageInfo[style][stage].fPostspeed = results.FetchFloat(4);
		results.FetchString(5, gA_WRStageInfo[style][stage].sName, MAX_NAME_LENGTH);
	}
}

void DB_DeleteStageData(int style, int stage, int steamid, const char[] mapname, SQLQueryCallback callback, any data)
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), sql_delete_data_stage, stage, style, mapname, steamid);

	gH_SQL.Query(callback, sQuery, data, DBPrio_High);
}