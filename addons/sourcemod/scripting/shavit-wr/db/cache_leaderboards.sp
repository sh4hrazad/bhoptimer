/*
	Caches all the track leaderboards on the map.
*/



void DB_UpdateLeaderboards()
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), mysql_update_leaderboards_cache, gS_Map);
	gH_SQL.Query(SQL_UpdateLeaderboards_Callback, sQuery);
}

public void SQL_UpdateLeaderboards_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR UpdateLeaderboards) SQL query failed. Reason: %s", error);

		return;
	}

	ResetLeaderboards();

	while(results.FetchRow())
	{
		int style = results.FetchInt(0);
		int track = results.FetchInt(1);

		if(style >= gI_Styles || Shavit_GetStyleSettingInt(style, "unranked") || track >= TRACKS_SIZE)
		{
			continue;
		}

		prcache_t pr;
		pr.fTime = ExactTimeMaybe(results.FetchFloat(2), results.FetchInt(3));
		pr.iSteamid = results.FetchInt(4);
		pr.fPrestrafe = results.FetchFloat(5);

		gA_Leaderboard[style][track].PushArray(pr);
	}
}