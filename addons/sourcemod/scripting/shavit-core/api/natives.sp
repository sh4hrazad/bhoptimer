static bool gB_StopChatSound = false;

void CreateNatives()
{
        CreateNative("Shavit_CanPause", Native_CanPause);
	CreateNative("Shavit_ChangeClientStyle", Native_ChangeClientStyle);
	CreateNative("Shavit_FinishMap", Native_FinishMap);
	CreateNative("Shavit_GetBhopStyle", Native_GetBhopStyle);
	CreateNative("Shavit_GetChatStrings", Native_GetChatStrings);
	CreateNative("Shavit_GetChatStringsStruct", Native_GetChatStringsStruct);
	CreateNative("Shavit_GetClientJumps", Native_GetClientJumps);
	CreateNative("Shavit_GetClientTime", Native_GetClientTime);
	CreateNative("Shavit_GetClientTrack", Native_GetClientTrack);
	CreateNative("Shavit_GetDatabase", Native_GetDatabase);
	CreateNative("Shavit_GetOrderedStyles", Native_GetOrderedStyles);
	CreateNative("Shavit_GetStrafeCount", Native_GetStrafeCount);
	CreateNative("Shavit_GetStyleCount", Native_GetStyleCount);
	CreateNative("Shavit_GetStyleSetting", Native_GetStyleSetting);
	CreateNative("Shavit_GetStyleSettingInt", Native_GetStyleSettingInt);
	CreateNative("Shavit_GetStyleSettingBool", Native_GetStyleSettingBool);
	CreateNative("Shavit_GetStyleSettingFloat", Native_GetStyleSettingFloat);
	CreateNative("Shavit_HasStyleSetting", Native_HasStyleSetting);
	CreateNative("Shavit_GetStyleStrings", Native_GetStyleStrings);
	CreateNative("Shavit_GetStyleStringsStruct", Native_GetStyleStringsStruct);
	CreateNative("Shavit_GetSync", Native_GetSync);
	CreateNative("Shavit_GetZoneOffset", Native_GetZoneOffset);
	CreateNative("Shavit_GetDistanceOffset", Native_GetDistanceOffset);
	CreateNative("Shavit_GetTimerStatus", Native_GetTimerStatus);
	CreateNative("Shavit_HasStyleAccess", Native_HasStyleAccess);
	CreateNative("Shavit_IsPaused", Native_IsPaused);
	CreateNative("Shavit_IsPracticeMode", Native_IsPracticeMode);
	CreateNative("Shavit_LoadSnapshot", Native_LoadSnapshot);
	CreateNative("Shavit_LogMessage", Native_LogMessage);
	CreateNative("Shavit_PauseTimer", Native_PauseTimer);
	CreateNative("Shavit_PrintToChat", Native_PrintToChat);
	CreateNative("Shavit_PrintToChatAll", Native_PrintToChatAll);
	CreateNative("Shavit_RestartTimer", Native_RestartTimer);
	CreateNative("Shavit_ResumeTimer", Native_ResumeTimer);
	CreateNative("Shavit_SaveSnapshot", Native_SaveSnapshot);
	CreateNative("Shavit_SetPracticeMode", Native_SetPracticeMode);
	CreateNative("Shavit_SetStyleSetting", Native_SetStyleSetting);
	CreateNative("Shavit_SetStyleSettingFloat", Native_SetStyleSettingFloat);
	CreateNative("Shavit_SetStyleSettingBool", Native_SetStyleSettingBool);
	CreateNative("Shavit_SetStyleSettingInt", Native_SetStyleSettingInt);
	CreateNative("Shavit_StartTimer", Native_StartTimer);
	CreateNative("Shavit_StopChatSound", Native_StopChatSound);
	CreateNative("Shavit_StopTimer", Native_StopTimer);
	CreateNative("Shavit_GetClientTimescale", Native_GetClientTimescale);
	CreateNative("Shavit_SetClientTimescale", Native_SetClientTimescale);
	CreateNative("Shavit_GetAvgVelocity", Native_GetAvgVelocity);
	CreateNative("Shavit_GetMaxVelocity", Native_GetMaxVelocity);
	CreateNative("Shavit_SetAvgVelocity", Native_SetAvgVelocity);
	CreateNative("Shavit_SetMaxVelocity", Native_SetMaxVelocity);
	CreateNative("Shavit_UpdateLaggedMovement", Native_UpdateLaggedMovement);
	CreateNative("Shavit_GetCurrentStage", Native_GetCurrentStage);
	CreateNative("Shavit_GetCurrentCP", Native_GetCurrentCP);
	CreateNative("Shavit_GetLastStage", Native_GetLastStage);
	CreateNative("Shavit_GetLastCP", Native_GetLastCP);
	CreateNative("Shavit_SetCurrentStage", Native_SetCurrentStage);
	CreateNative("Shavit_SetCurrentCP", Native_SetCurrentCP);
	CreateNative("Shavit_SetLastStage", Native_SetLastStage);
	CreateNative("Shavit_SetLastCP", Native_SetLastCP);
	CreateNative("Shavit_IsStageTimer", Native_IsStageTimer);
	CreateNative("Shavit_SetStageTimer", Native_SetStageTimer);
	CreateNative("Shavit_GetLeaveStageTime", Native_GetLeaveStageTime);
	CreateNative("Shavit_SetLeaveStageTime", Native_SetLeaveStageTime);
	CreateNative("Shavit_IsTeleporting", Native_IsTeleporting);
}

public int Native_CanPause(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int iFlags = 0;

	if(!gCV_Pause.BoolValue)
	{
		iFlags |= CPR_ByConVar;
	}

	if (!gA_Timers[client].bTimerEnabled)
	{
		iFlags |= CPR_NoTimer;
	}

	if (Shavit_InsideZone(client, Zone_Start, gA_Timers[client].iTimerTrack) && !gA_Timers[client].bClientPaused)
	{
		iFlags |= CPR_InStartZone;
	}

	if (Shavit_InsideZone(client, Zone_End, gA_Timers[client].iTimerTrack) && !gA_Timers[client].bClientPaused)
	{
		iFlags |= CPR_InEndZone;
	}

	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1 && GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		iFlags |= CPR_NotOnGround;
	}

	float vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	if (vel[0] != 0.0 || vel[1] != 0.0 || vel[2] != 0.0)
	{
		iFlags |= CPR_Moving;
	}

	bool bDucked = view_as<bool>(GetEntProp(client, Prop_Send, "m_bDucked"));
	bool bDucking = view_as<bool>(GetEntProp(client, Prop_Send, "m_bDucking"));

	float fDucktime = GetEntPropFloat(client, Prop_Send, "m_flDucktime");

	if (bDucked || bDucking || fDucktime > 0.0 || GetClientButtons(client) & IN_DUCK)
	{
		iFlags |= CPR_Duck;
	}

	return iFlags;
}

public int Native_ChangeClientStyle(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int style = GetNativeCell(2);
	bool force = view_as<bool>(GetNativeCell(3));
	bool manual = view_as<bool>(GetNativeCell(4));
	bool noforward = view_as<bool>(GetNativeCell(5));

	if(force || Shavit_HasStyleAccess(client, style))
	{
		CallOnStyleChanged(client, gA_Timers[client].bsStyle, style, manual, noforward);

		return true;
	}

	return false;
}

public int Native_FinishMap(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int timestamp = GetTime();

	if(gCV_UseOffsets.BoolValue)
	{
		CalculateTickIntervalOffset(client, Zone_End);
	}

	gA_Timers[client].fCurrentTime = (gA_Timers[client].fTimescaledTicks + gA_Timers[client].fZoneOffset[Zone_Start] + gA_Timers[client].fZoneOffset[Zone_End]) * GetTickInterval();

	timer_snapshot_t snapshot;
	BuildSnapshot(client, snapshot);

	Action result = Plugin_Continue;
	Call_OnFinishPre(client, snapshot, sizeof(timer_snapshot_t), result);

	if(result != Plugin_Continue && result != Plugin_Changed)
	{
		return 0;
	}

	Call_OnFinish(result, client, snapshot, timestamp);

	StopTimer(client);

	return 0;
}

public int Native_GetBhopStyle(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].bsStyle;
}

public int Native_GetChatStrings(Handle handler, int numParams)
{
	int type = GetNativeCell(1);
	int size = GetNativeCell(3);

	switch(type)
	{
		case sMessagePrefix: return SetNativeString(2, gS_ChatStrings.sPrefix, size);
		case sMessageText: return SetNativeString(2, gS_ChatStrings.sText, size);
		case sMessageWarning: return SetNativeString(2, gS_ChatStrings.sWarning, size);
		case sMessageTeam: return SetNativeString(2, gS_ChatStrings.sTeam, size);
		case sMessageStyle: return SetNativeString(2, gS_ChatStrings.sStyle, size);
		case sMessageGood: return SetNativeString(2, gS_ChatStrings.sGood, size);
		case sMessageBad: return SetNativeString(2, gS_ChatStrings.sBad, size);
	}

	return -1;
}

public int Native_GetChatStringsStruct(Handle plugin, int numParams)
{
	if (GetNativeCell(2) != sizeof(chatstrings_t))
	{
		return ThrowNativeError(200, "chatstrings_t does not match latest(got %i expected %i). Please update your includes and recompile your plugins", GetNativeCell(2), sizeof(chatstrings_t));
	}

	return SetNativeArray(1, gS_ChatStrings, sizeof(gS_ChatStrings));
}

public int Native_GetClientJumps(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iJumps;
}

public any Native_GetClientTime(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].fCurrentTime;
}

public int Native_GetClientTrack(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iTimerTrack;
}

public any Native_GetDatabase(Handle handler, int numParams)
{
	return CloneHandle(gH_SQL, handler);
}

public int Native_GetOrderedStyles(Handle handler, int numParams)
{
	return SetNativeArray(1, gI_OrderedStyles, GetNativeCell(2));
}

public int Native_GetStrafeCount(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iStrafes;
}

public int Native_GetStyleCount(Handle handler, int numParams)
{
	return (gI_Styles > 0)? gI_Styles:-1;
}

public int Native_GetStyleSetting(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	int maxlength = GetNativeCell(4);

	char sValue[256];
	bool ret = gSM_StyleKeys[style].GetString(sKey, sValue, maxlength);

	SetNativeString(3, sValue, maxlength);
	return ret;
}

public int Native_GetStyleSettingInt(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	return GetStyleSettingInt(style, sKey);
}

public int Native_GetStyleSettingBool(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	return GetStyleSettingBool(style, sKey);
}

public any Native_GetStyleSettingFloat(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	return GetStyleSettingFloat(style, sKey);
}

public any Native_HasStyleSetting(Handle handler, int numParams)
{
	// TODO: replace with sm 1.11 StringMap.ContainsKey
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	return HasStyleSetting(style, sKey);
}

public int Native_GetStyleStrings(Handle handler, int numParams)
{
	int style = GetNativeCell(1);
	int type = GetNativeCell(2);
	int size = GetNativeCell(4);
	char sValue[128];

	switch(type)
	{
		case sStyleName:
		{
			gSM_StyleKeys[style].GetString("name", sValue, size);
		}
		case sShortName:
		{
			gSM_StyleKeys[style].GetString("shortname", sValue, size);
		}
		case sHTMLColor:
		{
			gSM_StyleKeys[style].GetString("htmlcolor", sValue, size);
		}
		case sChangeCommand:
		{
			gSM_StyleKeys[style].GetString("command", sValue, size);
		}
		case sClanTag:
		{
			gSM_StyleKeys[style].GetString("clantag", sValue, size);
		}
		case sSpecialString:
		{
			gSM_StyleKeys[style].GetString("specialstring", sValue, size);
		}
		case sStylePermission:
		{
			gSM_StyleKeys[style].GetString("permission", sValue, size);
		}
		default:
		{
			return -1;
		}
	}

	return SetNativeString(3, sValue, size);
}

public int Native_GetStyleStringsStruct(Handle plugin, int numParams)
{
	int style = GetNativeCell(1);

	if (GetNativeCell(3) != sizeof(stylestrings_t))
	{
		return ThrowNativeError(200, "stylestrings_t does not match latest(got %i expected %i). Please update your includes and recompile your plugins", GetNativeCell(3), sizeof(stylestrings_t));
	}

	stylestrings_t strings;
	gSM_StyleKeys[style].GetString("name", strings.sStyleName, sizeof(strings.sStyleName));
	gSM_StyleKeys[style].GetString("shortname", strings.sShortName, sizeof(strings.sShortName));
	gSM_StyleKeys[style].GetString("htmlcolor", strings.sHTMLColor, sizeof(strings.sHTMLColor));
	gSM_StyleKeys[style].GetString("command", strings.sChangeCommand, sizeof(strings.sChangeCommand));
	gSM_StyleKeys[style].GetString("clantag", strings.sClanTag, sizeof(strings.sClanTag));
	gSM_StyleKeys[style].GetString("specialstring", strings.sSpecialString, sizeof(strings.sSpecialString));
	gSM_StyleKeys[style].GetString("permission", strings.sStylePermission, sizeof(strings.sStylePermission));

	return SetNativeArray(2, strings, sizeof(stylestrings_t));
}

public any Native_GetSync(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	return (GetStyleSettingBool(gA_Timers[client].bsStyle, "sync")? (gA_Timers[client].iGoodGains == 0)? 0.0:(gA_Timers[client].iGoodGains / float(gA_Timers[client].iTotalMeasures) * 100.0):-1.0);
}

public any Native_GetZoneOffset(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int zonetype = GetNativeCell(2);

	if(zonetype > 1 || zonetype < 0)
	{
		return ThrowNativeError(32, "ZoneType is out of bounds");
	}

	return gA_Timers[client].fZoneOffset[zonetype];
}

public any Native_GetDistanceOffset(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int zonetype = GetNativeCell(2);

	if(zonetype > 1 || zonetype < 0)
	{
		return ThrowNativeError(32, "ZoneType is out of bounds");
	}

	return gA_Timers[client].fDistanceOffset[zonetype];
}

public any Native_GetTimerStatus(Handle handler, int numParams)
{
	return GetTimerStatus(GetNativeCell(1));
}

public int Native_HasStyleAccess(Handle handler, int numParams)
{
	int style = GetNativeCell(2);

	if(GetStyleSettingBool(style, "inaccessible") || GetStyleSettingInt(style, "enabled") <= 0)
	{
		return false;
	}

	return CheckCommandAccess(GetNativeCell(1), (strlen(gS_StyleOverride[style]) > 0)? gS_StyleOverride[style]:"<none>", gI_StyleFlag[style]);
}

public any Native_IsPaused(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].bClientPaused;
}

public int Native_IsPracticeMode(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].bPracticeMode;
}

public int Native_LoadSnapshot(Handle handler, int numParams)
{
	if(GetNativeCell(3) != sizeof(timer_snapshot_t))
	{
		return ThrowNativeError(200, "timer_snapshot_t does not match latest(got %i expected %i). Please update your includes and recompile your plugins",
			GetNativeCell(3), sizeof(timer_snapshot_t));
	}

	int client = GetNativeCell(1);

	timer_snapshot_t snapshot;
	GetNativeArray(2, snapshot, sizeof(timer_snapshot_t));

	if (gA_Timers[client].iTimerTrack != snapshot.iTimerTrack)
	{
		Call_OnTrackChanged(client, gA_Timers[client].iTimerTrack, snapshot.iTimerTrack);
	}

	gA_Timers[client].iTimerTrack = snapshot.iTimerTrack;

	if (gA_Timers[client].bsStyle != snapshot.bsStyle && Shavit_HasStyleAccess(client, snapshot.bsStyle))
	{
		CallOnStyleChanged(client, gA_Timers[client].bsStyle, snapshot.bsStyle, false);
	}

	gA_Timers[client] = snapshot;
	gA_Timers[client].bClientPaused = snapshot.bClientPaused && snapshot.bTimerEnabled;
	gA_Timers[client].fTimescale = (snapshot.fTimescale > 0.0) ? snapshot.fTimescale : 1.0;

	return 0;
}

public int Native_LogMessage(Handle plugin, int numParams)
{
	char sPlugin[32];

	if(!GetPluginInfo(plugin, PlInfo_Name, sPlugin, 32))
	{
		GetPluginFilename(plugin, sPlugin, 32);
	}

	static int iWritten = 0;

	char sBuffer[300];
	FormatNativeString(0, 1, 2, 300, iWritten, sBuffer);

	LogToFileEx(gS_LogPath, "[%s] %s", sPlugin, sBuffer);

	return 0;
}

public int Native_PauseTimer(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	GetPauseMovement(client);
	PauseTimer(client);

	return 0;
}

public int Native_PrintToChat(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	return SemiNative_PrintToChat(client, 2);
}

public int Native_PrintToChatAll(Handle plugin, int numParams)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			SetGlobalTransTarget(i);

			bool previousStopChatSound = gB_StopChatSound;
			SemiNative_PrintToChat(i, 1);
			gB_StopChatSound = previousStopChatSound;
		}
	}

	gB_StopChatSound = false;

	return 0;
}

public int SemiNative_PrintToChat(int client, int formatParam)
{
	int iWritten;
	char sBuffer[256];
	char sInput[300];
	FormatNativeString(0, formatParam, formatParam+1, sizeof(sInput), iWritten, sInput);

	char sTime[50];

	if (gCV_TimeInMessages.BoolValue)
	{
		FormatTime(sTime, sizeof(sTime), gB_Protobuf ? "%H:%M:%S " : "\x01%H:%M:%S ");
	}

	// space before message needed show colors in cs:go
	// strlen(sBuffer)>252 is when CSS stops printing the messages
	FormatEx(sBuffer, (gB_Protobuf ? sizeof(sBuffer) : 253), "%s%s%s%s%s%s", (gB_Protobuf ? " ":""), sTime, gS_ChatStrings.sPrefix, (gS_ChatStrings.sPrefix[0] != 0 ? " " : ""), gS_ChatStrings.sText, sInput);
	ReplaceColors(sBuffer, sizeof(sBuffer));
	
	if(client == 0)
	{
		PrintToServer("%s", sBuffer);

		return false;
	}

	if(!IsClientInGame(client))
	{
		gB_StopChatSound = false;

		return false;
	}

	Handle hSayText2 = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);

	if(gB_Protobuf)
	{
		Protobuf pbmsg = UserMessageToProtobuf(hSayText2);
		pbmsg.SetInt("ent_idx", client);
		pbmsg.SetBool("chat", !(gB_StopChatSound || gCV_NoChatSound.BoolValue));
		pbmsg.SetString("msg_name", sBuffer);

		// needed to not crash
		for(int i = 1; i <= 4; i++)
		{
			pbmsg.AddString("params", "");
		}
	}
	else
	{
		BfWrite bfmsg = UserMessageToBfWrite(hSayText2);
		bfmsg.WriteByte(client);
		bfmsg.WriteByte(!(gB_StopChatSound || gCV_NoChatSound.BoolValue));
		bfmsg.WriteString(sBuffer);
	}

	EndMessage();

	gB_StopChatSound = false;

	return true;
}

public int Native_RestartTimer(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int track = GetNativeCell(2);

	RestartTimer(client, track);

	return 0;
}

public int Native_ResumeTimer(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	ResumeTimer(client);

	if(numParams >= 2 && view_as<bool>(GetNativeCell(2))) // teleport?
	{
		ResumePauseMovement(client);
	}

	return 0;
}

public int Native_SaveSnapshot(Handle handler, int numParams)
{
	if(GetNativeCell(3) != sizeof(timer_snapshot_t))
	{
		return ThrowNativeError(200, "timer_snapshot_t does not match latest(got %i expected %i). Please update your includes and recompile your plugins",
			GetNativeCell(3), sizeof(timer_snapshot_t));
	}

	int client = GetNativeCell(1);

	timer_snapshot_t snapshot;
	BuildSnapshot(client, snapshot);
	return SetNativeArray(2, snapshot, sizeof(timer_snapshot_t));
}

public int Native_SetPracticeMode(Handle handler, int numParams)
{
	gA_Timers[GetNativeCell(1)].bPracticeMode = view_as<bool>(GetNativeCell(2));

	return 0;
}

public any Native_SetStyleSetting(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	char sValue[256];
	GetNativeString(3, sValue, 256);

	bool replace = GetNativeCell(4);

	return gSM_StyleKeys[style].SetString(sKey, sValue, replace);
}

public any Native_SetStyleSettingFloat(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	float fValue = GetNativeCell(3);

	char sValue[16];
	FloatToString(fValue, sValue, 16);

	bool replace = GetNativeCell(4);

	return gSM_StyleKeys[style].SetString(sKey, sValue, replace);
}

public any Native_SetStyleSettingBool(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	bool value = GetNativeCell(3);

	bool replace = GetNativeCell(4);

	return gSM_StyleKeys[style].SetString(sKey, value ? "1" : "0", replace);
}

public any Native_SetStyleSettingInt(Handle handler, int numParams)
{
	int style = GetNativeCell(1);

	char sKey[256];
	GetNativeString(2, sKey, 256);

	int value = GetNativeCell(3);

	char sValue[16];
	IntToString(value, sValue, 16);

	bool replace = GetNativeCell(4);

	return gSM_StyleKeys[style].SetString(sKey, sValue, replace);
}

public int Native_StartTimer(Handle handler, int numParams)
{
	StartTimer(GetNativeCell(1), GetNativeCell(2));
	return 0;
}

public int Native_StopChatSound(Handle handler, int numParams)
{
	gB_StopChatSound = true;

	return 0;
}

public int Native_StopTimer(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	bool bBypass = (numParams < 2 || view_as<bool>(GetNativeCell(2)));
	bool bResult = true;

	if(!bBypass)
	{
		Call_OnStopPre(client, gA_Timers[client].iTimerTrack, bResult);

		if(!bResult)
		{
			return false;
		}
	}

	StopTimer(client);

	Call_OnStop(client, gA_Timers[client].iTimerTrack, bResult);

	return true;
}

public any Native_GetClientTimescale(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	return gA_Timers[client].fTimescale;
}

public int Native_SetClientTimescale(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	float timescale = GetNativeCell(2);

	timescale = float(RoundFloat((timescale * 10000.0)))/10000.0;

	if (timescale != gA_Timers[client].fTimescale && timescale > 0.0)
	{
		Call_OnTimescaleChanged(client, gA_Timers[client].fTimescale, timescale);
		UpdateLaggedMovement(client, true);
	}

	return 0;
}

public any Native_GetAvgVelocity(Handle plugin, int numParams)
{
	return gA_Timers[GetNativeCell(1)].fAvgVelocity;
}

public any Native_GetMaxVelocity(Handle plugin, int numParams)
{
	return gA_Timers[GetNativeCell(1)].fMaxVelocity;
}

public int Native_SetAvgVelocity(Handle plugin, int numParams)
{
	gA_Timers[GetNativeCell(1)].fAvgVelocity = GetNativeCell(2);

	return 0;
}

public int Native_SetMaxVelocity(Handle plugin, int numParams)
{
	gA_Timers[GetNativeCell(1)].fMaxVelocity = GetNativeCell(2);

	return 0;
}

public any Native_UpdateLaggedMovement(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	bool user_timescale = GetNativeCell(2) != 0;
	UpdateLaggedMovement(client, user_timescale);
	return 1;
}

public int Native_GetCurrentStage(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iCurrentStage;
}

public int Native_GetCurrentCP(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iCurrentCP;
}

public int Native_GetLastStage(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iLastStage;
}

public int Native_GetLastCP(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].iLastCP;
}

public int Native_SetCurrentStage(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int iOldStage = gA_Timers[client].iCurrentStage;
	int iNewStage = GetNativeCell(2);
	gA_Timers[client].iCurrentStage = iNewStage;

	Call_OnStageChanged(client, iOldStage, iNewStage);

	return 0;
}

public int Native_SetCurrentCP(Handle handler, int numParams)
{
	gA_Timers[GetNativeCell(1)].iCurrentCP = GetNativeCell(2);

	return 0;
}

public int Native_SetLastStage(Handle handler, int numParams)
{
	gA_Timers[GetNativeCell(1)].iLastStage = GetNativeCell(2);

	return 0;
}

public int Native_SetLastCP(Handle handler, int numParams)
{
	gA_Timers[GetNativeCell(1)].iLastCP = GetNativeCell(2);

	return 0;
}

public any Native_IsStageTimer(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].bStageTimer;
}

public int Native_SetStageTimer(Handle handler, int numParams)
{
	gA_Timers[GetNativeCell(1)].bStageTimer = view_as<bool>(GetNativeCell(2));

	return 0;
}

public any Native_GetLeaveStageTime(Handle handler, int numParams)
{
	return gA_Timers[GetNativeCell(1)].fLeaveStageTime;
}

public int Native_SetLeaveStageTime(Handle handler, int numParams)
{
	gA_Timers[GetNativeCell(1)].fLeaveStageTime = GetNativeCell(2);

	return 0;
}

public int Native_IsTeleporting(Handle handler, int numParams)
{
	return gA_HookedPlayer[GetNativeCell(1)].GetFlags() & STATUS_ONTELEPORT;
}
