/*
	Set up the connection to the shavit database.
*/



void SQL_DBConnect()
{
	gH_SQL = GetTimerDatabaseHandle2(false);
	gH_SQL_b = GetTimerDatabaseHandle2(false);

	if(!IsMySQLDatabase(gH_SQL))
	{
		SetFailState("MySQL is the only supported database engine for shavit-rankings.");
	}

	DB_CreateTables();
}