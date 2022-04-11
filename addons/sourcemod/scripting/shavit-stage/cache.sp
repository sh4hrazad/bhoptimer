// =======[ CLIENT ]======

void ReLoadPlayerStatus(int client)
{
	ResetPlayerStatus(client);

	DB_ReloadStageInfo(client);
	DB_ReloadCPInfo(client);
}

void ResetPlayerStatus(int client)
{
	for(int i = 0; i <= MAX_STAGES; i++)
	{
		gF_CPTime[client][i] = -1.0;
		gF_PreSpeed[client][i] = -1.0;
		gF_PostSpeed[client][i] = -1.0;
		gF_CPEnterStageTime[client][i] = -1.0;
		gI_CPStageAttemps[client][i] = 0;
	}

	ResetClientCache(client);
}

void ResetClientCache(int client)
{
	for(int i = 0; i < STYLE_LIMIT; i++)
	{
		for(int j = 0; j <= MAX_STAGES; j++)
		{
			cp_t cpcache; // null cache
			gA_CheckpointInfo[client][i][j] = cpcache;

			stage_t stagecache; // null cache
			gA_StageInfo[client][i][j] = stagecache;
		}
	}
}

void ResetAllClientsCache()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && !IsFakeClient(i))
		{
			ReLoadPlayerStatus(i);
		}
	}
}

void ResetStageLeaderboards()
{
	for(int i = 0; i < gI_Styles; i++)
	{
		for(int j = 1; j <= MAX_STAGES; j++)
		{
			gA_StageLeaderboard[i][j].Clear();
		}
	}
}



// ======[ WR ]======

void ResetWRStages(int styles = STYLE_LIMIT, int stages = MAX_STAGES)
{
	for(int i = 0; i < styles; i++)
	{
		for(int j = 1; j <= stages; j++)
		{
			gA_WRStageInfo[i][j].iSteamid = -1;
			gA_WRStageInfo[i][j].fTime = -1.0;
			gA_WRStageInfo[i][j].fPostspeed = -1.0;
			strcopy(gA_WRStageInfo[i][j].sName, MAX_NAME_LENGTH, "N/A");
		}
	}

	DB_ReloadWRStages();
}

void ResetWRCPs(int styles = STYLE_LIMIT, int maxcp = MAX_STAGES)
{
	for(int i = 0; i < styles; i++)
	{
		for(int j = 0; j <= maxcp; j++)
		{
			gA_WRCPInfo[i][j].fTime = -1.0;
			gA_WRCPInfo[i][j].fPrespeed = -1.0;
			gA_WRCPInfo[i][j].fPostspeed = -1.0;
		}
	}

	DB_ReloadWRCPs();
}