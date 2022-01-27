/*
	Set up the connection to the shavit database.
*/



void SQL_DBConnect()
{
	gH_SQL = GetTimerDatabaseHandle2(false);
	gB_MySQL = IsMySQLDatabase(gH_SQL);

	DB_CreateTables();
}