void InitCaches()
{
	gA_ValidMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	gA_MapTiers = new StringMap();
}

void OnClientConnected_InitCache(int client)
{
	ranking_t empty_cache;
	gA_Rankings[client] = empty_cache;
}

void OnClientPutInServer_UpdateCache(int client)
{
	if (gH_SQL && !IsFakeClient(client))
	{
		if (gB_WRHoldersRefreshed)
		{
			DB_UpdateWRs(client);
		}

		DB_UpdatePlayerRank(client, true);
	}
}