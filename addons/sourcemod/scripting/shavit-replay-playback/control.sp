Action OnPlayerRunCmd_Replay(bot_info_t info, int &buttons, int &impulse, float vel[3])
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

public Action Timer_EndReplay(Handle Timer, any data)
{
	gA_BotInfo[data].hTimer = null;

	FinishReplay(gA_BotInfo[data]);

	return Plugin_Stop;
}

// ======[ PRIVATE ]======
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