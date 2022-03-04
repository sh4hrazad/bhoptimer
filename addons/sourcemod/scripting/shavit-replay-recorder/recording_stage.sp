// ======[ EVENTS ]======

void OnClientDisconnect_StopRecording_Stage(int client)
{
	if(gB_GrabbingPostFrames_Stage[client])
	{
		FinishGrabbingPostFrames_Stage(client, gA_WRCPRunInfo[client]);
	}
}

void Shavit_OnEnterStage_Recording(int client, int stage, int style, bool stagetimer)
{
	CutStageFailureFrames(client, stage, style, stagetimer);
}

void Shavit_OnTeleportBackStagePost_Recording(int client, int stage, int style, bool stagetimer)
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

void Shavit_OnStop_ClearFrames(int client)
{
	if(!gB_GrabbingPostFrames_Stage[client])
	{
		ClearFrames(client);
	}
}

void Shavit_OnWRCP_SaveRecording(int client, int stage, int style, float time, int steamid)
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

public Action Timer_StagePostFrames(Handle timer, int client)
{
	gH_PostFramesTimer_Stage[client] = null;
	FinishGrabbingPostFrames_Stage(client, gA_WRCPRunInfo[client]);
	return Plugin_Stop;
}

void FinishGrabbingPostFrames_Stage(int client, wrcp_run_info info)
{
	delete gH_PostFramesTimer_Stage[client];

	DoStageReplaySaverCallbacks(client, info.iStage, info.iStyle, info.fTime, info.iSteamid);
	gB_GrabbingPostFrames_Stage[client] = false;
}

void DoStageReplaySaverCallbacks(int client, int stage, int style, float time, int steamid)
{
	SaveStageReplay(client, stage, style, time, steamid, gI_PlayerPrerunFrames_Stage[client], gA_PlayerFrames[client], gI_PlayerFrames[client]);
}

// ======[ PRIVATE ]======

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