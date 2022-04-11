// ======[ EVENTS ]======

public Action Timer_Scoreboard(Handle timer)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || IsFakeClient(i))
		{
			continue;
		}

		if(gCV_Scoreboard.BoolValue)
		{
			UpdateScoreboard(i);
		}

		UpdateClanTag(i);
	}

	return Plugin_Continue;
}

void OnPlayerSpawn_UpdateScoreBoard(int client)
{
	if(gCV_Scoreboard.BoolValue)
	{
		UpdateScoreboard(client);
	}

	UpdateClanTag(client);
}

void Shavit_OnFinish_UpdateScoreboard(int client)
{
	if(!gCV_Scoreboard.BoolValue)
	{
		return;
	}

	UpdateScoreboard(client);
	UpdateClanTag(client);
}



// ======[ PRIVATE ]======

static void UpdateScoreboard(int client)
{
	float fPB = Shavit_GetClientPB(client, 0, Track_Main);

	int iScore = (fPB != 0.0 && fPB < 2000)? -RoundToFloor(fPB):-2000;

	SetEntProp(client, Prop_Data, "m_iFrags", iScore);

	if(gB_Rankings)
	{
		SetEntProp(client, Prop_Data, "m_iDeaths", Shavit_GetRank(client));
	}
}

static void UpdateClanTag(int client)
{
	char sCustomTag[32];
	gCV_ClanTag.GetString(sCustomTag, 32);

	if(StrEqual(sCustomTag, "0"))
	{
		return;
	}

	char sTime[16];

	float fTime = Shavit_GetClientTime(client);

	if(Shavit_GetTimerStatus(client) == Timer_Stopped || fTime < 1.0)
	{
		strcopy(sTime, 16, "N/A");
	}
	else
	{
		FormatSeconds(fTime, sTime, sizeof(sTime), false, true);
	}

	int track = Shavit_GetClientTrack(client);
	char sTrack[4];

	if(track != Track_Main)
	{
		sTrack[0] = 'B';
		if (track > Track_Bonus)
		{
			sTrack[1] = '0' + track;
		}
	}

	char sRank[8];

	if(gB_Rankings)
	{
		IntToString(Shavit_GetRank(client), sRank, 8);
	}

	ReplaceString(sCustomTag, 32, "{style}", gS_StyleStrings[Shavit_GetBhopStyle(client)].sStyleName);
	ReplaceString(sCustomTag, 32, "{styletag}", gS_StyleStrings[Shavit_GetBhopStyle(client)].sClanTag);
	ReplaceString(sCustomTag, 32, "{time}", sTime);
	ReplaceString(sCustomTag, 32, "{tr}", sTrack);
	ReplaceString(sCustomTag, 32, "{rank}", sRank);

	if(gB_Chat)
	{
		char sChatrank[32];
		Shavit_GetPlainChatrank(client, sChatrank, sizeof(sChatrank), false);
		ReplaceString(sCustomTag, 32, "{cr}", sChatrank);
	}

	Action result = Plugin_Continue;
	Call_OnClanTagChangePre(client, sCustomTag, 32, result);

	if(result != Plugin_Continue && result != Plugin_Changed)
	{
		return;
	}

	CS_SetClientClanTag(client, sCustomTag);

	Call_OnClanTagChangePost(client, sCustomTag, 32);
}