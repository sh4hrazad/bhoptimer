// ======[ PUBLIC EVENTS ]======

void Shavit_OnPause_PersistData(int client)
{
	if (!gB_SaveStates[client])
	{
		PersistData(client, false);
	}
}

void Shavit_OnResume_LoadPersistentData(int client)
{
	if (gB_SaveStates[client])
	{
		// events&outputs won't work properly unless we do this next frame...
		RequestFrame(LoadPersistentData, GetClientSerial(client));
	}
}

void Shavit_OnStop_DeletePersistentDataFromClient(int client)
{
	if (gB_SaveStates[client])
	{
		DeletePersistentDataFromClient(client);
	}
}

int FindPersistentData(int client, persistent_data_t aData)
{
	int iSteamID;

	if((iSteamID = GetSteamAccountID(client)) != 0)
	{
		int index = gA_PersistentData.FindValue(iSteamID, 0);

		if (index != -1)
		{
			gA_PersistentData.GetArray(index, aData);
			return index;
		}
	}

	return -1;
}

void PersistData(int client, bool disconnected)
{
	if(!IsClientInGame(client) ||
		(!IsPlayerAlive(client) && !disconnected) ||
		(!IsPlayerAlive(client) && disconnected && !gB_SaveStates[client]) ||
		GetSteamAccountID(client) == 0 ||
		Shavit_GetTimerStatus(client) == Timer_Stopped ||
		(!gCV_RestoreStates.BoolValue && !disconnected) ||
		(gCV_PersistData.IntValue == 0 && disconnected))
	{
		ResetStageStatus(client);
		return;
	}

	persistent_data_t aData;
	int iIndex = FindPersistentData(client, aData);

	aData.iSteamID = GetSteamAccountID(client);
	aData.iTimesTeleported = gI_TimesTeleported[client];

	if (disconnected)
	{
		aData.iDisconnectTime = GetTime();
		aData.iCurrentCheckpoint = gI_CurrentCheckpoint[client];
		aData.aCheckpoints = gA_Checkpoints[client];
		gA_Checkpoints[client] = null;

		if (gB_Replay && aData.cpcache.aFrames == null)
		{
			aData.cpcache.aFrames = Shavit_GetReplayData(client, true);
			aData.cpcache.iPreFrames = Shavit_GetPlayerPreFrames(client);
			aData.cpcache.iStagePreFrames = Shavit_GetPlayerStagePreFrames(client);
		}
	}
	else
	{
		aData.iDisconnectTime = 0;
	}

	if (!gB_SaveStates[client])
	{
		SaveCheckpointCache(client, aData.cpcache, false);
	}

	gB_SaveStates[client] = true;

	if (iIndex == -1)
	{
		gA_PersistentData.PushArray(aData);
	}
	else
	{
		gA_PersistentData.SetArray(iIndex, aData);
	}
}

void LoadPersistentData(int serial)
{
	int client = GetClientFromSerial(serial);

	if(client == 0 ||
		GetSteamAccountID(client) == 0 ||
		GetClientTeam(client) < 2 ||
		!IsPlayerAlive(client))
	{
		return;
	}

	persistent_data_t aData;
	int iIndex = FindPersistentData(client, aData);

	if (iIndex == -1)
	{
		return;
	}

	LoadCheckpointCache(client, aData.cpcache, true);

	gI_TimesTeleported[client] = aData.iTimesTeleported;

	if (aData.aCheckpoints != null)
	{
		DeleteCheckpointCacheList(gA_Checkpoints[client]);
		delete gA_Checkpoints[client];
		gI_CurrentCheckpoint[client] = aData.iCurrentCheckpoint;
		gA_Checkpoints[client] = aData.aCheckpoints;
		aData.aCheckpoints = null;

		if (gA_Checkpoints[client].Length > 0)
		{
			OpenCheckpointsMenu(client);
		}
	}

	gB_SaveStates[client] = false;
	DeletePersistentData(iIndex, aData);
}

void DeletePersistentData(int index, persistent_data_t data)
{
	gA_PersistentData.Erase(index);
	DeleteCheckpointCache(data.cpcache);
	DeleteCheckpointCacheList(data.aCheckpoints);
	delete data.aCheckpoints;
}

void DeletePersistentDataFromClient(int client)
{
	persistent_data_t aData;
	int iIndex = FindPersistentData(client, aData);

	if (iIndex != -1)
	{
		DeletePersistentData(iIndex, aData);
	}

	gB_SaveStates[client] = false;
}