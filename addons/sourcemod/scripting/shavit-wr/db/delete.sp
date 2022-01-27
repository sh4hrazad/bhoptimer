/*
	Table data deletion.
*/



void DB_DeleteUserData(int steamid)
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), mysql_delete_userdata, steamid);

	gH_SQL.Query(SQL_DeleteUserData_GetRecords_Callback, sQuery, steamid, DBPrio_High);
}

public void SQL_DeleteUserData_GetRecords_Callback(Database db, DBResultSet results, const char[] error, int iSteamID)
{
	if(results == null)
	{
		LogError("Timer error! Failed to wipe user data (wipe | get player records). Reason: %s", error);
		return;
	}

	char map[PLATFORM_MAX_PATH];

	while(results.FetchRow())
	{
		int id = results.FetchInt(0);
		int style = results.FetchInt(1);
		int track = results.FetchInt(2);
		results.FetchString(3, map, sizeof(map));

		DB_DeleteWR(style, track, map, iSteamID, id, false, false);
	}
}

void DB_DeleteMapAllRecords(const char[] map)
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), mysql_delete_all_by_map, map);
	gH_SQL.Query(SQL_DeleteMap_Callback, sQuery, StrEqual(gS_Map, map, false), DBPrio_High);
}

public void DeleteWR_Callback(Database db, DBResultSet results, const char[] error, DataPack hPack)
{
	hPack.Reset();

	int style = hPack.ReadCell();
	int track = hPack.ReadCell();
	char map[PLATFORM_MAX_PATH];
	hPack.ReadString(map, sizeof(map));
	bool update_cache = view_as<bool>(hPack.ReadCell());
	int steamid = hPack.ReadCell();
	int recordid = hPack.ReadCell();

	delete hPack;

	if(results == null)
	{
		LogError("Timer (WR DB_DeleteWR) SQL query failed. Reason: %s", error);
		return;
	}

	DB_DeleteWRFinal(style, track, map, steamid, recordid, update_cache);
}

public void DeleteWRGetID_Callback(Database db, DBResultSet results, const char[] error, DataPack hPack)
{
	if(results == null || !results.FetchRow())
	{
		LogError("Timer (WR DeleteWRGetID) SQL query failed. Reason: %s", error);
		return;
	}

	DB_DeleteWRInner(results.FetchInt(0), results.FetchInt(1), hPack);
}

void DB_DeleteWR(int style, int track, const char[] map, int steamid, int recordid, bool delete_sql, bool update_cache)
{
	if (delete_sql)
	{
		DataPack hPack = new DataPack();
		hPack.WriteCell(style);
		hPack.WriteCell(track);
		hPack.WriteString(map);
		hPack.WriteCell(update_cache);

		char sQuery[512];

		if (recordid == -1) // missing WR recordid thing...
		{
			FormatEx(sQuery, sizeof(sQuery), mysql_delete_wr_get_id, map, style, track);
			gH_SQL.Query(DeleteWRGetID_Callback, sQuery, hPack, DBPrio_High);
		}
		else
		{
			DB_DeleteWRInner(recordid, steamid, hPack);
		}
	}
	else
	{
		DB_DeleteWRFinal(style, track, map, steamid, recordid, update_cache);
	}
}

void DB_DeleteWRInner(int recordid, int steamid, DataPack hPack)
{
	hPack.WriteCell(steamid);
	hPack.WriteCell(recordid);

	char sQuery[169];
	FormatEx(sQuery, sizeof(sQuery), mysql_delete_by_id, recordid);
	gH_SQL.Query(DeleteWR_Callback, sQuery, hPack, DBPrio_High);
}

void DB_DeleteWRFinal(int style, int track, const char[] map, int steamid, int recordid, bool update_cache)
{
	Call_OnWRDeleted(style, recordid, track, steamid, map);

	if (update_cache)
	{
		UpdateWRCache();
	}
}

public void SQL_DeleteMap_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR deletemap) SQL query failed. Reason: %s", error);

		return;
	}

	if(view_as<bool>(data))
	{
		OnMapStart();
	}
}