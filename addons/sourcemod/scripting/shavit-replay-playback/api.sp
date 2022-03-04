static GlobalForward H_OnReplayStart = null;
static GlobalForward H_OnReplayEnd = null;
static GlobalForward H_OnReplaysLoaded = null;



// ======[ NATIVES ]======

void CreateNatives()
{
	CreateNative("Shavit_DeleteReplay", Native_DeleteReplay);
	CreateNative("Shavit_GetReplayBotCurrentFrame", Native_GetReplayBotCurrentFrame);
	CreateNative("Shavit_GetReplayBotFirstFrameTime", Native_GetReplayBotFirstFrameTime);
	CreateNative("Shavit_GetReplayBotIndex", Native_GetReplayBotIndex);
	CreateNative("Shavit_GetReplayBotStage", Native_GetReplayBotStage);
	CreateNative("Shavit_GetReplayBotStyle", Native_GetReplayBotStyle);
	CreateNative("Shavit_GetReplayBotTrack", Native_GetReplayBotTrack);
	CreateNative("Shavit_GetReplayBotType", Native_GetReplayBotType);
	CreateNative("Shavit_GetReplayStarter", Native_GetReplayStarter);
	CreateNative("Shavit_GetReplayButtons", Native_GetReplayButtons);
	CreateNative("Shavit_GetReplayFrames", Native_GetReplayFrames);
	CreateNative("Shavit_GetReplayFrameCount", Native_GetReplayFrameCount);
	CreateNative("Shavit_GetReplayPreFrames", Native_GetReplayPreFrames);
	CreateNative("Shavit_GetReplayPostFrames", Native_GetReplayPostFrames);
	CreateNative("Shavit_GetReplayCacheFrameCount", Native_GetReplayCacheFrameCount);
	CreateNative("Shavit_GetReplayCachePreFrames", Native_GetReplayCachePreFrames);
	CreateNative("Shavit_GetReplayCachePostFrames", Native_GetReplayCachePostFrames);
	CreateNative("Shavit_GetReplayLength", Native_GetReplayLength);
	CreateNative("Shavit_GetReplayCacheLength", Native_GetReplayCacheLength);
	CreateNative("Shavit_GetReplayName", Native_GetReplayName);
	CreateNative("Shavit_GetReplayCacheName", Native_GetReplayCacheName);
	CreateNative("Shavit_GetReplayStatus", Native_GetReplayStatus);
	CreateNative("Shavit_GetReplayTime", Native_GetReplayTime);
	CreateNative("Shavit_IsReplayDataLoaded", Native_IsReplayDataLoaded);
	CreateNative("Shavit_IsReplayEntity", Native_IsReplayEntity);
	CreateNative("Shavit_StartReplay", Native_StartReplay);
	CreateNative("Shavit_ReloadReplay", Native_ReloadReplay);
	CreateNative("Shavit_ReloadReplays", Native_ReloadReplays);
	CreateNative("Shavit_Replay_DeleteMap", Native_Replay_DeleteMap);
	CreateNative("Shavit_GetClosestReplayTime", Native_GetClosestReplayTime);
	CreateNative("Shavit_GetClosestReplayStyle", Native_GetClosestReplayStyle);
	CreateNative("Shavit_SetClosestReplayStyle", Native_SetClosestReplayStyle);
	CreateNative("Shavit_GetClosestReplayVelocityDifference", Native_GetClosestReplayVelocityDifference);
	CreateNative("Shavit_StartReplayFromFrameCache", Native_StartReplayFromFrameCache);
	CreateNative("Shavit_StartReplayFromFile", Native_StartReplayFromFile);
	CreateNative("Shavit_SetReplayCacheName", Native_SetReplayCacheName);
}

public int Native_DeleteReplay(Handle handler, int numParams)
{
	char sMap[PLATFORM_MAX_PATH];
	GetNativeString(1, sMap, sizeof(sMap));

	int iStyle = GetNativeCell(2);
	int iTrack = GetNativeCell(3);
	int iSteamID = GetNativeCell(4);

	return DeleteReplay(iStyle, iTrack, iSteamID, sMap);
}

public int Native_GetReplayBotCurrentFrame(Handle handler, int numParams)
{
	return gA_BotInfo[GetNativeCell(1)].iTick;
}

public int Native_GetReplayBotFirstFrameTime(Handle handler, int numParams)
{
	return view_as<int>(gA_BotInfo[GetNativeCell(1)].fFirstFrameTime);
}

public int Native_GetReplayBotIndex(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int track = -1;

	if (numParams > 1)
	{
		track = GetNativeCell(2);
	}

	if (track == -1 && style == -1 && gI_CentralBot > 0)
	{
		return gI_CentralBot;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (gA_BotInfo[i].iEnt > 0)
		{
			if ((track == -1 || gA_BotInfo[i].iTrack == track) && (style == -1 || gA_BotInfo[i].iStyle == style))
			{
				return gA_BotInfo[i].iEnt;
			}
		}
	}

	return -1;
}

public int Native_GetReplayBotStage(Handle handler, int numParams)
{
	return gA_BotInfo[GetNativeCell(1)].iStage;
}

public int Native_GetReplayBotStyle(Handle handler, int numParams)
{
	return gA_BotInfo[GetNativeCell(1)].iStyle;
}

public int Native_GetReplayBotTrack(Handle handler, int numParams)
{
	return gA_BotInfo[GetNativeCell(1)].iTrack;
}

public int Native_GetReplayBotType(Handle handler, int numParams)
{
	return gA_BotInfo[GetNativeCell(1)].iType;
}

public int Native_GetReplayStarter(Handle handler, int numParams)
{
	int starter = gA_BotInfo[GetNativeCell(1)].iStarterSerial;
	return (starter > 0) ? GetClientFromSerial(starter) : 0;
}

public int Native_GetReplayButtons(Handle handler, int numParams)
{
	int bot = GetNativeCell(1);

	if (gA_BotInfo[bot].iStatus != Replay_Running)
	{
		return 0;
	}

	frame_t aFrame;
	gA_BotInfo[bot].aCache.aFrames.GetArray(gA_BotInfo[bot].iTick ? gA_BotInfo[bot].iTick-1 : 0, aFrame, 6);
	float prevAngle = aFrame.ang[1];
	gA_BotInfo[bot].aCache.aFrames.GetArray(gA_BotInfo[bot].iTick, aFrame, 6);

	SetNativeCellRef(2, GetAngleDiff(aFrame.ang[1], prevAngle));
	return aFrame.buttons;
}

public int Native_GetReplayFrames(Handle plugin, int numParams)
{
	int style = GetNativeCell(1);
	int track = GetNativeCell(2);
	bool cheapCloneHandle = (numParams > 2) && view_as<bool>(GetNativeCell(3));
	Handle cloned = null;

	if(gA_FrameCache[style][track].aFrames != null)
	{
		ArrayList frames = cheapCloneHandle ? gA_FrameCache[style][track].aFrames : gA_FrameCache[style][track].aFrames.Clone();
		cloned = CloneHandle(frames, plugin); // set the calling plugin as the handle owner

		if (!cheapCloneHandle)
		{
			// Only hit for .Clone()'d handles. .Clone() != CloneHandle()
			CloseHandle(frames);
		}
	}

	return view_as<int>(cloned);
}

public int Native_GetReplayFrameCount(Handle handler, int numParams)
{
	return gA_FrameCache[GetNativeCell(1)][GetNativeCell(2)].iFrameCount;
}

public int Native_GetReplayPreFrames(Handle plugin, int numParams)
{
	return gA_FrameCache[GetNativeCell(1)][GetNativeCell(2)].iPreFrames;
}

public int Native_GetReplayPostFrames(Handle plugin, int numParams)
{
	return gA_FrameCache[GetNativeCell(1)][GetNativeCell(2)].iPostFrames;
}

public int Native_GetReplayCacheFrameCount(Handle handler, int numParams)
{
	return gA_BotInfo[GetNativeCell(1)].aCache.iFrameCount;
}

public int Native_GetReplayCachePreFrames(Handle plugin, int numParams)
{
	return gA_BotInfo[GetNativeCell(1)].aCache.iPreFrames;
}

public int Native_GetReplayCachePostFrames(Handle plugin, int numParams)
{
	return gA_BotInfo[GetNativeCell(1)].aCache.iPostFrames;
}

public int Native_GetReplayLength(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int track = GetNativeCell(2);
	int stage = GetNativeCell(3);
	return view_as<int>(GetReplayLength(style, track, (stage==0)?gA_FrameCache[style][track]:gA_FrameCache_Stage[style][stage], stage));
}

public int Native_GetReplayCacheLength(Handle handler, int numParams)
{
	int bot = GetNativeCell(1);
	return view_as<int>(GetReplayLength(gA_BotInfo[bot].iStyle,  gA_BotInfo[bot].iTrack, gA_BotInfo[bot].aCache));
}

public int Native_GetReplayName(Handle handler, int numParams)
{
	return SetNativeString(3, (GetNativeCell(5) == 0)?gA_FrameCache[GetNativeCell(1)][GetNativeCell(2)].sReplayName:gA_FrameCache_Stage[GetNativeCell(1)][GetNativeCell(5)].sReplayName, GetNativeCell(4));
}

public int Native_GetReplayCacheName(Handle plugin, int numParams)
{
	return SetNativeString(2, gA_BotInfo[GetNativeCell(1)].aCache.sReplayName, GetNativeCell(3));
}

public int Native_GetReplayStatus(Handle handler, int numParams)
{
	return gA_BotInfo[GetNativeCell(1)].iStatus;
}

public any Native_GetReplayTime(Handle handler, int numParams)
{
	int index = GetNativeCell(1);

	if (gA_BotInfo[index].iTick > (gA_BotInfo[index].aCache.iFrameCount + gA_BotInfo[index].aCache.iPreFrames))
	{
		return gA_BotInfo[index].aCache.fTime;
	}

	if(gA_BotInfo[index].iStage != 0)
	{
		int preframes = RoundToFloor(FindConVar("shavit_stage_replay_preruntime").FloatValue * gF_Tickrate);

		if (gA_BotInfo[index].iTick > (gA_BotInfo[index].aCache.iFrameCount - preframes))
		{
			return gA_BotInfo[index].aCache.fTime;
		}

		return float(gA_BotInfo[index].iTick - preframes) / gF_Tickrate * Shavit_GetStyleSettingFloat(gA_BotInfo[index].iStyle, "timescale");
	}

	if(gA_BotInfo[index].iTrack != 0)
	{
		return float(gA_BotInfo[index].iTick - gA_BotInfo[index].aCache.iPreFrames) / gF_Tickrate * Shavit_GetStyleSettingFloat(gA_BotInfo[index].iStyle, "timescale");
	}
	else
	{
		return float(gA_BotInfo[index].iRealTick - gA_BotInfo[index].aCache.iPreFrames) / gF_Tickrate * Shavit_GetStyleSettingFloat(gA_BotInfo[index].iStyle, "timescale") + gA_BotInfo[index].fRealTime;
	}
}

public int Native_IsReplayDataLoaded(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int track = GetNativeCell(2);
	int stage = GetNativeCell(3);
	return view_as<int>(ReplayEnabled(style) && (stage == 0)?gA_FrameCache[style][track].iFrameCount > 0:gA_FrameCache_Stage[style][stage].iFrameCount > 0);
}

public int Native_IsReplayEntity(Handle handler, int numParams)
{
	int ent = GetNativeCell(1);
	return (gA_BotInfo[ent].iEnt == ent);
}

public int Native_StartReplay(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int track = GetNativeCell(2);
	float delay = GetNativeCell(3);
	int client = GetNativeCell(4);
	int bot = GetNativeCell(5);
	int type = GetNativeCell(6);
	bool ignorelimit = view_as<bool>(GetNativeCell(7));

	frame_cache_t cache; // null cache
	return CreateReplayEntity(track, style, delay, client, bot, type, ignorelimit, cache, 0);
}

public int Native_ReloadReplay(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int track = GetNativeCell(2);
	bool restart = view_as<bool>(GetNativeCell(3));

	char path[PLATFORM_MAX_PATH];
	GetNativeString(4, path, PLATFORM_MAX_PATH);

	return UnloadReplay(style, track, true, restart, path);
}

public int Native_ReloadReplays(Handle handler, int numParams)
{
	bool restart = view_as<bool>(GetNativeCell(1));
	int loaded = 0;

	for(int i = 0; i < gI_Styles; i++)
	{
		if(!ReplayEnabled(i))
		{
			continue;
		}

		for(int j = 0; j < TRACKS_SIZE; j++)
		{
			if(UnloadReplay(i, j, true, restart, ""))
			{
				loaded++;
			}
		}
	}

	return loaded;
}

public int Native_Replay_DeleteMap(Handle handler, int numParams)
{
	char sMap[PLATFORM_MAX_PATH];
	GetNativeString(1, sMap, sizeof(sMap));
	LowercaseString(sMap);

	DeleteAllReplays(sMap);

	if(StrEqual(gS_Map, sMap, false))
	{
		OnMapStart();
	}

	return 0;
}

public int Native_GetClosestReplayTime(Handle plugin, int numParams)
{
	if (!gCV_EnableDynamicTimeDifference.BoolValue)
	{
		return view_as<int>(-1.0);
	}

	int client = GetNativeCell(1);
	return view_as<int>(gF_TimeDifference[client]);
}

public int Native_GetClosestReplayStyle(Handle plugin, int numParams)
{
	return gI_TimeDifferenceStyle[GetNativeCell(1)];
}

public int Native_SetClosestReplayStyle(Handle plugin, int numParams)
{
	gI_TimeDifferenceStyle[GetNativeCell(1)] = GetNativeCell(2);

	return 0;
}

public int Native_GetClosestReplayVelocityDifference(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (view_as<bool>(GetNativeCell(2)))
	{
		return view_as<int>(gF_VelocityDifference3D[client]);
	}
	else
	{
		return view_as<int>(gF_VelocityDifference2D[client]);
	}
}

public int Native_StartReplayFromFrameCache(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int track = GetNativeCell(2);
	float delay = GetNativeCell(3);
	int client = GetNativeCell(4);
	int bot = GetNativeCell(5);
	int type = GetNativeCell(6);
	bool ignorelimit = view_as<bool>(GetNativeCell(7));

	if(GetNativeCell(9) != sizeof(frame_cache_t))
	{
		return ThrowNativeError(200, "frame_cache_t does not match latest(got %i expected %i). Please update your includes and recompile your plugins",
			GetNativeCell(9), sizeof(frame_cache_t));
	}

	frame_cache_t cache;
	GetNativeArray(8, cache, sizeof(cache));

	return CreateReplayEntity(track, style, delay, client, bot, type, ignorelimit, cache, 0);
}

public int Native_StartReplayFromFile(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int track = GetNativeCell(2);
	float delay = GetNativeCell(3);
	int client = GetNativeCell(4);
	int bot = GetNativeCell(5);
	int type = GetNativeCell(6);
	bool ignorelimit = view_as<bool>(GetNativeCell(7));

	char path[PLATFORM_MAX_PATH];
	GetNativeString(8, path, sizeof(path));

	frame_cache_t cache; // null cache

	if (!LoadReplay(cache, style, track, path, gS_Map))
	{
		return 0;
	}

	return CreateReplayEntity(track, style, delay, client, bot, type, ignorelimit, cache, 0);
}

public int Native_SetReplayCacheName(Handle plugin, int numParams)
{
	char name[MAX_NAME_LENGTH];
	GetNativeString(2, name, sizeof(name));

	int index = GetNativeCell(1);
	gA_BotInfo[index].aCache.sReplayName = name;

	return 0;
}



// ======[ FORWARDS ]======

void CreateGlobalForwards()
{
	H_OnReplayStart = new GlobalForward("Shavit_OnReplayStart", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	H_OnReplayEnd = new GlobalForward("Shavit_OnReplayEnd", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	H_OnReplaysLoaded = new GlobalForward("Shavit_OnReplaysLoaded", ET_Event);
}

void Call_OnReplayStart(int ent, int type, bool delay_elapsed)
{
	Call_StartForward(H_OnReplayStart);
	Call_PushCell(ent);
	Call_PushCell(type);
	Call_PushCell(delay_elapsed);
	Call_Finish();
}

void Call_OnReplayEnd(int ent, int type, bool actually_finished)
{
	Call_StartForward(H_OnReplayEnd);
	Call_PushCell(ent);
	Call_PushCell(type);
	Call_PushCell(actually_finished);
	Call_Finish();
}

void Call_OnReplaysLoaded()
{
	Call_StartForward(H_OnReplaysLoaded);
	Call_Finish();
}