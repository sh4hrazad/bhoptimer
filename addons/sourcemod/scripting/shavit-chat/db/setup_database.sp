/*
	Set up the connection to the shavit database.
*/



void SQL_DBConnect()
{
	gH_SQL = GetTimerDatabaseHandle2(false);
	if(!IsMySQLDatabase(gH_SQL))
	{
		SetFailState("shavit-chat module only support for mysql.");
		return;
	}

	DB_CreateTables();
}