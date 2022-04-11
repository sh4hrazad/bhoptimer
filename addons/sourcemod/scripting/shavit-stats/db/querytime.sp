// ======[ EVENTS ]======

void OnClientAuthorized_QueryPlaytime(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}

	QueryPlaytime(client);
}

void QueryPlaytime(int client)
{
	if (gH_SQL == null)
	{
		return;
	}

	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), mysql_query_style_playtime, GetSteamAccountID(client));
	gH_SQL.Query(SQL_QueryStylePlaytime_Callback, sQuery, GetClientSerial(client));
}

public void SQL_QueryStylePlaytime_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("Timer (style playtime) SQL query failed. Reason: %s", error);
		return;
	}

	int client = GetClientFromSerial(data);

	if (client == 0)
	{
		return;
	}

	while (results.FetchRow())
	{
		int style = results.FetchInt(0);
		//float playtime = results.FetchFloat(1);
		gB_HavePlaytimeOnStyle[client][style] = true;
	}

	gB_QueriedPlaytime[client] = true;
}