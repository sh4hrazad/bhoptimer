stock void ClearFrameCache(frame_cache_t cache)
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

stock float GetReplayLength(int style, int track, frame_cache_t aCache, int stage = 0)
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

stock void GetReplayName(int style, int track, char[] buffer, int length, int stage = 0)
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

stock bool CanControlReplay(int client, bot_info_t info)
{
	return CheckCommandAccess(client, "sm_deletereplay", ADMFLAG_RCON)
		|| (gCV_PlaybackCanStop.BoolValue && GetClientSerial(client) == info.iStarterSerial)
	;
}

stock int GetControllableReplay(int client)
{
	int target = GetSpectatorTarget(client);

	if (target != -1)
	{
		if (gA_BotInfo[target].iStatus == Replay_Start || gA_BotInfo[target].iStatus == Replay_Running)
		{
			if (CanControlReplay(client, gA_BotInfo[target]))
			{
				return target;
			}
		}
	}

	return -1;
}

stock bool ReplayEnabled(any style)
{
	return !Shavit_GetStyleSettingBool(style, "unranked") && !Shavit_GetStyleSettingBool(style, "noreplay");
}

stock void Replay_CreateDirectories(const char[] sReplayFolder, int styles)
{
	if (!DirExists(sReplayFolder) && !CreateDirectory(sReplayFolder, 511))
	{
		SetFailState("Failed to create replay folder (%s). Make sure you have file permissions", sReplayFolder);
	}

	char sPath[PLATFORM_MAX_PATH];
	FormatEx(sPath, PLATFORM_MAX_PATH, "%s/copy", sReplayFolder);

	if (!DirExists(sPath) && !CreateDirectory(sPath, 511))
	{
		SetFailState("Failed to create replay copy folder (%s). Make sure you have file permissions", sPath);
	}

	for(int i = 0; i < styles; i++)
	{
		if (!ReplayEnabled(i))
		{
			continue;
		}

		FormatEx(sPath, PLATFORM_MAX_PATH, "%s/%d", sReplayFolder, i);

		if (!DirExists(sPath) && !CreateDirectory(sPath, 511))
		{
			SetFailState("Failed to create replay style folder (%s). Make sure you have file permissions", sPath);
		}
	}

	// Test to see if replay file creation even works...
	FormatEx(sPath, sizeof(sPath), "%s/0/faketestfile_69.replay", sReplayFolder);
	File fTest = OpenFile(sPath, "wb+");
	CloseHandle(fTest);

	if (fTest == null)
	{
		SetFailState("Failed to write to replay folder (%s). Make sure you have file permissions.", sReplayFolder);
	}
}