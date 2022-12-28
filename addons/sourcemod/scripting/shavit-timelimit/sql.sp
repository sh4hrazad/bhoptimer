/*
	Database connect, queries.
*/



static char mysql_start_calculating[] = 
"SELECT COUNT(*), SUM(t.time) "...
	"FROM "...
		"("...
		"SELECT r.time, r.style "...
		"FROM `playertimes` r "...
		"WHERE r.map = '%s' AND r.track = 0 "...
		"%s"...
		"ORDER BY r.time "...
		"LIMIT %d"...
		")"...
	" t;";



// ======[ EVENTS ]======

void SQL_DBConnect()
{
	gH_SQL = GetTimerDatabaseHandle();
}

void StartCalculating()
{
	char sMap[PLATFORM_MAX_PATH];
	GetLowercaseMapName(sMap);

	char sQuery[512];
	FormatEx(sQuery, 512, mysql_start_calculating, 
		sMap, (gCV_Style.BoolValue)? "AND style = 0 ":"", gCV_PlayerAmount.IntValue);

	gH_SQL.Query(SQL_GetMapTimes, sQuery, 0, DBPrio_Low);
}

public void SQL_GetMapTimes(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (TIMELIMIT time selection) SQL query failed. Reason: %s", error);

		return;
	}

	results.FetchRow();
	int iRows = results.FetchInt(0);

	if(iRows >= gCV_MinimumTimes.IntValue)
	{
		float fTimeSum = results.FetchFloat(1);
		float fAverage = (fTimeSum / 60 / gCV_MinimumTimes.IntValue);

		if(fAverage <= 1)
		{
			fAverage *= 10;
		}
		else if(fAverage <= 2)
		{
			fAverage *= 9;
		}
		else if(fAverage <= 4)
		{
			fAverage *= 8;
		}
		else if(fAverage <= 8)
		{
			fAverage *= 7;
		}
		else if(fAverage <= 10)
		{
			fAverage *= 6;
		}
		else
		{
			fAverage *= 5;
		}

		fAverage += 5; // I give extra 5 minutes, so players can actually retry the map until they get a good time.

		if(fAverage < gCV_MinimumLimit.FloatValue)
		{
			fAverage = gCV_MinimumLimit.FloatValue;
		}

		else if(fAverage > gCV_MaximumLimit.FloatValue)
		{
			fAverage = gCV_MaximumLimit.FloatValue;
		}

		SetLimit(RoundToCeil(fAverage / 10) * 10);
	}

	else
	{
		SetLimit(RoundToNearest(gCV_DefaultLimit.FloatValue));
	}
}