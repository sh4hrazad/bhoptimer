static GlobalForward H_OnWorldRecord = null;
static GlobalForward H_OnFinish_Post = null;
static GlobalForward H_OnWRDeleted = null;
static GlobalForward H_OnWorstRecord = null;
static GlobalForward H_OnFinishMessage = null;
static GlobalForward H_OnWorldRecordsCached = null;



// ======[ NATIVES ]======

void CreateNatives()
{
	CreateNative("Shavit_GetClientPB", Native_GetClientPB);
	CreateNative("Shavit_SetClientPB", Native_SetClientPB);
	CreateNative("Shavit_GetClientCompletions", Native_GetClientCompletions);
	CreateNative("Shavit_GetClientPrestrafe", Native_GetClientPrestrafe);
	CreateNative("Shavit_GetRankForSteamid", Native_GetRankForSteamid);
	CreateNative("Shavit_GetRankForTime", Native_GetRankForTime);
	CreateNative("Shavit_GetRecordAmount", Native_GetRecordAmount);
	CreateNative("Shavit_GetTimeForRank", Native_GetTimeForRank);
	CreateNative("Shavit_GetSteamidForRank", Native_GetSteamidForRank);
	CreateNative("Shavit_GetPrestrafeForRank", Native_GetPrestrafeForRank);
	CreateNative("Shavit_GetWorldRecord", Native_GetWorldRecord);
	CreateNative("Shavit_GetWRName", Native_GetWRName);
	CreateNative("Shavit_GetWRRecordID", Native_GetWRRecordID);
	CreateNative("Shavit_ReloadLeaderboards", Native_ReloadLeaderboards);
	CreateNative("Shavit_WR_DeleteMap", Native_WR_DeleteMap);
	CreateNative("Shavit_DeleteWR", Native_DeleteWR);
}

public any Native_GetClientPB(Handle handler, int numParams)
{
	return gF_PlayerRecord[GetNativeCell(1)][GetNativeCell(2)][GetNativeCell(3)];
}

public int Native_SetClientPB(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int style = GetNativeCell(2);
	int track = GetNativeCell(3);
	float time = GetNativeCell(4);

	gF_PlayerRecord[client][style][track] = time;

	return 0;
}

public int Native_GetClientCompletions(Handle handler, int numParams)
{
	return gI_PlayerCompletion[GetNativeCell(1)][GetNativeCell(2)][GetNativeCell(3)];
}

public any Native_GetClientPrestrafe(Handle handler, int numParams)
{
	return gF_PlayerPrestrafe[GetNativeCell(1)][GetNativeCell(2)][GetNativeCell(3)];
}

public int Native_GetRankForSteamid(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int track = GetNativeCell(3);

	if(gA_Leaderboard[style][track] == null || gA_Leaderboard[style][track].Length == 0)
	{
		return 0;
	}

	return GetRankForSteamid(style, GetNativeCell(2), track);
}

public int Native_GetRankForTime(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int track = GetNativeCell(3);

	if(gA_Leaderboard[style][track] == null || gA_Leaderboard[style][track].Length == 0)
	{
		return 1;
	}

	return GetRankForTime(style, GetNativeCell(2), track);
}

public int Native_GetRecordAmount(Handle handler, int numParams)
{
	return GetRecordAmount(GetNativeCell(1), GetNativeCell(2));
}

public int Native_GetTimeForRank(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int rank = GetNativeCell(2);
	int track = GetNativeCell(3);

	#if defined DEBUG
	Shavit_PrintToChatAll("style %d | rank %d | track %d | amount %d", style, rank, track, GetRecordAmount(style, track));
	#endif

	if(rank > GetRecordAmount(style, track))
	{
		return view_as<int>(0.0);
	}

	prcache_t pr;
	gA_Leaderboard[style][track].GetArray(rank - 1, pr, sizeof(pr));

	return view_as<int>(pr.fTime);
}

public int Native_GetSteamidForRank(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int rank = GetNativeCell(2);
	int track = GetNativeCell(3);

	if(rank > GetRecordAmount(style, track))
	{
		return -1;
	}

	prcache_t pr;
	gA_Leaderboard[style][track].GetArray(rank - 1, pr, sizeof(pr));

	return pr.iSteamid;
}

public any Native_GetPrestrafeForRank(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int rank = GetNativeCell(2);
	int track = GetNativeCell(3);

	if(rank > GetRecordAmount(style, track))
	{
		return 0.0;
	}

	prcache_t pr;
	gA_Leaderboard[style][track].GetArray(rank - 1, pr, sizeof(pr));

	return pr.fPrestrafe;
}

public int Native_GetWorldRecord(Handle handler, int numParams)
{
	return view_as<int>(gF_WRTime[GetNativeCell(1)][GetNativeCell(2)]);
}

public int Native_GetWRName(Handle handler, int numParams)
{
	int iSteamID = gI_WRSteamID[GetNativeCell(1)][GetNativeCell(4)];
	char sName[MAX_NAME_LENGTH];

	if (iSteamID != 0)
	{
		char sSteamID[20];
		IntToString(iSteamID, sSteamID, sizeof(sSteamID));

		if (gSM_WRNames.GetString(sSteamID, sName, sizeof(sName)))
		{
			SetNativeString(2, sName, GetNativeCell(3));
			return 0;
		}
	}

	SetNativeString(2, "invalid", GetNativeCell(3));
	return 0;
}

public int Native_GetWRRecordID(Handle handler, int numParams)
{
	SetNativeCellRef(2, gI_WRRecordID[GetNativeCell(1)][GetNativeCell(3)]);

	return 0;
}

public int Native_ReloadLeaderboards(Handle handler, int numParams)
{
	UpdateWRCache();

	return 0;
}

public int Native_WR_DeleteMap(Handle handler, int numParams)
{
	char sMap[PLATFORM_MAX_PATH];
	GetNativeString(1, sMap, sizeof(sMap));
	LowercaseString(sMap);

	DB_DeleteMapAllRecords(sMap);

	return 0;
}

public int Native_DeleteWR(Handle handle, int numParams)
{
	int style = GetNativeCell(1);
	int track = GetNativeCell(2);
	char map[PLATFORM_MAX_PATH];
	GetNativeString(3, map, sizeof(map));
	LowercaseString(map);
	int steamid = GetNativeCell(4);
	int recordid = GetNativeCell(5);
	bool delete_sql = view_as<bool>(GetNativeCell(6));
	bool update_cache = view_as<bool>(GetNativeCell(7));

	DB_DeleteWR(style, track, map, steamid, recordid, delete_sql, update_cache);

	return 0;
}



// ======[ FORWARDS ]======

void CreateGlobalForwards()
{
	H_OnWorldRecord = new GlobalForward("Shavit_OnWorldRecord", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	H_OnFinish_Post = new GlobalForward("Shavit_OnFinish_Post", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	H_OnWRDeleted = new GlobalForward("Shavit_OnWRDeleted", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	H_OnWorstRecord = new GlobalForward("Shavit_OnWorstRecord", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	H_OnFinishMessage = new GlobalForward("Shavit_OnFinishMessage", ET_Event, Param_Cell, Param_CellByRef, Param_Array, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell);
	H_OnWorldRecordsCached = new GlobalForward("Shavit_OnWorldRecordsCached", ET_Ignore);
}

void Call_OnWorldRecord(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldwr, float oldtime, float avgvel, float maxvel, int timestamp)
{
	Call_StartForward(H_OnWorldRecord);
	Call_PushCell(client);
	Call_PushCell(style);
	Call_PushCell(time);
	Call_PushCell(jumps);
	Call_PushCell(strafes);
	Call_PushCell(sync);
	Call_PushCell(track);
	Call_PushCell(oldwr);
	Call_PushCell(oldtime);
	Call_PushCell(avgvel);
	Call_PushCell(maxvel);
	Call_PushCell(timestamp);
	Call_Finish();
}

void Call_OnFinish_Post(int client, int style, float time, int jumps, int strafes, float sync, int rank, int overwrite, int track, float oldtime, float avgvel, float maxvel, int timestamp)
{
	Call_StartForward(H_OnFinish_Post);
	Call_PushCell(client);
	Call_PushCell(style);
	Call_PushCell(time);
	Call_PushCell(jumps);
	Call_PushCell(strafes);
	Call_PushCell(sync);
	Call_PushCell(rank);
	Call_PushCell(overwrite);
	Call_PushCell(track);
	Call_PushCell(oldtime);
	Call_PushCell(avgvel);
	Call_PushCell(maxvel);
	Call_PushCell(timestamp);
	Call_Finish();
}

void Call_OnWRDeleted(int style, int id, int track, int accountid, const char[] mapname)
{
	Call_StartForward(H_OnWRDeleted);
	Call_PushCell(style);
	Call_PushCell(id);
	Call_PushCell(track);
	Call_PushCell(accountid);
	Call_PushString(mapname);
	Call_Finish();
}

void Call_OnWorstRecord(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldtime, float avgvel, float maxvel, int timestamp)
{
	Call_StartForward(H_OnWorstRecord);
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
	Call_Finish();
}

void Call_OnFinishMessage(int client, bool &everyone, timer_snapshot_t snapshot, int overwrite, int rank, char[] message, int maxlen, char[] message2, int maxlen2, Action &result)
{
	Call_StartForward(H_OnFinishMessage);
	Call_PushCell(client);
	Call_PushCellRef(everyone);
	Call_PushArrayEx(snapshot, sizeof(timer_snapshot_t), SM_PARAM_COPYBACK);
	Call_PushCell(overwrite);
	Call_PushCell(rank);
	Call_PushStringEx(message, maxlen, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(maxlen);
	Call_PushStringEx(message2, maxlen2, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(maxlen2);
	Call_Finish(result);
}

void Call_OnWorldRecordsCached()
{
	Call_StartForward(H_OnWorldRecordsCached);
	Call_Finish();
}