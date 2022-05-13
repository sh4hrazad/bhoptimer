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
	//info.iLoopingConfig
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

	OnReplayStart_ResetPrestrafeMsg(info.iEnt);
	Call_OnReplayStart(info.iEnt, info.iType, false);
}

public Action Timer_StartReplay(Handle Timer, any data)
{
	gA_BotInfo[data].hTimer = null;
	gA_BotInfo[data].iStatus = Replay_Running;

	Call_OnReplayStart(gA_BotInfo[data].iEnt, gA_BotInfo[data].iType, true);

	return Plugin_Stop;
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