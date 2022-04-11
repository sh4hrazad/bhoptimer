/*
	Caches the player's personal best times on the map.
*/



void DB_CachePBs(int client, int steamid)
{
	if(steamid == 0)
	{
		return;
	}

	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), mysql_update_client_cache, gS_Map, steamid);
	gH_SQL.Query(SQL_UpdateCache_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_UpdateCache_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (PB cache update) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	OnClientConnected(client);

	while(results.FetchRow())
	{
		int style = results.FetchInt(1);
		int track = results.FetchInt(2);

		if(style >= gI_Styles || style < 0 || track >= TRACKS_SIZE)
		{
			continue;
		}

		gF_PlayerRecord[client][style][track] = ExactTimeMaybe(results.FetchFloat(0), results.FetchInt(4));
		gI_PlayerCompletion[client][style][track] = results.FetchInt(3);
		gF_PlayerPrestrafe[client][style][track] = results.FetchFloat(5);
	}

	gB_LoadedCache[client] = true;
}