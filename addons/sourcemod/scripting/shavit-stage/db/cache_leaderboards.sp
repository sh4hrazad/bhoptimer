/*
	Caches all the stage times data on the map.
*/



void DB_UpdateStageLeaderboards()
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), sql_update_stage_leaderboards, gS_Map);
	gH_SQL.Query(SQL_UpdateStageLeaderboards_Callback, sQuery);
}

public void SQL_UpdateStageLeaderboards_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (Stage UpdateLeaderboards) SQL query failed. Reason: %s", error);

		return;
	}

	ResetStageLeaderboards();

	while(results.FetchRow())
	{
		int style = results.FetchInt(0);
		int stage = results.FetchInt(1);

		if(style >= gI_Styles || Shavit_GetStyleSettingInt(style, "unranked") || stage > MAX_STAGES)
		{
			continue;
		}

		stage_t stagepb;
		stagepb.iSteamid = results.FetchInt(2);
		stagepb.iDate = results.FetchInt(3);
		stagepb.iCompletions = results.FetchInt(4);
		stagepb.fTime = results.FetchFloat(5);
		stagepb.fPostspeed = results.FetchFloat(6);
		results.FetchString(7, stagepb.sName, MAX_NAME_LENGTH);

		gA_StageLeaderboard[style][stage].PushArray(stagepb);
	}
}