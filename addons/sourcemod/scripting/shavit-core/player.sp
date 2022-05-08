void HookPlayerEvents()
{
	HookEvent("player_jump", Player_Jump);
	HookEvent("player_death", Player_Death);
	HookEvent("player_team", Player_Death);
	HookEvent("player_spawn", Player_Death);
}

public void Player_Jump(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	DoJump(client);
}

public void Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	ResumeTimer(client);
	StopTimer(client);
}

public void OnClientPutInServer(int client)
{
	StopTimer(client);

	if(!IsClientConnected(client) || IsFakeClient(client))
	{
		return;
	}

	if(!gA_HookedPlayer[client].bHooked)
	{
		gA_HookedPlayer[client].Add(client);
	}

	gB_Auto[client] = true;
	gA_Timers[client].fStrafeWarning = 0.0;
	gA_Timers[client].bPracticeMode = false;
	gA_Timers[client].iSHSWCombination = -1;
	gA_Timers[client].iTimerTrack = 0;
	gA_Timers[client].bsStyle = 0;
	gA_Timers[client].fTimescale = 1.0;
	gA_Timers[client].fTimescaledTicks = 0.0;
	gA_Timers[client].iZoneIncrement = 0;
	gA_Timers[client].fplayer_speedmod = 1.0;
	gS_DeleteMap[client][0] = 0;

	gB_CookiesRetrieved[client] = false;

	if(AreClientCookiesCached(client))
	{
		OnClientCookiesCached(client);
	}

	// not adding style permission check here for obvious reasons
	else
	{
		CallOnStyleChanged(client, 0, gI_DefaultStyle, false);
	}

	SDKHook(client, SDKHook_PreThinkPost, PreThinkPost);
	SDKHook(client, SDKHook_PostThinkPost, PostThinkPost);

	if(GetSteamAccountID(client) == 0)
	{
		KickClient(client, "%T", "VerificationFailed", client);

		return;
	}

	OnClientPutInServer_UpdateClientData(client);
}

public void OnClientDisconnect(int client)
{
	gA_HookedPlayer[client].Remove();
	RequestFrame(StopTimer, client);
}

public Action Shavit_OnStartPre(int client, int track)
{
	if (GetTimerStatus(client) == Timer_Paused && gCV_PauseMovement.BoolValue)
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsFakeClient(client))
	{
		return Plugin_Continue;
	}

	int flags = GetEntityFlags(client);

	SetEntityFlags(client, (flags & ~FL_ATCONTROLS));

	// Wait till now to return so spectators can free-cam while paused...
	if(!IsPlayerAlive(client))
	{
		return Plugin_Changed;
	}

	Action result = Plugin_Continue;
	Call_OnUserCmdPre(client, buttons, impulse, vel, angles, GetTimerStatus(client), gA_Timers[client].iTimerTrack, gA_Timers[client].bsStyle, mouse, result);

	if(result != Plugin_Continue && result != Plugin_Changed)
	{
		return result;
	}

	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	bool bInStart = Shavit_InsideZone(client, Zone_Start, gA_Timers[client].iTimerTrack);

	if (gA_Timers[client].bTimerEnabled && !gA_Timers[client].bClientPaused)
	{
		// +strafe block
		if (GetStyleSettingInt(gA_Timers[client].bsStyle, "block_pstrafe") > 0 &&
			((vel[0] > 0.0 && (buttons & IN_FORWARD) == 0) || (vel[0] < 0.0 && (buttons & IN_BACK) == 0) ||
			(vel[1] > 0.0 && (buttons & IN_MOVERIGHT) == 0) || (vel[1] < 0.0 && (buttons & IN_MOVELEFT) == 0)))
		{
			if (gA_Timers[client].fStrafeWarning < gA_Timers[client].fCurrentTime)
			{
				if (GetStyleSettingInt(gA_Timers[client].bsStyle, "block_pstrafe") >= 2)
				{
					char sCheatDetected[64];
					FormatEx(sCheatDetected, 64, "%T", "Inconsistencies", client);
					StopTimer_Cheat(client, sCheatDetected);
				}

				vel[0] = 0.0;
				vel[1] = 0.0;

				return Plugin_Changed;
			}

			gA_Timers[client].fStrafeWarning = gA_Timers[client].fCurrentTime + 0.3;
		}
	}


	MoveType mtMoveType = GetEntityMoveType(client);

	if(mtMoveType == MOVETYPE_LADDER && gCV_SimplerLadders.BoolValue)
	{
		gA_Timers[client].bCanUseAllKeys = true;
	}

	else if(iGroundEntity != -1)
	{
		gA_Timers[client].bCanUseAllKeys = false;
	}

	// key blocking
	if(!gA_Timers[client].bCanUseAllKeys && mtMoveType != MOVETYPE_NOCLIP && mtMoveType != MOVETYPE_LADDER)
	{
		// block E
		if (GetStyleSettingBool(gA_Timers[client].bsStyle, "block_use") && (buttons & IN_USE) > 0)
		{
			buttons &= ~IN_USE;
		}

		if (iGroundEntity == -1 || GetStyleSettingBool(gA_Timers[client].bsStyle, "force_groundkeys"))
		{
			if (GetStyleSettingBool(gA_Timers[client].bsStyle, "block_w") && ((buttons & IN_FORWARD) > 0 || vel[0] > 0.0))
			{
				vel[0] = 0.0;
				buttons &= ~IN_FORWARD;
			}

			if (GetStyleSettingBool(gA_Timers[client].bsStyle, "block_a") && ((buttons & IN_MOVELEFT) > 0 || vel[1] < 0.0))
			{
				vel[1] = 0.0;
				buttons &= ~IN_MOVELEFT;
			}

			if (GetStyleSettingBool(gA_Timers[client].bsStyle, "block_s") && ((buttons & IN_BACK) > 0 || vel[0] < 0.0))
			{
				vel[0] = 0.0;
				buttons &= ~IN_BACK;
			}

			if (GetStyleSettingBool(gA_Timers[client].bsStyle, "block_d") && ((buttons & IN_MOVERIGHT) > 0 || vel[1] > 0.0))
			{
				vel[1] = 0.0;
				buttons &= ~IN_MOVERIGHT;
			}

			// HSW
			// Theory about blocking non-HSW strafes while playing HSW:
			// Block S and W without A or D.
			// Block A and D without S or W.
			if (GetStyleSettingInt(gA_Timers[client].bsStyle, "force_hsw") > 0)
			{
				bool bSHSW = (GetStyleSettingInt(gA_Timers[client].bsStyle, "force_hsw") == 2) && !bInStart; // don't decide on the first valid input until out of start zone!
				int iCombination = -1;

				bool bForward = ((buttons & IN_FORWARD) > 0 && vel[0] > 0.0);
				bool bMoveLeft = ((buttons & IN_MOVELEFT) > 0 && vel[1] < 0.0);
				bool bBack = ((buttons & IN_BACK) > 0 && vel[0] < 0.0);
				bool bMoveRight = ((buttons & IN_MOVERIGHT) > 0 && vel[1] > 0.0);

				if(bSHSW)
				{
					if((bForward && bMoveLeft) || (bBack && bMoveRight))
					{
						iCombination = 0;
					}
					else if((bForward && bMoveRight || bBack && bMoveLeft))
					{
						iCombination = 1;
					}

					// int gI_SHSW_FirstCombination[MAXPLAYERS+1]; // 0 - W/A S/D | 1 - W/D S/A
					if(gA_Timers[client].iSHSWCombination == -1 && iCombination != -1)
					{
						Shavit_PrintToChat(client, "%T", (iCombination == 0)? "SHSWCombination0":"SHSWCombination1", client);
						gA_Timers[client].iSHSWCombination = iCombination;
					}

					// W/A S/D
					if((gA_Timers[client].iSHSWCombination == 0 && iCombination != 0) ||
					// W/D S/A
						(gA_Timers[client].iSHSWCombination == 1 && iCombination != 1) ||
					// no valid combination & no valid input
						(gA_Timers[client].iSHSWCombination == -1 && iCombination == -1))
					{
						vel[0] = 0.0;
						vel[1] = 0.0;

						buttons &= ~IN_FORWARD;
						buttons &= ~IN_MOVELEFT;
						buttons &= ~IN_MOVERIGHT;
						buttons &= ~IN_BACK;
					}
				}
				else
				{
					if(bBack && (bMoveLeft || bMoveRight))
					{
						vel[0] = 0.0;

						buttons &= ~IN_FORWARD;
						buttons &= ~IN_BACK;
					}

					if(bForward && !(bMoveLeft || bMoveRight))
					{
						vel[0] = 0.0;

						buttons &= ~IN_FORWARD;
						buttons &= ~IN_BACK;
					}

					if((bMoveLeft || bMoveRight) && !bForward)
					{
						vel[1] = 0.0;

						buttons &= ~IN_MOVELEFT;
						buttons &= ~IN_MOVERIGHT;
					}
				}
			}
		}
	}

	bool bInWater = (GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2);
	bool bOnGround = (!bInWater && mtMoveType == MOVETYPE_WALK && iGroundEntity != -1);

	if (Shavit_InsideZone(client, Zone_AutoBhop, -1) || ((Shavit_CanAutoBhopInTrack(client) || GetStyleSettingBool(gA_Timers[client].bsStyle, "autobhop")) && gB_Auto[client] && (buttons & IN_JUMP) > 0 && mtMoveType == MOVETYPE_WALK && !bInWater))
	{
		int iOldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
		SetEntProp(client, Prop_Data, "m_nOldButtons", (iOldButtons & ~IN_JUMP));
	}

	gA_Timers[client].bJumped = false;
	gA_Timers[client].bOnGround = bOnGround;

	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (IsFakeClient(client))
	{
		return;
	}

	if (!IsPlayerAlive(client) || GetTimerStatus(client) != Timer_Running)
	{
		return;
	}

	if (GetStyleSettingBool(gA_Timers[client].bsStyle, "strafe_count_w")
	&& !GetStyleSettingBool(gA_Timers[client].bsStyle, "block_w")
	&& (gA_Timers[client].fLastInputVel[0] <= 0.0) && (vel[0] > 0.0)
	&& GetStyleSettingInt(gA_Timers[client].bsStyle, "force_hsw") != 1
	)
	{
		gA_Timers[client].iStrafes++;
	}

	if (GetStyleSettingBool(gA_Timers[client].bsStyle, "strafe_count_s")
	&& !GetStyleSettingBool(gA_Timers[client].bsStyle, "block_s")
	&& (gA_Timers[client].fLastInputVel[0] >= 0.0) && (vel[0] < 0.0)
	)
	{
		gA_Timers[client].iStrafes++;
	}

	if (GetStyleSettingBool(gA_Timers[client].bsStyle, "strafe_count_a")
	&& !GetStyleSettingBool(gA_Timers[client].bsStyle, "block_a")
	&& (gA_Timers[client].fLastInputVel[1] >= 0.0) && (vel[1] < 0.0)
	&& (GetStyleSettingInt(gA_Timers[client].bsStyle, "force_hsw") > 0 || vel[0] == 0.0)
	)
	{
		gA_Timers[client].iStrafes++;
	}

	if (GetStyleSettingBool(gA_Timers[client].bsStyle, "strafe_count_d")
	&& !GetStyleSettingBool(gA_Timers[client].bsStyle, "block_d")
	&& (gA_Timers[client].fLastInputVel[1] <= 0.0) && (vel[1] > 0.0)
	&& (GetStyleSettingInt(gA_Timers[client].bsStyle, "force_hsw") > 0 || vel[0] == 0.0)
	)
	{
		gA_Timers[client].iStrafes++;
	}

	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	float fAngle = GetAngleDiff(angles[1], gA_Timers[client].fLastAngle);

	if (iGroundEntity == -1 && (GetEntityFlags(client) & FL_INWATER) == 0 && fAngle != 0.0)
	{
		float fAbsVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);

		if (SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0)) > 0.0)
		{
			float fTempAngle = angles[1];

			float fAngles[3];
			GetVectorAngles(fAbsVelocity, fAngles);

			if (fTempAngle < 0.0)
			{
				fTempAngle += 360.0;
			}

			TestAngles(client, (fTempAngle - fAngles[1]), fAngle, vel);
		}
	}

	if (gA_Timers[client].fCurrentTime != 0.0)
	{
		float frameCount = float(gA_Timers[client].iZoneIncrement);
		float fAbsVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);
		float curVel = SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0));
		float maxVel = gA_Timers[client].fMaxVelocity;
		gA_Timers[client].fMaxVelocity = (curVel > maxVel) ? curVel : maxVel;
		// STOLEN from Epic/Disrevoid. Thx :)
		gA_Timers[client].fAvgVelocity += (curVel - gA_Timers[client].fAvgVelocity) / frameCount;
	}

	gA_Timers[client].iLastButtons = buttons;
	gA_Timers[client].fLastAngle = angles[1];
	gA_Timers[client].fLastInputVel[0] = vel[0];
	gA_Timers[client].fLastInputVel[1] = vel[1];
}

static void DoJump(int client)
{
	if (gA_Timers[client].bTimerEnabled && !gA_Timers[client].bClientPaused)
	{
		gA_Timers[client].iJumps++;
		gA_Timers[client].bJumped = true;
	}

	SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);

	RequestFrame(VelocityChanges, GetClientSerial(client));
}

static void VelocityChanges(int data)
{
	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	int style = gA_Timers[client].bsStyle;

	if(GetStyleSettingBool(style, "force_timescale"))
	{
		float mod = gA_Timers[client].fTimescale * GetStyleSettingFloat(gA_Timers[client].bsStyle, "speed");
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", mod);
	}

	float fAbsVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);

	float fSpeed = (SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0)));

	if(fSpeed != 0.0)
	{
		float fVelocityMultiplier = GetStyleSettingFloat(style, "velocity");
		float fVelocityBonus = GetStyleSettingFloat(style, "bonus_velocity");
		float fMin = GetStyleSettingFloat(style, "min_velocity");

		if(fVelocityMultiplier != 0.0)
		{
			fAbsVelocity[0] *= fVelocityMultiplier;
			fAbsVelocity[1] *= fVelocityMultiplier;
		}

		if(fVelocityBonus != 0.0)
		{
			float x = fSpeed / (fSpeed + fVelocityBonus);
			fAbsVelocity[0] /= x;
			fAbsVelocity[1] /= x;
		}

		if(fMin != 0.0 && fSpeed < fMin)
		{
			float x = (fSpeed / fMin);
			fAbsVelocity[0] /= x;
			fAbsVelocity[1] /= x;
		}
	}

	float fJumpMultiplier = GetStyleSettingFloat(style, "jump_multiplier");
	float fJumpBonus = GetStyleSettingFloat(style, "jump_bonus");

	if(fJumpMultiplier != 0.0)
	{
		fAbsVelocity[2] *= fJumpMultiplier;
	}

	if(fJumpBonus != 0.0)
	{
		fAbsVelocity[2] += fJumpBonus;
	}


	if(!gCV_VelocityTeleport.BoolValue)
	{
		SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);
	}

	else
	{
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fAbsVelocity);
	}
}

public void PreThinkPost(int client)
{
	if(IsPlayerAlive(client))
	{
		MoveType mtMoveType = GetEntityMoveType(client);

		if (GetStyleSettingFloat(gA_Timers[client].bsStyle, "gravity") != 1.0 &&
			(mtMoveType == MOVETYPE_WALK || mtMoveType == MOVETYPE_ISOMETRIC) &&
			(gA_Timers[client].iLastMoveType == MOVETYPE_LADDER || GetEntityGravity(client) == 1.0))
		{
			SetEntityGravity(client, GetStyleSettingFloat(gA_Timers[client].bsStyle, "gravity"));
		}

		gA_Timers[client].iLastMoveType = mtMoveType;
	}
}

public void PostThinkPost(int client)
{
	gF_Origin[client][1] = gF_Origin[client][0];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", gF_Origin[client][0]);

	if(gA_Timers[client].iZoneIncrement == 1 && gCV_UseOffsets.BoolValue)
	{
		float fVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel);

		if(fVel[2] == 0.0)
		{
			CalculateTickIntervalOffset(client, Zone_Start);
		}
	}
}

// reference: https://github.com/momentum-mod/game/blob/5e2d1995ca7c599907980ee5b5da04d7b5474c61/mp/src/game/server/momentum/mom_timer.cpp#L388
void CalculateTickIntervalOffset(int client, int zonetype)
{
	float localOrigin[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", localOrigin);
	float maxs[3];
	float mins[3];
	float vel[3];
	GetEntPropVector(client, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", maxs);
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);

	gF_SmallestDist[client] = 0.0;

	if (zonetype == Zone_Start)
	{
		TR_EnumerateEntitiesHull(localOrigin, gF_Origin[client][1], mins, maxs, PARTITION_TRIGGER_EDICTS, TREnumTrigger, client);
	}
	else
	{
		TR_EnumerateEntitiesHull(gF_Origin[client][0], localOrigin, mins, maxs, PARTITION_TRIGGER_EDICTS, TREnumTrigger, client);
	}

	float offset = gF_Fraction[client] * GetTickInterval();

	gA_Timers[client].fZoneOffset[zonetype] = gF_Fraction[client];
	gA_Timers[client].fDistanceOffset[zonetype] = gF_SmallestDist[client];

	Call_OnTimeOffsetCalculated(client, zonetype, offset, gF_SmallestDist[client]);

	gF_SmallestDist[client] = 0.0;
}

static bool TREnumTrigger(int entity, int client)
{
	if(entity <= MaxClients)
	{
		return true;
	}

	char classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));

	//the entity is a zone
	if(StrContains(classname, "trigger_multiple") > -1)
	{
		TR_ClipCurrentRayToEntity(MASK_ALL, entity);

		float start[3];
		TR_GetStartPosition(INVALID_HANDLE, start);

		float end[3];
		TR_GetEndPosition(end);

		float distance = GetVectorDistance(start, end);
		gF_SmallestDist[client] = distance;
		gF_Fraction[client] = TR_GetFraction();

		return false;
	}

	return true;
}

void UpdateLaggedMovement(int client, bool user_timescale)
{
	float style_laggedmovement =
		  GetStyleSettingFloat(gA_Timers[client].bsStyle, "timescale")
		* GetStyleSettingFloat(gA_Timers[client].bsStyle, "speed");

	float laggedmovement =
		  (user_timescale ? gA_Timers[client].fTimescale : 1.0)
		* style_laggedmovement;

	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", laggedmovement * gA_Timers[client].fplayer_speedmod);
}

static void TestAngles(int client, float dirangle, float yawdelta, const float vel[3])
{
	if(dirangle < 0.0)
	{
		dirangle = -dirangle;
	}

	// normal
	if(dirangle < 22.5 || dirangle > 337.5)
	{
		gA_Timers[client].iTotalMeasures++;

		if((yawdelta > 0.0 && vel[1] <= -100.0) || (yawdelta < 0.0 && vel[1] >= 100.0))
		{
			gA_Timers[client].iGoodGains++;
		}
	}

	// hsw (thanks nairda!)
	else if((dirangle > 22.5 && dirangle < 67.5))
	{
		gA_Timers[client].iTotalMeasures++;

		if((yawdelta != 0.0) && (vel[0] >= 100.0 || vel[1] >= 100.0) && (vel[0] >= -100.0 || vel[1] >= -100.0))
		{
			gA_Timers[client].iGoodGains++;
		}
	}

	// sw
	else if((dirangle > 67.5 && dirangle < 112.5) || (dirangle > 247.5 && dirangle < 292.5))
	{
		gA_Timers[client].iTotalMeasures++;

		if(vel[0] <= -100.0 || vel[0] >= 100.0)
		{
			gA_Timers[client].iGoodGains++;
		}
	}
}
