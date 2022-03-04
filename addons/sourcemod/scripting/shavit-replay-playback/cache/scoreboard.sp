void FormatStyle(int bot, const char[] source, int style, int track, char dest[MAX_NAME_LENGTH], bool idle, frame_cache_t aCache, int type, int stage = 0)
{
	char sTime[16];
	char sName[MAX_NAME_LENGTH];

	char temp[128];
	strcopy(temp, sizeof(temp), source);

	ReplaceString(temp, sizeof(temp), "{map}", gS_Map);

	if(idle)
	{
		FormatSeconds(0.0, sTime, 16);
		sName = "you should never see this";
		ReplaceString(temp, sizeof(temp), "{style} ", "");
		ReplaceString(temp, sizeof(temp), "{styletag} ", "");
	}
	else
	{
		FormatSeconds(GetReplayLength(style, track, aCache), sTime, 16);
		GetReplayName(style, track, sName, sizeof(sName), stage);
		if(style == 0)
		{
			ReplaceString(temp, sizeof(temp), "{style} ", "");
			ReplaceString(temp, sizeof(temp), "{styletag} ", "");
		}
		else
		{
			ReplaceString(temp, sizeof(temp), "{style}", gS_StyleStrings[style].sStyleName);
			ReplaceString(temp, sizeof(temp), "{styletag}", gS_StyleStrings[style].sClanTag);
		}
	}

	char sType[32];
	if (type == Replay_Central)
	{
		FormatEx(sType, sizeof(sType), "%T", "Replay_Central", 0);
	}
	else if (type == Replay_Dynamic)
	{
		FormatEx(sType, sizeof(sType), "%T", "Replay_Dynamic", 0);
	}
	else if (type == Replay_Looping)
	{
		if(bot == gI_TrackBot)
		{
			FormatEx(sType, sizeof(sType), "%T", "Replay_Track_Looping", 0);
		}
		else if(bot == gI_StageBot)
		{
			FormatEx(sType, sizeof(sType), "%T", "Replay_Stage_Looping", 0);
		}
	}

	ReplaceString(temp, sizeof(temp), "{type}", sType);
	ReplaceString(temp, sizeof(temp), "{time}", sTime);
	ReplaceString(temp, sizeof(temp), "{player}", sName);

	char sTrack[32];
	GetTrackName(LANG_SERVER, track, sTrack, 32);

	char sStage[32];
	FormatEx(sStage, 32, "WRCP #%d", stage);

	if(track == 0)
	{
		if(stage == 0)
		{
			ReplaceString(temp, sizeof(temp), "{track} ", "WR ");
			ReplaceString(temp, sizeof(temp), "{stage} ", "");
		}
		else
		{
			ReplaceString(temp, sizeof(temp), "{track} ", "");
			ReplaceString(temp, sizeof(temp), "{stage}", sStage);
		}
	}
	else
	{
		ReplaceString(sTrack, sizeof(sTrack), "Bonus ", "WRB #");
		ReplaceString(temp, sizeof(temp), "{track}", sTrack);
		ReplaceString(temp, sizeof(temp), "{stage} ", "");
	}

	strcopy(dest, MAX_NAME_LENGTH, temp);
}

void FillBotName(bot_info_t info, char sName[MAX_NAME_LENGTH])
{
	bool central = (info.iType == Replay_Central);
	bool idle = (info.iStatus == Replay_Idle);

	if (central || info.aCache.iFrameCount > 0)
	{
		FormatStyle(info.iEnt, idle ? gS_ReplayStrings.sCentralName : gS_ReplayStrings.sNameStyle, info.iStyle, info.iTrack, sName, idle, info.aCache, info.iType, info.iStage);
	}
	else
	{
		FormatStyle(info.iEnt, gS_ReplayStrings.sUnloaded, info.iStyle, info.iTrack, sName, idle, info.aCache, info.iType, info.iStage);
	}
}

void UpdateBotScoreboard(bot_info_t info)
{
	int client = info.iEnt;
	if(!IsValidClient(client))
	{
		return;
	}

	bool central = (info.iType == Replay_Central);
	bool idle = (info.iStatus == Replay_Idle);

	char sTag[MAX_NAME_LENGTH];
	FormatStyle(info.iEnt, gS_ReplayStrings.sClanTag, info.iStyle, info.iTrack, sTag, idle, info.aCache, info.iType, info.iStage);
	CS_SetClientClanTag(client, sTag);

	int sv_duplicate_playernames_ok_original;
	if (sv_duplicate_playernames_ok != null)
	{
		sv_duplicate_playernames_ok_original = sv_duplicate_playernames_ok.IntValue;
		sv_duplicate_playernames_ok.IntValue = 1;
	}

	char sName[MAX_NAME_LENGTH];
	FillBotName(info, sName);

	gB_HideNameChange = true;
	SetClientName(client, sName);

	if (sv_duplicate_playernames_ok != null)
	{
		sv_duplicate_playernames_ok.IntValue = sv_duplicate_playernames_ok_original;
	}

	int iScore = (info.aCache.iFrameCount > 0 || central) ? 1337 : -1337;

	CS_SetClientContributionScore(client, iScore);

	SetEntProp(client, Prop_Data, "m_iDeaths", 0);
}