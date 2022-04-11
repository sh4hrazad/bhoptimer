/*
	Table creation and alteration.
*/



void DB_CreateTables()
{
	gH_SQL.Query(SQL_Version_Callback, "SELECT VERSION();");

	char sQuery[2048];
	Transaction2 hTrans = new Transaction2();

	FormatEx(sQuery, sizeof(sQuery), mysql_maptiers_create, gCV_DefaultTier.IntValue, gCV_DefaultMaxvelocity.FloatValue);
	hTrans.AddQuery(sQuery);

	hTrans.AddQuery("DROP PROCEDURE IF EXISTS DB_UpdateAllPoints;;"); // old (and very slow) deprecated method
	hTrans.AddQuery("DROP FUNCTION IF EXISTS GetWeightedPoints;;"); // this is here, just in case we ever choose to modify or optimize the calculation
	hTrans.AddQuery("DROP FUNCTION IF EXISTS GetRecordPoints;;");

	char sWeightingLimit[30];

	if (gCV_WeightingLimit.IntValue > 0)
	{
		FormatEx(sWeightingLimit, sizeof(sWeightingLimit), "LIMIT %d", gCV_WeightingLimit.IntValue);
	}

	FormatEx(sQuery, sizeof(sQuery), mysql_function_GetWeightedPoints_create, sWeightingLimit, gCV_WeightingMultiplier.FloatValue);

	if (gCV_WeightingMultiplier.FloatValue != 1.0)
	{
		hTrans.AddQuery(sQuery);
	}

	gH_SQL.Execute(hTrans, Trans_RankingsSetupSuccess, Trans_RankingsSetupError, 0, DBPrio_High);
}

public void SQL_Version_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null || !results.FetchRow())
	{
		LogError("Timer (rankings) error! Failed to retrieve VERSION(). Reason: %s", error);
	}
	else
	{
		char sVersion[100];
		results.FetchString(0, sVersion, sizeof(sVersion));
		gB_HasSQLRANK = DoWeHaveRANK(sVersion);
	}

	char sWRHolderRankTrackQueryYuck[] =
		"CREATE OR REPLACE VIEW `%s` AS \
			SELECT \
			0 as wrrank, \
			style, auth, COUNT(auth) as wrcount \
			FROM `wrs` WHERE track %c 0 GROUP BY style, auth;";

	char sWRHolderRankTrackQueryRANK[] =
		"CREATE OR REPLACE VIEW `%s` AS \
			SELECT \
				RANK() OVER(PARTITION BY style ORDER BY wrcount DESC, auth ASC) \
			as wrrank, \
			style, auth, COUNT(auth) as wrcount \
			FROM `wrs` WHERE track %c 0 GROUP BY style, auth;";

	char sWRHolderRankOtherQueryYuck[] =
		"CREATE OR REPLACE VIEW `%s` AS \
			SELECT \
			0 as wrrank, \
			-1 as style, auth, COUNT(*) \
			FROM `wrs` %s %s %s %s GROUP BY auth;";

	char sWRHolderRankOtherQueryRANK[] =
		"CREATE OR REPLACE VIEW `%s` AS \
			SELECT \
				RANK() OVER(ORDER BY wrcount DESC, auth ASC) \
			as wrrank, \
			-1 as style, auth, COUNT(*) as wrcount \
			FROM `wrs` %s %s %s %s GROUP BY auth;";

	char sQuery[800];
	Transaction2 hTransaction = new Transaction2();

	FormatEx(sQuery, sizeof(sQuery),
		!gB_HasSQLRANK ? sWRHolderRankTrackQueryYuck : sWRHolderRankTrackQueryRANK,
		"wrhrankmain", '=');
	hTransaction.AddQuery(sQuery);

	FormatEx(sQuery, sizeof(sQuery),
		!gB_HasSQLRANK ? sWRHolderRankTrackQueryYuck : sWRHolderRankTrackQueryRANK,
		"wrhrankbonus", '>');
	hTransaction.AddQuery(sQuery);

	FormatEx(sQuery, sizeof(sQuery),
		!gB_HasSQLRANK ? sWRHolderRankOtherQueryYuck : sWRHolderRankOtherQueryRANK,
		"wrhrankall", "", "", "", "");
	hTransaction.AddQuery(sQuery);

	FormatEx(sQuery, sizeof(sQuery),
		!gB_HasSQLRANK ? sWRHolderRankOtherQueryYuck : sWRHolderRankOtherQueryRANK,
		"wrhrankcvar",
		(gCV_MVPRankOnes.IntValue == 2 || gCV_MVPRankOnes_Main.BoolValue) ? "WHERE" : "",
		(gCV_MVPRankOnes.IntValue == 2)  ? "style = 0" : "",
		(gCV_MVPRankOnes.IntValue == 2 && gCV_MVPRankOnes_Main.BoolValue) ? "AND" : "",
		(gCV_MVPRankOnes_Main.BoolValue) ? "track = 0" : "");
	hTransaction.AddQuery(sQuery);

	gH_SQL.Execute(hTransaction, Trans_WRHolderRankTablesSuccess, Trans_WRHolderRankTablesError, 0, DBPrio_High);
}

public void Trans_WRHolderRankTablesSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	gB_WRHolderTablesMade = true;
	DB_RefreshWRHolders();
}

public void Trans_WRHolderRankTablesError(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Timer (WR Holder Rank table creation %d/%d) SQL query failed. Reason: %s", failIndex, numQueries, error);
}

public void Trans_RankingsSetupSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	if(gI_Styles == 0)
	{
		Shavit_OnStyleConfigLoaded(Shavit_GetStyleCount());
	}

	OnMapStart();
}

public void Trans_RankingsSetupError(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Timer (rankings) error %d/%d. Reason: %s", failIndex, numQueries, error);
}



// ======[ PRIVATE ]======

static bool DoWeHaveRANK(const char[] sVersion)
{
	float fVersion = StringToFloat(sVersion);

	if (StrContains(sVersion, "MariaDB") != -1)
	{
		return fVersion >= 10.2;
	}
	else // mysql then...
	{
		return fVersion >= 8.0;
	}
}