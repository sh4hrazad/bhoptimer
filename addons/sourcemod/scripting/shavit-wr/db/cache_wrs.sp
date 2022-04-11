/*
	Caches all the track wrs on the map.
*/



void DB_CacheWRs()
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), mysql_update_wrs_cache, gS_Map);
	gH_SQL.Query(SQL_UpdateWRCache_Callback, sQuery);
}

public void SQL_UpdateWRCache_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR cache update) SQL query failed. Reason: %s", error);

		return;
	}

	ResetWRs();

	// setup cache again, dynamically and not hardcoded
	while(results.FetchRow())
	{
		int iStyle = results.FetchInt(2);
		int iTrack = results.FetchInt(3);

		if(iStyle >= gI_Styles || iStyle < 0 || Shavit_GetStyleSettingInt(iStyle, "unranked"))
		{
			continue;
		}

		gI_WRRecordID[iStyle][iTrack] = results.FetchInt(0);
		gF_WRTime[iStyle][iTrack] = ExactTimeMaybe(results.FetchFloat(4), results.FetchInt(6));
		gI_WRSteamID[iStyle][iTrack] = results.FetchInt(1);

		char sSteamID[20];
		IntToString(gI_WRSteamID[iStyle][iTrack], sSteamID, sizeof(sSteamID));

		char sName[MAX_NAME_LENGTH];
		results.FetchString(5, sName, MAX_NAME_LENGTH);
		ReplaceString(sName, MAX_NAME_LENGTH, "#", "?");
		gSM_WRNames.SetString(sSteamID, sName, false);
	}

	Call_OnWorldRecordsCached();
}