/*
	Table creation and alteration.
*/



void DB_CreateTables(bool mysql)
{
	Transaction hTransaction = new Transaction();

	if(mysql)
	{
		hTransaction.AddQuery(mysql_stagetimes_create);
		hTransaction.AddQuery(mysql_cptimes_create);
		hTransaction.AddQuery(mysql_stagewrs_min_create);
		hTransaction.AddQuery(mysql_stagewrs_create);
		hTransaction.AddQuery(mysql_cpwrs_create);
	}
	else
	{
		hTransaction.AddQuery(sqlite_stagetimes_create);
		hTransaction.AddQuery(sqlite_cptimes_create);
		hTransaction.AddQuery(sqlite_stagewrs_min_create);
		hTransaction.AddQuery(sqlite_stagewrs_create);
		hTransaction.AddQuery(sqlite_cpwrs_create);
	}

	gH_SQL.Execute(hTransaction, Trans_CreateTable_Success, Trans_CreateTable_Failed);
}

public void Trans_CreateTable_Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	gB_Connected = true;
	OnMapStart();
}

public void Trans_CreateTable_Failed(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Timer (stage module) error! 'Map stage or cp' table creation failed %d/%d. Reason: %s", failIndex, numQueries, error);
}