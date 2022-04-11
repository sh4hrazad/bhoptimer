static GlobalForward H_ShouldSaveReplayCopy = null;
static GlobalForward H_OnReplaySaved = null;
static GlobalForward H_OnStageReplaySaved = null;



// ======[ NATIVE ]======

void CreateNatives()
{
	CreateNative("Shavit_GetClientFrameCount", Native_GetClientFrameCount);
	CreateNative("Shavit_HijackAngles", Native_HijackAngles);
	CreateNative("Shavit_GetReplayData", Native_GetReplayData);
	CreateNative("Shavit_SetReplayData", Native_SetReplayData);
	CreateNative("Shavit_GetPlayerPreFrames", Native_GetPlayerPreFrames);
	CreateNative("Shavit_SetPlayerPreFrames", Native_SetPlayerPreFrames);
	CreateNative("Shavit_GetPlayerStagePreFrames", Native_GetPlayerStagePreFrames);
	CreateNative("Shavit_SetPlayerStagePreFrames", Native_SetPlayerStagePreFrames);
}

public int Native_GetClientFrameCount(Handle handler, int numParams)
{
	return gI_PlayerFrames[GetNativeCell(1)];
}

public int Native_HijackAngles(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	gF_HijackedAngles[client][0] = view_as<float>(GetNativeCell(2));
	gF_HijackedAngles[client][1] = view_as<float>(GetNativeCell(3));

	int ticks = GetNativeCell(4);

	if (ticks == -1)
	{
		float latency = GetClientLatency(client, NetFlow_Both);

		if (latency > 0.0)
		{
			ticks = RoundToCeil(latency / GetTickInterval()) + 1;
			//PrintToChat(client, "%f %f %d", latency, GetTickInterval(), ticks);
			gI_HijackFrames[client] = ticks;
		}
	}
	else
	{
		gI_HijackFrames[client] = ticks;
	}

	gB_HijackFramesKeepOnStart[client] = (numParams < 5) ? false : view_as<bool>(GetNativeCell(5));
	return ticks;
}

public int Native_GetReplayData(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool cheapCloneHandle = view_as<bool>(GetNativeCell(2));
	Handle cloned = null;

	if(gA_PlayerFrames[client] != null)
	{
		ArrayList frames = cheapCloneHandle ? gA_PlayerFrames[client] : gA_PlayerFrames[client].Clone();
		frames.Resize(gI_PlayerFrames[client]);
		cloned = CloneHandle(frames, plugin); // set the calling plugin as the handle owner

		if (!cheapCloneHandle)
		{
			// Only hit for .Clone()'d handles. .Clone() != CloneHandle()
			CloseHandle(frames);
		}
	}

	return view_as<int>(cloned);
}

public int Native_SetReplayData(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	ArrayList data = view_as<ArrayList>(GetNativeCell(2));
	bool cheapCloneHandle = view_as<bool>(GetNativeCell(3));

	if(gB_GrabbingPostFrames_Stage[client])
	{
		FinishGrabbingPostFrames_Stage(client, gA_WRCPRunInfo[client]);
	}

	if(gB_GrabbingPostFrames[client])
	{
		FinishGrabbingPostFrames(client, gA_FinishedRunInfo[client]);
	}

	if(cheapCloneHandle)
	{
		data = view_as<ArrayList>(CloneHandle(data));
	}
	else
	{
		data = data.Clone();
	}

	delete gA_PlayerFrames[client];
	gA_PlayerFrames[client] = data;
	gI_PlayerFrames[client] = data.Length;

	return 0;
}

public int Native_GetPlayerPreFrames(Handle handler, int numParams)
{
	return gI_PlayerPrerunFrames[GetNativeCell(1)];
}

public int Native_SetPlayerPreFrames(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int preframes = GetNativeCell(2);

	gI_PlayerPrerunFrames[client] = preframes;

	return 0;
}

public int Native_GetPlayerStagePreFrames(Handle handler, int numParams)
{
	return gI_PlayerPrerunFrames_Stage[GetNativeCell(1)];
}

public int Native_SetPlayerStagePreFrames(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int preframes = GetNativeCell(2);

	gI_PlayerPrerunFrames_Stage[client] = preframes;

	return 0;
}



// ======[ FORWARDS ]======

void CreateGlobalForwards()
{
	H_ShouldSaveReplayCopy = new GlobalForward("Shavit_ShouldSaveReplayCopy", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	H_OnReplaySaved = new GlobalForward("Shavit_OnReplaySaved", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_String);
	H_OnStageReplaySaved = new GlobalForward("Shavit_OnStageReplaySaved", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
}

void Call_ShouldSaveReplayCopy(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldtime, float avgvel, float maxvel, int timestamp, bool isbestreplay, bool istoolong, Action &result)
{
	Call_StartForward(H_ShouldSaveReplayCopy);
	Call_PushCell(client);
	Call_PushCell(style);
	Call_PushCell(time);
	Call_PushCell(jumps);
	Call_PushCell(strafes);
	Call_PushCell(sync);
	Call_PushCell(track);
	Call_PushCell(oldtime);
	Call_PushCell(avgvel);
	Call_PushCell(maxvel);
	Call_PushCell(timestamp);
	Call_PushCell(isbestreplay);
	Call_PushCell(istoolong);
	Call_Finish(result);
}

void Call_OnReplaySaved(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldtime, float avgvel, float maxvel, int timestamp, bool isbestreplay, bool istoolong, bool iscopy, const char[] replaypath, ArrayList frames, int preframes, int postframes, const char[] name)
{
	Call_StartForward(H_OnReplaySaved);
	Call_PushCell(client);
	Call_PushCell(style);
	Call_PushCell(time);
	Call_PushCell(jumps);
	Call_PushCell(strafes);
	Call_PushCell(sync);
	Call_PushCell(track);
	Call_PushCell(oldtime);
	Call_PushCell(avgvel);
	Call_PushCell(maxvel);
	Call_PushCell(timestamp);
	Call_PushCell(isbestreplay);
	Call_PushCell(istoolong);
	Call_PushCell(iscopy);
	Call_PushString(replaypath);
	Call_PushCell(frames);
	Call_PushCell(preframes);
	Call_PushCell(postframes);
	Call_PushString(name);
	Call_Finish();
}

void Call_OnStageReplaySaved(int client, int stage, int style, float time, int steamid, ArrayList frames, int preframes, int iSize, const char[] name)
{
	Call_StartForward(H_OnStageReplaySaved);
	Call_PushCell(client);
	Call_PushCell(stage);
	Call_PushCell(style);
	Call_PushCell(time);
	Call_PushCell(steamid);
	Call_PushCell(frames);
	Call_PushCell(preframes);
	Call_PushCell(iSize);
	Call_PushString(name);
	Call_Finish();
}