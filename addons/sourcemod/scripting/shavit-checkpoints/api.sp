static GlobalForward H_Forwards_OnSave = null;
static GlobalForward H_Forwards_OnTeleport = null;
static GlobalForward H_Forwards_OnDelete = null;
static GlobalForward H_Forwards_OnCheckpointMenuMade = null;
static GlobalForward H_Forwards_OnCheckpointMenuSelect = null;



// ======[ NATIVES ]======

void CreateNatives()
{
	CreateNative("Shavit_GetCheckpoint", Native_GetCheckpoint);
	CreateNative("Shavit_SetCheckpoint", Native_SetCheckpoint);
	CreateNative("Shavit_ClearCheckpoints", Native_ClearCheckpoints);
	CreateNative("Shavit_TeleportToCheckpoint", Native_TeleportToCheckpoint);
	CreateNative("Shavit_GetTotalCheckpoints", Native_GetTotalCheckpoints);
	CreateNative("Shavit_OpenCheckpointMenu", Native_OpenCheckpointMenu);
	CreateNative("Shavit_SaveCheckpoint", Native_SaveCheckpoint);
	CreateNative("Shavit_GetCurrentCheckpoint", Native_GetCurrentCheckpoint);
	CreateNative("Shavit_SetCurrentCheckpoint", Native_SetCurrentCheckpoint);
	CreateNative("Shavit_GetTimesTeleported", Native_GetTimesTeleported);
	CreateNative("Shavit_HasSavestate", Native_HasSavestate);
}

public any Native_GetCheckpoint(Handle plugin, int numParams)
{
	if(GetNativeCell(4) != sizeof(cp_cache_t))
	{
		return ThrowNativeError(200, "cp_cache_t does not match latest(got %i expected %i). Please update your includes and recompile your plugins",
			GetNativeCell(4), sizeof(cp_cache_t));
	}

	int client = GetNativeCell(1);
	int index = GetNativeCell(2);

	cp_cache_t cpcache;
	if(gA_Checkpoints[client].GetArray(index-1, cpcache, sizeof(cp_cache_t)))
	{
		SetNativeArray(3, cpcache, sizeof(cp_cache_t));
		return true;
	}

	return false;
}

public any Native_SetCheckpoint(Handle plugin, int numParams)
{
	if(GetNativeCell(4) != sizeof(cp_cache_t))
	{
		return ThrowNativeError(200, "cp_cache_t does not match latest(got %i expected %i). Please update your includes and recompile your plugins",
			GetNativeCell(4), sizeof(cp_cache_t));
	}

	int client = GetNativeCell(1);
	int position = GetNativeCell(2);

	cp_cache_t cpcache;
	GetNativeArray(3, cpcache, sizeof(cp_cache_t));

	if(position == -1)
	{
		position = gI_CurrentCheckpoint[client];
	}

	DeleteCheckpoint(client, position, true);
	gA_Checkpoints[client].SetArray(position-1, cpcache);
	
	return true;
}

public any Native_ClearCheckpoints(Handle plugin, int numParams)
{
	ResetCheckpoints(GetNativeCell(1));
	return 0;
}

public any Native_TeleportToCheckpoint(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int position = GetNativeCell(2);
	bool suppress = GetNativeCell(3);

	TeleportToCheckpoint(client, position, suppress);
	return 0;
}

public any Native_GetTotalCheckpoints(Handle plugin, int numParams)
{
	return gA_Checkpoints[GetNativeCell(1)].Length;
}

public any Native_OpenCheckpointMenu(Handle plugin, int numParams)
{
	OpenCheckpointsMenu(GetNativeCell(1));
	return 0;
}

public any Native_SaveCheckpoint(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(!CanSegment(client) && gA_Checkpoints[client].Length >= GetMaxCPs(client))
	{
		return -1;
	}

	SaveCheckpoint(client);
	return gI_CurrentCheckpoint[client];
}

public any Native_GetCurrentCheckpoint(Handle plugin, int numParams)
{
	return gI_CurrentCheckpoint[GetNativeCell(1)];
}

public any Native_SetCurrentCheckpoint(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int index = GetNativeCell(2);
	
	gI_CurrentCheckpoint[client] = index;
	return 0;
}

public any Native_GetTimesTeleported(Handle plugin, int numParams)
{
	return gI_TimesTeleported[GetNativeCell(1)];
}

public any Native_HasSavestate(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (gB_SaveStates[client])
	{
		return true;
	}

	persistent_data_t aData;
	int iIndex = FindPersistentData(client, aData);

	if (iIndex != -1)
	{
		gB_SaveStates[client] = true;
	}

	return gB_SaveStates[client];
}



// ======[ FORWARDS ]======

void CreateGlobalForwards()
{
	H_Forwards_OnSave = new GlobalForward("Shavit_OnSave", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	H_Forwards_OnDelete = new GlobalForward("Shavit_OnDelete", ET_Event, Param_Cell, Param_Cell);
	H_Forwards_OnTeleport = new GlobalForward("Shavit_OnTeleport", ET_Event, Param_Cell, Param_Cell);
	H_Forwards_OnCheckpointMenuMade = new GlobalForward("Shavit_OnCheckpointMenuMade", ET_Event, Param_Cell, Param_Cell);
	H_Forwards_OnCheckpointMenuSelect = new GlobalForward("Shavit_OnCheckpointMenuSelect", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell);
}

void Call_OnSave(int client, int index, bool overflow, Action &result)
{
	Call_StartForward(H_Forwards_OnSave);
	Call_PushCell(client);
	Call_PushCell(index);
	Call_PushCell(overflow);
	Call_Finish(result);
}

void Call_OnDelete(int client, int index, Action &result)
{
	Call_StartForward(H_Forwards_OnDelete);
	Call_PushCell(client);
	Call_PushCell(index);
	Call_Finish(result);
}

void Call_OnTeleport(int client, int index, Action &result)
{
	Call_StartForward(H_Forwards_OnTeleport);
	Call_PushCell(client);
	Call_PushCell(index);
	Call_Finish(result);
}

void Call_OnCheckpointMenuMade(int client, bool segmented, Action &result)
{
	Call_StartForward(H_Forwards_OnCheckpointMenuMade);
	Call_PushCell(client);
	Call_PushCell(segmented);
	Call_Finish(result);
}

void Call_OnCheckpointMenuSelect(int client, int param2, char[] info, int maxlength, int currentCheckpoint, int maxCPs, Action &result)
{
	Call_StartForward(H_Forwards_OnCheckpointMenuSelect);
	Call_PushCell(client);
	Call_PushCell(param2);
	Call_PushStringEx(info, maxlength, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(maxlength); 
	Call_PushCell(currentCheckpoint);
	Call_PushCell(maxCPs);
	Call_Finish(result);
}