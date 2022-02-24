/*
	Table creation and alteration.
*/



void DB_CreateTables()
{
	Transaction2 hTransaction = new Transaction2();

	if(gB_MySQL)
	{
		hTransaction.AddQuery(mysql_playertimes_create);
		hTransaction.AddQuery(mysql_wrs_min_create);
		hTransaction.AddQuery(mysql_wrs_create);
	}
	else
	{
		SetFailState("shavit-wr only support mysql database.");
		delete hTransaction;
		return;
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