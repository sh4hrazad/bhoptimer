/*
	Set up the connection to the shavit database.
*/



void SQL_DBConnect()
{
	gH_SQL = GetTimerDatabaseHandle2(false);

	DB_CreateTables(IsMySQLDatabase(gH_SQL));
}