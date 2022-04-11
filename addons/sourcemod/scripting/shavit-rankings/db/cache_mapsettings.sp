void DB_GetMapSettings()
{
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), mysql_GetMapSettings, gS_Map);
	gH_SQL.Query(SQL_GetMapSettings_Callback, sQuery);
}

public void SQL_GetMapSettings_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (rankings, get map settings) error! Reason: %s", error);

		return;
	}

	if(results.FetchRow())
	{
		gI_Tier = results.FetchInt(0);
		gB_Maplimitspeed = view_as<bool>(results.FetchInt(1));
		gF_Maxvelocity = results.FetchFloat(2);
		gCV_Maxvelocity.FloatValue = gF_Maxvelocity;
	}
	else
	{
		DB_SetTier(gI_Tier);
	}

	DB_FillTierCache();
}

void DB_FillTierCache()
{
	gH_SQL.Query(SQL_FillTierCache_Callback, mysql_GetMapTier, 0, DBPrio_High);
}

public void SQL_FillTierCache_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (rankings, fill tier cache) error! Reason: %s", error);

		return;
	}

	gA_ValidMaps.Clear();
	gA_MapTiers.Clear();

	while(results.FetchRow())
	{
		char sMap[PLATFORM_MAX_PATH];
		results.FetchString(0, sMap, sizeof(sMap));
		LowercaseString(sMap);

		int tier = results.FetchInt(1);

		gA_MapTiers.SetValue(sMap, tier);
		gA_ValidMaps.PushString(sMap);

		Call_OnTierAssigned(sMap, tier);
	}

	SortADTArray(gA_ValidMaps, Sort_Ascending, Sort_String);

	if (gA_MapTiers.GetValue(gS_Map, gI_Tier))
	{
		DB_RecalculateCurrentMap();
		DB_UpdateAllPoints();
	}
	else
	{
		DB_SetTier(gI_Tier);
	}
}

void DB_DeleteMapAllSettings(const char[] map)
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), mysql_DeleteMapAllSettings, map);
	gH_SQL.Query(SQL_DeleteMapSettings_Callback, sQuery, StrEqual(gS_Map, map, false), DBPrio_High);
}

public void SQL_DeleteMapSettings_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (rankings deletemap) SQL query failed. Reason: %s", error);

		return;
	}

	if(view_as<bool>(data))
	{
		gI_Tier = gCV_DefaultTier.IntValue;

		DB_UpdateAllPoints(true);
		DB_UpdateRankedPlayers();
	}
}

void DB_ModifyDefaultMaxvel(float maxvel)
{
	char sQuery[128];
	FormatEx(sQuery, sizeof(sQuery), mysql_modify_default_maxvel, maxvel);
	gH_SQL.Query(SQL_ModifyDefMaxvel_Callback, sQuery, maxvel);
}

public void SQL_ModifyDefMaxvel_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (rankings, modify column maxvelocity) error! Reason: %s", error);

		return;
	}

	Shavit_LogMessage("Alter MYSQL table `maptiers` default maxvelocity(%f) successfully!", data);

	DB_GetMapSettings();
}

void DB_SetTier(int tier)
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), mysql_SetMapTier, gS_Map, tier);

	gH_SQL.Query(SQL_SetMapTier_Callback, sQuery);
}

public void SQL_SetMapTier_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (rankings, set map tier) error! Reason: %s", error);

		return;
	}

	DB_RecalculateCurrentMap();
}

void DB_SaveMapSettings(int client, int tier, bool limitspeed, float maxvel)
{
	char sQuery[256];
	FormatEx(sQuery, 256, mysql_SaveMapSettings, tier, view_as<int>(limitspeed), maxvel, gS_Map);

	gH_SQL.Query(SQL_SetMapSettings_Callback, sQuery, GetClientSerial(client));
}

public void SQL_SetMapSettings_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (rankings, set map settings) error! Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		LogError("Cannot save mapsettings for client %d", client);

		return;
	}

	Shavit_LogMessage("%L - map `%s` settings saved.", client, gS_Map);
	Shavit_PrintToChat(client, "地图设置已保存.");
	DB_GetMapSettings();
}