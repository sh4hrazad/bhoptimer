// ======[ EVENTS ]======

void OnMapStart_ShouldClearCache()
{
	if (!StrEqual(gS_Map, gS_PreviousMap, false))
	{
		int iLength = gA_PersistentData.Length;

		for(int i = iLength - 1; i >= 0; i--)
		{
			persistent_data_t aData;
			gA_PersistentData.GetArray(i, aData);
			DeletePersistentData(i, aData);
		}
	}
}



void DeleteCheckpointCache(cp_cache_t cache)
{
	delete cache.aFrames;
}

void DeleteCheckpointCacheList(ArrayList cps)
{
	if (cps != null)
	{
		for(int i = 0; i < cps.Length; i++)
		{
			cp_cache_t cache;
			cps.GetArray(i, cache);
			DeleteCheckpointCache(cache);
		}

		cps.Clear();
	}
}

void ResetCheckpoints(int client)
{
	DeleteCheckpointCacheList(gA_Checkpoints[client]);
	gI_CurrentCheckpoint[client] = 0;
}

bool SaveCheckpoint(int client)
{
	// ???
	// nairda somehow triggered an error that requires this
	if(!IsValidClient(client))
	{
		return false;
	}

	int target = GetSpectatorTarget(client, client);

	if (target > MaxClients)
	{
		return false;
	}

	if(target == client && !IsPlayerAlive(client))
	{
		Shavit_PrintToChat(client, "%T", "CommandAliveSpectate", client);

		return false;
	}

	if(Shavit_IsPaused(client) || Shavit_IsPaused(target))
	{
		Shavit_PrintToChat(client, "%T", "CommandNoPause", client);

		return false;
	}

	if (IsFakeClient(target))
	{
		if(Shavit_InsideZone(client, Zone_Start, -1))
		{
			Shavit_PrintToChat(client, "%T", "CommandAliveSpectate", client);
			
			return false;
		}
	}

	if (IsFakeClient(target))
	{
		int style = Shavit_GetReplayBotStyle(target);
		int track = Shavit_GetReplayBotTrack(target);

		if(style < 0 || track < 0)
		{
			Shavit_PrintToChat(client, "%T", "CommandAliveSpectate", client);
			
			return false;
		}
	}

	int iMaxCPs = GetMaxCPs(client);
	bool overflow = (gA_Checkpoints[client].Length >= iMaxCPs);
	int index = (overflow ? iMaxCPs : gA_Checkpoints[client].Length+1);

	Action result = Plugin_Continue;
	Call_OnSave(client, index, overflow, result);

	if(result != Plugin_Continue)
	{
		return false;
	}

	cp_cache_t cpcache;
	SaveCheckpointCache(target, cpcache, true);
	gI_CurrentCheckpoint[client] = index;

	if(overflow)
	{
		DeleteCheckpoint(client, 1, true);

		if (gA_Checkpoints[client].Length >= iMaxCPs)
		{
			gA_Checkpoints[client].ShiftUp(iMaxCPs-1);
			gA_Checkpoints[client].SetArray(iMaxCPs-1, cpcache);
			return true;
		}
	}

	gA_Checkpoints[client].PushArray(cpcache);
	return true;
}

void SaveCheckpointCache(int target, cp_cache_t cpcache, bool actually_a_checkpoint)
{
	GetClientAbsOrigin(target, cpcache.fPosition);
	GetClientEyeAngles(target, cpcache.fAngles);
	GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", cpcache.fVelocity);
	GetEntPropVector(target, Prop_Data, "m_vecLadderNormal", cpcache.vecLadderNormal);

	cpcache.iMoveType = GetEntityMoveType(target);
	cpcache.fGravity = GetEntityGravity(target);
	cpcache.fSpeed = GetEntPropFloat(target, Prop_Send, "m_flLaggedMovementValue");

	if(IsFakeClient(target))
	{
		cpcache.iGroundEntity = -1;

		if (cpcache.iMoveType == MOVETYPE_NOCLIP)
		{
			cpcache.iMoveType = MOVETYPE_WALK;
		}
	}
	else
	{
		cpcache.iGroundEntity = GetEntPropEnt(target, Prop_Data, "m_hGroundEntity");

		if (cpcache.iGroundEntity != -1)
		{
			cpcache.iGroundEntity = EntIndexToEntRef(cpcache.iGroundEntity);
		}

		GetEntityClassname(target, cpcache.sClassname, 64);
		GetEntPropString(target, Prop_Data, "m_iName", cpcache.sTargetname, 64);
	}

	if (cpcache.iMoveType == MOVETYPE_NONE || (cpcache.iMoveType == MOVETYPE_NOCLIP && actually_a_checkpoint))
	{
		cpcache.iMoveType = MOVETYPE_WALK;
	}

	cpcache.iFlags = GetEntityFlags(target) & ~(FL_ATCONTROLS|FL_FAKECLIENT);

	cpcache.fStamina = GetEntPropFloat(target, Prop_Send, "m_flStamina");
	cpcache.bDucked = view_as<bool>(GetEntProp(target, Prop_Send, "m_bDucked"));
	cpcache.bDucking = view_as<bool>(GetEntProp(target, Prop_Send, "m_bDucking"));
	cpcache.fDucktime = GetEntPropFloat(target, Prop_Send, "m_flDuckAmount");
	cpcache.fDuckSpeed = GetEntPropFloat(target, Prop_Send, "m_flDuckSpeed");

	timer_snapshot_t snapshot;

	if(IsFakeClient(target))
	{
		// unfortunately replay bots don't have a snapshot, so we can generate a fake one
		snapshot.bTimerEnabled = true;
		snapshot.fCurrentTime = Shavit_GetReplayTime(target);
		snapshot.bClientPaused = false;
		snapshot.bsStyle = Shavit_GetReplayBotStyle(target);
		snapshot.iJumps = 0;
		snapshot.iStrafes = 0;
		snapshot.iTotalMeasures = 0;
		snapshot.iGoodGains = 0;
		snapshot.fServerTime = GetEngineTime();
		snapshot.iSHSWCombination = -1;
		snapshot.iTimerTrack = Shavit_GetReplayBotTrack(target);
		snapshot.fTimescale = Shavit_GetStyleSettingFloat(snapshot.bsStyle, "timescale");
		snapshot.fTimescaledTicks = (Shavit_GetReplayBotCurrentFrame(target) - Shavit_GetReplayCachePreFrames(target)) * snapshot.fTimescale;
		cpcache.fSpeed = snapshot.fTimescale * Shavit_GetStyleSettingFloat(snapshot.bsStyle, "speed");
		ScaleVector(cpcache.fVelocity, 1 / cpcache.fSpeed);
		cpcache.fGravity = Shavit_GetStyleSettingFloat(target, "gravity");
	}
	else
	{
		Shavit_SaveSnapshot(target, snapshot);
	}

	cpcache.aSnapshot = snapshot;
	cpcache.bSegmented = CanSegment(target);

	if (cpcache.bSegmented && gB_Replay && actually_a_checkpoint && cpcache.aFrames == null)
	{
		cpcache.aFrames = Shavit_GetReplayData(target, false);
		cpcache.iPreFrames = Shavit_GetPlayerPreFrames(target);
		cpcache.iStagePreFrames = Shavit_GetPlayerStagePreFrames(target);
	}

	cpcache.iSteamID = GetSteamAccountID(target);
}

void TeleportToCheckpoint(int client, int index, bool suppressMessage)
{
	if(index < 1 || index > gCV_MaxCP.IntValue || (!gCV_Checkpoints.BoolValue && !CanSegment(client)))
	{
		return;
	}

	if(Shavit_IsPaused(client))
	{
		Shavit_PrintToChat(client, "%T", "CommandNoPause", client);

		return;
	}

	if(index > gA_Checkpoints[client].Length)
	{
		Shavit_PrintToChat(client, "%T", "MiscCheckpointsEmpty", client, index);
		return;
	}

	cp_cache_t cpcache;
	gA_Checkpoints[client].GetArray(index - 1, cpcache, sizeof(cp_cache_t));

	if(IsNullVector(cpcache.fPosition))
	{
		return;
	}

	if(!IsPlayerAlive(client))
	{
		Shavit_PrintToChat(client, "%T", "CommandAlive", client);

		return;
	}

	Action result = Plugin_Continue;
	Call_OnTeleport(client, index, result);

	if(result != Plugin_Continue)
	{
		return;
	}

	gI_TimesTeleported[client]++;

	if(Shavit_InsideZone(client, Zone_Start, -1))
	{
		Shavit_StopTimer(client);
	}

	LoadCheckpointCache(client, cpcache, false);
	Shavit_ResumeTimer(client);

	if(!suppressMessage)
	{
		Shavit_PrintToChat(client, "%T", "MiscCheckpointsTeleported", client, index);
	}
}

void LoadCheckpointCache(int client, cp_cache_t cpcache, bool isPersistentData)
{
	SetEntityMoveType(client, cpcache.iMoveType);
	SetEntityFlags(client, cpcache.iFlags);

	int ground = (cpcache.iGroundEntity != -1) ? EntRefToEntIndex(cpcache.iGroundEntity) : -1;
	SetEntPropEnt(client, Prop_Data, "m_hGroundEntity", ground);

	SetEntPropVector(client, Prop_Data, "m_vecLadderNormal", cpcache.vecLadderNormal);
	SetEntPropFloat(client, Prop_Send, "m_flStamina", cpcache.fStamina);
	SetEntProp(client, Prop_Send, "m_bDucked", cpcache.bDucked);
	SetEntProp(client, Prop_Send, "m_bDucking", cpcache.bDucking);

	SetEntPropFloat(client, Prop_Send, "m_flDuckAmount", cpcache.fDucktime);
	SetEntPropFloat(client, Prop_Send, "m_flDuckSpeed", cpcache.fDuckSpeed);

	Shavit_LoadSnapshot(client, cpcache.aSnapshot);

	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", cpcache.fSpeed);
	SetEntPropString(client, Prop_Data, "m_iName", cpcache.sTargetname);
	SetEntPropString(client, Prop_Data, "m_iClassname", cpcache.sClassname);

	TeleportEntity(client, cpcache.fPosition,
		((gI_CheckpointsSettings[client] & CP_ANGLES)   > 0 || cpcache.bSegmented || isPersistentData) ? cpcache.fAngles   : NULL_VECTOR,
		((gI_CheckpointsSettings[client] & CP_VELOCITY) > 0 || cpcache.bSegmented || isPersistentData) ? cpcache.fVelocity : NULL_VECTOR);

	if (cpcache.aSnapshot.bPracticeMode || !(cpcache.bSegmented || isPersistentData) || GetSteamAccountID(client) != cpcache.iSteamID)
	{
		Shavit_SetPracticeMode(client, true);
	}
	else
	{
		Shavit_SetPracticeMode(client, false);

		float latency = GetClientLatency(client, NetFlow_Both);

		if (gCV_ExperimentalSegmentedEyeAngleFix.BoolValue && latency > 0.0)
		{
			int ticks = RoundToCeil(latency / GetTickInterval()) + 1;
			//PrintToChat(client, "%f %f %d", latency, GetTickInterval(), ticks);
			Shavit_HijackAngles(client, cpcache.fAngles[0], cpcache.fAngles[1], ticks);
		}
	}

	SetEntityGravity(client, cpcache.fGravity);

	if(gB_Replay && cpcache.aFrames != null)
	{
		// if isPersistentData, then CloneHandle() is done instead of ArrayList.Clone()
		Shavit_SetReplayData(client, cpcache.aFrames, isPersistentData);
		Shavit_SetPlayerPreFrames(client, cpcache.iPreFrames);
		Shavit_SetPlayerStagePreFrames(client, cpcache.iStagePreFrames);
	}
}

bool DeleteCheckpoint(int client, int index, bool force=false)
{
	if (index < 1 || index > gA_Checkpoints[client].Length)
	{
		return false;
	}

	Action result = Plugin_Continue;

	if (!force)
	{
		Call_OnDelete(client, index, result);
	}

	if (result != Plugin_Continue)
	{
		return false;
	}

	cp_cache_t cpcache;
	gA_Checkpoints[client].GetArray(index-1, cpcache);
	gA_Checkpoints[client].Erase(index-1);
	DeleteCheckpointCache(cpcache);

	return true;
}