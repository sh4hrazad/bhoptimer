/*
	Table creation and alteration.
*/



void DB_CreateTables(bool mysql)
{
	if(mysql)
	{
		gH_SQL.Query(SQL_CreateTable_Callback, mysql_create_table_chat);
	}
	else
	{
		gH_SQL.Query(SQL_CreateTable_Callback, sqlite_create_table_chat);
	}
}

public void SQL_CreateTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer error! Chat table creation failed. Reason: %s", error);

		return;
	}

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && gCV_CustomChat.IntValue > 0)
		{
			DB_LoadChatSettings(i);
		}
	}
}