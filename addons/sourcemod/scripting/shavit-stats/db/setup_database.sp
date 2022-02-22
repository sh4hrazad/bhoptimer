/*
	Database connect.
*/



void SQL_DBConnect()
{
	gH_SQL = GetTimerDatabaseHandle2(false);
	gH_SQL.Query(SQL_CreateStylePlaytimeTable_Callback, mysql_table_create);
}

public void SQL_CreateStylePlaytimeTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("Timer (styleplaytime table creation) SQL query failed. Reason: %s", error);
		return;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i) && IsClientAuthorized(i))
		{
			OnClientAuthorized(i, "");
		}
	}
}