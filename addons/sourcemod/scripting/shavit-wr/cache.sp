// ======[ EVENTS ]======

void OnMapStart_ClearMapCache()
{
	GetLowercaseMapName(gS_Map);

	gA_ValidMaps.Clear();
	gA_ValidMaps.PushString(gS_Map);
}

void InitCaches()
{
	gSM_WRNames = new StringMap();
	gSM_StyleCommands = new StringMap();
	gA_ValidMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
}

void UpdateMaps()
{
	DB_CacheMaps();
}

void OnStyleConfigLoaded_InitCaches(int styles)
{
	for(int i = 0; i < STYLE_LIMIT; i++)
	{
		if (i < styles)
		{
			Shavit_GetStyleStringsStruct(i, gS_StyleStrings[i]);
			RegisterWRCommands(i);
		}

		for (int j = 0; j < TRACKS_SIZE; j++)
		{
			if (i < styles)
			{
				if (gA_Leaderboard[i][j] == null)
				{
					gA_Leaderboard[i][j] = new ArrayList(sizeof(prcache_t));
				}

				gA_Leaderboard[i][j].Clear();
			}
			else
			{
				delete gA_Leaderboard[i][j];
			}
		}
	}
}

void OnClientConnected_InitCache(int client)
{
	wrcache_t empty_cache;
	gA_WRCache[client] = empty_cache;

	gB_LoadedCache[client] = false;

	any empty_cells[TRACKS_SIZE];

	for(int i = 0; i < gI_Styles; i++)
	{
		gF_PlayerRecord[client][i] = empty_cells;
		gI_PlayerCompletion[client][i] = empty_cells;
		gF_PlayerPrestrafe[client][i] = empty_cells;
	}
}

void UpdateClientCache(int client)
{
	DB_CachePBs(client, GetSteamAccountID(client));
}

void UpdateWRCache(int client = -1)
{
	if (client == -1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && !IsFakeClient(i))
			{
				UpdateClientCache(i);
			}
		}
	}
	else
	{
		UpdateClientCache(client);
	}

	DB_CacheWRs();
	DB_UpdateLeaderboards();

	if (client != -1)
	{
		return;
	}
}

void ResetWRs()
{
	gSM_WRNames.Clear();

	any empty_cells[TRACKS_SIZE];

	for(int i = 0; i < gI_Styles; i++)
	{
		gF_WRTime[i] = empty_cells;
		gI_WRRecordID[i] = empty_cells;
		gI_WRSteamID[i] = empty_cells;
	}
}

void ResetLeaderboards()
{
	for(int i = 0; i < gI_Styles; i++)
	{
		for(int j = 0; j < TRACKS_SIZE; j++)
		{
			gA_Leaderboard[i][j].Clear();
		}
	}
}