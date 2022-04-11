void FinishReplay(bot_info_t info)
{
	Call_OnReplayEnd(info.iEnt, info.iType, true);

	int starter = GetClientFromSerial(info.iStarterSerial);

	if (info.iType == Replay_Dynamic)
	{
		KickReplay(info);
	}
	else if (info.iType == Replay_Looping)
	{
		bool hasFrames = FindNextLoop(info);

		if (hasFrames)
		{
			int nexttrack = info.iTrack;
			int nextstage = info.iStage;
			ClearBotInfo(info);
			StartReplay(info, nexttrack, 0, 0, gCV_ReplayDelay.FloatValue, nextstage);
		}
		else
		{
			info.iStatus = Replay_Idle;
			UpdateBotScoreboard(info);
		}
	}
	else if (info.iType == Replay_Central)
	{
		if (info.aCache.aFrames != null)
		{
			TeleportToFrame(info, 0);
		}

		ClearBotInfo(info);
	}

	if (starter > 0)
	{
		gF_LastInteraction[starter] = GetEngineTime();
		gA_BotInfo[starter].iEnt = -1;

		if (gB_InReplayMenu[starter])
		{
			OpenReplayMenu(starter); // Refresh menu so Spawn Replay option shows up again...
		}
	}
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
	//info.iLoopingConfig
	delete info.hTimer;
	info.fFirstFrameTime = -1.0;
	info.bCustomFrames = false;
	//info.bIgnoreLimit
	info.b2x = false;
	info.fDelay = 0.0;
	info.iStage = 0;

	ClearFrameCache(info.aCache);
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

void CancelReplay(bot_info_t info, bool update = true)
{
	int starter = GetClientFromSerial(info.iStarterSerial);

	if(starter != 0)
	{
		gF_LastInteraction[starter] = GetEngineTime();
		gA_BotInfo[starter].iEnt = -1;
	}

	if (update)
	{
		TeleportToFrame(info, 0);
	}

	ClearBotInfo(info);

	if (update && 1 <= info.iEnt <= MaxClients)
	{
		RequestFrame(Frame_UpdateReplayClient, GetClientSerial(info.iEnt));
	}
}

void StopOrRestartBots(int style, int track, bool restart)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (gA_BotInfo[i].iEnt <= 0 || gA_BotInfo[i].iTrack != track || gA_BotInfo[i].iStyle != style || gA_BotInfo[i].bCustomFrames)
		{
			continue;
		}

		CancelReplay(gA_BotInfo[i], false);

		if (restart)
		{
			StartReplay(gA_BotInfo[i], track, style, GetClientFromSerial(gA_BotInfo[i].iStarterSerial), gCV_ReplayDelay.FloatValue);
		}
		else
		{
			FinishReplay(gA_BotInfo[i]);
		}
	}
}

bool UnloadReplay(int style, int track, bool reload, bool restart, const char[] path = "")
{
	ClearFrameCache(gA_FrameCache[style][track]);
	delete gH_ClosestPos[track][style];

	bool loaded = false;

	if (reload)
	{
		if(strlen(path) > 0)
		{
			loaded = LoadReplay(gA_FrameCache[style][track], style, track, path, gS_Map);
		}
		else
		{
			loaded = DefaultLoadReplay(gA_FrameCache[style][track], style, track);
		}
	}

	StopOrRestartBots(style, track, restart);

	return loaded;
}