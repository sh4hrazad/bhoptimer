static GlobalForward H_Forwards_OnTierAssigned = null;
static GlobalForward H_Forwards_OnRankAssigned = null;



// =====[ NATIVES ]=====

void CreateNatives()
{
	CreateNative("Shavit_GetMapTier", Native_GetMapTier);
	CreateNative("Shavit_GetMapTiers", Native_GetMapTiers);
	CreateNative("Shavit_GetMapLimitspeed", Native_GetMapLimitspeed);
	CreateNative("Shavit_GetMapMaxvelocity", Native_GetMapMaxvelocity);
	CreateNative("Shavit_GetPoints", Native_GetPoints);
	CreateNative("Shavit_GetRank", Native_GetRank);
	CreateNative("Shavit_GetRankedPlayers", Native_GetRankedPlayers);
	CreateNative("Shavit_Rankings_DeleteMap", Native_Rankings_DeleteMap);
	CreateNative("Shavit_GetWRCount", Native_GetWRCount);
	CreateNative("Shavit_GetWRHolders", Native_GetWRHolders);
	CreateNative("Shavit_GetWRHolderRank", Native_GetWRHolderRank);
	CreateNative("Shavit_GuessPointsForTime", Native_GuessPointsForTime);
}

public int Native_GetMapTier(Handle handler, int numParams)
{
	int tier = 0;
	char sMap[PLATFORM_MAX_PATH];
	GetNativeString(1, sMap, sizeof(sMap));

	if (!sMap[0])
	{
		return gI_Tier;
	}

	gA_MapTiers.GetValue(sMap, tier);
	return tier;
}

public int Native_GetMapTiers(Handle handler, int numParams)
{
	return view_as<int>(CloneHandle(gA_MapTiers, handler));
}

public int Native_GetMapLimitspeed(Handle handler, int numParams)
{
	return gB_Maplimitspeed;
}

public int Native_GetMapMaxvelocity(Handle handler, int numParams)
{
	return view_as<int>(gF_Maxvelocity);
}

public int Native_GetPoints(Handle handler, int numParams)
{
	return view_as<int>(gA_Rankings[GetNativeCell(1)].fPoints);
}

public int Native_GetRank(Handle handler, int numParams)
{
	return gA_Rankings[GetNativeCell(1)].iRank;
}

public int Native_GetRankedPlayers(Handle handler, int numParams)
{
	return gI_RankedPlayers;
}

public int Native_Rankings_DeleteMap(Handle handler, int numParams)
{
	char sMap[PLATFORM_MAX_PATH];
	GetNativeString(1, sMap, sizeof(sMap));
	LowercaseString(sMap);

	DB_DeleteMapAllSettings(sMap);

	return 0;
}

public int Native_GetWRCount(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int track = GetNativeCell(2);
	int style = GetNativeCell(3);
	bool usecvars = view_as<bool>(GetNativeCell(4));

	if (usecvars)
	{
		return gA_Rankings[client].iWRAmountCvar;
	}
	else if (track == -1 && style == -1)
	{
		return gA_Rankings[client].iWRAmountAll;
	}

	if (track > Track_Bonus)
	{
		track = Track_Bonus;
	}

	return gA_Rankings[client].iWRAmount[STYLE_LIMIT*track + style];
}

public int Native_GetWRHolders(Handle handler, int numParams)
{
	int track = GetNativeCell(1);
	int style = GetNativeCell(2);
	bool usecvars = view_as<bool>(GetNativeCell(3));

	if (usecvars)
	{
		return gI_WRHoldersCvar;
	}
	else if (track == -1 && style == -1)
	{
		return gI_WRHoldersAll;
	}

	if (track > Track_Bonus)
	{
		track = Track_Bonus;
	}

	return gI_WRHolders[track][style];
}

public int Native_GetWRHolderRank(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int track = GetNativeCell(2);
	int style = GetNativeCell(3);
	bool usecvars = view_as<bool>(GetNativeCell(4));

	if (usecvars)
	{
		return gA_Rankings[client].iWRHolderRankCvar;
	}
	else if (track == -1 && style == -1)
	{
		return gA_Rankings[client].iWRHolderRankAll;
	}

	if (track > Track_Bonus)
	{
		track = Track_Bonus;
	}

	return gA_Rankings[client].iWRHolderRank[STYLE_LIMIT*track + style];
}

public int Native_GuessPointsForTime(Handle plugin, int numParams)
{
	int rtrack = GetNativeCell(1);
	int rstyle = GetNativeCell(2);
	int tier = GetNativeCell(3);
	float rtime = view_as<float>(GetNativeCell(4));
	float pwr = view_as<float>(GetNativeCell(5));

	float ppoints = Sourcepawn_GetRecordPoints(
		rtrack,
		rtime,
		gCV_PointsPerTier.FloatValue,
		Shavit_GetStyleSettingFloat(rstyle, "rankingmultiplier"),
		pwr,
		tier == -1 ? gI_Tier : tier
	);

	return view_as<int>(ppoints);
}



// =====[ FORWARDS ]=====

void CreateGlobalForwards()
{
	H_Forwards_OnTierAssigned = new GlobalForward("Shavit_OnTierAssigned", ET_Event, Param_String, Param_Cell);
	H_Forwards_OnRankAssigned = new GlobalForward("Shavit_OnRankAssigned", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
}

void Call_OnTierAssigned(const char[] map, int tier)
{
	Call_StartForward(H_Forwards_OnTierAssigned);
	Call_PushString(map);
	Call_PushCell(tier);
	Call_Finish();
}

void Call_OnRankAssigned(int client, int rank, float points, bool first)
{
	Call_StartForward(H_Forwards_OnRankAssigned);
	Call_PushCell(client);
	Call_PushCell(rank);
	Call_PushCell(points);
	Call_PushCell(first);
	Call_Finish();
}