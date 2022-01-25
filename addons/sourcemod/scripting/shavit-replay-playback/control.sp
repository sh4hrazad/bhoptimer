// ======[ EVENTS ]======

void OnClientDisconnect_ControlReplay(int client)
{
	if (gA_BotInfo[client].iEnt > 0)
	{
		int index = gA_BotInfo[client].iEnt;

		if (gA_BotInfo[index].iType == Replay_Central)
		{
			CancelReplay(gA_BotInfo[index]);
		}
		else
		{
			KickReplay(gA_BotInfo[index]);
		}
	}
}

void PlayerEvent_ControlReplay(int client)
{
	int index = gA_BotInfo[client].iEnt;

	if (gA_BotInfo[index].iType != Replay_Central)
	{
		KickReplay(gA_BotInfo[index]); // kick his replay when the starter activated event.
	}
}

void Shavit_OnStageReplaySaved_StartReplay(int stage, int style)
{
	if(LoadStageReplay(gA_FrameCache_Stage[style][stage], style, stage))
	{
		if(gI_StageBot != -1 && gA_BotInfo[gI_StageBot].iStatus == Replay_Idle)
		{
			StartReplay(gA_BotInfo[gI_StageBot], 0, 0, -1, gCV_ReplayDelay.FloatValue, stage);
		}
	}
}

void Shavit_OnWRDeleted_DeleteReplay(int style, int track, int accountid, const char[] mapname)
{
	DeleteReplay(style, track, accountid, mapname);
}

void Shavit_OnWRCPDeleted_DeleteReplay(int stage, int style, const char[] mapname)
{
	char sPath[PLATFORM_MAX_PATH];
	FormatEx(sPath, PLATFORM_MAX_PATH, "%s/%d/%s_stage_%d.replay", gS_ReplayFolder, style, mapname, stage);
	if(FileExists(sPath))
	{
		DeleteFile(sPath);
		ClearFrameCache(gA_FrameCache_Stage[style][stage]);
		CancelReplay(gA_BotInfo[gI_StageBot], false);
		FinishReplay(gA_BotInfo[gI_StageBot]);
	}
}

void Shavit_OnReplaySaved_StartReplay(int style, int track)
{
	if(gA_BotInfo[gI_TrackBot].iStatus == Replay_Idle)
	{
		StartReplay(gA_BotInfo[gI_TrackBot], track, style, -1, gCV_ReplayDelay.FloatValue);
	}
}



// ======[ PUBLIC ]======
bool CanControlReplay(int client, bot_info_t info)
{
	return CheckCommandAccess(client, "sm_deletereplay", ADMFLAG_RCON) || (gCV_PlaybackCanStop.BoolValue && GetClientSerial(client) == info.iStarterSerial);
}

int GetControllableReplay(int client)
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

void TeleportToFrame(bot_info_t info, int iFrame)
{
	if (info.aCache.aFrames == null)
	{
		return;
	}

	frame_t frame;
	info.aCache.aFrames.GetArray(iFrame, frame, 6);

	float vecAngles[3];
	vecAngles[0] = frame.ang[0];
	vecAngles[1] = frame.ang[1];

	TeleportEntity(info.iEnt, frame.pos, vecAngles, view_as<float>({0.0, 0.0, 0.0}));
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

void KickReplay(bot_info_t info)
{
	if (info.iEnt <= 0)
	{
		return;
	}

	if (info.iType == Replay_Dynamic && !info.bIgnoreLimit)
	{
		--gI_DynamicBots;
	}

	if (1 <= info.iEnt <= MaxClients)
	{
		KickClient(info.iEnt, "you just lost The Game");
	}

	CancelReplay(info, false);

	info.iEnt = -1;
	info.iType = -1;
}

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
	DropClosestPos(style, track);

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

bool DefaultLoadReplay(frame_cache_t cache, int style, int track)
{
	char sPath[PLATFORM_MAX_PATH];
	GetReplayFilePath(style, track, gS_Map, sPath);

	if (!LoadReplay(cache, style, track, sPath, gS_Map))
	{
		return false;
	}

	OnDefaultLoadReplay_ClosestPos(cache, style, track);

	return true;
}

void StartReplay(bot_info_t info, int track, int style, int starter, float delay, int stage = 0)
{
	if (starter > 0)
	{
		gF_LastInteraction[starter] = GetEngineTime();
	}

	//info.iEnt;
	info.iStyle = style;
	info.iStatus = Replay_Start;
	//info.iType
	info.iTrack = track;
	info.iStarterSerial = (starter > 0) ? GetClientSerial(starter) : 0;
	info.iTick = 0;
	info.iRealTick = 0;
	info.fRealTime = 0.0;

	info.fDelay = delay;
	info.hTimer = CreateTimer((delay / 2.0), Timer_StartReplay, info.iEnt, TIMER_FLAG_NO_MAPCHANGE);
	info.iStage = stage;

	if (info.aCache.aFrames == null)
	{
		if(stage == 0)
		{
			info.aCache = gA_FrameCache[style][track];
		}
		else
		{
			info.aCache = gA_FrameCache_Stage[style][stage];
		}

		info.aCache.aFrames = view_as<ArrayList>(CloneHandle(info.aCache.aFrames));
	}

	TeleportToFrame(info, 0);
	UpdateReplayClient(info.iEnt);

	if (starter > 0 && GetClientTeam(starter) != 1)
	{
		ChangeClientTeam(starter, 1);
	}

	if (starter > 0)
	{
		gA_BotInfo[starter].iEnt = info.iEnt;
		// Timer is used because the bot's name is missing and profile pic random if using RequestFrame...
		// I really have no idea. Even delaying by 5 frames wasn't enough. Broken game.
		// Maybe would need to be delayed by the player's latency but whatever...
		// It seems to use early steamids for pfps since I've noticed BAILOPAN's and EricS's avatars...
		CreateTimer(0.2, Timer_SpectateMyBot, GetClientSerial(info.iEnt), TIMER_FLAG_NO_MAPCHANGE);
	}

	Call_OnReplayStart(info.iEnt, info.iType, false);
}

public Action Timer_SpectateMyBot(Handle timer, any data)
{
	SpectateMyBot(data);
	return Plugin_Stop;
}

void SpectateMyBot(int serial)
{
	int bot = GetClientFromSerial(serial);

	if (bot == 0)
	{
		return;
	}

	int starter = GetClientFromSerial(gA_BotInfo[bot].iStarterSerial);

	if (starter == 0)
	{
		return;
	}

	SetEntPropEnt(starter, Prop_Send, "m_hObserverTarget", bot);
}

public Action Timer_StartReplay(Handle Timer, any data)
{
	gA_BotInfo[data].hTimer = null;
	gA_BotInfo[data].iStatus = Replay_Running;

	Call_OnReplayStart(gA_BotInfo[data].iEnt, gA_BotInfo[data].iType, true);

	return Plugin_Stop;
}

public Action Timer_EndReplay(Handle Timer, any data)
{
	gA_BotInfo[data].hTimer = null;

	FinishReplay(gA_BotInfo[data]);

	return Plugin_Stop;
}

int InternalCreateReplayBot()
{
	gI_LatestClient = -1;

	// Do all this mp_randomspawn stuff on CSGO since it's easier than updating the signature for CCSGameRules::TeamFull.
	int mp_randomspawn_orig;
	
	if (mp_randomspawn != null)
	{
		mp_randomspawn_orig = mp_randomspawn.IntValue;
		mp_randomspawn.IntValue = gCV_DefaultTeam.IntValue;
	}

	if (gB_Linux)
	{
		/*int ret =*/ SDKCall(
			gH_BotAddCommand,
			0x10000,                   // thisptr           // unused (sourcemod needs > 0xFFFF though)
			gCV_DefaultTeam.IntValue,  // team
			false,                     // isFromConsole
			0,                         // profileName       // unused
			gI_WEAPONTYPE_UNKNOWN,     // CSWeaponType      // WEAPONTYPE_UNKNOWN
			0                          // BotDifficultyType // unused
		);
	}
	else
	{
		/*int ret =*/ SDKCall(
			gH_BotAddCommand,
			gCV_DefaultTeam.IntValue,  // team
			false,                     // isFromConsole
			0,                         // profileName       // unused
			gI_WEAPONTYPE_UNKNOWN,     // CSWeaponType      // WEAPONTYPE_UNKNOWN
			0                          // BotDifficultyType // unused
		);
	}

	if (mp_randomspawn != null)
	{
		mp_randomspawn.IntValue = mp_randomspawn_orig;
	}

	//bool success = (0xFF & ret) != 0;

	return gI_LatestClient;
}

int CreateReplayBot(bot_info_t info)
{
	gA_BotInfo_Temp = info;

	int bot = InternalCreateReplayBot();

	bot_info_t empty_bot_info;
	gA_BotInfo_Temp = empty_bot_info;

	if (bot <= 0)
	{
		ClearBotInfo(info);
		return -1;
	}

	gA_BotInfo[bot] = info;
	gA_BotInfo[bot].iEnt = bot;

	if (info.iType == Replay_Central)
	{
		gI_CentralBot = bot;
		ClearBotInfo(gA_BotInfo[bot]);
	}
	else if (info.iType == Replay_Looping)
	{
		gA_BotInfo[bot].iStatus = Replay_Idle;

		if(info.iStage == 0)
		{
			gI_TrackBot = bot;

			for(int i = 0; i < TRACKS_SIZE; i++)
			{
				if(gA_FrameCache[0][i].iFrameCount > 0)
				{
					StartReplay(gA_BotInfo[bot], i, 0, GetClientFromSerial(info.iStarterSerial), info.fDelay, 0);
					break;
				}
			}
		}
		else
		{
			gI_StageBot = bot;

			for(int i = 1; i <= Shavit_GetMapStages(); i++)
			{
				if(gA_FrameCache_Stage[0][i].iFrameCount > 0)
				{
					StartReplay(gA_BotInfo[bot], 0, 0, GetClientFromSerial(info.iStarterSerial), info.fDelay, i);
					break;
				}
			}
		}
	}
	else
	{
		StartReplay(gA_BotInfo[bot], gA_BotInfo[bot].iTrack, gA_BotInfo[bot].iStyle, GetClientFromSerial(info.iStarterSerial), info.fDelay, gA_BotInfo[bot].iStage);
	}

	gA_BotInfo[GetClientFromSerial(info.iStarterSerial)].iEnt = bot;

	return bot;
}

int CreateReplayEntity(int track, int style, float delay, int client, int bot, int type, bool ignorelimit, frame_cache_t cache, int stage = 0)
{
	if (client > 0 && gA_BotInfo[client].iEnt > 0)
	{
		return 0;
	}

	if (delay == -1.0)
	{
		delay = gCV_ReplayDelay.FloatValue;
	}

	if (bot == -1)
	{
		if (type == Replay_Dynamic)
		{
			if (!ignorelimit && gI_DynamicBots >= gCV_DynamicBotLimit.IntValue)
			{
				return 0;
			}
		}

		bot_info_t info;
		info.iType = type;
		info.iStyle = style;
		info.iTrack = track;
		info.iStage = stage;
		info.iStarterSerial = (client > 0) ? GetClientSerial(client) : 0;
		info.bIgnoreLimit = ignorelimit;
		info.fDelay = delay;
		info.iStatus = (type == Replay_Central) ? Replay_Idle : Replay_Start;
		SetupIfCustomFrames(info, cache);
		bot = CreateReplayBot(info);

		if (bot != 0)
		{
			if (client > 0)
			{
				gA_BotInfo[client].iEnt = bot;
			}

			if (type == Replay_Dynamic && !ignorelimit)
			{
				++gI_DynamicBots;
			}
		}
	}
	else
	{
		type = gA_BotInfo[bot].iType;

		if (type != Replay_Central && type != Replay_Dynamic)
		{
			return 0;
		}

		CancelReplay(gA_BotInfo[bot], false);
		SetupIfCustomFrames(gA_BotInfo[bot], cache);
		StartReplay(gA_BotInfo[bot], track, style, client, delay, stage);
	}

	return bot;
}

void AddReplayBots()
{
	if (!gCV_Enabled.BoolValue)
	{
		return;
	}

	frame_cache_t cache; // NULL cache

	// Load central bot if enabled...
	if (gCV_CentralBot.BoolValue && gI_CentralBot <= 0)
	{
		int bot = CreateReplayEntity(0, 0, -1.0, 0, -1, Replay_Central, false, cache, 0);

		if (bot == 0)
		{
			LogError("Failed to create central replay bot (client count %d)", GetClientCount());
			return;
		}

		UpdateReplayClient(bot);
	}

	if (gI_TrackBot <= 0)
	{
		int bot = CreateReplayEntity(0, 0, -1.0, 0, -1, Replay_Looping, false, cache, 0);

		if (bot == 0)
		{
			LogError("Failed to create track loop replay bot (client count %d)", GetClientCount());
			return;
		}

		UpdateReplayClient(bot);
	}

	if (gI_StageBot <= 0)
	{
		int bot = CreateReplayEntity(0, 0, -1.0, 0, -1, Replay_Looping, false, cache, 1);

		if (bot == 0)
		{
			LogError("Failed to create stage loop replay bot (client count %d)", GetClientCount());
			return;
		}

		UpdateReplayClient(bot);
	}
}