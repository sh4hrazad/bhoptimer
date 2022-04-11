static GlobalForward H_Forwards_EnterStage = null;
static GlobalForward H_Forwards_EnterCheckpoint = null;
static GlobalForward H_Forwards_LeaveStage = null;
static GlobalForward H_Forwards_LeaveCheckpoint = null;
static GlobalForward H_Forwards_OnWRCP = null;
static GlobalForward H_Forwards_OnWRCPDeleted = null;
static GlobalForward H_Forwards_OnFinishStagePre = null;
static GlobalForward H_Forwards_OnFinishStage_Post = null;
static GlobalForward H_Forwards_OnFinishCheckpointPre = null;
static GlobalForward H_Forwards_OnFinishCheckpoint = null;



// ======[ NATIVES ]======

void CreateNatives()
{
	CreateNative("Shavit_ReloadWRStages", Native_ReloadWRStages);
	CreateNative("Shavit_ReloadWRCPs", Native_ReloadWRCPs);
	CreateNative("Shavit_GetStageRecordAmount", Native_GetStageRecordAmount);
	CreateNative("Shavit_GetStageRankForTime", Native_GetStageRankForTime);
	CreateNative("Shavit_GetWRStageDate", Native_GetWRStageDate);
	CreateNative("Shavit_GetWRStageTime", Native_GetWRStageTime);
	CreateNative("Shavit_GetWRStagePostspeed", Native_GetWRStagePostspeed);
	CreateNative("Shavit_GetWRStageName", Native_GetWRStageName);
	CreateNative("Shavit_GetWRCPAttemps", Native_GetWRCPAttemps);
	CreateNative("Shavit_GetWRCPTime", Native_GetWRCPTime);
	CreateNative("Shavit_GetWRCPRealTime", Native_GetWRCPRealTime);
	CreateNative("Shavit_GetWRCPPrespeed", Native_GetWRCPPrespeed);
	CreateNative("Shavit_GetWRCPPostspeed", Native_GetWRCPPostspeed);
	CreateNative("Shavit_GetWRCPDiffTime", Native_GetWRCPDiffTime);
	CreateNative("Shavit_FinishStage", Native_FinishStage);
	CreateNative("Shavit_FinishCheckpoint", Native_FinishCheckpoint);
	CreateNative("Shavit_GetStagePB", Native_GetStagePB);
	CreateNative("Shavit_GetCheckpointPB", Native_GetCheckpointPB);
}

public any Native_ReloadWRStages(Handle handler, int numParams)
{
	if(gB_Connected)
	{
		ResetWRStages();
	}

	return;
}

public any Native_ReloadWRCPs(Handle handler, int numParams)
{
	if(gB_Connected)
	{
		ResetWRCPs();
	}

	return;
}

public int Native_GetStageRecordAmount(Handle handler, int numParams)
{
	return GetStageRecordAmount(GetNativeCell(1), GetNativeCell(2));
}

public int Native_GetStageRankForTime(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int stage = GetNativeCell(3);

	if(gA_StageLeaderboard[style][stage] == null || gA_StageLeaderboard[style][stage].Length == 0)
	{
		return 0;
	}

	return GetStageRankForTime(style, GetNativeCell(2), stage);
}

public int Native_GetWRStageDate(Handle handler, int numParams)
{
	// TODO
	return 0;
}

public any Native_GetWRStageTime(Handle handler, int numParams)
{
	return gA_WRStageInfo[GetNativeCell(2)][GetNativeCell(1)].fTime;
}

public any Native_GetWRStagePostspeed(Handle handler, int numParams)
{
	return gA_WRStageInfo[GetNativeCell(2)][GetNativeCell(1)].fPostspeed;
}

public any Native_GetWRStageName(Handle handler, int numParams)
{
	SetNativeString(3, gA_WRStageInfo[GetNativeCell(1)][GetNativeCell(2)].sName, GetNativeCell(4));

	return;
}

public int Native_GetWRCPAttemps(Handle handler, int numParams)
{
	return gA_WRCPInfo[GetNativeCell(2)][GetNativeCell(1)].iAttemps;
}

public any Native_GetWRCPTime(Handle handler, int numParams)
{
	return gA_WRCPInfo[GetNativeCell(2)][GetNativeCell(1)].fTime;
}

public any Native_GetWRCPRealTime(Handle handler, int numParams)
{
	return gA_WRCPInfo[GetNativeCell(2)][GetNativeCell(1)].fRealTime;
}

public any Native_GetWRCPPrespeed(Handle handler, int numParams)
{
	return gA_WRCPInfo[GetNativeCell(2)][GetNativeCell(1)].fPrespeed;
}

public any Native_GetWRCPPostspeed(Handle handler, int numParams)
{
	return gA_WRCPInfo[GetNativeCell(2)][GetNativeCell(1)].fPostspeed;
}

public any Native_GetWRCPDiffTime(Handle handler, int numParams)
{
	return gF_DiffTime[GetNativeCell(1)];
}

public any Native_FinishStage(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	bool bBypass = (numParams < 2 || view_as<bool>(GetNativeCell(2)));
	int stage = Shavit_GetCurrentStage(client);
	int style = Shavit_GetBhopStyle(client);

	if(Shavit_GetClientTrack(client) != Track_Main)
	{
		return;
	}

	float time = Shavit_GetClientTime(client) - Shavit_GetLeaveStageTime(client);

	if(time > 0.0 && Shavit_GetTimerStatus(client) != Timer_Stopped)
	{
		if(!bBypass)
		{
			Action result = Plugin_Continue;
			Call_OnFinishStagePre(client, stage, style, result);

			if(result > Plugin_Continue)
			{
				return;
			}
		}

		DB_OnFinishStage(client, stage - 1, style, time, gA_StageInfo[client][style][stage - 1].fTime);
	}

	return;
}

public any Native_FinishCheckpoint(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	bool bBypass = (numParams < 2 || view_as<bool>(GetNativeCell(2)));
	int cpnum = (Shavit_IsLinearMap()) ? Shavit_GetCurrentCP(client) : Shavit_GetCurrentStage(client);
	int style = Shavit_GetBhopStyle(client);

	if(Shavit_GetClientTrack(client) != Track_Main)
	{
		return;
	}

	float time = Shavit_GetClientTime(client);

	if(time > 0.0 && Shavit_GetTimerStatus(client) != Timer_Stopped)
	{
		if(!bBypass)
		{
			Action result = Plugin_Continue;
			Call_OnFinishCheckpointPre(client, cpnum, style, result);

			if(result > Plugin_Continue)
			{
				return;
			}
		}

		gF_CPTime[client][cpnum] = time;

		float diff = time - gA_WRCPInfo[style][cpnum].fTime;
		gF_DiffTime[client] = diff;

		float prTime = gA_CheckpointInfo[client][style][cpnum].fTime;

		float fVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelocity);
		float prespeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0) + Pow(fVelocity[2], 2.0));

		Call_OnFinishCheckpoint(client, cpnum, style, time, diff, time - prTime, prespeed);
	}

	return;
}

public int Native_GetStagePB(Handle handler, int numParams)
{
	if(GetNativeCell(5) != sizeof(stage_t))
	{
		return ThrowNativeError(200, "stage_t does not match latest(got %i expected %i). Please update your includes and recompile your plugins",
			GetNativeCell(4), sizeof(stage_t));
	}

	int client = GetNativeCell(1);
	int style = GetNativeCell(2);
	int stage = GetNativeCell(3);

	return SetNativeArray(4, gA_StageInfo[client][style][stage], sizeof(stage_t));
}

public int Native_GetCheckpointPB(Handle handler, int numParams)
{
	if(GetNativeCell(5) != sizeof(cp_t))
	{
		return ThrowNativeError(200, "cp_t does not match latest(got %i expected %i). Please update your includes and recompile your plugins",
			GetNativeCell(4), sizeof(cp_t));
	}

	int client = GetNativeCell(1);
	int style = GetNativeCell(2);
	int cp = GetNativeCell(3);

	return SetNativeArray(4, gA_CheckpointInfo[client][style][cp], sizeof(cp_t));
}



// ======[ FORWARDS ]======

void CreateGlobalForwards()
{
	H_Forwards_EnterStage = new GlobalForward("Shavit_OnEnterStage", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell);
	H_Forwards_EnterCheckpoint = new GlobalForward("Shavit_OnEnterCheckpoint", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float);
	H_Forwards_LeaveStage = new GlobalForward("Shavit_OnLeaveStage", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell);
	H_Forwards_LeaveCheckpoint = new GlobalForward("Shavit_OnLeaveCheckpoint", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float);
	H_Forwards_OnWRCP = new GlobalForward("Shavit_OnWRCP", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Float, Param_String);
	H_Forwards_OnWRCPDeleted = new GlobalForward("Shavit_OnWRCPDeleted", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String);
	H_Forwards_OnFinishStagePre = new GlobalForward("Shavit_OnFinishStagePre", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	H_Forwards_OnFinishStage_Post = new GlobalForward("Shavit_OnFinishStage_Post", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Float);
	H_Forwards_OnFinishCheckpointPre = new GlobalForward("Shavit_OnFinishCheckpointPre", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	H_Forwards_OnFinishCheckpoint = new GlobalForward("Shavit_OnFinishCheckpoint", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Float, Param_Float);
}

void Call_OnEnterStage(int client, int stage, int style, float enterspeed, float time, bool stagetimer)
{
	Call_StartForward(H_Forwards_EnterStage);
	Call_PushCell(client);
	Call_PushCell(stage);
	Call_PushCell(style);
	Call_PushFloat(enterspeed);
	Call_PushFloat(time);
	Call_PushCell(stagetimer);
	Call_Finish();
}

void Call_OnEnterCheckpoint(int client, int cp, int style, float enterspeed, float time)
{
	Call_StartForward(H_Forwards_EnterCheckpoint);
	Call_PushCell(client);
	Call_PushCell(cp);
	Call_PushCell(style);
	Call_PushFloat(enterspeed);
	Call_PushFloat(time);
	Call_Finish();
}

void Call_OnLeaveStage(int client, int stage, int style, float leavespeed, float time, bool stagetimer)
{
	Call_StartForward(H_Forwards_LeaveStage);
	Call_PushCell(client);
	Call_PushCell(stage);
	Call_PushCell(style);
	Call_PushFloat(leavespeed);
	Call_PushFloat(time);
	Call_PushCell(stagetimer);
	Call_Finish();
}

void Call_OnLeaveCheckpoint(int client, int cp, int style, float leavespeed, float time)
{
	Call_StartForward(H_Forwards_LeaveCheckpoint);
	Call_PushCell(client);
	Call_PushCell(cp);
	Call_PushCell(style);
	Call_PushFloat(leavespeed);
	Call_PushFloat(time);
	Call_Finish();
}

void Call_OnWRCP(int client, int stage, int style, int steamid, int records, float oldtime, float time, float leavespeed, const char[] mapname)
{
	Call_StartForward(H_Forwards_OnWRCP);
	Call_PushCell(client);
	Call_PushCell(stage);
	Call_PushCell(style);
	Call_PushCell(steamid);
	Call_PushCell(records);
	Call_PushFloat(oldtime);
	Call_PushFloat(time);
	Call_PushFloat(leavespeed);
	Call_PushString(mapname);
	Call_Finish();
}

void Call_OnWRCPDeleted(int stage, int style, int steamid, const char[] mapname)
{
	Call_StartForward(H_Forwards_OnWRCPDeleted);
	Call_PushCell(stage);
	Call_PushCell(style);
	Call_PushCell(steamid);
	Call_PushString(mapname);
	Call_Finish();
}

void Call_OnFinishStagePre(int client, int stage, int style, Action &result)
{
	Call_StartForward(H_Forwards_OnFinishStagePre);
	Call_PushCell(client);
	Call_PushCell(stage);
	Call_PushCell(style);
	Call_Finish(result);
}

void Call_OnFinishStage_Post(int client, int stage, int style, float time, float diff, int overwrite, int records, int rank, bool wrcp, float leavespeed)
{
	Call_StartForward(H_Forwards_OnFinishStage_Post);
	Call_PushCell(client);
	Call_PushCell(stage);
	Call_PushCell(style);
	Call_PushFloat(time);
	Call_PushFloat(diff);
	Call_PushCell(overwrite);
	Call_PushCell(records);
	Call_PushCell(rank);
	Call_PushCell(wrcp);
	Call_PushFloat(leavespeed);
	Call_Finish();
}

void Call_OnFinishCheckpointPre(int client, int cpnum, int style, Action &result)
{
	Call_StartForward(H_Forwards_OnFinishCheckpointPre);
	Call_PushCell(client);
	Call_PushCell(cpnum);
	Call_PushCell(style);
	Call_Finish(result);
}

void Call_OnFinishCheckpoint(int client, int cpnum, int style, float time, float wrdiff, float pbdiff, float enterspeed)
{
	Call_StartForward(H_Forwards_OnFinishCheckpoint);
	Call_PushCell(client);
	Call_PushCell(cpnum);
	Call_PushCell(style);
	Call_PushFloat(time);
	Call_PushFloat(wrdiff);
	Call_PushFloat(pbdiff);
	Call_PushFloat(enterspeed);
	Call_Finish();
}