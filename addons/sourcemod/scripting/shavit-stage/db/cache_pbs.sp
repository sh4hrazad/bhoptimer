/*
	Caches all the stage(zone's stage) and cp(zone's stage or checkpoint) data on the map.
*/



void DB_ReloadStageInfo(int client)
{
	if(!IsValidClient(client))
	{
		return;
	}

	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), sql_reload_stage_info, GetSteamAccountID(client), gS_Map);

	gH_SQL.Query(SQL_ReloadStageInfo_Callback, sQuery, GetClientSerial(client));
}

public void SQL_ReloadStageInfo_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (ReloadStageInfo) SQL query failed. Reason: %s", error);
		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	while(results.FetchRow())
	{
		int style = results.FetchInt(0);
		int stage = results.FetchInt(1);

		gA_StageInfo[client][style][stage].iSteamid = GetSteamAccountID(client);
		gA_StageInfo[client][style][stage].iDate = results.FetchInt(2);
		gA_StageInfo[client][style][stage].iCompletions = results.FetchInt(3);
		gA_StageInfo[client][style][stage].fTime = results.FetchFloat(4);
		gA_StageInfo[client][style][stage].fPostspeed = results.FetchFloat(5);
		GetClientName(client, gA_StageInfo[client][style][stage].sName, sizeof(stage_t::sName));
	}
}

void DB_ReloadCPInfo(int client)
{
	if(!IsValidClient(client))
	{
		return;
	}

	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), sql_reload_checkpoint_info, GetSteamAccountID(client), gS_Map);

	gH_SQL.Query(SQL_ReloadCPInfo_Callback, sQuery, GetClientSerial(client));
}

public void SQL_ReloadCPInfo_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (ReloadCPInfo) SQL query failed. Reason: %s", error);
		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	while(results.FetchRow())
	{
		int style = results.FetchInt(0);
		int cp = results.FetchInt(1);

		gA_CheckpointInfo[client][style][cp].iAttemps = results.FetchInt(2);
		gA_CheckpointInfo[client][style][cp].iDate = results.FetchInt(3);
		gA_CheckpointInfo[client][style][cp].fTime = results.FetchFloat(4);
		gA_CheckpointInfo[client][style][cp].fRealTime = results.FetchFloat(5);
		gA_CheckpointInfo[client][style][cp].fPrespeed = results.FetchFloat(6);
		gA_CheckpointInfo[client][style][cp].fPostspeed = results.FetchFloat(7);
	}
}