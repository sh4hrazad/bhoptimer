/*
	Caches all the wrcp(zone's stage or checkpoint) data on the map.
*/



// This runs after got or delete map wr
void DB_ReloadWRCPs()
{
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), sql_reload_wr_checkpoints, gS_Map);
	gH_SQL.Query(SQL_ReloadWRCPs_Callback, sQuery);
}

public void SQL_ReloadWRCPs_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (LoadWRCheckpoint) SQL query failed. Reason: %s", error);
		return;
	}

	while(results.FetchRow())
	{
		int style = results.FetchInt(0);
		int cpnum = results.FetchInt(1);
		gA_WRCPInfo[style][cpnum].iAttemps = results.FetchInt(2);
		gA_WRCPInfo[style][cpnum].fTime = results.FetchFloat(3);
		gA_WRCPInfo[style][cpnum].fRealTime = results.FetchFloat(4);
		gA_WRCPInfo[style][cpnum].fPrespeed = results.FetchFloat(5);
		gA_WRCPInfo[style][cpnum].fPostspeed = results.FetchFloat(6);
	}
}

void DB_DeleteWRCheckPoints(int style, int accountid, const char[] mapname)
{
	char sQuery[255];
	FormatEx(sQuery, sizeof(sQuery), sql_delete_data_checkpoint, accountid, mapname, style);
	gH_SQL.Query(SQL_DeleteWRCheckPoints_Callback, sQuery);
}

public void SQL_DeleteWRCheckPoints_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WRCPs Delete) SQL query failed. Reason: %s", error);
		return;
	}

	Shavit_PrintToChatAll("管理员删除了WR记录");

	ResetWRCPs();
}