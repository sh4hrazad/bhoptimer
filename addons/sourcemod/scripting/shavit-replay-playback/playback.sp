static int gI_LastReplayFlags[MAXPLAYERS + 1];



// ======[ EVENTS ]======

void Shavit_OnEnterStageZone_Playback(int bot, int stage)
{
	if(gA_BotInfo[bot].iStyle || gA_BotInfo[bot].iStage != 0 || gA_BotInfo[bot].iStage == stage) // invalid style or get into the same stage(dont print twice)
	{
		return;
	}

	gA_BotInfo[bot].iRealTick = gA_BotInfo[bot].aCache.iPreFrames;
	gA_BotInfo[bot].fRealTime = Shavit_GetWRCPRealTime(stage, gA_BotInfo[bot].iStyle);
}

Action OnPlayerRunCmd_Playback(bot_info_t info, int &buttons, int &impulse, float vel[3])
{
	buttons = 0;

	vel[0] = 0.0;
	vel[1] = 0.0;

	if(info.aCache.aFrames != null || info.aCache.iFrameCount > 0) // if no replay is loaded
	{
		if(info.iTick != -1 && info.aCache.iFrameCount >= 1)
		{
			if (info.iStatus == Replay_End)
			{
				return Plugin_Changed;
			}

			if (info.iStatus == Replay_Start)
			{
				bool bStart = (info.iStatus == Replay_Start);
				int iFrame = (bStart) ? 0 : (info.aCache.iFrameCount + info.aCache.iPostFrames + info.aCache.iPreFrames - 1);
				TeleportToFrame(info, iFrame);
				return Plugin_Changed;
			}

			info.iTick += info.b2x ? 2 : 1;
			info.iRealTick += info.b2x ? 2 : 1;

			int limit = (info.aCache.iFrameCount + info.aCache.iPreFrames + info.aCache.iPostFrames);

			if(info.iTick >= limit)
			{
				info.iTick = limit;
				info.iRealTick = limit;
				info.iStatus = Replay_End;
				info.hTimer = CreateTimer((info.fDelay / 2.0), Timer_EndReplay, info.iEnt, TIMER_FLAG_NO_MAPCHANGE);

				Call_OnReplayEnd(info.iEnt, info.iType, false);

				return Plugin_Changed;
			}

			if(info.iTick == 1)
			{
				info.fFirstFrameTime = GetEngineTime();
			}

			float vecPreviousPos[3];

			if (info.b2x)
			{
				frame_t aFramePrevious;
				int previousTick = (info.iTick > 0) ? (info.iTick-1) : 0;
				info.aCache.aFrames.GetArray(previousTick, aFramePrevious, 8);
				vecPreviousPos = aFramePrevious.pos;
			}
			else
			{
				GetEntPropVector(info.iEnt, Prop_Send, "m_vecOrigin", vecPreviousPos);
			}

			frame_t aFrame;
			info.aCache.aFrames.GetArray(info.iTick, aFrame, 8);
			buttons = aFrame.buttons;

			if((gCV_BotShooting.IntValue & iBotShooting_Attack1) == 0)
			{
				buttons &= ~IN_ATTACK;
			}

			if((gCV_BotShooting.IntValue & iBotShooting_Attack2) == 0)
			{
				buttons &= ~IN_ATTACK2;
			}

			if(!gCV_BotPlusUse.BoolValue)
			{
				buttons &= ~IN_USE;
			}

			bool bWalk = false;
			MoveType mt = MOVETYPE_NOCLIP;

			int iReplayFlags = aFrame.flags;

			int iEntityFlags = GetEntityFlags(info.iEnt);

			ApplyFlags(iEntityFlags, iReplayFlags, FL_ONGROUND);
			ApplyFlags(iEntityFlags, iReplayFlags, FL_PARTIALGROUND);
			ApplyFlags(iEntityFlags, iReplayFlags, FL_INWATER);
			ApplyFlags(iEntityFlags, iReplayFlags, FL_SWIM);

			SetEntityFlags(info.iEnt, iEntityFlags);

			if((gI_LastReplayFlags[info.iEnt] & FL_ONGROUND) && !(iReplayFlags & FL_ONGROUND) && gH_DoAnimationEvent != INVALID_HANDLE)
			{
				int jumpAnim = CSGO_ANIM_JUMP;

				if(gB_Linux)
				{
					SDKCall(gH_DoAnimationEvent, EntIndexToEntRef(info.iEnt), jumpAnim, 0);
				}
				else
				{
					SDKCall(gH_DoAnimationEvent, info.iEnt, jumpAnim, 0);
				}
			}

			if(aFrame.mt == MOVETYPE_LADDER)
			{
				mt = aFrame.mt;
			}
			else if(aFrame.mt == MOVETYPE_WALK && (iReplayFlags & FL_ONGROUND) > 0)
			{
				bWalk = true;
			}

			gI_LastReplayFlags[info.iEnt] = aFrame.flags; 
			SetEntityMoveType(info.iEnt, mt);

			float vecVelocity[3];
			MakeVectorFromPoints(vecPreviousPos, aFrame.pos, vecVelocity);
			ScaleVector(vecVelocity, gF_Tickrate);

			float ang[3];
			ang[0] = aFrame.ang[0];
			ang[1] = aFrame.ang[1];

			if(info.b2x || (info.iTick > 1 &&
				// replay is going above 15k speed, just teleport at this point
				(GetVectorLength(vecVelocity) > 15000.0 ||
				// bot is on ground.. if the distance between the previous position is much bigger (1.5x) than the expected according
				// to the bot's velocity, teleport to avoid sync issues
				(bWalk && GetVectorDistance(vecPreviousPos, aFrame.pos) > GetVectorLength(vecVelocity) / gF_Tickrate * 1.5))))
			{
				TeleportEntity(info.iEnt, aFrame.pos, ang, info.b2x ? vecVelocity : NULL_VECTOR);
			}
			else
			{
				TeleportEntity(info.iEnt, NULL_VECTOR, ang, vecVelocity);
			}
		}
	}

	return Plugin_Changed;
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

void Frame_UpdateReplayClient(int serial)
{
	int client = GetClientFromSerial(serial);

	if (client > 0)
	{
		UpdateReplayClient(client);
	}
}

void UpdateReplayClient(int client)
{
	// Only run on fakeclients
	if (!gB_CanUpdateReplayClient || !gCV_Enabled.BoolValue || !IsValidClient(client) || !IsFakeClient(client))
	{
		return;
	}

	gF_Tickrate = (1.0 / GetTickInterval());

	SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
	SetEntityMoveType(client, MOVETYPE_NOCLIP);

	UpdateBotScoreboard(gA_BotInfo[client]);

	if(GetClientTeam(client) != gCV_DefaultTeam.IntValue)
	{
		CS_SwitchTeam(client, gCV_DefaultTeam.IntValue);
	}

	if(!IsPlayerAlive(client))
	{
		CS_RespawnPlayer(client);
	}

	int iFlags = GetEntityFlags(client);

	if((iFlags & FL_ATCONTROLS) == 0)
	{
		SetEntityFlags(client, (iFlags | FL_ATCONTROLS));
	}

	char sWeapon[32];
	gCV_BotWeapon.GetString(sWeapon, 32);

	if(strlen(sWeapon) > 0)
	{
		int iWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");

		if(StrEqual(sWeapon, "none"))
		{
			RemoveAllWeapons(client);
		}
		else
		{
			char sClassname[32];

			if(iWeapon != -1 && IsValidEntity(iWeapon))
			{
				GetEntityClassname(iWeapon, sClassname, 32);

				bool same_thing = false;

				// special case for csgo stuff because the usp classname becomes weapon_hpk2000
				if (StrEqual(sWeapon, "weapon_usp_silencer"))
				{
					same_thing = (61 == GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"));
				}
				else if (StrEqual(sWeapon, "weapon_hpk2000"))
				{
					same_thing = (32 == GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"));
				}

				if (!same_thing && !StrEqual(sWeapon, sClassname))
				{
					RemoveAllWeapons(client);
					GivePlayerItem(client, sWeapon);
				}
			}
			else
			{
				GivePlayerItem(client, sWeapon);
			}
		}
	}
}



// ======[ PRIVATE ]======
static void FormatStyle(int bot, const char[] source, int style, int track, char dest[MAX_NAME_LENGTH], bool idle, frame_cache_t aCache, int type, int stage = 0)
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

static void RemoveAllWeapons(int client)
{
	int weapon = -1, max = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	for (int i = 0; i < max; i++)
	{
		if ((weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i)) == -1)
			continue;

		if (RemovePlayerItem(client, weapon))
		{
			AcceptEntityInput(weapon, "Kill");
		}
	}
}

static void ApplyFlags(int &flags1, int flags2, int flag)
{
	if((flags2 & flag) != 0)
	{
		flags1 |= flag;
	}
	else
	{
		flags1 &= ~flag;
	}
}