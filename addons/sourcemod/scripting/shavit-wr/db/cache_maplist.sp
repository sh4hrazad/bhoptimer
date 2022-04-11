/*
	Caches the maplist.
*/



void DB_CacheMaps()
{
	gH_SQL.Query(SQL_UpdateMaps_Callback, mysql_update_maps, 0, DBPrio_Low);
}

public void SQL_UpdateMaps_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR maps cache update) SQL query failed. Reason: %s", error);

		return;
	}

	while(results.FetchRow())
	{
		char sMap[PLATFORM_MAX_PATH];
		results.FetchString(0, sMap, sizeof(sMap));
		LowercaseString(sMap);

		if(gA_ValidMaps.FindString(sMap) == -1)
		{
			gA_ValidMaps.PushString(sMap);
		}
	}

	SortADTArray(gA_ValidMaps, Sort_Ascending, Sort_String);
}