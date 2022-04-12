int InternalCreateReplayBot()
{
	gI_LatestClient = -1;

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