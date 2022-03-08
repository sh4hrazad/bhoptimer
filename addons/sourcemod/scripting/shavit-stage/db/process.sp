void Shavit_OnFinish_Post_DBProcess(int client, int style, int track, int overwrite, int rank)
{
	if(track != Track_Main)
	{
		return;
	}

	bool bLinear = Shavit_IsLinearMap();

	// overwrite
	// 0 - no query
	// 1 - insert
	// 2 - update
	int maxCPs;

	if(bLinear)
	{
		maxCPs = Shavit_GetMapCheckpoints();
	}
	else
	{
		maxCPs = Shavit_GetMapStages();
	}

	if(overwrite > 0)
	{
		Transaction hTransaction = new Transaction();
		char sQuery[512];

		for(int i = 1; i <= maxCPs; i++)
		{
			float prespeed = gF_PreSpeed[client][i];
			float postspeed = gF_PostSpeed[client][i];

			if(overwrite == 1) // insert
			{
				FormatEx(sQuery, sizeof(sQuery), sql_insert_data_checkpoint, GetSteamAccountID(client), gS_Map, gF_CPTime[client][i], gF_CPEnterStageTime[client][i], style, i, gI_CPStageAttemps[client][i], prespeed, postspeed, GetTime());
			}
			else // update
			{
				FormatEx(sQuery, sizeof(sQuery), sql_update_data_checkpoint, gI_CPStageAttemps[client][i], gF_CPTime[client][i], gF_CPEnterStageTime[client][i], style, prespeed, postspeed, GetTime(), GetSteamAccountID(client), i, gS_Map);
			}

			hTransaction.AddQuery(sQuery);
		}

		DataPack dp = new DataPack();
		dp.WriteCell(GetClientSerial(client));
		dp.WriteCell(rank);

		gH_SQL.Execute(hTransaction, Trans_InsertCP_PR_Success, Trans_InsertCP_PR_Failed, dp);
	}
}

public void Trans_InsertCP_PR_Success(Database db, DataPack dp, int numQueries, DBResultSet[] results, any[] queryData)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	bool bWR = (dp.ReadCell() == 1);
	delete dp;

	DB_ReloadCPInfo(client);

	if(bWR)
	{
		DB_ReloadWRCPs();
	}
}

public void Trans_InsertCP_PR_Failed(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Insert CP error! cp %d failed , failIndex: %d. Reason: %s", numQueries, failIndex, error);
}

void DB_OnFinishStage(int client, int stage, int style, float time, float oldtime)
{
	int iOverwrite = PB_NoQuery;

	if(Shavit_GetStyleSettingInt(style, "unranked") || Shavit_IsPracticeMode(client))
	{
		iOverwrite = PB_UnRanked;
	}
	else if(oldtime == 0.0)
	{
		iOverwrite = PB_Insert;
	}
	else if(time < oldtime)
	{
		iOverwrite = PB_Update;
	}

	int iRecords = GetStageRecordAmount(style, stage);
	int iRank = GetStageRankForTime(style, time, stage);
	float wrcpTime = gA_WRStageInfo[style][stage].fTime;
	bool bWRCP = false;

	if(iOverwrite > PB_UnRanked && (time < wrcpTime || wrcpTime == -1.0))
	{
		bWRCP = true;

		Call_OnWRCP(client, stage, style, GetSteamAccountID(client), iRecords, wrcpTime, time, gF_PostSpeed[client][stage], gS_Map);
	}

	if(iOverwrite > PB_NoQuery)
	{
		char sQuery[512];

		if(iOverwrite == PB_Insert)
		{
			FormatEx(sQuery, sizeof(sQuery), sql_insert_data_stage, GetSteamAccountID(client), gS_Map, time, style, stage, gF_PostSpeed[client][stage], GetTime());
		}
		else
		{
			FormatEx(sQuery, sizeof(sQuery), sql_update_data_stage,	time, GetTime(), gF_PostSpeed[client][stage], stage, style, gS_Map, GetSteamAccountID(client));
		}

		DataPack dp = new DataPack();
		dp.WriteCell(GetClientSerial(client));
		dp.WriteCell(bWRCP?1:0);

		gH_SQL.Query(SQL_OnFinishStage_Callback, sQuery, dp, DBPrio_High);
	}
	else if (iOverwrite == PB_NoQuery && !bWRCP)
	{
		char sQuery[512];
		FormatEx(sQuery, sizeof(sQuery), sql_update_completion_stage, stage, style, gS_Map, GetSteamAccountID(client));

		gH_SQL.Query(SQL_OnStageIncrementCompletions_Callback, sQuery, 0, DBPrio_Low);
	}

	Call_OnFinishStage_Post(client, stage, style, time, time - oldtime, iOverwrite, iRecords, iRank, bWRCP, gF_PostSpeed[client][stage]);
}

public void SQL_OnFinishStage_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	if(results == null)
	{
		LogError("Insert Stage PR error! Reason: %s", error);
		delete dp;

		return;
	}

	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	bool wrcp = (dp.ReadCell() == 1);

	delete dp;

	if(client != 0)
	{
		DB_ReloadStageInfo(client);
	}

	if(wrcp)
	{
		DB_ReloadWRStages();
	}
	else
	{
		DB_UpdateStageLeaderboards();
	}
}

public void SQL_OnStageIncrementCompletions_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (Stage OnIncrementCompletions) SQL query failed. Reason: %s", error);

		return;
	}
}