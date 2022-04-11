void DB_Recalculate(bool bUseCurrentMap, int track, int style)
{
	char sQuery[1024];
	FormatRecalculate(bUseCurrentMap, track, style, sQuery, sizeof(sQuery));

	gH_SQL_b.Query(SQL_Recalculate_Callback, sQuery, (style << 8) | track, DBPrio_High);
}

void DB_RecalculateCurrentMap()
{
	char sQuery[1024];

	for(int i = 0; i < gI_Styles; i++)
	{
		FormatRecalculate(true, Track_Main, i, sQuery, sizeof(sQuery));
		gH_SQL_b.Query(SQL_Recalculate_Callback, sQuery, (i << 8) | 0, DBPrio_High);
		FormatRecalculate(true, Track_Bonus, i, sQuery, sizeof(sQuery));
		gH_SQL.Query(SQL_Recalculate_Callback, sQuery, (i << 8) | 1, DBPrio_High);
	}
}

public void SQL_Recalculate_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int track = data & 0xFF;
	int style = data >> 8;

	if(results == null)
	{
		LogError("Timer (rankings, recalculate map points, %s, style=%d) error! Reason: %s", (track == Track_Main) ? "main" : "bonus", style, error);

		return;
	}
}

void DB_UpdateAllPoints(bool recalcall = false)
{
	char sQuery[512];
	char sLastLogin[256];

	if (recalcall || gCV_LastLoginRecalculate.IntValue == 0)
	{
		FormatEx(sLastLogin, sizeof(sLastLogin), "lastlogin > %d", (GetTime() - gCV_LastLoginRecalculate.IntValue * 60));
	}

	if (gCV_WeightingMultiplier.FloatValue == 1.0)
	{
		FormatEx(sQuery, sizeof(sQuery), mysql_disable_weighing_multiplier, (sLastLogin[0] != 0) ? "WHERE" : "", sLastLogin);
	}
	else
	{
		FormatEx(sQuery, sizeof(sQuery), mysql_enable_weighing_multiplier, sLastLogin, (sLastLogin[0] != 0) ? "AND" : "");
	}

	gH_SQL.Query(SQL_UpdateAllPoints_Callback, sQuery);
}

public void SQL_UpdateAllPoints_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (rankings, update all points) error! Reason: %s", error);

		return;
	}

	DB_UpdateRankedPlayers();
}

void DB_RecalcAllRankings(int client)
{
	Transaction2 trans = new Transaction2();
	char sQuery[1024];

	FormatEx(sQuery, sizeof(sQuery), "UPDATE playertimes SET points = 0;");
	trans.AddQuery(sQuery);
	FormatEx(sQuery, sizeof(sQuery), "UPDATE users SET points = 0;");
	trans.AddQuery(sQuery);

	for(int i = 0; i < gI_Styles; i++)
	{
		if (!Shavit_GetStyleSettingBool(i, "unranked") && Shavit_GetStyleSettingFloat(i, "rankingmultiplier") != 0.0)
		{
			FormatRecalculate(false, Track_Main, i, sQuery, sizeof(sQuery));
			trans.AddQuery(sQuery);
			FormatRecalculate(false, Track_Bonus, i, sQuery, sizeof(sQuery));
			trans.AddQuery(sQuery);
		}
	}

	gH_SQL.Execute(trans, Trans_OnRecalcSuccess, Trans_OnRecalcFail, (client == 0)? 0:GetClientSerial(client));
}

public void Trans_OnRecalcSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	int client = (data == 0)? 0:GetClientFromSerial(data);

	if(client != 0)
	{
		SetCmdReplySource(SM_REPLY_TO_CONSOLE);
	}

	ReplyToCommand(client, "- Finished recalculating all points. Recalculating user points, top 100 and user cache.");

	DB_UpdateAllPoints(true);
	DB_UpdateTop100();

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsClientAuthorized(i))
		{
			DB_UpdatePlayerRank(i, false);
		}
	}

	ReplyToCommand(client, "- Done.");
}

public void Trans_OnRecalcFail(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Timer (rankings) error! Recalculation failed. Reason: %s", error);
}