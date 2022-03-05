/*
	Processing Shavit_OnFinish for wr.
*/



void DB_OnFinish(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldtime, float avgvel, float maxvel, int timestamp)
{
	// do not risk overwriting the player's data if their PB isn't loaded to cache yet
	if (!gB_LoadedCache[client])
	{
		return;
	}

	// client pb
	oldtime = gF_PlayerRecord[client][style][track];

	int iSteamID = GetSteamAccountID(client);
	float fPrestrafe = gF_CurrentPrestrafe[client];

	char sTime[32];
	FormatHUDSeconds(time, sTime, sizeof(sTime));

	char sTrack[32];
	GetTrackName(client, track, sTrack, 32);

	// 0 - no query
	// 1 - insert
	// 2 - update
	bool bIncrementCompletions = true;
	int iOverwrite = 0;

	if(Shavit_GetStyleSettingInt(style, "unranked") || Shavit_IsPracticeMode(client))
	{
		iOverwrite = 0; // ugly way of not writing to database
		bIncrementCompletions = false;
	}

	else if(gF_PlayerRecord[client][style][track] == 0.0)
	{
		iOverwrite = 1;
	}

	else if(time < gF_PlayerRecord[client][style][track])
	{
		iOverwrite = 2;
	}

	bool bEveryone = true;
	char sMessage[255];
	char sMessage2[255];

	if(iOverwrite > 0 && (time < gF_WRTime[style][track] || gF_WRTime[style][track] == 0.0)) // WR?
	{
		float fOldWR = gF_WRTime[style][track];
		gF_WRTime[style][track] = time;
		gI_WRSteamID[style][track] = iSteamID;

		Call_OnWorldRecord(client, style, time, jumps, strafes, sync, track, fOldWR, oldtime, avgvel, maxvel, timestamp);
	}

	int iRank = GetRankForTime(style, time, track);
	int iRecords = GetRecordAmount(style, track);

	if(iRank >= iRecords)
	{
		Call_OnWorstRecord(client, style, time, jumps, strafes, sync, track, oldtime, avgvel, maxvel, timestamp);
	}

	float fDifference = (gF_PlayerRecord[client][style][track] - time);

	if(fDifference < 0.0)
	{
		fDifference = -fDifference;
	}

	char sDifference[32];
	FormatHUDSeconds(fDifference, sDifference, sizeof(sDifference));

	char sSync[32]; // 32 because colors
	FormatEx(sSync, 32, (sync != -1.0)? " @ {gold}%.02f%%":"", sync);

	if(iOverwrite > 0)
	{
		float fPoints = gB_Rankings ? Shavit_GuessPointsForTime(track, style, -1, time, gF_WRTime[style][track]) : 0.0;

		char sQuery[1024];

		if(iOverwrite == 1) // insert
		{
			if(style == 0)
			{
				FormatEx(sMessage, 255, "%t", "FirstCompletion-Normal", client, sTrack, sTime, iRank, iRecords + 1);
			}
			else
			{
				FormatEx(sMessage, 255, "%t", "FirstCompletion-Other", client, sTrack, sTime, gS_StyleStrings[style].sStyleName, iRank, iRecords + 1);
			}

			FormatEx(sQuery, sizeof(sQuery), mysql_onfinish_insert_new, 
				iSteamID, gS_Map, time, jumps, timestamp, style, strafes, sync, fPoints, track, view_as<int>(time), fPrestrafe);
		}
		else // update
		{
			if(style == 0)
			{
				FormatEx(sMessage, 255, "%t", "NotFirstCompletion-Normal", client, sTrack, sTime, iRank, iRecords, sDifference);
			}
			else
			{
				FormatEx(sMessage, 255, "%t", "NotFirstCompletion-Other", client, sTrack, sTime, gS_StyleStrings[style].sStyleName, iRank, iRecords, sDifference);
			}

			FormatEx(sQuery, sizeof(sQuery), mysql_onfinish_update, 
				time, jumps, timestamp, strafes, sync, fPoints, view_as<int>(time), fPrestrafe, gS_Map, iSteamID, style, track);
		}

		gH_SQL.Query(SQL_OnFinish_Callback, sQuery, GetClientSerial(client), DBPrio_High);
	}

	Call_OnFinish_Post(client, style, time, jumps, strafes, sync, iRank, iOverwrite, track, oldtime, avgvel, maxvel, timestamp);

	if(bIncrementCompletions)
	{
		if (iOverwrite == 0)
		{
			char sQuery[512];
			FormatEx(sQuery, sizeof(sQuery), mysql_onfinish_update_completions, 
				gS_Map, iSteamID, style, track);
			gH_SQL.Query(SQL_OnIncrementCompletions_Callback, sQuery, 0, DBPrio_Low);
		}

		gI_PlayerCompletion[client][style][track]++;

		if(iOverwrite == 0 && !Shavit_GetStyleSettingInt(style, "unranked"))
		{
			if(style == 0)
			{
				FormatEx(sMessage, 255, "%t", "WorseTime-Normal", client, sTrack, sTime, sDifference);
			}
			else
			{
				FormatEx(sMessage, 255, "%t", "WorseTime-Other", client, sTrack, sTime, gS_StyleStrings[style].sStyleName, sDifference);
			}
		}
	}
	else
	{
		if(style == 0)
		{
			FormatEx(sMessage, 255, "%t", "UnrankedTime-Normal", client, sTrack, sTime, Shavit_IsPracticeMode(client) ? "[练习模式]" : "[未排名模式]");
		}
		else
		{
			FormatEx(sMessage, 255, "%t", "UnrankedTime-Other", client, sTrack, sTime, gS_StyleStrings[style].sStyleName, Shavit_IsPracticeMode(client) ? "[练习模式]" : "[未排名模式]");
		}
	}

	timer_snapshot_t aSnapshot;
	Shavit_SaveSnapshot(client, aSnapshot);

	Action aResult = Plugin_Continue;
	Call_OnFinishMessage(client, bEveryone, aSnapshot, iOverwrite, iRank, sMessage, sizeof(sMessage), sMessage2, sizeof(sMessage2), aResult);

	if(aResult < Plugin_Handled)
	{
		if(bEveryone)
		{
			Shavit_PrintToChatAll("%s", sMessage);
		}
		else
		{
			SetGlobalTransTarget(client);
			Shavit_PrintToChat(client, "%s", sMessage);

			for(int i = 1; i <= MaxClients; i++)
			{
				if(client != i && IsValidClient(i) && GetSpectatorTarget(i) == client)
				{
					if(style == 0)
					{
						FormatEx(sMessage, sizeof(sMessage), "%T", "NotFirstCompletionWorse-Normal", i, 
							client, sTrack, sTime, iRank, iRecords, sDifference);
					}
					else
					{
						FormatEx(sMessage, sizeof(sMessage), "%T", "NotFirstCompletionWorse-Other", i, 
							client, sTrack, sTime, gS_StyleStrings[style].sStyleName, iRank, iRecords, sDifference);
					}

					Shavit_PrintToChat(i, "%s", sMessage);

					if (sMessage2[0] != 0)
					{
						Shavit_PrintToChat(i, "%s", sMessage2);
					}
				}
			}
		}

		if (sMessage2[0] != 0)
		{
			Shavit_PrintToChat(client, "%s", sMessage2);
		}
	}

	// update pb cache only after sending the message so we can grab the old one inside the Shavit_OnFinishMessage forward
	if(iOverwrite > 0)
	{
		gF_PlayerRecord[client][style][track] = time;
	}
}

public void SQL_OnFinish_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR OnFinish) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	UpdateWRCache(client);
}

public void SQL_OnIncrementCompletions_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR OnIncrementCompletions) SQL query failed. Reason: %s", error);

		return;
	}
}