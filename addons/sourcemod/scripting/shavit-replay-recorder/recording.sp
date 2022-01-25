
// just a simple thing to prevent plugin reloads from recording half-replays
static bool gB_RecordingEnabled[MAXPLAYERS+1];

// stuff related to preframes
static int gI_PlayerLastStageFrame[MAXPLAYERS+1];

// stuff related to postframes
static Handle gH_PostFramesTimer[MAXPLAYERS+1];
static Handle gH_PostFramesTimer_Stage[MAXPLAYERS+1];
static int gI_PlayerFinishFrame[MAXPLAYERS+1];

static float gF_NextFrameTime[MAXPLAYERS+1];

// =====[ PUBLIC ]=====

void FinishGrabbingPostFrames_Stage(int client, wrcp_run_info info)
{
	delete gH_PostFramesTimer_Stage[client];

	DoStageReplaySaverCallbacks(client, info.iStage, info.iStyle, info.fTime, info.iSteamid);
	gB_GrabbingPostFrames_Stage[client] = false;
}

void FinishGrabbingPostFrames(int client, finished_run_info info)
{
	gB_GrabbingPostFrames[client] = false;
	delete gH_PostFramesTimer[client];

	DoReplaySaverCallbacks(info.iSteamID, client, info.style, info.time, info.jumps, info.strafes, info.sync, info.track, info.oldtime, info.avgvel, info.maxvel, info.timestamp, info.fZoneOffset);
}

// =====[ EVENTS ]=====

void OnClientPutInServer_Recording(int client)
{
	gI_HijackFrames[client] = 0;
	ClearFrames(client);
}

void OnClientDisconnect_StopRecording(int client)
{
	if(gB_GrabbingPostFrames_Stage[client])
	{
		FinishGrabbingPostFrames_Stage(client, gA_WRCPRunInfo[client]);
	}

	if (gB_GrabbingPostFrames[client])
	{
		FinishGrabbingPostFrames(client, gA_FinishedRunInfo[client]);
	}
}

void OnClientDisconnect_Post_StopRecording(int client)
{
	// This runs after shavit-misc has cloned the handle
	delete gA_PlayerFrames[client];
}

void OnPlayerRunCmdPost_Recording(int client, int buttons, const float vel[3], const int mouse[2])
{
	if (!gA_PlayerFrames[client] || !gB_RecordingEnabled[client])
	{
		return;
	}

	bool grabbing = (gB_GrabbingPostFrames[client] || gB_GrabbingPostFrames_Stage[client]);

	if(grabbing || (ReplayEnabled(Shavit_GetBhopStyle(client)) && Shavit_GetTimerStatus(client) == Timer_Running))
	{
		if((gI_PlayerFrames[client] / gF_Tickrate) > gCV_TimeLimit.FloatValue)
		{
			if (gI_HijackFrames[client])
			{
				gI_HijackFrames[client] = 0;
			}

			return;
		}

		float fTimescale = Shavit_GetClientTimescale(client);

		if(fTimescale != 0.0)
		{
			if(gF_NextFrameTime[client] <= 0.0)
			{
				if (gA_PlayerFrames[client].Length <= gI_PlayerFrames[client])
				{
					// Add about two seconds worth of frames so we don't have to resize so often
					gA_PlayerFrames[client].Resize(gI_PlayerFrames[client] + (RoundToCeil(gF_Tickrate) * 2));
				}

				frame_t aFrame;
				GetClientAbsOrigin(client, aFrame.pos);

				if (!gI_HijackFrames[client])
				{
					float vecEyes[3];
					GetClientEyeAngles(client, vecEyes);
					aFrame.ang[0] = vecEyes[0];
					aFrame.ang[1] = vecEyes[1];
				}
				else
				{
					aFrame.ang = gF_HijackedAngles[client];
					--gI_HijackFrames[client];
				}

				aFrame.buttons = buttons;
				aFrame.flags = GetEntityFlags(client);
				aFrame.mt = GetEntityMoveType(client);

				aFrame.mousexy = (mouse[0] & 0xFFFF) | ((mouse[1] & 0xFFFF) << 16);
				aFrame.vel = LimitMoveVelFloat(vel[0]) | (LimitMoveVelFloat(vel[1]) << 16);

				gA_PlayerFrames[client].SetArray(gI_PlayerFrames[client]++, aFrame, sizeof(frame_t));

				if(fTimescale != -1.0)
				{
					gF_NextFrameTime[client] += (1.0 - fTimescale);
				}
			}
			else if(fTimescale != -1.0)
			{
				gF_NextFrameTime[client] -= fTimescale;
			}
		}
	}
}

void Shavit_OnStart_Recording(int client)
{
	gB_RecordingEnabled[client] = true;

	if (!gB_HijackFramesKeepOnStart[client])
	{
		gI_HijackFrames[client] = 0;
	}

	if(gB_GrabbingPostFrames_Stage[client] && Shavit_GetCurrentStage(client) == 1)
	{
		FinishGrabbingPostFrames_Stage(client, gA_WRCPRunInfo[client]);
	}

	if (gB_GrabbingPostFrames[client])
	{
		FinishGrabbingPostFrames(client, gA_FinishedRunInfo[client]);
	}

	int iMaxPreFrames = RoundToFloor(gCV_PlaybackPreRunTime.FloatValue * gF_Tickrate / Shavit_GetStyleSettingFloat(Shavit_GetBhopStyle(client), "speed"));
	bool bInStart = Shavit_InsideZone(client, Zone_Start, Shavit_GetClientTrack(client));

	if (bInStart)
	{
		int iFrameDifference = gI_PlayerFrames[client] - iMaxPreFrames;

		if (iFrameDifference > 0)
		{
			// For too many extra frames, we'll just shift the preframes to the start of the array.
			if (iFrameDifference > 100)
			{
				for (int i = iFrameDifference; i < gI_PlayerFrames[client]; i++)
				{
					gA_PlayerFrames[client].SwapAt(i, i-iFrameDifference);
				}

				gI_PlayerFrames[client] = iMaxPreFrames;
			}
			else // iFrameDifference isn't that bad, just loop through and erase.
			{
				while (iFrameDifference--)
				{
					gA_PlayerFrames[client].Erase(0);
					gI_PlayerFrames[client]--;
				}
			}
		}
	}
	else
	{
		if (!gCV_PreRunAlways.BoolValue)
		{
			ClearFrames(client);
		}
	}

	gI_PlayerPrerunFrames[client] = gI_PlayerFrames[client];
}

void Shavit_OnEnterStage_Recording(int client, int stage, int style, bool stagetimer)
{
	CutStageFailureFrames(client, stage, style, stagetimer);
}

void Shavit_OnLeaveStage_Recording(int client, int style)
{
	if(gB_GrabbingPostFrames_Stage[client])
	{
		FinishGrabbingPostFrames_Stage(client, gA_WRCPRunInfo[client]);
	}

	int iMaxPreFrames = RoundToFloor(gCV_StagePlaybackPreRunTime.FloatValue * gF_Tickrate / Shavit_GetStyleSettingFloat(style, "speed"));
	int iPreframes = gI_PlayerFrames[client] - iMaxPreFrames;
	if(iPreframes < 0)
	{
		iPreframes = 0;
	}

	gI_PlayerPrerunFrames_Stage[client] = iPreframes;
}

void Shavit_OnTimerStop_Recording(int client)
{
	if(gB_GrabbingPostFrames[client])
	{
		FinishGrabbingPostFrames(client, gA_FinishedRunInfo[client]);
	}

	if(!gB_GrabbingPostFrames_Stage[client])
	{
		ClearFrames(client);
	}
}

void Shavit_OnFinish_Recording(int client, int style, float time, int jumps, int strafes, float sync, int track, float& oldtime, float avgvel, float maxvel, int timestamp)
{
	if(Shavit_IsPracticeMode(client) || !gCV_Enabled.BoolValue || gI_PlayerFrames[client] == 0)
	{
		return;
	}

	gI_PlayerFinishFrame[client] = gI_PlayerFrames[client];

	float fZoneOffset[2];
	fZoneOffset[0] = Shavit_GetZoneOffset(client, 0);
	fZoneOffset[1] = Shavit_GetZoneOffset(client, 1);

	if (gCV_PlaybackPostRunTime.FloatValue > 0.0)
	{
		finished_run_info info;
		info.iSteamID = GetSteamAccountID(client);
		info.style = style;
		info.time = time;
		info.jumps = jumps;
		info.strafes = strafes;
		info.sync = sync;
		info.track = track;
		info.oldtime = oldtime;
		info.avgvel = avgvel;
		info.maxvel = maxvel;
		info.timestamp = timestamp;
		info.fZoneOffset = fZoneOffset;

		gA_FinishedRunInfo[client] = info;
		gB_GrabbingPostFrames[client] = true;
		delete gH_PostFramesTimer[client];
		gH_PostFramesTimer[client] = CreateTimer(gCV_PlaybackPostRunTime.FloatValue, Timer_PostFrames, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		DoReplaySaverCallbacks(GetSteamAccountID(client), client, style, time, jumps, strafes, sync, track, oldtime, avgvel, maxvel, timestamp, fZoneOffset);
	}
}

void Shavit_OnWRCP_Recording(int client, int stage, int style, int steamid, float time)
{
	if(gCV_StagePlaybackPostRunTime.FloatValue > 0.0)
	{
		wrcp_run_info info;
		info.iStage = stage;
		info.iStyle = style;
		info.iSteamid = steamid;
		info.fTime = time;
		gA_WRCPRunInfo[client] = info;

		gB_GrabbingPostFrames_Stage[client] = true;
		delete gH_PostFramesTimer_Stage[client];
		gH_PostFramesTimer_Stage[client] = CreateTimer(gCV_StagePlaybackPostRunTime.FloatValue, Timer_StagePostFrames, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		DoStageReplaySaverCallbacks(client, stage, style, time, steamid);
	}
}

void Shavit_OnTimescaleChanged_Recording(int client)
{
	gF_NextFrameTime[client] = 0.0;
}

// =====[ PRIVATE ]=====

static int LimitMoveVelFloat(float vel)
{
	int x = RoundToCeil(vel);
	return ((x < -666) ? -666 : ((x > 666) ? 666 : x)) & 0xFFFF;
}

static void ClearFrames(int client)
{
	delete gA_PlayerFrames[client];
	gA_PlayerFrames[client] = new ArrayList(sizeof(frame_t));
	gI_PlayerFrames[client] = 0;
	gF_NextFrameTime[client] = 0.0;
	gI_PlayerPrerunFrames[client] = 0;
	gI_PlayerPrerunFrames_Stage[client] = 0;
	gI_PlayerFinishFrame[client] = 0;
	gI_HijackFrames[client] = 0;
	gB_HijackFramesKeepOnStart[client] = false;
}

static bool CutStageFailureFrames(int client, int stage, int style, bool stagetimer)
{
	if(stagetimer || StrContains(gS_StyleStrings[style].sSpecialString, "segment") != -1)
	{
		return false;
	}

	if(Shavit_GetLastStage(client) == stage)
	{
		gI_PlayerFrames[client] = gI_PlayerLastStageFrame[client];
	}

	gI_PlayerLastStageFrame[client] = gI_PlayerFrames[client];

	return true;
}

static void DoReplaySaverCallbacks(int iSteamID, int client, int style, float time, int jumps, int strafes, float sync, int track, float oldtime, float avgvel, float maxvel, int timestamp, float fZoneOffset[2])
{
	gA_PlayerFrames[client].Resize(gI_PlayerFrames[client]);

	bool isTooLong = (gCV_TimeLimit.FloatValue > 0.0 && time > gCV_TimeLimit.FloatValue);

	float length = Shavit_GetReplayLength(style, track);
	bool isBestReplay = (length == 0.0 || time < length);

	Action action = Plugin_Continue;
	Call_ShouldSaveReplayCopy(client, style, time, jumps, strafes, sync, track, oldtime, avgvel, maxvel, timestamp, isBestReplay, isTooLong, action);

	bool makeCopy = (action != Plugin_Continue);
	bool makeReplay = (isBestReplay && !isTooLong);

	if (!makeCopy && !makeReplay)
	{
		return;
	}

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, MAX_NAME_LENGTH);
	ReplaceString(sName, MAX_NAME_LENGTH, "#", "?");

	int postframes = gI_PlayerFrames[client] - gI_PlayerFinishFrame[client];

	char sPath[PLATFORM_MAX_PATH];
	SaveReplay(style, track, time, iSteamID, gI_PlayerPrerunFrames[client], gA_PlayerFrames[client], gI_PlayerFrames[client], postframes, timestamp, fZoneOffset, makeCopy, makeReplay, sPath, sizeof(sPath));

	Call_OnReplaySaved(client, style, time, jumps, strafes, sync, track, oldtime, avgvel, maxvel, timestamp, isBestReplay, isTooLong, makeCopy, sPath, gA_PlayerFrames[client], gI_PlayerPrerunFrames[client], postframes, sName);

	ClearFrames(client);
}

void DoStageReplaySaverCallbacks(int client, int stage, int style, float time, int steamid)
{
	SaveStageReplay(stage, style, time, steamid, gI_PlayerPrerunFrames_Stage[client], gA_PlayerFrames[client], gI_PlayerFrames[client]);

	Call_OnStageReplaySaved(client, stage, style, time, steamid, gA_PlayerFrames[client], gI_PlayerPrerunFrames_Stage[client], gI_PlayerFrames[client]);
}

public Action Timer_PostFrames(Handle timer, int client)
{
	gH_PostFramesTimer[client] = null;
	FinishGrabbingPostFrames(client, gA_FinishedRunInfo[client]);
	return Plugin_Stop;
}

public Action Timer_StagePostFrames(Handle timer, int client)
{
	gH_PostFramesTimer_Stage[client] = null;
	FinishGrabbingPostFrames_Stage(client, gA_WRCPRunInfo[client]);
	return Plugin_Stop;
}