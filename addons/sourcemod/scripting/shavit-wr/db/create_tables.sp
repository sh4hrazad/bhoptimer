/*
	Table creation and alteration.
*/



void DB_CreateTables(bool mysql)
{
	Transaction hTransaction = new Transaction();

	if(mysql)
	{
		hTransaction.AddQuery(mysql_playertimes_create);
		hTransaction.AddQuery(mysql_wrs_min_create);
		hTransaction.AddQuery(mysql_wrs_create);
	}
	else
	{
		hTransaction.AddQuery(sqlite_playertimes_create);
		hTransaction.AddQuery(sqlite_wrs_min_create);
		hTransaction.AddQuery(sqlite_wrs_create);
	}

	gH_SQL.Execute(hTransaction, Trans_CreateTable_Success, Trans_CreateTable_Error, 0, DBPrio_High);
}

public void Trans_CreateTable_Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	gB_Connected = true;

	OnMapStart();
}

public void Trans_CreateTable_Error(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("shavit-wr SQL query %d/%d failed. Reason: %s", failIndex, numQueries, error);
}