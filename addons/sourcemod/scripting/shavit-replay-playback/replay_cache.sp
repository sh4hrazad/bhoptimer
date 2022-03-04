// ======[ EVENTS ]======

void OnClientPutInServer_ClientCache(int client)
{
	gF_LastInteraction[client] = GetEngineTime() - gCV_PlaybackCooldown.FloatValue;
	gA_BotInfo[client].iEnt = -1;
	ClearBotInfo(gA_BotInfo[client]);
}

void OnClientPutInServer_BotCache(int client)
{
	char sName[MAX_NAME_LENGTH];
	FillBotName(gA_BotInfo_Temp, sName);
	SetClientName(client, sName);
}

void OnClientDisconnect_ClearBotInfo(int client)
{
	if (gA_BotInfo[client].iEnt == client)
	{
		CancelReplay(gA_BotInfo[client], false);

		gA_BotInfo[client].iEnt = -1;
	}

	if (gI_CentralBot == client)
	{
		gI_CentralBot = -1;
	}
	else if (gI_TrackBot == client)
	{
		gI_TrackBot = -1;
	}
	else if (gI_StageBot == client)
	{
		gI_StageBot = -1;
	}
}

void BotEvents_Player_Connect(Event event)
{
	char sName[MAX_NAME_LENGTH];
	FillBotName(gA_BotInfo_Temp, sName);
	event.SetString("name", sName);
}

bool Shavit_OnReplaySaved_CanBeCached(int style, float time, int track, bool isbestreplay, bool istoolong, ArrayList frames, int preframes, int postframes, const char[] name)
{
	if (!isbestreplay || istoolong)
	{
		return false;
	}

	delete gA_FrameCache[style][track].aFrames;
	gA_FrameCache[style][track].aFrames = view_as<ArrayList>(CloneHandle(frames));
	gA_FrameCache[style][track].iFrameCount = frames.Length - preframes - postframes;
	gA_FrameCache[style][track].fTime = time;
	gA_FrameCache[style][track].iReplayVersion = REPLAY_FORMAT_SUBVERSION;
	gA_FrameCache[style][track].bNewFormat = true;
	strcopy(gA_FrameCache[style][track].sReplayName, sizeof(frame_cache_t::sReplayName), name);
	gA_FrameCache[style][track].iPreFrames = preframes;
	gA_FrameCache[style][track].iPostFrames = postframes;
	gA_FrameCache[style][track].fTickrate = gF_Tickrate;

	return true;
}

bool Shavit_OnStageReplaySaved_CanBeCached(int stage, int style, float time, ArrayList frames, int preframes, int size, const char[] name)
{
	if(frames == null || frames.Length <= 10)
	{
		return false;
	}

	if(gA_FrameCache_Stage[style][stage].aFrames != null)
	{
		delete gA_FrameCache_Stage[style][stage].aFrames;
	}

	gA_FrameCache_Stage[style][stage].aFrames = view_as<ArrayList>(CloneHandle(frames));
	gA_FrameCache_Stage[style][stage].iFrameCount = size;
	gA_FrameCache_Stage[style][stage].fTime = time;
	gA_FrameCache_Stage[style][stage].iReplayVersion = REPLAY_FORMAT_SUBVERSION;
	gA_FrameCache_Stage[style][stage].bNewFormat = true;
	strcopy(gA_FrameCache_Stage[style][stage].sReplayName, sizeof(frame_cache_t::sReplayName), name);
	gA_FrameCache_Stage[style][stage].iPreFrames = preframes;
	gA_FrameCache_Stage[style][stage].iPostFrames = 0;
	gA_FrameCache_Stage[style][stage].fTickrate = gF_Tickrate;

	return true;
}



// ======[ PUBLIC ]=====
void ClearFrameCache(frame_cache_t cache)
{
	delete cache.aFrames;
	cache.iFrameCount = 0;
	cache.fTime = 0.0;
	cache.bNewFormat = true;
	cache.iReplayVersion = 0;
	cache.sReplayName = "unknown";
	cache.iPreFrames = 0;
	cache.iPostFrames = 0;
	cache.fTickrate = 0.0;
}

void ClearBotInfo(bot_info_t info)
{
	//info.iEnt
	info.iStyle = -1;
	info.iStatus = Replay_Idle;
	//info.iType
	info.iTrack = -1;
	info.iStarterSerial = -1;
	info.iTick = -1;
	info.iRealTick = -1;
	info.fRealTime = 0.0;

	delete info.hTimer;
	info.fFirstFrameTime = -1.0;
	info.bCustomFrames = false;
	//info.bIgnoreLimit
	info.b2x = false;
	info.fDelay = 0.0;
	info.iStage = 0;

	ClearFrameCache(info.aCache);
}

void SetupIfCustomFrames(bot_info_t info, frame_cache_t cache)
{
	info.bCustomFrames = false;

	if (cache.aFrames != null)
	{
		info.bCustomFrames = true;
		info.aCache = cache;
		info.aCache.aFrames = view_as<ArrayList>(CloneHandle(info.aCache.aFrames));
	}
}

bool FindNextLoop(bot_info_t info)
{
	if(info.iEnt == gI_TrackBot)
	{
		for(int i = 0; i < TRACKS_SIZE; i++)// check if have frames first
		{
			if(gA_FrameCache[0][i].iFrameCount > 0)
			{
				break;
			}

			if(i == TRACKS_SIZE - 1)
			{
				return false;
			}
		}

		for(int i = info.iTrack; i < TRACKS_SIZE; i++)
		{
			if(i == TRACKS_SIZE - 1)
			{
				i = -1;
			}

			if(gA_FrameCache[0][i + 1].iFrameCount > 0)
			{
				info.iTrack = i + 1;
				info.iStage = 0;
				return true;
			}
		}
	}
	else if(info.iEnt == gI_StageBot)
	{
		for(int i = 1; i <= Shavit_GetMapStages(); i++)// check if have frames first
		{
			if(gA_FrameCache_Stage[0][i].iFrameCount > 0)
			{
				break;
			}

			if(i == Shavit_GetMapStages())
			{
				return false;
			}
		}

		for(int i = info.iStage; i <= Shavit_GetMapStages(); i++)
		{
			if(i == Shavit_GetMapStages())
			{
				i = 0;
			}

			if(gA_FrameCache_Stage[0][i + 1].iFrameCount > 0)
			{
				info.iTrack = 0;
				info.iStage = i + 1;
				return true;
			}
		}
	}

	return false;
}

float GetReplayLength(int style, int track, frame_cache_t aCache, int stage = 0)
{
	if(aCache.iFrameCount <= 0)
	{
		return 0.0;
	}

	if(aCache.bNewFormat)
	{
		return aCache.fTime;
	}

	if(stage == 0)
	{
		return Shavit_GetWorldRecord(style, track) * Shavit_GetStyleSettingFloat(style, "speed");
	}
	else
	{
		return Shavit_GetWRStageTime(stage, style) * Shavit_GetStyleSettingFloat(style, "speed");
	}
}

void GetReplayName(int style, int track, char[] buffer, int length, int stage = 0)
{
	if(stage == 0)
	{
		if(gA_FrameCache[style][track].bNewFormat)
		{
			strcopy(buffer, length, gA_FrameCache[style][track].sReplayName);

			return;
		}

		Shavit_GetWRName(style, buffer, length, track);
	}
	else
	{
		if(gA_FrameCache_Stage[style][stage].bNewFormat)
		{
			strcopy(buffer, length, gA_FrameCache_Stage[style][stage].sReplayName);

			return;
		}

		if(gA_FrameCache_Stage[style][stage].iFrameCount <= 0)
		{
			strcopy(buffer, length, "N/A");
			return;
		}

		Shavit_GetWRStageName(style, stage, buffer, length);
	}
}